import 'dart:math' as math;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'bike_game_painter.dart';
import 'login_page.dart';

// ===================================================================
// PLAY & EARN: BIKE RIDER  (premium version)
// Ride the motorbike, dodge cars / trucks / buses, grab coins,
// pick up SHIELD and MAGNET power-ups, ride through day and night.
// Tap left / right (or swipe) to change lane. Hold BOOST to go faster.
//
// Points are still decided by the SERVER (functions/games.js):
//   startBikeGame  -> starts a run
//   finishBikeGame -> checks the score and adds the points
// Score speed stays inside the server's anti-cheat limit.
// ===================================================================

enum _Phase { loading, ready, countdown, running, crashing, over }

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

class BikeGamePage extends StatefulWidget {
  const BikeGamePage({super.key});

  @override
  State<BikeGamePage> createState() => _BikeGamePageState();
}

class _BikeGamePageState extends State<BikeGamePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final math.Random _rng = math.Random();
  final BikeScene _scene = BikeScene();

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  _Phase _phase = _Phase.loading;
  String? _error;
  bool _paused = false;

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
  int _best = 0;
  bool _newBest = false;

  // Game state
  Size _size = Size.zero;

  int _lane = 1;
  double _bikeX = 0;
  double _score = 0;
  double _playTime = 0;
  double _spawnDist = 0;
  int _coinsTaken = 0;
  double _count = 3;
  double _crashT = 0;
  double _crashSpeed = 0;
  double _exhaustAcc = 0;
  double _nextPickupAt = 4500;

  double _shieldT = 0;
  double _magnetT = 0;
  double _invT = 0;

  // BOOST
  bool _boostHeld = false;
  bool _boosting = false;
  bool _boostLocked = false;
  double _boostEnergy = 1.0;
  double _boostMul = 1.0;
  double _speed = 0;

  static const List<Color> _carColors = [
    Color(0xFF42A5F5),
    Color(0xFF66BB6A),
    Color(0xFFAB47BC),
    Color(0xFFEC407A),
    Color(0xFFECEFF1),
    Color(0xFFFF7043),
  ];

  // ---------------------------------------------------------
  // GEOMETRY
  // ---------------------------------------------------------

  void _layout(Size size) {
    _size = size;

    final w = math.min(size.width * 0.80, 400.0);

    _scene.roadW = w;
    _scene.roadLeft = (size.width - w) / 2;
    _scene.laneW = w / 3;

    _scene.bikeW = _scene.laneW * 0.5;
    _scene.bikeH = _scene.laneW * 1.03;
    _scene.bikeTop = size.height - _scene.bikeH - size.height * 0.12;

    _scene.carW = _scene.laneW * 0.62;
    _scene.carH = _scene.laneW * 1.15;
    _scene.coinR = _scene.laneW * 0.16;
  }

  Rect get _boostRect => Rect.fromLTWH(
        _size.width - 16 - 76 - 10,
        _size.height - 20 - 76 - 10,
        96,
        96,
      );

  Rect get _pauseRect => Rect.fromLTWH(_size.width - 70, 0, 70, 66);

  // ---------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _ticker = createTicker(_onTick)..start();

    _loadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        (_phase == _Phase.running || _phase == _Phase.countdown)) {
      setState(() => _paused = true);
    }
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
        _error = _gameErrorText(e);
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
        _phase = _Phase.countdown;
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

    _sessionId = null;

    if (mounted) setState(() => _saving = true);

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
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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
    _scene.vehicles.clear();
    _scene.coins.clear();
    _scene.pickups.clear();
    _scene.particles.clear();
    _scene.floats.clear();

    _lane = 1;
    _bikeX = _scene.laneCenter(1);
    _scene.bikeX = _bikeX;
    _scene.bikeVisible = true;
    _scene.shake = Offset.zero;
    _scene.night = 0;

    _score = 0;
    _playTime = 0;
    _spawnDist = 0;
    _coinsTaken = 0;
    _count = 3.0;
    _crashT = 0;
    _nextPickupAt = _scene.worldDist + 4500;

    _shieldT = 0;
    _magnetT = 0;
    _invT = 0;

    _boostHeld = false;
    _boosting = false;
    _boostLocked = false;
    _boostEnergy = 1.0;
    _boostMul = 1.0;
    _speed = 0;

    _earned = 0;
    _resultNote = '';
    _newBest = false;
    _paused = false;
  }

  void _onTick(Duration elapsed) {
    final raw = ((elapsed - _last).inMicroseconds / 1000000.0)
        .clamp(0.0, 0.05)
        .toDouble();

    _last = elapsed;

    if (_size == Size.zero || _paused) return;

    _scene.clock += raw;

    switch (_phase) {
      case _Phase.running:
        _stepRun(raw);
        break;
      case _Phase.countdown:
        _stepCountdown(raw);
        break;
      case _Phase.crashing:
        _stepCrash(raw);
        break;
      case _Phase.over:
        _stepParticles(raw, 0);
        if (_scene.particles.isEmpty && _scene.floats.isEmpty) return;
        break;
      default:
        _scene.worldDist += 70 * raw;
        _bikeX = _scene.laneCenter(1);
        _scene.bikeX = _bikeX;
        _scene.lean = 0;
        _scene.boosting = false;
        break;
    }

    if (mounted) setState(() {});
  }

  void _stepCountdown(double dt) {
    _count -= dt;

    final move = (60 + 160 * (1 - (_count / 3).clamp(0.0, 1.0))) * dt;

    _scene.worldDist += move;
    _scene.bikeX = _bikeX;
    _scene.lean = 0;

    _exhaust(dt, move);
    _stepParticles(dt, move);

    if (_count <= 0) {
      HapticFeedback.mediumImpact();
      _phase = _Phase.running;
    }
  }

  void _stepRun(double dt) {
    _playTime += dt;

    // Speed grows slowly: 260 -> 720 pixels per second.
    final baseSpeed = 260.0 + math.min(460.0, _playTime * 9.0);

    // BOOST: up to 45% faster while the bar lasts.
    if (_boostEnergy <= 0.02) _boostLocked = true;
    if (_boostEnergy >= 0.25) _boostLocked = false;

    _boosting = _boostHeld && !_boostLocked && _boostEnergy > 0.02;

    if (_boosting) {
      _boostEnergy = math.max(0.0, _boostEnergy - dt * 0.4);
    } else {
      _boostEnergy = math.min(1.0, _boostEnergy + dt * 0.12);
    }

    _boostMul +=
        ((_boosting ? 1.45 : 1.0) - _boostMul) * math.min(1.0, dt * 4.0);

    final speed = baseSpeed * _boostMul;

    _speed = speed;

    final move = speed * dt;

    _scene.worldDist += move;

    // Distance score (about 10 -> 27 per second).
    _score += dt * speed / 27.0;

    // Day / night cycle (100 seconds).
    _scene.night = 0.5 - 0.5 * math.cos(2 * math.pi * _playTime / 100.0);
    _scene.speedFx = ((speed - 330.0) / 650.0).clamp(0.0, 1.0).toDouble();

    // Bike slides smoothly to its lane.
    _bikeX += (_scene.laneCenter(_lane) - _bikeX) * math.min(1.0, dt * 14.0);

    _scene.bikeX = _bikeX;
    _scene.lean = ((_scene.laneCenter(_lane) - _bikeX) / _scene.laneW * 0.45)
        .clamp(-0.35, 0.35)
        .toDouble();
    _scene.boosting = _boosting;

    // Power-up timers.
    if (_shieldT > 0) _shieldT = math.max(0.0, _shieldT - dt);
    if (_magnetT > 0) _magnetT = math.max(0.0, _magnetT - dt);
    if (_invT > 0) _invT = math.max(0.0, _invT - dt);

    _scene.shield =
        _shieldT > 0 && (_shieldT > 3 || (_shieldT * 6).floor() % 2 == 0);
    _scene.magnet = _magnetT > 0;
    _scene.bikeVisible = _invT <= 0 || (_invT * 14).floor() % 2 == 0;

    // New traffic.
    _spawnDist += move;

    final gap = math.max(250.0, 430.0 - _playTime * 3.0);

    if (_spawnDist >= gap) {
      _spawnDist = 0;
      _spawnTraffic(gap);
    }

    for (final v in _scene.vehicles) {
      v.y += move;
    }
    for (final c in _scene.coins) {
      c.y += move;
    }
    for (final p in _scene.pickups) {
      p.y += move;
    }

    final h = _size.height;

    _scene.vehicles.removeWhere((v) => v.y > h + _scene.carH * v.len);
    _scene.coins.removeWhere((c) => c.y > h + _scene.coinR * 3);
    _scene.pickups.removeWhere((p) => p.y > h + _scene.coinR * 4);

    // Magnet pulls coins to the bike.
    if (_magnetT > 0) {
      final by = _scene.bikeTop + _scene.bikeH * 0.4;

      for (final c in _scene.coins) {
        final dx = _bikeX - c.x;
        final dy = by - c.y;

        if (math.sqrt(dx * dx + dy * dy) < _scene.laneW * 3.3) {
          c.x += dx * math.min(1.0, dt * 9.0);
          c.y += dy * math.min(1.0, dt * 5.0);
        }
      }
    }

    if (_collide()) return;

    _exhaust(dt, move);
    _stepParticles(dt, move);
  }

  void _stepCrash(double dt) {
    _crashT -= dt;

    _crashSpeed *= math.max(0.0, 1 - dt * 2.4);

    final move = _crashSpeed * dt;

    _scene.worldDist += move;

    for (final v in _scene.vehicles) {
      v.y += move;
    }
    for (final c in _scene.coins) {
      c.y += move;
    }

    final amp = 14.0 * (_crashT / 1.0).clamp(0.0, 1.0);

    _scene.shake = Offset(
      (_rng.nextDouble() - 0.5) * 2 * amp,
      (_rng.nextDouble() - 0.5) * 2 * amp,
    );

    _stepParticles(dt, move);

    if (_crashT <= 0) {
      _scene.shake = Offset.zero;
      _phase = _Phase.over;
    }
  }

  // ---------------------------------------------------------
  // TRAFFIC
  // ---------------------------------------------------------

  VehicleKind _pickKind() {
    final r = _rng.nextDouble();

    if (_playTime > 12 && r < 0.10) return VehicleKind.truck;
    if (_playTime > 30 && r < 0.16) return VehicleKind.bus;
    if (r < 0.32) return VehicleKind.sports;
    if (r < 0.50) return VehicleKind.taxi;

    return VehicleKind.sedan;
  }

  Vehicle _makeVehicle(int lane, VehicleKind kind) {
    final color = _carColors[_rng.nextInt(_carColors.length)];

    switch (kind) {
      case VehicleKind.truck:
        return Vehicle(lane, -_scene.carH * 1.75, kind,
            const Color(0xFFE53935), 1.75, 1.06);
      case VehicleKind.bus:
        return Vehicle(lane, -_scene.carH * 2.1, kind,
            const Color(0xFF1E88E5), 2.1, 1.1);
      case VehicleKind.taxi:
        return Vehicle(lane, -_scene.carH, kind, const Color(0xFFFFC107), 1.0, 1.0);
      case VehicleKind.sports:
        return Vehicle(lane, -_scene.carH, kind, color, 0.95, 0.95);
      case VehicleKind.sedan:
        return Vehicle(lane, -_scene.carH, kind, color, 1.0, 1.0);
    }
  }

  void _spawnTraffic(double gap) {
    final lane = _rng.nextInt(3);
    final used = <int>{lane};

    final kind = _pickKind();
    final first = _makeVehicle(lane, kind);

    _scene.vehicles.add(first);

    final isLong = kind == VehicleKind.truck || kind == VehicleKind.bus;

    // Later in the run two cars can come together, but one lane stays free.
    if (!isLong && _playTime > 15 && _rng.nextDouble() < 0.35) {
      final second = (lane + 1 + _rng.nextInt(2)) % 3;

      used.add(second);

      _scene.vehicles.add(_makeVehicle(
        second,
        _rng.nextBool() ? VehicleKind.sedan : VehicleKind.sports,
      ));
    }

    final free = [0, 1, 2].where((l) => !used.contains(l)).toList();
    final baseY = -_scene.carH * first.len - gap / 2;

    // A short line of coins in a free lane.
    if (_rng.nextDouble() < 0.32) {
      final coinLane = free[_rng.nextInt(free.length)];
      final count = 2 + _rng.nextInt(2);

      for (var i = 0; i < count; i++) {
        _scene.coins.add(Coin(
          _scene.laneCenter(coinLane),
          baseY - i * _scene.coinR * 4.2,
        ));
      }
    }

    // Power-up now and then.
    if (_scene.worldDist >= _nextPickupAt) {
      final pl = free[_rng.nextInt(free.length)];

      _scene.pickups.add(Pickup(
        pl,
        baseY - _scene.carH * 1.5,
        _rng.nextBool() ? PickupKind.shield : PickupKind.magnet,
      ));

      _nextPickupAt = _scene.worldDist + 6000 + _rng.nextDouble() * 5000;
    }

    // Long vehicles need more room before the next spawn.
    _spawnDist = -(first.len - 1) * _scene.carH;
  }

  // ---------------------------------------------------------
  // COLLISIONS
  // ---------------------------------------------------------

  bool _collide() {
    final bikeRect = Rect.fromCenter(
      center: Offset(_bikeX, _scene.bikeTop + _scene.bikeH / 2),
      width: _scene.bikeW * 0.78,
      height: _scene.bikeH * 0.85,
    );

    if (_invT <= 0) {
      for (final v in List<Vehicle>.of(_scene.vehicles)) {
        final rect = Rect.fromCenter(
          center: Offset(_scene.laneCenter(v.lane), v.y),
          width: _scene.carW * v.wf * 0.88,
          height: _scene.carH * v.len * 0.92,
        );

        if (!bikeRect.overlaps(rect)) continue;

        if (_shieldT > 0) {
          // Shield absorbs the hit and blasts the vehicle away.
          _shieldT = 0;
          _invT = 1.3;
          _scene.shield = false;
          _scene.vehicles.remove(v);

          _burst(_scene.laneCenter(v.lane), v.y,
              n: 26,
              colors: const [Color(0xFF81D4FA), Colors.white, Color(0xFFFFC107)],
              speed: 360,
              life: 0.7,
              size: 3.5);

          _scene.floats.add(FloatText(_bikeX, _scene.bikeTop - 20,
              'SHIELD!', const Color(0xFF81D4FA)));

          HapticFeedback.heavyImpact();
        } else {
          _crash();
          return true;
        }
      }
    }

    _scene.coins.removeWhere((coin) {
      final r = Rect.fromCircle(
        center: Offset(coin.x, coin.y),
        radius: _scene.coinR,
      );

      if (!bikeRect.overlaps(r)) return false;

      _score += 5;
      _coinsTaken++;

      _burst(coin.x, coin.y,
          n: 7,
          colors: const [Color(0xFFFFD54F), Color(0xFFFFF59D), Colors.white],
          speed: 150,
          life: 0.4,
          size: 2.4,
          scroll: 0.8);

      _scene.floats.add(FloatText(coin.x, coin.y - 12, '+5', const Color(0xFFFFD54F)));

      HapticFeedback.selectionClick();

      return true;
    });

    _scene.pickups.removeWhere((pk) {
      final r = Rect.fromCircle(
        center: Offset(_scene.laneCenter(pk.lane), pk.y),
        radius: _scene.coinR * 1.9,
      );

      if (!bikeRect.overlaps(r)) return false;

      final isShield = pk.kind == PickupKind.shield;

      if (isShield) {
        _shieldT = 15;
      } else {
        _magnetT = 8;
      }

      _burst(_scene.laneCenter(pk.lane), pk.y,
          n: 16,
          colors: isShield
              ? const [Color(0xFF29B6F6), Colors.white]
              : const [Color(0xFFEF5350), Colors.white],
          speed: 240,
          life: 0.5,
          size: 3);

      _scene.floats.add(FloatText(
        _bikeX,
        _scene.bikeTop - 20,
        isShield ? 'SHIELD' : 'MAGNET',
        isShield ? const Color(0xFF81D4FA) : const Color(0xFFFF8A80),
      ));

      HapticFeedback.mediumImpact();

      return true;
    });

    return false;
  }

  void _crash() {
    HapticFeedback.heavyImpact();

    _boostHeld = false;
    _boosting = false;
    _scene.boosting = false;
    _scene.shield = false;
    _scene.bikeVisible = false;

    final by = _scene.bikeTop + _scene.bikeH * 0.5;

    _burst(_bikeX, by,
        n: 46,
        colors: const [
          Color(0xFFFF6D00),
          Color(0xFFFFC107),
          Color(0xFFFF1744),
          Color(0xFFFFF59D),
        ],
        speed: 460,
        life: 0.9,
        size: 4.5,
        scroll: 0.3);

    _burst(_bikeX, by,
        n: 22,
        colors: const [Color(0x99455A64), Color(0x99607D8B)],
        speed: 150,
        life: 1.4,
        size: 7,
        glow: false,
        grow: 12,
        scroll: 0.3);

    _burst(_bikeX, by,
        n: 12,
        colors: const [Color(0xFFD32F2F), Color(0xFF212121), Color(0xFFB0BEC5)],
        speed: 380,
        life: 1.0,
        size: 3,
        glow: false,
        gravity: 500,
        scroll: 0.3);

    _crashSpeed = _speed;
    _crashT = 1.0;
    _phase = _Phase.crashing;

    _registerBest();
    _finish();
  }

  void _registerBest() {
    final s = _score.floor();

    if (s > _best) {
      _best = s;
      _newBest = s > 0;
    }
  }

  /// Player ends the ride from the pause menu (score is still saved).
  void _endRide() {
    _paused = false;
    _boostHeld = false;
    _boosting = false;
    _scene.boosting = false;
    _scene.shake = Offset.zero;

    _registerBest();

    setState(() => _phase = _Phase.over);

    _finish();
  }

  // ---------------------------------------------------------
  // PARTICLES
  // ---------------------------------------------------------

  void _burst(
    double x,
    double y, {
    required int n,
    required List<Color> colors,
    double speed = 200,
    double life = 0.6,
    double size = 3,
    bool glow = true,
    double scroll = 0.5,
    double grow = 0,
    double gravity = 0,
  }) {
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      final sp = speed * (0.3 + _rng.nextDouble() * 0.7);

      _scene.particles.add(Particle(
        x,
        y,
        math.cos(a) * sp,
        math.sin(a) * sp,
        life * (0.6 + _rng.nextDouble() * 0.4),
        size * (0.6 + _rng.nextDouble() * 0.8),
        colors[_rng.nextInt(colors.length)],
        glow: glow,
        grow: grow,
        gravity: gravity,
        scroll: scroll,
      ));
    }

    if (_scene.particles.length > 420) {
      _scene.particles.removeRange(0, _scene.particles.length - 420);
    }
  }

  void _exhaust(double dt, double move) {
    _exhaustAcc += dt;

    if (_exhaustAcc < 0.035) return;

    _exhaustAcc = 0;

    final x = _bikeX + (_rng.nextDouble() - 0.5) * _scene.bikeW * 0.3;
    final y = _scene.bikeTop + _scene.bikeH * 1.0;

    if (_boosting) {
      _scene.particles.add(Particle(
        x,
        y + 6,
        (_rng.nextDouble() - 0.5) * 60,
        120 + _rng.nextDouble() * 180,
        0.35,
        2.5 + _rng.nextDouble() * 2,
        _rng.nextBool() ? const Color(0xFFFF6D00) : const Color(0xFFFFEB3B),
        scroll: 0.2,
      ));
    } else {
      _scene.particles.add(Particle(
        x,
        y,
        (_rng.nextDouble() - 0.5) * 24,
        30 + _rng.nextDouble() * 30,
        0.5,
        2.5,
        const Color(0x55E0E0E0),
        glow: false,
        grow: 7,
        scroll: 0.6,
      ));
    }
  }

  void _stepParticles(double dt, double move) {
    for (final p in _scene.particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt + move * p.scroll;
      p.vy += p.gravity * dt;
      p.size += p.grow * dt;
      p.life -= dt;
    }

    _scene.particles.removeWhere((p) => p.life <= 0);

    for (final f in _scene.floats) {
      f.y -= 46 * dt;
      f.life -= dt;
    }

    _scene.floats.removeWhere((f) => f.life <= 0);
  }

  // ---------------------------------------------------------
  // CONTROLS
  // ---------------------------------------------------------

  void _moveLane(int direction) {
    if (_phase != _Phase.running && _phase != _Phase.countdown) return;
    if (_paused) return;

    final next = (_lane + direction).clamp(0, 2).toInt();

    if (next != _lane) {
      HapticFeedback.selectionClick();
      _lane = next;
    }
  }

  // ---------------------------------------------------------
  // UI
  // ---------------------------------------------------------

  bool get _playing =>
      _phase == _Phase.running ||
      _phase == _Phase.countdown ||
      _phase == _Phase.crashing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E7D32),
      appBar: AppBar(
        title: const Text(
          'Bike Rider',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _layout(Size(constraints.maxWidth, constraints.maxHeight));

          if (_phase != _Phase.running &&
              _phase != _Phase.crashing &&
              _phase != _Phase.over &&
              _phase != _Phase.countdown) {
            _bikeX = _scene.laneCenter(1);
            _scene.bikeX = _bikeX;
          }


          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              if (_playing &&
                  (_boostRect.contains(details.localPosition) ||
                      _pauseRect.contains(details.localPosition))) {
                return;
              }

              _moveLane(details.localPosition.dx < _size.width / 2 ? -1 : 1);
            },
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;

              if (v.abs() > 200) _moveLane(v < 0 ? -1 : 1);
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: BikePainter(_scene)),

                if (_playing) _buildHud(),
                if (_phase == _Phase.running) _buildBoostButton(),
                if (_phase == _Phase.running || _phase == _Phase.countdown)
                  _buildPauseButton(),

                if (_phase == _Phase.countdown) _buildCountdown(),
                if (_phase == _Phase.running && _playTime < 0.7) _buildGo(),

                if (_phase == _Phase.loading)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),

                if (_phase == _Phase.ready) _buildReadyCard(),
                if (_phase == _Phase.over) _buildOverCard(),
                if (_paused && _playing) _buildPauseCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---- HUD ----

  Widget _buildHud() {
    final kmh = (_speed / 4.0).round();
    final fraction = (_speed / 1050.0).clamp(0.0, 1.0).toDouble();

    final barColor = fraction < 0.45
        ? Colors.greenAccent
        : fraction < 0.75
            ? Colors.amber
            : Colors.redAccent;

    return Positioned(
      top: 10,
      left: 12,
      right: 12,
      child: IgnorePointer(
        child: Column(
          children: [
            Row(
              children: [
                _hudChip(Icons.flag_rounded, '${_score.floor()}'),
                const SizedBox(width: 8),
                if (_best > 0)
                  _hudChip(Icons.emoji_events, '$_best',
                      color: const Color(0xFFFFD54F), small: true),
                const Spacer(),
                _hudChip(Icons.monetization_on, '$_coinsTaken',
                    color: Colors.amber),
                const SizedBox(width: 50),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    _boosting ? Icons.bolt : Icons.speed,
                    color: _boosting ? Colors.orangeAccent : Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 9,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '$kmh km/h',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_shieldT > 0)
                  _powerChip('🛡️', _shieldT, 15, const Color(0xFF29B6F6)),
                if (_shieldT > 0 && _magnetT > 0) const SizedBox(width: 8),
                if (_magnetT > 0)
                  _powerChip('🧲', _magnetT, 8, const Color(0xFFEF5350)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _powerChip(String emoji, double left, double total, Color color) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          SizedBox(
            width: 44,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (left / total).clamp(0.0, 1.0).toDouble(),
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hudChip(IconData icon, String text,
      {Color color = Colors.white, bool small = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 9 : 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: small ? 15 : 18),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: small ? 13 : 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPauseButton() {
    return Positioned(
      top: 8,
      right: 10,
      child: GestureDetector(
        onTap: () => setState(() => _paused = true),
        child: Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.pause_rounded, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildBoostButton() {
    final active = _boosting;

    return Positioned(
      right: 16,
      bottom: 20,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _boostHeld = true,
        onPointerUp: (_) => _boostHeld = false,
        onPointerCancel: (_) => _boostHeld = false,
        child: SizedBox(
          width: 76,
          height: 76,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? const Color(0xFFFF6D00) : Colors.black54,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF6D00).withValues(alpha: 0.7),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
              SizedBox(
                width: 66,
                height: 66,
                child: CircularProgressIndicator(
                  value: _boostEnergy,
                  strokeWidth: 5,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _boostLocked ? Colors.redAccent : Colors.lightBlueAccent,
                  ),
                ),
              ),
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, color: Colors.white, size: 26),
                  Text(
                    'BOOST',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Countdown / GO ----

  Widget _bigText(String text, Color color) {
    return Center(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(text),
          tween: Tween(begin: 1.8, end: 1.0),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          builder: (context, v, child) =>
              Transform.scale(scale: v, child: child),
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 96,
              fontWeight: FontWeight.w900,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 14)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdown() =>
      _bigText('${_count.ceil().clamp(1, 3)}', Colors.white);

  Widget _buildGo() => _bigText('GO!', const Color(0xFF69F0AE));

  // ---- Cards ----

  Widget _card({required List<Widget> children}) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1F2540), Color(0xFF101428)],
            ),
            border: Border.all(color: Colors.white12, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }

  Widget _gradButton(String label, VoidCallback? onTap, {IconData? icon}) {
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [Color(0xFFFF5252), Color(0xFFFF9800)],
              ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF5252).withValues(alpha: 0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
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

  Widget _tip(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyCard() {
    final needsLogin = FirebaseAuth.instance.currentUser == null;
    final canPlay = _enabled && _playsLeft > 0 && _error == null;

    return _card(
      children: [
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            colors: [Color(0xFFFF8A80), Color(0xFFFFD180)],
          ).createShader(r),
          child: const Text(
            'BIKE RIDER',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ride day & night. Dodge traffic. Earn points.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, fontSize: 12.5),
        ),
        const SizedBox(height: 14),
        if (_error != null) ...[
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _gradButton(
              needsLogin ? 'Sign In' : 'Try again',
              needsLogin
                  ? _signIn
                  : () {
                      setState(() => _phase = _Phase.loading);
                      _loadStatus();
                    },
            ),
          ),
        ] else ...[
          _tip('👆', 'Tap left / right side (or swipe) to change lane'),
          _tip('⚡', 'Hold BOOST for speed - the ring shows your energy'),
          _tip('🛡️', 'Shield saves you from one crash'),
          _tip('🧲', 'Magnet pulls coins to your bike'),
          const SizedBox(height: 10),
          Text(
            'Every $_scorePerPoint score = 1 point (max $_maxPointsPerRun per ride)',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            'Plays left today: $_playsLeft / $_playsPerDay',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Game points today: $_pointsToday / $_maxPointsPerDay',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _gradButton(
              !_enabled
                  ? 'GAME PAUSED'
                  : _playsLeft <= 0
                      ? 'NO PLAYS LEFT TODAY'
                      : _starting
                          ? 'STARTING...'
                          : 'START RIDE',
              canPlay && !_starting ? _start : null,
              icon: Icons.two_wheeler,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPauseCard() {
    return Container(
      color: Colors.black54,
      child: _card(
        children: [
          const Icon(Icons.pause_circle_filled_rounded,
              color: Colors.white, size: 48),
          const SizedBox(height: 6),
          const Text(
            'PAUSED',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: _gradButton(
              'RESUME',
              () => setState(() => _paused = false),
              icon: Icons.play_arrow_rounded,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _phase == _Phase.running ? _endRide : null,
            child: const Text(
              'End ride & collect points',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
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

  Widget _stat(String label, String value, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverCard() {
    final note = _noteText();
    final finalScore = _score.floor();

    return _card(
      children: [
        Text(
          _newBest ? '🏆 NEW BEST!' : 'CRASH! 💥',
          style: TextStyle(
            color: _newBest ? const Color(0xFFFFD54F) : Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 14),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: finalScore.toDouble()),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOut,
          builder: (context, v, _) => Text(
            '${v.floor()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 54,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ),
        const Text(
          'SCORE',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
            letterSpacing: 2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _stat('Coins', '$_coinsTaken', color: Colors.amber),
            const SizedBox(width: 10),
            _stat('Best', '$_best', color: const Color(0xFFFFD54F)),
          ],
        ),
        const SizedBox(height: 14),
        if (_saving)
          const Padding(
            padding: EdgeInsets.all(10),
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
          )
        else ...[
          ShaderMask(
            shaderCallback: (r) => LinearGradient(
              colors: _earned > 0
                  ? const [Color(0xFFFFF59D), Color(0xFFFFA000)]
                  : const [Colors.grey, Colors.grey],
            ).createShader(r),
            child: Text(
              _earned > 0 ? '+$_earned points' : '0 points',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              note,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Plays left today: $_playsLeft / $_playsPerDay',
            style: const TextStyle(color: Colors.white54, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _gradButton(
                  'PLAY AGAIN',
                  _playsLeft > 0 && !_starting ? _start : null,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
