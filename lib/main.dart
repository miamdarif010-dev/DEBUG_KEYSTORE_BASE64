import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'home_page.dart';
import 'app_settings.dart';
import 'reseller_link.dart';
import 'services/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  await AppSettings.load();

  // AdMob শুরু করা। ব্যর্থ হলেও অ্যাপ চলবে।
  try {
    await MobileAds.instance.initialize();
  } catch (_) {}

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late final ResellerLinkHandler _linkHandler;

  @override
  void initState() {
    super.initState();

    _linkHandler = ResellerLinkHandler(_navigatorKey);

    // Start after the first frame so the Navigator exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _linkHandler.start();

      // Push notifications: token saving + what happens on tap.
      PushService.instance.init(
        onOpen: (data) {
          final link = (data['link'] ?? '').toString();
          if (link.isNotEmpty) {
            _linkHandler.openFromPush(link);
          }
        },
        onForeground: (title, body) {
          final ctx = _navigatorKey.currentContext;
          if (ctx == null) return;
          ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
            SnackBar(
              content: Text(body.isEmpty ? title : '$title\n$body'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    });
  }

  @override
  void dispose() {
    _linkHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.themeMode,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'BuyNova',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,

          themeMode: themeMode,

          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.redAccent,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),

          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.redAccent,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),

          home: const HomePage(),
        );
      },
    );
  }
}
