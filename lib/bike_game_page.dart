import 'dart:math' as math;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'login_page.dart';

// ===================================================================
// PLAY & EARN: BIKE RIDER
// Ride the motorbike, dodge the cars, grab the coins.
// Tap the left / right side of the screen (or swipe) to change lane.
//
// The points are decided by the SERVER (functions/games.js):
//   startBikeGame  -> starts a run
//   finishBikeGame -> checks the score and adds the points
// ===================================================================

enum _Phase { loading, ready, running, over }

class _Car {
  final int lane;
  double y;
  final Color color;

  _Car(this.lane, this.y, this.color);
}

class _Coin {
  final int lane;
  double y;

  _Coin(this.lane, this.y);
}

class BikeGamePage extends StatefulWidget {
  const BikeGamePage({super.key});

  @override
  State<BikeGamePage> createState() => _BikeGamePageState();
}

class _BikeGamePageState extends State<BikeGamePage>
    with SingleTickerProviderStateMixin {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final math.Random _rng = math.Random();

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  _Phase _phase = _Phase.loading;
  String? _error;

  // Rules from the server
  bool _enabled = true;
  int _playsLeft = 0;
  int _playsPerDay = 0;
  int _pointsToday = 0;
  int _maxPointsPerDay = 0;
  int _scorePerPoint = 100;
  int _maxPointsPerRun = 10;

  String? _sessionId;
  bool _starting = false;
  bool _saving = false;

  // Result of the last run
  int _earned = 0;
  String _resultNote = '';

  // Game state
  Size _size = Size.zero;

  int _lane = 1;
  double _bikeX = 0;
  double _roadOffset = 0;
  double _score = 0;
  double _playTime = 0;
  double _spawnDist = 0;
  int _coinsTaken = 0;

  final List<_Car> _cars = <_Car>[];
  final List<_Coin> _coins = <_Coin>[];

  static const List<Color> _carColors = [
    Color(0xFF42A5F5),
    Color(0xFFFFCA28),
    Color(0xFF66BB6A),
    Color(0xFFAB47BC),
    Color(0xFFEC407A),
    Color(0xFFECEFF1),
  ];

  // ---------------------------------------------------------
  // GEOMETRY
  // ---------------------------------------------------------

  double get _roadW => math.min(_size.width * 0.88, 420.0);
  double get _roadLeft => (_size.width - _roadW) / 2;
  double get _laneW => _roadW / 3;

  double _laneCenter(int lane) => _roadLeft + _laneW * (lane + 0.5);

  double get _bikeW => _laneW * 0.36;
  double get _bikeH => _laneW * 0.82;
  double get _bikeTop => _size.height - _bikeH - _size.height * 0.10;

  double get _carW => _laneW * 0.58;
  double get _carH => _laneW * 1.08;

  double get _coinR => _laneW * 0.15;

  // ---------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _ticker = createTicker(_onTick)..start();

    _loadStatus();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // SERVER
  // ---------------------------------------------------------

  Future<void> _loadStatus() async {
    if (FirebaseAuth.instance.currentUser == null) {
      if (!mounted) return;

      setState(() {
        _phase = _Phase.ready;
        _error = 'Please sign in to play and earn points.';
      });

      return;
    }

    try {
      final res = await _functions.httpsCallable('getGameStatus').call();
      final d = Map<String, dynamic>.from(res.data as Map);

      if (!mounted) return;

      setState(() {
        _enabled = d['enabled'] != false;
        _playsLeft = (d['playsLeft'] as num?)?.toInt() ?? 0;
        _playsPerDay = (d['playsPerDay'] as num?)?.toInt() ?? 0;
        _pointsToday = (d['pointsToday'] as num?)?.toInt() ?? 0;
        _maxPointsPerDay = (d['maxPointsPerDay'] as num?)?.toInt() ?? 0;
        _scorePerPoint = (d['scorePerPoint'] as num?)?.toInt() ?? 100;
        _maxPointsPerRun = (d['maxPointsPerRun'] as num?)?.toInt() ?? 10;
        _error = null;
        _phase = _Phase.ready;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not load the game. Check your internet and try again.';
        _phase = _Phase.ready;
      });
    }
  }

  Future<void> _start() async {
    if (_starting || _size == Size.zero) return;

    setState(() => _starting = true);

    try {
      final res = await _functions.httpsCallable('startBikeGame').call();
      final d = Map<String, dynamic>.from(res.data as Map);

      if (!mounted) return;

      _sessionId = d['sessionId']?.toString();
      _playsLeft = (d['playsLeft'] as num?)?.toInt() ?? 0;

      _resetRun();

      setState(() {
        _starting = false;
        _phase = _Phase.running;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      setState(() => _starting = false);

      _snack(e.message ?? 'Could not start the game.');

      if (e.code == 'resource-exhausted') {
        setState(() => _playsLeft = 0);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _starting = false);

      _snack('Could not start the game. Please try again.');
    }
  }

  Future<void> _finish() async {
    final id = _sessionId;

    if (id == null) return;

    setState(() => _saving = true);

    try {
      final res = await _functions.httpsCallable('finishBikeGame').call({
        'sessionId': id,
        'score': _score.floor(),
      });

      final d = Map<String, dynamic>.from(res.data as Map);

      if (!mounted) return;

      setState(() {
        _earned = (d['points'] as num?)?.toInt() ?? 0;
        _resultNote = d['note']?.toString() ?? '';
        _playsLeft = (d['playsLeft'] as num?)?.toInt() ?? _playsLeft;
        _pointsToday = (d['pointsToday'] as num?)?.toInt() ?? _pointsToday;
        _saving = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      setState(() {
        _earned = 0;
        _resultNote = e.message ?? 'Could not save your score.';
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _earned = 0;
        _resultNote = 'Could not save your score.';
        _saving = false;
      });
    } finally {
      _sessionId = null;
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

  Future<void> _signIn() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );

    if (!mounted) return;

    setState(() => _phase = _Phase.loading);

    await _loadStatus();
  }

  // ---------------------------------------------------------
  // GAME LOOP
  // ---------------------------------------------------------

  void _resetRun() {
    _cars.clear();
    _coins.clear();

    _lane = 1;
    _bikeX = _laneCenter(1);
    _roadOffset = 0;
    _score = 0;
    _playTime = 0;
    _spawnDist = 0;
    _coinsTaken = 0;
    _earned = 0;
    _resultNote = '';
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1000000.0)
        .clamp(0.0, 0.05)
        .toDouble();

    _last = elapsed;

    if (_phase != _Phase.running || _size == Size.zero) return;

    _playTime += dt;

    // Speed grows slowly: 260 -> 720 pixels per second.
    final speed = 260.0 + math.min(460.0, _playTime * 9.0);
    final move = speed * dt;

    _roadOffset = (_roadOffset + move) % 80.0;

    // Distance score (about 10 -> 28 per second).
    _score += dt * speed / 26.0;

    // Bike slides smoothly to its lane.
    _bikeX += (_laneCenter(_lane) - _bikeX) * math.min(1.0, dt * 14.0);

    // New traffic.
    _spawnDist += move;

    final gap = math.max(250.0, 430.0 - _playTime * 3.0);

    if (_spawnDist >= gap) {
      _spawnDist = 0;
      _spawnTraffic(gap);
    }

    for (final c in _cars) {
      c.y += move;
    }

    for (final c in _coins) {
      c.y += move;
    }

    _cars.removeWhere((c) => c.y > _size.height + _carH);
    _coins.removeWhere((c) => c.y > _size.height + _coinR * 2);

    // Collisions.
    final bikeRect = Rect.fromCenter(
      center: Offset(_bikeX, _bikeTop + _bikeH / 2),
      width: _bikeW * 0.8,
      height: _bikeH * 0.85,
    );

    for (final c in _cars) {
      final carRect = Rect.fromCenter(
        center: Offset(_laneCenter(c.lane), c.y),
        width: _carW * 0.88,
        height: _carH * 0.9,
      );

      if (bikeRect.overlaps(carRect)) {
        _crash();
        return;
      }
    }

    _coins.removeWhere((coin) {
      final coinRect = Rect.fromCircle(
        center: Offset(_laneCenter(coin.lane), coin.y),
        radius: _coinR,
      );

      if (bikeRect.overlaps(coinRect)) {
        _score += 5;
        _coinsTaken++;
        return true;
      }

      return false;
    });

    setState(() {});
  }

  void _spawnTraffic(double gap) {
    final lane = _rng.nextInt(3);

    final usedLanes = <int>{lane};

    _cars.add(
      _Car(lane, -_carH, _carColors[_rng.nextInt(_carColors.length)]),
    );

    // Later in the run two cars can come together, but one lane stays free.
    if (_playTime > 15 && _rng.nextDouble() < 0.35) {
      final second = (lane + 1 + _rng.nextInt(2)) % 3;

      usedLanes.add(second);

      _cars.add(
        _Car(second, -_carH, _carColors[_rng.nextInt(_carColors.length)]),
      );
    }

    // A coin in a free lane, between this car and the next one.
    if (_rng.nextDouble() < 0.55) {
      final free = [0, 1, 2].where((l) => !usedLanes.contains(l)).toList();

      final coinLane = free[_rng.nextInt(free.length)];

      _coins.add(_Coin(coinLane, -_carH - gap / 2));
    }
  }

  void _crash() {
    HapticFeedback.heavyImpact();

    setState(() {
      _phase = _Phase.over;
    });

    _finish();
  }

  // ---------------------------------------------------------
  // CONTROLS
  // ---------------------------------------------------------

  void _moveLane(int direction) {
    if (_phase != _Phase.running) return;

    final next = (_lane + direction).clamp(0, 2).toInt();

    if (next != _lane) {
      HapticFeedback.selectionClick();
      _lane = next;
    }
  }

  // ---------------------------------------------------------
  // UI
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E7D32),
      appBar: AppBar(
        title: const Text('Bike Rider'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _size = Size(constraints.maxWidth, constraints.maxHeight);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              _moveLane(details.localPosition.dx < _size.width / 2 ? -1 : 1);
            },
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;

              if (v.abs() > 200) _moveLane(v < 0 ? -1 : 1);
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _GamePainter(
                    roadLeft: _roadLeft,
                    roadW: _roadW,
                    laneW: _laneW,
                    roadOffset: _roadOffset,
                    bikeX: _bikeX,
                    bikeTop: _bikeTop,
                    bikeW: _bikeW,
                    bikeH: _bikeH,
                    carW: _carW,
                    carH: _carH,
                    coinR: _coinR,
                    cars: _cars,
                    coins: _coins,
                    laneCenter: _laneCenter,
                  ),
                ),

                if (_phase == _Phase.running) _buildHud(),

                if (_phase == _Phase.loading)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),

                if (_phase == _Phase.ready) _buildReadyCard(),

                if (_phase == _Phase.over) _buildOverCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHud() {
    return Positioned(
      top: 10,
      left: 12,
      right: 12,
      child: IgnorePointer(
        child: Row(
          children: [
            _hudChip(Icons.speed, '${_score.floor()}'),
            const Spacer(),
            _hudChip(Icons.monetization_on, '$_coinsTaken',
                color: Colors.amber),
          ],
        ),
      ),
    );
  }

  Widget _hudChip(IconData icon, String text, {Color color = Colors.white}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 26),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  Widget _buildReadyCard() {
    final needsLogin = FirebaseAuth.instance.currentUser == null;
    final canPlay = _enabled && _playsLeft > 0 && _error == null;

    return _card(
      children: [
        const Icon(Icons.two_wheeler, size: 54, color: Colors.redAccent),
        const SizedBox(height: 6),
        const Text(
          'Bike Rider',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (_error != null) ...[
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: needsLogin
                ? _signIn
                : () {
                    setState(() => _phase = _Phase.loading);
                    _loadStatus();
                  },
            child: Text(needsLogin ? 'Sign In' : 'Try again'),
          ),
        ] else ...[
          const Text(
            'Tap the left or right side of the screen to change lane. '
            'Dodge the cars and collect coins!',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Every $_scorePerPoint score = 1 point '
            '(max $_maxPointsPerRun per ride)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            'Plays left today: $_playsLeft / $_playsPerDay',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            'Game points today: $_pointsToday / $_maxPointsPerDay',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: canPlay && !_starting ? _start : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(
                !_enabled
                    ? 'Game paused'
                    : _playsLeft <= 0
                        ? 'No plays left today'
                        : _starting
                            ? 'Starting...'
                            : 'START',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _noteText() {
    switch (_resultNote) {
      case 'daily_cap':
        return "You reached today's game points limit.";
      case 'too_fast':
        return 'Ride a little longer to earn points.';
      case 'rejected':
        return 'This score could not be verified.';
      case 'expired':
        return 'This ride expired.';
      case 'ok':
        return '';
      default:
        return _resultNote;
    }
  }

  Widget _buildOverCard() {
    final note = _noteText();

    return _card(
      children: [
        const Text(
          'Crash! 💥',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Text(
          'Score: ${_score.floor()}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        Text(
          'Coins: $_coinsTaken',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        if (_saving)
          const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          )
        else ...[
          Text(
            _earned > 0 ? '+$_earned points' : '0 points',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: _earned > 0 ? Colors.deepOrange : Colors.grey,
            ),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              note,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Plays left today: $_playsLeft / $_playsPerDay',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _playsLeft > 0 && !_starting ? _start : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Play again'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ===================================================================
// DRAWING (road, traffic, coins, motorbike)
// ===================================================================

class _GamePainter extends CustomPainter {
  final double roadLeft;
  final double roadW;
  final double laneW;
  final double roadOffset;
  final double bikeX;
  final double bikeTop;
  final double bikeW;
  final double bikeH;
  final double carW;
  final double carH;
  final double coinR;
  final List<_Car> cars;
  final List<_Coin> coins;
  final double Function(int lane) laneCenter;

  _GamePainter({
    required this.roadLeft,
    required this.roadW,
    required this.laneW,
    required this.roadOffset,
    required this.bikeX,
    required this.bikeTop,
    required this.bikeW,
    required this.bikeH,
    required this.carW,
    required this.carH,
    required this.coinR,
    required this.cars,
    required this.coins,
    required this.laneCenter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Grass
    paint.color = const Color(0xFF2E7D32);
    canvas.drawRect(Offset.zero & size, paint);

    // Road
    paint.color = const Color(0xFF37474F);
    canvas.drawRect(
      Rect.fromLTWH(roadLeft, 0, roadW, size.height),
      paint,
    );

    // Road edges
    paint.color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(roadLeft - 4, 0, 4, size.height),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(roadLeft + roadW, 0, 4, size.height),
      paint,
    );

    // Moving lane dashes
    paint.color = Colors.white.withValues(alpha: 0.7);

    for (var i = 1; i <= 2; i++) {
      final x = roadLeft + laneW * i - 2;

      for (double y = -80 + roadOffset; y < size.height; y += 80) {
        canvas.drawRect(Rect.fromLTWH(x, y, 4, 40), paint);
      }
    }

    // Coins
    for (final c in coins) {
      final center = Offset(laneCenter(c.lane), c.y);

      paint.color = const Color(0xFFFFB300);
      canvas.drawCircle(center, coinR, paint);

      paint.color = const Color(0xFFFFE082);
      canvas.drawCircle(center, coinR * 0.68, paint);
    }

    // Cars
    for (final c in cars) {
      _drawCar(canvas, Offset(laneCenter(c.lane), c.y), c.color);
    }

    // Bike
    _drawBike(canvas);
  }

  void _drawCar(Canvas canvas, Offset center, Color color) {
    final paint = Paint();

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: carW, height: carH),
      Radius.circular(carW * 0.22),
    );

    // Shadow
    paint.color = Colors.black26;
    canvas.drawRRect(body.shift(const Offset(3, 4)), paint);

    // Body
    paint.color = color;
    canvas.drawRRect(body, paint);

    // Roof
    paint.color = Colors.black.withValues(alpha: 0.22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(0, carH * 0.02),
          width: carW * 0.74,
          height: carH * 0.42,
        ),
        Radius.circular(carW * 0.14),
      ),
      paint,
    );

    // Rear lights (the car is seen from above, moving away from the bike)
    paint.color = const Color(0xFFFF1744);
    canvas.drawRect(
      Rect.fromCenter(
        center: center.translate(-carW * 0.3, -carH * 0.46),
        width: carW * 0.2,
        height: carH * 0.05,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: center.translate(carW * 0.3, -carH * 0.46),
        width: carW * 0.2,
        height: carH * 0.05,
      ),
      paint,
    );
  }

  void _drawBike(Canvas canvas) {
    final paint = Paint();

    final cx = bikeX;
    final top = bikeTop;

    // Shadow
    paint.color = Colors.black26;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + 3, top + bikeH / 2 + 4),
        width: bikeW * 0.9,
        height: bikeH * 1.05,
      ),
      paint,
    );

    // Wheels (front at the top, rear at the bottom)
    paint.color = const Color(0xFF212121);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, top + bikeH * 0.14),
          width: bikeW * 0.34,
          height: bikeH * 0.28,
        ),
        Radius.circular(bikeW * 0.12),
      ),
      paint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, top + bikeH * 0.86),
          width: bikeW * 0.4,
          height: bikeH * 0.28,
        ),
        Radius.circular(bikeW * 0.12),
      ),
      paint,
    );

    // Body
    paint.color = const Color(0xFFE53935);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, top + bikeH * 0.5),
          width: bikeW * 0.5,
          height: bikeH * 0.62,
        ),
        Radius.circular(bikeW * 0.2),
      ),
      paint,
    );

    // Handlebar
    paint
      ..color = const Color(0xFFB0BEC5)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(cx - bikeW * 0.5, top + bikeH * 0.28),
      Offset(cx + bikeW * 0.5, top + bikeH * 0.28),
      paint,
    );

    // Rider: shoulders + helmet
    paint.color = const Color(0xFF1E88E5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, top + bikeH * 0.5),
        width: bikeW * 0.78,
        height: bikeH * 0.3,
      ),
      paint,
    );

    paint.color = const Color(0xFFFFA000);
    canvas.drawCircle(Offset(cx, top + bikeH * 0.6), bikeW * 0.2, paint);

    // Head light
    paint.color = const Color(0xFFFFF59D);
    canvas.drawCircle(Offset(cx, top + bikeH * 0.02), bikeW * 0.08, paint);
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) => true;
}
