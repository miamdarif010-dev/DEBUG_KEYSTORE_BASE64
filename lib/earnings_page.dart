import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EarningsPage extends StatelessWidget {
  const EarningsPage({super.key});

  // =========================================================
  // NUMBER
  // =========================================================

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  // =========================================================
  // INT
  // =========================================================

  int _int(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  // =========================================================
  // STATUS
  // =========================================================

  String _status(
    Map<String, dynamic> data,
  ) {
    return data['orderStatus']
            ?.toString()
            .toLowerCase() ??
        'placed';
  }

  // =========================================================
  // ITEMS
  // =========================================================

  List<Map<String, dynamic>> _items(
    Map<String, dynamic> data,
  ) {
    final raw = data['items'];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map(
          (item) =>
              Map<String, dynamic>.from(item),
        )
        .toList();
  }

  // =========================================================
  // ORDER TOTAL
  // =========================================================

  double _orderTotal(
    Map<String, dynamic> data,
  ) {
    final sellerSubtotal =
        data['sellerSubtotal'];

    if (sellerSubtotal != null) {
      return _number(sellerSubtotal);
    }

    double total = 0;

    for (final item in _items(data)) {
      final price = _number(item['price']);
      final quantity = _int(item['quantity']);

      final itemTotal = item['total'];

      if (itemTotal != null) {
        total += _number(itemTotal);
      } else {
        total += price * quantity;
      }
    }

    return total;
  }

  // =========================================================
  // FORMAT DATE
  // =========================================================

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();

      String two(int n) =>
          n.toString().padLeft(2, '0');

      return '${date.year}-${two(date.month)}-'
          '${two(date.day)} '
          '${two(date.hour)}:${two(date.minute)}';
    }

    return 'Date unavailable';
  }

  // =========================================================
  // STATUS COLOR
  // =========================================================

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.blue;

      case 'processing':
        return Colors.orange;

      case 'shipped':
        return Colors.indigo;

      case 'delivered':
        return Colors.green;

      case 'cancelled':
        return Colors.red;

      case 'returned':
        return Colors.deepOrange;

      default:
        return Colors.grey;
    }
  }

  // =========================================================
  // STATUS TEXT
  // =========================================================

  String _statusText(String status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmed';

      case 'processing':
        return 'Processing';

      case 'shipped':
        return 'Shipped';

      case 'delivered':
        return 'Delivered';

      case 'cancelled':
        return 'Cancelled';

      case 'returned':
        return 'Returned';

      default:
        return 'Placed';
    }
  }

  // =========================================================
  // STATUS CHIP
  // =========================================================

  Widget _statusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusText(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // =========================================================
  // SUMMARY CARD
  // =========================================================

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    final cardColor = color ?? Colors.blue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cardColor.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: cardColor,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ORDER HISTORY CARD
  // =========================================================

  Widget _orderHistoryCard(
    Map<String, dynamic> data,
  ) {
    final orderId =
        data['orderId']?.toString() ?? '';

    final customerName =
        data['customerName']?.toString() ??
            'Customer';

    final status = _status(data);

    final total = _orderTotal(data);

    final createdAt =
        _formatDate(data['createdAt']);

    final items = _items(data);

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 21,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Order #$orderId',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Customer: $customerName',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              createdAt,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              '${items.length} product(s)',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
            const Divider(
              height: 20,
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Seller Sales',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '৳${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Earnings'),
        ),
        body: const Center(
          child: Text(
            'Please login to view earnings.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Earnings',
        ),
      ),
      body: StreamBuilder<
          QuerySnapshot<
              Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('seller_orders')
            .where(
              'sellerId',
              isEqualTo: user.uid,
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(20),
                child: Text(
                  'Unable to load earnings.\n\n'
                  '${snapshot.error}',
                  textAlign:
                      TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final documents =
              snapshot.data?.docs.toList() ??
                  [];

          documents.sort((a, b) {
            final aTime =
                a.data()['createdAt'];

            final bTime =
                b.data()['createdAt'];

            if (aTime is Timestamp &&
                bTime is Timestamp) {
              return bTime.compareTo(aTime);
            }

            return 0;
          });

          // ===================================================
          // CALCULATE SELLER EARNINGS
          // ===================================================

          double totalSales = 0;
          double deliveredSales = 0;
          double pendingSales = 0;
          double cancelledSales = 0;

          int totalOrders = documents.length;
          int deliveredOrders = 0;
          int pendingOrders = 0;
          int cancelledOrders = 0;

          for (final document
              in documents) {
            final data = document.data();

            final status =
                _status(data);

            final amount =
                _orderTotal(data);

            if (status == 'cancelled') {
              cancelledSales += amount;
              cancelledOrders++;
              continue;
            }

            // A fully returned order is money that went back to the
            // customer. It is shown in the Return / Refund card below.
            if (status == 'returned') {
              continue;
            }

            totalSales += amount;

            if (status == 'delivered') {
              deliveredSales += amount;
              deliveredOrders++;
            } else {
              pendingSales += amount;
              pendingOrders++;
            }
          }

          // ===================================================
          // REAL EARNINGS (from the wallet)
          // ===================================================
          //
          // The money that really reached the seller wallet is recorded as
          // "sale_earning" transactions (already AFTER BuyNova's commission),
          // and money taken back for returns as "return_deduction".

          return StreamBuilder<
              QuerySnapshot<
                  Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('walletTransactions')
                .where(
                  'source',
                  whereIn: const [
                    'sale_earning',
                    'return_deduction',
                  ],
                )
                .snapshots(),
            builder: (
              context,
              walletSnapshot,
            ) {
              double netEarned = 0;
              double commissionPaid = 0;
              double returnRefundAmount = 0;

              if (walletSnapshot.connectionState ==
                      ConnectionState.waiting &&
                  !walletSnapshot.hasData) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              // On an error the numbers below simply stay 0.
              final walletDocs =
                  walletSnapshot.data?.docs ??
                      [];

              for (final doc
                  in walletDocs) {
                final data = doc.data();

                final source =
                    data['source']
                            ?.toString() ??
                        '';

                final amount =
                    _number(data['amount']);

                if (source ==
                    'sale_earning') {
                  netEarned += amount;

                  commissionPaid += _number(
                    data['commissionAmount'],
                  );
                } else if (source ==
                        'return_deduction' &&
                    data['subOrderCollection'] ==
                        'seller_orders') {
                  returnRefundAmount += amount;
                }
              }

              return _buildEarningsContent(
                context,
                documents,
                totalSales,
                deliveredSales,
                pendingSales,
                cancelledSales,
                returnRefundAmount,
                totalOrders,
                deliveredOrders,
                pendingOrders,
                cancelledOrders,
                user.uid,
                netEarned,
                commissionPaid,
              );
            },
          );
        },
      ),
    );
  }

  // =========================================================
  // EARNINGS CONTENT
  // =========================================================

  Widget _buildEarningsContent(
    BuildContext context,
    List<QueryDocumentSnapshot<
            Map<String, dynamic>>>
        documents,
    double totalSales,
    double deliveredSales,
    double pendingSales,
    double cancelledSales,
    double returnRefundAmount,
    int totalOrders,
    int deliveredOrders,
    int pendingOrders,
    int cancelledOrders,
    String sellerId,
    double netEarned,
    double commissionPaid,
  ) {
    final actualEarnings =
        netEarned - returnRefundAmount;

    final safeEarnings =
        actualEarnings < 0
            ? 0
            : actualEarnings;

    return RefreshIndicator(
      onRefresh: () async {
        await Future<void>.delayed(
          const Duration(milliseconds: 400),
        );
      },
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ===================================================
          // MAIN EARNINGS CARD
          // ===================================================

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: [
                  Theme.of(context)
                      .colorScheme
                      .primary,
                  Theme.of(context)
                      .colorScheme
                      .secondary,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 34,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Seller Earnings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '৳${safeEarnings.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Money credited to your BuyNova Wallet '
                  'after BuyNova commission, minus '
                  'returns and refunds.',
                  style: TextStyle(
                    color: Colors.white
                        .withValues(alpha: 0.88),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ===================================================
          // SUMMARY GRID
          // ===================================================

          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  title: 'Total Sales',
                  value:
                      '৳${totalSales.toStringAsFixed(0)}',
                  icon:
                      Icons.trending_up_outlined,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryCard(
                  title: 'Delivered',
                  value:
                      '৳${deliveredSales.toStringAsFixed(0)}',
                  icon:
                      Icons.check_circle_outline,
                  color: Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _summaryCard(
                  title: 'Pending',
                  value:
                      '৳${pendingSales.toStringAsFixed(0)}',
                  icon:
                      Icons.hourglass_empty,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryCard(
                  title: 'Cancelled',
                  value:
                      '৳${cancelledSales.toStringAsFixed(0)}',
                  icon:
                      Icons.cancel_outlined,
                  color: Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          _summaryCard(
            title: 'Return / Refund (taken back)',
            value:
                '৳${returnRefundAmount.toStringAsFixed(0)}',
            icon:
                Icons.assignment_return_outlined,
            color: Colors.deepOrange,
          ),

          const SizedBox(height: 10),

          _summaryCard(
            title: 'BuyNova Commission Paid',
            value:
                '৳${commissionPaid.toStringAsFixed(2)}',
            icon: Icons.percent,
            color: Colors.purple,
          ),

          const SizedBox(height: 22),

          // ===================================================
          // ORDER STATISTICS
          // ===================================================

          const Text(
            'Order Statistics',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Card(
            elevation: 1,
            child: Padding(
              padding:
                  const EdgeInsets.all(16),
              child: Column(
                children: [
                  _statRow(
                    'Total Orders',
                    totalOrders.toString(),
                    Icons.receipt_long_outlined,
                  ),
                  const Divider(),
                  _statRow(
                    'Delivered Orders',
                    deliveredOrders.toString(),
                    Icons.done_all_outlined,
                  ),
                  const Divider(),
                  _statRow(
                    'Pending Orders',
                    pendingOrders.toString(),
                    Icons.pending_actions_outlined,
                  ),
                  const Divider(),
                  _statRow(
                    'Cancelled Orders',
                    cancelledOrders.toString(),
                    Icons.cancel_outlined,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ===================================================
          // SALES HISTORY
          // ===================================================

          const Text(
            'Sales History',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          if (documents.isEmpty)
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(30),
                child: Column(
                  children: [
                    const Icon(
                      Icons.bar_chart_outlined,
                      size: 60,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No Sales Yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Orders containing your products '
                      'will appear here.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...documents.map(
              (document) =>
                  _orderHistoryCard(
                document.data(),
              ),
            ),

          const SizedBox(height: 20),

          // ===================================================
          // PAYMENT NOTE
          // ===================================================

          Container(
            padding:
                const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber
                  .withValues(alpha: 0.10),
              borderRadius:
                  BorderRadius.circular(14),
              border: Border.all(
                color: Colors.amber
                    .withValues(alpha: 0.25),
              ),
            ),
            child: const Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.orange,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Seller Earnings is the money already added '
                    'to your BuyNova Wallet when orders were '
                    'delivered, after BuyNova commission. '
                    'The sales cards below show order amounts '
                    'before commission. You can withdraw from '
                    'your wallet.',
                    style: TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // STAT ROW
  // =========================================================

  Widget _statRow(
    String title,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 21,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
