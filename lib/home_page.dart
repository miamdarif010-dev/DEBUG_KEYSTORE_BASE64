import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_page.dart';
import 'user_profile_page.dart';
import 'add_product_page.dart';
import 'settings_page.dart';
import 'cart_page.dart';
import 'categories_page.dart';
import 'news_feed_page.dart';
import 'product_details_page.dart';
import 'global_notifications_page.dart';

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

  // =========================================================
  // INIT STATE
  // =========================================================

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
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _couponAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // =========================================================
  // CATEGORY MATCH
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
        productData['category']?.toString().trim() ?? '';

    if (productCategory.isEmpty) {
      return false;
    }

    return productCategory.toLowerCase() ==
        selectedCategory.toLowerCase();
  }

  // =========================================================
  // BDT PRICE
  // =========================================================

  double _displayBdtPrice(
    Map<String, dynamic> productData,
  ) {
    final rawPrice =
        productData['price'] is num
            ? (productData['price'] as num).toDouble()
            : 0.0;

    final currency =
        productData['currency']
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
  // FAVORITE REFERENCE
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

  // =========================================================
  // ADD / REMOVE FAVORITE
  // =========================================================

  Future<void> _toggleFavorite({
    required User user,
    required String productId,
    required Map<String, dynamic> productData,
  }) async {
    final favoriteRef = _favoriteReference(
      user.uid,
      productId,
    );

    try {
      final favoriteSnapshot =
          await favoriteRef.get();

      if (favoriteSnapshot.exists) {
        await favoriteRef.delete();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Removed from Favorites',
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        final name =
            productData['name']?.toString() ??
                'Unnamed Product';

        final imageUrl =
            productData['imageUrl']?.toString() ?? '';

        final category =
            productData['category']?.toString() ?? '';

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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Added to Favorites ❤️',
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update Favorites: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // =========================================================
  // OPEN PRODUCT DETAILS
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
  // OPEN GLOBAL NOTIFICATIONS
  // =========================================================

  Future<void> _openGlobalNotifications() async {
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
  // OPEN CAMERA SEARCH
  // =========================================================

  void _openCameraSearch() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Camera search will be available soon.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  // =========================================================
  // OPEN COUPON
  // =========================================================

  void _openCoupon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Coupons will be available soon.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
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
          FirebaseAuth.instance.currentUser;

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
  // OPEN VIDEOS
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
  // OPEN ACCOUNT
  // =========================================================

  void _openAccount(bool isLoggedIn) {
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
  // BUYNOVA BRAND
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
              color: Colors.lightBlueAccent,
            ),
          ),
          TextSpan(
            text: 'v',
            style: TextStyle(
              color: Colors.purpleAccent,
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

  // =========================================================
  // GET COUPON
  // =========================================================

  Widget _buildGetCoupon() {
    return FadeTransition(
      opacity: _couponOpacity,
      child: GestureDetector(
        onTap: _openCoupon,
        child: const Text(
          'Get Coupon',
          style: TextStyle(
            color: Colors.yellowAccent,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance
          .authStateChanges(),
      builder: (
        context,
        authSnapshot,
      ) {
        final user = authSnapshot.data;
        final isLoggedIn = user != null;

        return Scaffold(
          // =================================================
          // DRAWER
          // =================================================

          drawer: Drawer(
            child: SafeArea(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shopping_bag,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'BuyNova',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  ListTile(
                    leading: const Icon(
                      Icons.person_outline,
                    ),
                    title: const Text(
                      'Account',
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _openAccount(
                        isLoggedIn,
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(
                      Icons.home_outlined,
                    ),
                    title: const Text(
                      'Home',
                    ),
                    onTap: () {
                      Navigator.pop(context);

                      setState(() {
                        _selectedIndex = 0;
                      });
                    },
                  ),

                  ListTile(
                    leading: const Icon(
                      Icons.category_outlined,
                    ),
                    title: const Text(
                      'Categories',
                    ),
                    onTap: () async {
                      Navigator.pop(context);

                      final result =
                          await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const CategoriesPage(),
                        ),
                      );

                      if (result != null &&
                          mounted) {
                        final matchIndex =
                            categories.indexOf(
                          result,
                        );

                        if (matchIndex != -1) {
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
                      leading: const Icon(
                        Icons.add_circle_outline,
                      ),
                      title: const Text(
                        'Add Product',
                      ),
                      onTap: () {
                        Navigator.pop(context);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AddProductPage(),
                          ),
                        );
                      },
                    ),

                  ListTile(
                    leading: const Icon(
                      Icons.video_library_outlined,
                    ),
                    title: const Text(
                      'Videos',
                    ),
                    subtitle: const Text(
                      'Watch Reels & Videos',
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _openVideos();
                    },
                  ),

                  ListTile(
                    leading: const Icon(
                      Icons.shopping_cart_outlined,
                    ),
                    title: const Text(
                      'Cart',
                    ),
                    onTap: () {
                      Navigator.pop(context);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const CartPage(),
                        ),
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(
                      Icons.settings_outlined,
                    ),
                    title: const Text(
                      'Settings',
                    ),
                    onTap: () {
                      Navigator.pop(context);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const SettingsPage(),
                        ),
                      );
                    },
                  ),

                  if (isLoggedIn)
                    ListTile(
                      leading: const Icon(
                        Icons.logout,
                      ),
                      title: const Text(
                        'Logout',
                      ),
                      onTap: () async {
                        Navigator.pop(context);

                        await FirebaseAuth
                            .instance
                            .signOut();
                      },
                    ),
                ],
              ),
            ),
          ),

          // =================================================
          // APP BAR
          // =================================================

          appBar: AppBar(
            backgroundColor:
                Colors.redAccent,
            elevation: 0,

            leading: Builder(
              builder: (context) {
                return IconButton(
                  icon: const Icon(
                    Icons.menu,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    Scaffold.of(context)
                        .openDrawer();
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

            // =================================================
            // IMPORTANT:
            // TOP CART REMOVED.
            //
            // Notification is intentionally placed in the
            // right-most position — the position previously
            // occupied by the top Cart icon.
            //
            // The old Notification position is therefore not
            // occupied by another icon.
            // =================================================

            actions: [
              if (user == null)
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                  ),
                  onPressed:
                      _openGlobalNotifications,
                )
              else
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore
                      .instance
                      .collection(
                        'global_notifications',
                      )
                      .where(
                        'active',
                        isEqualTo: true,
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

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore
                          .instance
                          .collection('users')
                          .doc(user.uid)
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

                        int unreadCount = 0;

                        for (final notification
                            in notifications) {
                          if (!readIds.contains(
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
                              icon: const Icon(
                                Icons
                                    .notifications_outlined,
                                color:
                                    Colors.white,
                              ),
                              onPressed:
                                  _openGlobalNotifications,
                            ),

                            if (unreadCount > 0)
                              Positioned(
                                right: 4,
                                top: 4,
                                child: Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  constraints:
                                      const BoxConstraints(
                                    minWidth: 17,
                                    minHeight: 17,
                                  ),
                                  decoration:
                                      const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape
                                        .circle,
                                  ),
                                  child: Text(
                                    unreadCount > 99
                                        ? '99+'
                                        : '$unreadCount',
                                    textAlign:
                                        TextAlign.center,
                                    style:
                                        const TextStyle(
                                      color: Colors
                                          .redAccent,
                                      fontSize: 9,
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

          // =================================================
          // BODY
          // =================================================

          body: Column(
            children: [
              // =================================================
              // SEARCH
              // =================================================

              Container(
                color: Colors.redAccent,
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  12,
                ),
                child: Container(
                  height: 42,
                  decoration:
                      BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      21,
                    ),
                  ),
                  child: TextField(
                    controller:
                        _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery =
                            value.trim()
                                .toLowerCase();
                      });
                    },
                    decoration:
                        InputDecoration(
                      hintText:
                          'Search products...',
                      prefixIcon:
                          const Icon(
                        Icons.search,
                        color: Colors.grey,
                      ),

                      // =================================================
                      // SEARCH CAMERA + CLEAR
                      // =================================================

                      suffixIcon: Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          if (_searchQuery
                              .isNotEmpty)
                            IconButton(
                              icon:
                                  const Icon(
                                Icons.clear,
                                color:
                                    Colors.grey,
                              ),
                              onPressed: () {
                                _searchController
                                    .clear();

                                setState(() {
                                  _searchQuery =
                                      '';
                                });
                              },
                            ),

                          IconButton(
                            icon:
                                const Icon(
                              Icons
                                  .camera_alt_outlined,
                              color:
                                  Colors.grey,
                            ),
                            onPressed:
                                _openCameraSearch,
                          ),
                        ],
                      ),

                      border:
                          InputBorder.none,
                      contentPadding:
                          const EdgeInsets
                              .symmetric(
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ),

              // =================================================
              // CATEGORIES
              // =================================================

              Container(
                height: 58,
                color: Colors.white,
                child: ListView.builder(
                  scrollDirection:
                      Axis.horizontal,
                  physics:
                      const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  itemCount:
                      categories.length,
                  itemBuilder:
                      (context, index) {
                    final isSelected =
                        _selectedCategory ==
                            index;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory =
                              index;
                        });
                      },
                      child:
                          AnimatedContainer(
                        duration:
                            const Duration(
                          milliseconds: 200,
                        ),
                        margin:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 5,
                        ),
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 17,
                          vertical: 8,
                        ),
                        decoration:
                            BoxDecoration(
                          color: isSelected
                              ? Colors.redAccent
                              : Colors.grey
                                  .shade100,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                          border:
                              Border.all(
                            color: isSelected
                                ? Colors
                                    .redAccent
                                : Colors.grey
                                    .shade300,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            categories[index],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors
                                      .black87,
                              fontWeight:
                                  isSelected
                                      ? FontWeight
                                          .bold
                                      : FontWeight
                                          .w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // =================================================
              // PRODUCTS
              // =================================================

              Expanded(
                child:
                    StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection(
                              'products')
                          .snapshots(),

                  builder: (
                    context,
                    snapshot,
                  ) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Failed to load products',
                          style:
                              TextStyle(
                            fontSize: 16,
                            color:
                                Colors.grey,
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
                        snapshot.data?.docs ??
                            [];

                    final filteredDocs =
                        allDocs.where(
                      (doc) {
                        final data =
                            doc.data()
                                as Map<String,
                                    dynamic>;

                        if (!_matchesCategory(
                            data)) {
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
                              TextAlign.center,
                          style:
                              const TextStyle(
                            fontSize: 16,
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
                                  'users')
                              .doc(user.uid)
                              .collection(
                                  'favorites')
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

                        return GridView.builder(
                          padding:
                              const EdgeInsets
                                  .all(8),

                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio:
                                0.75,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),

                          itemCount:
                              filteredDocs.length,

                          itemBuilder:
                              (context, index) {
                            final productDoc =
                                filteredDocs[
                                    index];

                            final data =
                                productDoc.data()
                                    as Map<String,
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
                              elevation: 2,
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
                                onTap: () {
                                  _openProductDetails(
                                    productId:
                                        productId,
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
                                            width: double
                                                .infinity,
                                            decoration:
                                                BoxDecoration(
                                              color: Colors
                                                  .grey[300],
                                            ),
                                            child: imageUrl !=
                                                        null &&
                                                    imageUrl
                                                        .isNotEmpty
                                                ? Image
                                                    .network(
                                                    imageUrl,
                                                    fit: BoxFit
                                                        .cover,
                                                    width:
                                                        double.infinity,
                                                    height:
                                                        double.infinity,
                                                    errorBuilder:
                                                        (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return const Center(
                                                        child:
                                                            Icon(
                                                          Icons
                                                              .image,
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
                                            top: 8,
                                            right: 8,
                                            child:
                                                Material(
                                              color: Colors
                                                  .white,
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
                                                    await Navigator
                                                        .push(
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
                                                        ? Icons
                                                            .favorite
                                                        : Icons
                                                            .favorite_border,
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
                                                TextOverflow
                                                    .ellipsis,
                                          ),

                                          const SizedBox(
                                            height: 4,
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
                                                      TextOverflow
                                                          .ellipsis,
                                                ),
                                              ),

                                              const SizedBox(
                                                width:
                                                    5,
                                              ),

                                              InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  20,
                                                ),
                                                onTap:
                                                    () async {
                                                  final currentUser =
                                                      user;

                                                  if (currentUser ==
                                                      null) {
                                                    await Navigator
                                                        .push(
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
                                                          SnackBarBehavior
                                                              .floating,
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
                                                      const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  decoration:
                                                      BoxDecoration(
                                                    color:
                                                        Colors.redAccent,
                                                    borderRadius:
                                                        BorderRadius.circular(
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

          // =================================================
          // SIGN IN BANNER
          // =================================================

          bottomSheet: isLoggedIn
              ? null
              : Container(
                  color: Colors.orangeAccent,
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
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style:
                            ElevatedButton.styleFrom(
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
                              builder: (context) =>
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

          // =================================================
          // BOTTOM NAVIGATION
          // =================================================

          bottomNavigationBar:
              BottomNavigationBar(
            currentIndex:
                _selectedIndex,
            onTap: _onNavTap,
            selectedItemColor:
                Colors.redAccent,
            unselectedItemColor:
                Colors.grey,
            type:
                BottomNavigationBarType.fixed,

            items: const [
              BottomNavigationBarItem(
                icon:
                    Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon:
                    Icon(Icons.category),
                label: 'Categories',
              ),
              BottomNavigationBarItem(
                icon: Icon(
                  Icons.video_library,
                ),
                label: 'Videos',
              ),
              BottomNavigationBarItem(
                icon: Icon(
                  Icons
                      .shopping_cart_outlined,
                ),
                label: 'Cart',
              ),
              BottomNavigationBarItem(
                icon:
                    Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
