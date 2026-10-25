import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Admin: find a user (email or UID) and add / deduct reward points.
/// The change is done by the Cloud Function `adminAdjustPoints`, which
/// checks that the caller is the admin and saves a record + reason.
class AdminPointsPage extends StatefulWidget {
  /// Optional: open the page with a user already selected.
  final String? initialUserId;

  const AdminPointsPage({super.key, this.initialUserId});

  @override
  State<AdminPointsPage> createState() => _AdminPointsPageState();
}

class _AdminPointsPageState extends State<AdminPointsPage> {
  static const String _adminEmail = 'miamdarif010@gmail.com';

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  String? _foundUid;
  Map<String, dynamic>? _found;

  bool _searching = false;
  bool _saving = false;

  bool get _isAdmin =>
      FirebaseAuth.instance.currentUser?.email?.toLowerCase() == _adminEmail;

  @override
  void initState() {
    super.initState();

    final id = widget.initialUserId?.trim();

    if (id != null && id.isNotEmpty) {
      _searchController.text = id;
      _search();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  int _points(Map<String, dynamic>? data, String key) =>
      (data?[key] as num?)?.toInt() ?? 0;

  // ============================================================
  // FIND USER
  // ============================================================

  Future<void> _search() async {
    final text = _searchController.text.trim();

    if (text.isEmpty || _searching) return;

    setState(() {
      _searching = true;
      _found = null;
      _foundUid = null;
    });

    try {
      final users = FirebaseFirestore.instance.collection('users');

      DocumentSnapshot<Map<String, dynamic>>? doc;

      if (text.contains('@')) {
        var q = await users.where('email', isEqualTo: text).limit(1).get();

        if (q.docs.isEmpty && text != text.toLowerCase()) {
          q = await users
              .where('email', isEqualTo: text.toLowerCase())
              .limit(1)
              .get();
        }

        if (q.docs.isNotEmpty) doc = q.docs.first;
      } else {
        final d = await users.doc(text).get();

        if (d.exists) doc = d;
      }

      if (!mounted) return;

      if (doc == null) {
        _toast('User not found.');
      } else {
        setState(() {
          _foundUid = doc!.id;
          _found = doc.data();
        });
      }
    } catch (e) {
      _toast('Search failed: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _reloadUser() async {
    final uid = _foundUid;

    if (uid == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (mounted) setState(() => _found = doc.data());
    } catch (_) {}
  }

  // ============================================================
  // ADD / DEDUCT
  // ============================================================

  Future<void> _apply(bool add) async {
    final uid = _foundUid;

    if (uid == null || _saving) return;

    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    final reason = _reasonController.text.trim();

    if (amount <= 0) {
      _toast('Enter the number of points.');
      return;
    }

    if (reason.length < 3) {
      _toast('Please write a reason.');
      return;
    }

    final name = (_found?['name'] ?? 'this user').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(add ? 'Add points?' : 'Deduct points?'),
        content: Text(
          '${add ? 'Add' : 'Deduct'} $amount points '
          '${add ? 'to' : 'from'} $name?\n\nReason: $reason',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: add ? Colors.green : Colors.red,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(add ? 'Add' : 'Deduct'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);

    try {
      final response = await FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      ).httpsCallable('adminAdjustPoints').call({
        'uid': uid,
        'points': amount,
        'action': add ? 'add' : 'deduct',
        'reason': reason,
      });

      final data = Map<String, dynamic>.from(response.data as Map);

      _toast('Done. New balance: ${data['newBalance']} points.');

      _amountController.clear();
      _reasonController.clear();

      await _reloadUser();
    } on FirebaseFunctionsException catch (e) {
      _toast(e.message ?? 'Could not change points.');
    } catch (_) {
      _toast('Could not change points. Please try again.');
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
        appBar: AppBar(title: const Text('Manage Points')),
        body: const Center(child: Text('Admin access only.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(
        title: const Text('Manage Points'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'User email or UID',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _search,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (_found != null) _userCard(),
        ],
      ),
    );
  }

  Widget _userCard() {
    final data = _found!;

    final name = (data['name'] ?? 'No name').toString();
    final email = (data['email'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(18),
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
          Text(
            name,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          if (email.isNotEmpty)
            Text(email, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 14),
          Row(
            children: [
              _balanceBox(
                'Points balance',
                _points(data, 'pointsBalance'),
                Colors.redAccent,
              ),
              const SizedBox(width: 12),
              _balanceBox(
                'Lifetime earned',
                _points(data, 'lifetimePoints'),
                Colors.blueGrey,
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            enabled: !_saving,
            decoration: InputDecoration(
              labelText: 'Points',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            maxLength: 200,
            enabled: !_saving,
            decoration: InputDecoration(
              labelText: 'Reason (the user will see this)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _saving ? null : () => _apply(true),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _saving ? null : () => _apply(false),
                  icon: const Icon(Icons.remove),
                  label: const Text('Deduct'),
                ),
              ),
            ],
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _balanceBox(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
