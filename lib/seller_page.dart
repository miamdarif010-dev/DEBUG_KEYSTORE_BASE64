import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'add_product_page.dart';
import 'my_products_page.dart';
import 'seller_orders_page.dart';
import 'seller_return_refund_page.dart';
import 'news_feed_page.dart';
import 'seller_information_page.dart';
import 'seller_stock_page.dart';
import 'seller_views_page.dart';
import 'seller_analytics_page.dart';
import 'seller_code_helper.dart';
import 'wallet_page.dart';

class SellerPage extends StatelessWidget {
  const SellerPage({super.key});

  // =========================================================
  // STATUS COLOR
  // =========================================================

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // =========================================================
  // OVERVIEW BOX
  // =========================================================

  Widget _statCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: Colors.redAccent,
                  size: 26,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // MANAGEMENT BOX
  // =========================================================

  Widget _menuCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.55,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(
                        alpha: 0.10,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.redAccent,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
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
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // MEMBERSHIP FEE CARD
  // =========================================================

  Widget _membershipCard({
    required BuildContext context,
    required String sellerStatus,
    required Map<String, dynamic> userData,
  }) {
    final normalizedStatus = sellerStatus.toLowerCase();

    // Already approved.
    if (normalizedStatus == 'approved') {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.25),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.verified,
              color: Colors.green,
              size: 30,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seller Membership Active',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your Seller membership is already approved.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Payment/request is already pending.
    if (normalizedStatus == 'pending') {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.25),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.hourglass_top,
              color: Colors.orange,
              size: 30,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seller Request Pending',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your Seller registration request is waiting for Admin approval.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _SellerMembershipPaymentCard(
      sellerStatus: sellerStatus,
      userData: userData,
    );
  }

  // =========================================================
  // OPEN ADD PRODUCT
  // =========================================================

