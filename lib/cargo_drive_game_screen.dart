import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'game_service.dart';

class CargoDriveGameScreen extends StatefulWidget {
  const CargoDriveGameScreen({super.key});

  @override
  State<CargoDriveGameScreen> createState() =>
      _CargoDriveGameScreenState();
}

class _CargoDriveGameScreenState
    extends State<CargoDriveGameScreen> {
  final GameService _gameService = GameService();
  final Random _random = Random();

  Timer? _gameLoopTimer;

  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isEnding = false;
  bool _gameEnabled = true;
  bool _pendingFinish = false;

  String? _sessionId;

  int _score = 0;
  int _playsLeft = 0;
  int _pointsToday = 0;
  int _scorePerPoint = 100;
  int _maxPointsPerRun = 10;
  int _maxPointsPerDay = 30;

  // তিনটি লেন: 0, 1, 2
  int _bikeLane = 1;
  int _obstacleLane = 1;

  double _obstacleX = 400;
  double _gameWidth = 400;

  int get _speed {
    return min(12, 5 + (_score ~/ 300));
  }

  @override
  void initState() {
    super.initState();
    _fetchGameStatus();
  }

  // -------------------------------------------------
  // LOAD SERVER STATUS
  // -------------------------------------------------

  Future<void> _fetchGameStatus() async {
    try {
      final status = await _gameService.getGameStatus();

      if (!mounted) return;

      setState(() {
        _gameEnabled = status['enabled'] == true;

        _playsLeft =
            (status['playsLeft'] as num?)?.toInt() ?? 0;

        _pointsToday =
            (status['pointsToday'] as num?)?.toInt() ?? 0;

        _scorePerPoint =
            (status['scorePerPoint'] as num?)?.toInt() ?? 100;

        _maxPointsPerRun =
            (status['maxPointsPerRun'] as num?)?.toInt() ?? 10;

        _maxPointsPerDay =
            (status['maxPointsPerDay'] as num?)?.toInt() ?? 30;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      _showSnack('গেম স্ট্যাটাস লোড হয়নি: $e');
    }
  }

  // -------------------------------------------------
  // START GAME SESSION
  // -------------------------------------------------

  Future<void> _startGameSession() async {
    if (_isLoading ||
        _isPlaying ||
        _isEnding ||
        !_gameEnabled ||
        _playsLeft <= 0) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _gameService.startBikeGame();

      if (!mounted) return;

      final sessionId = result['sessionId'] as String?;

      if (sessionId == null || sessionId.isEmpty) {
        throw Exception('Invalid game session ID');
      }

      setState(() {
        _sessionId = sessionId;

        _playsLeft =
            (result['playsLeft'] as num?)?.toInt() ?? 0;

        _score = 0;
        _bikeLane = 1;
        _obstacleLane = _random.nextInt(3);

        _obstacleX = _gameWidth + 50;

        _isPlaying = true;
        _isLoading = false;
        _pendingFinish = false;
      });

      _startGameLoop();
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      _showSnack('গেম শুরু করা যায়নি: $e');
    }
  }

  // -------------------------------------------------
  // GAME LOOP
  // -------------------------------------------------

  void _startGameLoop() {
    _gameLoopTimer?.cancel();

    _gameLoopTimer = Timer.periodic(
      const Duration(milliseconds: 30),
      (timer) {
        if (!mounted || !_isPlaying || _isEnding) {
          timer.cancel();
          return;
        }

        double nextX = _obstacleX - _speed;

        int nextLane = _obstacleLane;

        if (nextX < -60) {
          nextX = _gameWidth + 50;
          nextLane = _random.nextInt(3);
        }

        final collision = _checkCollision(
          nextX,
          nextLane,
        );

        setState(() {
          _score += 1;
          _obstacleX = nextX;
          _obstacleLane = nextLane;
        });

        if (collision) {
          _endGameSession();
        }
      },
    );
  }

  // -------------------------------------------------
  // COLLISION DETECTION
  // -------------------------------------------------

  bool _checkCollision(double obstacleX, int obstacleLane) {
    const bikeLeft = 75.0;
    const bikeWidth = 55.0;
    const obstacleWidth = 45.0;

    final horizontalCollision =
        obstacleX < bikeLeft + bikeWidth &&
        obstacleX + obstacleWidth > bikeLeft;

    final verticalCollision = _bikeLane == obstacleLane;

    return horizontalCollision && verticalCollision;
  }

  // -------------------------------------------------
  // BIKE CONTROL
  // -------------------------------------------------

  void _moveBike(bool up) {
    if (!_isPlaying || _isEnding) return;

    setState(() {
      if (up) {
        _bikeLane = max(0, _bikeLane - 1);
      } else {
        _bikeLane = min(2, _bikeLane + 1);
      }
    });
  }

  // -------------------------------------------------
  // END GAME
  // -------------------------------------------------

  Future<void> _endGameSession() async {
    if (_isEnding || !_isPlaying) return;

    _gameLoopTimer?.cancel();

    setState(() {
      _isEnding = true;
      _isPlaying = false;
      _isLoading = true;
      _pendingFinish = false;
    });

    await _submitGameScore();
  }

  // -------------------------------------------------
  // SUBMIT SCORE TO FIREBASE
  // -------------------------------------------------

  Future<void> _submitGameScore() async {
    if (_sessionId == null) return;

    try {
      final result = await _gameService.finishBikeGame(
        _sessionId!,
        _score,
      );

      if (!mounted) return;

      final points =
          (result['points'] as num?)?.toInt() ?? 0;

      final note = result['note']?.toString() ?? 'ok';

      setState(() {
        _playsLeft =
            (result['playsLeft'] as num?)?.toInt() ??
                _playsLeft;

        _pointsToday =
            (result['pointsToday'] as num?)?.toInt() ??
                _pointsToday;

        _sessionId = null;
        _pendingFinish = false;
        _isEnding = false;
        _isLoading = false;
      });

      if (points > 0) {
        _showResultDialog(points, note);
      } else {
        _showResultDialog(0, note);
      }

      // Refresh latest server settings
      await _fetchGameStatus();
    } catch (e) {
      if (!mounted) return;

      // Keep session ID so user can retry submission.
      setState(() {
        _isEnding = false;
        _isLoading = false;
        _isPlaying = false;
        _pendingFinish = true;
      });

      _showSnack(
        'স্কোর জমা হয়নি। ইন্টারনেট পরীক্ষা করে আবার চেষ্টা করো।',
      );
    }
  }

  // -------------------------------------------------
  // RESULT DIALOG
  // -------------------------------------------------

  void _showResultDialog(int points, String note) {
    String message;

    switch (note) {
      case 'too_fast':
        message = 'খুব দ্রুত গেম শেষ হয়েছে। পয়েন্ট পাওয়া যায়নি।';
        break;

      case 'rejected':
        message = 'স্কোর সার্ভার যাচাইয়ে গ্রহণ করা হয়নি।';
        break;

      case 'expired':
        message = 'গেম সেশনের সময় শেষ হয়েছে।';
        break;

      case 'daily_cap':
        message = 'আজকের পয়েন্ট সীমা পূর্ণ হয়েছে।';
        break;

      default:
        message = points > 0
            ? 'অভিনন্দন! তুমি $points পয়েন্ট পেয়েছো।'
            : 'এই ম্যাচে কোনো পয়েন্ট পাওয়া যায়নি।';
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.orange),
            SizedBox(width: 10),
            Text('ডেলিভারি সম্পন্ন!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'তোমার স্কোর',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              '$_score',
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'আজকের গেম পয়েন্ট: $_pointsToday / $_maxPointsPerDay',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ঠিক আছে'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------
  // SNACKBAR
  // -------------------------------------------------

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // -------------------------------------------------
  // LANE POSITION
  // -------------------------------------------------

  double _laneTop(int lane, double height) {
    final positions = [
      height * 0.20,
      height * 0.43,
      height * 0.66,
    ];

    return positions[lane];
  }

  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------
  // USER INTERFACE
  // -------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),

      appBar: AppBar(
        title: const Text(
          'কার্গো ড্রাইভ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // SCORE HEADER
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      _headerItem(
                        Icons.stars,
                        'স্কোর',
                        '$_score',
                        Colors.white,
                      ),
                      _headerItem(
                        Icons.local_play,
                        'বাকি প্লে',
                        '$_playsLeft',
                        Colors.amber,
                      ),
                      _headerItem(
                        Icons.monetization_on,
                        'আজকের পয়েন্ট',
                        '$_pointsToday',
                        Colors.greenAccent,
                      ),
                    ],
                  ),
                ),

                // GAME AREA
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _gameWidth = constraints.maxWidth;

                      final height = constraints.maxHeight;

                      return GestureDetector(
                        onVerticalDragEnd: (details) {
                          final velocity =
                              details.primaryVelocity ?? 0;

                          if (velocity < -100) {
                            _moveBike(true);
                          } else if (velocity > 100) {
                            _moveBike(false);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF455A64),
                                Color(0xFF17252E),
                                Color(0xFF101820),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              // ROAD LANES
                              for (int i = 1; i <= 2; i++)
                                Positioned(
                                  top: height * (0.32 + (i - 1) * 0.23),
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 2,
                                    color: Colors.white24,
                                  ),
                                ),

                              // ROAD DECORATION
                              Positioned(
                                bottom: 15,
                                left: 0,
                                right: 0,
                                child: Text(
                                  'BUY NOVA • DELIVERY EXPRESS',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ),

                              if (_isPlaying) ...[
                                // PLAYER BIKE
                                AnimatedPositioned(
                                  duration: const Duration(
                                    milliseconds: 120,
                                  ),
                                  curve: Curves.easeOut,
                                  left: 65,
                                  top: _laneTop(
                                    _bikeLane,
                                    height,
                                  ),
                                  child: const Text(
                                    '🏍️📦',
                                    style: TextStyle(fontSize: 43),
                                  ),
                                ),

                                // OBSTACLE
                                Positioned(
                                  left: _obstacleX,
                                  top: _laneTop(
                                    _obstacleLane,
                                    height,
                                  ),
                                  child: const Text(
                                    '🚧',
                                    style: TextStyle(fontSize: 42),
                                  ),
                                ),

                                // GAME INFO
                                Positioned(
                                  top: 15,
                                  right: 15,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'SPEED: $_speed',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ] else if (_pendingFinish) ...[
                                Center(
                                  child: ElevatedButton.icon(
                                    onPressed: _isEnding
                                        ? null
                                        : _submitGameScore,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text(
                                      'স্কোর আবার জমা দাও',
                                    ),
                                  ),
                                ),
                              ] else ...[
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        '🏍️📦',
                                        style: TextStyle(fontSize: 75),
                                      ),
                                      const SizedBox(height: 15),
                                      const Text(
                                        'ডেলিভারি রাইড শুরু করো!',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 20),

                                      if (!_gameEnabled)
                                        const Text(
                                          'গেম বর্তমানে বন্ধ আছে।',
                                          style: TextStyle(
                                            color: Colors.orangeAccent,
                                          ),
                                        )
                                      else
                                        ElevatedButton.icon(
                                          onPressed: _playsLeft > 0
                                              ? _startGameSession
                                              : null,
                                          icon: const Icon(
                                            Icons.play_arrow,
                                          ),
                                          label: const Text(
                                            'গেম শুরু করো',
                                          ),
                                          style:
                                              ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.green,
                                            foregroundColor: Colors.white,
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 28,
                                              vertical: 15,
                                            ),
                                          ),
                                        ),

                                      const SizedBox(height: 12),
                                      Text(
                                        'প্রতি $_scorePerPoint স্কোরে ১ পয়েন্ট',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                      Text(
                                        'প্রতি ম্যাচে সর্বোচ্চ $_maxPointsPerRun পয়েন্ট',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // GAME CONTROLS
                if (_isPlaying)
                  Container(
                    color: Colors.grey.shade900,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 10,
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                        children: [
                          _controlButton(
                            Icons.arrow_upward,
                            'উপরে',
                            () => _moveBike(true),
                          ),
                          _controlButton(
                            Icons.arrow_downward,
                            'নিচে',
                            () => _moveBike(false),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isEnding
                                ? null
                                : _endGameSession,
                            icon: const Icon(Icons.stop),
                            label: const Text('শেষ'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  // HEADER ITEM
  Widget _headerItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ],
    );
  }

  // CONTROL BUTTON
  Widget _controlButton(
    IconData icon,
    String label,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueGrey.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }
}
