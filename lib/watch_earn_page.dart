import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'news_feed_page.dart';

class WatchEarnPage extends StatefulWidget {
  const WatchEarnPage({super.key});

  @override
  State<WatchEarnPage> createState() => _WatchEarnPageState();
}

class _WatchEarnPageState extends State<WatchEarnPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int _dailyLimit = 20;
  static const int _pointsPerVideo = 5;

  bool _converting = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  // Same day key the Cloud Function uses (Bangladesh time, UTC+6).
  String get _todayKey => DateTime.now()
      .toUtc()
      .add(const Duration(hours: 6))
      .toIso8601String()
      .substring(0, 10);

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream() {
    final user = _user;
    if (user == null) return null;
    return _firestore.collection('users').doc(user.uid).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _dailyStream() {
    final user = _user;
    if (user == null) return null;
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('rewardDaily')
        .doc(_todayKey)
        .snapshots();
  }

  Future<void> _convertPoints(
    int availablePoints,
    int pointsPerTaka,
    int minPoints,
  ) async {
    if (_converting) return;

    if (availablePoints < minPoints) {
      _toast('You need at least $minPoints points to convert.');
      return;
    }

    final maxTaka = availablePoints ~/ pointsPerTaka;
    final controller = TextEditingController(text: '$maxTaka');

    final taka = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convert to Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$pointsPerTaka points = ৳1'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount in ৳ (max $maxTaka)',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim()) ?? 0;
              Navigator.pop(ctx, value);
            },
            child: const Text('Convert'),
          ),
        ],
      ),
    );

    if (taka == null) return;

    if (taka < 1 || taka > maxTaka || taka * pointsPerTaka < minPoints) {
      _toast(
        'Enter ৳1 to ৳$maxTaka (minimum $minPoints points).',
      );
      return;
    }

    setState(() => _converting = true);

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      ).httpsCallable('convertPointsToWallet');

      final response = await callable.call({
        'points': taka * pointsPerTaka,
      });

      final data = Map<String, dynamic>.from(response.data as Map);

      _toast('৳${data['taka']} added to your BuyNova Wallet.');
    } on FirebaseFunctionsException catch (e) {
      _toast(e.message ?? 'Conversion failed. Please try again.');
    } catch (_) {
      _toast('Conversion failed. Please try again.');
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openVideos() async {
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to earn points.')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewsFeedPage()),
    );
  }

  String _formatPoints(int points) {
    return points.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Watch & Earn',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _walletCard(),
          const SizedBox(height: 20),
          _convertCard(),
          const SizedBox(height: 20),
          _dailyProgressCard(),
          const SizedBox(height: 20),
          _watchEarnCard(),
          const SizedBox(height: 20),
          _earningHistoryCard(),
        ],
      ),
    );
  }

  Widget _walletCard() {
    final stream = _userStream();

    if (stream == null) {
      return _walletCardView(0, 0);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final points = (data?['pointsBalance'] as num?)?.toInt() ?? 0;
        final lifetime = (data?['lifetimePoints'] as num?)?.toInt() ?? 0;
        return _walletCardView(points, lifetime);
      },
    );
  }

  Widget _walletCardView(int points, int lifetimePoints) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE53935),
            Color(0xFFFF7043),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: 28,
              ),
              SizedBox(width: 10),
              Text(
                'My Rewards',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Available Points',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _formatPoints(points),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Lifetime earned: ${_formatPoints(lifetimePoints)} points',
            style: const TextStyle(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _convertCard() {
    final userStream = _userStream();

    if (userStream == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('platformSettings')
          .doc('monetization')
          .snapshots(),
      builder: (context, configSnap) {
        final config = configSnap.data?.data() ?? {};

        final enabled = config['pointsConversionEnabled'] != false;

        final pointsPerTaka =
            ((config['pointsPerTaka'] as num?)?.toInt() ?? 100)
                .clamp(1, 1000000);

        final minPoints =
            ((config['minPointsToConvert'] as num?)?.toInt() ?? 500)
                .clamp(pointsPerTaka, 100000000);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userStream,
          builder: (context, userSnap) {
            final points =
                (userSnap.data?.data()?['pointsBalance'] as num?)
                        ?.toInt() ??
                    0;

            final worth = points ~/ pointsPerTaka;
            final canConvert = enabled && points >= minPoints;

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.currency_exchange),
                        SizedBox(width: 10),
                        Text(
                          'Convert to Wallet',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$pointsPerTaka points = ৳1  •  Minimum $minPoints points',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your points are worth ৳$worth',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: (canConvert && !_converting)
                            ? () => _convertPoints(
                                  points,
                                  pointsPerTaka,
                                  minPoints,
                                )
                            : null,
                        icon: _converting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.account_balance_wallet),
                        label: Text(
                          enabled
                              ? 'Convert to ৳ Wallet'
                              : 'Conversion paused',
                        ),
                      ),
                    ),
                    if (enabled && points < minPoints)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Earn ${minPoints - points} more points to unlock conversion.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _dailyProgressCard() {
    final stream = _dailyStream();

    if (stream == null) {
      return _dailyProgressView(0);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final count =
            (snapshot.data?.data()?['count'] as num?)?.toInt() ?? 0;
        return _dailyProgressView(count);
      },
    );
  }

  Widget _dailyProgressView(int watchedToday) {
    final shown = watchedToday > _dailyLimit ? _dailyLimit : watchedToday;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.today_outlined),
                SizedBox(width: 10),
                Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            LinearProgressIndicator(
              value: shown / _dailyLimit,
              minHeight: 8,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 10),
            Text(
              '$shown / $_dailyLimit rewarded videos today',
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _watchEarnCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.10),
              ),
              child: const Icon(
                Icons.play_circle_outline,
                size: 42,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Watch & Earn',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Watch BuyNova videos for 10 seconds and earn $_pointsPerVideo points each (up to $_dailyLimit videos a day).',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _openVideos,
                icon: const Icon(Icons.play_arrow),
                label: const Text(
                  'Watch & Earn',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Open a video, keep it playing for 10 seconds, then tap "Claim". Points are added after verification. Your own videos do not earn points.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _earningHistoryCard() {
    final user = _user;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history),
                SizedBox(width: 10),
                Text(
                  'Earning History',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('pointsTransactions')
                  .orderBy('createdAt', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(15),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No earning history yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    child: Text(
                      'No earning history yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();

                    final points =
                        (data['points'] as num?)?.toInt() ?? 0;

                    final type =
                        data['type']?.toString() ?? 'Reward';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Icon(
                          points >= 0
                              ? Icons.add
                              : Icons.remove,
                        ),
                      ),
                      title: Text(type),
                      trailing: Text(
                        '${points >= 0 ? '+' : ''}$points',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: points >= 0
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
