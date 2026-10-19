import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ADMIN ONLY: choose which products appear in the auto-sliding
/// strip at the top of the Home page (max 10).
///
/// Data: collection `homeSlider`, one document per product
/// (document id = product id). Home page reads this collection.
class AdminSliderProductsPage extends StatefulWidget {
  const AdminSliderProductsPage({super.key});

  @override
  State<AdminSliderProductsPage> createState() =>
      _AdminSliderProductsPageState();
}

class _AdminSliderProductsPageState extends State<AdminSliderProductsPage> {
  static const int _maxItems = 10;

  // Same admin rule as the profile page.
  static const String _adminEmail = 'miamdarif010@gmail.com';

  final CollectionReference<Map<String, dynamic>> _sliderRef =
      FirebaseFirestore.instance.collection('homeSlider');

  bool _checking = true;
  bool _isAdmin = false;

  // Latest ids in the slider (kept so "Add" can enforce the limit).
  List<String> _sliderIds = [];

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _checking = false;
          _isAdmin = false;
        });
      }
      return;
    }

    // Same rule as the Admin Panel: only the admin email.
    final bool admin = (user.email ?? '').toLowerCase() == _adminEmail;

    if (!mounted) return;

    setState(() {
      _isAdmin = admin;
      _checking = false;
    });
  }

  // ---------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------

  String _price(Map<String, dynamic> data) {
    final raw = data['price'] is num ? (data['price'] as num).toDouble() : 0.0;

    final currency = data['currency']?.toString().trim().toUpperCase();

    final bdt = currency == 'BDT' ? raw : raw * 0.09;

    return '৳${bdt.toStringAsFixed(2)}';
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Widget _thumb(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 52,
        height: 52,
        child: url.isEmpty
            ? Container(
                color: Colors.grey.shade200,
                child: const Icon(Icons.image_outlined, color: Colors.grey),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image_outlined,
                      color: Colors.grey),
                ),
              ),
      ),
    );
  }

  // ---------------------------------------------------------
  // ADD / REMOVE
  // ---------------------------------------------------------

  Future<void> _addProduct(String productId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || !_isAdmin) return;

    if (_sliderIds.contains(productId)) {
      _message('This product is already in the slider.');
      return;
    }

    if (_sliderIds.length >= _maxItems) {
      _message('Maximum $_maxItems products. Remove one first.');
      return;
    }

    try {
      await _sliderRef.doc(productId).set({
        'productId': productId,
        'order': DateTime.now().millisecondsSinceEpoch,
        'addedBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _message('Added to Home slider.');
    } catch (e) {
      _message('Could not add: $e');
    }
  }

  Future<void> _removeProduct(String productId) async {
    try {
      await _sliderRef.doc(productId).delete();

      _message('Removed from Home slider.');
    } catch (e) {
      _message('Could not remove: $e');
    }
  }

  Future<void> _openPicker() async {
    if (_sliderIds.length >= _maxItems) {
      _message('Maximum $_maxItems products. Remove one first.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _ProductPickerSheet(
          existingIds: _sliderIds.toSet(),
          priceOf: _price,
          thumb: _thumb,
          onPick: (productId) async {
            Navigator.pop(sheetContext);
            await _addProduct(productId);
          },
        );
      },
    );
  }

  // ---------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Home Slider Products')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Only an Admin can manage the Home slider.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: const Text(
          'Home Slider Products',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        onPressed: _openPicker,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, productSnapshot) {
          final Map<String, Map<String, dynamic>> products = {};

          for (final doc in productSnapshot.data?.docs ?? []) {
            products[doc.id] = doc.data();
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _sliderRef.snapshots(),
            builder: (context, sliderSnapshot) {
              if (sliderSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load slider.\n${sliderSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (sliderSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = [...(sliderSnapshot.data?.docs ?? [])];

              docs.sort((a, b) {
                final oa = a.data()['order'];
                final ob = b.data()['order'];

                final na = oa is num ? oa.toInt() : 0;
                final nb = ob is num ? ob.toInt() : 0;

                return na.compareTo(nb);
              });

              _sliderIds = docs.map((d) => d.id).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.redAccent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'These products slide at the top of the Home '
                            'page. Only an Admin can add or remove them.\n'
                            '${docs.length} / $_maxItems selected.',
                            style: const TextStyle(height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (docs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No slider products yet.\nTap "Add Product".',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  for (int i = 0; i < docs.length; i++)
                    _sliderTile(
                      position: i + 1,
                      productId: docs[i].id,
                      product: products[docs[i].id],
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _sliderTile({
    required int position,
    required String productId,
    required Map<String, dynamic>? product,
  }) {
    final missing = product == null;

    final name = missing
        ? 'Product removed'
        : (product['name']?.toString() ?? 'Unnamed Product');

    final imageUrl =
        missing ? '' : (product['imageUrl']?.toString().trim() ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: Colors.redAccent,
            child: Text(
              '$position',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _thumb(imageUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: missing ? Colors.grey : Colors.black,
                  ),
                ),
                if (!missing)
                  Text(
                    _price(product),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: () => _removeProduct(productId),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// PRODUCT PICKER (bottom sheet)
// =====================================================================

class _ProductPickerSheet extends StatefulWidget {
  final Set<String> existingIds;
  final String Function(Map<String, dynamic>) priceOf;
  final Widget Function(String) thumb;
  final Future<void> Function(String productId) onPick;

  const _ProductPickerSheet({
    required this.existingIds,
    required this.priceOf,
    required this.thumb,
    required this.onPick,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.8;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const Text(
              'Choose a product',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (value) {
                  setState(() {
                    _query = value.trim().toLowerCase();
                  });
                },
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Could not load products.'),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = (snapshot.data?.docs ?? []).where((doc) {
                    if (widget.existingIds.contains(doc.id)) return false;

                    if (_query.isEmpty) return true;

                    final name =
                        doc.data()['name']?.toString().toLowerCase() ?? '';

                    return name.contains(_query);
                  }).toList();

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No products found.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();

                      return ListTile(
                        leading: widget.thumb(
                          data['imageUrl']?.toString().trim() ?? '',
                        ),
                        title: Text(
                          data['name']?.toString() ?? 'Unnamed Product',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(widget.priceOf(data)),
                        trailing: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.redAccent,
                        ),
                        onTap: () => widget.onPick(doc.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
