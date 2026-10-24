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
  // HELPERS (same rules as the Home page)
  // ---------------------------------------------------------

  bool _isOwnProduct(Map<String, dynamic> d) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return false;

    return d['sellerId'] == uid ||
        d['ownerId'] == uid ||
        d['entrepreneurUid'] == uid ||
        d['supplierSellerId'] == uid;
  }

  double _bdtPrice(Map<String, dynamic> d) {
    final raw = d['price'] is num ? (d['price'] as num).toDouble() : 0.0;
    final currency = d['currency']?.toString().trim().toUpperCase();

    return currency == 'BDT' ? raw : raw * 0.09;
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
  // PRODUCT TILE (round image + name + price)
  // ---------------------------------------------------------

  Widget _productTile(String id, Map<String, dynamic> data) {
    final name = data['name']?.toString() ?? 'Unnamed Product';
    final imageUrl = data['imageUrl']?.toString().trim() ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openProduct(id, data),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipOval(
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.image_outlined,
                            color: Colors.grey,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.image_outlined,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, height: 1.2),
          ),
          const SizedBox(height: 2),
          Text(
            '৳${_bdtPrice(data).toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // RIGHT SIDE: products of the selected category
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
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selected.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
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
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.62,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final doc = docs[i];

                        return _productTile(doc.id, doc.data());
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    // LEFT SIDEBAR
                    Container(
                      width: 100,
                      color: Colors.grey.shade100,
                      child: ListView.builder(
                        itemCount: categories.length,
                        itemBuilder: (context, i) {
                          final isSelected = i == index;

                          return InkWell(
                            onTap: () => setState(() => _selectedIndex = i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                border: Border(
                                  left: BorderSide(
                                    color: isSelected
                                        ? Colors.redAccent
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Text(
                                categories[i].name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.redAccent
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // RIGHT SIDE: products
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
