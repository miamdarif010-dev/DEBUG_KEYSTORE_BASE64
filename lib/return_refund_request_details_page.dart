import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReturnRefundRequestDetailsPage
    extends StatelessWidget {
  final String requestId;
  final String orderId;
  final String sellerOrderId;
  final String sellerId;
  final String sellerCode;
  final String productId;

  const ReturnRefundRequestDetailsPage({
    super.key,
    required this.requestId,
    required this.orderId,
    required this.sellerOrderId,
    required this.sellerId,
    required this.sellerCode,
    required this.productId,
  });

  String _statusText(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'processing':
        return 'Processing';
      case 'rejected':
        return 'Rejected';
      case 'completed':
        return 'Completed';
      default:
        return 'Pending';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.blue;
      case 'processing':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  String _requestTypeText(String type) {
    if (type == 'refund') {
      return 'Refund Request';
    }

    return 'Return Request';
  }

  IconData _requestTypeIcon(String type) {
    if (type == 'refund') {
      return Icons.currency_exchange;
    }

    return Icons.assignment_return_outlined;
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusText(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _infoRow(
    String title,
    String value, {
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 20,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? 'N/A' : value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productImage(String url) {
    if (url.isEmpty) {
      return Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey,
          size: 32,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url,
        width: 92,
        height: 92,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: 92,
            height: 92,
            color: Colors.grey.shade200,
            child: const Icon(
              Icons.broken_image_outlined,
              color: Colors.grey,
              size: 32,
            ),
          );
        },
      ),
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?>
      _findRequest(
    String uid,
  ) async {
    final collection = FirebaseFirestore.instance
        .collection('return_refund_requests');

    if (requestId.isNotEmpty) {
      final direct =
          await collection.doc(requestId).get();

      if (direct.exists) {
        final data = direct.data();

        if (data != null &&
            data['customerId']?.toString() == uid) {
          return direct;
        }
      }
    }

    final snapshot = await collection
        .where(
          'customerId',
          isEqualTo: uid,
        )
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final sameOrder =
          orderId.isEmpty ||
          data['orderId']?.toString() == orderId;

      final sameSellerOrder =
          sellerOrderId.isEmpty ||
          data['sellerOrderId']?.toString() ==
              sellerOrderId;

      final sameSeller =
          sellerId.isEmpty ||
          data['sellerId']?.toString() == sellerId;

      final sameProduct =
          productId.isEmpty ||
          data['productId']?.toString() == productId;

      if (sameOrder &&
          sameSellerOrder &&
          sameSeller &&
          sameProduct) {
        return doc;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Request Details',
          ),
        ),
        body: const Center(
          child: Text(
            'Please log in first.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Return / Refund Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<
          DocumentSnapshot<Map<String, dynamic>>?>(
        future: _findRequest(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load request details.\n\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final document = snapshot.data;

          if (document == null ||
              !document.exists) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.assignment_return_outlined,
                      size: 70,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Request Not Found',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The return/refund request could not be found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = document.data()!;

          final requestType =
              data['requestType']?.toString() ??
                  'return';

          final status =
              data['status']?.toString() ??
                  'pending';

          final productName =
              data['productName']?.toString() ??
                  'Product';

          final productImage =
              data['productImageUrl']?.toString() ??
                  '';

          final customerName =
              data['customerName']?.toString() ??
                  '';

          final customerEmail =
              data['customerEmail']?.toString() ??
                  '';

          final requestOrderId =
              data['orderId']?.toString() ??
                  orderId;

          final requestSellerOrderId =
              data['sellerOrderId']?.toString() ??
                  sellerOrderId;

          final requestSellerId =
              data['sellerId']?.toString() ??
                  sellerId;

          final requestSellerCode =
              data['sellerCode']?.toString() ??
                  sellerCode;

          final requestProductId =
              data['productId']?.toString() ??
                  productId;

          final reason =
              data['reason']?.toString() ?? '';

          final details =
              data['details']?.toString() ?? '';

          final sellerMessage =
              data['sellerMessage']?.toString() ??
                  data['sellerNote']?.toString() ??
                  '';

          final quantity =
              (data['quantity'] as num?)
                      ?.toInt() ??
                  1;

          final price =
              (data['price'] as num?)
                      ?.toDouble() ??
                  0;

          final total =
              (data['total'] as num?)
                      ?.toDouble() ??
                  price * quantity;

          final refundAmount =
              (data['refundAmount'] as num?)
                      ?.toDouble() ??
                  0;

          final createdAt =
              data['createdAt'] as Timestamp?;

          final updatedAt =
              data['updatedAt'] as Timestamp?;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.redAccent,
                      Colors.red.shade700,
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      _requestTypeIcon(
                        requestType,
                      ),
                      color: Colors.white,
                      size: 38,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            _requestTypeText(
                              requestType,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Request ID: ${document.id}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              productName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                          _statusBadge(status),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          _productImage(
                            productImage,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quantity: $quantity',
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Price: ৳${price.toStringAsFixed(0)}',
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Total: ৳${total.toStringAsFixed(0)}',
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                if (refundAmount > 0) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Refunded to your wallet: '
                                    '৳${refundAmount.toStringAsFixed(2)}',
                                    style:
                                        const TextStyle(
                                      color: Colors.green,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Request Information',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 18),

                      _infoRow(
                        'Request Type',
                        _requestTypeText(
                          requestType,
                        ),
                        icon: _requestTypeIcon(
                          requestType,
                        ),
                      ),

                      _infoRow(
                        'Order ID',
                        requestOrderId,
                        icon: Icons.receipt_long_outlined,
                      ),

                      _infoRow(
                        'Seller Order ID',
                        requestSellerOrderId,
                        icon: Icons.inventory_2_outlined,
                      ),

                      _infoRow(
                        'Seller ID',
                        requestSellerId,
                        icon: Icons.storefront_outlined,
                      ),

                      _infoRow(
                        'Seller Code',
                        requestSellerCode,
                        icon: Icons.badge_outlined,
                      ),

                      _infoRow(
                        'Product ID',
                        requestProductId,
                        icon: Icons.shopping_bag_outlined,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer Information',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 18),

                      _infoRow(
                        'Customer Name',
                        customerName,
                        icon: Icons.person_outline,
                      ),

                      _infoRow(
                        'Customer Email',
                        customerEmail,
                        icon: Icons.email_outlined,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer Reason',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        reason.isEmpty
                            ? 'Not provided'
                            : reason,
                        style: const TextStyle(
                          fontSize: 15,
                        ),
                      ),

                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          'Customer Details',
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          details,
                          style:
                              const TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              if (sellerMessage.isNotEmpty) ...[
                const SizedBox(height: 14),

                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Seller Message',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          sellerMessage,
                          style:
                              const TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 14),

              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Timeline',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 18),

                      if (createdAt != null)
                        _infoRow(
                          'Request Created',
                          _formatTimestamp(
                            createdAt,
                          ),
                          icon:
                              Icons.schedule_outlined,
                        ),

                      if (updatedAt != null)
                        _infoRow(
                          'Last Updated',
                          _formatTimestamp(
                            updatedAt,
                          ),
                          icon:
                              Icons.update_outlined,
                        ),

                      if (status == 'approved' &&
                          data['approvedAt']
                              is Timestamp)
                        _infoRow(
                          'Approved At',
                          _formatTimestamp(
                            data['approvedAt']
                                as Timestamp,
                          ),
                          icon:
                              Icons.check_circle_outline,
                        ),

                      if (status == 'rejected' &&
                          data['rejectedAt']
                              is Timestamp)
                        _infoRow(
                          'Rejected At',
                          _formatTimestamp(
                            data['rejectedAt']
                                as Timestamp,
                          ),
                          icon:
                              Icons.cancel_outlined,
                        ),

                      if (status == 'completed' &&
                          data['completedAt']
                              is Timestamp)
                        _infoRow(
                          'Completed At',
                          _formatTimestamp(
                            data['completedAt']
                                as Timestamp,
                          ),
                          icon:
                              Icons.task_alt_outlined,
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  String _formatTimestamp(
    Timestamp timestamp,
  ) {
    final date = timestamp.toDate();

    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);

    final minute =
        date.minute.toString().padLeft(2, '0');

    final period =
        date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day}/${date.month}/${date.year} '
        '$hour:$minute $period';
  }
}
