import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'order_tracking_page.dart';
import 'return_refund_request_page.dart';

class OrderDetailsPage extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> sellerOrders;

  const OrderDetailsPage({
    super.key,
    required this.orderId,
    required this.orderData,
    required this.sellerOrders,
  });

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  bool _isCancelling = false;

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

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      final hour = date.hour == 0
          ? 12
          : (date.hour > 12
              ? date.hour - 12
              : date.hour);

      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '$day/$month/$year $hour:$minute $period';
    }

    return 'Date unavailable';
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
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

  Widget _sectionTitle(
    String title,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.redAccent,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    String title,
    String value, {
    IconData? icon,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.image_outlined,
        color: Colors.grey.shade500,
        size: 32,
      ),
    );
  }

  Widget _productImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return _imagePlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: 76,
        height: 76,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return _imagePlaceholder();
        },
      ),
    );
  }

  Widget _productCard(
    Map<String, dynamic> item,
  ) {
    final name =
        (item['productName'] ??
                item['name'] ??
                'Product')
            .toString();

    final imageUrl =
        (item['imageUrl'] ??
                item['productImageUrl'] ??
                '')
            .toString();

    final quantity = _int(
      item['quantity'] ?? 1,
    );

    final price = _number(
      item['price'],
    );

    final itemTotal = _number(
      item['total'],
    );

    final calculatedTotal = price * quantity;

    final total = itemTotal > 0
        ? itemTotal
        : calculatedTotal;

    return Card(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _productImage(imageUrl),
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
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '৳${price.toStringAsFixed(0)} × $quantity',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '৳${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sellerProductCard({
    required Map<String, dynamic> item,
    required String sellerId,
    required String sellerCode,
    required String sellerOrderId,
    required String sellerStatus,
    required bool isResellerOrder,
  }) {
    final name =
        (item['productName'] ??
                item['name'] ??
                'Product')
            .toString();

    final productId =
        (item['productId'] ?? '').toString();

    final imageUrl =
        (item['imageUrl'] ??
                item['productImageUrl'] ??
                '')
            .toString();

    final quantity = _int(
      item['quantity'] ?? 1,
    );

    final price = _number(
      item['price'],
    );

    final itemTotal = _number(
      item['total'],
    );

    final total = itemTotal > 0
        ? itemTotal
        : price * quantity;

    final canRequest =
        !isResellerOrder &&
        sellerStatus == 'delivered' &&
        sellerId.isNotEmpty &&
        sellerOrderId.isNotEmpty &&
        productId.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _productImage(imageUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '৳${price.toStringAsFixed(0)} × $quantity',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '৳${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (canRequest) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ReturnRefundRequestPage(
                          orderId: widget.orderId,
                          sellerOrderId: sellerOrderId,
                          sellerId: sellerId,
                          sellerCode: sellerCode,
                          product: {
                            'productId': productId,
                            'productName': name,
                            'imageUrl': imageUrl,
                            'quantity': quantity,
                            'price': price,
                            'total': total,
                          },
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.assignment_return_outlined,
                    color: Colors.redAccent,
                  ),
                  label: const Text(
                    'Return / Refund',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Colors.redAccent,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _mainItems() {
    final raw = widget.orderData['items'];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  Future<void> _cancelOrder({
    required String collectionName,
    required QueryDocumentSnapshot<
            Map<String, dynamic>>
        orderDoc,
  }) async {
    if (_isCancelling) {
      return;
    }

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Please login again.',
        error: true,
      );
      return;
    }

    final data = orderDoc.data();

    final customerId =
        (data['customerId'] ?? '').toString();

    if (customerId != user.uid) {
      _showMessage(
        'You cannot cancel this order.',
        error: true,
      );
      return;
    }

    final status =
        (data['orderStatus'] ?? 'placed').toString();

    if (!_canCancel(status)) {
      _showMessage(
        'This order can no longer be cancelled.',
        error: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Order?'),
          content: Text(
            collectionName == 'reseller_orders'
                ? 'Are you sure you want to cancel this reseller order?'
                : 'Are you sure you want to cancel this seller order?',
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
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isCancelling = true;
    });

    try {
      final ref = FirebaseFirestore.instance
          .collection(collectionName)
          .doc(orderDoc.id);

      final latest = await ref.get();

      if (!latest.exists) {
        throw Exception('Order not found.');
      }

      final latestData = latest.data() ?? {};

      final latestCustomerId =
          (latestData['customerId'] ?? '').toString();

      if (latestCustomerId != user.uid) {
        throw Exception(
          'You cannot cancel this order.',
        );
      }

      final latestStatus =
          (latestData['orderStatus'] ?? 'placed')
              .toString();

      if (!_canCancel(latestStatus)) {
        throw Exception(
          'This order can no longer be cancelled.',
        );
      }

      await ref.update({
        'orderStatus': 'cancelled',
        'cancelledBy': 'customer',
        'cancelledAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      _showMessage(
        collectionName == 'reseller_orders'
            ? 'Reseller order cancelled successfully.'
            : 'Order cancelled successfully.',
      );
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      String message;

      if (e.code == 'permission-denied') {
        message =
            'You do not have permission to cancel this order.';
      } else if (e.code == 'not-found') {
        message = 'Order was not found.';
      } else {
        message =
            'Could not cancel order: ${e.message ?? e.code}';
      }

      _showMessage(
        message,
        error: true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Could not cancel order: $e',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            error ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _resellerDeliveryNotice() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        top: 10,
        bottom: 12,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.local_shipping_outlined,
            color: Colors.blue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'The Seller will deliver this order directly to you. '
              'The Reseller does not receive or ship the product.',
              style: TextStyle(
                color: Colors.blue.shade800,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderCard({
    required QueryDocumentSnapshot<
            Map<String, dynamic>>
        orderDoc,
    required bool isResellerOrder,
  }) {
    final data = orderDoc.data();

    final sellerCode =
        (data['sellerCode'] ??
                data['sellerName'] ??
                (isResellerOrder
                    ? 'Reseller Store'
                    : 'Seller'))
            .toString();

    final sellerEmail =
        (data['sellerEmail'] ?? '').toString();

    final sellerId =
        (data['sellerId'] ?? '').toString();

    final entrepreneurUid =
        (data['entrepreneurUid'] ?? '').toString();

    final status =
        (data['orderStatus'] ?? 'placed').toString();

    final subtotal = _number(
      isResellerOrder
          ? (data['sellingTotal'] ??
              data['subtotal'] ??
              data['sellerSubtotal'])
          : (data['sellerSubtotal'] ??
              data['subtotal']),
    );

    final couponDiscount = _number(
      data['couponDiscount'] ??
          data['discount'],
    );

    final customerAmount =
        (subtotal - couponDiscount) < 0
            ? 0
            : (subtotal - couponDiscount);

    final rawItems = data['items'];

    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map(
              (item) =>
                  Map<String, dynamic>.from(item),
            )
            .toList()
        : <Map<String, dynamic>>[];

    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
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
                const Icon(
                  Icons.storefront_outlined,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        sellerCode,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (sellerId.isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.only(
                            top: 3,
                          ),
                          child: Text(
                            'Seller ID: $sellerId',
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  Colors.grey.shade600,
                            ),
                          ),
                        ),
                      if (isResellerOrder &&
                          entrepreneurUid.isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.only(
                            top: 3,
                          ),
                          child: Text(
                            'Reseller ID: $entrepreneurUid',
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  Colors.grey.shade600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _statusChip(status),
              ],
            ),
            if (sellerEmail.isNotEmpty) ...[
              const SizedBox(height: 10),
              _infoRow(
                'Seller Email',
                sellerEmail,
                icon: Icons.email_outlined,
              ),
            ],
            if (isResellerOrder)
              _resellerDeliveryNotice(),
            const SizedBox(height: 12),
            if (items.isNotEmpty)
              ...items.map(
                (item) => _sellerProductCard(
                  item: item,
                  sellerId: sellerId,
                  sellerCode: sellerCode,
                  sellerOrderId: orderDoc.id,
                  sellerStatus: status,
                  isResellerOrder:
                      isResellerOrder,
                ),
              ),
            const Divider(),
            _infoRow(
              isResellerOrder
                  ? 'Selling Total'
                  : 'Seller Subtotal',
              '৳${subtotal.toStringAsFixed(0)}',
              bold: true,
            ),
            if (couponDiscount > 0)
              _infoRow(
                'Coupon Discount',
                '-৳${couponDiscount.toStringAsFixed(0)}',
              ),
            _infoRow(
              'Your Order Amount',
              '৳${customerAmount.toStringAsFixed(0)}',
              bold: true,
            ),
            const SizedBox(height: 8),
            if (_canCancel(status))
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isCancelling
                      ? null
                      : () => _cancelOrder(
                            collectionName:
                                isResellerOrder
                                    ? 'reseller_orders'
                                    : 'seller_orders',
                            orderDoc: orderDoc,
                          ),
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
            if (status != 'cancelled') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OrderTrackingPage(
                          orderId: widget.orderId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.local_shipping_outlined,
                  ),
                  label: const Text(
                    'Track This Order',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _orderSummaryCard() {
    final subtotal = _number(
      widget.orderData['subtotal'],
    );

    final deliveryFee = _number(
      widget.orderData['deliveryFee'],
    );

    final discount = _number(
      widget.orderData['discount'] ??
          widget.orderData['couponDiscount'],
    );

    final total = _number(
      widget.orderData['total'],
    );

    final itemCount = _int(
      widget.orderData['itemCount'],
    );

    final totalQuantity = _int(
      widget.orderData['totalQuantity'],
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _infoRow(
              'Products',
              '$itemCount',
            ),
            _infoRow(
              'Total Quantity',
              '$totalQuantity',
            ),
            _infoRow(
              'Subtotal',
              '৳${subtotal.toStringAsFixed(0)}',
            ),
            if (discount > 0)
              _infoRow(
                'Discount',
                '-৳${discount.toStringAsFixed(0)}',
              ),
            _infoRow(
              'Delivery Fee',
              '৳${deliveryFee.toStringAsFixed(0)}',
            ),
            const Divider(height: 20),
            _infoRow(
              'Total',
              '৳${total.toStringAsFixed(0)}',
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FIXED DELIVERY INFORMATION
  // ============================================================

  Widget _deliveryCard() {
    final rawAddress = widget.orderData['address'];

    Map<String, dynamic> addressMap = {};

    if (rawAddress is Map) {
      addressMap = Map<String, dynamic>.from(rawAddress);
    }

    // Sometimes the order may store the whole delivery address
    // under another field such as shippingAddress.
    final rawShippingAddress =
        widget.orderData['shippingAddress'];

    if (addressMap.isEmpty &&
        rawShippingAddress is Map) {
      addressMap =
          Map<String, dynamic>.from(
        rawShippingAddress,
      );
    }

    String fromOrderOrAddress({
      required List<String> orderKeys,
      required List<String> addressKeys,
    }) {
      for (final key in orderKeys) {
        final value = widget.orderData[key];

        if (value != null &&
            value.toString().trim().isNotEmpty &&
            value is! Map) {
          return value.toString().trim();
        }
      }

      for (final key in addressKeys) {
        final value = addressMap[key];

        if (value != null &&
            value.toString().trim().isNotEmpty &&
            value is! Map) {
          return value.toString().trim();
        }
      }

      return '';
    }

    final name = fromOrderOrAddress(
      orderKeys: [
        'customerName',
      ],
      addressKeys: [
        'name',
        'customerName',
      ],
    );

    final phone = fromOrderOrAddress(
      orderKeys: [
        'customerPhone',
        'phone',
      ],
      addressKeys: [
        'phone',
        'customerPhone',
      ],
    );

    final email = fromOrderOrAddress(
      orderKeys: [
        'customerEmail',
        'userEmail',
        'email',
      ],
      addressKeys: [
        'email',
        'customerEmail',
      ],
    );

    final address = fromOrderOrAddress(
      orderKeys: [
        'shippingAddress',
        'addressLine',
      ],
      addressKeys: [
        'address',
        'addressLine',
        'shippingAddress',
      ],
    );

    final city = fromOrderOrAddress(
      orderKeys: [
        'city',
      ],
      addressKeys: [
        'city',
      ],
    );

    final district = fromOrderOrAddress(
      orderKeys: [
        'district',
      ],
      addressKeys: [
        'district',
      ],
    );

    final postalCode = fromOrderOrAddress(
      orderKeys: [
        'postalCode',
        'zipCode',
        'postcode',
      ],
      addressKeys: [
        'postalCode',
        'zipCode',
        'postcode',
      ],
    );

    final deliveryZone = fromOrderOrAddress(
      orderKeys: [
        'deliveryZone',
      ],
      addressKeys: [
        'deliveryZone',
      ],
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _infoRow(
              'Name',
              name.isEmpty
                  ? 'Not available'
                  : name,
              icon: Icons.person_outline,
            ),

            _infoRow(
              'Phone',
              phone.isEmpty
                  ? 'Not available'
                  : phone,
              icon: Icons.phone_outlined,
            ),

            if (email.isNotEmpty)
              _infoRow(
                'Email',
                email,
                icon: Icons.email_outlined,
              ),

            _infoRow(
              'Address',
              address.isEmpty
                  ? 'Not available'
                  : address,
              icon: Icons.location_on_outlined,
            ),

            if (city.isNotEmpty)
              _infoRow(
                'City',
                city,
              ),

            if (district.isNotEmpty)
              _infoRow(
                'District',
                district,
              ),

            if (postalCode.isNotEmpty)
              _infoRow(
                'Postal Code',
                postalCode,
              ),

            if (deliveryZone.isNotEmpty)
              _infoRow(
                'Delivery Zone',
                deliveryZone,
              ),
          ],
        ),
      ),
    );
  }

  Widget _paymentCard() {
    final paymentMethod =
        (widget.orderData['paymentMethod'] ??
                'Not available')
            .toString();

    final paymentStatus =
        (widget.orderData['paymentStatus'] ??
                'pending')
            .toString();

    final currency =
        (widget.orderData['currency'] ?? 'BDT')
            .toString();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _infoRow(
              'Payment Method',
              paymentMethod,
              icon: Icons.payments_outlined,
            ),
            _infoRow(
              'Payment Status',
              paymentStatus,
              icon: Icons.receipt_long_outlined,
            ),
            _infoRow(
              'Currency',
              currency == 'BDT'
                  ? 'BDT (৳)'
                  : currency,
              icon: Icons.currency_exchange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _mainOrderInfoCard() {
    final status =
        (widget.orderData['orderStatus'] ??
                'placed')
            .toString();

    final createdAt = _formatDate(
      widget.orderData['createdAt'],
    );

    final userEmail =
        (widget.orderData['userEmail'] ??
                widget.orderData['customerEmail'] ??
                '')
            .toString();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Order Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _statusChip(status),
              ],
            ),
            const Divider(height: 24),
            _infoRow(
              'Order ID',
              '#${widget.orderId}',
              icon: Icons.confirmation_number_outlined,
              bold: true,
            ),
            _infoRow(
              'Order Date',
              createdAt,
              icon: Icons.calendar_today_outlined,
            ),
            if (userEmail.isNotEmpty)
              _infoRow(
                'Customer Email',
                userEmail,
                icon: Icons.email_outlined,
              ),
          ],
        ),
      ),
    );
  }

  Stream<List<QueryDocumentSnapshot<
      Map<String, dynamic>>>> _sellerOrdersStream(
    String collectionName,
  ) {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection(collectionName)
        .where(
          'customerId',
          isEqualTo: user.uid,
        )
        .snapshots()
        .map(
          (snapshot) {
            return snapshot.docs.where(
              (doc) {
                final data = doc.data();

                return data['orderId']?.toString() ==
                    widget.orderId;
              },
            ).toList();
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final items = _mainItems();

    final mainStatus =
        (widget.orderData['orderStatus'] ??
                'placed')
            .toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<
          List<QueryDocumentSnapshot<
              Map<String, dynamic>>>>
          (
        stream: _sellerOrdersStream(
          'seller_orders',
        ),
        initialData: widget.sellerOrders,
        builder: (
          context,
          sellerSnapshot,
        ) {
          final sellerOrders =
              sellerSnapshot.data ??
                  widget.sellerOrders;

          return StreamBuilder<
              List<QueryDocumentSnapshot<
                  Map<String, dynamic>>>>
              (
            stream: _sellerOrdersStream(
              'reseller_orders',
            ),
            builder: (
              context,
              resellerSnapshot,
            ) {
              final resellerOrders =
                  resellerSnapshot.data ?? [];

              return ListView(
                padding:
                    const EdgeInsets.all(16),
                children: [
                  _mainOrderInfoCard(),

                  const SizedBox(height: 20),

                  _sectionTitle(
                    'Products',
                    Icons.shopping_bag_outlined,
                  ),

                  if (items.isEmpty)
                    const Card(
                      child: Padding(
                        padding:
                            EdgeInsets.all(20),
                        child: Text(
                          'No product information available.',
                          textAlign:
                              TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ...items.map(_productCard),

                  const SizedBox(height: 10),

                  _sectionTitle(
                    'Order Summary',
                    Icons.calculate_outlined,
                  ),

                  _orderSummaryCard(),

                  const SizedBox(height: 20),

                  _sectionTitle(
                    'Delivery Information',
                    Icons.local_shipping_outlined,
                  ),

                  _deliveryCard(),

                  const SizedBox(height: 20),

                  _sectionTitle(
                    'Payment',
                    Icons.payments_outlined,
                  ),

                  _paymentCard(),

                  const SizedBox(height: 20),

                  if (sellerOrders.isNotEmpty) ...[
                    _sectionTitle(
                      'Seller Orders',
                      Icons.storefront_outlined,
                    ),
                    ...sellerOrders.map(
                      (doc) => _orderCard(
                        orderDoc: doc,
                        isResellerOrder: false,
                      ),
                    ),
                  ],

                  if (resellerOrders.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _sectionTitle(
                      'Reseller Store Orders',
                      Icons.storefront_outlined,
                    ),
                    ...resellerOrders.map(
                      (doc) => _orderCard(
                        orderDoc: doc,
                        isResellerOrder: true,
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  if (mainStatus != 'cancelled')
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  OrderTrackingPage(
                                orderId:
                                    widget.orderId,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.local_shipping_outlined,
                        ),
                        label: const Text(
                          'Track Order',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 30),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
