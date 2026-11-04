import 'dart:math' as math;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'login_page.dart';

// ===================================================================
// DAILY LUCKY SPIN  (premium look)
// Opens when the Home page opens (once a day) and from the Play button.
// The server decides the reward (functions/games.js). This page only
// shows the wheel and animates it to the result the server returns.
//
// Server API is unchanged: getSpinStatus / playSpinGame.
// ===================================================================

/// Readable message for a failed server call.
String _gameErrorText(Object e) {
  if (e is FirebaseFunctionsException) {
    switch (e.code) {
      case 'not-found':
        return 'The game is not set up on the server yet.\n'
            '(not-found: deploy functions/games.js)';
      case 'unauthenticated':
        return 'Please sign in again.\n(unauthenticated)';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'No connection to the server. Check your internet.\n'
            '(${e.code})';
      default:
        return 'Could not load.\n(${e.code}) ${e.message ?? ''}';
    }
  }

  return 'Could not load.\n$e';
}

class SpinGamePage extends StatefulWidget {
  const SpinGamePage({super.key});

  @override
  State<SpinGamePage> createState() => _SpinGamePageState();
}

class _SpinGamePageState extends State<SpinGamePage>
    with TickerProviderStateMixin {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final math.Random _rng = math.Random();

  late final AnimationController _spinCtl;
  late final AnimationController _glow;
  late final AnimationController _confetti;
  Animation<double>? _animation;

  double _rotation = 0;
  double _kick = 0;
  int _lastIdx = -1;

  bool _loading = true;
  bool _spinning = false;
  bool _enabled = true;
  String? _error;

  List<int> _segments = const [1, 2, 3, 5, 8, 10, 15, 20];
  int _playsLeft = 0;
  int _playsPerDay = 0;

  int? _lastWin;
  List<_Piece> _pieces = const [];

  @override
  void initState() {
    super.initState();

    _spinCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5400),
    )..addListener(_onSpinTick);

    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _loadStatus();
  }

  @override
  void dispose() {
    _spinCtl.dispose();
    _glow.dispose();
    _confetti.dispose();
    super.dispose();
  }

  void _onSpinTick() {
    final a = _animation;

    if (a == null) return;

    _rotation = a.value;

    final n = _segments.length;
    final piece = 2 * math.pi / n;
    final pos = (-_rotation) % (2 * math.pi);
    final idx = (pos / piece).floor() % n;

    // Every time the pointer passes a divider: tick + pointer kick.
    if (idx != _lastIdx) {
      _lastIdx = idx;
      _kick = 1.0;
      HapticFeedback.selectionClick();
    }

    _kick *= 0.86;

    setState(() {});
  }

  Future<void> _loadStatus() async {
    if (FirebaseAuth.instance.currentUser == null) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Please sign in to spin.';
      });

      return;
    }

    try {
      final res = await _functions.httpsCallable('getSpinStatus').call();
      final data = Map<String, dynamic>.from(res.data as Map);

      final segs =
          (data['segments'] as List).map((e) => (e as num).toInt()).toList();

      if (!mounted) return;

      setState(() {
        _segments = segs.length >= 2 ? segs : _segments;
        _enabled = data['enabled'] != false;
        _playsLeft = (data['playsLeft'] as num?)?.toInt() ?? 0;
        _playsPerDay = (data['playsPerDay'] as num?)?.toInt() ?? 0;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = _gameErrorText(e);
      });
    }
  }

  Future<void> _spin() async {
    if (_spinning || _playsLeft <= 0 || !_enabled) return;

    HapticFeedback.mediumImpact();

    setState(() {
      _spinning = true;
      _lastWin = null;
    });

    try {
      final res = await _functions.httpsCallable('playSpinGame').call();
      final data = Map<String, dynamic>.from(res.data as Map);

      final index = (data['index'] as num).toInt();
      final points = (data['points'] as num).toInt();
      final left = (data['playsLeft'] as num).toInt();

      final n = _segments.length;
      final seg = 2 * math.pi / n;

      // Land somewhere inside the winning piece (not always dead centre).
      final jitter = (_rng.nextDouble() - 0.5) * seg * 0.55;
      final center = index * seg + seg / 2 + jitter;

      final base = _rotation % (2 * math.pi);
      final delta = ((2 * math.pi - center) - base) % (2 * math.pi);

      final end = _rotation + 6 * 2 * math.pi + delta;

      _animation = Tween<double>(begin: _rotation, end: end).animate(
        CurvedAnimation(parent: _spinCtl, curve: Curves.easeOutQuart),
      );

      _lastIdx = -1;
      _spinCtl.reset();
      await _spinCtl.forward();

      if (!mounted) return;

      setState(() {
        _spinning = false;
        _playsLeft = left;
        _lastWin = points;
        _kick = 0;
      });

      if (points > 0) {
        _launchConfetti();
        HapticFeedback.heavyImpact();
      }

      _showResult(points);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      setState(() => _spinning = false);

      _snack(e.message ?? 'Something went wrong.');

      if (e.code == 'resource-exhausted') {
        setState(() => _playsLeft = 0);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _spinning = false);

      _snack('Something went wrong. Please try again.');
    }
  }

  void _launchConfetti() {
    const colors = [
      Color(0xFFFF5252),
      Color(0xFFFFD740),
      Color(0xFF40C4FF),
      Color(0xFF69F0AE),
      Color(0xFFE040FB),
      Color(0xFFFFFFFF),
    ];

    _pieces = List.generate(110, (i) {
      final a = -math.pi / 2 + (_rng.nextDouble() - 0.5) * math.pi * 1.15;
      final s = 260 + _rng.nextDouble() * 620;

      return _Piece(
        vx: math.cos(a) * s,
        vy: math.sin(a) * s,
        size: 6 + _rng.nextDouble() * 7,
        rot: _rng.nextDouble() * math.pi * 2,
        vr: (_rng.nextDouble() - 0.5) * 14,
        color: colors[_rng.nextInt(colors.length)],
        round: _rng.nextDouble() < 0.25,
      );
    });

    _confetti.forward(from: 0);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showResult(int points) {
    final maxVal = _segments.reduce(math.max);

    final String title;

    if (points <= 0) {
      title = 'Better luck next time';
    } else if (points >= maxVal && maxVal > 0) {
      title = '🏆 JACKPOT!';
    } else if (points >= maxVal * 0.4) {
      title = '🔥 BIG WIN!';
    } else {
      title = '🎉 You won!';
    }

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.55, end: 1.0),
            duration: const Duration(milliseconds: 650),
            curve: Curves.elasticOut,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF3B1478), Color(0xFF1A0838)],
                ),
                border: Border.all(color: const Color(0xFFFFD54F), width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFC107).withValues(alpha: 0.45),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFF59D), Color(0xFFFFA000)],
                    ).createShader(r),
                    child: Text(
                      points > 0 ? '+$points' : '0',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'REWARD POINTS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: _GradientButton(
                      label: 'AWESOME',
                      onTap: () => Navigator.pop(dialogContext),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _signIn() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );

    if (!mounted) return;

    setState(() => _loading = true);

    await _loadStatus();
  }

  // -----------------------------------------------------------------
  // UI
  // -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF12062E),
      appBar: AppBar(
        title: const Text(
          'Daily Lucky Spin',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF34106B), Color(0xFF16063A), Color(0xFF080216)],
              ),
            ),
          ),
          CustomPaint(painter: _StarsPainter(_glow)),
          Positioned(
            top: 90,
            left: -60,
            right: -60,
            child: IgnorePointer(
              child: Container(
                height: 520,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0x66FF4DA6), Color(0x00FF4DA6)],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : _error != null
                    ? _buildError()
                    : _buildGame(),
          ),

          // Confetti on top of everything
          IgnorePointer(
            child: CustomPaint(
              painter: _ConfettiPainter(_pieces, _confetti),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    final needsLogin = FirebaseAuth.instance.currentUser == null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.casino_outlined, size: 60, color: Colors.white54),
            const SizedBox(height: 14),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, height: 1.4),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: _GradientButton(
                label: needsLogin ? 'Sign In' : 'Try again',
                onTap: needsLogin
                    ? _signIn
                    : () {
                        setState(() => _loading = true);
                        _loadStatus();
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGame() {
    final canSpin = _enabled && _playsLeft > 0 && !_spinning;
    final maxVal = _segments.reduce(math.max);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [Color(0xFFFFF59D), Color(0xFFFFB300), Color(0xFFFFF59D)],
            ).createShader(r),
            child: const Text(
              'LUCKY SPIN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _enabled
                ? 'Spin the wheel and win reward points!'
                : 'The spin is paused for now.',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),

          // Spins left badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎟️', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  'Spins left today: $_playsLeft / $_playsPerDay',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // WHEEL
          LayoutBuilder(
            builder: (context, constraints) {
              final size = math.min(constraints.maxWidth, 360.0);

              return SizedBox(
                width: size,
                height: size,
                child: CustomPaint(
                  painter: _WheelPainter(
                    segments: _segments,
                    rotation: _rotation,
                    kick: _kick,
                    spinning: _spinning,
                    glow: _glow,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 26),

          // SPIN BUTTON (pulses when ready)
          AnimatedBuilder(
            animation: _glow,
            builder: (context, child) {
              final pulse =
                  canSpin ? 1.0 + 0.025 * math.sin(_glow.value * 2 * math.pi) : 1.0;

              return Transform.scale(scale: pulse, child: child);
            },
            child: SizedBox(
              width: double.infinity,
              height: 58,
              child: _GradientButton(
                label: _spinning
                    ? 'SPINNING...'
                    : _playsLeft > 0
                        ? 'SPIN NOW'
                        : 'NO SPINS LEFT TODAY',
                icon: Icons.casino_rounded,
                onTap: canSpin ? _spin : null,
                gold: true,
                fontSize: 18,
              ),
            ),
          ),

          if (_lastWin != null) ...[
            const SizedBox(height: 12),
            Text(
              _lastWin! > 0
                  ? 'Last win: +$_lastWin points'
                  : 'Last spin: no points',
              style: const TextStyle(
                color: Color(0xFFFFD54F),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],

          const SizedBox(height: 22),

          // PRIZE LIST
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'PRIZES ON THE WHEEL',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _segments.length; i++)
                _PrizeChip(
                  value: _segments[i],
                  color: _WheelPainter.colorFor(i, _segments.length),
                  gold: _segments[i] == maxVal && maxVal > 0,
                ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: const Text(
              'Your points are added to your account instantly. '
              'A new spin unlocks every day.',
              style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// SMALL WIDGETS
// ===================================================================

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool gold;
  final double fontSize;

  const _GradientButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.gold = false,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    final colors = gold
        ? const [Color(0xFFFFE082), Color(0xFFFFA000)]
        : const [Color(0xFFFF5252), Color(0xFFFF9800)];

    final fg = gold ? const Color(0xFF3E2000) : Colors.white;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(colors: colors),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: colors.last.withValues(alpha: 0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: fg, size: fontSize + 6),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrizeChip extends StatelessWidget {
  final int value;
  final Color color;
  final bool gold;

  const _PrizeChip({
    required this.value,
    required this.color,
    required this.gold,
  });

  @override
  Widget build(BuildContext context) {
    final c = gold ? const Color(0xFFFFC107) : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            gold ? '$value 👑' : '$value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// WHEEL DRAWING
// Piece i starts at angle (-90deg + i * piece): the top pointer is at
// the start of piece 0 when the wheel is not rotated.
// ===================================================================

class _WheelPainter extends CustomPainter {
  final List<int> segments;
  final double rotation;
  final double kick;
  final bool spinning;
  final Animation<double> glow;

  _WheelPainter({
    required this.segments,
    required this.rotation,
    required this.kick,
    required this.spinning,
    required this.glow,
  }) : super(repaint: glow);

  static const List<Color> _colors = [
    Color(0xFFE53935),
    Color(0xFF00ACC1),
    Color(0xFF7E57C2),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF1E88E5),
    Color(0xFFD81B60),
    Color(0xFF26A69A),
  ];

  static Color colorFor(int i, int n) {
    var idx = i % _colors.length;

    // Avoid the last piece having the same colour as the first.
    if (i == n - 1 && idx == 0 && n > 1) idx = 4;

    return _colors[idx];
  }

  Offset _polar(double r, double a) => Offset(math.cos(a) * r, math.sin(a) * r);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final rad = size.width / 2;

    final n = segments.length;
    final piece = 2 * math.pi / n;
    final maxVal = segments.reduce(math.max);

    // ---- soft golden glow behind the wheel ----
    canvas.drawCircle(
      c,
      rad * 0.98,
      Paint()
        ..color = const Color(0x66FFC107)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );

    // ---- golden rim ----
    final rimRect = Rect.fromCircle(center: c, radius: rad - 2);

    canvas.drawCircle(
      c,
      rad - 2,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFFF59D),
            Color(0xFFFFA000),
            Color(0xFFFFF59D),
            Color(0xFFFF8F00),
            Color(0xFFFFF59D),
          ],
        ).createShader(rimRect),
    );

    canvas.drawCircle(c, rad * 0.905, Paint()..color = const Color(0xFF2A1048));

    // ---- blinking bulbs on the rim ----
    const bulbs = 24;
    final phase = (glow.value * (spinning ? 10 : 2)).floor();

    for (var i = 0; i < bulbs; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / bulbs;
      final p = c + _polar(rad * 0.955, a);
      final on = (i + phase) % 2 == 0;

      if (on) {
        canvas.drawCircle(
          p,
          rad * 0.04,
          Paint()
            ..color = const Color(0xFFFFEE58).withValues(alpha: 0.55)
            ..blendMode = BlendMode.plus,
        );
        canvas.drawCircle(p, rad * 0.02, Paint()..color = Colors.white);
      } else {
        canvas.drawCircle(
          p,
          rad * 0.018,
          Paint()..color = const Color(0xFF9C6B12),
        );
      }
    }

    // ---- the wheel itself (rotates) ----
    final wr = rad * 0.84;
    final wheelRect = Rect.fromCircle(center: Offset.zero, radius: wr);

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rotation);

    for (var i = 0; i < n; i++) {
      final start = -math.pi / 2 + i * piece;
      final mid = start + piece / 2;

      final isTop = segments[i] == maxVal && maxVal > 0;
      final base = isTop ? const Color(0xFFFFB300) : colorFor(i, n);

      final light = Color.lerp(base, Colors.white, isTop ? 0.45 : 0.28)!;
      final dark = Color.lerp(base, Colors.black, 0.28)!;

      canvas.drawArc(
        wheelRect,
        start,
        piece,
        true,
        Paint()
          ..shader = RadialGradient(
            colors: [dark, base, light],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(wheelRect),
      );

      // divider
      canvas.drawLine(
        Offset.zero,
        _polar(wr, start),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..strokeWidth = 2.2,
      );

      // little dot near the rim
      canvas.drawCircle(
        _polar(wr * 0.93, mid),
        rad * 0.012,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );

      // number, reading from the centre outwards
      canvas.save();
      canvas.translate(_polar(wr * 0.64, mid).dx, _polar(wr * 0.64, mid).dy);
      canvas.rotate(mid);

      final fs = wr * (segments[i] >= 100 ? 0.15 : 0.19);

      final outline = TextPainter(
        text: TextSpan(
          text: '${segments[i]}',
          style: TextStyle(
            fontSize: fs,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..color = Colors.black.withValues(alpha: 0.45),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final fill = TextPainter(
        text: TextSpan(
          text: '${segments[i]}',
          style: TextStyle(
            fontSize: fs,
            fontWeight: FontWeight.w900,
            color: isTop ? const Color(0xFF4E2A00) : Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final off = Offset(-fill.width / 2, -fill.height / 2);

      outline.paint(canvas, off);
      fill.paint(canvas, off);

      canvas.restore();
    }

    // ring around the coloured area
    canvas.drawCircle(
      Offset.zero,
      wr,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white
        ..strokeWidth = 3.5,
    );

    canvas.restore();

    // ---- centre hub ----
    final hubR = rad * 0.15;

    canvas.drawCircle(
      c,
      hubR + 4,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    canvas.drawCircle(
      c,
      hubR,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFF59D), Color(0xFFFF8F00)],
        ).createShader(Rect.fromCircle(center: c, radius: hubR)),
    );

    canvas.drawCircle(c, hubR * 0.72, Paint()..color = const Color(0xFF2A1048));

    final star = TextPainter(
      text: TextSpan(
        text: '★',
        style: TextStyle(
          color: const Color(0xFFFFD54F),
          fontSize: hubR * 1.05,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    star.paint(canvas, c - Offset(star.width / 2, star.height / 2));

    // ---- pointer (fixed at the top, kicks when it hits a divider) ----
    final pivot = Offset(c.dx, c.dy - rad * 0.93);
    final len = rad * 0.2;
    final hw = rad * 0.075;

    final path = Path()
      ..moveTo(-hw, 0)
      ..lineTo(0, len)
      ..lineTo(hw, 0)
      ..close();

    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(-kick * 0.5);

    canvas.drawPath(
      path.shift(const Offset(2, 4)),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    canvas.drawPath(path, Paint()..color = const Color(0xFFFF1744));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(Offset.zero, hw * 1.05, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset.zero,
      hw * 0.6,
      Paint()..color = const Color(0xFFFF1744),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => true;
}

// ===================================================================
// STARS + CONFETTI
// ===================================================================

class _StarsPainter extends CustomPainter {
  final Animation<double> anim;

  _StarsPainter(this.anim) : super(repaint: anim);

  static final List<List<double>> _stars = () {
    final r = math.Random(11);

    return List.generate(
      46,
      (i) => [r.nextDouble(), r.nextDouble(), 0.8 + r.nextDouble() * 1.6, r.nextDouble() * 6.28],
    );
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();

    for (final s in _stars) {
      final twinkle = 0.25 + 0.75 * math.sin(anim.value * 2 * math.pi + s[3]).abs();

      p.color = Colors.white.withValues(alpha: 0.55 * twinkle);

      canvas.drawCircle(Offset(s[0] * size.width, s[1] * size.height), s[2], p);
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter old) => false;
}

class _Piece {
  final double vx;
  final double vy;
  final double size;
  final double rot;
  final double vr;
  final Color color;
  final bool round;

  const _Piece({
    required this.vx,
    required this.vy,
    required this.size,
    required this.rot,
    required this.vr,
    required this.color,
    required this.round,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final AnimationController anim;

  _ConfettiPainter(this.pieces, this.anim) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    if (pieces.isEmpty || !anim.isAnimating) return;

    final t = anim.value * 2.8;
    final fade = (1.0 - (anim.value - 0.7) / 0.3).clamp(0.0, 1.0);

    final ox = size.width / 2;
    final oy = size.height * 0.4;

    final paint = Paint();

    for (final p in pieces) {
      final x = ox + p.vx * t;
      final y = oy + p.vy * t + 0.5 * 950 * t * t;

      if (y > size.height + 30) continue;

      paint.color = p.color.withValues(alpha: fade);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rot + p.vr * t);

      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size * 0.45, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}
