import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ResellerOrdersPage extends StatefulWidget {
  const ResellerOrdersPage({super.key});

  @override
  State<ResellerOrdersPage> createState() =>
      _ResellerOrdersPageState();
}

class _ResellerOrdersPageState
    extends State<ResellerOrdersPage> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // =========================================================
  // MONEY
  // =========================================================

  String _money(double value) {
    if (value == value.roundToDouble()) {
      return '৳${value.toInt()}';
    }

    return '৳${value.toStringAsFixed(2)}';
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _stringValue(dynamic value) {
    return value?.toString() ?? '';
  }

  // =========================================================
  // STATUS COLOR
  // =========================================================

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return Colors.orange;

      case 'confirmed':
        return Colors.blue;

      case 'processing':
        return Colors.indigo;

      case 'shipped':
        return Colors.deepPurple;

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

  // =========================================================
  // STATUS TEXT
  // =========================================================

  String _statusText(String status) {
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
        if (status.isEmpty) {
          return 'Unknown';
        }

        return status[0].toUpperCase() +
            status.substring(1);
    }
  }

  // =========================================================
  // DATE
  // =========================================================

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

  String _formatDate(dynamic value) {
    final date = _dateValue(value);

    if (date == null) {
      return 'Recently';
    }

    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    final year =
        date.year.toString();

    final hour =
        date.hour.toString().padLeft(2, '0');

    final minute =
        date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  // =========================================================
  // ORDER ID
  // =========================================================

  String _orderId(
    DocumentSnapshot order,
    Map<String, dynamic> data,
  ) {
    final resellerOrderId =
        _stringValue(data['resellerOrderId']);

    if (resellerOrderId.isNotEmpty) {
      return resellerOrderId;
    }

    final orderId =
        _stringValue(data['orderId']);

    if (orderId.isNotEmpty) {
      return orderId;
    }

    return order.id;
  }

  // =========================================================
  // ORDER ITEMS
  // =========================================================

  Widget _orderItems(
    List<dynamic> items,
  ) {
    if (items.isEmpty) {
      return const Text(
        'No product information available.',
      );
    }

    return Column(
      children: items.map(
        (item) {
          if (item is! Map) {
            return const SizedBox.shrink();
          }

          final itemData =
              Map<String, dynamic>.from(
            item.map(
              (key, value) => MapEntry(
                key.toString(),
                value,
              ),
            ),
          );

          final name =
              _stringValue(
                itemData['productName'],
              ).isNotEmpty
                  ? _stringValue(
                      itemData['productName'],
                    )
                  : _stringValue(
                      itemData['name'],
                    ).isNotEmpty
                      ? _stringValue(
                          itemData['name'],
                        )
                      : 'Product';

          final quantity =
              _toInt(
                itemData['quantity'],
              ) > 0
                  ? _toInt(
                      itemData['quantity'],
                    )
                  : 1;

          final price =
              _toDouble(
            itemData['price'],
          );

          final total =
              _toDouble(
            itemData['total'],
          );

          final imageUrl =
              _stringValue(
            itemData['imageUrl'],
          );

          return Container(
            margin:
                const EdgeInsets.only(
              bottom: 10,
            ),
            padding:
                const EdgeInsets.all(10),
            decoration:
                BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(
                    alpha: 0.45,
                  ),
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child: Row(
              children: [
                // IMAGE
                SizedBox(
                  width: 58,
                  height: 58,
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      8,
                    ),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return Container(
                                color: Colors
                                    .grey
                                    .shade200,
                                child:
                                    const Icon(
                                  Icons
                                      .image_not_supported_outlined,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors
                                .grey
                                .shade200,
                            child:
                                const Icon(
                              Icons
                                  .image_outlined,
                            ),
                          ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                // NAME
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        'Qty: $quantity',
                        style:
                            TextStyle(
                          fontSize: 12,
                          color: Colors
                              .grey
                              .shade600,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        '${_money(price)} × $quantity',
                        style:
                            TextStyle(
                          fontSize: 12,
                          color: Colors
                              .grey
                              .shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                Text(
                  _money(
                    total > 0
                        ? total
                        : price * quantity,
                  ),
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ).toList(),
    );
  }

  // =========================================================
  // ORDER DETAILS
  // =========================================================

  Future<void> _showOrderDetails(
    DocumentSnapshot order,
  ) async {
    final rawData = order.data();

    if (rawData is! Map) {
      return;
    }

    final data =
        Map<String, dynamic>.from(
      rawData.map(
        (key, value) => MapEntry(
          key.toString(),
          value,
        ),
      ),
    );

    final items =
        data['items'] is List
            ? List<dynamic>.from(
                data['items'] as List,
              )
            : <dynamic>[];

    final customerName =
        _stringValue(
      data['customerName'],
    ).isNotEmpty
            ? _stringValue(
                data['customerName'],
              )
            : 'Customer';

    final phone =
        _stringValue(
      data['customerPhone'],
    ).isNotEmpty
            ? _stringValue(
                data['customerPhone'],
              )
            : _stringValue(
                data['phone'],
              );

    final email =
        _stringValue(
      data['customerEmail'],
    );

    final address =
        _stringValue(
      data['address'],
    );

    final deliveryZone =
        _stringValue(
      data['deliveryZone'],
    );

    final orderId =
        _orderId(
      order,
      data,
    );

    final entrepreneurCode =
        _stringValue(
      data['entrepreneurCode'],
    );

    final sellerCode =
        _stringValue(
      data['sellerCode'],
    );

    final sellerId =
        _stringValue(
      data['sellerId'],
    );

    final status =
        _stringValue(
      data['orderStatus'],
    ).isNotEmpty
            ? _stringValue(
                data['orderStatus'],
              ).toLowerCase()
            : 'placed';

    final sellingTotal =
        _toDouble(
      data['sellingTotal'] ??
          data['total'],
    );

    final supplierTotal =
        _toDouble(
      data['supplierTotal'],
    );

    final profit =
        _toDouble(
      data['resellerProfit'] ??
          data['profit'],
    );

    final deliveryFee =
        _toDouble(
      data['deliveryFee'],
    );

    final discount =
        _toDouble(
      data['discount'],
    );

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height:
                MediaQuery.of(
              sheetContext,
            ).size.height *
                    0.90,
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                20,
              ),
              child:
                  SingleChildScrollView(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Order Details',
                            style:
                                TextStyle(
                              fontSize: 21,
                              fontWeight:
                                  FontWeight
                                      .bold,
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

                    Text(
                      orderId,
                      style:
                          TextStyle(
                        color: Colors
                            .grey
                            .shade600,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    _detailRow(
                      'Order ID',
                      orderId,
                    ),

                    _detailRow(
                      'Date',
                      _formatDate(
                        data['createdAt'],
                      ),
                    ),

                    _detailRow(
                      'Customer',
                      customerName,
                    ),

                    if (phone.isNotEmpty)
                      _detailRow(
                        'Phone',
                        phone,
                      ),

                    if (email.isNotEmpty)
                      _detailRow(
                        'Email',
                        email,
                      ),

                    if (address.isNotEmpty)
                      _detailRow(
                        'Address',
                        address,
                      ),

                    if (deliveryZone
                        .isNotEmpty)
                      _detailRow(
                        'Delivery Zone',
                        deliveryZone,
                      ),

                    if (entrepreneurCode
                        .isNotEmpty)
                      _detailRow(
                        'Entrepreneur',
                        entrepreneurCode,
                      ),

                    if (sellerCode
                        .isNotEmpty)
                      _detailRow(
                        'Seller',
                        sellerCode,
                      ),

                    if (sellerId
                        .isNotEmpty)
                      _detailRow(
                        'Seller ID',
                        sellerId,
                      ),

                    const SizedBox(
                      height: 10,
                    ),

                    // STATUS
                    Row(
                      children: [
                        const Text(
                          'Status: ',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),
                        Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                _statusColor(
                              status,
                            ).withValues(
                              alpha: 0.12,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              20,
                            ),
                          ),
                          child: Text(
                            _statusText(
                              status,
                            ),
                            style:
                                TextStyle(
                              color:
                                  _statusColor(
                                status,
                              ),
                              fontWeight:
                                  FontWeight
                                      .bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // DELIVERY INFORMATION
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
                            .blue
                            .withValues(
                          alpha: 0.08,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                        border:
                            Border.all(
                          color: Colors
                              .blue
                              .withValues(
                            alpha: 0.20,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          const Icon(
                            Icons
                                .local_shipping_outlined,
                            color:
                                Colors.blue,
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                const Text(
                                  'Seller Delivery',
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  'The seller is responsible for delivering this order directly to the customer.',
                                  style:
                                      TextStyle(
                                    color: Colors
                                        .grey
                                        .shade700,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    const Text(
                      'Products',
                      style:
                          TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    _orderItems(
                      items,
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    _moneyRow(
                      'Selling Total',
                      sellingTotal,
                    ),

                    if (supplierTotal >
                        0)
                      _moneyRow(
                        'Supplier Cost',
                        supplierTotal,
                      ),

                    if (discount > 0)
                      _moneyRow(
                        'Discount',
                        discount,
                      ),

                    if (deliveryFee > 0)
                      _moneyRow(
                        'Delivery Fee',
                        deliveryFee,
                      ),

                    const Divider(
                      height: 20,
                    ),

                    if (profit != 0)
                      _moneyRow(
                        'Your Profit',
                        profit,
                        profitStyle:
                            true,
                      ),

                    const SizedBox(
                      height: 15,
                    ),

                    // READ-ONLY STATUS MESSAGE
                    Container(
                      width:
                          double.infinity,
                      padding:
                          const EdgeInsets.all(
                        12,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Theme.of(
                          context,
                        )
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(
                              alpha: 0.45,
                            ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons
                                .info_outline_rounded,
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: Text(
                              'Order status is updated by the seller. You can track the delivery status here.',
                              style:
                                  TextStyle(
                                fontSize: 12,
                                color: Colors
                                    .grey
                                    .shade700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
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

  // =========================================================
  // DETAIL ROW
  // =========================================================

  Widget _detailRow(
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 7,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              title,
              style:
                  TextStyle(
                color:
                    Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MONEY ROW
  // =========================================================

  Widget _moneyRow(
    String title,
    double value, {
    bool profitStyle = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,
        children: [
          Text(
            title,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          Text(
            _money(value),
            style:
                TextStyle(
              fontWeight:
                  FontWeight.bold,
              color: profitStyle
                  ? Colors.green
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ORDER CARD
  // =========================================================

  Widget _orderCard(
    DocumentSnapshot order,
  ) {
    final rawData = order.data();

    if (rawData is! Map) {
      return const SizedBox.shrink();
    }

    final data =
        Map<String, dynamic>.from(
      rawData.map(
        (key, value) => MapEntry(
          key.toString(),
          value,
        ),
      ),
    );

    final orderId =
        _orderId(
      order,
      data,
    );

    final customerName =
        _stringValue(
      data['customerName'],
    ).isNotEmpty
            ? _stringValue(
                data['customerName'],
              )
            : 'Customer';

    final phone =
        _stringValue(
      data['customerPhone'],
    ).isNotEmpty
            ? _stringValue(
                data['customerPhone'],
              )
            : _stringValue(
                data['phone'],
              );

    final status =
        _stringValue(
      data['orderStatus'],
    ).isNotEmpty
            ? _stringValue(
                data['orderStatus'],
              ).toLowerCase()
            : 'placed';

    final items =
        data['items'] is List
            ? List<dynamic>.from(
                data['items'] as List,
              )
            : <dynamic>[];

    final sellingTotal =
        _toDouble(
      data['sellingTotal'] ??
          data['total'],
    );

    final supplierTotal =
        _toDouble(
      data['supplierTotal'],
    );

    final profit =
        _toDouble(
      data['resellerProfit'] ??
          data['profit'],
    );

    final date =
        _formatDate(
      data['createdAt'],
    );

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      elevation: 1.5,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        onTap: () {
          _showOrderDetails(
            order,
          );
        },
        child: Padding(
          padding:
              const EdgeInsets.all(
            13,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              // TOP
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'Order #$orderId',
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          date,
                          style:
                              TextStyle(
                            fontSize: 11,
                            color: Colors
                                .grey
                                .shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          _statusColor(
                        status,
                      ).withValues(
                        alpha: 0.12,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        20,
                      ),
                    ),
                    child: Text(
                      _statusText(
                        status,
                      ),
                      style:
                          TextStyle(
                        color:
                            _statusColor(
                          status,
                        ),
                        fontSize: 11,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(
                height: 22,
              ),

              // CUSTOMER
              Row(
                children: [
                  const Icon(
                    Icons
                        .person_outline_rounded,
                    size: 19,
                  ),
                  const SizedBox(
                    width: 7,
                  ),
                  Expanded(
                    child: Text(
                      customerName,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight
                                .w600,
                      ),
                    ),
                  ),
                ],
              ),

              if (phone.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets
                          .only(
                    top: 5,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons
                            .phone_outlined,
                        size: 17,
                      ),
                      const SizedBox(
                        width: 7,
                      ),
                      Text(
                        phone,
                        style:
                            TextStyle(
                          fontSize: 12,
                          color: Colors
                              .grey
                              .shade700,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(
                height: 10,
              ),

              // ITEMS
              Row(
                children: [
                  const Icon(
                    Icons
                        .inventory_2_outlined,
                    size: 18,
                  ),
                  const SizedBox(
                    width: 7,
                  ),
                  Text(
                    '${items.length} product${items.length == 1 ? '' : 's'}',
                    style:
                        TextStyle(
                      fontSize: 12,
                      color: Colors
                          .grey
                          .shade700,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 10,
              ),

              // DELIVERY NOTE
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.blue
                      .withValues(
                    alpha: 0.07,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    8,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons
                          .local_shipping_outlined,
                      size: 17,
                      color:
                          Colors.blue,
                    ),
                    SizedBox(
                      width: 7,
                    ),
                    Expanded(
                      child: Text(
                        'Seller is responsible for delivery',
                        style:
                            TextStyle(
                          fontSize: 11,
                          fontWeight:
                              FontWeight
                                  .w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              // TOTALS
              Row(
                children: [
                  Expanded(
                    child:
                        _miniMoney(
                      'Selling',
                      sellingTotal,
                    ),
                  ),
                  Expanded(
                    child:
                        _miniMoney(
                      'Supplier',
                      supplierTotal,
                    ),
                  ),
                  Expanded(
                    child:
                        _miniMoney(
                      'Profit',
                      profit,
                      green: true,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 12,
              ),

              // BUTTON
              SizedBox(
                width:
                    double.infinity,
                child:
                    OutlinedButton.icon(
                  onPressed: () {
                    _showOrderDetails(
                      order,
                    );
                  },
                  icon:
                      const Icon(
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
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // MINI MONEY
  // =========================================================

  Widget _miniMoney(
    String title,
    double value, {
    bool green = false,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment
              .start,
      children: [
        Text(
          title,
          style:
              TextStyle(
            fontSize: 10,
            color:
                Colors.grey.shade600,
          ),
        ),
        const SizedBox(
          height: 3,
        ),
        Text(
          _money(value),
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style:
              TextStyle(
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

  // =========================================================
  // EMPTY
  // =========================================================

  Widget _emptyView() {
    return Center(
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment
                  .center,
          children: [
            Icon(
              Icons
                  .shopping_bag_outlined,
              size: 80,
              color:
                  Colors.grey.shade500,
            ),
            const SizedBox(
              height: 18,
            ),
            const Text(
              'No Reseller Orders Yet',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              'Orders placed through your reseller store will appear here.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    Colors.grey.shade600,
                height: 1.5,
              ),
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
  Widget build(
    BuildContext context,
  ) {
    final user =
        _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title:
              const Text(
            'Reseller Orders',
          ),
        ),
        body:
            const Center(
          child: Text(
            'Please login first.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Reseller Orders',
        ),
      ),
      body:
          StreamBuilder<
              QuerySnapshot<
                  Map<String, dynamic>>>(
        stream: _firestore
            .collection(
              'reseller_orders',
            )
            .where(
              'entrepreneurUid',
              isEqualTo: user.uid,
            )
            .snapshots(),
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  24,
                ),
                child: Text(
                  'Could not load reseller orders.\n\n${snapshot.error}',
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

          final docs =
              snapshot.data?.docs ??
                  [];

          if (docs.isEmpty) {
            return _emptyView();
          }

          docs.sort(
            (a, b) {
              final aData =
                  a.data();

              final bData =
                  b.data();

              final aDate =
                  _dateValue(
                aData['createdAt'],
              );

              final bDate =
                  _dateValue(
                bData['createdAt'],
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

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child:
                ListView.builder(
              padding:
                  const EdgeInsets.all(
                12,
              ),
              physics:
                  const AlwaysScrollableScrollPhysics(),
              itemCount:
                  docs.length,
              itemBuilder:
                  (
                context,
                index,
              ) {
                return _orderCard(
                  docs[index],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
