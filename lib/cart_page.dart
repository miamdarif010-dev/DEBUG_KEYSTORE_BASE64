import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'checkout_page.dart';
import 'login_page.dart';

class CartItem {
  final String id;
  final String name;
  final double price;
  final String? imageUrl;
  int quantity;

  // =========================================================
  // OPTIONAL PRODUCT SELECTION
  // =========================================================

  final String? color;
  final String? size;
  final String? variant;

  // =========================================================
  // RESELLER / ENTREPRENEUR DATA
  // =========================================================

  final bool isResellerProduct;
  final String? entrepreneurUid;
  final String? sellerId;
  final String? supplierProductId;
  final double? supplierPrice;
  final double? resellerProfit;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.quantity = 1,
    this.color,
    this.size,
    this.variant,
    this.isResellerProduct = false,
    this.entrepreneurUid,
    this.sellerId,
    this.supplierProductId,
    this.supplierPrice,
    this.resellerProfit,
  });

  double get total => price * quantity;

  double get supplierTotal =>
      (supplierPrice ?? 0) * quantity;

  double get profitTotal {
    if (resellerProfit != null) {
      return resellerProfit! * quantity;
    }

    if (supplierPrice != null) {
      return (price - supplierPrice!) * quantity;
    }

    return 0;
  }
}

// =============================================================
// CART SERVICE
// =============================================================

class CartService {
  static const double deliveryFeeAmount = 60;

  static CollectionReference<Map<String, dynamic>>
      _cartReference(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cart');
  }

  // ===========================================================
  // ADD ITEM
  // ===========================================================

  static Future<void> addItem({
    required String id,
    required String name,
    required double price,
    String? imageUrl,

    // Optional selection
    String? color,
    String? size,
    String? variant,

    // Reseller
    bool isResellerProduct = false,
    String? entrepreneurUid,
    String? sellerId,
    String? supplierProductId,
    double? supplierPrice,
    double? resellerProfit,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final cartRef = _cartReference(user.uid);
    final itemRef = cartRef.doc(id);

    final existing = await itemRef.get();

    if (existing.exists) {
      final data = existing.data() ?? {};

      final oldQuantity =
          (data['quantity'] as num?)?.toInt() ?? 1;

      await itemRef.update({
        'name': name,
        'price': price,
        'imageUrl': imageUrl ?? '',
        'quantity': oldQuantity + 1,

        // Optional selections
        'color': color ?? data['color'] ?? '',
        'size': size ?? data['size'] ?? '',
        'variant': variant ?? data['variant'] ?? '',

        // Reseller
        'isResellerProduct': isResellerProduct,
        'entrepreneurUid': entrepreneurUid ?? '',
        'sellerId': sellerId ?? '',
        'supplierProductId':
            supplierProductId ?? id,
        'supplierPrice': supplierPrice,
        'resellerProfit': resellerProfit,
      });
    } else {
      await itemRef.set({
        'productId': id,
        'name': name,
        'price': price,
        'imageUrl': imageUrl ?? '',
        'quantity': 1,
        'addedAt': FieldValue.serverTimestamp(),

        // Optional selections
        'color': color ?? '',
        'size': size ?? '',
        'variant': variant ?? '',

        // Reseller
        'isResellerProduct': isResellerProduct,
        'entrepreneurUid': entrepreneurUid ?? '',
        'sellerId': sellerId ?? '',
        'supplierProductId':
            supplierProductId ?? id,
        'supplierPrice': supplierPrice,
        'resellerProfit': resellerProfit,
      });
    }
  }

  // ===========================================================
  // REMOVE ITEM
  // ===========================================================

  static Future<void> removeItem(
    String id,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    await _cartReference(user.uid)
        .doc(id)
        .delete();
  }

  // ===========================================================
  // UPDATE QUANTITY
  // ===========================================================

  static Future<void> updateQuantity(
    String id,
    int quantity,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final itemRef =
        _cartReference(user.uid).doc(id);

    if (quantity <= 0) {
      await itemRef.delete();
      return;
    }

    await itemRef.update({
      'quantity': quantity,
    });
  }

  // ===========================================================
  // CLEAR CART
  // ===========================================================

  static Future<void> clearCart() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    final snapshot =
        await _cartReference(user.uid).get();

    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch =
        FirebaseFirestore.instance.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}

// =============================================================
// CART PAGE
// =============================================================

class CartPage extends StatefulWidget {
  const CartPage({
    super.key,
  });

