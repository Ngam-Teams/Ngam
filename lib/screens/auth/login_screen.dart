import '../../l10n/generated/app_localizations.dart';
import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';

// =============================================================================
// Ngam App — Unified Auth Portal (Static Left Branding + Dynamic Right Auth Card)
// =============================================================================

enum AuthScreenMode { login, register, forgotPassword }

class LoginScreen extends StatefulWidget {
  final AuthScreenMode initialMode;
  const LoginScreen({super.key, this.initialMode = AuthScreenMode.login});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AuthScreenMode _currentMode;

  // Login controllers
  final _loginFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Register controllers
  final _regFormKey = GlobalKey<FormState>();
  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  bool _regObscurePassword = true;

  // Forgot Password controllers
  final _forgotFormKey = GlobalKey<FormState>();
  final _forgotEmailController = TextEditingController();
  bool _forgotEmailSent = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Ngam Signature Blue palette
  static const Color accentBlue = Color(0xFF2196F3);
  static const Color accentBlueGlow = Color(0xFF42A5F5);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color bgDark = Color(0xFF0A0A0A);

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _forgotEmailController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/customer-home');
    }
  }

  Future<void> _handleRegister() async {
    if (!_regFormKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signUp(
      email: _regEmailController.text.trim(),
      password: _regPasswordController.text,
      name: _regNameController.text.trim(),
      phone: 'N/A',
      role: UserRole.customer,
    );

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/customer-home');
    }
  }

  Future<void> _handleForgotPassword() async {
    if (!_forgotFormKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resetPassword(_forgotEmailController.text.trim());

    if (success && mounted) {
      setState(() {
        _forgotEmailSent = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 960;

    return Scaffold(
      backgroundColor: bgDark,
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          children: [
            // ─── 1. Cinematic Background Image ───
            Positioned.fill(
              child: Image.asset(
                'assets/admin_hero_bg.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF080808),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x99000000),
                      Color(0xB3000000),
                    ],
                  ),
                ),
              ),
            ),

            // ─── 2. Main Portal Fixed Layout ───
            Positioned.fill(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: isDesktop
                      ? _buildDesktopLayout(context)
                      : _buildMobileLayout(context),
                ),
              ),
            ),

            // ─── Top-Left Back to Home Button (Guest Mode) ───
            Positioned(
              top: 24,
              left: 28,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: IconButton(
                      tooltip: 'Laman Utama (Home)',
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedHome01,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          Navigator.of(context).pushReplacementNamed('/customer-home');
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),

            // ─── 3. Top-Right Language & Theme Control ───
            Positioned(
              top: 24,
              right: 28,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Language button
                        IconButton(
                          tooltip: 'Language',
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedTranslate,
                            color: textPrimary,
                            size: 18,
                          ),
                          onPressed: () {
                            if (context.locale.languageCode == 'en') {
                              context.setLocale(const Locale('ms'));
                            } else {
                              context.setLocale(const Locale('en'));
                            }
                          },
                        ),
                        Container(
                          width: 1,
                          height: 16,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        // Theme button
                        IconButton(
                          tooltip: 'Theme',
                          icon: HugeIcon(
                            icon: isDark
                                ? HugeIcons.strokeRoundedSun01
                                : HugeIcons.strokeRoundedMoon02,
                            color: textPrimary,
                            size: 18,
                          ),
                          onPressed: () {
                            themeProvider.toggleTheme();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DESKTOP LAYOUT (Static Left Branding Banner + Dynamic Right Auth Card)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        // Left Branding Section (Permanently Static & Fixed)
        Expanded(
          flex: 12,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  border: Border(
                    right: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Logo Group
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Circular Silver Logo Badge
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.06),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Ngam',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'NGAM PORTAL',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 8.0,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Satu platform komuniti pintar untuk pesanan,\ntempahan, servis tempatan dan perkhidmatan tanpa had.',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            height: 1.6,
                            color: textSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),

                    // Bottom Branding Footer
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '© 2026 Ngam Community System\nSmart Community & Service Platform',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.6,
                            letterSpacing: 0.8,
                            color: Colors.white.withValues(alpha: 0.4),
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

        // Right Auth Section (Switches between Login, Register, Forgot Password)
        Expanded(
          flex: 11,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withValues(alpha: 0.32),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: _buildRightSideCard(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MOBILE LAYOUT
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mini Logo Badge (Static at top)
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Ngam',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'NGAM PORTAL',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6.0,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Dynamic Card Switcher
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: _buildRightSideCard(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ROUTE CARD SELECTOR
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildRightSideCard(BuildContext context) {
    switch (_currentMode) {
      case AuthScreenMode.register:
        return _buildRegisterCard(context);
      case AuthScreenMode.forgotPassword:
        return _buildForgotPasswordCard(context);
      case AuthScreenMode.login:
        return _buildLoginCard(context);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. THE LOGIN CARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildLoginCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return KeyedSubtree(
      key: const ValueKey('login_card'),
      child: _buildCardShell(
        child: Form(
          key: _loginFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                (l10n?.authLogin ?? 'USER LOGIN').toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Access your account and manage orders seamlessly.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Email Address
              Text(
                (l10n?.authEmail ?? 'EMAIL ADDRESS').toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                style: GoogleFonts.inter(color: textPrimary, fontSize: 13.5),
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(
                  hintText: 'alex.rivera@company.com',
                  prefixIcon: HugeIcons.strokeRoundedMail01,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Sila masukkan emel';
                  if (!value.contains('@')) return 'Emel tidak sah';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Password
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    (l10n?.authPassword ?? 'PASSWORD').toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentMode = AuthScreenMode.forgotPassword;
                      });
                    },
                    child: Text(
                      l10n?.authForgotPassword ?? 'Forgot?',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: accentBlueGlow,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: GoogleFonts.inter(color: textPrimary, fontSize: 13.5),
                decoration: _inputDecoration(
                  hintText: '••••••••',
                  prefixIcon: HugeIcons.strokeRoundedLockKey,
                  isPassword: true,
                  obscure: _obscurePassword,
                  onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (value) => (value == null || value.isEmpty) ? 'Sila masukkan kata laluan' : null,
              ),
              const SizedBox(height: 24),

              // Error Message
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  if (auth.error != null) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        auth.error!,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFF5252),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Sign In Button
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  return SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentBlue,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: accentBlue.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          : Text(
                              (l10n?.authLogin ?? 'SIGN IN').toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.0,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // Divider
              _buildDivider(),
              const SizedBox(height: 12),

              // Google Button
              _buildGoogleButton(),
              const SizedBox(height: 18),

              // Footer: Switch to Register
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    (l10n?.authNoAccount != null ? '${l10n!.authNoAccount} ' : "Don't have an account? "),
                    style: GoogleFonts.inter(fontSize: 12.5, color: textSecondary),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentMode = AuthScreenMode.register;
                      });
                    },
                    child: Text(
                      l10n?.authRegister ?? 'Sign Up',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: accentBlue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Terokai Tanpa Log Masuk (Guest Mode Button - Clean Minimalist)
              OutlinedButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacementNamed('/customer-home');
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                ),
                child: Text(
                  'Terokai Sebagai Tetamu (Guest)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. THE REGISTER CARD (3 Clean Fields: Name, Email, Password)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildRegisterCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return KeyedSubtree(
      key: const ValueKey('register_card'),
      child: _buildCardShell(
        child: Form(
          key: _regFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                (l10n?.authCreateAccount ?? 'CREATE ACCOUNT').toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Join the Ngam community and start exploring services.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Field 1: Full Name
              Text(
                (l10n?.authFullName ?? 'FULL NAME').toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _regNameController,
                style: GoogleFonts.inter(color: textPrimary, fontSize: 13.5),
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration(
                  hintText: 'Ahmad Faiz',
                  prefixIcon: HugeIcons.strokeRoundedUser,
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Sila masukkan nama anda' : null,
              ),
              const SizedBox(height: 14),

              // Field 2: Email Address
              Text(
                (l10n?.authEmail ?? 'EMAIL ADDRESS').toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _regEmailController,
                style: GoogleFonts.inter(color: textPrimary, fontSize: 13.5),
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(
                  hintText: 'nama@domain.com',
                  prefixIcon: HugeIcons.strokeRoundedMail01,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Sila masukkan emel';
                  if (!val.contains('@')) return 'Emel tidak sah';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Field 3: Password
              Text(
                (l10n?.authPassword ?? 'PASSWORD').toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _regPasswordController,
                obscureText: _regObscurePassword,
                style: GoogleFonts.inter(color: textPrimary, fontSize: 13.5),
                decoration: _inputDecoration(
                  hintText: '••••••••',
                  prefixIcon: HugeIcons.strokeRoundedLockKey,
                  isPassword: true,
                  obscure: _regObscurePassword,
                  onToggle: () => setState(() => _regObscurePassword = !_regObscurePassword),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Sila masukkan kata laluan';
                  if (val.length < 6) return 'Kata laluan sekurang-kurangnya 6 aksara';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Error Message
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  if (auth.error != null) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        auth.error!,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFF5252),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Submit Button
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  return SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentBlue,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: accentBlue.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          : Text(
                              (l10n?.authCreateAccount ?? 'CREATE ACCOUNT').toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.0,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              _buildDivider(),
              const SizedBox(height: 12),
              _buildGoogleButton(),
              const SizedBox(height: 18),

              // Footer: Switch to Login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    (l10n?.authHaveAccount != null ? '${l10n!.authHaveAccount} ' : 'Already have an account? '),
                    style: GoogleFonts.inter(fontSize: 12.5, color: textSecondary),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentMode = AuthScreenMode.login;
                      });
                    },
                    child: Text(
                      'Sign In',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: accentBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. THE FORGOT PASSWORD CARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildForgotPasswordCard(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('forgot_card'),
      child: _buildCardShell(
        child: _forgotEmailSent ? _buildForgotSuccessView() : _buildForgotFormView(),
      ),
    );
  }

  Widget _buildForgotFormView() {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _forgotFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentBlue.withValues(alpha: 0.12),
                border: Border.all(color: accentBlue.withValues(alpha: 0.35)),
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedLockPassword,
                  color: accentBlue,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'RESET PASSWORD',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Masukkan alamat emel untuk menerima pautan penetapan semula kata laluan.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Email Input
          Text(
            (l10n?.authEmail ?? 'EMAIL ADDRESS').toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _forgotEmailController,
            style: GoogleFonts.inter(color: textPrimary, fontSize: 13.5),
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration(hintText: 'nama@domain.com', prefixIcon: HugeIcons.strokeRoundedMail01),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Sila masukkan emel';
              if (!val.contains('@')) return 'Emel tidak sah';
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Submit Button
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              return SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _handleForgotPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: auth.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        )
                      : Text(
                          'SEND RESET LINK',
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                            color: Colors.white,
                          ),
                        ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),

          // Back to Login Link
          Center(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentMode = AuthScreenMode.login;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, size: 14, color: textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Back to Sign In',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForgotSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF44CF6C).withValues(alpha: 0.15),
              border: Border.all(color: const Color(0xFF44CF6C).withValues(alpha: 0.4)),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                color: Color(0xFF44CF6C),
                size: 30,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Pautan Telah Dihantar!',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sila semak peti masuk emel ${_forgotEmailController.text.trim()} untuk arahan penetapan semula kata laluan anda.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _currentMode = AuthScreenMode.login;
                _forgotEmailSent = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Text(
              'BACK TO SIGN IN',
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CARD SHELL & REUSABLE DECORATIONS
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCardShell({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 70,
                offset: const Offset(0, 25),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 26),
          child: child,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    List<List<dynamic>>? prefixIcon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.inter(
        color: Colors.white.withValues(alpha: 0.3),
        fontSize: 13,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      prefixIcon: prefixIcon != null
          ? UnconstrainedBox(
              child: HugeIcon(
                icon: prefixIcon,
                color: textSecondary,
                size: 18,
              ),
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      suffixIcon: isPassword
          ? IconButton(
              icon: HugeIcon(
                icon: obscure ? HugeIcons.strokeRoundedViewOffSlash : HugeIcons.strokeRoundedView,
                color: textSecondary,
                size: 18,
              ),
              onPressed: onToggle,
            )
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accentBlue, width: 1.5),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.1))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'or',
            style: GoogleFonts.inter(
              color: textSecondary.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.1))),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: () async {
          final authProvider = context.read<AuthProvider>();
          final nav = Navigator.of(context);
          final success = await authProvider.signInWithGoogle();
          if (success && authProvider.user != null && mounted) {
            nav.pushReplacementNamed('/customer-home');
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          backgroundColor: Colors.white.withValues(alpha: 0.04),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/google_logo.png',
              width: 18,
              height: 18,
            ),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
