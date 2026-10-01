import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'order_tracking_page.dart';
import 'order_details_page.dart';

class MyOrdersPage extends StatelessWidget {
  const MyOrdersPage({super.key});

  String _statusText(String status) {
    switch (status) {
      case 'placed':
        return 'Order Placed';
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

  bool _canCancel(String status) {
    return status == 'placed' ||
        status == 'confirmed' ||
        status == 'processing';
  }

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      final hour = date.hour == 0
          ? 12
          : (date.hour > 12 ? date.hour - 12 : date.hour);

      final minute = date.minute.toString().padLeft(2, '0');

      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '$day/$month/$year $hour:$minute $period';
    }

    return 'Date unavailable';
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

  /// Converts Firestore item data into a clean Map.
  Map<String, dynamic> _itemMap(dynamic item) {
    if (item is Map<String, dynamic>) {
      return item;
    }

    if (item is Map) {
      return Map<String, dynamic>.from(item);
    }

    return <String, dynamic>{};
  }

  /// Calculates subtotal directly from order items.
  ///
  /// This is used as a fallback when sellerSubtotal/subtotal/
  /// sellingTotal is missing or stored as 0.
  double _calculateItemsSubtotal(
    List<Map<String, dynamic>> items,
  ) {
    double subtotal = 0;

    for (final item in items) {
      final quantity = _int(item['quantity'] ?? 1);

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

  /// Gets the seller/reseller subtotal.
  ///
  /// First uses the value stored in Firestore.
  /// If it is missing/0, calculates it from the items.
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

  Widget _statusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusText(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.image_outlined,
        color: Colors.grey.shade500,
      ),
    );
  }

  Widget _buildProductItem(
    Map<String, dynamic> item,
  ) {
    final name = (item['name'] ?? 'Product').toString();

    final imageUrl = (
      item['imageUrl'] ??
          item['productImageUrl'] ??
          ''
    ).toString();

    final quantity = _int(
      item['quantity'] ?? 1,
    );

    final price = _number(
      item['price'] ??
          item['sellingPrice'] ??
          item['unitPrice'] ??
          item['productPrice'],
    );

    Widget image;

    if (imageUrl.isNotEmpty) {
      image = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          imageUrl,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return _imagePlaceholder();
          },
        ),
      );
    } else {
      image = _imagePlaceholder();
    }

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          image,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Quantity: $quantity',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '৳${(price * quantity).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelSellerOrder(
    BuildContext context,
    String sellerOrderId,
    Map<String, dynamic> sellerOrderData, {
    String collectionName = 'seller_orders',
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    final customerId = (
      sellerOrderData['customerId'] ?? ''
    ).toString();

    if (customerId != currentUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You cannot cancel this order.',
          ),
        ),
      );
      return;
    }

    final currentStatus = (
      sellerOrderData['orderStatus'] ?? 'placed'
    ).toString();

    if (!_canCancel(currentStatus)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This order cannot be cancelled because it is already ${_statusText(currentStatus)}.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Order?'),
          content: const Text(
            'Are you sure you want to cancel this order?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Yes, Cancel',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final sellerOrderRef = FirebaseFirestore.instance
          .collection(collectionName)
          .doc(sellerOrderId);

      final latestSnapshot = await sellerOrderRef.get();

      if (!latestSnapshot.exists) {
        throw Exception(
          'Seller order not found.',
        );
      }

      final latestData = latestSnapshot.data() ?? {};

      final latestCustomerId = (
        latestData['customerId'] ?? ''
      ).toString();

      if (latestCustomerId != currentUser.uid) {
        throw Exception(
          'You cannot cancel this order.',
        );
      }

      final latestStatus = (
        latestData['orderStatus'] ?? 'placed'
      ).toString();

      if (!_canCancel(latestStatus)) {
        throw Exception(
          'This order can no longer be cancelled.',
        );
      }

      await sellerOrderRef.update({
        'orderStatus': 'cancelled',
        'cancelledBy': 'customer',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Order cancelled successfully.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not cancel order: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSellerOrderCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    String collectionName = 'seller_orders',
    String fallbackLabel = 'Seller Order',
  }) {
    final data = doc.data();

    final sellerCode = (
      data['sellerCode'] ?? fallbackLabel
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

    final subtotal = _getSellerSubtotal(
      data,
      items,
    );

    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _statusChip(status),
              ],
            ),

            const SizedBox(height: 14),

            if (items.isNotEmpty)
              ...items.map(
                _buildProductItem,
              ),

            const Divider(),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Seller Subtotal',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '৳${subtotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (_canCancel(status))
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _cancelSellerOrder(
                      context,
                      doc.id,
                      data,
                      collectionName: collectionName,
                    );
                  },
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Cancel Order',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openOrderDetails(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> orderDoc,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sellerOrders,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailsPage(
          orderId: orderDoc.id,
          orderData: orderDoc.data(),
          sellerOrders: sellerOrders,
        ),
      ),
    );
  }

  Widget _buildMainOrderCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> orderDoc,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sellerOrders, {
    List<QueryDocumentSnapshot<Map<String, dynamic>>> resellerOrders =
        const [],
  }) {
    final data = orderDoc.data();

    final orderId = orderDoc.id;

    final mainStatus = (
      data['orderStatus'] ?? 'placed'
    ).toString();

    final total = _number(
      data['total'],
    );

    final createdAt = _formatDate(
      data['createdAt'],
    );

    return Card(
      margin: const EdgeInsets.only(
        bottom: 22,
      ),
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _openOrderDetails(
            context,
            orderDoc,
            sellerOrders,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '#$orderId',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusChip(mainStatus),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                createdAt,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 14),

              if (total > 0)
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Order Total',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '৳${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 8),

              const Row(
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 16,
                    color: Colors.redAccent,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Tap this order to view details',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OrderTrackingPage(
                          orderId: orderId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.local_shipping_outlined,
                  ),
                  label: const Text(
                    'Track Order',
                  ),
                ),
              ),

              if (sellerOrders.isNotEmpty) ...[
                const SizedBox(height: 18),

                const Text(
                  'Seller Orders',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                ...sellerOrders.map(
                  (sellerOrder) =>
                      _buildSellerOrderCard(
                    context,
                    sellerOrder,
                  ),
                ),
              ],

              if (resellerOrders.isNotEmpty) ...[
                const SizedBox(height: 18),

                const Text(
                  'Reseller Store Orders',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                ...resellerOrders.map(
                  (resellerOrder) =>
                      _buildSellerOrderCard(
                    context,
                    resellerOrder,
                    collectionName:
                        'reseller_orders',
                    fallbackLabel:
                        'Reseller Store',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Orders'),
          centerTitle: true,
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
        title: const Text('My Orders'),
        centerTitle: true,
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where(
              'userId',
              isEqualTo: user.uid,
            )
            .snapshots(),
        builder: (context, orderSnapshot) {
          if (orderSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (orderSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load orders.\n\n'
                  '${orderSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final orderDocs =
              orderSnapshot.data?.docs ?? [];

          if (orderDocs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 70,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'No Orders Yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Your orders will appear here.',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          final sortedOrders = [...orderDocs];

          sortedOrders.sort(
            (a, b) {
              final aTime = a.data()['createdAt'];
              final bTime = b.data()['createdAt'];

              if (aTime is Timestamp &&
                  bTime is Timestamp) {
                return bTime.compareTo(aTime);
              }

              return 0;
            },
          );

          return StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
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
              if (sellerSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (sellerSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Unable to load seller orders.\n\n'
                      '${sellerSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final sellerDocs =
                  sellerSnapshot.data?.docs ?? [];

              final sellerOrdersByOrderId =
                  <String,
                      List<
                          QueryDocumentSnapshot<
                              Map<String, dynamic>>>>{};

              for (final sellerDoc in sellerDocs) {
                final data = sellerDoc.data();

                final orderId = (
                  data['orderId'] ?? ''
                ).toString();

                if (orderId.isEmpty) {
                  continue;
                }

                sellerOrdersByOrderId
                    .putIfAbsent(
                  orderId,
                  () => [],
                )
                    .add(sellerDoc);
              }

              return StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('reseller_orders')
                    .where(
                      'customerId',
                      isEqualTo: user.uid,
                    )
                    .snapshots(),
                builder: (
                  context,
                  resellerSnapshot,
                ) {
                  if (resellerSnapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(20),
                        child: Text(
                          'Unable to load reseller orders.\n\n'
                          '${resellerSnapshot.error}',
                          textAlign:
                              TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final resellerDocs =
                      resellerSnapshot.data?.docs ??
                          [];

                  final resellerOrdersByOrderId =
                      <String,
                          List<
                              QueryDocumentSnapshot<
                                  Map<String, dynamic>>>>{};

                  for (final resellerDoc
                      in resellerDocs) {
                    final resellerOrderId = (
                      resellerDoc.data()['orderId'] ?? ''
                    ).toString();

                    if (resellerOrderId.isEmpty) {
                      continue;
                    }

                    resellerOrdersByOrderId
                        .putIfAbsent(
                      resellerOrderId,
                      () => [],
                    )
                        .add(resellerDoc);
                  }

                  return ListView.builder(
                    padding:
                        const EdgeInsets.all(16),
                    itemCount:
                        sortedOrders.length,
                    itemBuilder:
                        (context, index) {
                      final orderDoc =
                          sortedOrders[index];

                      final sellerOrders =
                          sellerOrdersByOrderId[
                                  orderDoc.id] ??
                              [];

                      final resellerOrders =
                          resellerOrdersByOrderId[
                                  orderDoc.id] ??
                              [];

                      return _buildMainOrderCard(
                        context,
                        orderDoc,
                        sellerOrders,
                        resellerOrders:
                            resellerOrders,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
