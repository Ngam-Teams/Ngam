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
import 'screens/auth/reset_password_screen.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/customer/review_screen.dart';
import 'screens/shared/profile_screen.dart';
import 'screens/shared/privacy_security_screen.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/explore/store_route_loader.dart';
import 'screens/shared/my_queue_ticket_screen.dart';
import 'screens/customer/post_route_loader.dart';
import 'core/router/url_strategy.dart';

import 'widgets/app_lock_wrapper.dart';

// ============================================================
// Ngam — Local Errands, Powered by Community
// Projek Individu CSC264
// ============================================================

// ─── Global Navigator Key ─────────────────────────────────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  setCleanUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge transparent status bar & dark navigation bar matching website (#0A0A14)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF0A0A14),
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  await EasyLocalization.ensureInitialized();
  
  // Load environment variables dulu
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}

  // Setup Supabase
  await SupabaseService.initialize();

  // Listen for Supabase password recovery event (bila user tekan link reset emel)
  SupabaseService.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.passwordRecovery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.pushNamed('/reset-password');
      });
    }
  });

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
            onGenerateInitialRoutes: (String initialRoute) {
              // Shortcut deep links (/tab/...) open ONLY the target tab (no stacked intermediate routes).
              if (initialRoute.startsWith('/tab/')) {
                return [_generateRoute(RouteSettings(name: initialRoute))!];
              }
              final target = _generateRoute(RouteSettings(name: initialRoute))!;
              if (initialRoute == '/') return [target];
              return [_generateRoute(const RouteSettings(name: '/'))!, target];
            },
            onGenerateRoute: _generateRoute,
          );
        },
      ),
    );
  }
}


/// Resolves all named routes (PWA deep links, shortcuts, store links).
Route<dynamic>? _generateRoute(RouteSettings settings) {
              final uri = Uri.tryParse(settings.name ?? '') ?? Uri();
              final segments = uri.pathSegments;

              // 0. Named Static Routes (Seamless Dark Fade for Auth routes)
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
                case '/reset-password':
                  return PageRouteBuilder(
                    settings: settings,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(milliseconds: 180),
                    pageBuilder: (_, __, ___) => const ResetPasswordScreen(),
                    transitionsBuilder: (_, animation, __, child) =>
                        FadeTransition(opacity: animation, child: child),
                  );
                case '/tab/discover':
                  return MaterialPageRoute(settings: settings, builder: (_) => const CustomerHomeScreen(initialIndex: 1));
                case '/tab/feed':
                  return MaterialPageRoute(settings: settings, builder: (_) => const CustomerHomeScreen(initialIndex: 2));
                case '/tab/inbox':
                  return MaterialPageRoute(settings: settings, builder: (_) => const CustomerHomeScreen(initialIndex: 3));
                case '/tab/profile':
                  return MaterialPageRoute(settings: settings, builder: (_) => const CustomerHomeScreen(initialIndex: 4));
                case '/customer-home':
                  return MaterialPageRoute(settings: settings, builder: (_) => const CustomerHomeScreen());
                case '/review':
                  return MaterialPageRoute(settings: settings, builder: (_) => const ReviewScreen());
                case '/profile':
                  return MaterialPageRoute(settings: settings, builder: (_) => const ProfileScreen());
              }

              // Deep Link Custom Scheme: ngam://reset-password
              if (uri.scheme == 'ngam' && uri.host == 'reset-password') {
                return PageRouteBuilder(
                  settings: settings,
                  transitionDuration: const Duration(milliseconds: 200),
                  reverseTransitionDuration: const Duration(milliseconds: 180),
                  pageBuilder: (_, __, ___) => const ResetPasswordScreen(),
                  transitionsBuilder: (_, animation, __, child) =>
                      FadeTransition(opacity: animation, child: child),
                );
              }

              final tableNumber = uri.queryParameters['table'];
              final promoCode = uri.queryParameters['promo'] ?? uri.queryParameters['voucher'];

              // 1. /@:handle or /@:handle?table=X&promo=Y (e.g. /@pisangkrispy?table=1)
              if (segments.isNotEmpty && Uri.decodeComponent(segments.first).startsWith('@')) {
                final rawHandle = Uri.decodeComponent(segments.first).substring(1);
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => StoreRouteLoader(
                    businessId: rawHandle,
                    tableNumber: tableNumber,
                    promoCode: promoCode,
                  ),
                );
              }

              // 2. /c/:handle or /store/:id or /shop/:id (e.g. /c/pisangkrispy?table=1)
              if (segments.isNotEmpty && (segments.first == 'c' || segments.first == 'store' || segments.first == 'shop')) {
                final businessId = segments.length > 1 ? segments[1] : '';
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => StoreRouteLoader(
                    businessId: businessId,
                    tableNumber: tableNumber,
                    promoCode: promoCode,
                  ),
                );
              }

              // 3. /queue/:businessId or /q/:businessId (e.g. /q/@pisangkrispy or /q/pisangkrispy or /queue/pisangkrispy)
              if (segments.isNotEmpty && (segments.first == 'queue' || segments.first == 'q')) {
                final businessId = segments.length > 1 ? segments[1] : '';
                if (businessId.isNotEmpty) {
                  return MaterialPageRoute(
                    settings: settings,
                    builder: (_) => StoreRouteLoader(
                      businessId: businessId.replaceFirst('@', ''),
                      tableNumber: tableNumber,
                      promoCode: promoCode,
                    ),
                  );
                }
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const MyQueueTicketScreen(),
                );
              }

              // 4. /p/:id or /post/:id (e.g. /p/1 or /post/uuid)
              if (segments.isNotEmpty && (segments.first == 'p' || segments.first == 'post')) {
                final postId = segments.length > 1 ? segments[1] : '';
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => PostRouteLoader(postId: postId),
                );
              }

              // 5. /voucher/:code or /promo/:code
              if (segments.isNotEmpty && (segments.first == 'voucher' || segments.first == 'promo')) {
                final code = segments.length > 1 ? segments[1] : '';
                final store = uri.queryParameters['store'] ?? uri.queryParameters['shop'] ?? '';
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => StoreRouteLoader(
                    businessId: store.isNotEmpty ? store : code,
                    promoCode: code,
                  ),
                );
              }

              // 6. Clean handle fallback (e.g. /pisangkrispy?table=1) where first segment is NOT reserved
              const reservedRoutes = {
                'tab', 'q', 'queue', 'login', 'register', 'forgot-password', 'reset-password',
                'customer-home', 'review', 'profile', 'explore', 'bookings',
                'cart', 'chat', 'wallet', 'orders', 'notifications', 'search',
                'privacy', 'terms', 'support', 'about', 'feed', 'api', 'assets',
                'p', 'post'
              };
              if (segments.isNotEmpty && !reservedRoutes.contains(segments.first.toLowerCase())) {
                final rawHandle = Uri.decodeComponent(segments.first);
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => StoreRouteLoader(
                    businessId: rawHandle,
                    tableNumber: tableNumber,
                    promoCode: promoCode,
                  ),
                );
              }

              // 4. Default / Home Fallback (Allows public & guest access to satisfy Google OAuth Branding Verification)
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
                    return const CustomerHomeScreen();
                  },
                ),
              );
}
