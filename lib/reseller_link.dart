import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'product_details_page.dart';

/// CHANGE THIS to your Firebase Hosting domain, e.g. buynova-12345.web.app
const String kLinkHost = 'buynova-cc5dd.web.app';

const String _kFunctionsRegion = 'asia-northeast3';

/// Parsed deep link. kind = 'r' (reseller listing) or 'p' (normal product).
class ParsedLink {
  final String kind;
  final String id;

  const ParsedLink(this.kind, this.id);
}

class ResellerLink {
  /// Web link for one reseller listing (reseller_products document id).
  static String build(String listingId) {
    return 'https://$kLinkHost/r/${Uri.encodeComponent(listingId)}';
  }

  /// Web link for one normal product (products document id).
  static String buildProduct(String productId) {
    return 'https://$kLinkHost/p/${Uri.encodeComponent(productId)}';
  }

  /// Opens the phone share sheet (Messenger, WhatsApp, ...).
  static Future<void> share({
    required String listingId,
    required String productName,
  }) async {
    await Share.share('$productName\n${build(listingId)}');
  }

  /// Accepts:
  ///  buynova://r/<id>  buynova://p/<id>
  ///  https://<kLinkHost>/r/<id>  https://<kLinkHost>/p/<id>
  static ParsedLink? parse(Uri uri) {
    final segments = uri.pathSegments;

    if (uri.scheme == 'buynova') {
      if ((uri.host == 'r' || uri.host == 'p') &&
          segments.isNotEmpty &&
          segments[0].isNotEmpty) {
        return ParsedLink(uri.host, segments[0]);
      }
      return null;
    }

    if (uri.host != kLinkHost) return null;

    if (segments.length >= 2 &&
        (segments[0] == 'r' || segments[0] == 'p') &&
        segments[1].isNotEmpty) {
      return ParsedLink(segments[0], segments[1]);
    }

    return null;
  }
}

/// Listens for opened links and shows the product.
class ResellerLinkHandler {
  ResellerLinkHandler(this.navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;

  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _subscription;

  String? _lastId;
  DateTime? _lastTime;

  Future<void> start() async {
    // Listen first, so no link is missed while the initial link is read.
    _subscription = _appLinks.uriLinkStream.listen(
      (uri) => _handle(uri),
      onError: (Object e) => debugPrint('Link stream error: $e'),
    );

    try {
      final initial = await _appLinks.getInitialLink();

      if (initial != null) {
        // Cold start: give the home page a moment to appear first.
        await Future.delayed(const Duration(milliseconds: 700));
        await _handle(initial);
      }
    } catch (e) {
      debugPrint('Initial link failed: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
  }

  Future<void> _handle(Uri uri) async {
    final link = ResellerLink.parse(uri);

    if (link == null) return;

    // The initial link can arrive twice (initial + stream).
    final key = '${link.kind}:${link.id}';
    final now = DateTime.now();

    if (_lastId == key &&
        _lastTime != null &&
        now.difference(_lastTime!).inSeconds < 4) {
      return;
    }

    _lastId = key;
    _lastTime = now;

    await _open(link);
  }

  Future<void> _open(ParsedLink link) async {
    // Wait (up to ~3 seconds) until the Navigator is ready.
    for (int i = 0;
        i < 15 &&
            (navigatorKey.currentState == null ||
                navigatorKey.currentContext == null);
        i++) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    final navigator = navigatorKey.currentState;
    final context = navigatorKey.currentContext;

    if (navigator == null || context == null) return;

    try {
      final isProduct = link.kind == 'p';

      final result = await FirebaseFunctions.instanceFor(
        region: _kFunctionsRegion,
      )
          .httpsCallable(isProduct ? 'getProductListing' : 'getResellerListing')
          .call(
            isProduct ? {'productId': link.id} : {'listingId': link.id},
          );

      // Convert to plain Dart maps/lists.
      final json = jsonDecode(jsonEncode(result.data)) as Map<String, dynamic>;

      final product = Map<String, dynamic>.from(json['listing'] as Map);

      navigator.push(
        MaterialPageRoute(
          builder: (_) => ProductDetailsPage(
            productId: link.id,
            product: product,
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      _message(context, e.message ?? 'Could not open this product.');
    } catch (e) {
      _message(context, 'Could not open this product.');
    }
  }

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
