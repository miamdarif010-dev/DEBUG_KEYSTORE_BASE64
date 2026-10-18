import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'cart_page.dart';
import 'price_discount.dart';
import 'product_details_page.dart';
import 'product_share.dart';

class MyStorePage extends StatefulWidget {
  const MyStorePage({super.key});

  @override
  State<MyStorePage> createState() => _MyStorePageState();
}

class _MyStorePageState extends State<MyStorePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // =========================================================
  // MONEY FORMAT
  // =========================================================

  String _money(double value) {
    if (value == value.roundToDouble()) {
      return '৳${value.toInt()}';
    }

    return '৳${value.toStringAsFixed(2)}';
  }

  // =========================================================
  // DOUBLE CONVERTER
  // =========================================================

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  // =========================================================
  // ADD RESELLER PRODUCT TO COMMON BUYNOVA CART
  // =========================================================

  Future<void> _addToCart(DocumentSnapshot product) async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please login first.');
      return;
    }

    final data = product.data() as Map<String, dynamic>;

    final productName = data['productName']?.toString() ??
        data['name']?.toString() ??
        'Product';

    final imageUrl = data['imageUrl']?.toString() ?? '';

    // `sellingPrice` is the price after the reseller's discount.
    final sellingPrice = _toDouble(data['sellingPrice']);

    final supplierPrice = _toDouble(data['supplierPrice']);

    final sellerId = data['sellerId']?.toString() ?? '';

    final entrepreneurUid = data['entrepreneurUid']?.toString() ?? '';

    final sourceProductId = data['sourceProductId']?.toString() ?? '';

    final active = data['active'] == true;

    if (!active) {
      _showMessage('This product is currently inactive.');
      return;
    }

    if (sellingPrice <= 0) {
      _showMessage('This product has an invalid selling price.');
      return;
    }

    if (supplierPrice <= 0) {
      _showMessage('Supplier price is missing.');
      return;
    }

    if (sellerId.isEmpty) {
      _showMessage('Seller information is missing.');
      return;
    }

    if (entrepreneurUid.isEmpty || entrepreneurUid != user.uid) {
      _showMessage('This reseller product does not belong to your account.');
      return;
    }

    if (sourceProductId.isEmpty) {
      _showMessage('Original product information is missing.');
      return;
    }

    final calculatedProfit = sellingPrice - supplierPrice;

    if (calculatedProfit <= 0) {
      _showMessage('Selling price must be higher than supplier price.');
      return;
    }

    try {
      // CartService.addItem IS STATIC. Quantity is handled by the service.
      await CartService.addItem(
        id: product.id,
        name: productName,
        price: sellingPrice,
        imageUrl: imageUrl.isNotEmpty ? imageUrl : null,

        // Reseller information
        isResellerProduct: true,
        entrepreneurUid: user.uid,
        sellerId: sellerId,
        supplierProductId: sourceProductId,
        supplierPrice: supplierPrice,
        resellerProfit: calculatedProfit,
      );

      if (!mounted) return;

      _showMessage('$productName added to cart.');
    } catch (e) {
      if (!mounted) return;

      _showMessage('Could not add product to cart: $e');
    }
  }

  // =========================================================
  // SHOW MESSAGE
  // =========================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================
  // DELETE PRODUCT
  // =========================================================

  Future<void> _deleteProduct(DocumentSnapshot product) async {
    final data = product.data() as Map<String, dynamic>;

    final productName = data['productName']?.toString() ??
        data['name']?.toString() ??
        'Product';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove Product?'),
          content: Text('Remove "$productName" from your store?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _firestore.collection('reseller_products').doc(product.id).delete();

      if (!mounted) return;

      _showMessage('Product removed from your store.');
    } catch (e) {
      if (!mounted) return;

      _showMessage('Could not remove product: $e');
    }
  }

  // =========================================================
  // TOGGLE PRODUCT STATUS
  // =========================================================

  Future<void> _toggleProductStatus(DocumentSnapshot product) async {
    final data = product.data() as Map<String, dynamic>;

    final active = data['active'] == true;

    try {
      await _firestore.collection('reseller_products').doc(product.id).update({
        'active': !active,
        'status': !active ? 'active' : 'inactive',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showMessage(
        !active ? 'Product is now active.' : 'Product is now inactive.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage('Could not update product: $e');
    }
  }

  // =========================================================
  // EDIT PRICE + DISCOUNT
  // =========================================================

  Future<void> _editSellingPrice(DocumentSnapshot product) async {
    final data = product.data() as Map<String, dynamic>;

    final supplierPrice = _toDouble(data['supplierPrice']);

    final currentSellingPrice = _toDouble(data['sellingPrice']);

    final storedOriginal = _toDouble(data['originalPrice']);

    // Total price before discount (same as selling price when no discount).
    final double original = storedOriginal > currentSellingPrice
        ? storedOriginal
        : currentSellingPrice;

    final double currentDiscount = original - currentSellingPrice;

    final productName = data['productName']?.toString() ??
        data['name']?.toString() ??
        'Product';

    DiscountResult result = DiscountResult(
      original: original,
      finalPrice: currentSellingPrice,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final double profit = result.finalPrice - supplierPrice;

            return AlertDialog(
              title: const Text('Edit Price & Discount'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text('Supplier Price: ${_money(supplierPrice)}'),
                    const SizedBox(height: 14),
                    DiscountPriceInput(
                      originalLabel: 'Your Total Price',
                      initialOriginal: original,
                      initialDiscountAmount: currentDiscount,
                      onChanged: (value) {
                        setDialogState(() {
                          result = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: profit > 0 ? Colors.green : Colors.red,
                        ),
                      ),
                      child: Text(
                        profit > 0
                            ? 'Your profit: ${_money(profit)}'
                            : 'Customer price must stay above the supplier price.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: profit > 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
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

                    final bool hasDiscount = result.hasDiscount;

                    try {
                      await _firestore
                          .collection('reseller_products')
                          .doc(product.id)
                          .update({
                        // What the customer pays
                        'sellingPrice': result.finalPrice,
                        'profit': result.finalPrice - supplierPrice,

                        // Discount information (display only)
                        'originalPrice':
                            hasDiscount ? result.original : result.finalPrice,
                        'discountAmount': hasDiscount ? result.amount : 0,
                        'discountPercent': hasDiscount ? result.percent : 0,
                        'hasDiscount': hasDiscount,

                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                      if (!dialogContext.mounted) {
                        return;
                      }

                      Navigator.pop(dialogContext);

                      if (!mounted) return;

                      _showMessage('Price updated.');
                    } catch (e) {
                      if (!mounted) return;

                      _showMessage('Could not update price: $e');
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================
  // PRODUCT CARD
  // =========================================================

  // =========================================================
  // OPEN PRODUCT DETAILS (exactly what a customer sees)
  // =========================================================
  // The public listing is loaded from the server: it never contains the
  // supplier price or your profit.

  Future<void> _openDetails(DocumentSnapshot product) async {
    final data = product.data() as Map<String, dynamic>;

    Map<String, dynamic> listing;

    try {
      final result = await FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      ).httpsCallable('getResellerListing').call({'listingId': product.id});

      final json = jsonDecode(jsonEncode(result.data)) as Map<String, dynamic>;

      listing = Map<String, dynamic>.from(json['listing'] as Map);
    } catch (_) {
      // Fallback: build the public view from the store product itself
      // (still without supplier price and profit).
      final imageUrl = data['imageUrl']?.toString() ?? '';

      listing = <String, dynamic>{
        'name': data['productName'] ?? data['name'] ?? '',
        'description': data['description'] ?? '',
        'imageUrl': imageUrl,
        'images': imageUrl.isEmpty ? <String>[] : <String>[imageUrl],
        'category': data['category'] ?? '',
        'price': _toDouble(data['sellingPrice']),
        'originalPrice': _toDouble(data['originalPrice']),
        'currency': 'BDT',
        'isResellerProduct': true,
        'entrepreneurUid': data['entrepreneurUid'] ?? '',
        'sellerId': data['sellerId'] ?? '',
      };
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailsPage(
          productId: product.id,
          product: listing,
        ),
      ),
    );
  }

  // =========================================================
  // SHARE (Facebook, WhatsApp, Messenger, ...)
  // The link and text never contain supplier price or profit.
  // =========================================================

  Future<void> _shareListing(DocumentSnapshot product) async {
    final data = product.data() as Map<String, dynamic>;

    final name = data['productName']?.toString() ??
        data['name']?.toString() ??
        'Product';

    final selling = _toDouble(data['sellingPrice']);
    final original = _toDouble(data['originalPrice']);

    final String priceText = original > selling
        ? '${_money(selling)} (was ${_money(original)})'
        : _money(selling);

    try {
      await ProductShare.share(
        productId: product.id,
        product: <String, dynamic>{
          'isResellerProduct': true,
          'listingId': product.id,
          'entrepreneurUid': data['entrepreneurUid'] ?? '',
        },
        name: name,
        formattedPrice: priceText,
      );
    } catch (e) {
      _showMessage('Could not share: $e');
    }
  }

  Widget _productCard(DocumentSnapshot product) {
    return GestureDetector(
      onTap: () {
        _openDetails(product);
      },
      child: _productCardBody(product),
    );
  }

  Widget _productCardBody(DocumentSnapshot product) {
    final data = product.data() as Map<String, dynamic>;

    final productName = data['productName']?.toString() ??
        data['name']?.toString() ??
        'Unnamed Product';

    final imageUrl = data['imageUrl']?.toString() ?? '';

    final category = data['category']?.toString() ?? 'General';

    final sellerCode = data['sellerCode']?.toString() ?? '';

    final supplierPrice = _toDouble(data['supplierPrice']);

    final sellingPrice = _toDouble(data['sellingPrice']);

    final originalPrice = _toDouble(data['originalPrice']);

    final profit = _toDouble(data['profit']);

    final active = data['active'] == true;

    final salesCount =
        data['salesCount'] is num ? (data['salesCount'] as num).toInt() : 0;

    final views = data['views'] is num ? (data['views'] as num).toInt() : 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IMAGE
          Stack(
            children: [
              SizedBox(
                height: 180,
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
                                size: 42,
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.image_outlined, size: 42),
                        ),
                      ),
              ),

              // STATUS
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: active ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    active ? 'ACTIVE' : 'INACTIVE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // MENU
              Positioned(
                top: 4,
                right: 4,
                child: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'share') {
                      _shareListing(product);
                    } else if (value == 'price') {
                      _editSellingPrice(product);
                    } else if (value == 'status') {
                      _toggleProductStatus(product);
                    } else if (value == 'delete') {
                      _deleteProduct(product);
                    }
                  },
                  itemBuilder: (context) {
                    return [
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share_outlined),
                            SizedBox(width: 10),
                            Text('Share'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'price',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded),
                            SizedBox(width: 10),
                            Text('Edit Price & Discount'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'status',
                        child: Row(
                          children: [
                            Icon(
                              active
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                            const SizedBox(width: 10),
                            Text(active ? 'Deactivate' : 'Activate'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red,
                            ),
                            SizedBox(width: 10),
                            Text('Remove', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ),
            ],
          ),

          // DETAILS
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  category,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 9),
                if (sellerCode.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.storefront_outlined, size: 15),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          sellerCode,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),

                // SUPPLIER PRICE
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Supplier', style: TextStyle(fontSize: 12)),
                    Text(
                      _money(supplierPrice),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),

                // SELLING PRICE (with red struck total price + % badge)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Selling', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PriceTag(
                        price: sellingPrice,
                        originalPrice:
                            originalPrice > sellingPrice ? originalPrice : null,
                        fontSize: 14,
                        align: WrapAlignment.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // PROFIT
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Profit',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _money(profit),
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),

                // STATS
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Views: $views',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Text(
                      'Sales: $salesCount',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // SHARE
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _shareListing(product);
                    },
                    icon: const Icon(Icons.share_outlined, size: 19),
                    label: const Text('Share to Sell'),
                  ),
                ),
                const SizedBox(height: 8),

                // ADD TO CART
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: FilledButton.icon(
                    onPressed: active
                        ? () {
                            _addToCart(product);
                          }
                        : null,
                    icon: const Icon(Icons.shopping_cart_outlined, size: 19),
                    label: const Text('Add to Cart'),
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
  // EMPTY VIEW
  // =========================================================

  Widget _emptyView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 80,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 18),
            const Text(
              'Your Store Is Empty',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Go to Available Products and add products from approved sellers to start your store.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
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
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Store')),
        body: const Center(child: Text('Please login first.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Store')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('reseller_products')
            .where('entrepreneurUid', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load your store.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return _emptyView();
          }

          // SUMMARY
          double totalProfit = 0;
          int activeProducts = 0;

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;

            totalProfit += _toDouble(data['profit']);

            if (data['active'] == true) {
              activeProducts++;
            }
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _summaryCard(
                        icon: Icons.inventory_2_outlined,
                        title: 'Products',
                        value: '${docs.length}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _summaryCard(
                        icon: Icons.check_circle_outline,
                        title: 'Active',
                        value: '$activeProducts',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _summaryCard(
                        icon: Icons.trending_up_rounded,
                        title: 'Profit',
                        value: _money(totalProfit),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: 560,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      return _productCard(docs[index]);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================================================
  // SUMMARY CARD
  // =========================================================

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 21),
          const SizedBox(height: 5),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