  @override
  State<CartPage> createState() =>
      _CartPageState();
}

class _CartPageState extends State<CartPage> {
  // ===========================================================
  // SELECTED PRODUCTS
  // ===========================================================

  final Set<String> _selectedItems = {};

  // ===========================================================
  // QUANTITY
  // ===========================================================

  Future<void> _changeQuantity(
    String id,
    int currentQuantity,
    int change,
  ) async {
    final newQuantity =
        currentQuantity + change;

    try {
      await CartService.updateQuantity(
        id,
        newQuantity,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Could not update cart: $e',
      );
    }
  }

  // ===========================================================
  // SELECT / UNSELECT
  // ===========================================================

  void _toggleItem(String id) {
    setState(() {
      if (_selectedItems.contains(id)) {
        _selectedItems.remove(id);
      } else {
        _selectedItems.add(id);
      }
    });
  }

  // ===========================================================
  // SELECT ALL
  // ===========================================================

  void _toggleAll(
    List<CartItem> cartItems,
  ) {
    setState(() {
      final allSelected =
          cartItems.isNotEmpty &&
          cartItems.every(
            (item) =>
                _selectedItems.contains(item.id),
          );

      if (allSelected) {
        _selectedItems.clear();
      } else {
        _selectedItems
          ..clear()
          ..addAll(
            cartItems.map(
              (item) => item.id,
            ),
          );
      }
    });
  }

  // ===========================================================
  // REMOVE
  // ===========================================================

  Future<void> _removeItem(
    String id,
  ) async {
    try {
      await CartService.removeItem(id);

      if (!mounted) return;

      setState(() {
        _selectedItems.remove(id);
      });

      _showMessage(
        'Product removed from cart.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Could not remove product: $e',
      );
    }
  }

  // ===========================================================
  // CHECKOUT
  // ===========================================================

