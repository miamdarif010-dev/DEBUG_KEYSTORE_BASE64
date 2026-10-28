import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin page: control the Google ads shown in the home feed.
/// Saved in Firestore at settings/ads:
///   enabled (bool), firstAdPosition (int), interval (int)
class AdminAdsSettingsPage extends StatefulWidget {
  const AdminAdsSettingsPage({super.key});

  @override
  State<AdminAdsSettingsPage> createState() => _AdminAdsSettingsPageState();
}

class _AdminAdsSettingsPageState extends State<AdminAdsSettingsPage> {
  final DocumentReference<Map<String, dynamic>> _ref =
      FirebaseFirestore.instance.collection('settings').doc('ads');

  final TextEditingController _firstController =
      TextEditingController(text: '6');
  final TextEditingController _intervalController =
      TextEditingController(text: '8');

  bool _enabled = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snap = await _ref.get();
      final d = snap.data();

      if (d != null) {
        _enabled = d['enabled'] != false;

        final first = d['firstAdPosition'];
        final interval = d['interval'];

        if (first is num) _firstController.text = first.toInt().toString();
        if (interval is num) {
          _intervalController.text = interval.toInt().toString();
        }
      }
    } catch (_) {
      // Keep the defaults.
    }

    if (mounted) setState(() => _loading = false);
  }

  int _readNumber(TextEditingController c, int fallback) {
    final n = int.tryParse(c.text.trim()) ?? fallback;
    return n < 1 ? 1 : (n > 100 ? 100 : n);
  }

  Future<void> _save() async {
    final first = _readNumber(_firstController, 6);
    final interval = _readNumber(_intervalController, 8);

    setState(() => _saving = true);

    try {
      await _ref.set({
        'enabled': _enabled,
        'firstAdPosition': first,
        'interval': interval,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _firstController.text = first.toString();
      _intervalController.text = interval.toString();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad settings saved')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    }

    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ad Settings'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: SwitchListTile(
                    title: const Text('Show ads on Home'),
                    subtitle: Text(
                      _enabled ? 'Ads are ON' : 'Ads are OFF',
                    ),
                    value: _enabled,
                    activeColor: Colors.redAccent,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _firstController,
                  enabled: _enabled,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'First ad after how many products',
                    helperText: 'Example: 6 = first ad after 6 products',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _intervalController,
                  enabled: _enabled,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Then one ad after every how many products',
                    helperText: 'Example: 8 = an ad after every 8 products',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
    );
  }
}