  void _openAddProduct(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddProductPage(),
      ),
    );
  }

  // =========================================================
  // OPEN MY PRODUCTS
  // =========================================================

  void _openMyProducts(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MyProductsPage(),
      ),
    );
  }

  // =========================================================
  // OPEN SELLER ORDERS
  // =========================================================

  void _openSellerOrders(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SellerOrdersPage(),
      ),
    );
  }

  // =========================================================
  // OPEN STOCK
  // =========================================================

  void _openSellerStock(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SellerStockPage(),
      ),
    );
  }

  // =========================================================
  // OPEN VIEWS
  // =========================================================

  void _openSellerViews(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SellerViewsPage(),
      ),
    );
  }

  // =========================================================
  // OPEN SALES ANALYTICS
  // =========================================================

  void _openSellerAnalytics(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SellerAnalyticsPage(),
      ),
    );
  }

  // =========================================================
  // OPEN RETURN REFUND
  // =========================================================

  void _openReturnRefundRequests(
    BuildContext context,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const SellerReturnRefundPage(),
      ),
    );
  }

  // =========================================================
  // OPEN VIDEOS
  // =========================================================

  void _openVideos(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NewsFeedPage(),
      ),
    );
  }

  // =========================================================
  // OPEN SELLER INFORMATION
  // =========================================================

  void _openSellerInformation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const SellerInformationPage(),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF9F7),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Seller Dashboard',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        body: const Center(
          child: Text(
            'Please login first.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Seller Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load seller information.\n\n'
                  '${userSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (userSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final userData =
              userSnapshot.data?.data() ?? {};

          final sellerStatus =
              userData['sellerStatus']?.toString() ??
                  'none';

          final sellerCode =
              userData['sellerCode']?.toString() ??
                  'Not assigned';

          return StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .where(
                  'sellerId',
                  isEqualTo: user.uid,
                )
                .snapshots(),
            builder: (context, productSnapshot) {
              if (productSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Unable to load products.\n\n'
                      '${productSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (productSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final products =
                  productSnapshot.data?.docs ?? [];

              int totalStock = 0;
              int totalSales = 0;
              int totalViews = 0;

              for (final product in products) {
                final data = product.data();

                totalStock +=
                    (data['stock'] as num?)?.toInt() ?? 0;

                totalSales +=
                    (data['salesCount'] as num?)?.toInt() ??
                        0;

                totalViews +=
                    (data['views'] as num?)?.toInt() ?? 0;
              }

              final isApproved =
                  sellerStatus == 'approved';

              // Approved seller without an ID: assign one
              // automatically. The dashboard refreshes by itself
              // once Firestore has the new sellerCode.
              if (isApproved &&
                  (userData['sellerCode'] ?? '')
                      .toString()
                      .isEmpty) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) {
                  ensureSellerCode(user.uid);
                });
              }

              final statusColor =
                  _statusColor(sellerStatus);

              return RefreshIndicator(
                onRefresh: () async {},
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // =================================================
                    // SELLER HEADER
                    // =================================================

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: 0.04,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.redAccent
                                  .withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.storefront,
                              size: 34,
                              color: Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'BuyNova Seller',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // =================================================
                                // CLICKABLE SELLER ID
                                // =================================================

                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    onTap: () {
                                      _openSellerInformation(
                                        context,
                                      );
                                    },
                                    child: Padding(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        vertical: 4,
                                        horizontal: 2,
                                      ),
                                      child: Row(
                                        mainAxisSize:
                                            MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Seller ID: $sellerCode',
                                            style:
                                                const TextStyle(
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.w600,
                                              color:
                                                  Colors.redAccent,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          const Icon(
                                            Icons
                                                .arrow_forward_ios,
                                            size: 12,
                                            color:
                                                Colors.redAccent,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  user.email ?? '',
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // =================================================
                    // APPROVAL STATUS
                    // =================================================

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(
                          alpha: 0.10,
                        ),
                        borderRadius:
                            BorderRadius.circular(16),
                        border: Border.all(
                          color: statusColor.withValues(
                            alpha: 0.30,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isApproved
                                ? Icons.verified
                                : Icons.info_outline,
                            color: statusColor,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Seller Status',
                                  style: TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  sellerStatus.toLowerCase() == 'none'
                                      ? 'NOT REGISTERED'
                                      : sellerStatus.toUpperCase(),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // =================================================
                    // MEMBERSHIP PAYMENT
                    // =================================================

                    if (!isApproved) ...[
                      const SizedBox(height: 16),
                      _membershipCard(
                        context: context,
                        sellerStatus: sellerStatus,
                        userData: userData,
                      ),
                    ],

                    const SizedBox(height: 24),

                    // =================================================
                    // OVERVIEW
                    // =================================================

                    const Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.35,
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      children: [
                        _statCard(
                          context: context,
                          title: 'Products',
                          value:
                              products.length.toString(),
                          icon:
                              Icons.inventory_2_outlined,
                          onTap: () {
                            _openMyProducts(context);
                          },
                        ),
                        _statCard(
                          context: context,
                          title: 'Stock',
                          value:
                              totalStock.toString(),
                          icon:
                              Icons.warehouse_outlined,
                          onTap: () {
                            _openSellerStock(context);
                          },
                        ),
                        _statCard(
                          context: context,
                          title: 'Sales',
                          value:
                              totalSales.toString(),
                          icon:
                              Icons.shopping_cart_checkout,
                          onTap: () {
                            _openSellerOrders(context);
                          },
                        ),
                        _statCard(
                          context: context,
                          title: 'Views',
                          value:
                              totalViews.toString(),
                          icon:
                              Icons.visibility_outlined,
                          onTap: () {
                            _openSellerViews(context);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 26),

                    // =================================================
                    // PRODUCT MANAGEMENT
                    // =================================================

                    const Text(
                      'Product Management',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _menuCard(
                      context: context,
                      icon: Icons.add_box_outlined,
                      title: 'Add Product',
                      subtitle: isApproved
                          ? 'Add a new product to BuyNova.'
                          : 'Seller approval is required.',
                      enabled: isApproved,
                      onTap: () {
                        _openAddProduct(context);
                      },
                    ),

                    _menuCard(
                      context: context,
                      icon: Icons.inventory_outlined,
                      title: 'My Products',
                      subtitle:
                          'Manage, edit and delete your products.',
                      enabled: true,
                      onTap: () {
                        _openMyProducts(context);
                      },
                    ),

                    _menuCard(
                      context: context,
                      icon: Icons.receipt_long_outlined,
                      title: 'Orders',
                      subtitle:
                          'View orders containing your products.',
                      enabled: isApproved,
                      onTap: () {
                        _openSellerOrders(context);
                      },
                    ),

                    _menuCard(
                      context: context,
                      icon:
                          Icons.assignment_return_outlined,
                      title: 'Return & Refund Requests',
                      subtitle:
                          'Review customer return and refund requests.',
                      enabled: isApproved,
                      onTap: () {
                        _openReturnRefundRequests(context);
                      },
                    ),

                    _menuCard(
                      context: context,
                      icon:
                          Icons.video_library_outlined,
                      title: 'Videos',
                      subtitle:
                          'Watch, upload and manage your BuyNova videos.',
                      enabled: isApproved,
                      onTap: () {
                        _openVideos(context);
                      },
                    ),

                    _menuCard(
                      context: context,
                      icon: Icons.analytics_outlined,
                      title: 'Sales Analytics',
                      subtitle:
                          'View sales and product performance.',
                      enabled: isApproved,
                      onTap: () {
                        _openSellerAnalytics(context);
                      },
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// =====================================================================
// SELLER MEMBERSHIP PAYMENT CARD
// =====================================================================

class _SellerMembershipPaymentCard extends StatefulWidget {
  final String sellerStatus;
  final Map<String, dynamic> userData;

  const _SellerMembershipPaymentCard({
    required this.sellerStatus,
    required this.userData,
  });

  @override
  State<_SellerMembershipPaymentCard> createState() =>
      _SellerMembershipPaymentCardState();
}

class _SellerMembershipPaymentCardState
    extends State<_SellerMembershipPaymentCard> {
  final FirebaseFirestore _db =
      FirebaseFirestore.instance;

  bool _processing = false;

  bool get _rejected =>
      widget.sellerStatus.toLowerCase() == 'rejected';

  double _sellerFee = 1000;
  bool _freeCampaignEnabled = false;
  DateTime? _campaignStart;
  DateTime? _campaignEnd;

  // =========================================================
  // LOAD MONETIZATION SETTINGS
  // =========================================================

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final snapshot = await _db
          .collection('platformSettings')
          .doc('monetization')
          .get();

      if (!mounted) return;

      final data = snapshot.data();

      if (data == null) {
        return;
      }

      setState(() {
        _sellerFee =
            _toDouble(data['sellerMembershipFee']) ??
                1000;

        _freeCampaignEnabled =
            data['freeCampaignEnabled'] == true;

        _campaignStart =
            _toDateTime(data['freeCampaignStart']);

        _campaignEnd =
            _toDateTime(data['freeCampaignEnd']);
      });
    } catch (_) {
      // Keep safe default values if settings cannot load.
    }
  }

  // =========================================================
  // HELPERS
  // =========================================================

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    );
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  bool _isFreeCampaignActive() {
    if (!_freeCampaignEnabled) {
      return false;
    }

    if (_campaignStart == null ||
        _campaignEnd == null) {
      return false;
    }

    final now = DateTime.now();

    if (now.isBefore(_campaignStart!)) {
      return false;
    }

    if (now.isAfter(_campaignEnd!)) {
      return false;
    }

    return true;
  }

  String _formatMoney(double amount) {
    if (amount == amount.roundToDouble()) {
      return '৳${amount.toStringAsFixed(0)}';
    }

    return '৳${amount.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Not set';
    }

    final day =
        date.day.toString().padLeft(2, '0');
    final month =
        date.month.toString().padLeft(2, '0');
    final year =
        date.year.toString();

    return '$day/$month/$year';
  }

  // =========================================================
  // PAY MEMBERSHIP
  // =========================================================

  Future<void> _payMembership() async {
    if (_processing) {
      return;
    }

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Please login first.',
        isError: true,
      );
      return;
    }

    if (widget.sellerStatus.toLowerCase() ==
        'approved') {
      _showMessage(
        'Your Seller membership is already approved.',
        isError: true,
      );
      return;
    }

    final freeCampaign = _isFreeCampaignActive();

    // FIX 1:
    // Use 0.0 so Dart keeps this value as double
    // instead of inferring num.
    final double displayedFee =
        (freeCampaign || _rejected) ? 0.0 : _sellerFee;

    final confirmed = _rejected
        ? true
        : await _showPaymentConfirmation(
            displayedFee,
            freeCampaign,
          );

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      final functions =
          FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      );

      final callable = functions.httpsCallable(
        'payMembershipRegistrationFee',
      );

      // IMPORTANT:
      // The Cloud Function decides the actual fee from
      // platformSettings/monetization.
      //
      // We send only the role.
      final result = await callable.call({
        'role': 'seller',
      });

      if (!mounted) return;

      final raw =
          result.data is Map
              ? Map<String, dynamic>.from(
                  result.data as Map,
                )
              : <String, dynamic>{};

      final success =
          raw['success'] == true;

      final free =
          raw['freeCampaign'] == true;

      final amount =
          _toDouble(raw['amount']) ?? 0;

      final newBalance =
          _toDouble(raw['balanceAfter'] ?? raw['newBalance']);

      if (success) {
        String message;

        if (raw['reapplied'] == true) {
          message =
              'Your request was submitted again.\n'
              'No new fee was charged.';
        } else if (free || amount <= 0) {
          message =
              'Free Seller membership request submitted successfully.';
        } else if (newBalance != null) {
          message =
              'Seller membership payment successful.\n'
              'Paid: ${_formatMoney(amount)}\n'
              'Wallet balance: ${_formatMoney(newBalance)}';
        } else {
          message =
              'Seller membership payment successful.';
        }

        _showSuccessDialog(message);
      } else {
        _showMessage(
          'Membership payment could not be completed.',
          isError: true,
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      String message =
          e.message ??
          'Membership payment failed.';

      switch (e.code) {
        case 'failed-precondition':
          message =
              e.message ??
              'Your Seller membership request cannot be processed right now.';
          break;

        case 'permission-denied':
          message =
              e.message ??
              'You do not have permission to complete this payment.';
          break;

        case 'unauthenticated':
          message =
              'Please login again and try.';
          break;

        case 'resource-exhausted':
          message =
              e.message ??
              'Your wallet balance is not enough.';
          break;

        case 'invalid-argument':
          message =
              e.message ??
              'Invalid membership request.';
          break;
      }

      final lower = message.toLowerCase();

      if (lower.contains('insufficient') ||
          lower.contains('not enough')) {
        _showInsufficientDialog(message);
      } else {
        _showMessage(
          message,
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Something went wrong.\n$e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  // =========================================================
  // CONFIRMATION DIALOG
  // =========================================================

  Future<bool> _showPaymentConfirmation(
    double displayedFee,
    bool freeCampaign,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Seller Membership',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              if (freeCampaign) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green
                        .withValues(alpha: 0.08),
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.local_offer,
                        color: Colors.green,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Free membership campaign is active.',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              const Text(
                'Seller Membership Fee',
                style: TextStyle(
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                freeCampaign
                    ? 'FREE'
                    : _formatMoney(
                        displayedFee,
                      ),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight:
                      FontWeight.bold,
                  color: freeCampaign
                      ? Colors.green
                      : Colors.redAccent,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                freeCampaign
                    ? 'Your Seller registration request will be submitted without a membership fee.'
                    : 'The membership fee will be deducted from your BuyNova Wallet.',
                style: TextStyle(
                  color:
                      Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.redAccent,
                foregroundColor:
                    Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: Text(
                freeCampaign
                    ? 'Continue'
                    : 'Pay & Apply',
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  // =========================================================
  // INSUFFICIENT BALANCE DIALOG
  // =========================================================

  void _showInsufficientDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.redAccent,
            size: 46,
          ),
          title: const Text(
            'Not enough wallet balance',
          ),
          content: Text(
            '$message\n\n'
            'Add money to your BuyNova Wallet, '
            'then apply again.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const WalletPage(),
                  ),
                );
              },
              child: const Text('Add Money'),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // SUCCESS DIALOG
  // =========================================================

  void _showSuccessDialog(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 52,
          ),
          title: const Text(
            'Request Submitted',
          ),
          content: Text(
            message,
            textAlign: TextAlign.center,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.redAccent,
                  foregroundColor:
                      Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                  );
                },
                child: const Text(
                  'Done',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor:
              isError
                  ? Colors.red.shade700
                  : Colors.green.shade700,
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final freeCampaign =
        _isFreeCampaignActive();

    // FIX 2:
    // Use 0.0 so this value is explicitly a double.
    final double displayedFee =
        freeCampaign ? 0.0 : _sellerFee;

    final bool noFee = freeCampaign || _rejected;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.redAccent
              .withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.redAccent
                      .withValues(alpha: 0.10),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: Colors.redAccent,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      _rejected
                          ? 'Request Again'
                          : 'Become a Seller',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Register your BuyNova Seller membership.',
                      style: TextStyle(
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // =====================================================
          // FEE
          // =====================================================

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: noFee
                  ? Colors.green
                      .withValues(alpha: 0.08)
                  : Colors.redAccent
                      .withValues(alpha: 0.06),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Membership Fee',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        noFee
                            ? 'FREE'
                            : _formatMoney(
                                displayedFee,
                              ),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight:
                              FontWeight.bold,
                          color: noFee
                              ? Colors.green
                              : Colors.redAccent,
                        ),
                      ),

                      if (_rejected)
                        const Padding(
                          padding:
                              EdgeInsets.only(top: 3),
                          child: Text(
                            'Fee already paid. No new fee.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (freeCampaign)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'FREE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // =====================================================
          // CAMPAIGN INFO
          // =====================================================

          if (_freeCampaignEnabled)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue
                    .withValues(alpha: 0.06),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      freeCampaign
                          ? 'Free membership campaign is active now.'
                          : 'Free membership campaign is not active right now.',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_freeCampaignEnabled)
            const SizedBox(height: 10),

          // =====================================================
          // PAYMENT BUTTON
          // =====================================================

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.redAccent,
                foregroundColor:
                    Colors.white,
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
              onPressed:
                  _processing
                      ? null
                      : _payMembership,
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      noFee
                          ? Icons
                              .how_to_reg_outlined
                          : Icons
                              .account_balance_wallet_outlined,
                    ),
              label: Text(
                _processing
                    ? 'Processing...'
                    : _rejected
                        ? 'Apply Again (No Fee)'
                        : freeCampaign
                            ? 'Apply as Seller'
                            : 'Pay & Apply as Seller',
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _rejected
                ? 'Your earlier membership fee is still valid.'
                : freeCampaign
                ? 'Your request will be processed through BuyNova.'
                : 'Payment is securely processed through your BuyNova Wallet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),

          if (_campaignStart != null ||
              _campaignEnd != null) ...[
            const SizedBox(height: 10),
            Text(
              'Campaign: ${_formatDate(_campaignStart)}'
              ' → '
              '${_formatDate(_campaignEnd)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
