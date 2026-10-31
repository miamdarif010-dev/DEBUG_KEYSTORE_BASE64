import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SellerReturnRefundPage extends StatelessWidget {
  const SellerReturnRefundPage({super.key});

  // =========================================================
  // REQUEST STREAM
  // =========================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> _requestStream(
    String uid,
  ) {
    return FirebaseFirestore.instance
        .collection('return_refund_requests')
        .where('sellerId', isEqualTo: uid)
        .snapshots();
  }

  // =========================================================
  // STATUS TEXT
  // =========================================================

  String _statusText(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      default:
        return 'Pending';
    }
  }

  // =========================================================
  // STATUS COLOR
  // =========================================================

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'processing':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  // =========================================================
  // REQUEST TYPE TEXT
  // =========================================================

  String _requestTypeText(String requestType) {
    return requestType.toLowerCase() == 'refund'
        ? 'Refund'
        : 'Return';
  }

  // =========================================================
  // NOTIFICATION TITLE
  // =========================================================

  String _notificationTitle(
    String status,
    String requestType,
  ) {
    final type = _requestTypeText(requestType);

    switch (status.toLowerCase()) {
      case 'approved':
        return '$type Request Approved';

      case 'rejected':
        return '$type Request Rejected';

      case 'processing':
        return '$type Request Processing';

      case 'completed':
        return '$type Request Completed';

      default:
        return '$type Request Updated';
    }
  }

  // =========================================================
  // NOTIFICATION MESSAGE
  // =========================================================

  String _notificationMessage({
    required String status,
    required String requestType,
    required String productName,
    required String sellerMessage,
  }) {
    final type = requestType.toLowerCase() == 'refund'
        ? 'refund'
        : 'return';

    String message;

    switch (status.toLowerCase()) {
      case 'approved':
        message =
            'Your $type request for "$productName" has been approved by the seller.';
        break;

      case 'rejected':
        message =
            'Your $type request for "$productName" has been rejected by the seller.';
        break;

      case 'processing':
        message =
            'Your $type request for "$productName" is now being processed.';
        break;

      case 'completed':
        message =
            'Your $type request for "$productName" has been completed.';
        break;

      default:
        message =
            'Your $type request for "$productName" has been updated.';
    }

    if (sellerMessage.trim().isNotEmpty) {
      message +=
          '\n\nSeller message: ${sellerMessage.trim()}';
    }

    return message;
  }

  // =========================================================
  // SEND BUYER NOTIFICATION
  // =========================================================

  Future<void> _sendBuyerNotification({
    required Map<String, dynamic> requestData,
    required String requestId,
    required String status,
    String sellerMessage = '',
  }) async {
    final customerId =
        requestData['customerId']?.toString() ?? '';

    if (customerId.isEmpty) {
      return;
    }

    final requestType =
        requestData['requestType']?.toString() ?? 'return';

    final productName =
        requestData['productName']?.toString() ?? 'Product';

    final finalMessage =
        sellerMessage.trim().isNotEmpty
            ? sellerMessage.trim()
            : requestData['sellerMessage']
                    ?.toString() ??
                '';

    final notificationRef = FirebaseFirestore.instance
        .collection('users')
        .doc(customerId)
        .collection('notifications')
        .doc();

    await notificationRef.set({
      'title': _notificationTitle(
        status,
        requestType,
      ),
      'message': _notificationMessage(
        status: status,
        requestType: requestType,
        productName: productName,
        sellerMessage: finalMessage,
      ),
      'type': 'return_refund',
      'requestId': requestId,
      'orderId':
          requestData['orderId']?.toString() ?? '',
      'sellerOrderId':
          requestData['sellerOrderId']?.toString() ?? '',
      'sellerId':
          requestData['sellerId']?.toString() ?? '',
      'sellerCode':
          requestData['sellerCode']?.toString() ?? '',
      'productId':
          requestData['productId']?.toString() ?? '',
      'productName': productName,
      'requestType': requestType,
      'requestStatus': status,
      'sellerMessage': finalMessage,
      'isRead': false,
      'createdAt':
          FieldValue.serverTimestamp(),
    });
  }

  // =========================================================
  // UPDATE REQUEST
  // =========================================================

  Future<void> _updateRequest({
    required BuildContext context,
    required String requestId,
    required String status,
    required Map<String, dynamic> requestData,
    String sellerMessage = '',
  }) async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final requestSellerId =
        requestData['sellerId']?.toString() ?? '';

    if (requestSellerId != user.uid) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You are not allowed to update this request.',
          ),
        ),
      );

      return;
    }

    final currentStatus =
        requestData['status']?.toString() ?? 'pending';

    if (currentStatus == status) {
      return;
    }

    try {
      final firestore =
          FirebaseFirestore.instance;

      final requestRef = firestore
          .collection('return_refund_requests')
          .doc(requestId);

      final updateData =
          <String, dynamic>{
        'status': status,
        'updatedAt':
            FieldValue.serverTimestamp(),
      };

      if (sellerMessage.trim().isNotEmpty) {
        updateData['sellerMessage'] =
            sellerMessage.trim();

        updateData['sellerNote'] =
            sellerMessage.trim();
      }

      if (status == 'approved') {
        updateData['approvedAt'] =
            FieldValue.serverTimestamp();
      }

      if (status == 'rejected') {
        updateData['rejectedAt'] =
            FieldValue.serverTimestamp();
      }

      if (status == 'completed') {
        updateData['completedAt'] =
            FieldValue.serverTimestamp();
      }

      await requestRef.update(updateData);

      await _sendBuyerNotification(
        requestData: requestData,
        requestId: requestId,
        status: status,
        sellerMessage: sellerMessage,
      );

      if (!context.mounted) return;

      final type =
          _requestTypeText(
        requestData['requestType']
                ?.toString() ??
            'return',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$type request changed to '
            '${_statusText(status)}.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update request.\n$e',
          ),
        ),
      );
    }
  }

  // =========================================================
  // SELLER MESSAGE DIALOG
  // =========================================================

  Future<void> _showSellerMessageDialog(
    BuildContext context, {
    required String requestId,
    required String status,
    required Map<String, dynamic> requestData,
  }) async {
    final controller =
        TextEditingController(
      text:
          requestData['sellerMessage']
                  ?.toString() ??
              '',
    );

    final type =
        _requestTypeText(
      requestData['requestType']
              ?.toString() ??
          'return',
    );

    final messageRequired =
        status == 'rejected';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            status == 'rejected'
                ? 'Reject $type Request'
                : '${_statusText(status)} $type Request',
          ),
          content: TextField(
            controller: controller,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Seller Message',
              hintText:
                  'Write a message for the customer...',
              border:
                  const OutlineInputBorder(),
              alignLabelWithHint: true,
              helperText: messageRequired
                  ? 'Message is recommended when rejecting.'
                  : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final message =
                    controller.text.trim();

                Navigator.pop(
                  dialogContext,
                );

                await _updateRequest(
                  context: context,
                  requestId: requestId,
                  status: status,
                  requestData: requestData,
                  sellerMessage: message,
                );
              },
              child: Text(
                _statusText(status),
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  // =========================================================
  // COMPLETE + REFUND (server moves the money)
  // =========================================================
  //
  // "Completed" is no longer a plain status change. The Cloud Function
  // completeReturnRefund refunds the customer's BuyNova Wallet and takes the
  // same amount back from the seller's earning (and BuyNova's commission),
  // all in one step, and then marks the request completed.

  Future<void> _completeWithRefund(
    BuildContext context, {
    required String requestId,
    required Map<String, dynamic> requestData,
  }) async {
    final type = _requestTypeText(
      requestData['requestType']?.toString() ?? 'return',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Complete $type & Refund'),
          content: const Text(
            'The customer will be refunded to the BuyNova Wallet and '
            'the same amount will be taken back from your earnings. '
            'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Refund'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      ).httpsCallable('completeReturnRefund').call({
        'requestId': requestId,
      });

      final data = result.data is Map
          ? Map<String, dynamic>.from(result.data as Map)
          : <String, dynamic>{};

      final amount = (data['refundAmount'] as num?)?.toDouble() ?? 0;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            data['alreadyDone'] == true
                ? 'This request was already refunded.'
                : '$type completed. ৳${amount.toStringAsFixed(2)} '
                    'was refunded to the customer.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Could not complete the refund.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not complete the refund.\n$e'),
        ),
      );
    }
  }

  // =========================================================
  // STATUS MENU
  // =========================================================

  void _showStatusMenu(
    BuildContext context, {
    required String requestId,
    required String currentStatus,
    required Map<String, dynamic> requestData,
  }) {
    const statuses = [
      'pending',
      'approved',
      'processing',
      'rejected',
      'completed',
    ];

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.all(16),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const Text(
                  'Update Request Status',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  _requestTypeText(
                    requestData['requestType']
                            ?.toString() ??
                        'return',
                  ),
                  style: TextStyle(
                    color:
                        Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 12),

                ...statuses.map(
                  (status) {
                    final selected =
                        status ==
                            currentStatus;

                    return ListTile(
                      leading: Icon(
                        selected
                            ? Icons
                                .radio_button_checked
                            : Icons
                                .radio_button_unchecked,
                        color: selected
                            ? _statusColor(
                                status,
                              )
                            : Colors.grey,
                      ),
                      title: Text(
                        _statusText(
                          status,
                        ),
                      ),
                      onTap: () async {
                        Navigator.pop(
                          sheetContext,
                        );

                        if (status ==
                            currentStatus) {
                          return;
                        }

                        if (status == 'completed') {
                          await _completeWithRefund(
                            context,
                            requestId: requestId,
                            requestData: requestData,
                          );
                          return;
                        }

                        if (status ==
                                'approved' ||
                            status ==
                                'rejected') {
                          await _showSellerMessageDialog(
                            context,
                            requestId:
                                requestId,
                            status:
                                status,
                            requestData:
                                requestData,
                          );
                        } else {
                          await _updateRequest(
                            context:
                                context,
                            requestId:
                                requestId,
                            status:
                                status,
                            requestData:
                                requestData,
                          );
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // STATUS BADGE
  // =========================================================

  Widget _statusBadge(String status) {
    final color =
        _statusColor(status);

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        _statusText(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }

  // =========================================================
  // PRODUCT IMAGE
  // =========================================================

  Widget _productImage(String url) {
    if (url.isEmpty) {
      return Container(
        width: 70,
        height: 70,
        decoration:
            BoxDecoration(
          color:
              Colors.grey.shade200,
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons
              .image_not_supported_outlined,
          color: Colors.grey,
        ),
      );
    }

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) {
          return Container(
            width: 70,
            height: 70,
            color:
                Colors.grey.shade200,
            child: const Icon(
              Icons
                  .broken_image_outlined,
              color: Colors.grey,
            ),
          );
        },
      ),
    );
  }

  // =========================================================
  // REQUEST CARD
  // =========================================================

  Widget _requestCard(
    BuildContext context,
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) {
    final data = doc.data();

    final requestType =
        data['requestType']
                ?.toString() ??
            'return';

    final status =
        data['status']
                ?.toString() ??
            'pending';

    final productName =
        data['productName']
                ?.toString() ??
            'Product';

    final productImage =
        data['productImageUrl']
                ?.toString() ??
            '';

    final customerName =
        data['customerName']
                ?.toString() ??
            '';

    final customerEmail =
        data['customerEmail']
                ?.toString() ??
            '';

    final reason =
        data['reason']
                ?.toString() ??
            '';

    final details =
        data['details']
                ?.toString() ??
            '';

    final sellerMessage =
        data['sellerMessage']
                ?.toString() ??
            '';

    final quantity =
        data['quantity'] is num
            ? (data['quantity']
                    as num)
                .toInt()
            : 1;

    final price =
        data['price'] is num
            ? (data['price']
                    as num)
                .toDouble()
            : 0;

    final total =
        data['total'] is num
            ? (data['total']
                    as num)
                .toDouble()
            : price * quantity;

    final orderId =
        data['orderId']
                ?.toString() ??
            '';

    final sellerOrderId =
        data['sellerOrderId']
                ?.toString() ??
            '';

    final requestId =
        data['requestId']
                ?.toString() ??
            doc.id;

    final type =
        _requestTypeText(
      requestType,
    );

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 16,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // -------------------------------------------------
            // HEADER
            // -------------------------------------------------

            Row(
              children: [
                Icon(
                  requestType
                              .toLowerCase() ==
                          'refund'
                      ? Icons
                          .currency_exchange
                      : Icons
                          .assignment_return_outlined,
                  color:
                      Colors.redAccent,
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    '$type Request',
                    style:
                        const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                _statusBadge(
                  status,
                ),
              ],
            ),

            const SizedBox(
              height: 14,
            ),

            // -------------------------------------------------
            // PRODUCT
            // -------------------------------------------------

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _productImage(
                  productImage,
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        'Quantity: $quantity',
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        'Price: ৳${price.toStringAsFixed(0)}',
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        'Total: ৳${total.toStringAsFixed(0)}',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      if (data['refundAmount'] is num &&
                          (data['refundAmount'] as num) > 0) ...[
                        const SizedBox(
                          height: 3,
                        ),
                        Text(
                          'Refunded: ৳${(data['refundAmount'] as num).toStringAsFixed(2)}',
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

            const Divider(
              height: 28,
            ),

            // -------------------------------------------------
            // CUSTOMER
            // -------------------------------------------------

            Text(
              'Customer',
              style: TextStyle(
                fontSize: 13,
                color:
                    Colors.grey.shade600,
              ),
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              customerName.isEmpty
                  ? 'Customer'
                  : customerName,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            if (customerEmail.isNotEmpty) ...[
              const SizedBox(
                height: 3,
              ),
              Text(
                customerEmail,
              ),
            ],

            const SizedBox(
              height: 14,
            ),

            // -------------------------------------------------
            // ORDER INFORMATION
            // -------------------------------------------------

            Text(
              'Order ID',
              style: TextStyle(
                fontSize: 13,
                color:
                    Colors.grey.shade600,
              ),
            ),

            const SizedBox(
              height: 3,
            ),

            Text(
              orderId.isEmpty
                  ? 'N/A'
                  : orderId,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            if (sellerOrderId.isNotEmpty) ...[
              const SizedBox(
                height: 8,
              ),
              Text(
                'Seller Order ID',
                style: TextStyle(
                  fontSize: 13,
                  color:
                      Colors.grey.shade600,
                ),
              ),
              const SizedBox(
                height: 3,
              ),
              Text(
                sellerOrderId,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(
              height: 14,
            ),

            // -------------------------------------------------
            // REQUEST ID
            // -------------------------------------------------

            Text(
              'Request ID',
              style: TextStyle(
                fontSize: 13,
                color:
                    Colors.grey.shade600,
              ),
            ),

            const SizedBox(
              height: 3,
            ),

            Text(
              requestId,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            // -------------------------------------------------
            // REASON
            // -------------------------------------------------

            Text(
              'Reason',
              style: TextStyle(
                fontSize: 13,
                color:
                    Colors.grey.shade600,
              ),
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              reason.isEmpty
                  ? 'Not provided'
                  : reason,
            ),

            // -------------------------------------------------
            // CUSTOMER DETAILS
            // -------------------------------------------------

            if (details.isNotEmpty) ...[
              const SizedBox(
                height: 12,
              ),
              Text(
                'Customer Details',
                style: TextStyle(
                  fontSize: 13,
                  color:
                      Colors.grey.shade600,
                ),
              ),
              const SizedBox(
                height: 4,
              ),
              Text(
                details,
              ),
            ],

            // -------------------------------------------------
            // SELLER MESSAGE
            // -------------------------------------------------

            if (sellerMessage.isNotEmpty) ...[
              const SizedBox(
                height: 14,
              ),
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.all(
                  12,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.blue
                      .withValues(
                    alpha: 0.06,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                  border:
                      Border.all(
                    color: Colors.blue
                        .withValues(
                      alpha: 0.15,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seller Message',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Colors.blue,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      sellerMessage,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(
              height: 18,
            ),

            // -------------------------------------------------
            // STATUS UPDATE
            // -------------------------------------------------

            SizedBox(
              width:
                  double.infinity,
              child:
                  OutlinedButton.icon(
                onPressed: () {
                  _showStatusMenu(
                    context,
                    requestId:
                        requestId,
                    currentStatus:
                        status,
                    requestData:
                        data,
                  );
                },
                icon: const Icon(
                  Icons.sync,
                ),
                label:
                    const Text(
                  'Update Status',
                ),
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
  Widget build(BuildContext context) {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Return & Refund Requests',
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
          'Return & Refund Requests',
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<
          QuerySnapshot<
              Map<String, dynamic>>>(
        stream:
            _requestStream(
          user.uid,
        ),
        builder:
            (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  20,
                ),
                child: Text(
                  'Could not load requests.\n\n'
                  '${snapshot.error}',
                  textAlign:
                      TextAlign.center,
                ),
              ),
            );
          }

          final requests =
              snapshot.data?.docs ??
                  [];

          if (requests.isEmpty) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  24,
                ),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons
                          .assignment_return_outlined,
                      size: 70,
                      color:
                          Colors.grey.shade400,
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    const Text(
                      'No Return or Refund Requests',
                      style:
                          TextStyle(
                        fontSize: 19,
                        fontWeight:
                            FontWeight.bold,
                      ),
                      textAlign:
                          TextAlign.center,
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    Text(
                      'Customer requests for your products '
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
            );
          }

          return ListView(
            padding:
                const EdgeInsets.all(
              16,
            ),
            children: [
              // ------------------------------------------------
              // HEADER
              // ------------------------------------------------

              Container(
                padding:
                    const EdgeInsets.all(
                  18,
                ),
                decoration:
                    BoxDecoration(
                  gradient:
                      LinearGradient(
                    colors: [
                      Colors.redAccent,
                      Colors.red.shade700,
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons
                          .assignment_return_outlined,
                      color:
                          Colors.white,
                      size: 40,
                    ),
                    const SizedBox(
                      width: 14,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Customer Requests',
                            style:
                                TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Text(
                            '${requests.length} request${requests.length == 1 ? '' : 's'}',
                            style:
                                const TextStyle(
                              color:
                                  Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // ------------------------------------------------
              // REQUESTS
              // ------------------------------------------------

              ...requests.map(
                (doc) => _requestCard(
                  context,
                  doc,
                ),
              ),

              const SizedBox(
                height: 20,
              ),
            ],
          );
        },
      ),
    );
  }
}
