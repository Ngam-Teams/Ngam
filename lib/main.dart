import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'providers/auth_provider.dart';
import 'providers/gig_provider.dart';
import 'providers/theme_provider.dart';
import 'services/supabase_service.dart';
import 'utils/app_theme.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'services/push_service.dart';
import 'l10n/generated/app_localizations.dart';

// ─── Screens ─────────────────────────────────────────────────
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/customer/post_task_screen.dart';
import 'screens/customer/task_posted_screen.dart';
import 'screens/customer/my_tasks_screen.dart';
import 'screens/customer/order_status_screen.dart';
import 'screens/customer/review_screen.dart';
import 'screens/shared/profile_screen.dart';
import 'screens/shared/privacy_security_screen.dart';
import 'package:flutter/services.dart';

import 'widgets/app_lock_wrapper.dart';

// ============================================================
// Ngam — Local Errands, Powered by Community
// Projek Individu CSC264
// ============================================================

// ─── Global Navigator Key ─────────────────────────────────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await EasyLocalization.ensureInitialized();
  
  // Load environment variables dulu
  await dotenv.load(fileName: ".env");

  // Setup Supabase
  await SupabaseService.initialize();

  // Setup Push Notifications
  await PushService.initialize();

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
        ChangeNotifierProvider(create: (_) => GigProvider()),
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

            // ─── Initial Route ─────────────────────
            home: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.isInitializing) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                if (!auth.isLoggedIn) {
                  return const LoginScreen();
                }

                return const CustomerHomeScreen();
              },
            ),

            // ─── Named Routes ──────────────────────
            routes: {
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/customer-home': (context) => const CustomerHomeScreen(),
              '/post-task': (context) => const PostTaskScreen(),
              '/task-posted': (context) => const TaskPostedScreen(),
              '/my-tasks': (context) => const MyTasksScreen(),
              '/order-status': (context) => const OrderStatusScreen(),
              '/review': (context) => const ReviewScreen(),
              

              '/profile': (context) => const ProfileScreen(),
            },
          );
        },
      ),
    );
  }
}

