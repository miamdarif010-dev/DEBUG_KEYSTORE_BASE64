import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'return_refund_request_details_page.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  // =========================================================
  // TIMESTAMP
  // =========================================================

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();

    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);

    final minute = date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day}/${date.month}/${date.year} '
        '$hour:$minute $period';
  }

  // =========================================================
  // NOTIFICATION ICON
  // =========================================================

  IconData _notificationIcon(String type) {
    switch (type) {
      // -------------------------------------------------------
      // ORDER
      // -------------------------------------------------------

      case 'order':
        return Icons.shopping_bag_outlined;

      case 'shipped':
        return Icons.local_shipping_outlined;

      case 'delivered':
        return Icons.check_circle_outline;

      case 'cancelled':
        return Icons.cancel_outlined;

      // -------------------------------------------------------
      // RETURN / REFUND
      // -------------------------------------------------------

      case 'return':
      case 'refund':
      case 'return_refund':
        return Icons.assignment_return_outlined;

      // -------------------------------------------------------
      // SELLER
      // -------------------------------------------------------

      case 'seller':
        return Icons.storefront_outlined;

      // -------------------------------------------------------
      // PAYMENT
      // -------------------------------------------------------

      case 'payment':
        return Icons.payment_outlined;

      // -------------------------------------------------------
      // REVIEW
      // -------------------------------------------------------

      case 'review':
        return Icons.star_outline;

      // -------------------------------------------------------
      // WALLET
      // -------------------------------------------------------

      case 'wallet_deposit':
        return Icons.account_balance_wallet_outlined;

      case 'wallet_deposit_rejected':
        return Icons.money_off_outlined;

      case 'wallet_withdrawal':
        return Icons.payments_outlined;

      case 'wallet_withdrawal_rejected':
        return Icons.cancel_outlined;

      default:
        return Icons.notifications_outlined;
    }
  }

  // =========================================================
  // NOTIFICATION COLOR
  // =========================================================

  Color _notificationColor(String type) {
    switch (type) {
      // -------------------------------------------------------
      // ORDER
      // -------------------------------------------------------

      case 'delivered':
        return Colors.green;

      case 'cancelled':
        return Colors.red;

      case 'shipped':
        return Colors.blue;

      // -------------------------------------------------------
      // RETURN / REFUND
      // -------------------------------------------------------

      case 'return':
      case 'refund':
      case 'return_refund':
        return Colors.orange;

      // -------------------------------------------------------
      // SELLER
      // -------------------------------------------------------

      case 'seller':
        return Colors.purple;

      // -------------------------------------------------------
      // PAYMENT
      // -------------------------------------------------------

      case 'payment':
        return Colors.teal;

      // -------------------------------------------------------
      // REVIEW
      // -------------------------------------------------------

      case 'review':
        return Colors.amber;

      // -------------------------------------------------------
      // WALLET
      // -------------------------------------------------------

      case 'wallet_deposit':
        return Colors.green;

      case 'wallet_deposit_rejected':
        return Colors.red;

      case 'wallet_withdrawal':
        return Colors.blue;

      case 'wallet_withdrawal_rejected':
        return Colors.red;

      default:
        return Colors.redAccent;
    }
  }

  // =========================================================
  // MARK ONE AS READ
  // =========================================================

  Future<void> _markAsRead(
    String notificationId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // =========================================================
  // MARK ALL AS READ
  // =========================================================

  Future<void> _markAllAsRead(
    BuildContext context,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where(
            'isRead',
            isEqualTo: false,
          )
          .get();

      if (snapshot.docs.isEmpty) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'All notifications are already read.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );

        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in snapshot.docs) {
        batch.update(
          doc.reference,
          {
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          },
        );
      }

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'All notifications marked as read.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not update notifications. Please try again.',
            ),
          ),
        );
      }
    }
  }

  // =========================================================
  // NOTIFICATION DETAILS
  // =========================================================

  void _showNotificationDetails(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final title =
        (data['title'] ?? 'Notification').toString();

    final message =
        (data['message'] ?? '').toString();

    final orderId =
        (data['orderId'] ?? '').toString();

    final type =
        (data['type'] ?? 'general').toString();

    final amount = data['amount'];

    final paymentMethod =
        (data['paymentMethodName'] ??
                data['withdrawalMethodName'] ??
                '')
            .toString();

    // ---------------------------------------------------------
    // SUPPORT BOTH:
    // reason
    // rejectionReason
    // ---------------------------------------------------------

    final reason =
        (data['reason'] ??
                data['rejectionReason'] ??
                '')
            .toString();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                _notificationIcon(type),
                color: _notificationColor(type),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(message),

              // ------------------------------------------------
              // WALLET AMOUNT
              // ------------------------------------------------

              if (amount is num) ...[
                const SizedBox(height: 12),
                Text(
                  'Amount: ৳${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],

              // ------------------------------------------------
              // PAYMENT / WITHDRAWAL METHOD
              // ------------------------------------------------

              if (paymentMethod.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Method: $paymentMethod',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              // ------------------------------------------------
              // REJECTION REASON
              // ------------------------------------------------

              if (reason.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Reason: $reason',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              // ------------------------------------------------
              // ORDER ID
              // ------------------------------------------------

              if (orderId.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Order ID: $orderId',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // OPEN NOTIFICATION
  // =========================================================

  Future<void> _openNotification(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final type =
        (data['type'] ?? 'general').toString();

    final requestType =
        (data['requestType'] ?? '').toString();

    // ---------------------------------------------------------
    // RETURN / REFUND
    // ---------------------------------------------------------

    final isReturnRefund =
        type == 'return_refund' ||
        type == 'return' ||
        type == 'refund' ||
        requestType == 'return' ||
        requestType == 'refund';

    if (isReturnRefund) {
      final requestId =
          (data['requestId'] ?? '').toString();

      final orderId =
          (data['orderId'] ?? '').toString();

      final sellerOrderId =
          (data['sellerOrderId'] ?? '').toString();

      final sellerId =
          (data['sellerId'] ?? '').toString();

      final sellerCode =
          (data['sellerCode'] ?? '').toString();

      final productId =
          (data['productId'] ?? '').toString();

      if (!context.mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ReturnRefundRequestDetailsPage(
            requestId: requestId,
            orderId: orderId,
            sellerOrderId: sellerOrderId,
            sellerId: sellerId,
            sellerCode: sellerCode,
            productId: productId,
          ),
        ),
      );

      return;
    }

    // ---------------------------------------------------------
    // WALLET
    // ---------------------------------------------------------

    final isWalletNotification =
        type == 'wallet_deposit' ||
        type == 'wallet_deposit_rejected' ||
        type == 'wallet_withdrawal' ||
        type == 'wallet_withdrawal_rejected';

    if (isWalletNotification) {
      if (!context.mounted) return;

      _showNotificationDetails(
        context,
        data,
      );

      return;
    }

    // ---------------------------------------------------------
    // OTHER NOTIFICATIONS
    // ---------------------------------------------------------

    if (context.mounted) {
      _showNotificationDetails(
        context,
        data,
      );
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
        ),
        body: const Center(
          child: Text(
            'Please log in to view notifications.',
          ),
        ),
      );
    }

    final notificationReference =
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'read') {
                _markAllAsRead(context);
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem<String>(
                  value: 'read',
                  child: Text(
                    'Mark all as read',
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: notificationReference
            .orderBy(
              'createdAt',
              descending: true,
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(24),
                child: Text(
'Could not load notifications.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final documents =
              snapshot.data?.docs ?? [];

          if (documents.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {},
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Icon(
                    Icons.notifications_none,
                    size: 70,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      'No Notifications Yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Your BuyNova notifications will appear here.',
                      textAlign:
                          TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding:
                const EdgeInsets.all(12),
            itemCount: documents.length,
            itemBuilder:
                (context, index) {
              final document =
                  documents[index];

              final data =
                  document.data();

              final type =
                  (data['type'] ??
                          'general')
                      .toString();

              final title =
                  (data['title'] ??
                          'Notification')
                      .toString();

              final message =
                  (data['message'] ??
                          '')
                      .toString();

              final isRead =
                  data['isRead'] == true;

              final timestamp =
                  data['createdAt']
                      as Timestamp?;

              final iconColor =
                  _notificationColor(type);

              final isReturnRefund =
                  type ==
                          'return_refund' ||
                      type == 'return' ||
                      type == 'refund' ||
                      data['requestType'] ==
                          'return' ||
                      data['requestType'] ==
                          'refund';

              final isWalletNotification =
                  type ==
                          'wallet_deposit' ||
                      type ==
                          'wallet_deposit_rejected' ||
                      type ==
                          'wallet_withdrawal' ||
                      type ==
                          'wallet_withdrawal_rejected';

              return Card(
                elevation: 0,
                margin:
                    const EdgeInsets.only(
                  bottom: 10,
                ),
                color: isRead
                    ? null
                    : Colors.redAccent
                        .withValues(
                        alpha: 0.06,
                      ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration:
                        BoxDecoration(
                      shape:
                          BoxShape.circle,
                      color:
                          iconColor.withValues(
                        alpha: 0.12,
                      ),
                    ),
                    child: Icon(
                      _notificationIcon(
                        type,
                      ),
                      color: iconColor,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style:
                              TextStyle(
                            fontWeight:
                                isRead
                                    ? FontWeight
                                        .w500
                                    : FontWeight
                                        .bold,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 9,
                          height: 9,
                          decoration:
                              const BoxDecoration(
                            shape:
                                BoxShape
                                    .circle,
                            color:
                                Colors
                                    .redAccent,
                          ),
                        ),
                    ],
                  ),
                  subtitle:
                      Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 5,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          message,
                          maxLines: 2,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                        ),

                        if (timestamp !=
                            null) ...[
                          const SizedBox(
                            height: 5,
                          ),
                          Text(
                            _formatTimestamp(
                              timestamp,
                            ),
                            style:
                                TextStyle(
                              fontSize: 11,
                              color: Colors
                                  .grey
                                  .shade600,
                            ),
                          ),
                        ],

                        // ------------------------------------------------
                        // RETURN / REFUND LABEL
                        // ------------------------------------------------

                        if (isReturnRefund) ...[
                          const SizedBox(
                            height: 4,
                          ),
                          const Text(
                            'Tap to view request details',
                            style:
                                TextStyle(
                              fontSize: 11,
                              color: Colors
                                  .redAccent,
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ],

                        // ------------------------------------------------
                        // WALLET LABEL
                        // ------------------------------------------------

                        if (isWalletNotification) ...[
                          const SizedBox(
                            height: 4,
                          ),
                          const Text(
                            'Tap to view wallet details',
                            style:
                                TextStyle(
                              fontSize: 11,
                              color: Colors
                                  .green,
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  onTap: () async {
                    if (!isRead) {
                      await _markAsRead(
                        document.id,
                      );
                    }

                    if (context.mounted) {
                      await _openNotification(
                        context,
                        data,
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
