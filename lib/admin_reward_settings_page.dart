import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Admin: change every Watch & Earn / Invite & Earn number in one place.
/// Saves into platformSettings/monetization (other fields there, like the
/// membership fees, are NOT touched). Cloud Functions read these values on
/// every reward, so a change works immediately, no deploy needed.
class AdminRewardSettingsPage extends StatefulWidget {
  const AdminRewardSettingsPage({super.key});

  @override
  State<AdminRewardSettingsPage> createState() =>
      _AdminRewardSettingsPageState();
}

class _NumField {
  final String key;
  final String label;
  final int def;
  final int min;
  final int max;
  final String help;

  const _NumField(this.key, this.label, this.def, this.min, this.max, this.help);
}

class _AdminRewardSettingsPageState extends State<AdminRewardSettingsPage> {
  static const String _adminEmail = 'miamdarif010@gmail.com';

  // ---------- number fields (same defaults / limits as functions/rewards.js) ----------
  static const _watch = [
    _NumField('pointsPerVideo', 'Points per watched video', 5, 0, 1000,
        '0 = pause video rewards'),
    _NumField('dailyVideoLimit', 'Rewarded videos per user per day', 20, 1, 1000,
        'A user cannot earn from more videos than this each day'),
  ];

  static const _invite = [
    _NumField('referralBonusPoints', 'Inviter gets (points)', 200, 0, 1000000,
        'Paid when the invited user gets their first rewarded video'),
    _NumField('referralWelcomePoints', 'New user gets (points)', 50, 0, 1000000,
        'Paid together with the inviter bonus'),
    _NumField('referralMaxPerUser', 'Max rewarded invites per user', 50, 0, 100000,
        '0 = no limit'),
  ];

  static const _streak = [
    _NumField('streakBonusDays', 'Bonus every N days in a row', 7, 2, 60,
        'Between 2 and 60'),
    _NumField('streakBonusPoints', 'Streak bonus (points)', 50, 0, 100000,
        '0 = no bonus'),
  ];

  static const _convert = [
    _NumField('pointsPerTaka', 'Points = ৳1', 100, 1, 1000000,
        'Example: 100 means 100 points = ৳1'),
    _NumField('minPointsToConvert', 'Minimum points to convert', 500, 1, 100000000,
        'Users below this cannot convert'),
    _NumField('maxConvertTakaPerDay', 'Max ৳ a user can convert per day', 0, 0,
        100000000, '0 = no daily limit'),
  ];

  final Map<String, TextEditingController> _c = {};

  bool _referralEnabled = true;
  bool _streakEnabled = true;
  bool _conversionEnabled = true;

  bool _loading = true;
  bool _saving = false;

  bool get _isAdmin =>
      FirebaseAuth.instance.currentUser?.email?.toLowerCase() == _adminEmail;

  Iterable<_NumField> get _all =>
      [..._watch, ..._invite, ..._streak, ..._convert];

  @override
  void initState() {
    super.initState();

    for (final f in _all) {
      _c[f.key] = TextEditingController(text: '${f.def}');
    }

    if (_isAdmin) {
      _load();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('platformSettings')
          .doc('monetization')
          .get();

      final data = doc.data() ?? <String, dynamic>{};

      for (final f in _all) {
        final v = data[f.key];

        if (v is num) _c[f.key]!.text = '${v.toInt()}';
      }

      _referralEnabled = data['referralEnabled'] != false;
      _streakEnabled = data['streakBonusEnabled'] != false;
      _conversionEnabled = data['pointsConversionEnabled'] != false;
    } catch (e) {
      _toast('Could not load settings: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _value(String key) {
    final f = _all.firstWhere((x) => x.key == key);

    return int.tryParse(_c[key]!.text.trim()) ?? f.def;
  }

  Future<void> _save() async {
    if (_saving) return;

    final update = <String, dynamic>{};

    for (final f in _all) {
      final text = _c[f.key]!.text.trim();
      final n = int.tryParse(text);

      if (n == null || n < f.min || n > f.max) {
        _toast('${f.label}: enter a number from ${f.min} to ${f.max}.');
        return;
      }

      update[f.key] = n;
    }

    update['referralEnabled'] = _referralEnabled;
    update['streakBonusEnabled'] = _streakEnabled;
    update['pointsConversionEnabled'] = _conversionEnabled;
    update['rewardSettingsUpdatedAt'] = FieldValue.serverTimestamp();
    update['rewardSettingsUpdatedBy'] =
        FirebaseAuth.instance.currentUser?.uid ?? '';

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('platformSettings')
          .doc('monetization')
          .set(update, SetOptions(merge: true));

      _toast('Saved. New numbers work from the next reward.');
    } catch (e) {
      _toast('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reward Settings')),
        body: const Center(child: Text('Admin access only.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(
        title: const Text('Reward Settings'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section(
                  icon: Icons.play_circle_fill,
                  color: Colors.redAccent,
                  title: 'Watch & Earn',
                  children: [
                    ..._watch.map(_numberField),
                    _worth('pointsPerVideo'),
                  ],
                ),
                _section(
                  icon: Icons.group_add,
                  color: Colors.blue,
                  title: 'Invite & Earn',
                  switchValue: _referralEnabled,
                  switchLabel: 'Invites enabled',
                  onSwitch: (v) => setState(() => _referralEnabled = v),
                  children: [
                    ..._invite.map(_numberField),
                    _worth('referralBonusPoints', prefix: 'Inviter gets '),
                    _worth('referralWelcomePoints', prefix: 'New user gets '),
                  ],
                ),
                _section(
                  icon: Icons.local_fire_department,
                  color: Colors.deepOrange,
                  title: 'Streak bonus',
                  switchValue: _streakEnabled,
                  switchLabel: 'Streak bonus enabled',
                  onSwitch: (v) => setState(() => _streakEnabled = v),
                  children: _streak.map(_numberField).toList(),
                ),
                _section(
                  icon: Icons.account_balance_wallet,
                  color: Colors.green,
                  title: 'Convert to Wallet',
                  switchValue: _conversionEnabled,
                  switchLabel: 'Conversion enabled',
                  onSwitch: (v) => setState(() => _conversionEnabled = v),
                  children: _convert.map(_numberField).toList(),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Save settings'),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Changes apply to new rewards only. Points users already '
                  'have are not changed. To change one user\'s points, use '
                  'Manage Points.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _section({
    required IconData icon,
    required Color color,
    required String title,
    required List<Widget> children,
    bool? switchValue,
    String? switchLabel,
    ValueChanged<bool>? onSwitch,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (switchValue != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(switchLabel ?? ''),
              value: switchValue,
              onChanged: onSwitch,
            ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _numberField(_NumField f) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _c[f.key],
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: f.label,
          helperText: f.help,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  /// Shows what the points are worth in Taka, using the current rate.
  Widget _worth(String key, {String prefix = 'Each video = '}) {
    final perTaka = _value('pointsPerTaka');
    final points = _value(key);
    final taka = perTaka > 0 ? points / perTaka : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$prefix$points points ≈ ৳${taka.toStringAsFixed(2)}',
        style: const TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
