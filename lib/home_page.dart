import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import 'login_page.dart';
import 'user_profile_page.dart';
import 'add_product_page.dart';
import 'settings_page.dart';
import 'cart_page.dart';
import 'categories_page.dart';
import 'news_feed_page.dart';
import 'product_details_page.dart';
import 'global_notifications_page.dart';
import 'coupon_page.dart';
import 'seller_information_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  int _selectedCategory = 0;

  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';

  late AnimationController _couponAnimationController;
  late Animation<double> _couponOpacity;

  // =========================================================
  // PRODUCT AUTO SLIDER
  // =========================================================

  Timer? _productSliderTimer;

  final ScrollController _productSliderController =
      ScrollController();

  int _productSliderIndex = 0;
  int _productSliderCount = 0;

  final List<String> categories = [
    'All',
    'Phones',
    'Laptops',
    'Watches',
    'Earbuds',
    'Cameras',
    'Fashion',
    'Shoes',
    'Bags',
    'Beauty',
    'Sports',
    'Toys',
    'Grocery',
  ];

  @override
  void initState() {
    super.initState();

    _couponAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _couponOpacity = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _couponAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // =========================================================
    // START PRODUCT AUTO SLIDER
    // =========================================================

    _productSliderTimer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) {
        if (!mounted ||
            !_productSliderController.hasClients ||
            _productSliderCount <= 1) {
          return;
        }

        _productSliderIndex++;

        if (_productSliderIndex >= _productSliderCount) {
          _productSliderIndex = 0;

          _productSliderController.jumpTo(0);
          return;
        }

        final targetOffset =
            _productSliderIndex * 106.0;

        final maxScrollExtent =
            _productSliderController.position.maxScrollExtent;

        final safeOffset =
            targetOffset > maxScrollExtent
                ? maxScrollExtent
                : targetOffset;

        _productSliderController.animateTo(
          safeOffset,
          duration: const Duration(
            milliseconds: 650,
          ),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  @override
  void dispose() {
    _productSliderTimer?.cancel();
    _productSliderController.dispose();

    _couponAnimationController.dispose();
    _searchController.dispose();

    super.dispose();
  }

  // =========================================================
  // CATEGORY
  // =========================================================

  bool _matchesCategory(
    Map<String, dynamic> productData,
  ) {
    final selectedCategory =
        categories[_selectedCategory];

    if (selectedCategory == 'All') {
      return true;
    }

    final productCategory =
        productData['category']
                ?.toString()
                .trim() ??
            '';

    if (productCategory.isEmpty) {
      return false;
    }

    return productCategory.toLowerCase() ==
        selectedCategory.toLowerCase();
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'all':
        return Icons.apps_rounded;
      case 'phones':
        return Icons.phone_iphone;
      case 'laptops':
        return Icons.laptop_mac;
      case 'watches':
        return Icons.watch;
      case 'earbuds':
        return Icons.headphones;
      case 'cameras':
        return Icons.camera_alt;
      case 'fashion':
        return Icons.checkroom;
      case 'shoes':
        return Icons.directions_run;
      case 'bags':
        return Icons.shopping_bag;
      case 'beauty':
        return Icons.face_retouching_natural;
      case 'sports':
        return Icons.sports_soccer;
      case 'toys':
        return Icons.toys;
      case 'grocery':
        return Icons.local_grocery_store;
      default:
        return Icons.category;
    }
  }

  String? _getCategoryImageUrl(
    String category,
    List<QueryDocumentSnapshot> products,
  ) {
    final normalizedCategory =
        category.trim().toLowerCase();

    for (final product in products) {
      final data =
          product.data() as Map<String, dynamic>;

      final imageUrl =
          data['imageUrl']
                  ?.toString()
                  .trim() ??
              '';

      if (imageUrl.isEmpty) {
        continue;
      }

      final productCategory =
          data['category']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

      if (normalizedCategory == 'all' ||
          productCategory ==
              normalizedCategory) {
        return imageUrl;
      }
    }

    return null;
  }

  // =========================================================
  // PRICE
  // =========================================================

  double _displayBdtPrice(
    Map<String, dynamic> productData,
  ) {
    final rawPrice = productData['price'] is num
        ? (productData['price'] as num).toDouble()
        : 0.0;

    final currency = productData['currency']
        ?.toString()
        .trim()
        .toUpperCase();

    if (currency == 'BDT') {
      return rawPrice;
    }

    return rawPrice * 0.09;
  }

  String _formatBdtPrice(
    Map<String, dynamic> productData,
  ) {
    final bdtPrice =
        _displayBdtPrice(productData);

    return '৳${bdtPrice.toStringAsFixed(2)}';
  }

  // =========================================================
  // FAVORITES
  // =========================================================

  DocumentReference<Map<String, dynamic>>
      _favoriteReference(
    String userId,
    String productId,
  ) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(productId);
  }

  Future<void> _toggleFavorite({
    required User user,
    required String productId,
    required Map<String, dynamic> productData,
  }) async {
    final favoriteRef =
        _favoriteReference(
      user.uid,
      productId,
    );

    try {
      final favoriteSnapshot =
          await favoriteRef.get();

      if (favoriteSnapshot.exists) {
        await favoriteRef.delete();

        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content:
                Text('Removed from Favorites'),
            behavior:
                SnackBarBehavior.floating,
            duration:
                Duration(seconds: 1),
          ),
        );
      } else {
        final name =
            productData['name']
                    ?.toString() ??
                'Unnamed Product';

        final imageUrl =
            productData['imageUrl']
                    ?.toString() ??
                '';

        final category =
            productData['category']
                    ?.toString() ??
                '';

        final price =
            _displayBdtPrice(productData);

        await favoriteRef.set({
          'productId': productId,
          'productName': name,
          'productImageUrl': imageUrl,
          'category': category,
          'price': price,
          'currency': 'BDT',
          'currencySymbol': '৳',
          'userId': user.uid,
          'createdAt':
              FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content:
                Text('Added to Favorites ❤️'),
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
            'Could not update Favorites: $e',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    }
  }

  // =========================================================
  // SELLER PROFILE
  // =========================================================

  String? _getProductSellerId(
    Map<String, dynamic> product,
  ) {
    // Reseller/Entrepreneur product:
    final entrepreneurUid =
        product['entrepreneurUid']
                ?.toString()
                .trim() ??
            '';

    if (entrepreneurUid.isNotEmpty) {
      return entrepreneurUid;
    }

    // Normal seller product:
    final sellerId =
        product['sellerId']
                ?.toString()
                .trim() ??
            '';

    if (sellerId.isNotEmpty) {
      return sellerId;
    }

    return null;
  }

  Future<void> _openSellerProfile({
    required Map<String, dynamic> product,
  }) async {
    final sellerId =
        _getProductSellerId(product);

    if (sellerId == null ||
        sellerId.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Seller information is not available.',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );

      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SellerInformationPage(
          sellerId: sellerId,
        ),
      ),
    );
  }

  // =========================================================
  // PRODUCT DETAILS
  // =========================================================

  void _openProductDetails({
    required String productId,
    required Map<String, dynamic> product,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProductDetailsPage(
          productId: productId,
          product: product,
        ),
      ),
    );
  }

  // =========================================================
  // GLOBAL NOTIFICATIONS
  // =========================================================

  Future<void>
      _openGlobalNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const GlobalNotificationsPage(),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  // =========================================================
  // CAMERA / GALLERY IMAGE SEARCH
  // =========================================================

  Future<void> _openCameraSearch() async {
    final ImageSource? source =
        await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              20,
            ),
            decoration:
                const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin:
                      const EdgeInsets.only(
                    bottom: 18,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.grey.shade300,
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                ),
                const Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    'Search by Image',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                ListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration:
                        BoxDecoration(
                      color: Colors
                          .redAccent
                          .withValues(
                        alpha: 0.10,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                    ),
                    child: const Icon(
                      Icons
                          .camera_alt_outlined,
                      color:
                          Colors.redAccent,
                    ),
                  ),
                  title: const Text(
                    'Take Photo',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Take a new picture with camera',
                  ),
                  onTap: () {
                    Navigator.pop(
                      context,
                      ImageSource.camera,
                    );
                  },
                ),
                const SizedBox(height: 6),
                ListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration:
                        BoxDecoration(
                      color: Colors
                          .blueAccent
                          .withValues(
                        alpha: 0.10,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                    ),
                    child: const Icon(
                      Icons
                          .photo_library_outlined,
                      color:
                          Colors.blueAccent,
                    ),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Select an existing product photo',
                  ),
                  onTap: () {
                    Navigator.pop(
                      context,
                      ImageSource.gallery,
                    );
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width:
                      double.infinity,
                  height: 46,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                    },
                    child:
                        const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }

    try {
      final picker =
          ImagePicker();

      final XFile? image =
          await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (image == null || !mounted) {
        return;
      }

      await _showImagePreview(image);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not select image: $e',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    }
  }

  // =========================================================
  // IMAGE PREVIEW
  // =========================================================

  Future<void> _showImagePreview(
    XFile image,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            padding:
                const EdgeInsets.all(16),
            decoration:
                const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin:
                      const EdgeInsets.only(
                    bottom: 16,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.grey.shade300,
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                ),
                const Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    'Selected Photo',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                  child: Image.file(
                    File(image.path),
                    width:
                        double.infinity,
                    height: 300,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                Row(
                  children: [
                    Expanded(
                      child:
                          OutlinedButton
                              .icon(
                        style:
                            OutlinedButton
                                .styleFrom(
                          minimumSize:
                              const Size
                                  .fromHeight(
                            50,
                          ),
                          side:
                              const BorderSide(
                            color:
                                Colors.redAccent,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              14,
                            ),
                          ),
                        ),
                        onPressed:
                            () async {
                          Navigator.pop(
                            context,
                          );
                          await _openCameraSearch();
                        },
                        icon:
                            const Icon(
                          Icons.refresh,
                          color:
                              Colors.redAccent,
                        ),
                        label:
                            const Text(
                          'Choose Again',
                          style:
                              TextStyle(
                            color:
                                Colors.redAccent,
                            fontWeight:
                                FontWeight.bold,
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
                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              Colors.redAccent,
                          foregroundColor:
                              Colors.white,
                          minimumSize:
                              const Size
                                  .fromHeight(
                            50,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              14,
                            ),
                          ),
                        ),
                        onPressed:
                            () async {
                          Navigator.pop(
                            context,
                          );
                          await _findProductsFromImage(
                            image,
                          );
                        },
                        icon:
                            const Icon(
                          Icons.search,
                        ),
                        label:
                            const Text(
                          'Use Photo',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 8,
                ),
                SizedBox(
                  width:
                      double.infinity,
                  height: 45,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                    },
                    child:
                        const Text(
                      'Cancel',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // IMAGE ANALYSIS
  // =========================================================

  Future<void> _findProductsFromImage(
    XFile image,
  ) async {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 3,
                ),
              ),
              SizedBox(width: 18),
              Expanded(
                child: Text(
                  'Analyzing image...',
                ),
              ),
            ],
          ),
        );
      },
    );

    ImageLabeler? imageLabeler;

    try {
      final inputImage =
          InputImage.fromFilePath(
        image.path,
      );

      imageLabeler =
          ImageLabeler(
        options:
            ImageLabelerOptions(
          confidenceThreshold:
              0.45,
        ),
      );

      final labels =
          await imageLabeler.processImage(
        inputImage,
      );

      final detectedLabels =
          labels
              .map(
                (label) => label.label
                    .trim()
                    .toLowerCase(),
              )
              .where(
                (label) =>
                    label.isNotEmpty,
              )
              .toSet()
              .toList();

      final snapshot =
          await FirebaseFirestore
              .instance
              .collection('products')
              .get();

      final matchedProducts =
          <QueryDocumentSnapshot>[];

      for (final doc
          in snapshot.docs) {
        final data = doc.data();

        final productName =
            data['name']
                    ?.toString()
                    .toLowerCase() ??
                '';

        final category =
            data['category']
                    ?.toString()
                    .toLowerCase() ??
                '';

        final description =
            data['description']
                    ?.toString()
                    .toLowerCase() ??
                '';

        final searchText =
            '$productName $category $description';

        bool matched = false;

        for (final label
            in detectedLabels) {
          if (searchText
              .contains(label)) {
            matched = true;
            break;
          }

          final words = label
              .split(
                RegExp(
                  r'[\s\-_]+',
                ),
              )
              .where(
                (word) =>
                    word.length >= 3,
              );

          for (final word
              in words) {
            if (searchText
                .contains(word)) {
              matched = true;
              break;
            }
          }

          if (matched) {
            break;
          }
        }

        if (matched) {
          matchedProducts.add(doc);
        }
      }

      if (!mounted) return;

      Navigator.of(context).pop();

      await imageLabeler.close();
      imageLabeler = null;

      await _showImageSearchResults(
        image: image,
        detectedLabels:
            detectedLabels,
        products:
            matchedProducts,
      );
    } catch (e) {
      if (imageLabeler != null) {
        await imageLabeler.close();
      }

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Image search failed: $e',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    }
  }

  // =========================================================
  // IMAGE SEARCH RESULTS
  // =========================================================

  Future<void> _showImageSearchResults({
    required XFile image,
    required List<String> detectedLabels,
    required List<QueryDocumentSnapshot>
        products,
  }) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            height:
                MediaQuery.of(context)
                        .size
                        .height *
                    0.82,
            decoration:
                const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                Container(
                  width: 42,
                  height: 4,
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.grey.shade300,
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                const Padding(
                  padding:
                      EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  child: Align(
                    alignment:
                        Alignment.centerLeft,
                    child: Text(
                      'Image Search Results',
                      style:
                          TextStyle(
                        fontSize: 21,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                Padding(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                        child:
                            Image.file(
                          File(image.path),
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Text(
                              'Detected:',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                              height: 4,
                            ),
                            Text(
                              detectedLabels
                                      .isEmpty
                                  ? 'No clear object detected'
                                  : detectedLabels
                                      .take(5)
                                      .join(
                                        ', ',
                                      ),
                              maxLines: 2,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  TextStyle(
                                color: Colors
                                    .grey
                                    .shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                const Divider(
                  height: 1,
                ),
                Expanded(
                  child: products
                          .isEmpty
                      ? Center(
                          child:
                              Padding(
                            padding:
                                const EdgeInsets
                                    .all(
                              30,
                            ),
                            child:
                                Column(
                              mainAxisSize:
                                  MainAxisSize
                                      .min,
                              children: [
                                Icon(
                                  Icons
                                      .search_off_rounded,
                                  size: 60,
                                  color: Colors
                                      .grey
                                      .shade400,
                                ),
                                const SizedBox(
                                  height: 14,
                                ),
                                const Text(
                                  'No matching products found',
                                  textAlign:
                                      TextAlign
                                          .center,
                                  style:
                                      TextStyle(
                                    fontSize:
                                        18,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                                const SizedBox(
                                  height: 8,
                                ),
                                Text(
                                  'Try another photo with the product clearly visible.',
                                  textAlign:
                                      TextAlign
                                          .center,
                                  style:
                                      TextStyle(
                                    color: Colors
                                        .grey
                                        .shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets
                                  .all(
                            12,
                          ),
                          itemCount:
                              products.length,
                          itemBuilder:
                              (context,
                                  index) {
                            final doc =
                                products[
                                    index];

                            final data =
                                doc.data()
                                    as Map<String,
                                        dynamic>;

                            final name =
                                data['name']
                                        ?.toString() ??
                                    'Unnamed Product';

                            final imageUrl =
                                data['imageUrl']
                                    ?.toString();

                            final price =
                                _formatBdtPrice(
                              data,
                            );

                            return Card(
                              elevation: 2,
                              margin:
                                  const EdgeInsets
                                      .only(
                                bottom: 10,
                              ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  14,
                                ),
                              ),
                              child:
                                  ListTile(
                                contentPadding:
                                    const EdgeInsets
                                        .all(
                                  8,
                                ),
                                leading:
                                    ClipRRect(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    10,
                                  ),
                                  child: imageUrl !=
                                              null &&
                                          imageUrl
                                              .isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          width:
                                              65,
                                          height:
                                              65,
                                          fit: BoxFit
                                              .cover,
                                          errorBuilder:
                                              (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return Container(
                                              width:
                                                  65,
                                              height:
                                                  65,
                                              color: Colors
                                                  .grey
                                                  .shade200,
                                              child:
                                                  const Icon(
                                                Icons
                                                    .image,
                                              ),
                                            );
                                          },
                                        )
                                      : Container(
                                          width:
                                              65,
                                          height:
                                              65,
                                          color: Colors
                                              .grey
                                              .shade200,
                                          child:
                                              const Icon(
                                            Icons
                                                .image,
                                          ),
                                        ),
                                ),
                                title:
                                    Text(
                                  name,
                                  maxLines:
                                      2,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                                subtitle:
                                    Padding(
                                  padding:
                                      const EdgeInsets
                                          .only(
                                    top: 5,
                                  ),
                                  child:
                                      Text(
                                    price,
                                    style:
                                        const TextStyle(
                                      color: Colors
                                          .redAccent,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                      fontSize:
                                          16,
                                    ),
                                  ),
                                ),
                                trailing:
                                    const Icon(
                                  Icons
                                      .arrow_forward_ios,
                                  size: 16,
                                ),
                                onTap: () {
                                  Navigator.pop(
                                    context,
                                  );

                                  _openProductDetails(
                                    productId:
                                        doc.id,
                                    product:
                                        data,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // COUPON
  // =========================================================

  void _openCoupon() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const CouponPage(),
      ),
    );
  }

  // =========================================================
  // BOTTOM NAVIGATION
  // =========================================================

  Future<void> _onNavTap(
    int index,
  ) async {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      return;
    }

    if (index == 1) {
      final result =
          await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const CategoriesPage(),
        ),
      );

      if (result != null && mounted) {
        final matchIndex =
            categories.indexOf(result);

        if (matchIndex != -1) {
          setState(() {
            _selectedCategory =
                matchIndex;
          });
        }
      }

      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
      }

      return;
    }

    if (index == 2) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const NewsFeedPage(),
        ),
      );

      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
      }

      return;
    }

    if (index == 3) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const CartPage(),
        ),
      );

      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
      }

      return;
    }

    if (index == 4) {
      final currentUser =
          FirebaseAuth.instance
              .currentUser;

      if (currentUser == null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const LoginPage(),
          ),
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const UserProfilePage(),
          ),
        );
      }

      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
      }
    }
  }

  // =========================================================
  // VIDEOS
  // =========================================================

  void _openVideos() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const NewsFeedPage(),
      ),
    );
  }

  // =========================================================
  // ACCOUNT
  // =========================================================

  void _openAccount(
    bool isLoggedIn,
  ) {
    if (isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const UserProfilePage(),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const LoginPage(),
        ),
      );
    }
  }

  // =========================================================
  // BUYNOVA LOGO
  // =========================================================

  Widget _buildBuyNovaLogo() {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          fontSize: 21,
          fontWeight:
              FontWeight.w900,
          letterSpacing: -0.4,
        ),
        children: [
          TextSpan(
            text: 'B',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          TextSpan(
            text: 'u',
            style: TextStyle(
              color: Colors.yellow,
            ),
          ),
          TextSpan(
            text: 'y',
            style: TextStyle(
              color: Colors.orange,
            ),
          ),
          TextSpan(
            text: 'N',
            style: TextStyle(
              color: Colors.greenAccent,
            ),
          ),
          TextSpan(
            text: 'o',
            style: TextStyle(
              color:
                  Colors.lightBlueAccent,
            ),
          ),
          TextSpan(
            text: 'v',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          TextSpan(
            text: 'a',
            style: TextStyle(
              color: Colors.cyanAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGetCoupon() {
    return FadeTransition(
      opacity: _couponOpacity,
      child: GestureDetector(
        onTap: _openCoupon,
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 5,
          ),
          decoration:
              BoxDecoration(
            gradient:
                LinearGradient(
              colors: [
                Colors.yellowAccent
                    .withValues(
                  alpha: 0.16,
                ),
                Colors.white.withValues(
                  alpha: 0.10,
                ),
              ],
            ),
            borderRadius:
                BorderRadius.circular(9),
            border: Border.all(
              color: Colors
                  .yellowAccent
                  .withValues(
                alpha: 0.75,
              ),
              width: 1,
            ),
          ),
          child: const Text(
            'Get Coupon',
            style: TextStyle(
              color:
                  Colors.yellowAccent,
              fontSize: 11,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // CART BADGE
  // =========================================================

  Widget _buildCartNavIcon(
    User? user,
  ) {
    if (user == null) {
      return const Icon(
        Icons.shopping_cart_outlined,
      );
    }

    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream: FirebaseFirestore
          .instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .snapshots(),
      builder:
          (context, snapshot) {
        int cartCount = 0;

        if (snapshot.hasData) {
          for (final doc
              in snapshot.data!.docs) {
            final data = doc.data();

            final quantity =
                data['quantity'];

            if (quantity is num) {
              cartCount +=
                  quantity.toInt();
            } else {
              cartCount += 1;
            }
          }
        }

        return Stack(
          clipBehavior:
              Clip.none,
          children: [
            const Icon(
              Icons
                  .shopping_cart_outlined,
            ),
            if (cartCount > 0)
              Positioned(
                right: -9,
                top: -9,
                child: Container(
                  constraints:
                      const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration:
                      const BoxDecoration(
                    color:
                        Colors.redAccent,
                    shape:
                        BoxShape.circle,
                  ),
                  child: Text(
                    cartCount > 99
                        ? '99+'
                        : '$cartCount',
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize: 9,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // =========================================================
  // CATEGORY WIDGET
  // =========================================================

  Widget _buildCategoryItem({
    required String category,
    required int index,
    required List<QueryDocumentSnapshot>
        products,
  }) {
    final isSelected =
        _selectedCategory == index;

    final imageUrl =
        _getCategoryImageUrl(
      category,
      products,
    );

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory =
              index;
        });
      },
      child: SizedBox(
        width: 78,
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration:
                  const Duration(
                milliseconds: 180,
              ),
              width: 60,
              height: 60,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    Colors.grey.shade100,
                border: Border.all(
                  color: isSelected
                      ? Colors.redAccent
                      : Colors.grey.shade200,
                  width: isSelected
                      ? 2.5
                      : 1,
                ),
                boxShadow:
                    isSelected
                        ? [
                            BoxShadow(
                              color: Colors
                                  .redAccent
                                  .withValues(
                                alpha: 0.18,
                              ),
                              blurRadius:
                                  7,
                              spreadRadius:
                                  1,
                            ),
                          ]
                        : null,
              ),
              child: ClipOval(
                child: imageUrl != null &&
                        imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (
                          context,
                          error,
                          stackTrace,
                        ) {
                          return Icon(
                            _categoryIcon(
                              category,
                            ),
                            color: isSelected
                                ? Colors
                                    .redAccent
                                : Colors
                                    .grey
                                    .shade600,
                            size: 28,
                          );
                        },
                      )
                    : Icon(
                        _categoryIcon(
                          category,
                        ),
                        color: isSelected
                            ? Colors
                                .redAccent
                            : Colors
                                .grey
                                .shade600,
                        size: 28,
                      ),
              ),
            ),
            const SizedBox(
              height: 5,
            ),
            Text(
              category,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: isSelected
                    ? Colors.redAccent
                    : Colors.black87,
                fontSize: 11,
                fontWeight: isSelected
                    ? FontWeight.bold
                    : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // PRODUCT AUTO SLIDER
  // =========================================================

  Widget _buildProductAutoSlider(
    List<QueryDocumentSnapshot>
        products,
  ) {
    final sliderProducts =
        products.take(10).toList();

    _productSliderCount =
        sliderProducts.length;

    if (_productSliderCount == 0) {
      return const SizedBox.shrink();
    }

    if (_productSliderIndex >=
        _productSliderCount) {
      _productSliderIndex = 0;
    }

    return Container(
      height: 122,
      color: Colors.white,
      child: ListView.builder(
        controller:
            _productSliderController,
        scrollDirection:
            Axis.horizontal,
        physics:
            const BouncingScrollPhysics(),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        itemCount:
            sliderProducts.length,
        itemBuilder:
            (context, index) {
          final doc =
              sliderProducts[index];

          final data =
              doc.data()
                  as Map<String, dynamic>;

          final name =
              data['name']
                      ?.toString() ??
                  'Unnamed Product';

          final imageUrl =
              data['imageUrl']
                      ?.toString()
                      .trim() ??
                  '';

          final price =
              _formatBdtPrice(data);

          return SizedBox(
            width: 98,
            child: GestureDetector(
              onTap: () {
                _openSellerProfile(
                  product: data,
                );
              },
              child: Container(
                margin:
                    const EdgeInsets.only(
                  right: 8,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                  border: Border.all(
                    color:
                        Colors.grey.shade200,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(
                        alpha: 0.07,
                      ),
                      blurRadius: 4,
                      offset:
                          const Offset(
                        0,
                        2,
                      ),
                    ),
                  ],
                ),
                clipBehavior:
                    Clip.antiAlias,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    SizedBox(
                      height: 72,
                      width:
                          double.infinity,
                      child: imageUrl
                              .isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit
                                  .cover,
                              errorBuilder:
                                  (
                                context,
                                error,
                                stackTrace,
                              ) {
                                return Container(
                                  color: Colors
                                      .grey
                                      .shade100,
                                  child:
                                      const Icon(
                                    Icons
                                        .image_outlined,
                                    color:
                                        Colors.grey,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors
                                  .grey
                                  .shade100,
                              child:
                                  const Icon(
                                Icons
                                    .image_outlined,
                                color:
                                    Colors.grey,
                              ),
                            ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        6,
                        4,
                        6,
                        3,
                      ),
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 10,
                          fontWeight:
                              FontWeight
                                  .w600,
                        ),
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 6,
                      ),
                      child: Text(
                        price,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          color: Colors
                              .redAccent,
                          fontSize: 11,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance
          .authStateChanges(),
      builder:
          (context, authSnapshot) {
        final user =
            authSnapshot.data;

        final isLoggedIn =
            user != null;

        return Scaffold(
          // ==================================================
          // DRAWER
          // ==================================================

          drawer: Drawer(
            child: SafeArea(
              child: ListView(
                padding:
                    EdgeInsets.zero,
                children: [
                  const DrawerHeader(
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.redAccent,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons
                              .shopping_bag,
                          color:
                              Colors.white,
                          size: 32,
                        ),
                        SizedBox(
                          width: 12,
                        ),
                        Text(
                          'BuyNova',
                          style:
                              TextStyle(
                            color:
                                Colors.white,
                            fontSize:
                                24,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading:
                        const Icon(
                      Icons
                          .person_outline,
                    ),
                    title:
                        const Text(
                      'Account',
                    ),
                    onTap: () {
                      Navigator.pop(
                        context,
                      );

                      _openAccount(
                        isLoggedIn,
                      );
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(
                      Icons
                          .home_outlined,
                    ),
                    title:
                        const Text(
                      'Home',
                    ),
                    onTap: () {
                      Navigator.pop(
                        context,
                      );

                      setState(() {
                        _selectedIndex =
                            0;
                      });
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(
                      Icons
                          .category_outlined,
                    ),
                    title:
                        const Text(
                      'Categories',
                    ),
                    onTap:
                        () async {
                      Navigator.pop(
                        context,
                      );

                      final result =
                          await Navigator
                              .push<
                                  String>(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  const CategoriesPage(),
                        ),
                      );

                      if (result != null &&
                          mounted) {
                        final matchIndex =
                            categories
                                .indexOf(
                          result,
                        );

                        if (matchIndex !=
                            -1) {
                          setState(() {
                            _selectedCategory =
                                matchIndex;
                          });
                        }
                      }
                    },
                  ),
                  if (isLoggedIn)
                    ListTile(
                      leading:
                          const Icon(
                        Icons
                            .add_circle_outline,
                      ),
                      title:
                          const Text(
                        'Add Product',
                      ),
                      onTap: () {
                        Navigator.pop(
                          context,
                        );

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    const AddProductPage(),
                          ),
                        );
                      },
                    ),
                  ListTile(
                    leading:
                        const Icon(
                      Icons
                          .video_library_outlined,
                    ),
                    title:
                        const Text(
                      'Videos',
                    ),
                    subtitle:
                        const Text(
                      'Watch Reels & Videos',
                    ),
                    onTap: () {
                      Navigator.pop(
                        context,
                      );

                      _openVideos();
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(
                      Icons
                          .shopping_cart_outlined,
                    ),
                    title:
                        const Text(
                      'Cart',
                    ),
                    onTap: () {
                      Navigator.pop(
                        context,
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  const CartPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(
                      Icons
                          .settings_outlined,
                    ),
                    title:
                        const Text(
                      'Settings',
                    ),
                    onTap: () {
                      Navigator.pop(
                        context,
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  const SettingsPage(),
                        ),
                      );
                    },
                  ),
                  if (isLoggedIn)
                    ListTile(
                      leading:
                          const Icon(
                        Icons.logout,
                      ),
                      title:
                          const Text(
                        'Logout',
                      ),
                      onTap:
                          () async {
                        Navigator.pop(
                          context,
                        );

                        await FirebaseAuth
                            .instance
                            .signOut();
                      },
                    ),
                ],
              ),
            ),
          ),

          // ==================================================
          // APP BAR
          // ==================================================

          appBar: AppBar(
            backgroundColor:
                Colors.redAccent,
            elevation: 0,
            leading:
                Builder(
              builder:
                  (context) {
                return IconButton(
                  icon:
                      const Icon(
                    Icons.menu,
                    color:
                        Colors.white,
                  ),
                  onPressed: () {
                    Scaffold.of(
                      context,
                    ).openDrawer();
                  },
                );
              },
            ),
            titleSpacing: 0,
            title: Row(
              children: [
                _buildBuyNovaLogo(),
                const SizedBox(
                  width: 10,
                ),
                _buildGetCoupon(),
              ],
            ),
            actions: [
              if (user == null)
                IconButton(
                  icon:
                      const Icon(
                    Icons
                        .notifications_outlined,
                    color:
                        Colors.white,
                  ),
                  onPressed:
                      _openGlobalNotifications,
                )
              else
                StreamBuilder<
                    QuerySnapshot>(
                  stream:
                      FirebaseFirestore
                          .instance
                          .collection(
                            'global_notifications',
                          )
                          .where(
                            'active',
                            isEqualTo:
                                true,
                          )
                          .snapshots(),
                  builder: (
                    context,
                    notificationSnapshot,
                  ) {
                    final notifications =
                        notificationSnapshot
                                .data
                                ?.docs ??
                            [];

                    return StreamBuilder<
                        QuerySnapshot>(
                      stream:
                          FirebaseFirestore
                              .instance
                              .collection(
                                'users',
                              )
                              .doc(
                                user.uid,
                              )
                              .collection(
                                'globalNotificationReads',
                              )
                              .snapshots(),
                      builder: (
                        context,
                        readSnapshot,
                      ) {
                        final readIds =
                            <String>{};

                        for (final readDoc
                            in readSnapshot
                                    .data
                                    ?.docs ??
                                []) {
                          readIds.add(
                            readDoc.id,
                          );
                        }

                        int unreadCount =
                            0;

                        for (final notification
                            in notifications) {
                          if (!readIds
                              .contains(
                            notification.id,
                          )) {
                            unreadCount++;
                          }
                        }

                        return Stack(
                          clipBehavior:
                              Clip.none,
                          children: [
                            IconButton(
                              icon:
                                  const Icon(
                                Icons
                                    .notifications_outlined,
                                color: Colors
                                    .white,
                              ),
                              onPressed:
                                  _openGlobalNotifications,
                            ),
                            if (unreadCount >
                                0)
                              Positioned(
                                right: 4,
                                top: 4,
                                child:
                                    Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal:
                                        4,
                                    vertical:
                                        2,
                                  ),
                                  constraints:
                                      const BoxConstraints(
                                    minWidth:
                                        17,
                                    minHeight:
                                        17,
                                  ),
                                  decoration:
                                      const BoxDecoration(
                                    color: Colors
                                        .white,
                                    shape:
                                        BoxShape
                                            .circle,
                                  ),
                                  child:
                                      Text(
                                    unreadCount >
                                            99
                                        ? '99+'
                                        : '$unreadCount',
                                    textAlign:
                                        TextAlign
                                            .center,
                                    style:
                                        const TextStyle(
                                      color: Colors
                                          .redAccent,
                                      fontSize:
                                          9,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
            ],
          ),

          // ==================================================
          // BODY
          // ==================================================

          body: Column(
            children: [
              // ==================================================
              // SEARCH BAR
              // ==================================================

              Container(
                color:
                    Colors.redAccent,
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  14,
                  2,
                  14,
                  12,
                ),
                child: Container(
                  height: 48,
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white,
                    borderRadius:
                        BorderRadius
                            .circular(
                      24,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors
                            .black
                            .withValues(
                          alpha:
                              0.12,
                        ),
                        blurRadius: 7,
                        offset:
                            const Offset(
                          0,
                          2,
                        ),
                      ),
                    ],
                  ),
                  child:
                      TextField(
                    controller:
                        _searchController,
                    textInputAction:
                        TextInputAction
                            .search,
                    onChanged:
                        (value) {
                      setState(() {
                        _searchQuery =
                            value
                                .trim()
                                .toLowerCase();
                      });
                    },
                    decoration:
                        InputDecoration(
                      hintText:
                          'Search products...',
                      hintStyle:
                          TextStyle(
                        color: Colors
                            .grey
                            .shade500,
                        fontSize:
                            14,
                        fontWeight:
                            FontWeight
                                .w400,
                      ),
                      prefixIcon:
                          const Padding(
                        padding:
                            EdgeInsets
                                .only(
                          left: 4,
                          right: 2,
                        ),
                        child:
                            Icon(
                          Icons
                              .search_rounded,
                          color: Colors
                              .redAccent,
                          size: 24,
                        ),
                      ),
                      prefixIconConstraints:
                          const BoxConstraints(
                        minWidth:
                            46,
                        minHeight:
                            48,
                      ),
                      suffixIcon:
                          Row(
                        mainAxisSize:
                            MainAxisSize
                                .min,
                        children: [
                          if (_searchQuery
                              .isNotEmpty)
                            IconButton(
                              tooltip:
                                  'Clear',
                              splashRadius:
                                  20,
                              icon:
                                  Icon(
                                Icons
                                    .close_rounded,
                                color: Colors
                                    .grey
                                    .shade600,
                                size:
                                    20,
                              ),
                              onPressed:
                                  () {
                                _searchController
                                    .clear();

                                setState(
                                  () {
                                    _searchQuery =
                                        '';
                                  },
                                );
                              },
                            ),
                          Container(
                            height:
                                26,
                            width: 1,
                            color: Colors
                                .grey
                                .shade300,
                          ),
                          IconButton(
                            tooltip:
                                'Search by camera',
                            splashRadius:
                                20,
                            icon:
                                Icon(
                              Icons
                                  .camera_alt_outlined,
                              color: Colors
                                  .grey
                                  .shade700,
                              size:
                                  21,
                            ),
                            onPressed:
                                _openCameraSearch,
                          ),
                          const SizedBox(
                            width: 4,
                          ),
                        ],
                      ),
                      suffixIconConstraints:
                          const BoxConstraints(
                        minWidth: 0,
                        minHeight:
                            48,
                      ),
                      border:
                          InputBorder
                              .none,
                      enabledBorder:
                          InputBorder
                              .none,
                      focusedBorder:
                          InputBorder
                              .none,
                      contentPadding:
                          const EdgeInsets
                              .symmetric(
                        vertical:
                            13,
                        horizontal:
                            4,
                      ),
                    ),
                  ),
                ),
              ),

              // ==================================================
              // TEMU STYLE CATEGORIES
              // ==================================================

              SizedBox(
                height: 104,
                child:
                    StreamBuilder<
                        QuerySnapshot>(
                  stream:
                      FirebaseFirestore
                          .instance
                          .collection(
                            'products',
                          )
                          .snapshots(),
                  builder: (
                    context,
                    categorySnapshot,
                  ) {
                    final categoryProducts =
                        categorySnapshot
                                .data
                                ?.docs ??
                            [];

                    return Container(
                      color:
                          Colors.white,
                      child:
                          ListView.builder(
                        scrollDirection:
                            Axis.horizontal,
                        physics:
                            const BouncingScrollPhysics(),
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal:
                              10,
                        ),
                        itemCount:
                            categories
                                .length,
                        itemBuilder:
                            (
                          context,
                          index,
                        ) {
                          return _buildCategoryItem(
                            category:
                                categories[
                                    index],
                            index:
                                index,
                            products:
                                categoryProducts,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              // ==================================================
              // 10 PRODUCT AUTO SLIDER
              // ==================================================

              StreamBuilder<
                  QuerySnapshot>(
                stream:
                    FirebaseFirestore
                        .instance
                        .collection(
                          'products',
                        )
                        .snapshots(),
                builder: (
                  context,
                  sliderSnapshot,
                ) {
                  if (sliderSnapshot
                      .hasError) {
                    _productSliderCount =
                        0;

                    return const SizedBox
                        .shrink();
                  }

                  final sliderProducts =
                      sliderSnapshot
                              .data
                              ?.docs
                              .take(10)
                              .toList() ??
                          [];

                  return _buildProductAutoSlider(
                    sliderProducts,
                  );
                },
              ),

              // ==================================================
              // PRODUCTS
              // ==================================================

              Expanded(
                child:
                    StreamBuilder<
                        QuerySnapshot>(
                  stream:
                      FirebaseFirestore
                          .instance
                          .collection(
                            'products',
                          )
                          .snapshots(),
                  builder: (
                    context,
                    snapshot,
                  ) {
                    if (snapshot
                        .hasError) {
                      return const Center(
                        child: Text(
                          'Failed to load products',
                          style:
                              TextStyle(
                            fontSize:
                                16,
                            color: Colors
                                .grey,
                          ),
                        ),
                      );
                    }

                    if (snapshot
                            .connectionState ==
                        ConnectionState
                            .waiting) {
                      return const Center(
                        child:
                            CircularProgressIndicator(),
                      );
                    }

                    final allDocs =
                        snapshot
                                .data
                                ?.docs ??
                            [];

                    final filteredDocs =
                        allDocs.where(
                      (doc) {
                        final data =
                            doc.data()
                                as Map<
                                    String,
                                    dynamic>;

                        if (!_matchesCategory(
                          data,
                        )) {
                          return false;
                        }

                        if (_searchQuery
                            .isEmpty) {
                          return true;
                        }

                        final productName =
                            data['name']
                                    ?.toString()
                                    .toLowerCase() ??
                                '';

                        return productName
                            .contains(
                          _searchQuery,
                        );
                      },
                    ).toList();

                    if (filteredDocs
                        .isEmpty) {
                      return Center(
                        child: Text(
                          _searchQuery
                                  .isNotEmpty
                              ? 'No products found for "$_searchQuery"'
                              : _selectedCategory ==
                                      0
                                  ? 'No products found yet'
                                  : 'No products found in ${categories[_selectedCategory]}',
                          textAlign:
                              TextAlign
                                  .center,
                          style:
                              const TextStyle(
                            fontSize:
                                16,
                            color:
                                Colors.grey,
                          ),
                        ),
                      );
                    }

                    return StreamBuilder<
                        QuerySnapshot>(
                      stream: user == null
                          ? null
                          : FirebaseFirestore
                              .instance
                              .collection(
                                'users',
                              )
                              .doc(
                                user.uid,
                              )
                              .collection(
                                'favorites',
                              )
                              .snapshots(),
                      builder: (
                        context,
                        favoriteSnapshot,
                      ) {
                        final favoriteIds =
                            <String>{};

                        for (final favoriteDoc
                            in favoriteSnapshot
                                    .data
                                    ?.docs ??
                                []) {
                          favoriteIds.add(
                            favoriteDoc.id,
                          );
                        }

                        return GridView
                            .builder(
                          padding:
                              const EdgeInsets
                                  .all(
                            8,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                                2,
                            childAspectRatio:
                                0.75,
                            crossAxisSpacing:
                                8,
                            mainAxisSpacing:
                                8,
                          ),
                          itemCount:
                              filteredDocs
                                  .length,
                          itemBuilder:
                              (
                            context,
                            index,
                          ) {
                            final productDoc =
                                filteredDocs[
                                    index];

                            final data =
                                productDoc
                                    .data()
                                    as Map<
                                        String,
                                        dynamic>;

                            final productId =
                                productDoc.id;

                            final name =
                                data['name']
                                        ?.toString() ??
                                    'Unnamed Product';

                            final displayPrice =
                                _formatBdtPrice(
                              data,
                            );

                            final imageUrl =
                                data['imageUrl']
                                    ?.toString();

                            final isFavorite =
                                favoriteIds
                                    .contains(
                              productId,
                            );

                            return Card(
                              elevation:
                                  2,
                              clipBehavior:
                                  Clip.antiAlias,
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  10,
                                ),
                              ),
                              child:
                                  InkWell(
                                onTap:
                                    () {
                                  _openSellerProfile(
                                    product:
                                        data,
                                  );
                                },
                                child:
                                    Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Expanded(
                                      child:
                                          Stack(
                                        children: [
                                          Container(
                                            width:
                                                double.infinity,
                                            decoration:
                                                BoxDecoration(
                                              color: Colors
                                                  .grey[300],
                                            ),
                                            child: imageUrl !=
                                                        null &&
                                                    imageUrl
                                                        .isNotEmpty
                                                ? Image.network(
                                                    imageUrl,
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    errorBuilder:
                                                        (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return const Center(
                                                        child:
                                                            Icon(
                                                          Icons.image,
                                                          size:
                                                              50,
                                                          color:
                                                              Colors.grey,
                                                        ),
                                                      );
                                                    },
                                                  )
                                                : const Center(
                                                    child:
                                                        Icon(
                                                      Icons
                                                          .image,
                                                      size:
                                                          50,
                                                      color:
                                                          Colors.grey,
                                                    ),
                                                  ),
                                          ),
                                          Positioned(
                                            top:
                                                8,
                                            right:
                                                8,
                                            child:
                                                Material(
                                              color:
                                                  Colors.white,
                                              shape:
                                                  const CircleBorder(),
                                              elevation:
                                                  2,
                                              child:
                                                  InkWell(
                                                customBorder:
                                                    const CircleBorder(),
                                                onTap:
                                                    () async {
                                                  final currentUser =
                                                      user;

                                                  if (currentUser ==
                                                      null) {
                                                    await Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder:
                                                            (context) =>
                                                                const LoginPage(),
                                                      ),
                                                    );
                                                    return;
                                                  }

                                                  await _toggleFavorite(
                                                    user:
                                                        currentUser,
                                                    productId:
                                                        productId,
                                                    productData:
                                                        data,
                                                  );
                                                },
                                                child:
                                                    Padding(
                                                  padding:
                                                      const EdgeInsets.all(
                                                    7,
                                                  ),
                                                  child:
                                                      Icon(
                                                    isFavorite
                                                        ? Icons.favorite
                                                        : Icons.favorite_border,
                                                    color:
                                                        isFavorite
                                                            ? Colors.redAccent
                                                            : Colors.grey,
                                                    size:
                                                        21,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          const EdgeInsets
                                              .all(
                                        8,
                                      ),
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
                                            maxLines:
                                                1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(
                                            height:
                                                4,
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              Flexible(
                                                child:
                                                    Text(
                                                  displayPrice,
                                                  style:
                                                      const TextStyle(
                                                    color:
                                                        Colors.redAccent,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize:
                                                        16,
                                                  ),
                                                  maxLines:
                                                      1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(
                                                width:
                                                    5,
                                              ),
                                              InkWell(
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                  20,
                                                ),
                                                onTap:
                                                    () async {
                                                  final currentUser =
                                                      user;

                                                  if (currentUser ==
                                                      null) {
                                                    await Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder:
                                                            (context) =>
                                                                const LoginPage(),
                                                      ),
                                                    );
                                                    return;
                                                  }

                                                  final bdtPrice =
                                                      _displayBdtPrice(
                                                    data,
                                                  );

                                                  await CartService
                                                      .addItem(
                                                    id:
                                                        productId,
                                                    name:
                                                        name,
                                                    price:
                                                        bdtPrice,
                                                    imageUrl:
                                                        imageUrl,
                                                  );

                                                  if (!context
                                                      .mounted) {
                                                    return;
                                                  }

                                                  ScaffoldMessenger
                                                      .of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content:
                                                          Text(
                                                        '$name added to cart',
                                                      ),
                                                      behavior:
                                                          SnackBarBehavior.floating,
                                                      duration:
                                                          const Duration(
                                                        seconds:
                                                            1,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child:
                                                    Container(
                                                  padding:
                                                      const EdgeInsets
                                                          .all(
                                                    6,
                                                  ),
                                                  decoration:
                                                      BoxDecoration(
                                                    color:
                                                        Colors.redAccent,
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(
                                                      20,
                                                    ),
                                                  ),
                                                  child:
                                                      const Icon(
                                                    Icons
                                                        .add_shopping_cart,
                                                    size:
                                                        16,
                                                    color:
                                                        Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // ==================================================
          // SIGN-IN BANNER
          // ==================================================

          bottomSheet: isLoggedIn
              ? null
              : Container(
                  color:
                      Colors.orangeAccent,
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Sign in for best experience!',
                          style:
                              TextStyle(
                            color:
                                Colors.white,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              Colors.white,
                          foregroundColor:
                              Colors
                                  .orangeAccent,
                        ),
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
                        child:
                            const Text(
                          'Sign In',
                        ),
                      ),
                    ],
                  ),
                ),

          // ==================================================
          // BOTTOM NAVIGATION
          // ==================================================

          bottomNavigationBar:
              BottomNavigationBar(
            currentIndex:
                _selectedIndex,
            onTap:
                _onNavTap,
            selectedItemColor:
                Colors.redAccent,
            unselectedItemColor:
                Colors.grey,
            type:
                BottomNavigationBarType
                    .fixed,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(
                  Icons.home,
                ),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(
                  Icons.category,
                ),
                label: 'Categories',
              ),
              const BottomNavigationBarItem(
                icon: Icon(
                  Icons.video_library,
                ),
                label: 'Videos',
              ),
              BottomNavigationBarItem(
                icon:
                    _buildCartNavIcon(
                  user,
                ),
                label: 'Cart',
              ),
              const BottomNavigationBarItem(
                icon: Icon(
                  Icons.person,
                ),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}

