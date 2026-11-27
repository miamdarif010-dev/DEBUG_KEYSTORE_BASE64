import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'cart_page.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  User? get _user => FirebaseAuth.instance.currentUser;

  Stream<QuerySnapshot<Map<String, dynamic>>> _favoritesStream() {
    final user = _user;

    if (user == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .snapshots();
  }

  String _formatPrice(dynamic price) {
    double value = 0;

    if (price is num) {
      value = price.toDouble();
    } else {
      value = double.tryParse(
            price?.toString() ?? '0',
          ) ??
          0;
    }

    return '৳${value.toStringAsFixed(0)}';
  }

  double _priceAsDouble(dynamic price) {
    if (price is num) {
      return price.toDouble();
    }

    return double.tryParse(
          price?.toString() ?? '0',
        ) ??
        0;
  }

  Future<void> _removeFavorite(
    BuildContext context,
    String favoriteId,
  ) async {
    final user = _user;

    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(favoriteId)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Removed from Favorites.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not remove favorite. Please try again.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _addToCart(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final user = _user;

    if (user == null) return;

    final data = document.data() ?? {};

    final name = (
      data['productName'] ??
      data['name'] ??
      'BuyNova Product'
    ).toString();

    final imageUrl = (
      data['productImageUrl'] ??
      data['imageUrl'] ??
      ''
    ).toString();

    final price = _priceAsDouble(
      data['price'] ??
          data['sellingPrice'] ??
          0,
    );

    try {
      // Use the existing CartService.
      await CartService.addItem(
        id: document.id,
        name: name,
        price: price,
        imageUrl: imageUrl.isEmpty ? null : imageUrl,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$name added to Cart.',
            ),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'VIEW CART',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const CartPage(),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not add to Cart. Please try again.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _favoriteCard(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    final name = (
      data['productName'] ??
      data['name'] ??
      'BuyNova Product'
    ).toString();

    final imageUrl = (
      data['productImageUrl'] ??
      data['imageUrl'] ??
      ''
    ).toString();

    final price =
        data['price'] ??
        data['sellingPrice'] ??
        0;

    final category =
        (data['category'] ?? '').toString();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // PRODUCT IMAGE
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(10),
                color: Colors.grey.shade100,
              ),
              child: imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius:
                          BorderRadius.circular(10),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (
                          context,
                          error,
                          stackTrace,
                        ) {
                          return const Icon(
                            Icons
                                .image_not_supported_outlined,
                            color: Colors.grey,
                          );
                        },
                      ),
                    )
                  : const Icon(
                      Icons.shopping_bag_outlined,
                      size: 38,
                      color: Colors.grey,
                    ),
            ),

            const SizedBox(width: 12),

            // PRODUCT INFORMATION
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  if (category.isNotEmpty)
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Colors.grey.shade600,
                      ),
                    ),

                  const SizedBox(height: 5),

                  Text(
                    _formatPrice(price),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ADD TO CART BUTTON
                  SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _addToCart(
                          context,
                          document,
                        );
                      },
                      icon: const Icon(
                        Icons.shopping_cart_outlined,
                        size: 18,
                      ),
                      label: const Text(
                        'Add to Cart',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.redAccent,
                        foregroundColor:
                            Colors.white,
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // REMOVE FAVORITE
            IconButton(
              tooltip:
                  'Remove from Favorites',
              onPressed: () {
                _removeFavorite(
                  context,
                  document.id,
                );
              },
              icon: const Icon(
                Icons.favorite,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyFavorites() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 30,
          vertical: 80,
        ),
        child: Column(
          children: [
            Container(
              width: 95,
              height: 95,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    Colors.redAccent.withValues(
                  alpha: 0.08,
                ),
              ),
              child: const Icon(
                Icons.favorite_border,
                size: 48,
                color: Colors.redAccent,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'No Favorites Yet',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Products you save as favorites will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Favorites',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: Text(
            'Please log in to view your favorites.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Favorites',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _favoritesStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 50,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Could not load Favorites.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Colors.grey.shade600,
                      ),
                    ),
                  ],
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

          final favorites =
              snapshot.data?.docs ?? [];

          if (favorites.isEmpty) {
            return _emptyFavorites();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              return _favoriteCard(
                context,
                favorites[index],
              );
            },
          );
        },
      ),
    );
  }
}
