import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'order_tracking_page.dart';
import 'order_details_page.dart';

class MyOrdersPage extends StatelessWidget {
  const MyOrdersPage({super.key});

  // ============================================================
  // STATUS
  // ============================================================

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

  // ============================================================
  // HELPERS
  // ============================================================

  String _formatDate(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }

    if (date == null) {
      return 'Date unavailable';
    }

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

  DateTime? _dateValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
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

  // ============================================================
  // SUBTOTAL
  // ============================================================

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

  // ============================================================
  // CUSTOMER FINAL AMOUNT
  // ============================================================

  double _getCustomerOrderAmount(
    Map<String, dynamic> data,
    double subtotal,
  ) {
    final couponDiscount = _number(
      data['couponDiscount'] ??
          data['discount'],
    );

    final storedNetSellingTotal = _number(
      data['netSellingTotal'],
    );

    final storedNetSellerEarnings = _number(
      data['netSellerEarnings'] ??
          data['sellerEarnings'],
    );

    if (storedNetSellingTotal > 0) {
      return storedNetSellingTotal;
    }

    // This field is only a compatibility fallback.
    // It is not displayed as seller earnings.
    if (storedNetSellerEarnings > 0) {
      return storedNetSellerEarnings;
    }

    final calculated = subtotal - couponDiscount;

    return calculated < 0 ? 0 : calculated;
  }

  // ============================================================
  // STATUS CHIP
  // ============================================================

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

  // ============================================================
  // IMAGE
  // ============================================================

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

  // ============================================================
  // PRODUCT ITEM
  // ============================================================

  Widget _buildProductItem(
    Map<String, dynamic> item,
  ) {
    final name =
        (item['name'] ?? 'Product').toString();

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
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          image,
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

  // ============================================================
  // ORDER TYPE
  // ============================================================

  String _orderTypeLabel(
    String collectionName,
  ) {
    if (collectionName == 'reseller_orders') {
      return 'Reseller Order';
    }

    return 'Seller Order';
  }

  // ============================================================
  // CUSTOMER DELIVERY SUMMARY
  // ============================================================

  Widget _buildDeliverySummary(
    Map<String, dynamic> data, {
    required bool isResellerOrder,
  }) {
    final customerName =
        (data['customerName'] ?? '').toString();

    final customerPhone = (
      data['customerPhone'] ??
          data['phone'] ??
          ''
    ).toString();

    final address =
        (data['address'] ?? '').toString();

    final city =
        (data['city'] ?? '').toString();

    final district =
        (data['district'] ?? '').toString();

    final postalCode =
        (data['postalCode'] ?? '').toString();

    final deliveryZone =
        (data['deliveryZone'] ?? '').toString();

    final deliveryAddress =
        data['deliveryAddress'];

    final hasBasicAddress =
        customerName.isNotEmpty ||
        customerPhone.isNotEmpty ||
        address.isNotEmpty ||
        city.isNotEmpty ||
        district.isNotEmpty ||
        postalCode.isNotEmpty;

    final hasMapDeliveryAddress =
        deliveryAddress is Map &&
        deliveryAddress.isNotEmpty;

    if (!hasBasicAddress &&
        !hasMapDeliveryAddress) {
      return const SizedBox.shrink();
    }

    String mapAddress = '';
    String mapCity = '';
    String mapDistrict = '';
    String mapPostalCode = '';

    if (deliveryAddress is Map) {
      mapAddress = (
        deliveryAddress['address'] ??
            deliveryAddress['fullAddress'] ??
            deliveryAddress['street'] ??
            ''
      ).toString();

      mapCity = (
        deliveryAddress['city'] ?? ''
      ).toString();

      mapDistrict = (
        deliveryAddress['district'] ?? ''
      ).toString();

      mapPostalCode = (
        deliveryAddress['postalCode'] ??
            deliveryAddress['zipCode'] ??
            ''
      ).toString();
    }

    final finalAddress =
        address.isNotEmpty ? address : mapAddress;

    final finalCity =
        city.isNotEmpty ? city : mapCity;

    final finalDistrict =
        district.isNotEmpty
            ? district
            : mapDistrict;

    final finalPostalCode =
        postalCode.isNotEmpty
            ? postalCode
            : mapPostalCode;

    final zoneText =
        deliveryZone == 'inside_dhaka'
            ? 'Inside Dhaka'
            : deliveryZone == 'outside_dhaka'
                ? 'Outside Dhaka'
                : '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 19,
                color: Colors.redAccent,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Delivery Information',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (customerName.isNotEmpty)
            Text(
              customerName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),

          if (customerPhone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(customerPhone),
            ),

          if (finalAddress.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(finalAddress),
            ),

          if (finalCity.isNotEmpty ||
              finalDistrict.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                [
                  finalCity,
                  finalDistrict,
                ]
                    .where(
                      (e) => e.isNotEmpty,
                    )
                    .join(', '),
              ),
            ),

          if (finalPostalCode.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                'Postal Code: $finalPostalCode',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ),

          if (zoneText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                zoneText,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ),

          if (isResellerOrder) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(
                  alpha: 0.07,
                ),
                borderRadius:
                    BorderRadius.circular(8),
              ),
              child: const Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 18,
                    color: Colors.blue,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'The Seller will deliver this order '
                      'directly to you. The Reseller does '
                      'not receive or ship the product.',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // CUSTOMER FINANCIAL SUMMARY
  // ============================================================

