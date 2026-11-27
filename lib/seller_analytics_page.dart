import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SellerAnalyticsPage extends StatelessWidget {
  const SellerAnalyticsPage({super.key});

  int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _money(double amount) {
    return '৳${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF9F7),
        appBar: AppBar(
          title: const Text(
            'Sales Analytics',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Text('Please login first.'),
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
          'Sales Analytics',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('sellerId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load sales analytics.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final products = snapshot.data?.docs ?? [];

          int totalProducts = 0;
          int totalSales = 0;
          int totalViews = 0;
          int totalStock = 0;

          double totalRevenue = 0;

          String bestProduct = 'No sales yet';
          int bestProductSales = 0;

          for (final product in products) {
            final data = product.data();

            final sales = _toInt(data['salesCount']);
            final views = _toInt(data['views']);
            final stock = _toInt(data['stock']);

            final price = _toDouble(data['price']);

            totalProducts++;
            totalSales += sales;
            totalViews += views;
            totalStock += stock;

            totalRevenue += price * sales;

            if (sales > bestProductSales) {
              bestProductSales = sales;
              bestProduct =
                  data['name']?.toString() ?? 'Unnamed Product';
            }
          }

          final double conversionRate = totalViews > 0
              ? (totalSales / totalViews) * 100
              : 0;

          return RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(
                const Duration(milliseconds: 500),
              );
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _headerCard(
                  totalSales: totalSales,
                  totalRevenue: totalRevenue,
                ),

                const SizedBox(height: 16),

                const Text(
                  'Sales Overview',
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
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _statCard(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Total Sales',
                      value: totalSales.toString(),
                    ),
                    _statCard(
                      icon: Icons.payments_outlined,
                      title: 'Revenue',
                      value: _money(totalRevenue),
                    ),
                    _statCard(
                      icon: Icons.inventory_2_outlined,
                      title: 'Products',
                      value: totalProducts.toString(),
                    ),
                    _statCard(
                      icon: Icons.visibility_outlined,
                      title: 'Views',
                      value: totalViews.toString(),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                const Text(
                  'Performance',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                _performanceCard(
                  icon: Icons.trending_up,
                  title: 'Conversion Rate',
                  value: '${conversionRate.toStringAsFixed(2)}%',
                  subtitle:
                      'Sales compared with total product views',
                ),

                const SizedBox(height: 10),

                _performanceCard(
                  icon: Icons.inventory_outlined,
                  title: 'Available Stock',
                  value: totalStock.toString(),
                  subtitle: 'Total stock across your products',
                ),

                const SizedBox(height: 10),

                _performanceCard(
                  icon: Icons.emoji_events_outlined,
                  title: 'Best Selling Product',
                  value: bestProduct,
                  subtitle:
                      '$bestProductSales sale${bestProductSales == 1 ? '' : 's'}',
                ),

                const SizedBox(height: 24),

                const Text(
                  'Product Sales',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                if (products.isEmpty)
                  _emptyCard()
                else
                  ...products.map(
                    (product) {
                      final data = product.data();

                      final name =
                          data['name']?.toString() ?? 'Unnamed Product';

                      final sales = _toInt(data['salesCount']);
                      final views = _toInt(data['views']);
                      final price = _toDouble(data['price']);

                      final revenue = price * sales;

                      final imageUrl =
                          data['imageUrl']?.toString();

                      return _productSalesCard(
                        name: name,
                        sales: sales,
                        views: views,
                        revenue: revenue,
                        imageUrl: imageUrl,
                      );
                    },
                  ),

                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.blue.shade100,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sales analytics are calculated from your current product data. Revenue is estimated using product price × sales count.',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
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

  Widget _headerCard({
    required int totalSales,
    required double totalRevenue,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.redAccent,
            Colors.red.shade700,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: 0.20),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Sales',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$totalSales Sales',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Estimated Revenue: ${_money(totalRevenue)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.redAccent,
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
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
    );
  }

  Widget _performanceCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
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
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.10),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productSalesCard({
    required String name,
    required int sales,
    required int views,
    required double revenue,
    required String? imageUrl,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
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
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.grey,
                      );
                    },
                  )
                : const Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.grey,
                  ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Sales: $sales • Views: $views',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Revenue: ${_money(revenue)}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 55,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          const Text(
            'No products yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Add products to start seeing your sales analytics.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
