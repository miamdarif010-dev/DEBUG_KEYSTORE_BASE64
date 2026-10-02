import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'seller_return_refund_page.dart';

// =============================================================
// ORDER ENTRY
// =============================================================

class _SellerOrderEntry {
  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final bool isResellerOrder;

  const _SellerOrderEntry({
    required this.document,
    required this.isResellerOrder,
  });

  Map<String, dynamic> get data => document.data();

  String get documentId => document.id;
}

// =============================================================
// SELLER ORDERS PAGE
// =============================================================

class SellerOrdersPage extends StatelessWidget {
  const SellerOrdersPage({super.key});

  // ===========================================================
  // STATUS COLOR
  // ===========================================================

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return Colors.grey;
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
        return Colors.brown;
      case 'refunded':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  // ===========================================================
  // STATUS TEXT
  // ===========================================================

  String _statusText(String status) {
    if (status.isEmpty) {
      return 'Placed';
    }

    switch (status.toLowerCase()) {
      case 'placed':
        return 'Placed';
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
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  // ===========================================================
  // NOTIFICATION TITLE
  // ===========================================================

  String _notificationTitle(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Order Confirmed';
      case 'processing':
        return 'Order Processing';
      case 'shipped':
        return 'Order Shipped';
      case 'delivered':
        return 'Order Delivered';
      case 'cancelled':
        return 'Order Cancelled';
      default:
        return 'Order Updated';
    }
  }

  // ===========================================================
  // NOTIFICATION MESSAGE
  // ===========================================================

  String _notificationMessage({
    required String status,
    required String sellerName,
  }) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Your order has been confirmed by $sellerName.';

      case 'processing':
        return 'Your order is now being prepared by $sellerName.';

      case 'shipped':
        return 'Your order has been shipped by $sellerName.';

      case 'delivered':
        return 'Your order has been delivered successfully.';

      case 'cancelled':
        return 'Your order has been cancelled by $sellerName.';

      default:
        return 'Your order status has been updated to '
            '${_statusText(status)}.';
    }
  }

  // ===========================================================
  // NOTIFICATION TYPE
  // ===========================================================

  String _notificationType(String status) {
    switch (status.toLowerCase()) {
      case 'shipped':
        return 'shipped';

      case 'delivered':
        return 'delivered';

      case 'cancelled':
        return 'cancelled';

      default:
        return 'order';
    }
  }

  // ===========================================================
  // FORMAT DATE
  // ===========================================================

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();

      String two(int n) => n.toString().padLeft(2, '0');

      return '${date.year}-${two(date.month)}-${two(date.day)} '
          '${two(date.hour)}:${two(date.minute)}';
    }

    if (value is DateTime) {
      String two(int n) => n.toString().padLeft(2, '0');

      return '${value.year}-${two(value.month)}-${two(value.day)} '
          '${two(value.hour)}:${two(value.minute)}';
    }

    if (value is String) {
      final parsed = DateTime.tryParse(value);

      if (parsed != null) {
        String two(int n) => n.toString().padLeft(2, '0');

        return '${parsed.year}-${two(parsed.month)}-'
            '${two(parsed.day)} '
            '${two(parsed.hour)}:${two(parsed.minute)}';
      }
    }

    return 'Date unavailable';
  }

  // ===========================================================
  // PARSE DATE
  // ===========================================================

  DateTime? _parseDate(dynamic value) {
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

  // ===========================================================
  // NUMBER
  // ===========================================================

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  // ===========================================================
  // INT
  // ===========================================================

  int _int(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  // ===========================================================
  // MONEY
  // ===========================================================

  String _money(double value) {
    if (value == value.roundToDouble()) {
      return '৳${value.toInt()}';
    }

    return '৳${value.toStringAsFixed(2)}';
  }

  // ===========================================================
  // STATUS CHIP
  // ===========================================================

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
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  // ===========================================================
  // ORDER TYPE CHIP
  // ===========================================================

  Widget _orderTypeChip(bool isResellerOrder) {
    final color = isResellerOrder
        ? Colors.deepPurple
        : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isResellerOrder
                ? Icons.swap_horiz_rounded
                : Icons.storefront_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isResellerOrder
                ? 'Reseller Order'
                : 'Direct Order',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // IMAGE PLACEHOLDER
  // ===========================================================

  Widget _imagePlaceholder() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.image_outlined,
        color: Colors.grey,
      ),
    );
  }

  // ===========================================================
  // BUILD ITEM CARD
  // ===========================================================

  Widget _buildItemCard(
    Map<String, dynamic> item,
  ) {
    final name =
        item['productName']?.toString() ??
            item['name']?.toString() ??
            'Product';

    final imageUrl =
        item['imageUrl']?.toString() ??
            item['productImageUrl']?.toString() ??
            '';

    final price = _number(item['price']);

    final quantityValue =
        _int(item['quantity']);

    final quantity =
        quantityValue > 0 ? quantityValue : 1;

    final totalValue = item['total'];

    final total = totalValue != null
        ? _number(totalValue)
        : price * quantity;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                BorderRadius.circular(10),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return _imagePlaceholder();
                    },
                  )
                : _imagePlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_money(price)} × $quantity',
                  style: const TextStyle(
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total: ${_money(total)}',
                  style: const TextStyle(
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

  // ===========================================================
  // ITEMS
  // ===========================================================

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

  // ===========================================================
  // CREATE BUYER NOTIFICATION
  // ===========================================================

  void _addBuyerNotification({
    required WriteBatch batch,
    required String customerId,
    required String orderId,
    required String sellerId,
    required String sellerName,
    required String newStatus,
  }) {
    if (customerId.isEmpty || orderId.isEmpty) {
      return;
    }

    final firestore =
        FirebaseFirestore.instance;

    final notificationRef = firestore
        .collection('users')
        .doc(customerId)
        .collection('notifications')
        .doc();

    batch.set(
      notificationRef,
      {
        'title':
            _notificationTitle(newStatus),
        'message': _notificationMessage(
          status: newStatus,
          sellerName: sellerName,
        ),
        'type':
            _notificationType(newStatus),
        'orderId': orderId,
        'sellerId': sellerId,
        'sellerName': sellerName,
        'customerId': customerId,
        'orderStatus': newStatus,
        'isRead': false,
        'createdAt':
            FieldValue.serverTimestamp(),
      },
    );
  }

  // ===========================================================
  // UPDATE ORDER STATUS
  //
  // Direct:
  //   seller_orders
  //
  // Reseller:
  //   reseller_orders
  //
  // Main /orders is intentionally NOT updated here.
  // ===========================================================

  Future<void> _updateStatus({
    required BuildContext context,
    required String orderDocumentId,
    required String mainOrderId,
    required String sellerId,
    required String customerId,
    required String newStatus,
    required String currentStatus,
    required bool isResellerOrder,
  }) async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    if (user.uid != sellerId) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'You are not allowed to update this order.',
          ),
        ),
      );

      return;
    }

    if (orderDocumentId.isEmpty) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Order document ID is missing.',
          ),
        ),
      );

      return;
    }

    if (newStatus == currentStatus) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Order is already '
            '${_statusText(currentStatus)}.',
          ),
        ),
      );

      return;
    }

    try {
      final firestore =
          FirebaseFirestore.instance;

      final collectionName =
          isResellerOrder
              ? 'reseller_orders'
              : 'seller_orders';

      final orderRef = firestore
          .collection(collectionName)
          .doc(orderDocumentId);

      final batch = firestore.batch();

      batch.update(
        orderRef,
        {
          'orderStatus': newStatus,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
      );

      final sellerName =
          user.displayName?.trim().isNotEmpty ==
                  true
              ? user.displayName!.trim()
              : 'Seller';

      _addBuyerNotification(
        batch: batch,
        customerId: customerId,
        orderId: mainOrderId.isNotEmpty
            ? mainOrderId
            : orderDocumentId,
        sellerId: sellerId,
        sellerName: sellerName,
        newStatus: newStatus,
      );

      await batch.commit();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '${isResellerOrder ? 'Reseller order' : 'Order'} '
            'changed to ${_statusText(newStatus)}.',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not update order.\n'
            '${e.message ?? e.code}',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not update order.\n$e',
          ),
        ),
      );
    }
  }

  // ===========================================================
  // STATUS DIALOG
  // ===========================================================

  void _showStatusDialog(
    BuildContext context, {
    required String orderDocumentId,
    required String mainOrderId,
    required String sellerId,
    required String customerId,
    required String currentStatus,
    required bool isResellerOrder,
  }) {
    const statuses = [
      'placed',
      'confirmed',
      'processing',
      'shipped',
      'delivered',
      'cancelled',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isResellerOrder
                ? 'Update Reseller Order'
                : 'Update Order Status',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: statuses.map(
              (status) {
                final selected =
                    status == currentStatus;

                return ListTile(
                  leading: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected
                        ? _statusColor(status)
                        : null,
                  ),
                  title: Text(
                    _statusText(status),
                  ),
                  onTap: () async {
                    Navigator.pop(
                      dialogContext,
                    );

                    await _updateStatus(
                      context: context,
                      orderDocumentId:
                          orderDocumentId,
                      mainOrderId:
                          mainOrderId,
                      sellerId:
                          sellerId,
                      customerId:
                          customerId,
                      newStatus:
                          status,
                      currentStatus:
                          currentStatus,
                      isResellerOrder:
                          isResellerOrder,
                    );
                  },
                );
              },
            ).toList(),
          ),
        );
      },
    );
  }

  // ===========================================================
  // RETURN / REFUND PAGE
  // ===========================================================

  void _openReturnRefundPage(
    BuildContext context,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const SellerReturnRefundPage(),
      ),
    );
  }

  // ===========================================================
  // CHECK RETURN / REFUND REQUESTS
  // ===========================================================

  Stream<
      List<
          QueryDocumentSnapshot<
              Map<String, dynamic>>>>
      _returnRefundRequestsStream(
    String sellerId,
    String orderId,
  ) {
    return FirebaseFirestore.instance
        .collection('return_refund_requests')
        .where(
          'sellerId',
          isEqualTo: sellerId,
        )
        .snapshots()
        .map(
      (snapshot) {
        return snapshot.docs.where((doc) {
          final data = doc.data();

          final requestOrderId =
              data['orderId']?.toString() ??
                  '';

          return requestOrderId == orderId;
        }).toList();
      },
    );
  }

  // ===========================================================
  // RETURN / REFUND BUTTON
  // ===========================================================

  Widget _returnRefundButton(
    BuildContext context, {
    required String sellerId,
    required String orderId,
  }) {
    if (sellerId.isEmpty ||
        orderId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<
        List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>> >(
      stream: _returnRefundRequestsStream(
        sellerId,
        orderId,
      ),
      builder: (context, snapshot) {
        final count =
            snapshot.data?.length ?? 0;

        if (count == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          margin:
              const EdgeInsets.only(top: 10),
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              _openReturnRefundPage(
                context,
              );
            },
            icon: const Icon(
              Icons.assignment_return_outlined,
            ),
            label: Text(
              'Return / Refund Requests ($count)',
            ),
          ),
        );
      },
    );
  }

  // ===========================================================
  // CUSTOMER ADDRESS
  //
  // Supports:
  // address: String
  // customerAddress: String
  // deliveryAddress: String
  // deliveryAddress: Map
  // ===========================================================

  String _customerAddress(
    Map<String, dynamic> data,
  ) {
    final address =
        data['address']?.toString() ?? '';

    if (address.isNotEmpty &&
        address != 'null') {
      return address;
    }

    final customerAddress =
        data['customerAddress']
            ?.toString() ??
            '';

    if (customerAddress.isNotEmpty &&
        customerAddress != 'null') {
      return customerAddress;
    }

    final deliveryAddress =
        data['deliveryAddress'];

    if (deliveryAddress is String) {
      if (deliveryAddress.isNotEmpty &&
          deliveryAddress != 'null') {
        return deliveryAddress;
      }
    }

    if (deliveryAddress is Map) {
      final parts = <String>[];

      void addPart(dynamic value) {
        final text =
            value?.toString().trim() ?? '';

        if (text.isNotEmpty &&
            text != 'null') {
          parts.add(text);
        }
      }

      addPart(deliveryAddress['address']);
      addPart(deliveryAddress['addressLine']);
      addPart(deliveryAddress['street']);
      addPart(deliveryAddress['area']);
      addPart(deliveryAddress['upazila']);
      addPart(deliveryAddress['district']);
      addPart(deliveryAddress['city']);
      addPart(deliveryAddress['division']);
      addPart(deliveryAddress['postalCode']);

      return parts.join(', ');
    }

    return '';
  }

  // ===========================================================
  // CUSTOMER PHONE
  // ===========================================================

  String _customerPhone(
    Map<String, dynamic> data,
  ) {
    final customerPhone =
        data['customerPhone']
            ?.toString() ??
            '';

    if (customerPhone.isNotEmpty) {
      return customerPhone;
    }

    final phone =
        data['phone']?.toString() ?? '';

    if (phone.isNotEmpty) {
      return phone;
    }

    final deliveryAddress =
        data['deliveryAddress'];

    if (deliveryAddress is Map) {
      return deliveryAddress['phone']
              ?.toString() ??
          '';
    }

    return '';
  }

  // ===========================================================
  // CUSTOMER EMAIL
  // ===========================================================

  String _customerEmail(
    Map<String, dynamic> data,
  ) {
    final customerEmail =
        data['customerEmail']
            ?.toString() ??
            '';

    if (customerEmail.isNotEmpty) {
      return customerEmail;
    }

    return data['email']?.toString() ?? '';
  }

  // ===========================================================
  // CUSTOMER NAME
  // ===========================================================

  String _customerName(
    Map<String, dynamic> data,
  ) {
    final customerName =
        data['customerName']
            ?.toString() ??
            '';

    if (customerName.isNotEmpty) {
      return customerName;
    }

    final name =
        data['name']?.toString() ?? '';

    if (name.isNotEmpty) {
      return name;
    }

    final deliveryAddress =
        data['deliveryAddress'];

    if (deliveryAddress is Map) {
      final addressName =
          deliveryAddress['name']
                  ?.toString() ??
              '';

      if (addressName.isNotEmpty) {
        return addressName;
      }
    }

    return 'Customer';
  }

  // ===========================================================
  // DELIVERY INFORMATION CARD
  // ===========================================================

  Widget _deliveryInformationCard(
    Map<String, dynamic> data,
  ) {
    final customerName =
        _customerName(data);

    final phone =
        _customerPhone(data);

    final email =
        _customerEmail(data);

    final address =
        _customerAddress(data);

    final deliveryZone =
        data['deliveryZone']
                ?.toString() ??
            '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(
          alpha: 0.06,
        ),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: Colors.blue.withValues(
            alpha: 0.12,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                color: Colors.blue,
              ),
              SizedBox(width: 8),
              Text(
                'Customer Delivery Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _infoRow(
            Icons.person_outline,
            'Customer',
            customerName,
          ),

          if (phone.isNotEmpty)
            _infoRow(
              Icons.phone_outlined,
              'Phone',
              phone,
            ),

          if (email.isNotEmpty)
            _infoRow(
              Icons.email_outlined,
              'Email',
              email,
            ),

          if (address.isNotEmpty)
            _infoRow(
              Icons.location_on_outlined,
              'Address',
              address,
            ),

          if (deliveryZone.isNotEmpty)
            _infoRow(
              Icons.map_outlined,
              'Delivery Zone',
              deliveryZone,
            ),

          if (phone.isEmpty &&
              email.isEmpty &&
              address.isEmpty)
            const Padding(
              padding:
                  EdgeInsets.only(top: 8),
              child: Text(
                'Some delivery information is '
                'not available in this order.',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================
  // INFO ROW
  // ===========================================================

  Widget _infoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.grey.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: value,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // ORDER DETAILS
  // ===========================================================

  Future<void> _showOrderDetails(
    BuildContext context,
    _SellerOrderEntry entry,
  ) async {
    final data = entry.data;

    final isResellerOrder =
        entry.isResellerOrder;

    final documentId =
        entry.documentId;

    final orderId =
        data['orderId']?.toString() ??
            documentId;

    final paymentMethod =
        data['paymentMethod']
                ?.toString() ??
            'Unknown';

    final paymentStatus =
        data['paymentStatus']
                ?.toString() ??
            'pending';

    final status =
        data['orderStatus']
                ?.toString() ??
            data['status']?.toString() ??
            'placed';

    final sellerId =
        data['sellerId']?.toString() ?? '';

    final customerId =
        data['customerId']?.toString() ?? '';

    final items = _items(data);

    final sellerSubtotal =
        _number(
      data['sellerSubtotal'] ??
          data['subtotal'],
    );

    final sellingTotal =
        _number(
      data['sellingTotal'] ??
          data['total'],
    );

    final supplierTotal =
        _number(
      data['supplierTotal'],
    );

    final resellerProfit =
        _number(
      data['resellerProfit'] ??
          data['profit'],
    );

    final netSellerEarnings =
        _number(
      data['netSellerEarnings'] ??
          data['sellerEarnings'],
    );

    final deliveryFee =
        _number(data['deliveryFee']);

    final discount =
        _number(
      data['couponDiscount'] ??
          data['discount'],
    );

    final couponCode =
        data['couponCode']?.toString() ?? '';

    final entrepreneurCode =
        data['entrepreneurCode']
                ?.toString() ??
            '';

    final sellerCode =
        data['sellerCode']?.toString() ?? '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height:
                MediaQuery.of(sheetContext)
                        .size
                        .height *
                    0.90,
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                10,
                20,
                24,
              ),
              child:
                  SingleChildScrollView(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isResellerOrder
                                ? 'Reseller Order Details'
                                : 'Order Details',
                            style:
                                const TextStyle(
                              fontSize: 22,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(
                              sheetContext,
                            );
                          },
                          icon:
                              const Icon(
                            Icons.close,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    _orderTypeChip(
                      isResellerOrder,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Order ID: $orderId',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 14),

                    _deliveryInformationCard(
                      data,
                    ),

                    if (isResellerOrder) ...[
                      const SizedBox(height: 12),
                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets.all(
                          12,
                        ),
                        decoration:
                            BoxDecoration(
                          color: Colors
                              .deepPurple
                              .withValues(
                            alpha: 0.08,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                          border: Border.all(
                            color: Colors
                                .deepPurple
                                .withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ),
                        child:
                            const Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Icon(
                              Icons
                                  .local_shipping_outlined,
                              color: Colors
                                  .deepPurple,
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: Text(
                                'Reseller Order — Seller '
                                'delivers directly to this '
                                'customer. The product should '
                                'not be sent to the reseller.',
                                style:
                                    TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    Text(
                      'Payment: $paymentMethod',
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Payment Status: $paymentStatus',
                    ),

                    if (entrepreneurCode
                        .isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Entrepreneur ID: '
                        '$entrepreneurCode',
                      ),
                    ],

                    if (sellerCode
                        .isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Seller ID: $sellerCode',
                      ),
                    ],

                    if (sellerId
                        .isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Seller UID: $sellerId',
                      ),
                    ],

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        const Text(
                          'Status: ',
                        ),
                        _statusChip(status),
                      ],
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Products',
                      style:
                          TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    if (items.isEmpty)
                      const Text(
                        'No product information found.',
                        style:
                            TextStyle(
                          color: Colors.grey,
                        ),
                      ),

                    ...items.map(
                      (item) =>
                          _buildItemCard(
                        item,
                      ),
                    ),

                    const SizedBox(height: 10),

                    if (isResellerOrder) ...[
                      _moneyDetailRow(
                        'Selling Total',
                        sellingTotal,
                      ),
                      _moneyDetailRow(
                        'Supplier Cost',
                        supplierTotal,
                      ),
                      _moneyDetailRow(
                        'Reseller Profit',
                        resellerProfit,
                        green: true,
                      ),
                    ] else ...[
                      _moneyDetailRow(
                        'Seller Subtotal',
                        sellerSubtotal,
                      ),
                      if (netSellerEarnings >
                          0)
                        _moneyDetailRow(
                          'Net Seller Earnings',
                          netSellerEarnings,
                          green: true,
                        ),
                    ],

                    if (discount > 0)
                      _moneyDetailRow(
                        couponCode.isNotEmpty
                            ? 'Coupon Discount ($couponCode)'
                            : 'Coupon Discount',
                        discount,
                      ),

                    if (deliveryFee > 0)
                      _moneyDetailRow(
                        'Delivery Fee',
                        deliveryFee,
                      ),

                    const SizedBox(height: 10),

                    _returnRefundButton(
                      context,
                      sellerId: sellerId,
                      orderId: orderId,
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width:
                          double.infinity,
                      child:
                          OutlinedButton.icon(
                        onPressed:
                            sellerId.isEmpty
                                ? null
                                : () {
                                    Navigator.pop(
                                      sheetContext,
                                    );

                                    _showStatusDialog(
                                      context,
                                      orderDocumentId:
                                          documentId,
                                      mainOrderId:
                                          orderId,
                                      sellerId:
                                          sellerId,
                                      customerId:
                                          customerId,
                                      currentStatus:
                                          status
                                              .toLowerCase(),
                                      isResellerOrder:
                                          isResellerOrder,
                                    );
                                  },
                        icon: const Icon(
                          Icons
                              .edit_outlined,
                        ),
                        label: Text(
                          isResellerOrder
                              ? 'Update Reseller Order Status'
                              : 'Update Order Status',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================
  // MONEY DETAIL ROW
  // ===========================================================

  Widget _moneyDetailRow(
    String title,
    double value, {
    bool green = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _money(value),
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
              color: green
                  ? Colors.green
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // ORDER CARD
  // ===========================================================

  Widget _buildOrderCard(
    BuildContext context,
    _SellerOrderEntry entry,
  ) {
    final document =
        entry.document;

    final data =
        entry.data;

    final isResellerOrder =
        entry.isResellerOrder;

    final orderDocumentId =
        document.id;

    final mainOrderId =
        data['orderId']?.toString() ??
            orderDocumentId;

    final sellerId =
        data['sellerId']?.toString() ?? '';

    final customerId =
        data['customerId']?.toString() ?? '';

    final customerName =
        _customerName(data);

    final phone =
        _customerPhone(data);

    final address =
        _customerAddress(data);

    final deliveryZone =
        data['deliveryZone']
                ?.toString() ??
            '';

    final status =
        data['orderStatus']?.toString() ??
            data['status']?.toString() ??
            'placed';

    final paymentStatus =
        data['paymentStatus']
                ?.toString() ??
            'pending';

    final items =
        _items(data);

    final total = isResellerOrder
        ? _number(
            data['sellingTotal'] ??
                data['total'],
          )
        : _number(
            data['sellerSubtotal'] ??
                data['subtotal'],
          );

    final supplierTotal =
        _number(
      data['supplierTotal'],
    );

    final resellerProfit =
        _number(
      data['resellerProfit'] ??
          data['profit'],
    );

    final netSellerEarnings =
        _number(
      data['netSellerEarnings'] ??
          data['sellerEarnings'],
    );

    final createdAt =
        _formatDate(data['createdAt']);

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
      elevation: 2,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(12),
        onTap: () {
          _showOrderDetails(
            context,
            entry,
          );
        },
        child: Padding(
          padding:
              const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  const Icon(
                    Icons
                        .receipt_long_outlined,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          mainOrderId
                                  .isNotEmpty
                              ? 'Order #$mainOrderId'
                              : 'Order',
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        _orderTypeChip(
                          isResellerOrder,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  _statusChip(status),
                ],
              ),

              const SizedBox(height: 10),

              Text(
                createdAt,
                style: TextStyle(
                  color:
                      Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),

              const Divider(
                height: 22,
              ),

              Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  const Icon(
                    Icons
                        .person_outline_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customerName,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              if (phone.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.only(
                    top: 6,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons
                            .phone_outlined,
                        size: 17,
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors
                              .grey
                              .shade700,
                        ),
                      ),
                    ],
                  ),
                ),

              if (address.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.only(
                    top: 6,
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Icon(
                        Icons
                            .location_on_outlined,
                        size: 18,
                        color: isResellerOrder
                            ? Colors
                                .deepPurple
                            : Colors.redAccent,
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Expanded(
                        child: Text(
                          address,
                          maxLines: 3,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors
                                .grey
                                .shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (deliveryZone
                  .isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.only(
                    top: 5,
                  ),
                  child: Text(
                    'Delivery Zone: '
                    '$deliveryZone',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors
                          .grey
                          .shade700,
                    ),
                  ),
                ),

              if (isResellerOrder)
                Container(
                  margin:
                      const EdgeInsets.only(
                    top: 10,
                  ),
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors
                        .deepPurple
                        .withValues(
                      alpha: 0.07,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(10),
                  ),
                  child:
                      const Row(
                    children: [
                      Icon(
                        Icons
                            .local_shipping_outlined,
                        size: 18,
                        color: Colors
                            .deepPurple,
                      ),
                      SizedBox(
                        width: 7,
                      ),
                      Expanded(
                        child: Text(
                          'Seller delivers directly '
                          'to customer',
                          style:
                              TextStyle(
                            fontSize: 12,
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              Text(
                '${items.length} product(s)',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              if (items.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...items.take(2).map(
                  (item) =>
                      _buildItemCard(item),
                ),
              ],

              if (items.length > 2)
                Padding(
                  padding:
                      const EdgeInsets.only(
                    top: 4,
                  ),
                  child: Text(
                    '+ ${items.length - 2} '
                    'more product(s)',
                    style: TextStyle(
                      color: Colors
                          .grey
                          .shade600,
                    ),
                  ),
                ),

              const Divider(
                height: 24,
              ),

              if (isResellerOrder)
                Row(
                  children: [
                    Expanded(
                      child: _miniMoney(
                        'Selling',
                        total,
                      ),
                    ),
                    Expanded(
                      child: _miniMoney(
                        'Supplier',
                        supplierTotal,
                      ),
                    ),
                    Expanded(
                      child: _miniMoney(
                        'Reseller Profit',
                        resellerProfit,
                        green: true,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            'Seller Total: '
                            '${_money(total)}',
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                              fontSize: 16,
                            ),
                          ),
                          if (netSellerEarnings >
                              0) ...[
                            const SizedBox(
                              height: 3,
                            ),
                            Text(
                              'Net Earnings: '
                              '${_money(netSellerEarnings)}',
                              style:
                                  const TextStyle(
                                color:
                                    Colors.green,
                                fontWeight:
                                    FontWeight
                                        .w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      'Payment: '
                      '$paymentStatus',
                      style: TextStyle(
                        color: paymentStatus ==
                                'paid'
                            ? Colors.green
                            : Colors.orange,
                        fontWeight:
                            FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

              if (isResellerOrder) ...[
                const SizedBox(height: 8),
                Text(
                  'Payment: '
                  '$paymentStatus',
                  style: TextStyle(
                    color: paymentStatus ==
                            'paid'
                        ? Colors.green
                        : Colors.orange,
                    fontWeight:
                        FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],

              _returnRefundButton(
                context,
                sellerId: sellerId,
                orderId: mainOrderId,
              ),

              const SizedBox(height: 10),

              SizedBox(
                width:
                    double.infinity,
                child:
                    OutlinedButton.icon(
                  onPressed: () {
                    _showOrderDetails(
                      context,
                      entry,
                    );
                  },
                  icon: const Icon(
                    Icons
                        .visibility_outlined,
                    size: 18,
                  ),
                  label:
                      const Text(
                    'View Order',
                  ),
                ),
              ),

              const SizedBox(height: 8),

              SizedBox(
                width:
                    double.infinity,
                child:
                    OutlinedButton.icon(
                  onPressed:
                      sellerId.isEmpty
                          ? null
                          : () {
                              _showStatusDialog(
                                context,
                                orderDocumentId:
                                    orderDocumentId,
                                mainOrderId:
                                    mainOrderId,
                                sellerId:
                                    sellerId,
                                customerId:
                                    customerId,
                                currentStatus:
                                    status
                                        .toLowerCase(),
                                isResellerOrder:
                                    isResellerOrder,
                              );
                            },
                  icon: const Icon(
                    Icons.edit_outlined,
                  ),
                  label: Text(
                    isResellerOrder
                        ? 'Update Reseller Order Status'
                        : 'Update Order Status',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================
  // MINI MONEY
  // ===========================================================

  Widget _miniMoney(
    String title,
    double value, {
    bool green = false,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _money(value),
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                FontWeight.bold,
            color: green
                ? Colors.green
                : null,
          ),
        ),
      ],
    );
  }

  // ===========================================================
  // EMPTY
  // ===========================================================

  Widget _emptyView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons
                  .receipt_long_outlined,
              size: 70,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No Seller Orders Yet',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Orders containing your products '
              'will appear here.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================
  // BUILD
  // ===========================================================

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
              const Text(
            'Seller Orders',
          ),
        ),
        body:
            const Center(
          child: Text(
            'Please login to view seller orders.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Seller Orders',
        ),
        actions: [
          IconButton(
            tooltip:
                'Return / Refund',
            onPressed: () {
              _openReturnRefundPage(
                context,
              );
            },
            icon:
                const Icon(
              Icons
                  .assignment_return_outlined,
            ),
          ),
        ],
      ),
      body: StreamBuilder<
          QuerySnapshot<
              Map<String, dynamic>>>(
        stream: FirebaseFirestore
            .instance
            .collection(
              'seller_orders',
            )
            .where(
              'sellerId',
              isEqualTo: user.uid,
            )
            .snapshots(),
        builder: (
          context,
          sellerSnapshot,
        ) {
          if (sellerSnapshot
              .hasError) {
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

          if (sellerSnapshot
                  .connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final sellerDocuments =
              sellerSnapshot.data?.docs ??
                  <QueryDocumentSnapshot<
                      Map<String, dynamic>>>[];

          return StreamBuilder<
              QuerySnapshot<
                  Map<String, dynamic>>>(
            stream: FirebaseFirestore
                .instance
                .collection(
                  'reseller_orders',
                )
                .where(
                  'sellerId',
                  isEqualTo: user.uid,
                )
                .snapshots(),
            builder: (
              context,
              resellerSnapshot,
            ) {
              if (resellerSnapshot
                  .hasError) {
                return Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      20,
                    ),
                    child: Text(
                      'Unable to load reseller orders.\n\n'
                      '${resellerSnapshot.error}',
                      textAlign:
                          TextAlign.center,
                    ),
                  ),
                );
              }

              if (resellerSnapshot
                      .connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              final resellerDocuments =
                  resellerSnapshot.data
                          ?.docs ??
                      <QueryDocumentSnapshot<
                          Map<String, dynamic>>>[];

              // ------------------------------------------------
              // COMBINE DIRECT + RESELLER
              // ------------------------------------------------

              final entries =
                  <_SellerOrderEntry>[
                ...sellerDocuments.map(
                  (doc) =>
                      _SellerOrderEntry(
                    document: doc,
                    isResellerOrder:
                        false,
                  ),
                ),
                ...resellerDocuments.map(
                  (doc) =>
                      _SellerOrderEntry(
                    document: doc,
                    isResellerOrder:
                        true,
                  ),
                ),
              ];

              // ------------------------------------------------
              // SORT NEWEST FIRST
              // ------------------------------------------------

              entries.sort(
                (a, b) {
                  final aDate =
                      _parseDate(
                    a.data['createdAt'],
                  );

                  final bDate =
                      _parseDate(
                    b.data['createdAt'],
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

                  return bDate.compareTo(
                    aDate,
                  );
                },
              );

              // ------------------------------------------------
              // EMPTY
              // ------------------------------------------------

              if (entries.isEmpty) {
                return _emptyView();
              }

              // ------------------------------------------------
              // ORDER LIST
              // ------------------------------------------------

              return RefreshIndicator(
                onRefresh: () async {
                  await Future<void>.delayed(
                    const Duration(
                      milliseconds: 300,
                    ),
                  );
                },
                child:
                    ListView.builder(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    12,
                    12,
                    12,
                    24,
                  ),
                  itemCount:
                      entries.length,
                  itemBuilder:
                      (context, index) {
                    final entry =
                        entries[index];

                    return _buildOrderCard(
                      context,
                      entry,
                    );
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
