import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_shimmer.dart';
import 'price_discount.dart';
import 'product_details_page.dart';

typedef _ProductDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

/// Fresh Bazar Express
///
/// Shows only the products the seller marked as fast delivery
/// (`isFastDelivery == true`), for example vegetables, fish, meat, eggs
/// and other raw goods.
class FreshBazarPage extends StatefulWidget {
  const FreshBazarPage({super.key});

  @override
  State<FreshBazarPage> createState() => _FreshBazarPageState();
}

class _FreshBazarPageState extends State<FreshBazarPage> {
  static const String _all = 'All';

  static const LinearGradient _gradient = LinearGradient(
    colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
  );

  static const Color _green = Color(0xFF2E7D32);

  // One equality filter only, so no Firestore index is needed.
  final Stream<QuerySnapshot<Map<String, dynamic>>> _stream = FirebaseFirestore
      .instance
      .collection('products')
      .where('isFastDelivery', isEqualTo: true)
      .snapshots();

  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  String _category = _all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // =========================================================
  // PRODUCT HELPERS
  // =========================================================

  bool _isVisible(Map<String, dynamic> data) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // Nobody sees their own product (same rule as the Home page).
    if (uid != null &&
        (data['sellerId'] == uid ||
            data['ownerId'] == uid ||
            data['entrepreneurUid'] == uid ||
            data['supplierSellerId'] == uid)) {
      return false;
    }

    if (data['isActive'] == false || data['active'] == false) {
      return false;
    }

    final status = (data['status'] ?? 'active').toString().trim().toLowerCase();

    const hidden = {
      'pending',
      'rejected',
      'deleted',
      'hidden',
      'draft',
      'blocked',
      'removed',
      'disabled',
      'inactive',
    };

    return !hidden.contains(status);
  }

  double _price(Map<String, dynamic> data) {
    final raw = data['price'] is num ? (data['price'] as num).toDouble() : 0.0;

    final currency = data['currency']?.toString().trim().toUpperCase();

    return currency == 'BDT' ? raw : raw * 0.09;
  }

  double _originalPrice(Map<String, dynamic> data) {
    final value = data['originalPrice'];

    final raw = value is num ? value.toDouble() : 0.0;

    if (raw <= 0) return 0;

    final currency = data['currency']?.toString().trim().toUpperCase();

    return currency == 'BDT' ? raw : raw * 0.09;
  }

  int _discountPercent(Map<String, dynamic> data) {
    final original = _originalPrice(data);
    final current = _price(data);

    if (original <= 0 || current <= 0 || original <= current) return 0;

    return (((original - current) / original) * 100).round();
  }

  int _createdMillis(Map<String, dynamic> data) {
    final t = data['createdAt'];

    return t is Timestamp ? t.millisecondsSinceEpoch : 0;
  }

  String _categoryOf(Map<String, dynamic> data) {
    return data['category']?.toString().trim() ?? '';
  }

  void _openProduct(String id, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsPage(
          productId: id,
          product: data,
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 62,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: _gradient),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fresh Bazar Express',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 2),
            Text(
              'টাটকা পণ্য, দ্রুত ডেলিভারি',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _message(
              icon: Icons.wifi_off_rounded,
              text: 'Failed to load products',
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _green),
            );
          }

          final List<_ProductDoc> visible = snapshot.data!.docs
              .where((d) => _isVisible(d.data()))
              .toList()
            ..sort(
              (a, b) =>
                  _createdMillis(b.data()).compareTo(_createdMillis(a.data())),
            );

          final categories = <String>[
            _all,
            ...{
              for (final d in visible)
                if (_categoryOf(d.data()).isNotEmpty) _categoryOf(d.data()),
            },
          ];

          final selected = categories.contains(_category) ? _category : _all;

          final shown = visible.where((d) {
            final data = d.data();

            if (selected != _all && _categoryOf(data) != selected) {
              return false;
            }

            if (_query.isNotEmpty) {
              final name = data['name']?.toString().toLowerCase() ?? '';

              if (!name.contains(_query)) return false;
            }

            return true;
          }).toList();

          return Column(
            children: [
              _buildSearch(),
              if (categories.length > 1) _buildCategoryChips(categories, selected),
              Expanded(
                child: visible.isEmpty
                    ? _message(
                        icon: Icons.eco_outlined,
                        text: 'এখনো কোনো পণ্য নেই',
                        logo: true,
                      )
                    : shown.isEmpty
                        ? _message(
                            icon: Icons.search_off_rounded,
                            text: 'কোনো পণ্য পাওয়া যায়নি',
                          )
                        : _buildGrid(shown),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required String text,
    bool logo = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (logo)
              Image.asset(
                'assets/fresh_logo.png',
                width: 150,
                height: 150,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(icon, size: 56, color: Colors.grey.shade400),
              )
            else
              Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          setState(() => _query = value.trim().toLowerCase());
        },
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search fresh products...',
          prefixIcon: const Icon(Icons.search_rounded, color: _green),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: _green, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(List<String> categories, String selected) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final name = categories[index];
          final isSelected = name == selected;

          return ChoiceChip(
            label: Text(name),
            selected: isSelected,
            showCheckmark: false,
            selectedColor: _green,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.black87,
            ),
            onSelected: (_) => setState(() => _category = name),
          );
        },
      ),
    );
  }

  Widget _buildGrid(List<_ProductDoc> docs) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];

        return _buildCard(doc.id, doc.data());
      },
    );
  }

  Widget _buildCard(String id, Map<String, dynamic> data) {
    final name = data['name']?.toString() ?? 'Unnamed Product';
    final imageUrl = data['imageUrl']?.toString().trim() ?? '';
    final discount = _discountPercent(data);
    final original = _originalPrice(data);

    final placeholder = Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.image, size: 46, color: Colors.grey),
      ),
    );

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
          onTap: () => _openProduct(id, data),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageUrl.isEmpty
                        ? placeholder
                        : CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 500,
                            fadeInDuration: const Duration(milliseconds: 200),
                            placeholder: (context, _) => const ShimmerBox(),
                            errorWidget: (context, _, __) => placeholder,
                          ),
                    if (discount > 0)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '-$discount%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt, color: Colors.white, size: 12),
                            SizedBox(width: 2),
                            Text(
                              'Express',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: PriceTag(
                            price: _price(data),
                            originalPrice: original > 0 ? original : null,
                            fontSize: 15,
                            color: _green,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: _gradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.add_shopping_cart,
                            size: 16,
                            color: Colors.white,
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
}