  Widget _buildFinancialSummary(
    Map<String, dynamic> data, {
    required bool isResellerOrder,
    required double subtotal,
  }) {
    final couponDiscount = _number(
      data['couponDiscount'] ??
          data['discount'],
    );

    if (couponDiscount <= 0) {
      return const SizedBox.shrink();
    }

    final finalAmount =
        _getCustomerOrderAmount(
      data,
      subtotal,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _financialRow(
            'Subtotal',
            subtotal,
          ),
          _financialRow(
            'Coupon Discount',
            couponDiscount,
            valueColor: Colors.green,
            negative: true,
          ),
          const Divider(height: 14),
          _financialRow(
            'Order Amount',
            finalAmount,
            valueColor: Colors.redAccent,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _financialRow(
    String title,
    double value, {
    Color? valueColor,
    bool negative = false,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 6,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              fontWeight:
                  bold ? FontWeight.bold : null,
            ),
          ),
          Text(
            '${negative ? '- ' : ''}'
            '৳${value.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: valueColor,
              fontWeight:
                  bold
                      ? FontWeight.bold
                      : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CANCEL ERROR
  // ============================================================

  String _friendlyCancelError(
    Object error,
  ) {
    final message =
        error.toString().toLowerCase();

    if (message.contains('permission-denied') ||
        message.contains(
          'missing or insufficient permissions',
        )) {
      return 'You do not have permission to cancel this order.';
    }

    if (message.contains('not-found')) {
      return 'This order could not be found.';
    }

    if (message.contains('you cannot cancel')) {
      return 'You cannot cancel this order.';
    }

    if (message.contains(
      'no longer be cancelled',
    )) {
      return 'This order can no longer be cancelled.';
    }

    return 'Could not cancel order. Please try again.';
  }

  // ============================================================
  // CANCEL SELLER / RESELLER ORDER
  // ============================================================

  Future<void> _cancelSellerOrder(
    BuildContext context,
    String sellerOrderId,
    Map<String, dynamic> sellerOrderData, {
    String collectionName = 'seller_orders',
  }) async {
    final currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    final customerId = (
      sellerOrderData['customerId'] ??
          sellerOrderData['userId'] ??
          sellerOrderData['buyerId'] ??
          ''
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
      sellerOrderData['orderStatus'] ??
          sellerOrderData['status'] ??
          'placed'
    ).toString();

    if (!_canCancel(currentStatus)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This order cannot be cancelled because '
            'it is already ${_statusText(currentStatus)}.',
          ),
        ),
      );
      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Cancel Order?',
          ),
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
      final orderRef =
          FirebaseFirestore.instance
              .collection(collectionName)
              .doc(sellerOrderId);

      final latestSnapshot =
          await orderRef.get();

      if (!latestSnapshot.exists) {
        throw Exception(
          'Seller order not found.',
        );
      }

      final latestData =
          latestSnapshot.data() ?? {};

      final latestCustomerId = (
        latestData['customerId'] ??
            latestData['userId'] ??
            latestData['buyerId'] ??
            ''
      ).toString();

      if (latestCustomerId != currentUser.uid) {
        throw Exception(
          'You cannot cancel this order.',
        );
      }

      final latestStatus = (
        latestData['orderStatus'] ??
            latestData['status'] ??
            'placed'
      ).toString();

      if (!_canCancel(latestStatus)) {
        throw Exception(
          'This order can no longer be cancelled.',
        );
      }

      await orderRef.update({
        'orderStatus': 'cancelled',
        'cancelledBy': 'customer',
        'cancelledAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
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
              _friendlyCancelError(e),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================
  // SELLER / RESELLER ORDER CARD
  // ============================================================

  Widget _buildSellerOrderCard(
    BuildContext context,
    QueryDocumentSnapshot<
        Map<String, dynamic>> doc, {
    String collectionName = 'seller_orders',
    String fallbackLabel = 'Seller Order',
  }) {
    final data = doc.data();

    final isResellerOrder =
        collectionName == 'reseller_orders';

    final sellerCode = (
      data['sellerCode'] ??
          data['sellerName'] ??
          fallbackLabel
    ).toString();

    final status = (
      data['orderStatus'] ??
          data['status'] ??
          'placed'
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

    final subtotalLabel =
        isResellerOrder
            ? 'Reseller Subtotal'
            : 'Seller Subtotal';

    final couponDiscount = _number(
      data['couponDiscount'] ??
          data['discount'],
    );

    final customerAmount =
        _getCustomerOrderAmount(
      data,
      subtotal,
    );

    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _statusChip(status),
              ],
            ),

            const SizedBox(height: 8),

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: isResellerOrder
                    ? Colors.blue.withValues(
                        alpha: 0.08,
                      )
                    : Colors.redAccent.withValues(
                        alpha: 0.08,
                      ),
                borderRadius:
                    BorderRadius.circular(6),
              ),
              child: Text(
                _orderTypeLabel(
                  collectionName,
                ),
                style: TextStyle(
                  color: isResellerOrder
                      ? Colors.blue
                      : Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                Text(
                  subtotalLabel,
                  style: const TextStyle(
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

            if (couponDiscount > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Coupon Discount',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '- ৳${couponDiscount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Order Amount',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '৳${customerAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],

            _buildDeliverySummary(
              data,
              isResellerOrder:
                  isResellerOrder,
            ),

            if (_canCancel(status)) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _cancelSellerOrder(
                      context,
                      doc.id,
                      data,
                      collectionName:
                          collectionName,
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
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ORDER DETAILS
  // ============================================================

  void _openOrderDetails(
    BuildContext context,
    QueryDocumentSnapshot<
        Map<String, dynamic>> orderDoc,
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        sellerOrders,
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

  // ============================================================
  // MAIN ORDER CARD
  // ============================================================

  Widget _buildMainOrderCard(
    BuildContext context,
    QueryDocumentSnapshot<
        Map<String, dynamic>> orderDoc,
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        sellerOrders, {
    List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        resellerOrders = const [],
  }) {
    final data = orderDoc.data();

    final orderId = orderDoc.id;

    final mainStatus = (
      data['orderStatus'] ??
          data['status'] ??
          'placed'
    ).toString();

    final total = _number(
      data['total'] ??
          data['grandTotal'] ??
          data['totalAmount'],
    );

    final createdAt =
        _formatDate(data['createdAt']);

    final deliveryZone =
        (data['deliveryZone'] ?? '').toString();

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

              if (deliveryZone.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  deliveryZone == 'inside_dhaka'
                      ? 'Delivery: Inside Dhaka'
                      : deliveryZone == 'outside_dhaka'
                          ? 'Delivery: Outside Dhaka'
                          : 'Delivery: $deliveryZone',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
              ],

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
                    collectionName:
                        'seller_orders',
                    fallbackLabel:
                        'Seller Order',
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

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyOrders() {
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
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
        stream:
            FirebaseFirestore.instance
                .collection('orders')
                .where(
                  'userId',
                  isEqualTo: user.uid,
                )
                .snapshots(),
        builder: (
          context,
          orderSnapshot,
        ) {
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

          final sortedOrders =
              [...orderDocs];

          sortedOrders.sort(
            (a, b) {
              final aDate =
                  _dateValue(
                a.data()['createdAt'],
              );

              final bDate =
                  _dateValue(
                b.data()['createdAt'],
              );

              if (aDate == null &&
                  bDate == null) {
                return 0;
              }

              if (aDate == null) {
                return 1;
              }

              if (bDate == null) {
                return -1;
              }

              return bDate.compareTo(aDate);
            },
          );

          return StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance
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
                    padding:
                        const EdgeInsets.all(20),
                    child: Text(
                      'Unable to load seller orders.\n\n'
                      '${sellerSnapshot.error}',
                      textAlign:
                          TextAlign.center,
                    ),
                  ),
                );
              }

              final sellerDocs =
                  sellerSnapshot.data?.docs ?? [];

              final sellerOrdersByOrderId =
                  <
                      String,
                      List<
                          QueryDocumentSnapshot<
                              Map<String,
                                  dynamic>>>>{};

              for (final sellerDoc in sellerDocs) {
                final data = sellerDoc.data();

                final orderId =
                    (data['orderId'] ?? '')
                        .toString();

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
                stream:
                    FirebaseFirestore.instance
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
                  if (resellerSnapshot
                          .connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child:
                          CircularProgressIndicator(),
                    );
                  }

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
                      resellerSnapshot.data?.docs ?? [];

                  final resellerOrdersByOrderId =
                      <
                          String,
                          List<
                              QueryDocumentSnapshot<
                                  Map<String,
                                      dynamic>>>>{};

                  for (final resellerDoc
                      in resellerDocs) {
                    final data =
                        resellerDoc.data();

                    final orderId =
                        (data['orderId'] ?? '')
                            .toString();

                    if (orderId.isEmpty) {
                      continue;
                    }

                    resellerOrdersByOrderId
                        .putIfAbsent(
                      orderId,
                      () => [],
                    )
                        .add(resellerDoc);
                  }

                  // ==================================================
                  // EMPTY STATE
                  // ==================================================

                  if (sortedOrders.isEmpty) {
                    return _emptyOrders();
                  }

                  // ==================================================
                  // ORDER LIST
                  // ==================================================

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


