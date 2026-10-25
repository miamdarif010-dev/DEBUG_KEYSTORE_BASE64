import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'login_page.dart';
import 'news_feed_page.dart';

/// Watch & Earn
///
/// Uses only the backend you already have:
///  - users/{uid}                          pointsBalance, lifetimePoints
///  - users/{uid}/rewardDaily/{YYYY-MM-DD} count   (today, streak, week chart)
///  - users/{uid}/pointsTransactions       history
///  - platformSettings/monetization        conversion rate
///  - callable convertPointsToWallet       points -> wallet
class WatchEarnPage extends StatefulWidget {
  const WatchEarnPage({super.key});

  @override
  State<WatchEarnPage> createState() => _WatchEarnPageState();
}

class _WatchEarnPageState extends State<WatchEarnPage> {
  // Set by the Admin (platformSettings/monetization). These are only the
  // defaults used until the settings arrive; _buildContent updates them.
  int _dailyLimit = 20; // dailyVideoLimit
  int _pointsPerVideo = 5; // pointsPerVideo

  static const Color _bg = Color(0xFFF6F6F8);

  static const LinearGradient _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE53935), Color(0xFFFF7043)],
  );

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _converting = false;
  bool _referralBusy = false;

  final TextEditingController _codeController = TextEditingController();

  // Streams are created once, so rebuilds never re-subscribe.
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _configStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _daysStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _historyStream;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();

    _configStream = _firestore
        .collection('platformSettings')
        .doc('monetization')
        .snapshots();

    final user = _user;

    if (user != null) {
      final userRef = _firestore.collection('users').doc(user.uid);

      _userStream = userRef.snapshots();

      // Last 30 days (doc id = YYYY-MM-DD, Bangladesh time).
      _daysStream = userRef
          .collection('rewardDaily')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(30)
          .snapshots();

      _historyStream = userRef
          .collection('pointsTransactions')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // ============================================================
  // DATE HELPERS (Bangladesh time, same as the Cloud Function)
  // ============================================================

  DateTime get _todayBd =>
      DateTime.now().toUtc().add(const Duration(hours: 6));

  String _keyOf(DateTime d) => d.toIso8601String().substring(0, 10);

  int _streak(Map<String, int> counts) {
    var cursor = _todayBd;

    // Today not watched yet: the streak is still alive until midnight.
    if ((counts[_keyOf(cursor)] ?? 0) == 0) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var streak = 0;

    while ((counts[_keyOf(cursor)] ?? 0) > 0) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  String _formatPoints(int points) {
    return points.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }

  String _timeAgo(dynamic value) {
    if (value is! Timestamp) return '';

    final diff = DateTime.now().difference(value.toDate());

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} day ago';

    final d = value.toDate();

    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  void _toast(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _openVideos() async {
    if (_user == null) {
      _toast('Please login to earn points.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewsFeedPage()),
    );
  }

  Future<void> _convertPoints({
    required int maxTaka, // already limited by points and the daily limit
    required int pointsPerTaka,
    required int minPoints,
  }) async {
    if (_converting) return;

    final minTaka = (minPoints + pointsPerTaka - 1) ~/ pointsPerTaka;

    if (maxTaka < minTaka) {
      _toast('You need at least $minPoints points to convert.');
      return;
    }

    final taka = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ConvertSheet(
        minTaka: minTaka,
        maxTaka: maxTaka,
        pointsPerTaka: pointsPerTaka,
      ),
    );

    if (taka == null || !mounted) return;

    setState(() => _converting = true);

    try {
      final response = await FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      ).httpsCallable('convertPointsToWallet').call({
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Watch & Earn',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userStream,
        builder: (context, userSnap) {
          final userData = userSnap.data?.data() ?? <String, dynamic>{};

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _configStream,
            builder: (context, configSnap) {
              final config = configSnap.data?.data() ?? <String, dynamic>{};

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _daysStream,
                builder: (context, daysSnap) {
                  return _buildContent(
                    userData: userData,
                    config: config,
                    dayDocs: daysSnap.data?.docs ?? [],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContent({
    required Map<String, dynamic> userData,
    required Map<String, dynamic> config,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> dayDocs,
  }) {
    final loggedIn = _user != null;

    // ---- reward numbers set by the Admin ----
    var perVideo = (config['pointsPerVideo'] as num?)?.toInt() ?? 5;
    if (perVideo < 0) perVideo = 0;
    if (perVideo > 1000) perVideo = 1000;
    _pointsPerVideo = perVideo;

    var dayLimit = (config['dailyVideoLimit'] as num?)?.toInt() ?? 20;
    if (dayLimit < 1) dayLimit = 1;
    if (dayLimit > 1000) dayLimit = 1000;
    _dailyLimit = dayLimit;

    // ---- user ----
    final points = (userData['pointsBalance'] as num?)?.toInt() ?? 0;
    final lifetime = (userData['lifetimePoints'] as num?)?.toInt() ?? 0;

    // ---- admin settings ----
    final enabled = config['pointsConversionEnabled'] != false;

    var pointsPerTaka = (config['pointsPerTaka'] as num?)?.toInt() ?? 100;
    if (pointsPerTaka < 1) pointsPerTaka = 1;

    var minPoints = (config['minPointsToConvert'] as num?)?.toInt() ?? 500;
    if (minPoints < pointsPerTaka) minPoints = pointsPerTaka;

    // streak bonus (same limits as functions/rewards.js)
    final streakEnabled = config['streakBonusEnabled'] != false;

    var streakDays = (config['streakBonusDays'] as num?)?.toInt() ?? 7;
    if (streakDays < 2) streakDays = 2;
    if (streakDays > 60) streakDays = 60;

    final streakPoints = (config['streakBonusPoints'] as num?)?.toInt() ?? 50;

    // max ৳ a user can convert per day (0 = no limit)
    final dailyConvertLimit =
        (config['maxConvertTakaPerDay'] as num?)?.toInt() ?? 0;

    // ---- daily data ----
    final counts = <String, int>{};
    final converted = <String, int>{};

    for (final doc in dayDocs) {
      counts[doc.id] = (doc.data()['count'] as num?)?.toInt() ?? 0;
      converted[doc.id] = (doc.data()['convertedTaka'] as num?)?.toInt() ?? 0;
    }

    final today = _todayBd;
    final todayCount = counts[_keyOf(today)] ?? 0;
    final convertedToday = converted[_keyOf(today)] ?? 0;

    int? convertLeft;

    if (dailyConvertLimit > 0) {
      convertLeft = dailyConvertLimit - convertedToday;
      if (convertLeft < 0) convertLeft = 0;
    }
    final remaining = (_dailyLimit - todayCount).clamp(0, _dailyLimit);
    final streak = _streak(counts);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
      children: [
        _hero(points, lifetime, pointsPerTaka),
        const SizedBox(height: 14),
        _statTiles(todayCount, streak, remaining),
        const SizedBox(height: 14),
        if (!loggedIn) ...[
          _loginBanner(),
          const SizedBox(height: 14),
        ],
        _watchButton(loggedIn, remaining),
        const SizedBox(height: 16),
        _dailyGoalCard(todayCount, remaining),
        const SizedBox(height: 16),
        if (streakEnabled && streakPoints > 0) ...[
          _streakCard(streak, streakDays, streakPoints, todayCount),
          const SizedBox(height: 16),
        ],
        if (config['referralEnabled'] != false) ...[
          _inviteCard(userData, config, loggedIn),
          const SizedBox(height: 16),
        ],
        _weekCard(counts, today),
        const SizedBox(height: 16),
        _convertCard(
          loggedIn: loggedIn,
          enabled: enabled,
          points: points,
          pointsPerTaka: pointsPerTaka,
          minPoints: minPoints,
          convertLeft: convertLeft,
          dailyConvertLimit: dailyConvertLimit,
        ),
        const SizedBox(height: 16),
        _howItWorksCard(),
        const SizedBox(height: 16),
        _historyCard(),
      ],
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _hero(int points, int lifetime, int pointsPerTaka) {
    final worth = points ~/ pointsPerTaka;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: _gradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -40,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.stars_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Available Points',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _formatPoints(points),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '≈ ৳$worth in wallet',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Lifetime ${_formatPoints(lifetime)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STAT TILES
  // ============================================================

  Widget _statTiles(int todayCount, int streak, int remaining) {
    return Row(
      children: [
        Expanded(
          child: _statTile(
            icon: Icons.bolt_rounded,
            color: Colors.orange,
            value: '+${todayCount * _pointsPerVideo}',
            label: 'Earned today',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statTile(
            icon: Icons.local_fire_department_rounded,
            color: Colors.deepOrange,
            value: streak >= 30 ? '30+' : '$streak',
            label: streak == 1 ? 'Day streak' : 'Days streak',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statTile(
            icon: Icons.play_circle_fill_rounded,
            color: Colors.green,
            value: '$remaining',
            label: 'Videos left',
          ),
        ),
      ],
    );
  }

  Widget _statTile({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // ============================================================
  // LOGIN BANNER + WATCH BUTTON
  // ============================================================

  Widget _loginBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.orange),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Login to start earning points.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(onPressed: _openLogin, child: const Text('Login')),
        ],
      ),
    );
  }

  Widget _watchButton(bool loggedIn, int remaining) {
    final limitReached = loggedIn && remaining == 0;

    final label = !loggedIn
        ? 'Login to Earn'
        : limitReached
            ? 'Daily limit reached'
            : 'Watch & Earn +$_pointsPerVideo';

    return Opacity(
      opacity: limitReached ? 0.55 : 1,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          gradient: _gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: limitReached
                ? () => _toast('You reached today\'s limit. Come back tomorrow!')
                : (loggedIn ? _openVideos : _openLogin),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    limitReached ? Icons.check_circle : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
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

  // ============================================================
  // DAILY GOAL
  // ============================================================

  Widget _dailyGoalCard(int todayCount, int remaining) {
    final shown = todayCount > _dailyLimit ? _dailyLimit : todayCount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 92,
                  height: 92,
                  child: CircularProgressIndicator(
                    value: shown / _dailyLimit,
                    strokeWidth: 9,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      shown >= _dailyLimit ? Colors.green : Colors.redAccent,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$shown',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'of $_dailyLimit',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily goal',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  remaining > 0
                      ? 'You can still earn ${remaining * _pointsPerVideo} points today.'
                      : 'Goal complete! 🎉 See you tomorrow.',
                  style: const TextStyle(color: Colors.black87, height: 1.3),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Resets at 12:00 AM (Bangladesh time)',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LAST 7 DAYS
  // ============================================================

  Widget _weekCard(Map<String, int> counts, DateTime today) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const barArea = 84.0;

    final bars = <Widget>[];
    var weekTotal = 0;

    for (var i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final count = counts[_keyOf(day)] ?? 0;
      weekTotal += count;

      final ratio = (count / _dailyLimit).clamp(0.0, 1.0);
      final isToday = i == 0;

      bars.add(
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                count > 0 ? '$count' : '',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              const SizedBox(height: 3),
              Container(
                height: count > 0 ? (barArea * ratio).clamp(6.0, barArea) : 4,
                width: 20,
                decoration: BoxDecoration(
                  gradient: count > 0 ? _gradient : null,
                  color: count > 0 ? null : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                names[day.weekday - 1],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday ? Colors.redAccent : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Colors.redAccent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Last 7 days',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '$weekTotal videos • ${weekTotal * _pointsPerVideo} pts',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: barArea + 44,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: bars,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONVERT
  // ============================================================

  Widget _convertCard({
    required bool loggedIn,
    required bool enabled,
    required int points,
    required int pointsPerTaka,
    required int minPoints,
    required int? convertLeft,
    required int dailyConvertLimit,
  }) {
    final minTaka = (minPoints + pointsPerTaka - 1) ~/ pointsPerTaka;

    var maxTaka = points ~/ pointsPerTaka;

    final limitHit = convertLeft != null && convertLeft < minTaka;

    if (convertLeft != null && convertLeft < maxTaka) {
      maxTaka = convertLeft;
    }

    final canConvert = loggedIn && enabled && maxTaka >= minTaka;

    final progress = (points / minPoints).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Convert to Wallet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$pointsPerTaka points = ৳1  •  Minimum ${_formatPoints(minPoints)} points',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 14),
          if (enabled && points < minPoints) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 9,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_formatPoints(minPoints - points)} more points to unlock conversion.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: (canConvert && !_converting)
                  ? () => _convertPoints(
                        maxTaka: maxTaka,
                        pointsPerTaka: pointsPerTaka,
                        minPoints: minPoints,
                      )
                  : null,
              icon: _converting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.swap_horiz_rounded),
              label: Text(
                !enabled
                    ? 'Conversion paused'
                    : limitHit
                        ? 'Daily conversion limit reached'
                        : canConvert
                            ? 'Convert up to ৳$maxTaka'
                            : 'Convert to ৳ Wallet',
              ),
            ),
          ),
          if (dailyConvertLimit > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Daily limit ৳$dailyConvertLimit  •  ৳${convertLeft ?? 0} left today',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // INVITE & EARN
  // ============================================================

  Future<void> _getCode() async {
    if (_referralBusy) return;

    setState(() => _referralBusy = true);

    try {
      await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('getMyReferralCode')
          .call();
      // The code appears automatically (users/{uid} is a live stream).
    } on FirebaseFunctionsException catch (e) {
      _toast(e.message ?? 'Could not create your code.');
    } catch (_) {
      _toast('Could not create your code. Please try again.');
    } finally {
      if (mounted) setState(() => _referralBusy = false);
    }
  }

  Future<void> _applyCode() async {
    final code = _codeController.text.trim().toUpperCase();

    if (code.isEmpty || _referralBusy) return;

    setState(() => _referralBusy = true);

    try {
      final response = await FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      ).httpsCallable('applyReferralCode').call({'code': code});

      final data = Map<String, dynamic>.from(response.data as Map);

      _codeController.clear();

      _toast('Invite code applied. You joined with ${data['inviterName']}.');
    } on FirebaseFunctionsException catch (e) {
      _toast(e.message ?? 'Could not apply this code.');
    } catch (_) {
      _toast('Could not apply this code. Please try again.');
    } finally {
      if (mounted) setState(() => _referralBusy = false);
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    _toast('Invite code copied.');
  }

  Future<void> _shareCode(String code) async {
    try {
      await Share.share(
        'Join BuyNova and earn rewards by watching videos! '
        'Use my invite code $code after you sign up.',
      );
    } catch (_) {}
  }

  Widget _inviteCard(
    Map<String, dynamic> user,
    Map<String, dynamic> config,
    bool loggedIn,
  ) {
    final bonus = (config['referralBonusPoints'] as num?)?.toInt() ?? 200;
    final welcome = (config['referralWelcomePoints'] as num?)?.toInt() ?? 50;

    final code = (user['referralCode'] ?? '').toString();
    final referredBy = (user['referredBy'] ?? '').toString();
    final count = (user['referralCount'] as num?)?.toInt() ?? 0;
    final earned = (user['referralEarnings'] as num?)?.toInt() ?? 0;
    final lifetime = (user['lifetimePoints'] as num?)?.toInt() ?? 0;

    final canEnterCode = loggedIn && referredBy.isEmpty && lifetime == 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.group_add_rounded, color: Colors.indigo),
              SizedBox(width: 8),
              Text(
                'Invite & Earn',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Invite a friend. When they join and earn their first video '
            'reward, you get +$bonus points and they get +$welcome points.',
            style: const TextStyle(color: Colors.black87, height: 1.35),
          ),
          const SizedBox(height: 14),
          if (!loggedIn)
            const Text(
              'Login to get your invite code.',
              style: TextStyle(color: Colors.grey),
            )
          else if (code.isEmpty)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: _referralBusy ? null : _getCode,
                icon: _referralBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.card_giftcard),
                label: const Text('Get my invite code'),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.indigo.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      code,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                        color: Colors.indigo,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    onPressed: () => _copyCode(code),
                    icon: const Icon(Icons.copy_rounded),
                  ),
                  IconButton(
                    tooltip: 'Share',
                    onPressed: () => _shareCode(code),
                    icon: const Icon(Icons.share_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _miniStat('$count', 'Friends rewarded'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniStat('+$earned', 'Points earned'),
                ),
              ],
            ),
          ],
          if (referredBy.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 18),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'You joined with an invite code.',
                    style: TextStyle(color: Colors.green),
                  ),
                ),
              ],
            ),
          ],
          if (canEnterCode) ...[
            const SizedBox(height: 16),
            const Text(
              'Have an invite code?',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    enabled: !_referralBusy,
                    decoration: InputDecoration(
                      hintText: 'Enter code',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _referralBusy ? null : _applyCode,
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  // ============================================================
  // STREAK BONUS
  // ============================================================

  Widget _streakCard(int streak, int days, int bonus, int todayCount) {
    var inCycle = streak == 0 ? 0 : ((streak - 1) % days) + 1;

    final bonusEarnedToday = inCycle == days && todayCount > 0;

    // Bonus was paid on an earlier day: a new cycle starts.
    if (inCycle == days && todayCount == 0) inCycle = 0;

    final left = days - inCycle;

    final String message;

    if (bonusEarnedToday) {
      message = 'Streak bonus earned! +$bonus points 🎉';
    } else if (streak > 0 && todayCount == 0) {
      message = 'Watch a video today to keep your $streak-day streak. '
          '$left more ${left == 1 ? 'day' : 'days'} for +$bonus bonus points.';
    } else {
      message = 'Watch $left more ${left == 1 ? 'day' : 'days'} in a row '
          'to earn +$bonus bonus points.';
    }

    final Widget progress;

    if (days <= 14) {
      progress = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(days, (i) {
          final filled = bonusEarnedToday || i < inCycle;
          final isLast = i == days - 1;

          return Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: filled ? _gradient : null,
              color: filled ? null : Colors.grey.shade200,
            ),
            child: Icon(
              isLast ? Icons.card_giftcard : Icons.check,
              size: 16,
              color: filled ? Colors.white : Colors.grey.shade400,
            ),
          );
        }),
      );
    } else {
      progress = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: bonusEarnedToday ? 1 : inCycle / days,
          minHeight: 10,
          backgroundColor: Colors.grey.shade200,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: Colors.deepOrange,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Streak bonus',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+$bonus pts',
                  style: const TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          progress,
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.black87, height: 1.35),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HOW IT WORKS
  // ============================================================

  Widget _howItWorksCard() {
    Widget step(int number, String title, String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: _gradient,
              ),
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                'How it works',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          step(
            1,
            'Watch a video',
            'Open Videos and keep a video playing for 10 seconds.',
          ),
          step(
            2,
            'Tap Claim',
            'Tap the claim button on the video. Each video gives '
                '$_pointsPerVideo points, up to $_dailyLimit videos a day.',
          ),
          step(
            3,
            'Convert to money',
            'Points are added after verification. Convert them to your '
                'BuyNova Wallet any time.',
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Your own videos do not earn points, and each video can be '
              'rewarded only once.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HISTORY
  // ============================================================

  Widget _historyCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, color: Colors.blueGrey),
              SizedBox(width: 8),
              Text(
                'Earning History',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_historyStream == null)
            _historyMessage('Login to see your earning history.')
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _historyStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (snapshot.hasError || docs.isEmpty) {
                  return _historyMessage('No earning history yet.');
                }

                return Column(
                  children: docs.map((doc) => _historyRow(doc.data())).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _historyMessage(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(text, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }

  Widget _historyRow(Map<String, dynamic> data) {
    final points = (data['points'] as num?)?.toInt() ?? 0;
    final type = (data['type'] ?? 'Reward').toString();
    final source = (data['source'] ?? '').toString();
    final positive = points >= 0;

    final IconData icon = source == 'points_conversion'
        ? Icons.swap_horiz_rounded
        : source == 'streak_bonus'
            ? Icons.local_fire_department_rounded
            : (source == 'referral' || source == 'referral_welcome')
                ? Icons.group_add_rounded
                : (source == 'admin_adjust')
                    ? Icons.admin_panel_settings_rounded
                    : Icons.play_arrow_rounded;

    final Color color = source == 'streak_bonus'
        ? Colors.deepOrange
        : (positive ? Colors.green : Colors.red);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(type, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        _timeAgo(data['createdAt']),
        style: const TextStyle(fontSize: 11.5),
      ),
      trailing: Text(
        '${positive ? '+' : ''}$points',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 16,
          color: color,
        ),
      ),
    );
  }
}

// ============================================================
// CONVERT BOTTOM SHEET
// ============================================================

class _ConvertSheet extends StatefulWidget {
  final int minTaka;
  final int maxTaka;
  final int pointsPerTaka;

  const _ConvertSheet({
    required this.minTaka,
    required this.maxTaka,
    required this.pointsPerTaka,
  });

  @override
  State<_ConvertSheet> createState() => _ConvertSheetState();
}

class _ConvertSheetState extends State<_ConvertSheet> {
  late int _taka = widget.maxTaka;

  @override
  Widget build(BuildContext context) {
    final range = widget.maxTaka - widget.minTaka;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Convert to Wallet',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            Text(
              '৳$_taka',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Uses ${_taka * widget.pointsPerTaka} points',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 14),
            if (range > 0) ...[
              Slider(
                value: _taka.toDouble(),
                min: widget.minTaka.toDouble(),
                max: widget.maxTaka.toDouble(),
                divisions: range <= 200 ? range : null,
                onChanged: (v) => setState(() => _taka = v.round()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('৳${widget.minTaka}',
                      style: const TextStyle(color: Colors.grey)),
                  Text('৳${widget.maxTaka}',
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Min'),
                    onPressed: () => setState(() => _taka = widget.minTaka),
                  ),
                  ActionChip(
                    label: const Text('Half'),
                    onPressed: () => setState(
                      () => _taka = ((widget.minTaka + widget.maxTaka) ~/ 2),
                    ),
                  ),
                  ActionChip(
                    label: const Text('All'),
                    onPressed: () => setState(() => _taka = widget.maxTaka),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _taka),
                    child: Text('Convert ৳$_taka'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
