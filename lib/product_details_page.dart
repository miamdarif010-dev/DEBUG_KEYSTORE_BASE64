import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';

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

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  // =========================================================
  // BASIC STATE
  // =========================================================

  int _quantity = 1;

  bool _isFavorite = false;
  bool _loadingFavorite = true;

  // =========================================================
  // PRODUCT MEDIA
  // =========================================================

  late List<String> _productImages;

  String _videoUrl = '';

  int _selectedMediaIndex = 0;

  VideoPlayerController? _videoController;

  bool _videoLoading = false;

  final PageController _mediaPageController = PageController();

  // =========================================================
  // FLOATING CART POSITION
  // =========================================================

  double _cartLeft = 0;
  double _cartTop = 20;

  bool _cartPositionInitialized = false;

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();

    _prepareMedia();
    _loadFavoriteStatus();
    _initializeVideo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_cartPositionInitialized) {
      final screenWidth = MediaQuery.of(context).size.width;

      _cartLeft = screenWidth - 78;
      _cartTop = 20;

      _cartPositionInitialized = true;
    }
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _videoController?.dispose();
    _mediaPageController.dispose();
    super.dispose();
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
    final value =
        widget.product['imageUrl']?.toString() ??
        widget.product['productImageUrl']?.toString() ??
        '';

    return value.trim();
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

    return double.tryParse(value.toString()) ?? 0;
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
    return currency == 'BDT' || currency == '৳';
  }

  double get price {
    if (isBdt) {
      return rawPrice;
    }

    // Legacy products were stored as KRW.
    return rawPrice * 0.09;
  }

  String get formattedPrice {
    return '৳${price.toStringAsFixed(2)}';
  }

  String get formattedWholePrice {
    return '৳${price.toStringAsFixed(0)}';
  }

  String get sellerCode {
    return widget.product['sellerCode']?.toString() ?? '';
  }

  String get sellerId {
    return widget.product['sellerId']?.toString() ?? '';
  }

  String get sellerEmail {
    return widget.product['sellerEmail']?.toString() ?? '';
  }

  // =========================================================
  // RESELLER DATA
  // =========================================================

  String get entrepreneurUid {
    return widget.product['entrepreneurUid']?.toString().trim() ?? '';
  }

  String get entrepreneurName {
    return widget.product['entrepreneurName']?.toString().trim() ?? '';
  }

  bool get isResellerProduct {
    return widget.product['isResellerProduct'] == true ||
        entrepreneurUid.isNotEmpty;
  }

  String get sellerNameFromProduct {
    return widget.product['sellerName']?.toString().trim() ?? '';
  }

  String get recipientId {
    if (isResellerProduct && entrepreneurUid.isNotEmpty) {
      return entrepreneurUid;
    }

    return sellerId;
  }

  String get recipientNameFromProduct {
    if (isResellerProduct && entrepreneurName.isNotEmpty) {
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

    return isResellerProduct ? 'Reseller' : 'Seller';
  }

  double get subtotal {
    return price * _quantity;
  }

  String get formattedSubtotal {
    return '৳${subtotal.toStringAsFixed(2)}';
  }

  // =========================================================
  // PREPARE MEDIA
  // =========================================================

  void _prepareMedia() {
    final List<String> images = <String>[];

    void addImage(dynamic value) {
      if (value == null) return;

      if (value is String) {
        final url = value.trim();

        if (url.isNotEmpty && !images.contains(url)) {
          images.add(url);
        }

        return;
      }

      if (value is List) {
        for (final item in value) {
          addImage(item);
        }
      }
    }

    // Main image first.
    addImage(widget.product['imageUrl']);
    addImage(widget.product['productImageUrl']);

    // Multiple image fields.
    addImage(widget.product['imageUrls']);
    addImage(widget.product['images']);
    addImage(widget.product['productImages']);
    addImage(widget.product['gallery']);

    if (images.isEmpty) {
      images.add('');
    }

    _productImages = images;

    // =======================================================
    // VIDEO
    // =======================================================

    final List<dynamic> possibleVideoFields = <dynamic>[
      widget.product['videoUrl'],
      widget.product['productVideoUrl'],
      widget.product['video'],
    ];

    for (final value in possibleVideoFields) {
      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty) {
        _videoUrl = text;
        break;
      }
    }

    // Support videoUrls list.
    if (_videoUrl.isEmpty) {
      final dynamic videoUrls = widget.product['videoUrls'];

      if (videoUrls is List && videoUrls.isNotEmpty) {
        final first = videoUrls.first?.toString().trim();

        if (first != null && first.isNotEmpty) {
          _videoUrl = first;
        }
      }
    }
  }

  // =========================================================
  // INITIALIZE VIDEO
  // =========================================================

  Future<void> _initializeVideo() async {
    if (_videoUrl.isEmpty) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _videoLoading = true;
    });

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(_videoUrl),
      );

      await controller.initialize();
      await controller.setLooping(true);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _videoController = controller;
        _videoLoading = false;
      });
    } catch (e) {
      debugPrint('Product video initialization failed: $e');

      if (!mounted) return;

      setState(() {
        _videoLoading = false;
      });
    }
  }

  // =========================================================
  // OPEN FULL-SCREEN MEDIA GALLERY
  // =========================================================

  void _openFullScreenGallery(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          return _FullScreenMediaGallery(
            imageUrls: _productImages,
            videoUrl: _videoUrl,
            initialIndex: initialIndex,
            videoController: _videoController,
            onCartTap: _openCart,
          );
        },
      ),
    );
  }

  // =========================================================
  // FAVORITE REFERENCE
  // =========================================================

  DocumentReference<Map<String, dynamic>> _favoriteReference(
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
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _loadingFavorite = false;
      });

      return;
    }

    try {
      final snapshot = await _favoriteReference(user.uid).get();

      if (!mounted) return;

      setState(() {
        _isFavorite = snapshot.exists;
        _loadingFavorite = false;
      });
    } catch (e) {
      debugPrint('Favorite load failed: $e');

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
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );

      await _loadFavoriteStatus();
      return;
    }

    final favoriteRef = _favoriteReference(user.uid);

    try {
      if (_isFavorite) {
        await favoriteRef.delete();

        if (!mounted) return;

        setState(() {
          _isFavorite = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from Favorites'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        await favoriteRef.set({
          'productId': widget.productId,
          'productName': productName,
          'productImageUrl': imageUrl,
          'category': category,
          'price': price,
          'currency': 'BDT',
          'currencySymbol': '৳',
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        setState(() {
          _isFavorite = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to Favorites ❤️'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Favorite update failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // =========================================================
  // ADD TO CART
  // =========================================================

  Future<void> _addToCart() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );
      return;
    }

    try {
      for (int i = 0; i < _quantity; i++) {
        await CartService.addItem(
          id: widget.productId,
          name: productName,
          price: price,
          imageUrl: imageUrl.isEmpty ? null : imageUrl,
          isResellerProduct: isResellerProduct,
          entrepreneurUid:
              entrepreneurUid.isEmpty ? null : entrepreneurUid,
          sellerId: sellerId.isEmpty ? null : sellerId,
          supplierProductId:
              widget.product['supplierProductId']?.toString(),
          supplierPrice: _nullableDouble(
            widget.product['supplierPrice'],
          ),
          resellerProfit: _nullableDouble(
            widget.product['resellerProfit'],
          ),
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$_quantity × $productName added to cart',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not add to cart: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // =========================================================
  // BUY NOW
  // =========================================================

  Future<void> _buyNow() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutPage(
          items: [
            CheckoutItem(
              id: widget.productId,
              name: productName,
              price: price,
              imageUrl: imageUrl.isEmpty ? null : imageUrl,
              quantity: _quantity,
              isResellerProduct: isResellerProduct,
              entrepreneurUid:
                  entrepreneurUid.isEmpty ? null : entrepreneurUid,
              sellerId: sellerId.isEmpty ? null : sellerId,
              supplierProductId:
                  widget.product['supplierProductId']?.toString(),
              supplierPrice: _nullableDouble(
                widget.product['supplierPrice'],
              ),
              resellerProfit: _nullableDouble(
                widget.product['resellerProfit'],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // OPEN CART
  // =========================================================

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CartPage(),
      ),
    );
  }

  // =========================================================
  // OPEN MESSAGE CHAT
  // =========================================================

  Future<void> _openMessageChat() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );

      user = FirebaseAuth.instance.currentUser;

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

    if (targetId == user.uid) {
      if (!mounted) return;

      _showInfoDialog(
        'Cannot Message',
        'You cannot send a message to your own account.',
      );

      return;
    }

    String targetName = recipientNameFromProduct;

    final shouldLoadUserName =
        targetName == 'Seller' ||
        targetName == 'Reseller' ||
        targetName.isEmpty;

    if (shouldLoadUserName) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(targetId)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data();

          final name = data?['name']?.toString().trim();
          final displayName =
              data?['displayName']?.toString().trim();

          if (name != null && name.isNotEmpty) {
            targetName = name;
          } else if (displayName != null &&
              displayName.isNotEmpty) {
            targetName = displayName;
          }
        }
      } catch (e) {
        debugPrint('Seller name load failed: $e');
      }
    }

    String conversationId = '';

    try {
      final existing = await FirebaseFirestore.instance
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
        conversationId = existing.docs.first.id;
      }
    } catch (e) {
      debugPrint('Conversation lookup failed: $e');
    }

    if (conversationId.isEmpty) {
      conversationId = 'chat_${user.uid}_$targetId';
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BuyerChatPage(
          conversationId: conversationId,
          sellerId: targetId,
          sellerName: targetName,
          isReseller: isResellerProduct,
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
  // REVIEWS
  // =========================================================

  CollectionReference<Map<String, dynamic>> get _reviewsReference {
    return FirebaseFirestore.instance.collection('product_reviews');
  }

  Future<bool> _hasDeliveredProduct() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return false;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('seller_orders')
          .where(
            'customerId',
            isEqualTo: user.uid,
          )
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final status = data['orderStatus']?.toString() ?? '';

        if (status != 'delivered') {
          continue;
        }

        final items = data['items'];

        if (items is! List) {
          continue;
        }

        for (final item in items) {
          if (item is! Map) {
            continue;
          }

          final itemProductId =
              item['productId']?.toString() ??
              item['id']?.toString() ??
              '';

          if (itemProductId == widget.productId) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint('Delivered order check failed: $e');
      return false;
    }
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?>
      _findMyReview() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return null;

    try {
      final snapshot = await _reviewsReference
          .where(
            'productId',
            isEqualTo: widget.productId,
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
    } catch (e) {
      debugPrint('Review lookup failed: $e');
      return null;
    }
  }

  // =========================================================
  // REVIEW DIALOG
  // =========================================================

  Future<void> _showReviewDialog({
    DocumentSnapshot<Map<String, dynamic>>? existingReview,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );
      return;
    }

    if (existingReview == null) {
      final eligible = await _hasDeliveredProduct();

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

    final existingData = existingReview?.data();

    if (existingData != null) {
      final oldRating = existingData['rating'];

      if (oldRating is num) {
        selectedRating = oldRating.toInt().clamp(1, 5);
      }
    }

    final controller = TextEditingController(
      text: existingData?['review']?.toString() ?? '',
    );

    final result = await showDialog<bool>(
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
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'How would you rate this product?',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (index) {
                          final star = index + 1;

                          return IconButton(
                            onPressed: () {
                              setDialogState(() {
                                selectedRating = star;
                              });
                            },
                            icon: Icon(
                              star <= selectedRating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 34,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Your Review',
                        hintText:
                            'Tell other buyers about this product...',
                        border: OutlineInputBorder(),
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
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final review = controller.text.trim();

                    if (review.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please write a review.',
                          ),
                        ),
                      );
                      return;
                    }

                    try {
                      if (existingReview == null) {
                        await _reviewsReference.add({
                          'productId': widget.productId,
                          'productName': productName,
                          'productImageUrl': imageUrl,
                          'userId': user.uid,
                          'userName':
                              user.displayName ?? 'Buyer',
                          'userEmail': user.email ?? '',
                          'rating': selectedRating,
                          'review': review,
                          'createdAt':
                              FieldValue.serverTimestamp(),
                          'updatedAt':
                              FieldValue.serverTimestamp(),
                        });
                      } else {
                        await existingReview.reference.update({
                          'rating': selectedRating,
                          'review': review,
                          'updatedAt':
                              FieldValue.serverTimestamp(),
                        });
                      }

                      if (!dialogContext.mounted) {
                        return;
                      }

                      Navigator.pop(
                        dialogContext,
                        true,
                      );
                    } catch (e) {
                      if (!dialogContext.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Review failed: $e',
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
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
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // IMAGE VIEWER
  // =========================================================

  Widget _buildImageViewer(String url) {
    if (url.trim().isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(
            Icons.image_outlined,
            size: 80,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Image.network(
      url,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.contain,
      loadingBuilder: (
        context,
        child,
        loadingProgress,
      ) {
        if (loadingProgress == null) {
          return child;
        }

        return const Center(
          child: CircularProgressIndicator(),
        );
      },
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) {
        return Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 70,
              color: Colors.grey,
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // VIDEO VIEWER
  // =========================================================

  Widget _buildVideoViewer() {
    final controller = _videoController;

    if (_videoLoading) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    if (controller == null ||
        !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.video_library_outlined,
                color: Colors.white,
                size: 50,
              ),
              SizedBox(height: 8),
              Text(
                'Video unavailable',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }

        if (mounted) {
          setState(() {});
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio == 0
                  ? 16 / 9
                  : controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          if (!controller.value.isPlaying)
            Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(12),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 42,
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================
  // MEDIA GALLERY
  // =========================================================

  Widget _buildMediaGallery() {
    final int totalMedia =
        _productImages.length +
        (_videoUrl.isNotEmpty ? 1 : 0);

    return Column(
      children: [
        Stack(
          children: [
            SizedBox(
              width: double.infinity,
              height: 390,
              child: PageView.builder(
                controller: _mediaPageController,
                itemCount: totalMedia,
                onPageChanged: (index) {
                  setState(() {
                    _selectedMediaIndex = index;
                  });

                  if (_videoUrl.isNotEmpty &&
                      index != _productImages.length) {
                    _videoController?.pause();
                  }
                },
                itemBuilder: (context, index) {
                  final bool isVideo =
                      _videoUrl.isNotEmpty &&
                      index == _productImages.length;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: isVideo
                        ? null
                        : () {
                            _openFullScreenGallery(index);
                          },
                    child: isVideo
                        ? _buildVideoViewer()
                        : _buildImageViewer(
                            _productImages[index],
                          ),
                  );
                },
              ),
            ),

            // =================================================
            // FULL-SCREEN BUTTON
            // =================================================

            Positioned(
              left: 14,
              bottom: 14,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    _openFullScreenGallery(
                      _selectedMediaIndex,
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(9),
                    child: Icon(
                      Icons.fullscreen,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                ),
              ),
            ),

            // =================================================
            // MEDIA COUNTER
            // =================================================

            Positioned(
              right: 14,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_selectedMediaIndex + 1}/$totalMedia',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // =================================================
            // DRAGGABLE CART
            // =================================================

            _buildDraggableCart(),
          ],
        ),

        // =====================================================
        // THUMBNAILS
        // =====================================================

        if (totalMedia > 1)
          SizedBox(
            height: 88,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              itemCount: totalMedia,
              itemBuilder: (context, index) {
                final bool selected =
                    index == _selectedMediaIndex;

                return GestureDetector(
                  onTap: () {
                    _selectMediaFromThumbnail(index);
                  },
                  child: Container(
                    width: 68,
                    margin: const EdgeInsets.only(
                      right: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: selected
                            ? Colors.redAccent
                            : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildThumbnail(index),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // =========================================================
  // THUMBNAIL PAGE SELECTION
  // =========================================================

  void _selectMediaFromThumbnail(int index) {
    if (_mediaPageController.hasClients) {
      _mediaPageController.animateToPage(
        index,
        duration: const Duration(
          milliseconds: 300,
        ),
        curve: Curves.easeInOut,
      );
    }

    setState(() {
      _selectedMediaIndex = index;
    });
  }

  // =========================================================
  // THUMBNAIL
  // =========================================================

  Widget _buildThumbnail(int index) {
    final bool isVideo =
        _videoUrl.isNotEmpty &&
        index == _productImages.length;

    if (isVideo) {
      return Container(
        color: Colors.black,
        child: const Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 34,
            ),
            Positioned(
              bottom: 3,
              child: Text(
                'VIDEO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final url = _productImages[index];

    if (url.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Icon(
          Icons.image_outlined,
          color: Colors.grey,
        ),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) {
        return Container(
          color: Colors.grey.shade200,
          child: const Icon(
            Icons.broken_image_outlined,
            color: Colors.grey,
          ),
        );
      },
    );
  }

  // =========================================================
  // DRAGGABLE FLOATING CART
  // =========================================================

  Widget _buildDraggableCart() {
    return Positioned(
      left: _cartLeft,
      top: _cartTop,
      child: GestureDetector(
        onPanUpdate: (details) {
          final screenWidth =
              MediaQuery.of(context).size.width;

          setState(() {
            _cartLeft += details.delta.dx;
            _cartTop += details.delta.dy;

            _cartLeft = _cartLeft.clamp(
              0.0,
              screenWidth - 68,
            );

            _cartTop = _cartTop.clamp(
              5.0,
              320.0,
            );
          });
        },
        onTap: _openCart,
        child: StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseAuth.instance.currentUser == null
              ? null
              : FirebaseFirestore.instance
                  .collection('users')
                  .doc(
                    FirebaseAuth.instance.currentUser!.uid,
                  )
                  .collection('cart')
                  .snapshots(),
          builder: (context, snapshot) {
            int quantity = 0;

            if (snapshot.hasData) {
              for (final doc in snapshot.data!.docs) {
                final data = doc.data();
                final value = data['quantity'];

                if (value is num) {
                  quantity += value.toInt();
                } else {
                  quantity++;
                }
              }
            }

            return Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.22,
                    ),
                    blurRadius: 10,
                    offset: const Offset(
                      0,
                      4,
                    ),
                  ),
                ],
                border: Border.all(
                  color: Colors.redAccent,
                  width: 2,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Center(
                    child: Icon(
                      Icons.shopping_cart,
                      color: Colors.redAccent,
                      size: 29,
                    ),
                  ),
                  if (quantity > 0)
                    Positioned(
                      right: -2,
                      top: -4,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 22,
                          minHeight: 22,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            quantity > 99
                                ? '99+'
                                : '$quantity',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // =========================================================
  // REVIEWS SECTION
  // =========================================================

  Widget _buildReviewsSection() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _reviewsReference
          .where(
            'productId',
            isEqualTo: widget.productId,
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Unable to load reviews.',
            ),
          );
        }

        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final reviews = snapshot.data?.docs ?? [];

        double averageRating = 0;

        if (reviews.isNotEmpty) {
          double total = 0;

          for (final review in reviews) {
            final rating = review.data()['rating'];

            if (rating is num) {
              total += rating.toDouble();
            }
          }

          averageRating = total / reviews.length;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 28),

            const Text(
              'Ratings & Reviews',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Column(
                    children: [
                      Text(
                        averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: List.generate(
                          5,
                          (index) {
                            return Icon(
                              index < averageRating.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 20,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${reviews.length} review${reviews.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 24),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customer Reviews',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'See what other buyers think about this product.',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            FutureBuilder<
                QueryDocumentSnapshot<
                    Map<String, dynamic>>?>(
              future: _findMyReview(),
              builder: (
                context,
                myReviewSnapshot,
              ) {
                final myReview = myReviewSnapshot.data;

                return SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showReviewDialog(
                        existingReview: myReview,
                      );
                    },
                    icon: Icon(
                      myReview == null
                          ? Icons.rate_review_outlined
                          : Icons.edit_outlined,
                    ),
                    label: Text(
                      myReview == null
                          ? 'Write a Review'
                          : 'Edit My Review',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(
                        color: Colors.redAccent,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 13,
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            if (reviews.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      size: 42,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No reviews yet',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Be the first buyer to review this product.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...reviews.map(
                (reviewDoc) {
                  final data = reviewDoc.data();

                  final ratingValue = data['rating'];

                  final rating =
                      ratingValue is num
                          ? ratingValue.toInt()
                          : 0;

                  final name =
                      data['userName']?.toString() ??
                      'Buyer';

                  final reviewText =
                      data['review']?.toString() ??
                      '';

                  return Card(
                    margin: const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    Colors.redAccent.withValues(
                                  alpha: 0.10,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.redAccent,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: List.generate(
                                        5,
                                        (index) {
                                          return Icon(
                                            index < rating
                                                ? Icons.star
                                                : Icons.star_border,
                                            color: Colors.amber,
                                            size: 17,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            reviewText,
                            style: const TextStyle(
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
  Widget build(BuildContext context) {
    final recipientType =
        isResellerProduct ? 'Reseller' : 'Seller';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        title: const Text(
          'Product Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.shopping_cart_outlined,
            ),
            onPressed: _openCart,
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          bottom: 120,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // =================================================
            // PRODUCT MEDIA
            // =================================================

            _buildMediaGallery(),

            // =================================================
            // PRODUCT INFORMATION
            // =================================================

            Padding(
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
                        child: Text(
                          productName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _loadingFavorite
                            ? null
                            : _toggleFavorite,
                        icon: Icon(
                          _isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: _isFavorite
                              ? Colors.redAccent
                              : Colors.grey,
                          size: 30,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  if (category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(
                          alpha: 0.10,
                        ),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  Text(
                    formattedPrice,
                    style: const TextStyle(
                      fontSize: 25,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // =================================================
                  // QUANTITY
                  // =================================================

                  const Text(
                    'Quantity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.shade300,
                          ),
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _decreaseQuantity,
                              icon: const Icon(
                                Icons.remove,
                              ),
                            ),
                            SizedBox(
                              width: 35,
                              child: Text(
                                '$_quantity',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _increaseQuantity,
                              icon: const Icon(
                                Icons.add,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 20),

                      Text(
                        'Total: $formattedSubtotal',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // =================================================
                  // SELLER / RESELLER
                  // =================================================

                  if (sellerCode.isNotEmpty ||
                      sellerId.isNotEmpty ||
                      sellerEmail.isNotEmpty ||
                      isResellerProduct)
                    Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              isResellerProduct
                                  ? 'Reseller Information'
                                  : 'Seller Information',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 10),

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

                            if (sellerCode.isNotEmpty)
                              Text(
                                'Seller ID: $sellerCode',
                              ),

                            if (sellerId.isNotEmpty)
                              Text(
                                'Seller UID: $sellerId',
                              ),

                            if (sellerEmail.isNotEmpty)
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

      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openMessageChat,
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                  ),
                  label: Text(
                    'Message $recipientType',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        Colors.redAccent,
                    side: const BorderSide(
                      color: Colors.redAccent,
                    ),
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addToCart,
                      icon: const Icon(
                        Icons.shopping_cart_outlined,
                      ),
                      label: const Text(
                        'Add to Cart',
                      ),
                      style:
                          OutlinedButton.styleFrom(
                        foregroundColor:
                            Colors.redAccent,
                        side: const BorderSide(
                          color: Colors.redAccent,
                        ),
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _buyNow,
                      icon: const Icon(
                        Icons.flash_on,
                      ),
                      label: const Text(
                        'Buy Now',
                      ),
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.redAccent,
                        foregroundColor:
                            Colors.white,
                        padding:
                            const EdgeInsets.symmetric(
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

  // =========================================================
  // NULLABLE DOUBLE
  // =========================================================

  double? _nullableDouble(dynamic value) {
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
}

// ===================================================================
// FULL-SCREEN MEDIA GALLERY
// ===================================================================

class _FullScreenMediaGallery extends StatefulWidget {
  final List<String> imageUrls;
  final String videoUrl;
  final int initialIndex;
  final VideoPlayerController? videoController;
  final VoidCallback onCartTap;

  const _FullScreenMediaGallery({
    required this.imageUrls,
    required this.videoUrl,
    required this.initialIndex,
    required this.videoController,
    required this.onCartTap,
  });

  @override
  State<_FullScreenMediaGallery> createState() =>
      _FullScreenMediaGalleryState();
}

class _FullScreenMediaGalleryState
    extends State<_FullScreenMediaGallery> {
  late final PageController _pageController;

  int _currentIndex = 0;

  double _cartLeft = 0;
  double _cartTop = 90;

  bool _cartPositionInitialized = false;

  int get totalMedia {
    return widget.imageUrls.length +
        (widget.videoUrl.isNotEmpty ? 1 : 0);
  }

  bool _isVideoIndex(int index) {
    return widget.videoUrl.isNotEmpty &&
        index == widget.imageUrls.length;
  }

  @override
  void initState() {
    super.initState();

    _currentIndex =
        widget.initialIndex.clamp(0, totalMedia - 1);

    _pageController = PageController(
      initialPage: _currentIndex,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_cartPositionInitialized) {
      final width = MediaQuery.of(context).size.width;

      _cartLeft = width - 78;
      _cartTop = 90;

      _cartPositionInitialized = true;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // =========================================================
  // IMAGE
  // =========================================================

  Widget _buildFullScreenImage(String url) {
    if (url.trim().isEmpty) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_outlined,
          color: Colors.white54,
          size: 90,
        ),
      );
    }

    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      panEnabled: true,
      child: Image.network(
        url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        loadingBuilder: (
          context,
          child,
          progress,
        ) {
          if (progress == null) {
            return child;
          }

          return const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          );
        },
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
          return const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 80,
            ),
          );
        },
      ),
    );
  }

  // =========================================================
  // VIDEO
  // =========================================================

  Widget _buildFullScreenVideo() {
    final controller = widget.videoController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Colors.white,
              ),
              SizedBox(height: 14),
              Text(
                'Loading video...',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }

        setState(() {});
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio == 0
                  ? 16 / 9
                  : controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          if (!controller.value.isPlaying)
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 48,
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================
  // THUMBNAIL
  // =========================================================

  Widget _buildFullScreenThumbnail(int index) {
    if (_isVideoIndex(index)) {
      return Container(
        color: Colors.black87,
        child: const Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 32,
            ),
            Positioned(
              bottom: 3,
              child: Text(
                'VIDEO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final url = widget.imageUrls[index];

    if (url.isEmpty) {
      return Container(
        color: Colors.grey.shade900,
        child: const Icon(
          Icons.image_outlined,
          color: Colors.white54,
        ),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) {
        return Container(
          color: Colors.grey.shade900,
          child: const Icon(
            Icons.broken_image_outlined,
            color: Colors.white54,
          ),
        );
      },
    );
  }

  // =========================================================
  // SELECT THUMBNAIL
  // =========================================================

  void _selectPage(int index) {
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(
          milliseconds: 280,
        ),
        curve: Curves.easeInOut,
      );
    }

    setState(() {
      _currentIndex = index;
    });
  }

  // =========================================================
  // CART
  // =========================================================

  Widget _buildFullScreenCart() {
    return Positioned(
      left: _cartLeft,
      top: _cartTop,
      child: GestureDetector(
        onPanUpdate: (details) {
          final width = MediaQuery.of(context).size.width;
          final height = MediaQuery.of(context).size.height;

          setState(() {
            _cartLeft += details.delta.dx;
            _cartTop += details.delta.dy;

            _cartLeft = _cartLeft.clamp(
              0.0,
              width - 68,
            );

            _cartTop = _cartTop.clamp(
              55.0,
              height - 150,
            );
          });
        },
        onTap: widget.onCartTap,
        child: StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseAuth.instance.currentUser == null
              ? null
              : FirebaseFirestore.instance
                  .collection('users')
                  .doc(
                    FirebaseAuth.instance.currentUser!.uid,
                  )
                  .collection('cart')
                  .snapshots(),
          builder: (context, snapshot) {
            int quantity = 0;

            if (snapshot.hasData) {
              for (final doc in snapshot.data!.docs) {
                final data = doc.data();
                final value = data['quantity'];

                if (value is num) {
                  quantity += value.toInt();
                } else {
                  quantity++;
                }
              }
            }

            return Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.redAccent,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.35,
                    ),
                    blurRadius: 12,
                    offset: const Offset(
                      0,
                      5,
                    ),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Center(
                    child: Icon(
                      Icons.shopping_cart,
                      color: Colors.redAccent,
                      size: 29,
                    ),
                  ),
                  if (quantity > 0)
                    Positioned(
                      right: -3,
                      top: -5,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 23,
                          minHeight: 23,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            quantity > 99
                                ? '99+'
                                : '$quantity',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // =========================================================
  // BUILD FULL-SCREEN GALLERY
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // =================================================
            // MEDIA
            // =================================================

            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                itemCount: totalMedia,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });

                  if (!_isVideoIndex(index)) {
                    widget.videoController?.pause();
                  }
                },
                itemBuilder: (context, index) {
                  if (_isVideoIndex(index)) {
                    return _buildFullScreenVideo();
                  }

                  return _buildFullScreenImage(
                    widget.imageUrls[index],
                  );
                },
              ),
            ),

            // =================================================
            // TOP BACK BUTTON
            // =================================================

            Positioned(
              left: 12,
              top: 12,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 27,
                    ),
                  ),
                ),
              ),
            ),

            // =================================================
            // MEDIA COUNTER
            // =================================================

            Positioned(
              top: 15,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1}/$totalMedia',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // =================================================
            // CART
            // =================================================

            _buildFullScreenCart(),

            // =================================================
            // PREVIOUS BUTTON
            // =================================================

            if (_currentIndex > 0)
              Positioned(
                left: 12,
                top: MediaQuery.of(context).size.height / 2 - 30,
                child: Material(
                  color: Colors.black45,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      _selectPage(_currentIndex - 1);
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),

            // =================================================
            // NEXT BUTTON
            // =================================================

            if (_currentIndex < totalMedia - 1)
              Positioned(
                right: 12,
                top: MediaQuery.of(context).size.height / 2 - 30,
                child: Material(
                  color: Colors.black45,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      _selectPage(_currentIndex + 1);
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),

            // =================================================
            // THUMBNAILS
            // =================================================

            if (totalMedia > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 92,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: 0.78,
                    ),
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    itemCount: totalMedia,
                    itemBuilder: (context, index) {
                      final selected =
                          index == _currentIndex;

                      return GestureDetector(
                        onTap: () {
                          _selectPage(index);
                        },
                        child: Container(
                          width: 68,
                          margin: const EdgeInsets.only(
                            right: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? Colors.redAccent
                                  : Colors.white30,
                              width: selected ? 3 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(6),
                            child:
                                _buildFullScreenThumbnail(
                              index,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
