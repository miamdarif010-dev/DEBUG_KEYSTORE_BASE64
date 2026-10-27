import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Invite & Earn page.
///
/// - Shows the user's invite code (Cloud Function `getMyReferralCode`).
/// - New users (joined within 7 days, no points yet) can enter a friend's
///   code (Cloud Function `applyReferralCode`).
/// - Every number comes LIVE from platformSettings/monetization, the same
///   document the Admin edits in Admin Panel > Reward Settings.
class InvitePage extends StatefulWidget {
  const InvitePage({super.key});

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  static const String _region = 'asia-northeast3';
  static const int _codeWindowDays = 7;

  final TextEditingController _codeController = TextEditingController();

  String? _myCode;
  String? _codeError;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _loadMyCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  int _num(Map<String, dynamic> d, String key, int def) {
    final v = d[key];
    return v is num ? v.toInt() : def;
  }

  Future<void> _loadMyCode() async {
    try {
      final res = await FirebaseFunctions.instanceFor(region: _region)
          .httpsCallable('getMyReferralCode')
          .call();

      final data = Map<String, dynamic>.from(res.data as Map);

      if (mounted) setState(() => _myCode = data['code']?.toString());
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _codeError = e.message ?? 'Could not load your code.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _codeError = 'Could not load your code.');
      }
    }
  }

  Future<void> _applyCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty || _applying) return;

    setState(() => _applying = true);

    try {
      final res = await FirebaseFunctions.instanceFor(region: _region)
          .httpsCallable('applyReferralCode')
          .call({'code': code});

      final data = Map<String, dynamic>.from(res.data as Map);

      _codeController.clear();

      _toast(
        'Code accepted! ${data['inviterName'] ?? 'Your friend'} invited you. '
        'Watch your first reward video to get your bonus.',
      );
    } on FirebaseFunctionsException catch (e) {
      _toast(e.message ?? 'Could not use this code.');
    } catch (_) {
      _toast('Could not use this code. Please try again.');
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _share(String message) async {
    try {
      await Share.share(message);
    } catch (_) {
      _copy(message, 'Could not open share. Message copied instead.');
    }
  }

  void _copy(String text, String done) {
    Clipboard.setData(ClipboardData(text: text));
    _toast(done);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(
        title: const Text('Invite & Earn'),
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text('Please sign in first.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('platformSettings')
                  .doc('monetization')
                  .snapshots(),
              builder: (context, settingsSnap) {
                if (settingsSnap.connectionState == ConnectionState.waiting &&
                    !settingsSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final s = settingsSnap.data?.data() ?? <String, dynamic>{};

                final enabled = s['referralEnabled'] != false;
                final inviterPts = _num(s, 'referralBonusPoints', 200);
                final welcomePts = _num(s, 'referralWelcomePoints', 50);
                final maxInvites = _num(s, 'referralMaxPerUser', 50);
                final perTaka = _num(s, 'pointsPerTaka', 100);

                String taka(int pts) =>
                    perTaka > 0 ? (pts / perTaka).toStringAsFixed(2) : '0.00';

                if (!enabled) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Invites are not available right now.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                }

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .snapshots(),
                  builder: (context, userSnap) {
                    final u = userSnap.data?.data() ?? <String, dynamic>{};

                    final referralCount = _num(u, 'referralCount', 0);
                    final referralEarnings = _num(u, 'referralEarnings', 0);

                    final alreadyReferred =
                        (u['referredBy']?.toString() ?? '').isNotEmpty;

                    final created = user.metadata.creationTime;
                    final isNewUser = created != null &&
                        DateTime.now().difference(created).inDays <
                            _codeWindowDays;

                    final canEnterCode = !alreadyReferred &&
                        isNewUser &&
                        _num(u, 'lifetimePoints', 0) == 0;

                    final code = _myCode;

                    final message = code == null
                        ? ''
                        : 'Join me on BuyNova and earn reward points! '
                            'Use my invite code: $code';

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // HERO
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF5252), Color(0xFFFF7A5C)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.card_giftcard,
                                  color: Colors.white, size: 44),
                              const SizedBox(height: 10),
                              Text(
                                'Invite a friend, get $inviterPts points',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Your friend gets $welcomePts points too.',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // MY CODE
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your invite code',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (code != null) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: SelectableText(
                                        code,
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 3,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Copy code',
                                      icon: const Icon(Icons.copy),
                                      onPressed: () =>
                                          _copy(code, 'Code copied'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: FilledButton.icon(
                                    onPressed: () => _share(message),
                                    icon: const Icon(Icons.share),
                                    label: const Text('Share invite'),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: double.infinity,
                                  height: 42,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _copy(
                                      message,
                                      'Invite message copied.',
                                    ),
                                    icon: const Icon(Icons.copy),
                                    label: const Text('Copy message'),
                                  ),
                                ),
                              ] else if (_codeError != null)
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _codeError!,
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setState(() => _codeError = null);
                                        _loadMyCode();
                                      },
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                )
                              else
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: LinearProgressIndicator(),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // MY STATS
                        Row(
                          children: [
                            _statBox('Friends invited', '$referralCount',
                                Colors.blueGrey),
                            const SizedBox(width: 12),
                            _statBox('Points earned', '$referralEarnings',
                                Colors.green),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ENTER A FRIEND'S CODE (new users only)
                        if (canEnterCode)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Got an invite code?',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Enter it now and get $welcomePts points '
                                  'after your first reward video.',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _codeController,
                                  enabled: !_applying,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  maxLength: 10,
                                  decoration: InputDecoration(
                                    labelText: 'Invite code',
                                    counterText: '',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: FilledButton(
                                    onPressed: _applying ? null : _applyCode,
                                    child: _applying
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Apply code'),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (alreadyReferred)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              u['referralStatus'] == 'rewarded'
                                  ? 'You joined with an invite code and got your welcome bonus.'
                                  : 'You joined with an invite code. Watch your first reward video to get your bonus.',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        if (canEnterCode || alreadyReferred)
                          const SizedBox(height: 16),

                        // HOW IT WORKS
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'How it works',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '1. Send your code to a friend.\n'
                                '2. They enter it within $_codeWindowDays days of joining.\n'
                                '3. When they get their first rewarded video, '
                                'you get $inviterPts points '
                                '(≈ ৳${taka(inviterPts)}) and they get '
                                '$welcomePts points (≈ ৳${taka(welcomePts)}).',
                                style: const TextStyle(height: 1.5),
                              ),
                              if (maxInvites > 0) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'You can earn from up to $maxInvites invites.',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
