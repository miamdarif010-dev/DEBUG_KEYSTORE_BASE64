import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'add_product_page.dart';
import 'fresh_info.dart';
import 'product_details_page.dart';

/// The seller's own Fresh Bazar Express products.
class MyFreshProductsPage extends StatelessWidget {
  const MyFreshProductsPage({super.key});

  num _num(dynamic value) {
    if (value is num) return value;

    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime _time(Map<String, dynamic> data) {
    final value = data['createdAt'];

    if (value is Timestamp) return value.toDate();

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _openAdd(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddProductPage(startAsFresh: true),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final name = data['name']?.toString() ?? 'Unnamed Product';
    final image = data['imageUrl']?.toString().trim() ?? '';
    final price = _num(data['price']);
    final stock = _num(data['stock']).toInt();
    final category = FreshInfo.categoryLabel(data['freshCategory']);
    final unit = FreshInfo.unitShort(data['unit']);
    final expiry = FreshInfo.expiryOf(data);
    final badge = FreshInfo.badge(data);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: image.isEmpty
              ? Container(
                  width: 58,
                  height: 58,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image_outlined, color: Colors.grey),
                )
              : Image.network(
                  image,
                  width: 58,
                  height: 58,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 58,
                    height: 58,
                    color: Colors.grey.shade200,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.grey,
                    ),
                  ),
                ),
        ),
        title: Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '৳${price.toStringAsFixed(0)}'
              '${unit.isEmpty ? '' : ' / $unit'}  •  Stock: $stock'
              '${category.isEmpty ? '' : '  •  $category'}',
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badge.color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (expiry != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    'Expiry: ${FreshInfo.formatDate(expiry)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ] else
                  Text(
                    'No expiry date - not shown in Fresh Bazar',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade800,
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ProductDetailsPage(productId: doc.id, product: data),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text(
          'My Fresh Products',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: user == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openAdd(context),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Fresh Product'),
            ),
      body: user == null
          ? const Center(child: Text('Please login first.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('sellerId', isEqualTo: user.uid)
                  .where('isFastDelivery', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Could not load products.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.toList()
                  ..sort(
                    (a, b) => _time(b.data()).compareTo(_time(a.data())),
                  );

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/fresh_logo.png',
                            width: 130,
                            height: 130,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(
                              Icons.eco_outlined,
                              size: 56,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No Fresh products yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap "Add Fresh Product" to upload your first one.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                  children: [
                    for (final doc in docs) _tile(context, doc),
                  ],
                );
              },
            ),
    );
  }
}
