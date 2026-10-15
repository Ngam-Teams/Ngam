import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';

// ============================================================
// Ngam App — Skrin Register (Aligned with Modern Ngam Glass)
// ============================================================

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Ngam Signature Blue palette
  static const Color accentBlue = Color(0xFF2196F3);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color bgDark = Color(0xFF0A0A0A);

  @override
  void initState() {
    super.initState();
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
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      role: UserRole.customer,
    );

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/customer-home');
    }
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.inter(
        color: textSecondary.withValues(alpha: 0.6),
        fontSize: 13,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      prefixIcon: Icon(icon, color: textSecondary, size: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: textSecondary,
                size: 18,
              ),
              onPressed: onToggle,
            )
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: accentBlue,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final size = MediaQuery.of(context).size;

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
                      Color(0x99000000), // rgba(0, 0, 0, 0.6)
                      Color(0xB3000000), // rgba(0, 0, 0, 0.7)
                    ],
                  ),
                ),
              ),
            ),

            // ─── 2. Top-Left Back Button ───
            Positioned(
              top: 24,
              left: 24,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowLeft01,
                        color: textPrimary,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
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
                          icon: const HugeIcon(
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

            // ─── 4. Main Scrollable Form Card ───
            Positioned.fill(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 76),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  width: 1,
                                ),
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Mini Logo Badge
                                    Container(
                                      width: 52,
                                      height: 52,
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
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'CREATE ACCOUNT',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 3.0,
                                        color: accentBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Daftar akaun komuniti Ngam anda',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        color: textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // ─── Nama Penuh ───
                                    TextFormField(
                                      controller: _nameController,
                                      style: GoogleFonts.inter(color: textPrimary, fontSize: 13.5),
                                      textCapitalization: TextCapitalization.words,
                                      decoration: _inputDecoration(
                                        hintText: 'Nama Penuh',
                                        icon: Icons.person_outline,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Sila masukkan nama penuh';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // ─── Email ───
                                    TextFormField(
                                      controller: _emailController,
                                      style: GoogleFonts.inter(color: textPrimary, fontSize: 13.5),
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: _inputDecoration(
                                        hintText: 'Alamat Emel',
                                        icon: Icons.email_outlined,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Sila masukkan alamat emel';
                                        }
                                        if (!value.contains('@')) {
                                          return 'Emel tidak sah';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // ─── Nombor Telefon ───
                                    TextFormField(
                                      controller: _phoneController,
                                      style: GoogleFonts.inter(color: textPrimary, fontSize: 13.5),
                                      keyboardType: TextInputType.phone,
                                      decoration: _inputDecoration(
                                        hintText: 'Nombor Telefon (cth: 0123456789)',
                                        icon: Icons.phone_outlined,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Sila masukkan nombor telefon';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // ─── Password ───
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      style: GoogleFonts.inter(color: textPrimary, fontSize: 13.5),
                                      decoration: _inputDecoration(
                                        hintText: 'Kata Laluan (min 6 aksara)',
                                        icon: Icons.lock_outline,
                                        isPassword: true,
                                        obscure: _obscurePassword,
                                        onToggle: () {
                                          setState(() {
                                            _obscurePassword = !_obscurePassword;
                                          });
                                        },
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Sila masukkan kata laluan';
                                        }
                                        if (value.length < 6) {
                                          return 'Kata laluan sekurang-kurangnya 6 aksara';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // ─── Sahkan Password ───
                                    TextFormField(
                                      controller: _confirmPasswordController,
                                      obscureText: _obscureConfirmPassword,
                                      style: GoogleFonts.inter(color: textPrimary, fontSize: 13.5),
                                      decoration: _inputDecoration(
                                        hintText: 'Sahkan Kata Laluan',
                                        icon: Icons.lock_outline,
                                        isPassword: true,
                                        obscure: _obscureConfirmPassword,
                                        onToggle: () {
                                          setState(() {
                                            _obscureConfirmPassword = !_obscureConfirmPassword;
                                          });
                                        },
                                      ),
                                      validator: (value) {
                                        if (value != _passwordController.text) {
                                          return 'Kata laluan tidak sepadan';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),

                                    // ─── Error Message Display ───
                                    Consumer<AuthProvider>(
                                      builder: (context, auth, _) {
                                        if (auth.error != null) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            margin: const EdgeInsets.only(bottom: 12),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.red.withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.error_outline,
                                                  color: Colors.redAccent,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    auth.error!,
                                                    style: GoogleFonts.inter(
                                                      color: Colors.redAccent,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),

                                    // ─── Butang Sign Up ───
                                    Consumer<AuthProvider>(
                                      builder: (context, auth, _) {
                                        return SizedBox(
                                          height: 48,
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: auth.isLoading ? null : _handleRegister,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: accentBlue,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                            ),
                                            child: auth.isLoading
                                                ? const SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : Text(
                                                    'CREATE ACCOUNT',
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

                                    // ─── Divider ───
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            height: 1,
                                            color: Colors.white.withValues(alpha: 0.1),
                                          ),
                                        ),
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
                                        Expanded(
                                          child: Container(
                                            height: 1,
                                            color: Colors.white.withValues(alpha: 0.1),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // ─── Google Sign-In Button (Dark Glass Pill) ───
                                    SizedBox(
                                      height: 46,
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          final authProvider = context.read<AuthProvider>();
                                          final success = await authProvider.signInWithGoogle();
                                          if (success && authProvider.user != null && context.mounted) {
                                            Navigator.pushReplacementNamed(context, '/customer-home');
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
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
                                    ),
                                    const SizedBox(height: 20),

                                    // ─── Link Balik ke Login ───
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Already have an account? ',
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            color: textSecondary,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => Navigator.pop(context),
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
                          ),
                        ),
                      ),
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
}
