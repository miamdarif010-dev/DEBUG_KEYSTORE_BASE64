import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Push notifications for BuyNova.
///
/// Works with functions/push.js:
///  - saves this phone's token after login (savePushToken)
///  - removes it on logout (removePushToken)
///  - tells the app what to open when the user taps a notification
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FirebaseFunctions _fn =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  String? _token;
  bool _started = false;

  /// Call once, after Firebase.initializeApp().
  ///
  /// [onOpen] is called when the user taps a notification. `data` contains:
  ///   link      e.g. "buynova://p/<productId>" (empty if none)
  ///   type      "order_payment", "order_refund", "order_earning", "wallet" ...
  ///   orderId, productId
  ///
  /// [onForeground] (optional) is called when a push arrives while the app
  /// is open (Android does not show a system notification in that case).
  Future<void> init({
    required void Function(Map<String, dynamic> data) onOpen,
    void Function(String title, String body)? onForeground,
  }) async {
    if (_started) return;
    _started = true;

    final fm = FirebaseMessaging.instance;

    // Android 13+ asks the user for permission here.
    await fm.requestPermission();

    // Save the token every time a user logs in.
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) _saveCurrentToken();
    });

    // Token can change (reinstall, restore ...).
    fm.onTokenRefresh.listen((token) {
      _token = token;
      if (FirebaseAuth.instance.currentUser != null) _save(token);
    });

    // User tapped a notification while the app was in background.
    FirebaseMessaging.onMessageOpenedApp.listen((m) => onOpen(m.data));

    // User tapped a notification while the app was closed.
    final initial = await fm.getInitialMessage();
    if (initial != null) onOpen(initial.data);

    // Push received while the app is open.
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n != null && onForeground != null) {
        onForeground(n.title ?? '', n.body ?? '');
      }
    });
  }

  /// Call this BEFORE FirebaseAuth.instance.signOut().
  Future<void> unregister() async {
    try {
      final token = _token ?? await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _fn.httpsCallable('removePushToken').call({'token': token});
      }
    } catch (_) {}
  }

  Future<void> _saveCurrentToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      _token = token;
      await _save(token);
    } catch (_) {}
  }

  Future<void> _save(String token) async {
    try {
      await _fn.httpsCallable('savePushToken').call({'token': token});
    } catch (_) {}
  }
}
