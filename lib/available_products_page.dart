import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'price_discount.dart';

class AvailableProductsPage extends StatefulWidget {
  const AvailableProductsPage({super.key});

  @override
  State<AvailableProductsPage> createState() => _AvailableProductsPageState();
}

class _AvailableProductsPageState extends State<AvailableProductsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isCheckingEntrepreneur = true;
  bool _isApprovedEntrepreneur = false;

  String? _entrepreneurCode;

  @override
  void initState() {
    super.initState();
    _checkEntrepreneurApproval();
  }

  // =========================================================
  // CHECK ENTREPRENEUR APPROVAL
  // =========================================================

  Future<void> _checkEntrepreneurApproval() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _isApprovedEntrepreneur = false;
        _isCheckingEntrepreneur = false;
      });

      return;
    }

    try {
      final snapshot =
          await _firestore.collection('users').doc(user.uid).get();

      final data = snapshot.data();

      final status = data?['entrepreneurStatus']?.toString();

      final code = data?['entrepreneurCode']?.toString();

      if (!mounted) return;

      setState(() {
        _isApprovedEntrepreneur = status == 'approved';
        _entrepreneurCode = code;
        _isCheckingEntrepreneur = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isApprovedEntrepreneur = false;
        _isCheckingEntrepreneur = false;
      });

      _showMessage('Could not check entrepreneur status.');
    }
  }

  // =========================================================
  // MONEY / DOUBLE / MESSAGE
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

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // =========================================================
  // ADD TO MY STORE DIALOG
  // =========================================================

  Future<void> _showAddToStoreDialog(DocumentSnapshot product) async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please login first.');
      return;
    }

    if (!_isApprovedEntrepreneur) {
      _showMessage('Only approved entrepreneurs can resell products.');
      return;
    }

    final data = product.data() as Map<String, dynamic>;

    final productId = product.id;

    final productName = data['name']?.toString() ?? 'Product';

    // Supplier price = what the supplier's buyers pay now (after the
    // supplier's own discount, if any).
    final supplierPrice = _toDouble(data['price']);

    final imageUrl = data['imageUrl']?.toString() ?? '';

    final category = data['category']?.toString() ?? 'General';

    final description = data['description']?.toString() ?? '';

    final sellerId = data['sellerId']?.toString() ?? '';

    final sellerCode = data['sellerCode']?.toString() ?? '';

    final sellerEmail = data['sellerEmail']?.toString() ?? '';

    final sellerApproved = data['sellerApproved'] == true;

    if (sellerId.isEmpty) {
      _showMessage('Seller information is missing.');
      return;
    }

    if (!sellerApproved) {
      _showMessage('This product is not available from an approved seller.');
      return;
    }

    if (supplierPrice <= 0) {
      _showMessage('This product has an invalid supplier price.');
      return;
    }

    // Default total price = supplier price + 1000 (reseller can change it).
    final double defaultTotal = supplierPrice + 1000;

    // What the reseller typed (total price, discount %, discount amount).
    DiscountResult result = DiscountResult(
      original: defaultTotal,
      finalPrice: defaultTotal,
    );

    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // The price the customer pays and the reseller profit.
            final double finalPrice = result.finalPrice;
            final double profit = finalPrice - supplierPrice;

            return AlertDialog(
              title: const Text('Add to My Store'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imageUrl,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 150,
                              width: double.infinity,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 42,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 14),
                    Text(
                      productName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      category,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    if (sellerCode.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.storefront_rounded,
                              size: 20,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Supplier: $sellerCode',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),

                    // SUPPLIER PRICE
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Supplier Price',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _money(supplierPrice),
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // TOTAL PRICE + DISCOUNT (same input the seller uses)
                    DiscountPriceInput(
                      originalLabel: 'Your Total Price',
                      helperText: 'Price before discount. Customers pay '
                          'this minus your discount.',
                      initialOriginal: defaultTotal,
                      enabled: !isSaving,
                      onChanged: (value) {
                        setDialogState(() {
                          result = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    // PROFIT
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: profit > 0 ? Colors.green : Colors.red,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            profit > 0
                                ? Icons.trending_up_rounded
                                : Icons.warning_amber_rounded,
                            color: profit > 0 ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Your Profit (after discount)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _money(profit),
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: profit > 0
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                if (profit <= 0)
                                  const Text(
                                    'The customer price must stay above the supplier price.',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 11.5,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Product Description',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        description,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!result.isValid) {
                            _showMessage('Enter a valid price.');
                            return;
                          }

                          if (result.finalPrice <= supplierPrice) {
                            _showMessage(
                              'Customer price (after discount) must be '
                              'higher than the supplier price.',
                            );
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          final success = await _addProductToMyStore(
                            productId: productId,
                            productName: productName,
                            supplierPrice: supplierPrice,
                            discount: result,
                            imageUrl: imageUrl,
                            category: category,
                            description: description,
                            sellerId: sellerId,
                            sellerCode: sellerCode,
                            sellerEmail: sellerEmail,
                          );

                          if (!dialogContext.mounted) {
                            return;
                          }

                          if (success) {
                            Navigator.pop(dialogContext);
                          } else {
                            setDialogState(() {
                              isSaving = false;
                            });
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_business_rounded),
                  label: Text(isSaving ? 'Adding...' : 'Add to My Store'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================
  // SAVE TO RESELLER PRODUCTS
  // =========================================================

  Future<bool> _addProductToMyStore({
    required String productId,
    required String productName,
    required double supplierPrice,
    required DiscountResult discount,
    required String imageUrl,
    required String category,
    required String description,
    required String sellerId,
    required String sellerCode,
    required String sellerEmail,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please login first.');
      return false;
    }

    try {
      // CHECK ENTREPRENEUR AGAIN
      final entrepreneurSnapshot =
          await _firestore.collection('users').doc(user.uid).get();

      final entrepreneurData = entrepreneurSnapshot.data();

      final status = entrepreneurData?['entrepreneurStatus']?.toString();

      if (status != 'approved') {
        _showMessage('Your entrepreneur account is not approved.');
        return false;
      }

      final entrepreneurCode =
          entrepreneurData?['entrepreneurCode']?.toString() ??
              _entrepreneurCode ??
              '';

      if (entrepreneurCode.isEmpty) {
        _showMessage(
          'Entrepreneur ID is missing. Please contact BuyNova Admin.',
        );
        return false;
      }

      // VERIFY ORIGINAL PRODUCT STILL EXISTS
      final originalProduct =
          await _firestore.collection('products').doc(productId).get();

      if (!originalProduct.exists) {
        _showMessage('This product is no longer available.');
        return false;
      }

      final originalData = originalProduct.data();

      if (originalData == null) {
        _showMessage('Product information is unavailable.');
        return false;
      }

      if (originalData['active'] != true) {
        _showMessage('This product is no longer active.');
        return false;
      }

      if (originalData['sellerApproved'] != true) {
        _showMessage('This seller is no longer approved.');
        return false;
      }

      // The supplier may have changed the price while the dialog was open.
      final double currentSupplierPrice = _toDouble(originalData['price']);

      if (currentSupplierPrice <= 0 ||
          discount.finalPrice <= currentSupplierPrice) {
        _showMessage(
          'The supplier price changed. Please open the product again.',
        );
        return false;
      }

      // PREVENT DUPLICATE
      final existingQuery = await _firestore
          .collection('reseller_products')
          .where('entrepreneurUid', isEqualTo: user.uid)
          .where('sourceProductId', isEqualTo: productId)
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        _showMessage('This product is already in your store.');
        return false;
      }

      // `sellingPrice` is what the customer pays (after discount).
      // `originalPrice` is the total price before the discount.
      // Cart, checkout and orders use `sellingPrice`, so they stay correct.
      final bool hasDiscount = discount.hasDiscount;

      final double sellingPrice = discount.finalPrice;

      await _firestore.collection('reseller_products').add({
        // Original Seller Product
        'sourceProductId': productId,
        'productName': productName,
        'imageUrl': imageUrl,
        'category': category,
        'description': description,

        // Seller / Supplier
        'sellerId': sellerId,
        'sellerCode': sellerCode,
        'sellerEmail': sellerEmail,
        'supplierPrice': currentSupplierPrice,

        // Entrepreneur
        'entrepreneurUid': user.uid,
        'entrepreneurCode': entrepreneurCode,
        'entrepreneurEmail': user.email ?? '',

        // Entrepreneur pricing
        'sellingPrice': sellingPrice,
        'profit': sellingPrice - currentSupplierPrice,

        // Discount information (display only)
        'originalPrice': hasDiscount ? discount.original : sellingPrice,
        'discountAmount': hasDiscount ? discount.amount : 0,
        'discountPercent': hasDiscount ? discount.percent : 0,
        'hasDiscount': hasDiscount,

        // Status
        'active': true,
        'status': 'active',

        // Statistics
        'views': 0,
        'salesCount': 0,

        // Dates
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return true;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product added to your store successfully!'),
        ),
      );

      return true;
    } catch (e) {
      if (!mounted) return false;

      _showMessage('Could not add product: $e');

      return false;
    }
  }

  // =========================================================
  // NOT APPROVED
  // =========================================================

  Widget _notApprovedView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business_center_rounded,
              size: 80,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 20),
            const Text(
              'Entrepreneur Approval Required',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Only approved BuyNova entrepreneurs can source products for resale.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _checkEntrepreneurApproval,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Check Again'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // PRODUCT CARD
  // =========================================================

  Widget _productCard(DocumentSnapshot product) {
    final data = product.data() as Map<String, dynamic>;

    final name = data['name']?.toString() ?? 'Unnamed Product';

    final imageUrl = data['imageUrl']?.toString() ?? '';

    final category = data['category']?.toString() ?? 'General';

    final description = data['description']?.toString() ?? '';

    final price = _toDouble(data['price']);

    final originalPrice = _toDouble(data['originalPrice']);

    final sellerCode = data['sellerCode']?.toString() ?? '';

    final sellerApproved = data['sellerApproved'] == true;

    // Only approved seller products
    if (!sellerApproved) {
      return const SizedBox.shrink();
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 190,
            width: double.infinity,
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: 45,
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.image_outlined, size: 45),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  category,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Supplier price',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 2),
                PriceTag(
                  price: price,
                  originalPrice: originalPrice > price ? originalPrice : null,
                  fontSize: 17,
                ),
                if (sellerCode.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Seller: $sellerCode',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: () {
                      _showAddToStoreDialog(product);
                    },
                    icon: const Icon(Icons.add_business_rounded),
                    label: const Text('Add to My Store'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Products'),
        actions: [
          if (_entrepreneurCode != null && _entrepreneurCode!.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Text(
                  _entrepreneurCode!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isCheckingEntrepreneur
          ? const Center(child: CircularProgressIndicator())
          : !_isApprovedEntrepreneur
              ? _notApprovedView()
              : StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('products')
                      .where('active', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Could not load products.\n\n${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allDocs = snapshot.data?.docs ?? [];

                    // ONLY APPROVED SELLER PRODUCTS
                    final docs = allDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      return data['sellerApproved'] == true &&
                          data['sellerId'] != null &&
                          data['sellerId'].toString().isNotEmpty;
                    }).toList();

                    if (docs.isEmpty) {
                      return Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 80,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'No Products Available',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Approved sellers have not added any active products yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _checkEntrepreneurApproval,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(12),
                        physics: const AlwaysScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.58,
                        ),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          return _productCard(docs[index]);
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
