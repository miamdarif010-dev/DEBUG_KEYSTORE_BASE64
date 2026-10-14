import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'home_page.dart';
import 'app_settings.dart';
import 'reseller_link.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  await AppSettings.load();

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
