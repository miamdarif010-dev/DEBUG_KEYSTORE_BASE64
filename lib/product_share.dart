import 'package:share_plus/share_plus.dart';

/// Share helper used by Home page and Product Details page.
/// Works for every product: normal seller product (/p/) and
/// reseller listing (/r/).
class ProductShare {
  static const String base = 'https://buynova-cc5dd.web.app';

  static bool _isReseller(Map<String, dynamic> product) {
    return product['isResellerProduct'] == true ||
        (product['entrepreneurUid']?.toString().trim().isNotEmpty ?? false);
  }

  static String link({
    required String productId,
    required Map<String, dynamic> product,
  }) {
    if (_isReseller(product)) {
      final listingId = product['listingId']?.toString().trim() ?? '';
      final id = listingId.isNotEmpty ? listingId : productId;
      return '$base/r/${Uri.encodeComponent(id)}';
    }

    return '$base/p/${Uri.encodeComponent(productId)}';
  }

  static Future<void> share({
    required String productId,
    required Map<String, dynamic> product,
    required String name,
    required String formattedPrice,
  }) async {
    final url = link(productId: productId, product: product);

    await Share.share(
      '$name\nPrice: $formattedPrice\n\n$url',
      subject: name,
    );
  }
}
