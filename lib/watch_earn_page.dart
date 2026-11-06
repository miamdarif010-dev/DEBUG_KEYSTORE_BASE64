import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'login_page.dart';

/// Points & Wallet (convert points, invite friends, earning history)
///
/// Uses only the backend you already have:
///  - users/{uid}                          pointsBalance, lifetimePoints
///  - users/{uid}/rewardDaily/{YYYY-MM-DD} convertedTaka (today's conversion limit)
///  - users/{uid}/pointsTransactions       history
///  - platformSettings/monetization        conversion rate
///  - callable convertPointsToWallet       points -> wallet
class WatchEarnPage extends StatefulWidget {
  const WatchEarnPage({super.key});

  @override
  State<WatchEarnPage> createState() => _WatchEarnPageState();
}

class _WatchEarnPageState extends State<WatchEarnPage> {
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
          'Points & Wallet',
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

    // ---- user ----
    final points = (userData['pointsBalance'] as num?)?.toInt() ?? 0;
    final lifetime = (userData['lifetimePoints'] as num?)?.toInt() ?? 0;

    // ---- admin settings ----
    final enabled = config['pointsConversionEnabled'] != false;

    var pointsPerTaka = (config['pointsPerTaka'] as num?)?.toInt() ?? 100;
    if (pointsPerTaka < 1) pointsPerTaka = 1;

    var minPoints = (config['minPointsToConvert'] as num?)?.toInt() ?? 500;
    if (minPoints < pointsPerTaka) minPoints = pointsPerTaka;

    // max ৳ a user can convert per day (0 = no limit)
    final dailyConvertLimit =
        (config['maxConvertTakaPerDay'] as num?)?.toInt() ?? 0;

    // ---- ৳ already converted today ----
    final todayKey = _keyOf(_todayBd);
    var convertedToday = 0;

    for (final doc in dayDocs) {
      if (doc.id == todayKey) {
        convertedToday = (doc.data()['convertedTaka'] as num?)?.toInt() ?? 0;
      }
    }

    int? convertLeft;

    if (dailyConvertLimit > 0) {
      convertLeft = dailyConvertLimit - convertedToday;
      if (convertLeft < 0) convertLeft = 0;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
      children: [
        _hero(points, lifetime, pointsPerTaka),
        const SizedBox(height: 14),
        if (!loggedIn) ...[
          _loginBanner(),
          const SizedBox(height: 14),
        ],
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
        if (config['referralEnabled'] != false) ...[
          _inviteCard(userData, config, loggedIn),
          const SizedBox(height: 16),
        ],
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
  // LOGIN BANNER
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
        'Join BuyNova and earn rewards by playing games! '
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
            'Invite a friend. When they join and earn their first '
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
