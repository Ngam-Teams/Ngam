import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' hide GlassCard;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/glass_card.dart';

// ============================================================
// Ngam App — Skrin Login
// ============================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/customer-home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GlassCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ─── Logo ──────────────────────────────
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset('assets/app.png', fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 16),
      
                        // ─── Nama App ──────────────────────────
                        Text(
                          'Ngam',
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'auth.welcome_subtitle'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 40),
      
                        // ─── Ruangan Email ─────────────────────
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'auth.email'.tr(),
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'auth.please_enter_email'.tr();
                            }
                            if (!value.contains('@')) {
                              return 'auth.valid_email'.tr();
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
      
                        // ─── Ruangan Password ──────────────────
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'auth.password'.tr(),
                            prefixIcon: const Icon(Icons.lock_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'auth.please_enter_password'.tr();
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // ─── Lupa Password ─────────────────────
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              // TODO: Kena hantar pegi skrin forgot password nanti
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'auth.forgot_password'.tr(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
      
                        // ─── Mesej Error ───────────────────────
                        Consumer<AuthProvider>(
                          builder: (context, auth, _) {
                            if (auth.error != null) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline,
                                          color: AppTheme.error, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          auth.error!,
                                          style: const TextStyle(
                                            color: AppTheme.error,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
      
                        // ─── Butang Login ──────────────────────
                        Consumer<AuthProvider>(
                          builder: (context, auth, _) {
                            return SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: auth.isLoading ? null : _handleLogin,
                                child: auth.isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text('auth.login'.tr()),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 32),

                        // ─── Login Guna Social Media ───────────
                        Row(
                          children: [
                            const Expanded(child: Divider(color: Colors.grey, thickness: 0.5)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'auth.or_continue_with'.tr(),
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(color: Colors.grey, thickness: 0.5)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () async {
                              final authProvider = context.read<AuthProvider>();
                              final success = await authProvider.signInWithGoogle();
                              if (success && mounted) {
                                Navigator.pushReplacementNamed(context, '/customer-home');
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const FaIcon(FontAwesomeIcons.google, size: 20),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('auth.google_signin'.tr()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
      
                        // ─── Link Sign Up ──────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'auth.no_account'.tr(),
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, '/register');
                              },
                              child: Text(
                                'auth.register'.tr(),
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // ─── Butang Atas Kanan (Theme & Bahasa) ───
                Positioned(
                  top: 16,
                  right: 24,
                  child: GlassContainer(
                    quality: GlassQuality.standard,
                    shape: LiquidRoundedSuperellipse(borderRadius: 24.0),
                    settings: LiquidGlassSettings(
                      thickness: 0.1,
                      blur: 15,
                      glassColor: Colors.transparent,
                      lightIntensity: isDark ? 0.1 : 0.2,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.7),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Butang Bahasa
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (context.locale.languageCode == 'en') {
                                context.setLocale(const Locale('ms'));
                              } else {
                                context.setLocale(const Locale('en'));
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedTranslate,
                                color: isDark ? Colors.white : Colors.black87,
                                size: 20,
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 20,
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                          // Butang Theme
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              themeProvider.toggleTheme();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: HugeIcon(
                                icon: isDark
                                    ? HugeIcons.strokeRoundedSun01
                                    : HugeIcons.strokeRoundedMoon02,
                                color: isDark ? Colors.white : Colors.black87,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
