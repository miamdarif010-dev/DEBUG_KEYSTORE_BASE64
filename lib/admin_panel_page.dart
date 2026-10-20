import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_coupon_page.dart';
import 'admin_wallet_page.dart';
import 'admin_slider_products_page.dart';
import 'admin_categories_page.dart';

// The big admin panel is split into part files.
// They share this file's private members (_db, _toDouble, ...).
part 'admin_monetization_part.dart';
part 'admin_users_part.dart';
part 'admin_requests_part.dart';
part 'admin_catalog_part.dart';
part 'admin_helpers_part.dart';
part 'admin_section_page_part.dart';

const String kAdminEmail = 'miamdarif010@gmail.com';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  bool _checkingAuth = true;
  bool _isAuthorized = false;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _monetizationPath =
      'platformSettings/monetization';

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;

    final authorized = user != null &&
        (user.email ?? '').toLowerCase() == kAdminEmail.toLowerCase();

    if (!mounted) return;

    setState(() {
      _checkingAuth = false;
      _isAuthorized = authorized;
    });
  }

  // ============================================================
  // SEQUENTIAL CODE GENERATION
  // ============================================================

  Future<String> _generateSequentialSellerCode() async {
    final counterRef = _db.collection('counters').doc('sellerCounter');

    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      final current = (snapshot.data()?['value'] as num?)?.toInt() ?? 0;
      final next = current + 1;

      transaction.set(
        counterRef,
        {'value': next},
        SetOptions(merge: true),
      );

      return 'SELL-${next.toString().padLeft(6, '0')}';
    });
  }

  Future<String> _generateSequentialEntrepreneurCode() async {
    final counterRef =
        _db.collection('counters').doc('entrepreneurCounter');

    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      final current = (snapshot.data()?['value'] as num?)?.toInt() ?? 0;
      final next = current + 1;

      transaction.set(
        counterRef,
        {'value': next},
        SetOptions(merge: true),
      );

      return 'ENT-${next.toString().padLeft(6, '0')}';
    });
  }

  // ============================================================
  // OPEN SECTION
  // ============================================================

  void _openSection({
    required String title,
    required Widget page,
    Stream<QuerySnapshot<Map<String, dynamic>>>? notificationStream,
    String notificationLabel = 'Items',
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AdminSectionPage(
          title: title,
          notificationStream: notificationStream,
          notificationLabel: notificationLabel,
          child: page,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_checkingAuth) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 70,
                  color: Colors.red,
                ),
                SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'You do not have permission to access the Admin Panel.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Panel',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _dashboard(),
    );
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _dashboard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('users').snapshots(),
      builder: (context, userSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _db.collection('products').snapshots(),
          builder: (context, productSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db.collection('orders').snapshots(),
              builder: (context, orderSnapshot) {
                final users = userSnapshot.data?.docs ?? [];
                final products = productSnapshot.data?.docs ?? [];
                final orders = orderSnapshot.data?.docs ?? [];

                final sellers = users.where(
                  (doc) =>
                      (doc.data()['sellerStatus'] ?? '') == 'approved',
                ).length;

                final entrepreneurs = users.where(
                  (doc) =>
                      (doc.data()['entrepreneurStatus'] ?? '') ==
                      'approved',
                ).length;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _dashboardHeader(),
                      const SizedBox(height: 18),

                      const Text(
                        'Management',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      _adminMenuBox(
                        icon: Icons.people_alt_outlined,
                        title: 'Users / Buyers',
                        subtitle: '${users.length} users',
                        onTap: () {
                          _openSection(
                            title: 'Users / Buyers',
                            notificationStream:
                                _db.collection('users').snapshots(),
                            notificationLabel: 'Buyers / Users',
                            page: _usersTab(),
                          );
                        },
                      ),

                      _adminMenuBox(
                        icon: Icons.storefront_outlined,
                        title: 'Sellers',
                        subtitle: '$sellers approved sellers',
                        onTap: () {
                          _openSection(
                            title: 'Sellers',
                            notificationStream: _db
                                .collection('users')
                                .where(
                                  'sellerStatus',
                                  isEqualTo: 'approved',
                                )
                                .snapshots(),
                            notificationLabel: 'Sellers',
                            page: _sellersTab(),
                          );
                        },
                      ),

                      _adminMenuBox(
                        icon: Icons.person_add_alt_1_outlined,
                        title: 'Resellers / Entrepreneurs',
                        subtitle:
                            '$entrepreneurs approved entrepreneurs',
                        onTap: () {
                          _openSection(
                            title: 'Resellers / Entrepreneurs',
                            notificationStream: _db
                                .collection('users')
                                .where(
                                  'entrepreneurStatus',
                                  isEqualTo: 'approved',
                                )
                                .snapshots(),
                            notificationLabel: 'Entrepreneurs',
                            page: _resellersTab(),
                          );
                        },
                      ),

                      _adminMenuBox(
                        icon: Icons.inventory_2_outlined,
                        title: 'Products',
                        subtitle: '${products.length} seller products',
                        onTap: () {
                          _openSection(
                            title: 'Products',
                            notificationStream:
                                _db.collection('products').snapshots(),
                            notificationLabel: 'Products',
                            page: _productsTab(),
                          );
                        },
                      ),

                      _adminMenuBox(
                        icon: Icons.pending_actions_outlined,
                        title: 'Seller Requests',
                        subtitle: 'Pending seller applications',
                        onTap: () {
                          _openSection(
                            title: 'Seller Requests',
                            notificationStream: _db
                                .collection('users')
                                .where(
                                  'sellerStatus',
                                  isEqualTo: 'pending',
                                )
                                .snapshots(),
                            notificationLabel:
                                'Pending Seller Requests',
                            page: _sellerRequestsTab(),
                          );
                        },
                      ),

                      _adminMenuBox(
                        icon: Icons.person_add_alt_1_outlined,
                        title: 'Entrepreneur Requests',
                        subtitle:
                            'Pending entrepreneur applications',
                        onTap: () {
                          _openSection(
                            title: 'Entrepreneur Requests',
                            notificationStream: _db
                                .collection('users')
                                .where(
                                  'entrepreneurStatus',
                                  isEqualTo: 'pending',
                                )
                                .snapshots(),
                            notificationLabel:
                                'Pending Entrepreneur Requests',
                            page: _entrepreneurRequestsTab(),
                          );
                        },
                      ),

                      _adminMenuBox(
                        icon: Icons.sync_alt_outlined,
                        title: 'Relationships',
                        subtitle: 'Seller ↔ Reseller products',
                        onTap: () {
                          _openSection(
                            title: 'Relationships',
                            notificationStream: _db
                                .collection('reseller_products')
                                .snapshots(),
                            notificationLabel: 'Relationships',
                            page: _relationshipsTab(),
                          );
                        },
                      ),

                      _adminMenuBox(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Orders',
                        subtitle: '${orders.length} customer orders',
                        onTap: () {
                          _openSection(
                            title: 'Orders',
                            notificationStream:
                                _db.collection('orders').snapshots(),
                            notificationLabel: 'Customer Orders',
                            page: _ordersTab(),
                          );
                        },
                      ),

                      _adminMenuBox(
                        icon: Icons.local_offer_outlined,
                        title: 'Coupons',
                        subtitle: 'Manage BuyNova coupons',
                        onTap: () {
                          _openSection(
                            title: 'Coupons',
                            notificationStream:
                                _db.collection('coupons').snapshots(),
                            notificationLabel: 'Coupons',
                            page: const AdminCouponPage(),
                          );
                        },
                      ),

                      _adminMenuBox(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Wallet',
                        subtitle: 'Manage wallet transactions',
                        onTap: () {
                          _openSection(
                            title: 'Wallet',
                            notificationStream: _db
                                .collectionGroup('walletTransactions')
                                .snapshots(),
                            notificationLabel: 'Wallet Transactions',
                            page: const AdminWalletPage(),
                          );
                        },
                      ),

                      // ==================================================
                      // HOME SLIDER PRODUCTS (admin chooses them)
                      // ==================================================

                      _adminMenuBox(
                        icon: Icons.view_carousel_outlined,
                        title: 'Home Slider Products',
                        subtitle:
                            'Choose the products shown at the top of Home',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AdminSliderProductsPage(),
                            ),
                          );
                        },
                      ),

                      // ==================================================
                      // CATEGORIES (admin adds / removes category names)
                      // ==================================================

                      _adminMenuBox(
                        icon: Icons.category_outlined,
                        title: 'Categories',
                        subtitle: 'Add or remove product categories',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AdminCategoriesPage(),
                            ),
                          );
                        },
                      ),

                      // ==================================================
                      // NEW: BUY NOVA MONETIZATION
                      // ==================================================

                      _adminMenuBox(
                        icon: Icons.settings_suggest_outlined,
                        title: 'BuyNova Monetization',
                        subtitle:
                            'Membership fees, commissions & campaigns',
                        onTap: () {
                          _openSection(
                            title: 'BuyNova Monetization',
                            page: _monetizationTab(),
                          );
                        },
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _dashboardHeader() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.12),
              child: Icon(
                Icons.admin_panel_settings_outlined,
                size: 34,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BuyNova Admin',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage users, sellers, products, orders and more.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminMenuBox({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.10),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
