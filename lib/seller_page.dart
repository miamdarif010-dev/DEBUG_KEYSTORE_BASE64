import 'package:cloud_firestore/cloud_firestore.dart';
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
                  'pending';

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
                                  sellerStatus.toUpperCase(),
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
