import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'cart_page.dart';
import 'login_page.dart';
import 'checkout_page.dart';
import 'buyer_chat_page.dart';

class ProductDetailsPage extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> product;

  const ProductDetailsPage({
    super.key,
    required this.productId,
    required this.product,
  });

  @override
  State<ProductDetailsPage> createState() =>
      _ProductDetailsPageState();
}

class _ProductDetailsPageState
    extends State<ProductDetailsPage> {
  int _quantity = 1;
  bool _isFavorite = false;
  bool _loadingFavorite = true;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
  }

  // =========================================================
  // PRODUCT DATA
  // =========================================================

  String get productName {
    return widget.product['name']?.toString() ??
        widget.product['productName']?.toString() ??
        'Unnamed Product';
  }

  String get imageUrl {
    return widget.product['imageUrl']?.toString() ??
        widget.product['productImageUrl']?.toString() ??
        '';
  }

  String get category {
    return widget.product['category']?.toString() ?? '';
  }

  String get description {
    return widget.product['description']?.toString() ??
        'No description available.';
  }

  double get rawPrice {
    final value =
        widget.product['price'] ??
        widget.product['sellingPrice'] ??
        0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0;
  }

  // =========================================================
  // CURRENCY
  // =========================================================

  String get currency {
    return widget.product['currency']
            ?.toString()
            .trim()
            .toUpperCase() ??
        '';
  }

  bool get isBdt {
    return currency == 'BDT';
  }

  double get price {
    if (isBdt) {
      return rawPrice;
    }

    return rawPrice * 0.09;
  }

  String get formattedPrice {
    return '৳${price.toStringAsFixed(2)}';
  }

  String get formattedWholePrice {
    return '৳${price.toStringAsFixed(0)}';
  }

  String get sellerCode {
    return widget.product['sellerCode']
            ?.toString() ??
        '';
  }

  String get sellerId {
    return widget.product['sellerId']
            ?.toString() ??
        '';
  }

  String get sellerEmail {
    return widget.product['sellerEmail']
            ?.toString() ??
        '';
  }

  // =========================================================
  // RESELLER DATA
  // =========================================================

  String get entrepreneurUid {
    return widget.product['entrepreneurUid']
            ?.toString()
            .trim() ??
        '';
  }

  String get entrepreneurName {
    return widget.product['entrepreneurName']
            ?.toString()
            .trim() ??
        '';
  }

  bool get isResellerProduct {
    return widget.product['isResellerProduct'] ==
            true ||
        entrepreneurUid.isNotEmpty;
  }

  String get sellerNameFromProduct {
    return widget.product['sellerName']
            ?.toString()
            .trim() ??
        '';
  }

  String get recipientId {
    if (isResellerProduct &&
        entrepreneurUid.isNotEmpty) {
      return entrepreneurUid;
    }

    return sellerId;
  }

  String get recipientNameFromProduct {
    if (isResellerProduct &&
        entrepreneurName.isNotEmpty) {
      return entrepreneurName;
    }

    if (sellerNameFromProduct.isNotEmpty) {
      return sellerNameFromProduct;
    }

    if (sellerCode.isNotEmpty) {
      return sellerCode;
    }

    if (sellerEmail.isNotEmpty) {
      return sellerEmail;
    }

    return isResellerProduct
        ? 'Reseller'
        : 'Seller';
  }

  double get subtotal {
    return price * _quantity;
  }

  String get formattedSubtotal {
    return '৳${subtotal.toStringAsFixed(2)}';
  }

  // =========================================================
  // FAVORITE REFERENCE
  // =========================================================

  DocumentReference<Map<String, dynamic>>
      _favoriteReference(
    String userId,
  ) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(widget.productId);
  }

  // =========================================================
  // LOAD FAVORITE
  // =========================================================

  Future<void> _loadFavoriteStatus() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingFavorite = false;
        });
      }
      return;
    }

    try {
      final snapshot =
          await _favoriteReference(
        user.uid,
      ).get();

      if (!mounted) return;

      setState(() {
        _isFavorite =
            snapshot.exists;
        _loadingFavorite = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingFavorite = false;
      });
    }
  }

  // =========================================================
  // TOGGLE FAVORITE
  // =========================================================

  Future<void> _toggleFavorite() async {
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

      await _loadFavoriteStatus();
      return;
    }

    final favoriteRef =
        _favoriteReference(
      user.uid,
    );

    try {
      if (_isFavorite) {
        await favoriteRef.delete();

        if (!mounted) return;

        setState(() {
          _isFavorite = false;
        });

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Removed from Favorites',
            ),
            behavior:
                SnackBarBehavior.floating,
            duration:
                Duration(seconds: 1),
          ),
        );
      } else {
        await favoriteRef.set({
          'productId':
              widget.productId,
          'productName':
              productName,
          'productImageUrl':
              imageUrl,
          'category': category,
          'price': price,
          'currency': 'BDT',
          'currencySymbol': '৳',
          'userId': user.uid,
          'createdAt':
              FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        setState(() {
          _isFavorite = true;
        });

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Added to Favorites ❤️',
            ),
            behavior:
                SnackBarBehavior.floating,
            duration:
                Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Favorite update failed: $e',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    }
  }

  // =========================================================
  // ADD TO CART
  // =========================================================

  Future<void> _addToCart() async {
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

    try {
      for (int i = 0;
          i < _quantity;
          i++) {
        await CartService.addItem(
          id: widget.productId,
          name: productName,
          price: price,
          imageUrl: imageUrl.isEmpty
              ? null
              : imageUrl,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '$_quantity × $productName added to cart',
          ),
          behavior:
              SnackBarBehavior.floating,
          duration:
              const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not add to cart: $e',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    }
  }

  // =========================================================
  // BUY NOW
  // =========================================================

  Future<void> _buyNow() async {
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

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CheckoutPage(
          items: [
            CheckoutItem(
              id: widget.productId,
              name: productName,
              price: price,
              imageUrl:
                  imageUrl.isEmpty
                      ? null
                      : imageUrl,
              quantity: _quantity,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // OPEN SELLER / RESELLER CHAT
  // =========================================================

  Future<void> _openMessageChat() async {
    User? user =
        FirebaseAuth.instance.currentUser;

    // -------------------------------------------------------
    // LOGIN REQUIRED
    // -------------------------------------------------------

    if (user == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const LoginPage(),
        ),
      );

      user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }
    }

    final targetId = recipientId;

    if (targetId.isEmpty) {
      if (!mounted) return;

      _showInfoDialog(
        isResellerProduct
            ? 'Reseller Not Available'
            : 'Seller Not Available',
        isResellerProduct
            ? 'This reseller does not have a valid account ID yet.'
            : 'This product does not have a valid seller ID yet.',
      );

      return;
    }

    // Prevent messaging yourself.
    if (targetId == user.uid) {
      if (!mounted) return;

      _showInfoDialog(
        'Cannot Message',
        'You cannot send a message to your own account.',
      );

      return;
    }

    String targetName =
        recipientNameFromProduct;

    // -------------------------------------------------------
    // GET NAME FROM USERS COLLECTION IF NEEDED
    // -------------------------------------------------------

    final shouldLoadUserName =
        targetName == 'Seller' ||
            targetName == 'Reseller' ||
            targetName.isEmpty;

    if (shouldLoadUserName) {
      try {
        final userDoc =
            await FirebaseFirestore
                .instance
                .collection('users')
                .doc(targetId)
                .get();

        if (userDoc.exists) {
          final data =
              userDoc.data();

          final name =
              data?['name']
                  ?.toString()
                  .trim();

          final displayName =
              data?['displayName']
                  ?.toString()
                  .trim();

          if (name != null &&
              name.isNotEmpty) {
            targetName = name;
          } else if (displayName != null &&
              displayName.isNotEmpty) {
            targetName = displayName;
          }
        }
      } catch (_) {
        // Keep fallback name.
      }
    }

    // -------------------------------------------------------
    // FIND EXISTING CONVERSATION
    // -------------------------------------------------------

    String conversationId = '';

    try {
      final existing =
          await FirebaseFirestore
              .instance
              .collection('conversations')
              .where(
                'buyerId',
                isEqualTo: user.uid,
              )
              .where(
                'sellerId',
                isEqualTo: targetId,
              )
              .limit(1)
              .get();

      if (existing.docs.isNotEmpty) {
        conversationId =
            existing.docs.first.id;
      }
    } catch (_) {
      // If query fails, use deterministic ID.
    }

    // -------------------------------------------------------
    // CREATE A STABLE CHAT ID FOR NEW CHAT
    // -------------------------------------------------------

    if (conversationId.isEmpty) {
      conversationId =
          'chat_${user.uid}_$targetId';
    }

    if (!mounted) return;

    // -------------------------------------------------------
    // OPEN CHAT
    // -------------------------------------------------------

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BuyerChatPage(
          conversationId:
              conversationId,
          sellerId: targetId,
          sellerName: targetName,
          isReseller:
              isResellerProduct,
        ),
      ),
    );
  }

  // =========================================================
  // QUANTITY
  // =========================================================

  void _increaseQuantity() {
    setState(() {
      _quantity++;
    });
  }

  void _decreaseQuantity() {
    if (_quantity <= 1) return;

    setState(() {
      _quantity--;
    });
  }

  // =========================================================
  // REVIEWS REFERENCE
  // =========================================================

  CollectionReference<Map<String, dynamic>>
      get _reviewsReference {
    return FirebaseFirestore.instance
        .collection('product_reviews');
  }

  // =========================================================
  // CHECK IF USER PURCHASED PRODUCT
  // =========================================================

  Future<bool> _hasDeliveredProduct() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return false;

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('seller_orders')
              .where(
                'customerId',
                isEqualTo: user.uid,
              )
              .get();

      for (final doc
          in snapshot.docs) {
        final data = doc.data();

        final status =
            data['orderStatus']
                    ?.toString() ??
                '';

        if (status != 'delivered') {
          continue;
        }

        final items =
            data['items'];

        if (items is! List) {
          continue;
        }

        for (final item in items) {
          if (item is! Map) {
            continue;
          }

          final itemProductId =
              item['productId']
                      ?.toString() ??
                  item['id']
                      ?.toString() ??
                  '';

          if (itemProductId ==
              widget.productId) {
            return true;
          }
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  // =========================================================
  // FIND USER'S REVIEW
  // =========================================================

  Future<QueryDocumentSnapshot<
          Map<String, dynamic>>?>
      _findMyReview() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return null;

    try {
      final snapshot =
          await _reviewsReference
              .where(
                'productId',
                isEqualTo:
                    widget.productId,
              )
              .where(
                'userId',
                isEqualTo: user.uid,
              )
              .limit(1)
              .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return snapshot.docs.first;
    } catch (_) {
      return null;
    }
  }

  // =========================================================
  // REVIEW DIALOG
  // =========================================================

  Future<void> _showReviewDialog({
    DocumentSnapshot<
            Map<String, dynamic>>?
        existingReview,
  }) async {
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

    if (existingReview == null) {
      final eligible =
          await _hasDeliveredProduct();

      if (!eligible) {
        if (!mounted) return;

        _showInfoDialog(
          'Review Not Available',
          'You can review this product after your order has been delivered.',
        );

        return;
      }
    }

    int selectedRating = 5;

    final existingData =
        existingReview?.data();

    if (existingData != null) {
      final oldRating =
          existingData['rating'];

      if (oldRating is num) {
        selectedRating =
            oldRating.toInt().clamp(
                  1,
                  5,
                );
      }
    }

    final controller =
        TextEditingController(
      text:
          existingData?['review']
                  ?.toString() ??
              '',
    );

    final result =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            dialogContext,
            setDialogState,
          ) {
            return AlertDialog(
              title: Text(
                existingReview == null
                    ? 'Write a Review'
                    : 'Edit Your Review',
              ),
              content:
                  SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    const Text(
                      'How would you rate this product?',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children:
                          List.generate(
                        5,
                        (index) {
                          final star =
                              index + 1;

                          return IconButton(
                            onPressed: () {
                              setDialogState(
                                () {
                                  selectedRating =
                                      star;
                                },
                              );
                            },
                            icon: Icon(
                              star <=
                                      selectedRating
                                  ? Icons.star
                                  : Icons.star_border,
                              color:
                                  Colors.amber,
                              size: 34,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    TextField(
                      controller:
                          controller,
                      maxLines: 4,
                      maxLength: 500,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Your Review',
                        hintText:
                            'Tell other buyers about this product...',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      false,
                    );
                  },
                  child:
                      const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final review =
                        controller.text
                            .trim();

                    if (review.isEmpty) {
                      ScaffoldMessenger
                              .of(
                        dialogContext,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please write a review.',
                          ),
                        ),
                      );
                      return;
                    }

                    try {
                      if (existingReview ==
                          null) {
                        await _reviewsReference
                            .add({
                          'productId':
                              widget.productId,
                          'productName':
                              productName,
                          'productImageUrl':
                              imageUrl,
                          'userId':
                              user.uid,
                          'userName':
                              user.displayName ??
                                  'Buyer',
                          'userEmail':
                              user.email ??
                                  '',
                          'rating':
                              selectedRating,
                          'review':
                              review,
                          'createdAt':
                              FieldValue
                                  .serverTimestamp(),
                          'updatedAt':
                              FieldValue
                                  .serverTimestamp(),
                        });
                      } else {
                        await existingReview
                            .reference
                            .update({
                          'rating':
                              selectedRating,
                          'review':
                              review,
                          'updatedAt':
                              FieldValue
                                  .serverTimestamp(),
                        });
                      }

                      if (!dialogContext
                          .mounted) {
                        return;
                      }

                      Navigator.pop(
                        dialogContext,
                        true,
                      );
                    } catch (e) {
                      if (!dialogContext
                          .mounted) {
                        return;
                      }

                      ScaffoldMessenger
                              .of(
                        dialogContext,
                      ).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Review failed: $e',
                          ),
                        ),
                      );
                    }
                  },
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        Colors.redAccent,
                    foregroundColor:
                        Colors.white,
                  ),
                  child: Text(
                    existingReview == null
                        ? 'Submit'
                        : 'Update',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (result == true && mounted) {
      setState(() {});
    }
  }

  // =========================================================
  // INFO DIALOG
  // =========================================================

  void _showInfoDialog(
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );
              },
              child:
                  const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // REVIEWS SECTION
  // =========================================================

  Widget _buildReviewsSection() {
    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream: _reviewsReference
          .where(
            'productId',
            isEqualTo:
                widget.productId,
          )
          .snapshots(),
      builder:
          (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding:
                EdgeInsets.all(16),
            child: Text(
              'Unable to load reviews.',
            ),
          );
        }

        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding:
                EdgeInsets.all(16),
            child: Center(
              child:
                  CircularProgressIndicator(),
            ),
          );
        }

        final reviews =
            snapshot.data?.docs ?? [];

        double averageRating = 0;

        if (reviews.isNotEmpty) {
          double total = 0;

          for (final review
              in reviews) {
            final rating =
                review.data()['rating'];

            if (rating is num) {
              total +=
                  rating.toDouble();
            }
          }

          averageRating =
              total / reviews.length;
        }

        return Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 28,
            ),
            const Text(
              'Ratings & Reviews',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(
                16,
              ),
              decoration:
                  BoxDecoration(
                color:
                    Colors.grey.shade50,
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
                border: Border.all(
                  color:
                      Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Column(
                    children: [
                      Text(
                        averageRating
                            .toStringAsFixed(
                          1,
                        ),
                        style:
                            const TextStyle(
                          fontSize: 34,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      Row(
                        children:
                            List.generate(
                          5,
                          (index) {
                            return Icon(
                              index <
                                      averageRating
                                          .round()
                                  ? Icons.star
                                  : Icons.star_border,
                              color:
                                  Colors.amber,
                              size: 20,
                            );
                          },
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        '${reviews.length} review${reviews.length == 1 ? '' : 's'}',
                        style:
                            const TextStyle(
                          color:
                              Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    width: 24,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'Customer Reviews',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        const Text(
                          'See what other buyers think about this product.',
                          style:
                              TextStyle(
                            color:
                                Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            FutureBuilder<
                QueryDocumentSnapshot<
                    Map<String,
                        dynamic>>?>(
              future: _findMyReview(),
              builder: (
                context,
                myReviewSnapshot,
              ) {
                final myReview =
                    myReviewSnapshot
                        .data;

                return SizedBox(
                  width:
                      double.infinity,
                  child:
                      OutlinedButton.icon(
                    onPressed: () {
                      _showReviewDialog(
                        existingReview:
                            myReview,
                      );
                    },
                    icon: Icon(
                      myReview == null
                          ? Icons
                              .rate_review_outlined
                          : Icons
                              .edit_outlined,
                    ),
                    label: Text(
                      myReview == null
                          ? 'Write a Review'
                          : 'Edit My Review',
                    ),
                    style:
                        OutlinedButton
                            .styleFrom(
                      foregroundColor:
                          Colors.redAccent,
                      side:
                          const BorderSide(
                        color:
                            Colors.redAccent,
                      ),
                      padding:
                          const EdgeInsets
                              .symmetric(
                        vertical: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(
              height: 16,
            ),
            if (reviews.isEmpty)
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.all(
                  20,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.grey.shade50,
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child:
                    const Column(
                  children: [
                    Icon(
                      Icons
                          .rate_review_outlined,
                      size: 42,
                      color:
                          Colors.grey,
                    ),
                    SizedBox(
                      height: 8,
                    ),
                    Text(
                      'No reviews yet',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),
                    SizedBox(
                      height: 4,
                    ),
                    Text(
                      'Be the first buyer to review this product.',
                      textAlign:
                          TextAlign.center,
                      style:
                          TextStyle(
                        color:
                            Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...reviews.map(
                (reviewDoc) {
                  final data =
                      reviewDoc.data();

                  final ratingValue =
                      data['rating'];

                  final rating =
                      ratingValue is num
                          ? ratingValue
                              .toInt()
                          : 0;

                  final name =
                      data['userName']
                              ?.toString() ??
                          'Buyer';

                  final reviewText =
                      data['review']
                              ?.toString() ??
                          '';

                  return Card(
                    margin:
                        const EdgeInsets
                            .only(
                      bottom: 12,
                    ),
                    child: Padding(
                      padding:
                          const EdgeInsets
                              .all(14),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    Colors
                                        .redAccent
                                        .withValues(
                                  alpha:
                                      0.10,
                                ),
                                child:
                                    const Icon(
                                  Icons.person,
                                  color:
                                      Colors.redAccent,
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              Expanded(
                                child:
                                    Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      name,
                                      style:
                                          const TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 3,
                                    ),
                                    Row(
                                      children:
                                          List.generate(
                                        5,
                                        (index) {
                                          return Icon(
                                            index <
                                                    rating
                                                ? Icons.star
                                                : Icons.star_border,
                                            color:
                                                Colors.amber,
                                            size:
                                                17,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Text(
                            reviewText,
                            style:
                                const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final recipientType =
        isResellerProduct
            ? 'Reseller'
            : 'Seller';

    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            Colors.redAccent,
        foregroundColor:
            Colors.white,
        title: const Text(
          'Product Details',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons
                  .shopping_cart_outlined,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const CartPage(),
                ),
              );
            },
          ),
        ],
      ),
      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.only(
          bottom: 120,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            // =================================================
            // IMAGE
            // =================================================

            SizedBox(
              width:
                  double.infinity,
              height: 330,
              child: imageUrl
                      .isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit:
                          BoxFit.cover,
                      errorBuilder: (
                        context,
                        error,
                        stackTrace,
                      ) {
                        return Container(
                          color: Colors
                              .grey
                              .shade200,
                          child:
                              const Center(
                            child:
                                Icon(
                              Icons.image,
                              size: 80,
                              color:
                                  Colors.grey,
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors
                          .grey
                          .shade200,
                      child:
                          const Center(
                        child: Icon(
                          Icons.image,
                          size: 80,
                          color:
                              Colors.grey,
                        ),
                      ),
                    ),
            ),

            // =================================================
            // PRODUCT INFORMATION
            // =================================================

            Padding(
              padding:
                  const EdgeInsets
                      .all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Expanded(
                        child: Text(
                          productName,
                          style:
                              const TextStyle(
                            fontSize: 24,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed:
                            _loadingFavorite
                                ? null
                                : _toggleFavorite,
                        icon: Icon(
                          _isFavorite
                              ? Icons.favorite
                              : Icons
                                  .favorite_border,
                          color:
                              _isFavorite
                                  ? Colors
                                      .redAccent
                                  : Colors
                                      .grey,
                          size: 30,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  if (category
                      .isNotEmpty)
                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Colors
                            .redAccent
                            .shade100,
                        borderRadius:
                            BorderRadius
                                .circular(
                          20,
                        ),
                      ),
                      child: Text(
                        category,
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight
                                  .w600,
                        ),
                      ),
                    ),

                  const SizedBox(
                    height: 12,
                  ),

                  Text(
                    formattedPrice,
                    style:
                        const TextStyle(
                      fontSize: 25,
                      color:
                          Colors.redAccent,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  const Text(
                    'Description',
                    style:
                        TextStyle(
                      fontSize: 19,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    description,
                    style:
                        const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color:
                          Colors.black87,
                    ),
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  // =================================================
                  // QUANTITY
                  // =================================================

                  const Text(
                    'Quantity',
                    style:
                        TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  Row(
                    children: [
                      Container(
                        decoration:
                            BoxDecoration(
                          border:
                              Border.all(
                            color: Colors
                                .grey
                                .shade300,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            8,
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed:
                                  _decreaseQuantity,
                              icon:
                                  const Icon(
                                Icons
                                    .remove,
                              ),
                            ),
                            SizedBox(
                              width: 35,
                              child:
                                  Text(
                                '$_quantity',
                                textAlign:
                                    TextAlign
                                        .center,
                                style:
                                    const TextStyle(
                                  fontSize:
                                      18,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed:
                                  _increaseQuantity,
                              icon:
                                  const Icon(
                                Icons
                                    .add,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        width: 20,
                      ),
                      Text(
                        'Total: $formattedSubtotal',
                        style:
                            const TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight
                                  .bold,
                          color:
                              Colors
                                  .redAccent,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  // =================================================
                  // SELLER / RESELLER INFORMATION
                  // =================================================

                  if (sellerCode.isNotEmpty ||
                      sellerId.isNotEmpty ||
                      sellerEmail.isNotEmpty ||
                      isResellerProduct)
                    Card(
                      child:
                          Padding(
                        padding:
                            const EdgeInsets
                                .all(
                          14,
                        ),
                        child:
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              isResellerProduct
                                  ? 'Reseller Information'
                                  : 'Seller Information',
                              style:
                                  const TextStyle(
                                fontSize:
                                    18,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            if (isResellerProduct &&
                                entrepreneurUid
                                    .isNotEmpty)
                              Text(
                                'Reseller UID: $entrepreneurUid',
                              ),

                            if (isResellerProduct &&
                                entrepreneurName
                                    .isNotEmpty)
                              Text(
                                'Reseller Name: $entrepreneurName',
                              ),

                            if (sellerCode
                                .isNotEmpty)
                              Text(
                                'Seller ID: $sellerCode',
                              ),

                            if (sellerId
                                .isNotEmpty)
                              Text(
                                'Seller UID: $sellerId',
                              ),

                            if (sellerEmail
                                .isNotEmpty)
                              Text(
                                'Seller Email: $sellerEmail',
                              ),
                          ],
                        ),
                      ),
                    ),

                  // =================================================
                  // REVIEWS
                  // =================================================

                  _buildReviewsSection(),
                ],
              ),
            ),
          ],
        ),
      ),

      // =========================================================
      // BOTTOM ACTIONS
      // =========================================================

      bottomNavigationBar:
          SafeArea(
        child: Container(
          padding:
              const EdgeInsets.all(10),
          decoration:
              const BoxDecoration(
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              // -------------------------------------------------
              // MESSAGE BUTTON
              // -------------------------------------------------

              SizedBox(
                width:
                    double.infinity,
                child:
                    OutlinedButton.icon(
                  onPressed:
                      _openMessageChat,
                  icon: const Icon(
                    Icons
                        .chat_bubble_outline,
                  ),
                  label: Text(
                    'Message $recipientType',
                  ),
                  style:
                      OutlinedButton
                          .styleFrom(
                    foregroundColor:
                        Colors
                            .redAccent,
                    side:
                        const BorderSide(
                      color:
                          Colors.redAccent,
                    ),
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              // -------------------------------------------------
              // CART + BUY NOW
              // -------------------------------------------------

              Row(
                children: [
                  Expanded(
                    child:
                        OutlinedButton
                            .icon(
                      onPressed:
                          _addToCart,
                      icon: const Icon(
                        Icons
                            .shopping_cart_outlined,
                      ),
                      label:
                          const Text(
                        'Add to Cart',
                      ),
                      style:
                          OutlinedButton
                              .styleFrom(
                        foregroundColor:
                            Colors
                                .redAccent,
                        side:
                            const BorderSide(
                          color: Colors
                              .redAccent,
                        ),
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child:
                        ElevatedButton
                            .icon(
                      onPressed:
                          _buyNow,
                      icon: const Icon(
                        Icons.flash_on,
                      ),
                      label:
                          const Text(
                        'Buy Now',
                      ),
                      style:
                          ElevatedButton
                              .styleFrom(
                        backgroundColor:
                            Colors
                                .redAccent,
                        foregroundColor:
                            Colors.white,
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 14,
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
    );
  }
}
