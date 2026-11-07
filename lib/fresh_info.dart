import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// One selling unit of a Fresh product (kg, dozen ...).
class FreshUnit {
  final String key;
  final String label;
  final String shortName;

  const FreshUnit(this.key, this.label, this.shortName);
}

/// One fixed Fresh Bazar category.
class FreshCategory {
  final String key;
  final String label;
  final String english;
  final IconData icon;

  const FreshCategory(this.key, this.label, this.english, this.icon);
}

/// Small colored badge that tells how fresh a product still is.
class FreshBadge {
  final String text;
  final Color color;

  const FreshBadge(this.text, this.color);
}

/// Shared helpers for Fresh Bazar products:
/// unit names, packed / expiry dates and the freshness badge.
///
/// Firestore fields on a Fresh product:
///   isFastDelivery  true
///   unit            "kg" | "dozen" | "hali" | "piece" | "litre" | "pack"
///   packedDate      Timestamp (packing / harvest day)
///   expiryDate      Timestamp (last day the product is good)
class FreshInfo {
  FreshInfo._();

  static const List<FreshUnit> units = <FreshUnit>[
    FreshUnit('kg', 'কেজি', 'কেজি'),
    FreshUnit('piece', 'পিস', 'পিস'),
    FreshUnit('dozen', 'ডজন', 'ডজন'),
    FreshUnit('hali', 'হালি (৪টি)', 'হালি'),
    FreshUnit('litre', 'লিটার', 'লিটার'),
    FreshUnit('pack', 'প্যাক', 'প্যাক'),
  ];

  static const String defaultUnit = 'kg';

  /// Fixed Fresh Bazar categories (not managed by the admin).
  static const List<FreshCategory> categories = <FreshCategory>[
    FreshCategory('vegetables', 'সবজি', 'Vegetables', Icons.grass),
    FreshCategory('fruits', 'ফল', 'Fruits', Icons.apple),
    FreshCategory('fish', 'মাছ', 'Fish', Icons.set_meal_outlined),
    FreshCategory('meat', 'মাংস', 'Meat', Icons.kebab_dining_outlined),
    FreshCategory('eggs', 'ডিম', 'Eggs', Icons.egg_outlined),
    FreshCategory('dairy', 'দুধ ও দুগ্ধজাত', 'Dairy', Icons.local_drink_outlined),
    FreshCategory('grocery', 'চাল-ডাল-তেল', 'Grocery', Icons.rice_bowl_outlined),
    FreshCategory('spices', 'মসলা', 'Spices', Icons.spa_outlined),
    FreshCategory('others', 'অন্যান্য', 'Others', Icons.more_horiz),
  ];

  static FreshCategory? categoryOf(dynamic key) {
    final k = key?.toString().trim() ?? '';

    for (final c in categories) {
      if (c.key == k) return c;
    }

    return null;
  }

  /// Bengali label of a stored category key ("fish" -> "মাছ").
  static String categoryLabel(dynamic key) => categoryOf(key)?.label ?? '';

  /// Short Bengali unit name for a stored key ("kg" -> "কেজি").
  static String unitShort(dynamic key) {
    final k = key?.toString().trim() ?? '';

    for (final u in units) {
      if (u.key == k) return u.shortName;
    }

    return '';
  }

  static DateTime? dateOf(dynamic value) {
    if (value is Timestamp) return value.toDate();

    if (value is DateTime) return value;

    return null;
  }

  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime today() => dayOnly(DateTime.now());

  /// 07/11/2026
  static String formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');

    return '$day/$month/${d.year}';
  }

  static DateTime? expiryOf(Map<String, dynamic> data) =>
      dateOf(data['expiryDate']);

  static DateTime? packedOf(Map<String, dynamic> data) =>
      dateOf(data['packedDate']);

  /// Days until the expiry day. 0 = last day is today, negative = expired.
  /// null when the product has no expiry date.
  static int? daysLeft(Map<String, dynamic> data) {
    final expiry = expiryOf(data);

    if (expiry == null) return null;

    return dayOnly(expiry).difference(today()).inDays;
  }

  static bool hasExpiry(Map<String, dynamic> data) => expiryOf(data) != null;

  static bool isExpired(Map<String, dynamic> data) {
    final left = daysLeft(data);

    return left != null && left < 0;
  }

  static FreshBadge? badge(Map<String, dynamic> data) {
    final left = daysLeft(data);

    if (left == null) return null;

    if (left < 0) {
      return const FreshBadge('মেয়াদ শেষ', Color(0xFFD32F2F));
    }

    if (left == 0) {
      return const FreshBadge('আজই শেষ দিন', Color(0xFFEF6C00));
    }

    if (left <= 2) {
      return FreshBadge('$left দিন বাকি', const Color(0xFFEF6C00));
    }

    return FreshBadge('$left দিন বাকি', const Color(0xFF2E7D32));
  }
}
