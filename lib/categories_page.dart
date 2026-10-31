import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'category_service.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _productsStream =
      FirebaseFirestore.instance.collection('products').snapshots();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isOwnProduct(Map<String, dynamic> d) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return false;

    return d['sellerId'] == uid ||
        d['ownerId'] == uid ||
        d['entrepreneurUid'] == uid ||
        d['supplierSellerId'] == uid;
  }

  /// lowercase category -> first product image (same idea as Home).
  Map<String, String> _imagesFrom(QuerySnapshot<Map<String, dynamic>>? snap) {
    final images = <String, String>{};

    if (snap == null) return images;

    for (final doc in snap.docs) {
      final d = doc.data();

      if (_isOwnProduct(d)) continue;

      final img = d['imageUrl']?.toString().trim() ?? '';
      final cat = d['category']?.toString().trim().toLowerCase() ?? '';

      if (img.isNotEmpty && cat.isNotEmpty) {
        images.putIfAbsent(cat, () => img);
      }
    }

    return images;
  }

  /// Tapping a category goes back to the Home page with that category.
  void _select(String name) {
    Navigator.pop(context, name);
  }

  Widget _categoryTile({
    required String name,
    required IconData icon,
    String? imageUrl,
  }) {
    final fallback = Icon(icon, color: Colors.redAccent, size: 26);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _select(name),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: 58,
                      height: 58,
                      cacheWidth: 140,
                      errorBuilder: (context, error, stackTrace) =>
                          Center(child: fallback),
                    )
                  : Center(child: fallback),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, height: 1.15),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // SEARCH (filters the category names)
          Container(
            color: Colors.redAccent,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(21),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) {
                  setState(() => _searchQuery = v.trim().toLowerCase());
                },
                decoration: InputDecoration(
                  hintText: 'Search categories...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<CategoryItem>>(
              stream: CategoryService.stream(),
              builder: (context, catSnap) {
                if (catSnap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Unable to load categories.\n${catSnap.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!catSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _productsStream,
                  builder: (context, prodSnap) {
                    final images = _imagesFrom(prodSnap.data);

                    // "All" is always first.
                    final entries = <_CatEntry>[
                      _CatEntry(
                        name: CategoryService.allName,
                        icon: Icons.apps_rounded,
                        image: images.values.isNotEmpty
                            ? images.values.first
                            : null,
                      ),
                      for (final item in catSnap.data!)
                        _CatEntry(
                          name: item.name,
                          icon: item.icon,
                          image: images[item.name.trim().toLowerCase()],
                        ),
                    ];

                    final shown = entries
                        .where(
                          (e) =>
                              _searchQuery.isEmpty ||
                              e.name.toLowerCase().contains(_searchQuery),
                        )
                        .toList();

                    if (shown.isEmpty) {
                      return const Center(
                        child: Text(
                          'No categories found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 6,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: shown.length,
                      itemBuilder: (context, i) {
                        final e = shown[i];

                        return _categoryTile(
                          name: e.name,
                          icon: e.icon,
                          imageUrl: e.image,
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
    );
  }
}

class _CatEntry {
  final String name;
  final IconData icon;
  final String? image;

  const _CatEntry({required this.name, required this.icon, this.image});
}
