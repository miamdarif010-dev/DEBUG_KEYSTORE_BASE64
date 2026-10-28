import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'home_page.dart';
import 'app_settings.dart';
import 'app_strings.dart';
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
          // User turned notifications off in Settings.
          if (!AppSettings.notifications.value) return;

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
    return ValueListenableBuilder<String>(
      valueListenable: AppSettings.language,
      builder: (context, language, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: AppSettings.themeMode,
          builder: (context, themeMode, child) {
            return MaterialApp(
              title: 'BuyNova',
              debugShowCheckedModeBanner: false,
              navigatorKey: _navigatorKey,

              // Language
              locale: AppStrings.localeFor(language),
              supportedLocales: const [
                Locale('en'),
                Locale('bn'),
                Locale('ko'),
              ],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],

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

              // Text Size slider from Settings
              builder: (context, child) {
                return ValueListenableBuilder<double>(
                  valueListenable: AppSettings.textScale,
                  builder: (context, scale, _) {
                    final mq = MediaQuery.of(context);
                    final system = mq.textScaler.scale(1.0);
                    return MediaQuery(
                      data: mq.copyWith(
                        textScaler: TextScaler.linear(system * scale),
                      ),
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
                );
              },

              home: const HomePage(),
            );
          },
        );
      },
    );
  }
}
