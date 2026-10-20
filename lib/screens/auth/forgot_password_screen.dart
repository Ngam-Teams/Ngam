import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/glass_toast.dart';

// ============================================================
// Ngam App — Skrin Lupa Kata Laluan (Modern Glass Edition)
// ============================================================

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _inputController = TextEditingController();
  bool _emailSent = false;
  String _recoveryMode = 'email'; // 'email' or 'phone'
  String? _recoveredMaskedEmail;

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
    _inputController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final input = _inputController.text.trim();

    if (_recoveryMode == 'phone') {
      final res = await authProvider.lookupAccountByPhone(input);
      if (!mounted) return;

      if (res['success'] == true) {
        final targetEmail = res['email']?.toString() ?? '';
        _recoveredMaskedEmail = res['masked_email']?.toString() ?? targetEmail;
        final success = await authProvider.resetPassword(targetEmail);
        if (mounted && success) {
          setState(() {
            _emailSent = true;
          });
        }
      } else {
        final error = res['message']?.toString() ?? 'Tiada akaun dijumpai untuk nombor telefon ini.';
        showGlassToast(context, error, isError: true);
      }
    } else {
      _recoveredMaskedEmail = input;
      final success = await authProvider.resetPassword(input);
      if (!mounted) return;

      if (success) {
        setState(() {
          _emailSent = true;
        });
      } else {
        final error = authProvider.error ?? 'Ralat menghantar emel pemulihan.';
        showGlassToast(context, error, isError: true);
      }
    }
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

            // ─── 4. Main Centered Card ───
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
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  width: 1,
                                ),
                              ),
                              child: _emailSent ? _buildSuccessView() : _buildFormView(),
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

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ─── Ikon Kunci Moden ───
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: accentBlue.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: accentBlue.withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentBlue.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedLockPassword,
                color: accentBlue,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ─── Tajuk ───
          Text(
            'PULIHKAN AKAUN',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.0,
              color: accentBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Lupa Emel atau Kata Laluan?',
            style: GoogleFonts.outfit(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Masukkan alamat emel atau nombor telefon berdaftar anda untuk menerima pautan penetapan semula kata laluan.',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),

          // ─── Mode Switcher: Emel vs No Telefon ───
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _recoveryMode = 'email';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _recoveryMode == 'email' ? accentBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '✉️ Guna Emel',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: _recoveryMode == 'email' ? FontWeight.w700 : FontWeight.w500,
                          color: _recoveryMode == 'email' ? Colors.white : textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _recoveryMode = 'phone';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _recoveryMode == 'phone' ? const Color(0xFF10B981) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '📱 No. Telefon (Lupa Emel)',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: _recoveryMode == 'phone' ? FontWeight.w700 : FontWeight.w500,
                          color: _recoveryMode == 'phone' ? Colors.white : textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Input Field ───
          TextFormField(
            controller: _inputController,
            keyboardType: _recoveryMode == 'phone' ? TextInputType.phone : TextInputType.emailAddress,
            style: GoogleFonts.inter(color: textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: _recoveryMode == 'phone' ? '0123456789 atau +6012...' : 'Alamat Emel Anda',
              hintStyle: GoogleFonts.inter(
                color: textSecondary.withValues(alpha: 0.6),
                fontSize: 13,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              prefixIcon: Icon(
                _recoveryMode == 'phone' ? Icons.phone_iphone_outlined : Icons.email_outlined,
                color: textSecondary,
                size: 18,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                borderSide: BorderSide(
                  color: _recoveryMode == 'phone' ? const Color(0xFF10B981) : accentBlue,
                  width: 1.5,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return _recoveryMode == 'phone' ? 'Sila masukkan nombor telefon' : 'Sila masukkan alamat emel';
              }
              if (_recoveryMode == 'email' && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                return 'Format emel tidak sah';
              }
              if (_recoveryMode == 'phone' && value.replaceAll(RegExp(r'[^0-9]'), '').length < 8) {
                return 'Nombor telefon tidak sah';
              }
              return null;
            },
          ),
          if (_recoveryMode == 'phone')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '💡 Kami akan mencari emel akaun anda dan menghantar pautan reset kata laluan secara percuma ke emel tersebut.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF10B981),
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 20),

          // ─── Butang Hantar ───
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              return SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _handleReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _recoveryMode == 'phone' ? const Color(0xFF10B981) : accentBlue,
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
                          _recoveryMode == 'phone' ? 'CARI AKAUN & RESET' : 'SEND RESET LINK',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
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

          // ─── Kembali ke Login ───
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_back, size: 14, color: textSecondary),
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
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF44CF6C).withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF44CF6C).withValues(alpha: 0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF44CF6C).withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
              color: Color(0xFF44CF6C),
              size: 34,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _recoveryMode == 'phone' ? 'Akaun Dijumpai!' : 'Pautan Telah Dihantar!',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF44CF6C).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF44CF6C).withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Text(
                'EMEL BERDAFTAR ANDA',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: const Color(0xFF44CF6C),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _recoveredMaskedEmail ?? _inputController.text.trim(),
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Pautan penetapan semula kata laluan telah dihantar ke alamat emel di atas secara percuma. Sila buka peti masuk anda sekarang.',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: textSecondary,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
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
}
