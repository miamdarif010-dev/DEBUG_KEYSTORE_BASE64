import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OrderTrackingPage extends StatelessWidget {
  final String orderId;

  const OrderTrackingPage({
    super.key,
    required this.orderId,
  });

  String _statusText(String status) {
    switch (status) {
      case 'placed':
        return 'Order Placed';
      case 'confirmed':
        return 'Order Confirmed';
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
      case 'refunded':
        return 'Refunded';
      default:
        return 'Order Placed';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'placed':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.indigo;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'returned':
        return Colors.brown;
      case 'refunded':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  int _statusIndex(String status) {
    switch (status) {
      case 'placed':
        return 0;
      case 'confirmed':
        return 1;
      case 'processing':
        return 2;
      case 'shipped':
        return 3;
      case 'delivered':
        return 4;
      default:
        return 0;
    }
  }

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  int _int(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  Map<String, dynamic> _itemMap(dynamic item) {
    if (item is Map<String, dynamic>) {
      return item;
    }

    if (item is Map) {
      return Map<String, dynamic>.from(item);
    }

    return <String, dynamic>{};
  }

  double _calculateItemsSubtotal(
    List<Map<String, dynamic>> items,
  ) {
    double subtotal = 0;

    for (final item in items) {
      final quantity = _int(
        item['quantity'] ?? 1,
      );

      final price = _number(
        item['price'] ??
            item['sellingPrice'] ??
            item['unitPrice'] ??
            item['productPrice'],
      );

      subtotal += price * quantity;
    }

    return subtotal;
  }

  double _getSellerSubtotal(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> items,
  ) {
    final storedSubtotal = _number(
      data['sellerSubtotal'] ??
          data['subtotal'] ??
          data['sellingTotal'],
    );

    if (storedSubtotal > 0) {
      return storedSubtotal;
    }

    return _calculateItemsSubtotal(items);
  }

  String _calculateOverallStatus(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sellerDocs,
    String fallback,
  ) {
    if (sellerDocs.isEmpty) {
      return fallback;
    }

    final statuses = sellerDocs.map((doc) {
      final data = doc.data();

      return (
        data['orderStatus'] ?? 'placed'
      ).toString();
    }).toList();

    // Terminal states have priority.
    if (statuses.every(
      (status) => status == 'refunded',
    )) {
      return 'refunded';
    }

    if (statuses.every(
      (status) => status == 'returned',
    )) {
      return 'returned';
    }

    if (statuses.every(
      (status) => status == 'cancelled',
    )) {
      return 'cancelled';
    }

    // If at least one order is still active,
    // use the furthest active progress.
    if (statuses.any(
      (status) => status == 'delivered',
    )) {
      return 'delivered';
    }

    if (statuses.any(
      (status) => status == 'shipped',
    )) {
      return 'shipped';
    }

    if (statuses.any(
      (status) => status == 'processing',
    )) {
      return 'processing';
    }

    if (statuses.any(
      (status) => status == 'confirmed',
    )) {
      return 'confirmed';
    }

    return 'placed';
  }

  Widget _buildStep({
    required String title,
    required IconData icon,
    required bool active,
    required bool completed,
    required bool showLine,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed || active
                    ? Colors.redAccent
                    : Colors.grey.shade300,
              ),
              child: Icon(
                completed
                    ? Icons.check
                    : icon,
                color: completed || active
                    ? Colors.white
                    : Colors.grey.shade600,
              ),
            ),
            if (showLine)
              Container(
                width: 2,
                height: 38,
                color: completed
                    ? Colors.redAccent
                    : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Padding(
          padding: const EdgeInsets.only(
            top: 10,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight:
                  active || completed
                      ? FontWeight.bold
                      : FontWeight.normal,
              color:
                  active || completed
                      ? Colors.black
                      : Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTerminalStatus(
    String status,
  ) {
    final color = _statusColor(status);

    IconData icon;

    switch (status) {
      case 'cancelled':
        icon = Icons.cancel_outlined;
        break;
      case 'returned':
        icon = Icons.keyboard_return_outlined;
        break;
      case 'refunded':
        icon = Icons.payments_outlined;
        break;
      default:
        icon = Icons.info_outline;
    }

    String message;

    switch (status) {
      case 'cancelled':
        message =
            'This order has been cancelled.';
        break;
      case 'returned':
        message =
            'This order has been returned.';
        break;
      case 'refunded':
        message =
            'This order has been refunded.';
        break;
      default:
        message = _statusText(status);
    }

    return Card(
      color: color.withValues(
        alpha: 0.08,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: color,
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTracking(
    String status,
  ) {
    if (status == 'cancelled' ||
        status == 'returned' ||
        status == 'refunded') {
      return _buildTerminalStatus(
        status,
      );
    }

    final index =
        _statusIndex(status);

    return Card(
      elevation: 2,
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildStep(
              title: 'Order Placed',
              icon:
                  Icons.receipt_long_outlined,
              active: index >= 0,
              completed: index > 0,
              showLine: true,
            ),
            _buildStep(
              title: 'Confirmed',
              icon:
                  Icons.verified_outlined,
              active: index >= 1,
              completed: index > 1,
              showLine: true,
            ),
            _buildStep(
              title: 'Processing',
              icon:
                  Icons.inventory_2_outlined,
              active: index >= 2,
              completed: index > 2,
              showLine: true,
            ),
            _buildStep(
              title: 'Shipped',
              icon:
                  Icons.local_shipping_outlined,
              active: index >= 3,
              completed: index > 3,
              showLine: true,
            ),
            _buildStep(
              title: 'Delivered',
              icon:
                  Icons.home_outlined,
              active: index >= 4,
              completed: false,
              showLine: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerOrderCard(
    QueryDocumentSnapshot<
        Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final sellerCode = (
      data['sellerCode'] ?? 'Seller'
    ).toString();

    final status = (
      data['orderStatus'] ?? 'placed'
    ).toString();

    final itemsRaw = data['items'];

    final items = itemsRaw is List
        ? itemsRaw
            .map(_itemMap)
            .where(
              (item) => item.isNotEmpty,
            )
            .toList()
        : <Map<String, dynamic>>[];

    final subtotal =
        _getSellerSubtotal(
      data,
      items,
    );

    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      elevation: 2,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sellerCode,
                    style:
                        const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration:
                      BoxDecoration(
                    color: _statusColor(
                      status,
                    ).withValues(
                      alpha: 0.12,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Text(
                    _statusText(status),
                    style: TextStyle(
                      color: _statusColor(
                        status,
                      ),
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            if (items.isNotEmpty)
              ...items.map(
                (item) {
                  final name = (
                    item['name'] ??
                        'Product'
                  ).toString();

                  final quantity = _int(
                    item['quantity'] ?? 1,
                  );

                  final price = _number(
                    item['price'] ??
                        item[
                            'sellingPrice'] ??
                        item['unitPrice'] ??
                        item[
                            'productPrice'],
                  );

                  return Padding(
                    padding:
                        const EdgeInsets
                            .only(
                      bottom: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons
                              .shopping_bag_outlined,
                          size: 18,
                          color: Colors.grey,
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Expanded(
                          child: Text(
                            '$name × $quantity',
                            style:
                                const TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          '৳${(price * quantity).toStringAsFixed(0)}',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            const Divider(),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
              children: [
                const Text(
                  'Seller Subtotal',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                Text(
                  '৳${subtotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Colors.redAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title:
              const Text('Order Tracking'),
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
        title:
            const Text('Order Tracking'),
        centerTitle: true,
      ),
      body: StreamBuilder<
          DocumentSnapshot<
              Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .snapshots(),
        builder: (
          context,
          orderSnapshot,
        ) {
          if (orderSnapshot
                  .connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (orderSnapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(20),
                child: Text(
                  'Unable to load order.\n\n'
                  '${orderSnapshot.error}',
                  textAlign:
                      TextAlign.center,
                ),
              ),
            );
          }

          if (!orderSnapshot.hasData ||
              !orderSnapshot
                  .data!
                  .exists) {
            return const Center(
              child: Text(
                'Order not found.',
              ),
            );
          }

          final orderData =
              orderSnapshot.data!
                      .data() ??
                  {};

          final fallbackStatus = (
            orderData['orderStatus'] ??
                'placed'
          ).toString();

          final customerId = (
            orderData['userId'] ?? ''
          ).toString();

          if (customerId != user.uid) {
            return const Center(
              child: Text(
                'You are not allowed to view this order.',
              ),
            );
          }

          return StreamBuilder<
              QuerySnapshot<
                  Map<String, dynamic>>>(
            stream: FirebaseFirestore
                .instance
                .collection('seller_orders')
                .where(
                  'customerId',
                  isEqualTo: user.uid,
                )
                .snapshots(),
            builder: (
              context,
              sellerSnapshot,
            ) {
              if (sellerSnapshot
                      .connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              if (sellerSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      20,
                    ),
                    child: Text(
                      'Unable to load seller orders.\n\n'
                      '${sellerSnapshot.error}',
                      textAlign:
                          TextAlign.center,
                    ),
                  ),
                );
              }

              final allSellerDocs =
                  sellerSnapshot.data?.docs ??
                      [];

              final sellerDocs =
                  allSellerDocs.where(
                (doc) {
                  final data =
                      doc.data();

                  return data['orderId']
                          ?.toString() ==
                      orderId;
                },
              ).toList();

              final overallStatus =
                  _calculateOverallStatus(
                sellerDocs,
                fallbackStatus,
              );

              return ListView(
                padding:
                    const EdgeInsets.all(16),
                children: [
                  Text(
                    'Order #$orderId',
                    style:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Row(
                    children: [
                      const Text(
                        'Overall Status: ',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                      Text(
                        _statusText(
                          overallStatus,
                        ),
                        style: TextStyle(
                          color:
                              _statusColor(
                            overallStatus,
                          ),
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  _buildTracking(
                    overallStatus,
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  if (sellerDocs.isNotEmpty) ...[
                    const Text(
                      'Seller Orders',
                      style:
                          TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    ...sellerDocs.map(
                      _buildSellerOrderCard,
                    ),
                  ],

                  if (sellerDocs.isEmpty)
                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(
                          20,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons
                                  .info_outline,
                              size: 40,
                              color: Colors
                                  .grey
                                  .shade500,
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            const Text(
                              'Seller order details are not available yet.',
                              textAlign:
                                  TextAlign
                                      .center,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
