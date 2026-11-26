import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SellerEarningsPage extends StatefulWidget {
  const SellerEarningsPage({super.key});

  @override
  State<SellerEarningsPage> createState() => _SellerEarningsPageState();
}

class _SellerEarningsPageState extends State<SellerEarningsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _formatMoney(double amount) {
    return '৳${amount.toStringAsFixed(2)}';
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }

    return 0.0;
  }

  int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  String _productName(Map<String, dynamic> data) {
    final name = data['name'];

    if (name == null || name.toString().trim().isEmpty) {
      return 'Unnamed Product';
    }

    return name.toString();
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    Color? iconColor,
  }) {
    final color = iconColor ?? Colors.redAccent;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: color,
                size: 25,
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
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.broken_image_outlined,
              color: Colors.grey,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Seller Earnings'),
        ),
        body: const Center(
          child: Text(
            'Please login to view your earnings.',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Seller Earnings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('products')
            .where('sellerId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load earnings.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.red,
                  ),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.redAccent,
              ),
            );
          }

          final documents = snapshot.data?.docs ?? [];

          double totalRevenue = 0;
          int totalSales = 0;
          int totalProducts = documents.length;

          double bestProductRevenue = 0;
          String bestProductName = 'No sales yet';

          final productEarnings = <Map<String, dynamic>>[];

          for (final document in documents) {
            final data = document.data();

            final name = _productName(data);
            final price = _toDouble(data['price']);
            final salesCount = _toInt(data['salesCount']);
            final views = _toInt(data['views']);

            final estimatedRevenue = price * salesCount;

            totalRevenue += estimatedRevenue;
            totalSales += salesCount;

            if (estimatedRevenue > bestProductRevenue) {
              bestProductRevenue = estimatedRevenue;
              bestProductName = name;
            }

            productEarnings.add({
              'id': document.id,
              'name': name,
              'price': price,
              'salesCount': salesCount,
              'views': views,
              'estimatedRevenue': estimatedRevenue,
              'imageUrl': data['imageUrl']?.toString(),
            });
          }

          productEarnings.sort(
            (a, b) => (b['estimatedRevenue'] as double)
                .compareTo(a['estimatedRevenue'] as double),
          );

          return RefreshIndicator(
            color: Colors.redAccent,
            onRefresh: () async {
              await Future<void>.delayed(
                const Duration(milliseconds: 500),
              );
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                // Main Earnings Card
                Card(
                  elevation: 3,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          Colors.redAccent,
                          Colors.red.shade700,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              color: Colors.white,
                              size: 25,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Estimated Seller Earnings',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _formatMoney(totalRevenue),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Based on product price × sales count',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Summary
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.45,
                  children: [
                    _summaryCard(
                      title: 'Total Sales',
                      value: totalSales.toString(),
                      icon: Icons.shopping_cart_checkout,
                      iconColor: Colors.green,
                    ),
                    _summaryCard(
                      title: 'Products',
                      value: totalProducts.toString(),
                      icon: Icons.inventory_2_outlined,
                      iconColor: Colors.blue,
                    ),
                    _summaryCard(
                      title: 'Best Product',
                      value: bestProductName,
                      icon: Icons.emoji_events_outlined,
                      iconColor: Colors.orange,
                    ),
                    _summaryCard(
                      title: 'Best Revenue',
                      value: _formatMoney(bestProductRevenue),
                      icon: Icons.trending_up,
                      iconColor: Colors.purple,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                const Text(
                  'Earnings by Product',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                if (productEarnings.isEmpty)
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(28),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No products found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Add products and start selling to see your earnings here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...productEarnings.map(
                    (product) {
                      final name = product['name'] as String;
                      final price = product['price'] as double;
                      final salesCount = product['salesCount'] as int;
                      final views = product['views'] as int;
                      final estimatedRevenue =
                          product['estimatedRevenue'] as double;
                      final imageUrl = product['imageUrl'] as String?;

                      return Card(
                        elevation: 1.5,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              _productImage(imageUrl),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Price: ${_formatMoney(price)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Sales: $salesCount  •  Views: $views',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Estimated',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatMoney(estimatedRevenue),
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 12),

                // Information
                Card(
                  elevation: 1,
                  color: Colors.orange.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Important: The amount shown here is an estimated '
                            'sales value calculated from the current product '
                            'price and sales count. It is not yet the actual '
                            'withdrawable seller balance. Actual earnings will '
                            'be connected to confirmed orders and the common '
                            'BuyNova Wallet in a later step.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
