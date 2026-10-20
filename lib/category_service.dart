import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// =====================================================================
// CATEGORY ITEM
// =====================================================================

class CategoryItem {
  final String id;
  final String name;
  final String iconKey;
  final String colorKey;

  const CategoryItem({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorKey,
  });

  IconData get icon =>
      CategoryService.icons[iconKey] ?? Icons.category_outlined;

  Color get color => CategoryService.colors[colorKey] ?? Colors.grey;
}

// =====================================================================
// CATEGORY SERVICE
// Firestore collection: categories
// Fields: name, iconKey, colorKey, order, createdAt
// "All" is NOT stored. Every screen adds it as the first item.
// =====================================================================

class CategoryService {
  CategoryService._();

  static const String allName = 'All';

  static final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('categories');

  // ---------------------------------------------------------------
  // ICON AND COLOR PRESETS (admin picks one key for each category)
  // ---------------------------------------------------------------

  static const Map<String, IconData> icons = {
    'phone': Icons.smartphone,
    'laptop': Icons.laptop_mac,
    'watch': Icons.watch,
    'headphones': Icons.headphones,
    'camera': Icons.camera_alt,
    'fashion': Icons.checkroom,
    'shoes': Icons.hiking,
    'bag': Icons.shopping_bag_outlined,
    'beauty': Icons.spa_outlined,
    'sports': Icons.sports_soccer,
    'toys': Icons.toys_outlined,
    'grocery': Icons.local_grocery_store_outlined,
    'home': Icons.chair_outlined,
    'book': Icons.menu_book_outlined,
    'car': Icons.directions_car_outlined,
    'health': Icons.health_and_safety_outlined,
    'game': Icons.sports_esports_outlined,
    'tv': Icons.tv,
    'kitchen': Icons.kitchen_outlined,
    'category': Icons.category_outlined,
  };

  static const Map<String, Color> colors = {
    'red': Colors.redAccent,
    'blue': Colors.blue,
    'indigo': Colors.indigo,
    'teal': Colors.teal,
    'purple': Colors.purple,
    'brown': Colors.brown,
    'orange': Colors.deepOrange,
    'deepPurple': Colors.deepPurple,
    'pink': Colors.pinkAccent,
    'green': Colors.green,
    'amber': Colors.orange,
    'lime': Colors.lightGreen,
  };

  // ---------------------------------------------------------------
  // DEFAULT CATEGORIES (your old hard-coded list, without "All")
  // ---------------------------------------------------------------

  static const List<Map<String, String>> defaults = [
    {'name': 'Phones', 'icon': 'phone', 'color': 'blue'},
    {'name': 'Laptops', 'icon': 'laptop', 'color': 'indigo'},
    {'name': 'Watches', 'icon': 'watch', 'color': 'teal'},
    {'name': 'Earbuds', 'icon': 'headphones', 'color': 'purple'},
    {'name': 'Cameras', 'icon': 'camera', 'color': 'brown'},
    {'name': 'Fashion', 'icon': 'fashion', 'color': 'orange'},
    {'name': 'Shoes', 'icon': 'shoes', 'color': 'brown'},
    {'name': 'Bags', 'icon': 'bag', 'color': 'deepPurple'},
    {'name': 'Beauty', 'icon': 'beauty', 'color': 'pink'},
    {'name': 'Sports', 'icon': 'sports', 'color': 'green'},
    {'name': 'Toys', 'icon': 'toys', 'color': 'amber'},
    {'name': 'Grocery', 'icon': 'grocery', 'color': 'lime'},
  ];

  static List<CategoryItem> get _defaultItems => [
        for (final d in defaults)
          CategoryItem(
            id: '',
            name: d['name']!,
            iconKey: d['icon']!,
            colorKey: d['color']!,
          ),
      ];

  // ---------------------------------------------------------------
  // READ
  // ---------------------------------------------------------------

  static List<CategoryItem> _fromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return CategoryItem(
        id: doc.id,
        name: (data['name'] ?? '').toString(),
        iconKey: (data['iconKey'] ?? 'category').toString(),
        colorKey: (data['colorKey'] ?? 'red').toString(),
      );
    }).where((item) => item.name.trim().isNotEmpty).toList();
  }

  /// Raw list for the admin screen (no fallback).
  static Stream<List<CategoryItem>> adminStream() {
    return _col.orderBy('order').snapshots().map(_fromSnapshot);
  }

  /// List for the customer screens (Home, Categories, filters...).
  /// If the admin has not created any category yet, the default list
  /// is returned so the app never shows an empty category bar.
  static Stream<List<CategoryItem>> stream() {
    return _col.orderBy('order').snapshots().map((snapshot) {
      final items = _fromSnapshot(snapshot);
      return items.isEmpty ? _defaultItems : items;
    });
  }

  // ---------------------------------------------------------------
  // WRITE (admin only, protected by Firestore rules)
  // ---------------------------------------------------------------

  static Future<void> add({
    required String name,
    required String iconKey,
    required String colorKey,
    required int order,
  }) async {
    await _col.add({
      'name': name.trim(),
      'iconKey': iconKey,
      'colorKey': colorKey,
      'order': order,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  static Future<void> saveOrder(List<CategoryItem> items) async {
    final batch = FirebaseFirestore.instance.batch();

    for (var i = 0; i < items.length; i++) {
      batch.update(_col.doc(items[i].id), {'order': i});
    }

    await batch.commit();
  }

  static Future<void> seedDefaults() async {
    final batch = FirebaseFirestore.instance.batch();

    for (var i = 0; i < defaults.length; i++) {
      final d = defaults[i];

      batch.set(_col.doc(), {
        'name': d['name'],
        'iconKey': d['icon'],
        'colorKey': d['color'],
        'order': i,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}
