import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'wallet_page.dart';

/// Admin only: BuyNova income page.
///
///  * Shows the admin wallet balance and the total income earned
///  * Lists the recent income (seller/reseller commission + buyer service fee)
///  * Opens the wallet so the admin can withdraw
///
/// The percentages are NOT set here. They live in
/// Admin Panel -> BuyNova Monetization (platformSettings/monetization).
/// The income is credited to the admin wallet by the Cloud Function
/// (payoutDeliveredSubOrder) when an order is delivered.
class AdminCommissionPage extends StatelessWidget {
  const AdminCommissionPage({super.key});

  String _money(num value) {
    final number = value.toDouble();

    if (number == number.roundToDouble()) {
      return '৳${number.toInt()}';
    }

    return '৳${number.toStringAsFixed(2)}';
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Processing...';

    final date = timestamp.toDate();

    final hour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day}/${date.month}/${date.year} $hour:$minute $period';
  }

  // =========================================================
  // EARNINGS CARD
  // =========================================================

  Widget _earningsCard(BuildContext context, String uid) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};

        final balance = (data['cashBalance'] as num?)?.toDouble() ?? 0.0;

        final earned =
            (data['totalCommissionEarned'] as num?)?.toDouble() ?? 0.0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Colors.redAccent, Colors.deepOrange],
            ),
          ),
          child: Column(
            children: [
              const Text(
                'Admin Wallet Balance',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                _money(balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total BuyNova income: ${_money(earned)}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WalletPage()),
                    );
                  },
                  icon: const Icon(Icons.account_balance_wallet),
                  label: const Text('Open Wallet / Withdraw'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // RECENT INCOME
  // =========================================================

  Widget _recentIncome(String uid) {
    // Needs a composite index (source + createdAt). If Firestore asks for
    // it, open the link shown in the error once and create it.
    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('walletTransactions')
        .where('source', isEqualTo: 'commission')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Could not load income history.\n${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'No income yet. It is added when an order is delivered.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();

            final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final commission =
                (data['commissionAmount'] as num?)?.toDouble() ?? 0.0;
            final serviceFee =
                (data['serviceFeeAmount'] as num?)?.toDouble() ?? 0.0;

            final orderId = (data['orderId'] ?? '').toString();

            final shortId =
                orderId.length > 8 ? orderId.substring(0, 8) : orderId;

            final reversed = data['type'] == 'debit';

            final detail = <String>[
              if (commission > 0) 'Commission ${_money(commission)}',
              if (serviceFee > 0) 'Service fee ${_money(serviceFee)}',
            ].join(' • ');

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0.5,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: (reversed ? Colors.red : Colors.green)
                      .withValues(alpha: 0.10),
                  child: Icon(
                    reversed ? Icons.undo : Icons.percent,
                    color: reversed ? Colors.red : Colors.green,
                  ),
                ),
                title: Text(
                  reversed ? 'Reversed • Order #$shortId' : 'Order #$shortId',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  [
                    if (detail.isNotEmpty) detail,
                    _formatDate(data['createdAt'] as Timestamp?),
                  ].join('\n'),
                  style: const TextStyle(fontSize: 11),
                ),
                isThreeLine: detail.isNotEmpty,
                trailing: Text(
                  '${reversed ? '-' : '+'}${_money(amount)}',
                  style: TextStyle(
                    color: reversed ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'BuyNova Income',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text('Please login again.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _earningsCard(context, user.uid),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Set the commission % and the buyer service fee in '
                    'Admin Panel → BuyNova Monetization. Income is added to '
                    'this wallet when an order is delivered.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Recent Income',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _recentIncome(user.uid),
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}

