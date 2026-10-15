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

class ResellerLink {
  /// Web link for one reseller listing (reseller_products document id).
  /// It opens the web page in the browser; the page has an "Open app" button.
  static String build(String listingId) {
    return 'https://$kLinkHost/r/${Uri.encodeComponent(listingId)}';
  }

  /// Opens the phone share sheet (Messenger, WhatsApp, ...).
  static Future<void> share({
    required String listingId,
    required String productName,
  }) async {
    await Share.share('$productName\n${build(listingId)}');
  }

  /// Accepts buynova://r/<listingId> (from the web page's "Open app" button)
  /// and https://<kLinkHost>/r/<listingId>.
  static String? parseListingId(Uri uri) {
    final segments = uri.pathSegments;

    if (uri.scheme == 'buynova') {
      if (uri.host == 'r' && segments.isNotEmpty && segments[0].isNotEmpty) {
        return segments[0];
      }
      return null;
    }

    if (uri.host != kLinkHost) return null;

    if (segments.length >= 2 && segments[0] == 'r' && segments[1].isNotEmpty) {
      return segments[1];
    }

    return null;
  }
}

/// Listens for opened links and shows the reseller product.
class ResellerLinkHandler {
  ResellerLinkHandler(this.navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;

  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _subscription;

  String? _lastId;
  DateTime? _lastTime;

  Future<void> start() async {
    try {
      final initial = await _appLinks.getInitialLink();

      if (initial != null) {
        await _handle(initial);
      }
    } catch (e) {
      debugPrint('Initial link failed: $e');
    }

    _subscription = _appLinks.uriLinkStream.listen(
      (uri) => _handle(uri),
      onError: (Object e) => debugPrint('Link stream error: $e'),
    );
  }

  void dispose() {
    _subscription?.cancel();
  }

  Future<void> _handle(Uri uri) async {
    final id = ResellerLink.parseListingId(uri);

    if (id == null) return;

    // The initial link can arrive twice (initial + stream).
    final now = DateTime.now();

    if (_lastId == id &&
        _lastTime != null &&
        now.difference(_lastTime!).inSeconds < 4) {
      return;
    }

    _lastId = id;
    _lastTime = now;

    await _open(id);
  }

  Future<void> _open(String listingId) async {
    final navigator = navigatorKey.currentState;
    final context = navigatorKey.currentContext;

    if (navigator == null || context == null) return;

    try {
      final result = await FirebaseFunctions.instanceFor(
        region: _kFunctionsRegion,
      ).httpsCallable('getResellerListing').call({'listingId': listingId});

      // Convert to plain Dart maps/lists.
      final json = jsonDecode(jsonEncode(result.data)) as Map<String, dynamic>;

      final product = Map<String, dynamic>.from(json['listing'] as Map);

      navigator.push(
        MaterialPageRoute(
          builder: (_) => ProductDetailsPage(
            productId: listingId,
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
