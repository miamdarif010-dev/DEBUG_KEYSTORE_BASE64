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
import 'category_service.dart';
import 'news_feed_page.dart';
import 'product_details_page.dart';
import 'global_notifications_page.dart';
import 'coupon_page.dart';
import 'price_discount.dart';
import 'verify_code_page.dart';
import 'product_share.dart';
import 'native_ad_card.dart';
import 'invite_page.dart';

part 'home_page_image_search.dart';
part 'home_page_drawer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  int _selectedCategory = 0;

  // Search bar + categories + slider hide when scrolling down,
  // and come back when scrolling up.
  bool _showHeader = true;

  // While the header animates, the list size changes and fires fake scroll
  // events. We ignore scroll events until this time, so the header does not
  // jump back (feedback loop).
  DateTime _headerLockUntil = DateTime.fromMillisecondsSinceEpoch(0);

  // Distance scrolled in the same direction (to avoid tiny-move flicker).
  double _scrollAcc = 0;

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  late AnimationController _couponAnimationController;
  late Animation<double> _couponOpacity;

  // TOP AUTO SLIDER (Admin products 1-10)
  Timer? _productSliderTimer;

  final ScrollController _productSliderController = ScrollController();

  int _productSliderIndex = 0;
  int _productSliderCount = 0;

  // FEED LAYOUT
  // Admin's first 10 products appear in the top slider.
  // Every 8 ordinary feed products, show the next admin slider.
  // Ads appear after 6 ordinary products, then every 8 more.
  static const int _sliderSize = 10;
  static const int _feedSliderInterval = 8;

  // AD SETTINGS (controlled by the Admin from Firestore: settings/ads).
  // These are the defaults used until the Admin's values arrive.
  bool _adsEnabled = true;
  int _firstAdPosition = 6;
  int _adInterval = 8;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _adSettingsSubscription;

  // LOOK
  static const LinearGradient _headerGradient = LinearGradient(
    colors: [Color(0xFFFF5252), Color(0xFFFF7A5C)],
  );

  static const Color _pageBackground = Color(0xFFF6F6F8);

  // CATEGORIES (managed by the Admin, loaded from Firestore).
  // "All" is always first. The default list is shown until the
  // Firestore list arrives, so the bar is never empty.
  List<String> categories = [
    CategoryService.allName,
    ...CategoryService.defaults.map((d) => d['name']!),
  ];

  // category name (lowercase) -> item with the icon the Admin chose
  Map<String, CategoryItem> _categoryItemMap = {};

  StreamSubscription<List<CategoryItem>>? _categorySubscription;

  @override
  void initState() {
    super.initState();

    // LOAD CATEGORIES FROM ADMIN
    _categorySubscription = CategoryService.stream().listen(
      (items) {
        if (!mounted) return;

        final selectedName = _selectedCategory < categories.length
            ? categories[_selectedCategory]
            : CategoryService.allName;

        setState(() {
          _categoryItemMap = {
            for (final item in items) item.name.toLowerCase(): item,
          };

          categories = [
            CategoryService.allName,
            ...items.map((item) => item.name),
          ];

          final newIndex = categories.indexOf(selectedName);

          _selectedCategory = newIndex == -1 ? 0 : newIndex;
        });
      },
      onError: (_) {
        // Keep the current list if categories cannot load.
      },
    );

    // LOAD AD SETTINGS FROM ADMIN
    _adSettingsSubscription = FirebaseFirestore.instance
        .collection('settings')
        .doc('ads')
        .snapshots()
        .listen(
      (doc) {
        if (!mounted) return;

        final d = doc.data();

        // No settings document yet -> keep the defaults.
        if (d == null) return;

        int readInt(String key, int fallback) {
          final v = d[key];
          final n = v is num ? v.toInt() : fallback;
          return n < 1 ? 1 : (n > 100 ? 100 : n);
        }

        setState(() {
          _adsEnabled = d['enabled'] != false;
          _firstAdPosition = readInt('firstAdPosition', 6);
          _adInterval = readInt('interval', 8);
        });
      },
      onError: (_) {
        // Keep the current settings if they cannot load.
      },
    );

    _couponAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _couponOpacity = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(
        parent: _couponAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _startProductSliderTimer();

    // New email + password accounts must enter the email code first.
    _checkEmailCode();
  }

  Future<void> _checkEmailCode() async {
    final current = FirebaseAuth.instance.currentUser;

    if (current == null || emailCodeOkUid == current.uid) {
      return;
    }

    final needs = await needsEmailCode(current);

    if (!mounted) return;

    if (needs) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const VerifyCodePage()),
      );
    } else {
      emailCodeOkUid = current.uid;
    }
  }

  void _startProductSliderTimer() {
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

        final targetOffset = _productSliderIndex * 106.0;

        final maxScrollExtent =
            _productSliderController.position.maxScrollExtent;

        final safeOffset =
            targetOffset > maxScrollExtent ? maxScrollExtent : targetOffset;

        _productSliderController.animateTo(
          safeOffset,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  @override
  void dispose() {
    _categorySubscription?.cancel();
    _adSettingsSubscription?.cancel();

    _productSliderTimer?.cancel();
    _productSliderController.dispose();

    _couponAnimationController.dispose();
    _searchController.dispose();

    super.dispose();
  }

  // =========================================================
  // OWN PRODUCT (nobody sees / buys their own product)
  // =========================================================

  bool _isOwnProduct(Map<String, dynamic> d) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return false;

    return d['sellerId'] == uid ||
        d['ownerId'] == uid ||
        d['entrepreneurUid'] == uid ||
        d['supplierSellerId'] == uid;
  }

  // =========================================================
  // CATEGORY
  // =========================================================

  bool _matchesCategory(Map<String, dynamic> productData) {
    final selectedCategory = categories[_selectedCategory];

    if (selectedCategory == 'All') {
      return true;
    }

    final productCategory = productData['category']?.toString().trim() ?? '';

    if (productCategory.isEmpty) {
      return false;
    }

    return productCategory.toLowerCase() == selectedCategory.toLowerCase();
  }

  IconData _categoryIcon(String category) {
    final lower = category.toLowerCase();

    if (lower == 'all') {
      return Icons.apps_rounded;
    }

    // Icon chosen by the Admin
    final adminItem = _categoryItemMap[lower];

    if (adminItem != null) {
      return adminItem.icon;
    }

    return Icons.category;
  }

  String? _getCategoryImageUrl(
    String category,
    List<QueryDocumentSnapshot> products,
  ) {
    final normalizedCategory = category.trim().toLowerCase();

    for (final product in products) {
      final data = product.data() as Map<String, dynamic>;

      final imageUrl = data['imageUrl']?.toString().trim() ?? '';

      if (imageUrl.isEmpty) {
        continue;
      }

      final productCategory =
          data['category']?.toString().trim().toLowerCase() ?? '';

      if (normalizedCategory == 'all' || productCategory == normalizedCategory) {
        return imageUrl;
      }
    }

    return null;
  }

  // =========================================================
  // PRICE
  // =========================================================

  double _displayBdtPrice(Map<String, dynamic> productData) {
    final rawPrice = productData['price'] is num
        ? (productData['price'] as num).toDouble()
        : 0.0;

    final currency = productData['currency']?.toString().trim().toUpperCase();

    if (currency == 'BDT') {
      return rawPrice;
    }

    return rawPrice * 0.09;
  }

  /// Price before discount in BDT (0 when the product has no discount).
  double _displayOriginalBdtPrice(Map<String, dynamic> productData) {
    final value = productData['originalPrice'];

    final raw = value is num ? value.toDouble() : 0.0;

    if (raw <= 0) return 0;

    final currency = productData['currency']?.toString().trim().toUpperCase();

    return currency == 'BDT' ? raw : raw * 0.09;
  }

  String _formatBdtPrice(Map<String, dynamic> productData) {
    final bdtPrice = _displayBdtPrice(productData);

    return '৳${bdtPrice.toStringAsFixed(2)}';
  }

  /// Discount in percent (0 when the product has no discount).
  int _discountPercent(Map<String, dynamic> productData) {
    final original = _displayOriginalBdtPrice(productData);
    final current = _displayBdtPrice(productData);

    if (original <= 0 || current <= 0 || original <= current) return 0;

    return (((original - current) / original) * 100).round();
  }

  Widget _discountBadge(int percent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        '-$percent%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // =========================================================
  // FAVORITES
  // =========================================================

  DocumentReference<Map<String, dynamic>> _favoriteReference(
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
    final favoriteRef = _favoriteReference(user.uid, productId);

    try {
      final favoriteSnapshot = await favoriteRef.get();

      if (favoriteSnapshot.exists) {
        await favoriteRef.delete();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from Favorites'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        final name = productData['name']?.toString() ?? 'Unnamed Product';

        final imageUrl = productData['imageUrl']?.toString() ?? '';

        final category = productData['category']?.toString() ?? '';

        final price = _displayBdtPrice(productData);

        await favoriteRef.set({
          'productId': productId,
          'productName': name,
          'productImageUrl': imageUrl,
          'category': category,
          'price': price,
          'currency': 'BDT',
          'currencySymbol': '৳',
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

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
          content: Text('Could not update Favorites: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // =========================================================
  // SHARE
  // =========================================================

  Future<void> _shareProduct({
    required String productId,
    required Map<String, dynamic> productData,
  }) async {
    try {
      await ProductShare.share(
        productId: productId,
        product: productData,
        name: productData['name']?.toString() ?? 'Unnamed Product',
        formattedPrice: _formatBdtPrice(productData),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Share failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
        builder: (context) => ProductDetailsPage(
          productId: productId,
          product: product,
        ),
      ),
    );
  }

  // =========================================================
  // GLOBAL NOTIFICATIONS
  // =========================================================

  Future<void> _openGlobalNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GlobalNotificationsPage(),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  // =========================================================
  // COUPON
  // =========================================================

  void _openCoupon() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CouponPage()),
    );
  }

  // =========================================================
  // BOTTOM NAVIGATION
  // =========================================================

  Future<void> _onNavTap(int index) async {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      return;
    }

    if (index == 1) {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const CategoriesPage()),
      );

      if (result != null && mounted) {
        final matchIndex = categories.indexOf(result);

        if (matchIndex != -1) {
          setState(() {
            _selectedCategory = matchIndex;
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
        MaterialPageRoute(builder: (context) => const NewsFeedPage()),
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
        MaterialPageRoute(builder: (context) => const CartPage()),
      );

      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
      }

      return;
    }

    if (index == 4) {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserProfilePage()),
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
      MaterialPageRoute(builder: (context) => const NewsFeedPage()),
    );
  }

  // =========================================================
  // ACCOUNT
  // =========================================================

  void _openAccount(bool isLoggedIn) {
    if (isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UserProfilePage()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
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
          fontWeight: FontWeight.w900,
          letterSpacing: -0.4,
        ),
        children: [
          TextSpan(text: 'B', style: TextStyle(color: Colors.white)),
          TextSpan(text: 'u', style: TextStyle(color: Colors.yellow)),
          TextSpan(text: 'y', style: TextStyle(color: Colors.orange)),
          TextSpan(text: 'N', style: TextStyle(color: Colors.greenAccent)),
          TextSpan(
            text: 'o',
            style: TextStyle(color: Colors.lightBlueAccent),
          ),
          TextSpan(text: 'v', style: TextStyle(color: Colors.white)),
          TextSpan(text: 'a', style: TextStyle(color: Colors.cyanAccent)),
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
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.yellowAccent.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: Colors.yellowAccent.withValues(alpha: 0.75),
              width: 1,
            ),
          ),
          child: const Text(
            'Get Coupon',
            style: TextStyle(
              color: Colors.yellowAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // CART BADGE
  // =========================================================

  Widget _buildCartNavIcon(User? user) {
    if (user == null) {
      return const Icon(Icons.shopping_cart_outlined);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .snapshots(),
      builder: (context, snapshot) {
        int cartCount = 0;

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data();

            final quantity = data['quantity'];

            if (quantity is num) {
              cartCount += quantity.toInt();
            } else {
              cartCount += 1;
            }
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.shopping_cart_outlined),
            if (cartCount > 0)
              Positioned(
                right: -9,
                top: -9,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    cartCount > 99 ? '99+' : '$cartCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
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
    required List<QueryDocumentSnapshot> products,
  }) {
    final isSelected = _selectedCategory == index;

    final imageUrl = _getCategoryImageUrl(category, products);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = index;
        });
      },
      child: SizedBox(
        width: 78,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade100,
                border: Border.all(
                  color: isSelected ? Colors.redAccent : Colors.grey.shade200,
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? Colors.redAccent.withValues(alpha: 0.28)
                        : Colors.black.withValues(alpha: 0.06),
                    blurRadius: isSelected ? 9 : 5,
                    spreadRadius: isSelected ? 1 : 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            _categoryIcon(category),
                            color: isSelected
                                ? Colors.redAccent
                                : Colors.grey.shade600,
                            size: 28,
                          );
                        },
                      )
                    : Icon(
                        _categoryIcon(category),
                        color: isSelected
                            ? Colors.redAccent
                            : Colors.grey.shade600,
                        size: 28,
                      ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.redAccent : Colors.black87,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 3,
              width: isSelected ? 24 : 0,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // ADMIN PICKS (products chosen by the Admin only)
  // =========================================================

  /// Products the Admin added to `homeSlider`, in the order the
  /// Admin added them. Deleted products and the user's own products
  /// are skipped.
  List<QueryDocumentSnapshot> _adminPicks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sliderDocs,
    List<QueryDocumentSnapshot> allDocs,
  ) {
    final sorted = List.of(sliderDocs)
      ..sort((a, b) {
        final oa = a.data()['order'];
        final ob = b.data()['order'];

        final na = oa is num ? oa.toInt() : 0;
        final nb = ob is num ? ob.toInt() : 0;

        return na.compareTo(nb);
      });

    final byId = <String, QueryDocumentSnapshot>{
      for (final d in allDocs) d.id: d,
    };

    final result = <QueryDocumentSnapshot>[];

    for (final s in sorted) {
      final doc = byId[s.id];

      // Skip products that were deleted.
      if (doc == null) continue;

      // Nobody sees their own product.
      if (_isOwnProduct(doc.data() as Map<String, dynamic>)) continue;

      result.add(doc);
    }

    return result;
  }

  /// One small product card, used by the top slider and the feed sliders.
  /// Total width on screen = width + 8 (right margin).
  Widget _sliderCard({
    required QueryDocumentSnapshot doc,
    required double width,
    required double imageHeight,
  }) {
    final data = doc.data() as Map<String, dynamic>;

    final name = data['name']?.toString() ?? 'Unnamed Product';

    final imageUrl = data['imageUrl']?.toString().trim() ?? '';

    final discount = _discountPercent(data);

    final placeholder = Container(
      color: Colors.grey.shade100,
      child: const Icon(Icons.image_outlined, color: Colors.grey),
    );

    return GestureDetector(
      onTap: () {
        _openProductDetails(productId: doc.id, product: data);
      },
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return placeholder;
                          },
                        )
                      : placeholder,
                  if (discount > 0)
                    Positioned(
                      top: 5,
                      left: 5,
                      child: _discountBadge(discount),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                _formatBdtPrice(data),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Top slider: auto-scrolling, shows Admin products 1-10.
  Widget _buildSliderSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('homeSlider').snapshots(),
      builder: (context, sliderSnapshot) {
        if (sliderSnapshot.hasError ||
            (sliderSnapshot.data?.docs ?? []).isEmpty) {
          _productSliderCount = 0;
          return const SizedBox.shrink();
        }

        final sliderDocs = sliderSnapshot.data!.docs;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('products').snapshots(),
          builder: (context, productSnapshot) {
            final picks = _adminPicks(
              sliderDocs,
              productSnapshot.data?.docs ?? <QueryDocumentSnapshot>[],
            ).take(_sliderSize).toList();

            return _buildProductAutoSlider(picks);
          },
        );
      },
    );
  }

  Widget _buildProductAutoSlider(List<QueryDocumentSnapshot> sliderProducts) {
    _productSliderCount = sliderProducts.length;

    if (_productSliderCount == 0) {
      return const SizedBox.shrink();
    }

    if (_productSliderIndex >= _productSliderCount) {
      _productSliderIndex = 0;
    }

    return Container(
      height: 122,
      color: Colors.white,
      child: ListView.builder(
        controller: _productSliderController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        itemCount: sliderProducts.length,
        itemBuilder: (context, index) {
          // width 98 + margin 8 = 106, the step used by the auto-scroll timer.
          return _sliderCard(
            doc: sliderProducts[index],
            width: 98,
            imageHeight: 72,
          );
        },
      ),
    );
  }

  /// Horizontal slider shown inside the product feed.
  /// It has no shared controller, so it can appear many times.
  Widget _buildAdminPickSlider(List<QueryDocumentSnapshot> picks) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      height: 172,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFEFEA), Colors.white],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.deepOrange,
                  size: 19,
                ),
                const SizedBox(width: 4),
                const Text(
                  'বাছাই করা পণ্য',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: picks.length,
              itemBuilder: (context, index) {
                return _sliderCard(
                  doc: picks[index],
                  width: 100,
                  imageHeight: 82,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // FEED: products + Admin slider + native ads
  // =========================================================

  List<Widget> _buildFeedSlivers({
    required User? user,
    required List<QueryDocumentSnapshot> docs,
    required Set<String> favoriteIds,
    required List<QueryDocumentSnapshot> picks,
  }) {
    final slivers = <Widget>[];

    var start = 0;
    // When the Admin turns ads off, the first ad position is unreachable.
    var nextAdAt = _adsEnabled ? _firstAdPosition : 1 << 30;
    var nextSliderAt = _feedSliderInterval;
    var adNo = 0;

    while (start < docs.length) {
      // Stop at the next ad, slider, or end of the product list.
      var end = docs.length;

      if (nextAdAt > start && nextAdAt < end) {
        end = nextAdAt;
      }

      if (nextSliderAt > start && nextSliderAt < end) {
        end = nextSliderAt;
      }

      // Ordinary products only. Ads and sliders never count as products.
      final from = start;

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          sliver: SliverGrid(
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.70,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final productDoc = docs[from + i];
                final data =
                    productDoc.data() as Map<String, dynamic>;

                return _buildProductCard(
                  user: user,
                  productId: productDoc.id,
                  data: data,
                  isFavorite: favoriteIds.contains(productDoc.id),
                );
              },
              childCount: end - from,
            ),
          ),
        ),
      );

      start = end;

      // Insert an ad after ordinary products 6, 14, 22, 30...
      // Do not append an ad after the final ordinary product.
      if (start == nextAdAt) {
        if (start < docs.length) {
          slivers.add(
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: NativeAdCard(
                    key: ValueKey('native_ad_$adNo'),
                    productStyle: adNo.isOdd,
                  ),
                ),
              ),
            ),
          );

          adNo++;
        }

        nextAdAt += _adInterval;
      }

      // Insert a feed slider after ordinary products 8, 16, 24...
      // The top slider uses picks 0-9, so feed sliders start at index 10.
      if (start == nextSliderAt) {
        final sliderStart = (start ~/ _feedSliderInterval) * _sliderSize;

        final sliderEnd = sliderStart + _sliderSize < picks.length
            ? sliderStart + _sliderSize
            : picks.length;

        if (sliderStart < picks.length) {
          slivers.add(
            SliverToBoxAdapter(
              child: _buildAdminPickSlider(
                picks.sublist(sliderStart, sliderEnd),
              ),
            ),
          );
        }

        nextSliderAt += _feedSliderInterval;
      }
    }

    // Small space under the last product.
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));

    return slivers;
  }

  // =========================================================
  // NOTIFICATION BELL
  // =========================================================

  Widget _buildNotificationAction(User? user) {
    if (user == null) {
      return IconButton(
        icon: const Icon(Icons.notifications_outlined, color: Colors.white),
        onPressed: _openGlobalNotifications,
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('global_notifications')
          .where('active', isEqualTo: true)
          .snapshots(),
      builder: (context, notificationSnapshot) {
        final notifications = notificationSnapshot.data?.docs ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('globalNotificationReads')
              .snapshots(),
          builder: (context, readSnapshot) {
            final readIds = <String>{};

            for (final readDoc in readSnapshot.data?.docs ?? []) {
              readIds.add(readDoc.id);
            }

            int unreadCount = 0;

            for (final notification in notifications) {
              if (!readIds.contains(notification.id)) {
                unreadCount++;
              }
            }

            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                  ),
                  onPressed: _openGlobalNotifications,
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 17,
                        minHeight: 17,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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

  Widget _buildProductCard({
    required User? user,
    required String productId,
    required Map<String, dynamic> data,
    required bool isFavorite,
  }) {
    final name = data['name']?.toString() ?? 'Unnamed Product';

    final imageUrl = data['imageUrl']?.toString();

    final discount = _discountPercent(data);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: () {
            _openProductDetails(productId: productId, product: data);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.grey[200]),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(
                                    Icons.image,
                                    size: 50,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            )
                          : const Center(
                              child: Icon(
                                Icons.image,
                                size: 50,
                                color: Colors.grey,
                              ),
                            ),
                    ),

                    // SOFT SHADE AT THE BOTTOM OF THE IMAGE
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 36,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.10),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // DISCOUNT BADGE
                    if (discount > 0)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _discountBadge(discount),
                      ),

                    // FAVORITE
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () async {
                            final currentUser = user;

                            if (currentUser == null) {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginPage(),
                                ),
                              );
                              return;
                            }

                            await _toggleFavorite(
                              user: currentUser,
                              productId: productId,
                              productData: data,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(7),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color:
                                  isFavorite ? Colors.redAccent : Colors.grey,
                              size: 21,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // SHARE (under the favorite button)
                    Positioned(
                      top: 48,
                      right: 8,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            _shareProduct(
                              productId: productId,
                              productData: data,
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(
                              Icons.share_outlined,
                              color: Colors.grey,
                              size: 21,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: PriceTag(
                            price: _displayBdtPrice(data),
                            originalPrice: _displayOriginalBdtPrice(data) > 0
                                ? _displayOriginalBdtPrice(data)
                                : null,
                            fontSize: 15,
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(width: 5),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            // Cart icon opens Product Details
                            _openProductDetails(
                              productId: productId,
                              product: data,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: _headerGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.redAccent.withValues(alpha: 0.30),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add_shopping_cart,
                              size: 16,
                              color: Colors.white,
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
      ),
    );
  }

  // =========================================================
  // SEARCH BAR
  // =========================================================

  Widget _buildSearchBar() {
    return Container(
      decoration: const BoxDecoration(gradient: _headerGradient),
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 9,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onChanged: (value) {
            setState(() {
              _searchQuery = value.trim().toLowerCase();
            });
          },
          decoration: InputDecoration(
            hintText: 'Search products...',
            hintStyle: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 4, right: 2),
              child: Icon(
                Icons.search_rounded,
                color: Colors.redAccent,
                size: 24,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 46,
              minHeight: 50,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear',
                    splashRadius: 20,
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();

                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
                Container(
                  height: 26,
                  width: 1,
                  color: Colors.grey.shade300,
                ),
                IconButton(
                  tooltip: 'Search by camera',
                  splashRadius: 20,
                  icon: Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.grey.shade700,
                    size: 21,
                  ),
                  onPressed: _openCameraSearch,
                ),
                const SizedBox(width: 4),
              ],
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 50,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 4,
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // CATEGORIES BAR
  // =========================================================

  Widget _buildCategoriesBar() {
    return SizedBox(
      height: 108,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, categorySnapshot) {
          final categoryProducts = (categorySnapshot.data?.docs ?? [])
              .where(
                (d) => !_isOwnProduct(d.data() as Map<String, dynamic>),
              )
              .toList();

          return Container(
            color: Colors.white,
            padding: const EdgeInsets.only(top: 4),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                return _buildCategoryItem(
                  category: categories[index],
                  index: index,
                  products: categoryProducts,
                );
              },
            ),
          );
        },
      ),
    );
  }

  // =========================================================
  // SCROLL: hide / show the header
  // =========================================================
  //
  // Why the old version jumped back: hiding the header changes the list
  // height, which fires extra scroll notifications, which toggled the header
  // again (a loop). Fixes:
  //   1. react only to real finger drags (dragDetails != null)
  //   2. lock for 400 ms after each toggle (animation time)
  //   3. need 40 px of movement in one direction before toggling

  bool _onProductScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;

    if (n is! ScrollUpdateNotification || n.dragDetails == null) {
      return false;
    }

    // Ignore the layout-change shake while the header is animating.
    if (DateTime.now().isBefore(_headerLockUntil)) return false;

    final delta = n.scrollDelta ?? 0;
    final pixels = n.metrics.pixels;

    // Distance in the same direction; reset when direction changes.
    if (delta != 0 && (_scrollAcc > 0) != (delta > 0)) {
      _scrollAcc = 0;
    }

    _scrollAcc += delta;

    void setHeader(bool show) {
      if (_showHeader == show) return;

      _headerLockUntil = DateTime.now().add(const Duration(milliseconds: 400));
      _scrollAcc = 0;

      setState(() => _showHeader = show);
    }

    if (pixels <= 0) {
      setHeader(true);
    } else if (_scrollAcc > 40 && pixels > 120) {
      // scrolling down -> hide, more room for products
      setHeader(false);
    } else if (_scrollAcc < -40) {
      // scrolling up -> show
      setHeader(true);
    }

    return false;
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        final isLoggedIn = user != null;

        return Scaffold(
          backgroundColor: _pageBackground,

          // SIDE MENU (see home_page_drawer.dart)
          drawer: _HomeDrawer(
            isLoggedIn: isLoggedIn,
            onAccount: () => _openAccount(isLoggedIn),
            onHome: () => setState(() => _selectedIndex = 0),
            onVideos: _openVideos,
            onCategorySelected: (result) {
              final i = categories.indexOf(result);

              if (i != -1) setState(() => _selectedCategory = i);
            },
          ),

          // APP BAR
          appBar: AppBar(
            backgroundColor: Colors.redAccent,
            elevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(gradient: _headerGradient),
            ),
            leading: Builder(
              builder: (context) {
                return IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                );
              },
            ),
            titleSpacing: 0,
            title: Row(
              children: [
                _buildBuyNovaLogo(),
                const SizedBox(width: 10),
                _buildGetCoupon(),
              ],
            ),
            actions: [_buildNotificationAction(user)],
          ),

          // BODY
          body: Column(
            children: [
              // HEADER: search + categories + slider.
              // Slides up when scrolling down, back when scrolling up.
              ClipRect(
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  heightFactor: _showHeader ? 1.0 : 0.0,
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSearchBar(),
                        _buildCategoriesBar(),
                        _buildSliderSection(),
                      ],
                    ),
                  ),
                ),
              ),

              // PRODUCTS
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('products')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Failed to load products',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _SkeletonGrid();
                    }

                    final allDocs = snapshot.data?.docs ?? [];

                    final filteredDocs = allDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      // Nobody sees their own product.
                      if (_isOwnProduct(data)) {
                        return false;
                      }

                      if (!_matchesCategory(data)) {
                        return false;
                      }

                      if (_searchQuery.isEmpty) {
                        return true;
                      }

                      final productName =
                          data['name']?.toString().toLowerCase() ?? '';

                      return productName.contains(_searchQuery);
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return Center(
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'No products found for "$_searchQuery"'
                              : _selectedCategory == 0
                                  ? 'No products found yet'
                                  : 'No products found in ${categories[_selectedCategory]}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: user == null
                          ? null
                          : FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('favorites')
                              .snapshots(),
                      builder: (context, favoriteSnapshot) {
                        final favoriteIds = <String>{};

                        for (final favoriteDoc
                            in favoriteSnapshot.data?.docs ?? []) {
                          favoriteIds.add(favoriteDoc.id);
                        }

                        // Admin-chosen products (homeSlider collection).
                        return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('homeSlider')
                              .snapshots(),
                          builder: (context, sliderSnapshot) {
                            final picks = _adminPicks(
                              sliderSnapshot.data?.docs ?? [],
                              allDocs,
                            );

                            return NotificationListener<ScrollNotification>(
                              onNotification: _onProductScroll,
                              child: CustomScrollView(
                                slivers: _buildFeedSlivers(
                                  user: user,
                                  docs: filteredDocs,
                                  favoriteIds: favoriteIds,
                                  picks: picks,
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

          // SIGN-IN BANNER
          bottomSheet: isLoggedIn
              ? null
              : Container(
                  color: Colors.orangeAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Sign in for best experience!',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.orangeAccent,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                          );
                        },
                        child: const Text('Sign In'),
                      ),
                    ],
                  ),
                ),

          // BOTTOM NAVIGATION
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onNavTap,
            selectedItemColor: Colors.redAccent,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.category),
                label: 'Categories',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.video_library),
                label: 'Videos',
              ),
              BottomNavigationBarItem(
                icon: _buildCartNavIcon(user),
                label: 'Cart',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===================================================================
// LOADING SKELETON (grey pulsing cards while products load)
// ===================================================================

class _SkeletonGrid extends StatefulWidget {
  const _SkeletonGrid();

  @override
  State<_SkeletonGrid> createState() => _SkeletonGridState();
}

class _SkeletonGridState extends State<_SkeletonGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: 0.45,
    end: 1.0,
  ).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _bar(double width) {
    return Container(
      height: 11,
      width: width,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.70,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Container(color: Colors.grey.shade200)),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bar(110),
                      const SizedBox(height: 8),
                      _bar(60),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
