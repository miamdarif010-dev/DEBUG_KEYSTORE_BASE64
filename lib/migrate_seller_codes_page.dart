// =====================================================================
// ONE-TIME MIGRATION PAGE
// =====================================================================
//
// Purpose: convert every existing seller / entrepreneur that still has
// an old UID-based code (e.g. SELL-A1B2C3, ENT-9F00E1) into the new
// sequential format (SELL-000001, ENT-000001, ...).
//
// How it works:
// 1. Reads all users with sellerStatus == 'approved', sorted by
//    sellerApprovedAt (falls back to name/uid order if missing) so the
//    earliest-approved seller becomes SELL-000001, and so on.
// 2. Assigns a new sequential code to each one and writes it back.
// 3. Sets the sellerCounter / entrepreneurCounter documents to match
//    the highest number handed out, so any *future* approval from
//    admin_panel_page.dart continues the sequence correctly instead of
//    starting over from 1.
// 4. Same process, separately, for entrepreneurs.
//
// This page is meant to be opened ONCE by the admin, run, and then
// removed from the app (or just never opened again). It intentionally
// asks for confirmation before writing anything, and shows a log of
// what it did.
//
// Usage: temporarily add a button/route to open MigrateSellerCodesPage,
// run it, confirm the results in Firestore, then remove the route.
// =====================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MigrateSellerCodesPage extends StatefulWidget {
  const MigrateSellerCodesPage({super.key});

  @override
  State<MigrateSellerCodesPage> createState() =>
      _MigrateSellerCodesPageState();
}

class _MigrateSellerCodesPageState extends State<MigrateSellerCodesPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _running = false;
  bool _done = false;
  final List<String> _log = [];

  void _addLog(String line) {
    setState(() {
      _log.add(line);
    });
  }

  // ============================================================
  // CONFIRM + RUN
  // ============================================================

  Future<void> _confirmAndRun() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Run migration?'),
          content: const Text(
            'This will assign new sequential Seller IDs (SELL-000001, '
            'SELL-000002, ...) and Entrepreneur IDs (ENT-000001, ...) '
            'to every approved seller/entrepreneur that still has an '
            'old-style code. This cannot be easily undone.\n\n'
            'Run this only once.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Run Migration'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _running = true;
      _done = false;
      _log.clear();
    });

    try {
      await _migrateSellers();
      await _migrateEntrepreneurs();
      _addLog('âœ… Migration complete.');
    } catch (e) {
      _addLog('âŒ Migration failed: $e');
    }

    setState(() {
      _running = false;
      _done = true;
    });
  }

  // ============================================================
  // SELLERS
  // ============================================================

  bool _looksSequential(String code, String prefix) {
    // Matches PREFIX-000001 style codes exactly (6 digits).
    final pattern = RegExp('^$prefix-\\d{6}\$');
    return pattern.hasMatch(code);
  }

  Future<void> _migrateSellers() async {
    _addLog('Fetching approved sellers...');

    final snapshot = await _db
        .collection('users')
        .where('sellerStatus', isEqualTo: 'approved')
        .get();

    final docs = [...snapshot.docs];

    if (docs.isEmpty) {
      _addLog('No approved sellers found.');
      return;
    }

    // Earliest-approved first, so numbering reflects approval order.
    docs.sort((a, b) {
      final aTime = _timestampOf(a.data()['sellerApprovedAt']);
      final bTime = _timestampOf(b.data()['sellerApprovedAt']);
      return aTime.compareTo(bTime);
    });

    int nextNumber = 0;
    int migrated = 0;
    int skipped = 0;

    for (final doc in docs) {
      final data = doc.data();
      final existingCode = (data['sellerCode'] ?? '').toString();

      if (existingCode.isNotEmpty &&
          _looksSequential(existingCode, 'SELL')) {
        // Already migrated / already sequential â€” keep it, but make
        // sure our running counter accounts for it.
        final num = int.tryParse(
              existingCode.replaceAll('SELL-', ''),
            ) ??
            0;
        if (num > nextNumber) nextNumber = num;
        skipped++;
        continue;
      }

      nextNumber++;
      final newCode = 'SELL-${nextNumber.toString().padLeft(6, '0')}';

      await _db.collection('users').doc(doc.id).set(
        {'sellerCode': newCode},
        SetOptions(merge: true),
      );

      migrated++;
      _addLog('Seller ${doc.id}: "$existingCode" -> "$newCode"');
    }

    // Sync the counter so future approvals continue from here.
    await _db.collection('counters').doc('sellerCounter').set(
      {'value': nextNumber},
      SetOptions(merge: true),
    );

    _addLog(
      'Sellers done: $migrated migrated, $skipped already sequential. '
      'Counter set to $nextNumber.',
    );
  }

  // ============================================================
  // ENTREPRENEURS
  // ============================================================

  Future<void> _migrateEntrepreneurs() async {
    _addLog('Fetching approved entrepreneurs...');

    final snapshot = await _db
        .collection('users')
        .where('entrepreneurStatus', isEqualTo: 'approved')
        .get();

    final docs = [...snapshot.docs];

    if (docs.isEmpty) {
      _addLog('No approved entrepreneurs found.');
      return;
    }

    docs.sort((a, b) {
      final aTime = _timestampOf(a.data()['entrepreneurApprovedAt']);
      final bTime = _timestampOf(b.data()['entrepreneurApprovedAt']);
      return aTime.compareTo(bTime);
    });

    int nextNumber = 0;
    int migrated = 0;
    int skipped = 0;

    for (final doc in docs) {
      final data = doc.data();
      final existingCode = (data['entrepreneurCode'] ?? '').toString();

      if (existingCode.isNotEmpty &&
          _looksSequential(existingCode, 'ENT')) {
        final num = int.tryParse(
              existingCode.replaceAll('ENT-', ''),
            ) ??
            0;
        if (num > nextNumber) nextNumber = num;
        skipped++;
        continue;
      }

      nextNumber++;
      final newCode = 'ENT-${nextNumber.toString().padLeft(6, '0')}';

      await _db.collection('users').doc(doc.id).set(
        {'entrepreneurCode': newCode},
        SetOptions(merge: true),
      );

      migrated++;
      _addLog('Entrepreneur ${doc.id}: "$existingCode" -> "$newCode"');
    }

    await _db.collection('counters').doc('entrepreneurCounter').set(
      {'value': nextNumber},
      SetOptions(merge: true),
    );

    _addLog(
      'Entrepreneurs done: $migrated migrated, $skipped already '
      'sequential. Counter set to $nextNumber.',
    );
  }

  DateTime _timestampOf(dynamic value) {
    if (value is Timestamp) return value.toDate();
    // Users approved before this field existed sort first (oldest).
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Migrate Seller / Entrepreneur Codes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text(
                'One-time tool: converts old-style Seller/Entrepreneur '
                'IDs to the new sequential format. Safe to run more '
                'than once â€” already-migrated codes are skipped.',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _running ? null : _confirmAndRun,
              icon: _running
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_running ? 'Running...' : 'Run Migration'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Log',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _log.isEmpty
                    ? const Text(
                        'No output yet.',
                        style: TextStyle(color: Colors.white54),
                      )
                    : ListView.builder(
                        itemCount: _log.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              _log[index],
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
