import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'services/supabase_service.dart';
import 'utils/app_theme.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'services/push_service.dart';
import 'l10n/generated/app_localizations.dart';

// ─── Screens ─────────────────────────────────────────────────
import 'screens/auth/login_screen.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/customer/review_screen.dart';
import 'screens/shared/profile_screen.dart';
import 'screens/shared/privacy_security_screen.dart';
import 'package:flutter/services.dart';

import 'screens/explore/store_route_loader.dart';
import 'screens/shared/my_queue_ticket_screen.dart';

import 'widgets/app_lock_wrapper.dart';

// ============================================================
// Ngam — Local Errands, Powered by Community
// Projek Individu CSC264
// ============================================================

// ─── Global Navigator Key ─────────────────────────────────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  
  // Load environment variables dulu
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}

  // Setup Supabase
  await SupabaseService.initialize();

  // Setup Push Notifications asynchronously without delaying initial UI mount
  PushService.initialize().catchError((e) {
    debugPrint("PushService initialization error: $e");
  });

  // Remove native splash immediately so UI paints frame 1 without delay
  FlutterNativeSplash.remove();

  // Apply Screen Security kalau on
  try {
    if (SecurityData.hideContentEnabled.value) {
      const securityChannel = MethodChannel('com.example.ngam/security');
      await securityChannel.invokeMethod('enableSecureMode');
    }
  } catch (e) {
    // Plugin mungkin tak jumpa kalau baru hot reload
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ms')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ms'),
      useOnlyLangCode: true,
      child: const NgamApp(),
    ),
  );
}

class NgamApp extends StatelessWidget {
  const NgamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Ngam',
            builder: (context, child) {
              return AppLockWrapper(child: child!);
            },
            localizationsDelegates: [
              ...context.localizationDelegates,
              AppLocalizations.delegate,
            ],
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,

            // ─── Dynamic Route Resolution (PWA & Deep Links) ───
            onGenerateRoute: (settings) {
              final uri = Uri.tryParse(settings.name ?? '') ?? Uri();
              final segments = uri.pathSegments;

              // 1. /store/:businessId?table=X&promo=Y
              if (segments.isNotEmpty && segments.first == 'store') {
                final businessId = segments.length > 1 ? segments[1] : '';
                final tableNumber = uri.queryParameters['table'];
                final promoCode = uri.queryParameters['promo'];
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => StoreRouteLoader(
                    businessId: businessId,
                    tableNumber: tableNumber,
                    promoCode: promoCode,
                  ),
                );
              }

              // 2. /queue/:businessId
              if (segments.isNotEmpty && segments.first == 'queue') {
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const MyQueueTicketScreen(),
                );
              }

              // 3. Named Static Routes (Seamless Dark Fade for Auth routes)
              switch (uri.path) {
                case '/login':
                  return PageRouteBuilder(
                    settings: settings,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(milliseconds: 180),
                    pageBuilder: (_, __, ___) => const LoginScreen(initialMode: AuthScreenMode.login),
                    transitionsBuilder: (_, animation, __, child) =>
                        FadeTransition(opacity: animation, child: child),
                  );
                case '/register':
                  return PageRouteBuilder(
                    settings: settings,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(milliseconds: 180),
                    pageBuilder: (_, __, ___) => const LoginScreen(initialMode: AuthScreenMode.register),
                    transitionsBuilder: (_, animation, __, child) =>
                        FadeTransition(opacity: animation, child: child),
                  );
                case '/forgot-password':
                  return PageRouteBuilder(
                    settings: settings,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(milliseconds: 180),
                    pageBuilder: (_, __, ___) => const LoginScreen(initialMode: AuthScreenMode.forgotPassword),
                    transitionsBuilder: (_, animation, __, child) =>
                        FadeTransition(opacity: animation, child: child),
                  );
                case '/customer-home':
                  return MaterialPageRoute(settings: settings, builder: (_) => const CustomerHomeScreen());
                case '/review':
                  return MaterialPageRoute(settings: settings, builder: (_) => const ReviewScreen());
                case '/profile':
                  return MaterialPageRoute(settings: settings, builder: (_) => const ProfileScreen());
              }

              // 4. Default / Home Fallback
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (auth.isInitializing) {
                      return const Scaffold(
                        backgroundColor: Color(0xFF0A0A0A),
                        body: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF2196F3),
                            strokeWidth: 2.5,
                          ),
                        ),
                      );
                    }
                    if (!auth.isLoggedIn) {
                      return const LoginScreen();
                    }
                    return const CustomerHomeScreen();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

