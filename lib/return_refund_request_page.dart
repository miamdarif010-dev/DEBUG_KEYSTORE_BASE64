import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'my_return_refund_requests_page.dart';

class ReturnRefundRequestPage extends StatefulWidget {
  final String orderId;
  final String sellerOrderId;
  final String sellerId;
  final String sellerCode;
  final Map<String, dynamic> product;

  const ReturnRefundRequestPage({
    super.key,
    required this.orderId,
    required this.sellerOrderId,
    required this.sellerId,
    required this.sellerCode,
    required this.product,
  });

  @override
  State<ReturnRefundRequestPage> createState() =>
      _ReturnRefundRequestPageState();
}

class _ReturnRefundRequestPageState
    extends State<ReturnRefundRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _detailsController =
      TextEditingController();

  String _requestType = 'return';
  String _reason = 'Product damaged';
  bool _submitting = false;

  final List<String> _reasons = [
    'Product damaged',
    'Wrong product received',
    'Product is defective',
    'Product does not match description',
    'Missing item',
    'Changed my mind',
    'Other',
  ];

  String _stringValue(dynamic value) {
    return value?.toString() ?? '';
  }

  double _numberValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _intValue(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 1;
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Login Required',
        'Please login before submitting a return or refund request.',
      );
      return;
    }

    if (_submitting) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final productId = _stringValue(widget.product['productId']);

      if (productId.isEmpty) {
        throw Exception('Product ID is missing.');
      }

      final productName =
          _stringValue(widget.product['productName']).isEmpty
              ? 'Product'
              : _stringValue(widget.product['productName']);

      final imageUrl =
          _stringValue(widget.product['imageUrl']).isNotEmpty
              ? _stringValue(widget.product['imageUrl'])
              : _stringValue(widget.product['productImageUrl']);

      final quantity = _intValue(widget.product['quantity']);
      final price = _numberValue(widget.product['price']);

      final existingQuery = await FirebaseFirestore.instance
          .collection('return_refund_requests')
          .where(
            'customerId',
            isEqualTo: user.uid,
          )
          .get();

      for (final doc in existingQuery.docs) {
        final data = doc.data();

        final existingOrderId =
            _stringValue(data['orderId']);

        final existingSellerOrderId =
            _stringValue(data['sellerOrderId']);

        final existingProductId =
            _stringValue(data['productId']);

        final existingStatus =
            _stringValue(data['status']).toLowerCase();

        if (existingOrderId == widget.orderId &&
            existingSellerOrderId == widget.sellerOrderId &&
            existingProductId == productId &&
            existingStatus != 'rejected' &&
            existingStatus != 'completed') {
          if (mounted) {
            _showMessage(
              'Request Already Exists',
              'You already have an active return or refund request for this product.',
            );
          }

          setState(() {
            _submitting = false;
          });

          return;
        }
      }

      final customerName =
          user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : 'Customer';

      final requestData = <String, dynamic>{
        'customerId': user.uid,
        'customerEmail': user.email ?? '',
        'customerName': customerName,
        'orderId': widget.orderId,
        'sellerOrderId': widget.sellerOrderId,
        'sellerId': widget.sellerId,
        'sellerCode': widget.sellerCode,
        'productId': productId,
        'productName': productName,
        'productImageUrl': imageUrl,
        'quantity': quantity,
        'price': price,
        'requestType': _requestType,
        'reason': _reason,
        'details': _detailsController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('return_refund_requests')
          .add(requestData);

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Request Submitted'),
                ),
              ],
            ),
            content: Text(
              _requestType == 'return'
                  ? 'Your return request has been submitted successfully. '
                      'The seller will review your request.'
                  : 'Your refund request has been submitted successfully. '
                      'The seller will review your request.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const MyReturnRefundRequestsPage(),
        ),
        (route) => route.isFirst,
      );
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Request Failed',
        e.message ?? 'Could not submit your request.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Request Failed',
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _showMessage(
    String title,
    String message,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _productImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        width: 86,
        height: 86,
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
        imageUrl,
        width: 86,
        height: 86,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
            ),
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

  Widget _requestTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Request Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        RadioGroup<String>(
          groupValue: _requestType,
          onChanged: (value) {
            if (value == null) {
              return;
            }

            setState(() {
              _requestType = value;
            });
          },
          child: Column(
            children: [
              Card(
                child: RadioListTile<String>(
                  value: 'return',
                  title: const Text('Return Product'),
                  subtitle: const Text(
                    'I want to return this product.',
                  ),
                  secondary: const Icon(
                    Icons.assignment_return_outlined,
                    color: Colors.redAccent,
                  ),
                ),
              ),
              Card(
                child: RadioListTile<String>(
                  value: 'refund',
                  title: const Text('Request Refund'),
                  subtitle: const Text(
                    'I want to request a refund.',
                  ),
                  secondary: const Icon(
                    Icons.currency_exchange,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productName =
        _stringValue(widget.product['productName']).isEmpty
            ? 'Product'
            : _stringValue(widget.product['productName']);

    final imageUrl =
        _stringValue(widget.product['imageUrl']).isNotEmpty
            ? _stringValue(widget.product['imageUrl'])
            : _stringValue(widget.product['productImageUrl']);

    final quantity = _intValue(widget.product['quantity']);
    final price = _numberValue(widget.product['price']);
    final total = price * quantity;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Return / Refund'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.redAccent,
                    Colors.red.shade700,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.assignment_return_outlined,
                    color: Colors.white,
                    size: 42,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Return or Refund Request',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Submit a request for this product.',
                    style: TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _productImage(imageUrl),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text('Quantity: $quantity'),
                          const SizedBox(height: 4),
                          Text(
                            'Price: ৳${price.toStringAsFixed(0)}',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total: ৳${total.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Seller: ${widget.sellerCode}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            _requestTypeSelector(),

            const SizedBox(height: 20),

            const Text(
              'Reason',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(
                  Icons.help_outline,
                ),
              ),
              items: _reasons.map((reason) {
                return DropdownMenuItem<String>(
                  value: reason,
                  child: Text(reason),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _reason = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a reason.';
                }

                return null;
              },
            ),

            const SizedBox(height: 20),

            const Text(
              'Additional Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            TextFormField(
              controller: _detailsController,
              maxLines: 5,
              maxLength: 500,
              decoration: InputDecoration(
                hintText:
                    'Describe the problem or explain your request...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your request will be reviewed by the seller. '
                      'Return or refund eligibility depends on the product, '
                      'seller policy and order status.',
                      style: TextStyle(
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed:
                    _submitting ? null : _submitRequest,
                icon: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_outlined,
                      ),
                label: Text(
                  _submitting
                      ? 'Submitting...'
                      : 'Submit Request',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const MyReturnRefundRequestsPage(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.pending_actions_outlined,
                ),
                label: const Text(
                  'My Return & Refund Requests',
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
