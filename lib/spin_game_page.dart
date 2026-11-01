import 'dart:math' as math;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_page.dart';

// ===================================================================
// DAILY LUCKY SPIN
// Opens when the Home page opens (once a day) and from the Play button.
// The server decides the reward (functions/games.js). This page only
// shows the wheel and animates it to the result the server returns.
// ===================================================================

class SpinGamePage extends StatefulWidget {
  const SpinGamePage({super.key});

  @override
  State<SpinGamePage> createState() => _SpinGamePageState();
}

class _SpinGamePageState extends State<SpinGamePage>
    with SingleTickerProviderStateMixin {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  late final AnimationController _controller;
  Animation<double>? _animation;

  double _rotation = 0;

  bool _loading = true;
  bool _spinning = false;
  bool _enabled = true;
  String? _error;

  List<int> _segments = const [1, 2, 3, 5, 8, 10, 15, 20];
  int _playsLeft = 0;
  int _playsPerDay = 0;

  int? _lastWin;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..addListener(() {
        final a = _animation;

        if (a != null) setState(() => _rotation = a.value);
      });

    _loadStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

      final segs = (data['segments'] as List)
          .map((e) => (e as num).toInt())
          .toList();

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
        _error = 'Could not load the spin. Please try again.';
      });
    }
  }

  Future<void> _spin() async {
    if (_spinning || _playsLeft <= 0 || !_enabled) return;

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

      // Middle of the winning piece, clockwise from the top pointer.
      final center = index * seg + seg / 2;

      final base = _rotation % (2 * math.pi);
      final delta = ((2 * math.pi - center) - base) % (2 * math.pi);

      final end = _rotation + 5 * 2 * math.pi + delta;

      _animation = Tween<double>(begin: _rotation, end: end).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );

      _controller.reset();
      await _controller.forward();

      if (!mounted) return;

      setState(() {
        _spinning = false;
        _playsLeft = left;
        _lastWin = points;
      });

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

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showResult(int points) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            points > 0 ? '🎉 You won!' : 'Better luck next time',
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                points > 0 ? '+$points' : '0',
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: Colors.deepOrange,
                ),
              ),
              const Text('points'),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4EE),
      appBar: AppBar(
        title: const Text('Daily Lucky Spin'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildGame(),
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
            const Icon(Icons.casino_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: needsLogin
                  ? _signIn
                  : () {
                      setState(() => _loading = true);
                      _loadStatus();
                    },
              child: Text(needsLogin ? 'Sign In' : 'Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGame() {
    final canSpin = _enabled && _playsLeft > 0 && !_spinning;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        children: [
          const Text(
            'Lucky Spin',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            _enabled
                ? 'Spin the wheel and win reward points!'
                : 'The spin is paused for now.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 22),

          // WHEEL + POINTER
          LayoutBuilder(
            builder: (context, constraints) {
              final size = math.min(constraints.maxWidth, 320.0);

              return SizedBox(
                width: size,
                height: size + 18,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: 18,
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Transform.rotate(
                          angle: _rotation,
                          child: CustomPaint(
                            painter: _WheelPainter(_segments),
                          ),
                        ),
                      ),
                    ),
                    // Pointer (fixed, at the top)
                    const Positioned(
                      top: 0,
                      child: Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 54,
                        color: Colors.black87,
                      ),
                    ),
                    // Center cap
                    Positioned(
                      top: 18 + size / 2 - 22,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.redAccent,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: canSpin ? _spin : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: Text(
                _spinning
                    ? 'Spinning...'
                    : _playsLeft > 0
                        ? 'SPIN'
                        : 'No spins left today',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          Text(
            'Spins left today: $_playsLeft / $_playsPerDay',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),

          if (_lastWin != null) ...[
            const SizedBox(height: 6),
            Text(
              'Last win: +$_lastWin points',
              style: const TextStyle(
                color: Colors.deepOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],

          const SizedBox(height: 18),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Your points are added to your account. A new spin unlocks '
              'every day.',
              style: TextStyle(fontSize: 12.5, height: 1.4),
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

  _WheelPainter(this.segments);

  static const List<Color> _colors = [
    Color(0xFFFF5252),
    Color(0xFFFFB300),
    Color(0xFF26C6DA),
    Color(0xFF66BB6A),
    Color(0xFFAB47BC),
    Color(0xFFFF7043),
    Color(0xFF42A5F5),
    Color(0xFFEC407A),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final n = segments.length;
    final piece = 2 * math.pi / n;

    final fill = Paint()..style = PaintingStyle.fill;

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 3;

    for (var i = 0; i < n; i++) {
      final start = -math.pi / 2 + i * piece;

      fill.color = _colors[i % _colors.length];

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        piece,
        true,
        fill,
      );

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        piece,
        true,
        border,
      );

      // Label in the middle of the piece
      final mid = start + piece / 2;
      final labelPos = Offset(
        center.dx + math.cos(mid) * radius * 0.68,
        center.dy + math.sin(mid) * radius * 0.68,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: '${segments[i]}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black38, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(labelPos.dx, labelPos.dy);
      canvas.rotate(mid + math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // Outer ring
    canvas.drawCircle(
      center,
      radius - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white
        ..strokeWidth = 5,
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.segments != segments;
}
