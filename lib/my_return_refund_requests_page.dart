import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyReturnRefundRequestsPage extends StatelessWidget {
  const MyReturnRefundRequestsPage({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _requestStream(
    String uid,
  ) {
    return FirebaseFirestore.instance
        .collection('return_refund_requests')
        .where(
          'customerId',
          isEqualTo: uid,
        )
        .snapshots();
  }

  String _statusText(String status) {
    switch (status.toLowerCase()) {
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
    switch (status.toLowerCase()) {
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

  Widget _statusBadge(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
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
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _productImage(String url) {
    if (url.isEmpty) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: 72,
            height: 72,
            color: Colors.grey.shade200,
            child: const Icon(
              Icons.broken_image_outlined,
              color: Colors.grey,
            ),
          );
        },
      ),
    );
  }

  void _showDetails(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final type =
        data['requestType']?.toString() ?? 'return';

    final status =
        data['status']?.toString() ?? 'pending';

    final reason =
        data['reason']?.toString() ?? '';

    final details =
        data['details']?.toString() ?? '';

    final orderId =
        data['orderId']?.toString() ?? '';

    final sellerCode =
        data['sellerCode']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            type == 'refund'
                ? 'Refund Request'
                : 'Return Request',
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Status: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _statusBadge(status),
                  ],
                ),

                const SizedBox(height: 16),

                Text(
                  'Order ID: $orderId',
                ),

                if (sellerCode.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Seller: $sellerCode',
                  ),
                ],

                const SizedBox(height: 14),

                const Text(
                  'Reason',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  reason.isEmpty
                      ? 'Not provided'
                      : reason,
                ),

                if (details.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(details),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _requestCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final type =
        data['requestType']?.toString() ?? 'return';

    final status =
        data['status']?.toString() ?? 'pending';

    final productName =
        data['productName']?.toString() ?? 'Product';

    final imageUrl =
        data['productImageUrl']?.toString() ?? '';

    final quantity =
        (data['quantity'] as num?)?.toInt() ?? 1;

    final price =
        (data['price'] as num?)?.toDouble() ?? 0;

    final orderId =
        data['orderId']?.toString() ?? '';

    final reason =
        data['reason']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _showDetails(
            context,
            data,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    type == 'refund'
                        ? Icons.currency_exchange
                        : Icons.assignment_return_outlined,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      type == 'refund'
                          ? 'Refund Request'
                          : 'Return Request',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _statusBadge(status),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _productImage(imageUrl),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Qty: $quantity',
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Price: ৳${price.toStringAsFixed(0)}',
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Order: $orderId',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (reason.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Reason: $reason',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Tap to view details',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Return & Refund Requests',
          ),
        ),
        body: const Center(
          child: Text(
            'Please login first.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Return & Refund Requests',
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _requestStream(user.uid),
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
                padding: const EdgeInsets.all(20),
                child: const Text(
                  'Could not load your requests. Please try again.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final requests =
              snapshot.data?.docs ?? [];

          if (requests.isEmpty) {
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
                      'No Return or Refund Requests',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your return and refund requests will appear here.',
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
                    const Icon(
                      Icons.assignment_return_outlined,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Requests',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${requests.length} request${requests.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              ...requests.map(
                (doc) => _requestCard(
                  context,
                  doc,
                ),
              ),

              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}
