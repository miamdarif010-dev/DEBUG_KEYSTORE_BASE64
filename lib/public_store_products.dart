import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'price_discount.dart';
import 'product_details_page.dart';

/// Products of a seller / reseller, shown on his public profile page.
///
/// The data comes from the server (`getPublicStore`): it contains only
/// public fields (no email, phone, supplier price or profit). A reseller
/// store shows only the reseller's own listings.
class PublicStoreProducts extends StatefulWidget {
  final String userId;

  const PublicStoreProducts({super.key, required this.userId});

  @override
  State<PublicStoreProducts> createState() => _PublicStoreProductsState();
}

class _PublicStoreProductsState extends State<PublicStoreProducts> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();

    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final result = await FirebaseFunctions.instanceFor(
      region: 'asia-northeast3',
    ).httpsCallable('getPublicStore').call({'userId': widget.userId});

    return jsonDecode(jsonEncode(result.data)) as Map<String, dynamic>;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // =========================================================
  // OPEN A PRODUCT
  // =========================================================

  Future<void> _open(Map<String, dynamic> item, bool isReseller) async {
    final String id = item['id']?.toString() ?? '';

    if (id.isEmpty) return;

    try {
      Map<String, dynamic> product;

      if (isReseller) {
        final result = await FirebaseFunctions.instanceFor(
          region: 'asia-northeast3',
        ).httpsCallable('getResellerListing').call({'listingId': id});

        final json =
            jsonDecode(jsonEncode(result.data)) as Map<String, dynamic>;

        product = Map<String, dynamic>.from(json['listing'] as Map);
      } else {
        final snapshot =
            await FirebaseFirestore.instance.collection('products').doc(id).get();

        final data = snapshot.data();

        if (data == null) {
          _showMessage('This product is no longer available.');
          return;
        }

        product = Map<String, dynamic>.from(data);
      }

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailsPage(productId: id, product: product),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      _showMessage(e.message ?? 'Could not open this product.');
    } catch (_) {
      _showMessage('Could not open this product.');
    }
  }

  // =========================================================
  // PRODUCT CARD
  // =========================================================

  Widget _card(Map<String, dynamic> item, bool isReseller) {
    final String name = item['name']?.toString() ?? '';
    final String imageUrl = item['imageUrl']?.toString() ?? '';
    final double price = _toDouble(item['price']);
    final double original = _toDouble(item['originalPrice']);

    return GestureDetector(
      onTap: () {
        _open(item, isReseller);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade100,
                          child: const Icon(
                            Icons.image_outlined,
                            size: 38,
                            color: Colors.grey,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey.shade100,
                      child: const Icon(
                        Icons.image_outlined,
                        size: 38,
                        color: Colors.grey,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 8, 9, 3),
              child: Text(
                name.isEmpty ? 'Product' : name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 2, 9, 8),
              child: PriceTag(
                price: price,
                originalPrice: original > price ? original : null,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<dynamic> items,
    required bool isReseller,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${items.length} items',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 275,
            ),
            itemBuilder: (context, index) {
              final item = Map<String, dynamic>.from(items[index] as Map);

              return _card(item, isReseller);
            },
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
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Could not load products.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _future = _load();
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data!;

        final profile = Map<String, dynamic>.from(
          (data['profile'] as Map?) ?? <String, dynamic>{},
        );

        final String shopName = profile['shopName']?.toString() ?? '';

        final List<dynamic> sellerProducts =
            (data['sellerProducts'] as List?) ?? <dynamic>[];

        final List<dynamic> resellerProducts =
            (data['resellerProducts'] as List?) ?? <dynamic>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (shopName.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.store_outlined, color: Colors.redAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        shopName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            _section(
              title: 'Seller Products',
              icon: Icons.storefront,
              items: sellerProducts,
              isReseller: false,
            ),
            _section(
              title: 'Reseller Store',
              icon: Icons.business_center,
              items: resellerProducts,
              isReseller: true,
            ),
            if (sellerProducts.isEmpty && resellerProducts.isEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 44,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No products yet',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
