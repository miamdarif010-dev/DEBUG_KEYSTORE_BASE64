import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'category_service.dart';
import 'product_details_page.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  int _selectedIndex = 0;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _productsStream =
      FirebaseFirestore.instance.collection('products').snapshots();

  // "All" is always first, then the categories the admin created.
  static const CategoryItem _allItem = CategoryItem(
    id: 'all',
    name: CategoryService.allName,
    iconKey: '',
    colorKey: '',
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------

  bool _isOwnProduct(Map<String, dynamic> d) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return false;

    return d['sellerId'] == uid ||
        d['ownerId'] == uid ||
        d['entrepreneurUid'] == uid ||
        d['supplierSellerId'] == uid;
  }

  bool _matches(Map<String, dynamic> d, CategoryItem selected) {
    if (_isOwnProduct(d)) return false;

    if (selected.id != 'all') {
      final productCategory =
          d['category']?.toString().trim().toLowerCase() ?? '';

      if (productCategory != selected.name.trim().toLowerCase()) {
        return false;
      }
    }

    if (_searchQuery.isNotEmpty) {
      final name = d['name']?.toString().toLowerCase() ?? '';

      if (!name.contains(_searchQuery)) return false;
    }

    return true;
  }

  bool _hasDiscount(Map<String, dynamic> d) {
    final o = d['originalPrice'];
    final p = d['price'];

    if (o is! num || p is! num) return false;

    return o > 0 && o > p;
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

  // ---------------------------------------------------------
  // ROUND ITEM (picture + name), like the screenshot
  // ---------------------------------------------------------

  Widget _roundItem(String id, Map<String, dynamic> data) {
    final name = data['name']?.toString() ?? 'Unnamed Product';
    final imageUrl = data['imageUrl']?.toString().trim() ?? '';

    final placeholder = Container(
      color: Colors.grey.shade200,
      child: const Icon(Icons.image_outlined, color: Colors.grey),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openProduct(id, data),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipOval(
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            cacheWidth: 260,
                            errorBuilder: (context, error, stackTrace) =>
                                placeholder,
                          )
                        : placeholder,
                  ),
                ),
                if (_hasDiscount(data))
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'HOT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, height: 1.2),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // RIGHT SIDE: "Shop by category"
  // ---------------------------------------------------------

  Widget _productsPanel(CategoryItem selected) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _productsStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Failed to load products\n${snap.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs
            .where((d) => _matches(d.data(), selected))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Shop by category',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    // Goes back to Home with this category selected.
                    onPressed: () => Navigator.pop(context, selected.name),
                    child: const Text(
                      'Home-এ দেখুন',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: docs.isEmpty
                  ? const Center(
                      child: Text(
                        'এই ক্যাটাগরিতে কোনো পণ্য নেই',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.74,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final doc = docs[i];

                        return _roundItem(doc.id, doc.data());
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------
  // LEFT SIDEBAR
  // ---------------------------------------------------------

  Widget _sidebar(List<CategoryItem> categories, int index) {
    return Container(
      width: 96,
      color: const Color(0xFFF5F5F5),
      child: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, i) {
          final isSelected = i == index;

          return InkWell(
            onTap: () => setState(() => _selectedIndex = i),
            child: Container(
              constraints: const BoxConstraints(minHeight: 58),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 10,
              ),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: isSelected ? Colors.deepOrange : Colors.transparent,
                    width: 4,
                  ),
                ),
              ),
              child: Text(
                categories[i].name,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.black : Colors.black87,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<CategoryItem>>(
        stream: CategoryService.stream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load categories.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = <CategoryItem>[_allItem, ...snapshot.data!];

          final index =
              _selectedIndex < categories.length ? _selectedIndex : 0;

          final selected = categories[index];

          return Column(
            children: [
              // SEARCH BAR
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
                      hintText: 'Search products...',
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.grey),
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
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: Row(
                  children: [
                    _sidebar(categories, index),
                    Expanded(child: _productsPanel(selected)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
