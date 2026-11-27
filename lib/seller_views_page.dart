import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SellerViewsPage extends StatelessWidget {
  const SellerViewsPage({super.key});

  // =========================================================
  // VIEWS STATUS
  // =========================================================

  String _performanceText(int views) {
    if (views <= 0) {
      return 'No Views';
    }

    if (views < 10) {
      return 'Getting Started';
    }

    if (views < 100) {
      return 'Good Reach';
    }

    if (views < 1000) {
      return 'High Reach';
    }

    return 'Very High Reach';
  }

  Color _performanceColor(int views) {
    if (views <= 0) {
      return Colors.grey;
    }

    if (views < 10) {
      return Colors.orange;
    }

    if (views < 100) {
      return Colors.blue;
    }

    if (views < 1000) {
      return Colors.green;
    }

    return Colors.deepPurple;
  }

  // =========================================================
  // SUMMARY CARD
  // =========================================================

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
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
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: color,
              size: 25,
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
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // PRODUCT VIEWS CARD
  // =========================================================

  Widget _productViewsCard({
    required String productName,
    required int views,
    required String? imageUrl,
  }) {
    final performanceColor = _performanceColor(views);
    final performanceText = _performanceText(views);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          // =====================================================
          // PRODUCT IMAGE
          // =====================================================

          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      imageUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (
                        context,
                        error,
                        stackTrace,
                      ) {
                        return const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey,
                          size: 28,
                        );
                      },
                    ),
                  )
                : const Icon(
                    Icons.visibility_outlined,
                    color: Colors.redAccent,
                    size: 30,
                  ),
          ),

          const SizedBox(width: 14),

          // =====================================================
          // PRODUCT INFORMATION
          // =====================================================

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName.isEmpty
                      ? 'Unnamed Product'
                      : productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  'Views: $views',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 5),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: performanceColor.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    performanceText,
                    style: TextStyle(
                      color: performanceColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // =====================================================
          // VIEWS NUMBER
          // =====================================================

          Column(
            children: [
              Icon(
                Icons.visibility_outlined,
                color: performanceColor,
                size: 24,
              ),
              const SizedBox(height: 3),
              Text(
                views.toString(),
                style: TextStyle(
                  color: performanceColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
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
            'Product Views',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
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
        iconTheme: const IconThemeData(
          color: Colors.black,
        ),
        title: const Text(
          'Product Views',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where(
              'sellerId',
              isEqualTo: user.uid,
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load product views.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final products = snapshot.data?.docs ?? [];

          int totalViews = 0;
          int productsWithViews = 0;
          int highestViews = 0;

          for (final product in products) {
            final data = product.data();

            final views =
                (data['views'] as num?)?.toInt() ?? 0;

            totalViews += views;

            if (views > 0) {
              productsWithViews++;
            }

            if (views > highestViews) {
              highestViews = views;
            }
          }

          return RefreshIndicator(
            onRefresh: () async {
              await Future<void>.delayed(
                const Duration(milliseconds: 300),
              );
            },
            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                // =================================================
                // HEADER
                // =================================================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(
                            alpha: 0.10,
                          ),
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.visibility_outlined,
                          color: Colors.redAccent,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Product Views',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Monitor how many times customers view your products.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // =================================================
                // SUMMARY
                // =================================================

                const Text(
                  'Views Overview',
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
                    _summaryCard(
                      title: 'Total Products',
                      value: products.length.toString(),
                      icon: Icons.inventory_2_outlined,
                      color: Colors.blue,
                    ),
                    _summaryCard(
                      title: 'Total Views',
                      value: totalViews.toString(),
                      icon: Icons.visibility_outlined,
                      color: Colors.deepPurple,
                    ),
                    _summaryCard(
                      title: 'Products Viewed',
                      value: productsWithViews.toString(),
                      icon: Icons.visibility,
                      color: Colors.green,
                    ),
                    _summaryCard(
                      title: 'Highest Views',
                      value: highestViews.toString(),
                      icon: Icons.trending_up,
                      color: Colors.orange,
                    ),
                  ],
                ),

                const SizedBox(height: 26),

                // =================================================
                // PRODUCT VIEW LIST
                // =================================================

                const Text(
                  'Product Performance',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                if (products.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.visibility_off_outlined,
                          size: 52,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No products found.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Your product views will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...products.map((product) {
                    final data = product.data();

                    final productName =
                        data['name']?.toString() ?? '';

                    final views =
                        (data['views'] as num?)?.toInt() ?? 0;

                    String? imageUrl;

                    final possibleImage =
                        data['imageUrl'];

                    if (possibleImage != null) {
                      imageUrl =
                          possibleImage.toString();
                    }

                    return _productViewsCard(
                      productName: productName,
                      views: views,
                      imageUrl: imageUrl,
                    );
                  }),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