  Future<void> _checkout(
    List<CartItem> cartItems,
  ) async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const LoginPage(),
        ),
      );

      return;
    }

    final selectedItems =
        cartItems.where(
      (item) =>
          _selectedItems.contains(item.id),
    ).toList();

    if (selectedItems.isEmpty) {
      _showMessage(
        'Please select at least one product.',
      );
      return;
    }

    final checkoutItems =
        selectedItems.map((item) {
      return CheckoutItem(
        id: item.id,
        name: item.name,
        price: item.price,
        imageUrl: item.imageUrl,
        quantity: item.quantity,

        // Reseller
        isResellerProduct:
            item.isResellerProduct,
        entrepreneurUid:
            item.entrepreneurUid,
        sellerId:
            item.sellerId,
        supplierProductId:
            item.supplierProductId,
        supplierPrice:
            item.supplierPrice,
        resellerProfit:
            item.resellerProfit,
      );
    }).toList();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CheckoutPage(
          items: checkoutItems,
          clearCartOnSuccess: true,
        ),
      ),
    );
  }

  // ===========================================================
  // MESSAGE
  // ===========================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ===========================================================
  // PRODUCT IMAGE
  // ===========================================================

  Widget _productImage(
    String? imageUrl,
  ) {
    if (imageUrl == null ||
        imageUrl.trim().isEmpty) {
      return Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.image_outlined,
          size: 42,
          color: Colors.grey,
        ),
      );
    }

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: 112,
        height: 112,
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stackTrace) {
          return Container(
            width: 112,
            height: 112,
            color: Colors.grey.shade100,
            child: const Icon(
              Icons.image_outlined,
              size: 42,
              color: Colors.grey,
            ),
          );
        },
      ),
    );
  }

  // ===========================================================
  // SELECTION INFORMATION
  // ===========================================================

  Widget _selectionInfo(
    CartItem item,
  ) {
    final parts = <String>[];

    if (item.color != null &&
        item.color!.trim().isNotEmpty) {
      parts.add(
        'Color: ${item.color}',
      );
    }

    if (item.size != null &&
        item.size!.trim().isNotEmpty) {
      parts.add(
        'Size: ${item.size}',
      );
    }

    if (item.variant != null &&
        item.variant!.trim().isNotEmpty) {
      parts.add(
        item.variant!,
      );
    }

    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding:
          const EdgeInsets.only(
        top: 5,
      ),
      child: Text(
        parts.join('  •  '),
        maxLines: 1,
        overflow:
            TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 12,
        ),
      ),
    );
  }

  // ===========================================================
  // CART ITEM CARD
  // ===========================================================

  Widget _cartItemCard(
    CartItem item,
  ) {
    final selected =
        _selectedItems.contains(
      item.id,
    );

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? Colors.redAccent
                  .withValues(
                  alpha: 0.45,
                )
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(
              alpha: 0.035,
            ),
            blurRadius: 5,
            offset:
                const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // =====================================================
          // CHECKBOX
          // =====================================================

          Padding(
            padding:
                const EdgeInsets.only(
              top: 40,
            ),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Checkbox(
                value: selected,
                activeColor:
                    Colors.redAccent,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    50,
                  ),
                ),
                onChanged: (_) {
                  _toggleItem(
                    item.id,
                  );
                },
              ),
            ),
          ),

          const SizedBox(
            width: 5,
          ),

          // =====================================================
          // IMAGE
          // =====================================================

          _productImage(
            item.imageUrl,
          ),

          const SizedBox(
            width: 10,
          ),

          // =====================================================
          // DETAILS
          // =====================================================

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 14,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed: () =>
                          _removeItem(
                        item.id,
                      ),
                      icon:
                          const Icon(
                        Icons
                            .delete_outline,
                        size: 21,
                        color:
                            Colors.grey,
                      ),
                      padding:
                          EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(
                        minWidth: 30,
                        minHeight: 30,
                      ),
                    ),
                  ],
                ),

                _selectionInfo(item),

                const SizedBox(
                  height: 5,
                ),

                if (item
                    .isResellerProduct)
                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors.blue
                          .withValues(
                        alpha: 0.08,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                    ),
                    child:
                        const Text(
                      'Reseller',
                      style:
                          TextStyle(
                        color:
                            Colors.blue,
                        fontSize: 9,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),

                const SizedBox(
                  height: 5,
                ),

                // PRICE
                Text(
                  '৳${item.price.toStringAsFixed(0)}',
                  style:
                      const TextStyle(
                    color:
                        Colors.redAccent,
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                // FREE SHIPPING
                Row(
                  children: [
                    Icon(
                      Icons
                          .local_shipping_outlined,
                      size: 14,
                      color:
                          Colors.green
                              .shade700,
                    ),
                    const SizedBox(
                      width: 4,
                    ),
                    Text(
                      'Free shipping',
                      style: TextStyle(
                        color:
                            Colors.green
                                .shade700,
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 7,
                ),

                // QUANTITY
                Row(
                  children: [
                    Container(
                      height: 32,
                      decoration:
                          BoxDecoration(
                        border: Border.all(
                          color: Colors
                              .grey
                              .shade300,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          7,
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed:
                                item.quantity >
                                        1
                                    ? () =>
                                        _changeQuantity(
                                          item.id,
                                          item.quantity,
                                          -1,
                                        )
                                    : null,
                            icon:
                                const Icon(
                              Icons.remove,
                              size: 16,
                            ),
                            padding:
                                EdgeInsets.zero,
                            constraints:
                                const BoxConstraints(
                              minWidth: 30,
                            ),
                          ),

                          SizedBox(
                            width: 26,
                            child: Text(
                              '${item.quantity}',
                              textAlign:
                                  TextAlign
                                      .center,
                              style:
                                  const TextStyle(
                                fontSize:
                                    13,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                          ),

                          IconButton(
                            onPressed:
                                () =>
                                    _changeQuantity(
                              item.id,
                              item.quantity,
                              1,
                            ),
                            icon:
                                const Icon(
                              Icons.add,
                              size: 16,
                            ),
                            padding:
                                EdgeInsets.zero,
                            constraints:
                                const BoxConstraints(
                              minWidth: 30,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    Text(
                      '৳${item.total.toStringAsFixed(0)}',
                      style:
                          const TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                if (item
                    .isResellerProduct)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 4,
                    ),
                    child: Text(
                      'Profit: ৳${item.profitTotal.toStringAsFixed(0)}',
                      style:
                          const TextStyle(
                        color:
                            Colors.green,
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w600,
                      ),
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
  // FREE SHIPPING HEADER
  // ===========================================================

  Widget _shippingBanner() {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color:
                Colors.green.shade600,
            size: 19,
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Text(
              'Free shipping special for you',
              style: TextStyle(
                color:
                    Colors.grey.shade800,
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          Text(
            'Exclusive offer',
            style: TextStyle(
              color:
                  Colors.grey.shade600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // SUMMARY
  // ===========================================================

  Widget _summaryCard(
    double subtotal,
    double deliveryFee,
    double total,
    int totalQuantity,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        top: 6,
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Selected quantity',
                ),
              ),
              Text(
                '$totalQuantity',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 9,
          ),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Subtotal',
                ),
              ),
              Text(
                '৳${subtotal.toStringAsFixed(0)}',
              ),
            ],
          ),

          const SizedBox(
            height: 9,
          ),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Delivery Fee',
                ),
              ),
              Text(
                '৳${deliveryFee.toStringAsFixed(0)}',
              ),
            ],
          ),

          const Divider(
            height: 25,
          ),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total',
                  style:
                      TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '৳${total.toStringAsFixed(0)}',
                style:
                    const TextStyle(
                  color:
                      Colors.redAccent,
                  fontSize: 21,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
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

    // =========================================================
    // LOGIN REQUIRED
    // =========================================================

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor:
              Colors.redAccent,
          foregroundColor:
              Colors.white,
          title: const Text(
            'Cart',
            style:
                TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),
        body: Center(
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
                      .shopping_cart_outlined,
                  size: 80,
                  color:
                      Colors.grey.shade400,
                ),
                const SizedBox(
                  height: 16,
                ),
                const Text(
                  'Please login to view your cart.',
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                const LoginPage(),
                      ),
                    );
                  },
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        Colors.redAccent,
                    foregroundColor:
                        Colors.white,
                  ),
                  child:
                      const Text(
                    'Login',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // =========================================================
    // CART STREAM
    // =========================================================

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F7F7),

      appBar: AppBar(
        backgroundColor:
            Colors.white,
        foregroundColor:
            Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Cart',
          style:
              TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),

      body: StreamBuilder<
          QuerySnapshot<
              Map<String, dynamic>>>(
        stream:
            FirebaseFirestore
                .instance
                .collection(
                  'users',
                )
                .doc(user.uid)
                .collection(
                  'cart',
                )
                .snapshots(),

        builder:
            (context, snapshot) {
          if (snapshot
                  .connectionState ==
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
                  'Could not load cart.\n${snapshot.error}',
                  textAlign:
                      TextAlign.center,
                ),
              ),
            );
          }

          final documents =
              snapshot.data?.docs ??
                  [];

          if (documents.isEmpty) {
            _selectedItems.clear();
            return _emptyCart();
          }

          final cartItems =
              <CartItem>[];

          for (final doc
              in documents) {
            final data =
                doc.data();

            final name =
                data['name']
                        ?.toString() ??
                    data['productName']
                        ?.toString() ??
                    'Unnamed Product';

            final priceValue =
                data['price'] ??
                    data['sellingPrice'] ??
                    0;

            final double price =
                priceValue is num
                    ? priceValue.toDouble()
                    : double.tryParse(
                          priceValue
                              .toString(),
                        ) ??
                        0;

            final quantity =
                (data['quantity']
                            as num?)
                        ?.toInt() ??
                    1;

            final image =
                data['imageUrl']
                    ?.toString();

            // Optional selections
            final color =
                _nullableString(
              data['color'] ??
                  data['selectedColor'],
            );

            final size =
                _nullableString(
              data['size'] ??
                  data['selectedSize'],
            );

            final variant =
                _nullableString(
              data['variant'],
            );

            // Reseller
            final isResellerProduct =
                data['isResellerProduct'] ==
                    true;

            final entrepreneurUid =
                _nullableString(
              data['entrepreneurUid'],
            );

            final sellerId =
                _nullableString(
              data['sellerId'],
            );

            final supplierProductId =
                _nullableString(
              data['supplierProductId'],
            );

            final supplierPrice =
                _nullableDouble(
              data['supplierPrice'],
            );

            final resellerProfit =
                _nullableDouble(
              data['resellerProfit'],
            );

            cartItems.add(
              CartItem(
                id: doc.id,
                name: name,
                price: price,
                imageUrl:
                    image == null ||
                            image.isEmpty
                        ? null
                        : image,
                quantity:
                    quantity < 1
                        ? 1
                        : quantity,
                color: color,
                size: size,
                variant: variant,
                isResellerProduct:
                    isResellerProduct,
                entrepreneurUid:
                    entrepreneurUid,
                sellerId:
                    sellerId,
                supplierProductId:
                    supplierProductId,
                supplierPrice:
                    supplierPrice,
                resellerProfit:
                    resellerProfit,
              ),
            );
          }

          // Remove deleted products from selection.
          _selectedItems.removeWhere(
            (id) => !cartItems.any(
              (item) => item.id == id,
            ),
          );

          final allSelected =
              cartItems.isNotEmpty &&
              cartItems.every(
                (item) =>
                    _selectedItems
                        .contains(item.id),
              );

          final selectedItems =
              cartItems.where(
            (item) =>
                _selectedItems
                    .contains(item.id),
          ).toList();

          // =====================================================
          // SELECTED TOTALS
          // =====================================================

          double subtotal = 0;
          int totalQuantity = 0;

          for (final item
              in selectedItems) {
            subtotal += item.total;
            totalQuantity +=
                item.quantity;
          }

          final deliveryFee =
              selectedItems.isEmpty
                  ? 0
                  : CartService
                      .deliveryFeeAmount;

          final total =
              subtotal + deliveryFee;

          // =====================================================
          // PAGE
          // =====================================================

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    10,
                    10,
                    10,
                    20,
                  ),
                  children: [
                    // =================================================
                    // SELECT ALL BAR
                    // =================================================

                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.white,
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value:
                                allSelected,
                            activeColor:
                                Colors
                                    .redAccent,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                50,
                              ),
                            ),
                            onChanged: (_) =>
                                _toggleAll(
                              cartItems,
                            ),
                          ),
                          const Text(
                            'All',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${cartItems.length} item${cartItems.length == 1 ? '' : 's'}',
                            style:
                                TextStyle(
                              color: Colors
                                  .grey
                                  .shade600,
                              fontSize:
                                  12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    // =================================================
                    // SHIPPING
                    // =================================================

                    _shippingBanner(),

                    // =================================================
                    // CART PRODUCTS
                    // =================================================

                    ...cartItems.map(
                      (item) =>
                          _cartItemCard(
                        item,
                      ),
                    ),
                  ],
                ),
              ),

              // =====================================================
              // BOTTOM CHECKOUT AREA
              // =====================================================

              SafeArea(
                top: false,
                child: Container(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    12,
                    10,
                    12,
                    12,
                  ),
                  decoration:
                      const BoxDecoration(
                    color:
                        Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black12,
                        blurRadius:
                            10,
                        offset:
                            Offset(
                          0,
                          -3,
                        ),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  selectedItems
                                      .isEmpty
                                      ? 'No items selected'
                                      : '$totalQuantity item${totalQuantity == 1 ? '' : 's'} selected',
                                  style:
                                      TextStyle(
                                    color: Colors
                                        .grey
                                        .shade700,
                                    fontSize:
                                        12,
                                  ),
                                ),
                                const SizedBox(
                                  height: 3,
                                ),
                                Text(
                                  '৳${total.toStringAsFixed(0)}',
                                  style:
                                      const TextStyle(
                                    color: Colors
                                        .redAccent,
                                    fontSize:
                                        21,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(
                            height: 50,
                            child:
                                ElevatedButton(
                              onPressed:
                                  selectedItems
                                          .isEmpty
                                      ? null
                                      : () =>
                                          _checkout(
                                            cartItems,
                                          ),
                              style:
                                  ElevatedButton
                                      .styleFrom(
                                backgroundColor:
                                    Colors
                                        .redAccent,
                                disabledBackgroundColor:
                                    Colors
                                        .grey
                                        .shade300,
                                foregroundColor:
                                    Colors
                                        .white,
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal:
                                      28,
                                ),
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    25,
                                  ),
                                ),
                              ),
                              child:
                                  Text(
                                selectedItems
                                        .isEmpty
                                    ? 'Checkout'
                                    : 'Checkout (${selectedItems.length})',
                                style:
                                    const TextStyle(
                                  fontSize:
                                      15,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================
  // NULLABLE STRING
  // ===========================================================

  String? _nullableString(
    dynamic value,
  ) {
    final text =
        value?.toString().trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    return text;
  }

  // ===========================================================
  // NULLABLE DOUBLE
  // ===========================================================

  double? _nullableDouble(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  // ===========================================================
  // EMPTY CART
  // ===========================================================

  Widget _emptyCart() {
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
                  .shopping_cart_outlined,
              size: 90,
              color:
                  Colors.grey.shade400,
            ),

            const SizedBox(
              height: 18,
            ),

            const Text(
              'Your Cart is Empty',
              style:
                  TextStyle(
                fontSize: 21,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              'Add products to your cart and they will appear here.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    Colors.grey.shade600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
