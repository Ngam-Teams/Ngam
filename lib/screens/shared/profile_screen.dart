import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/review_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/glass_toast.dart';
import 'account_details_screen.dart';
import 'support_screens.dart';
import 'about_screens.dart';
import 'privacy_security_screen.dart';

import 'wallet_screen.dart';

import 'package:easy_localization/easy_localization.dart';
// ============================================================
// Ngam App — Skrin Profil (Customer & Runner)
// User profile with role toggle, stats, and settings (Glassmorphic)
// ============================================================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _tasksPosted = 0;
  int _tasksCompleted = 0;
  double _rating = 0.0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    try {
      final posted = 0;
      final completed = 0;
      final rating = await ReviewService.getAverageRating(user.id);

      if (mounted) {
        setState(() {
          _tasksPosted = posted;
          _tasksCompleted = completed;
          _rating = rating;
        });
      }
    } catch (e) {
      // Kalau error kita ignore je diam-diam
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = authProvider.user;
    final isDark = themeProvider.isDarkMode;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // ─── Header Profil ───────────────────────────
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.5,
                                    ),
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: isDark
                                      ? Colors.white10
                                      : Colors.black12,
                                  backgroundImage: user.avatarUrl != null 
                                      ? CachedNetworkImageProvider(user.avatarUrl!) 
                                      : null,
                                  child: user.avatarUrl == null 
                                      ? HugeIcon(
                                          icon: HugeIcons.strokeRoundedUser,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54,
                                          size: 40,
                                        ) 
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                user.name.isNotEmpty ? user.name : 'User',
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  user.role == UserRole.customer
                                      ? "CUSTOMER"
                                      : "RUNNER",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                user.email,
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.grey,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),


                        // ─── Bahagian Stat / Statistik ───────────────
                        _buildSectionHeader('profile.statistics'.tr()),
                        Row(
                          children: [
                            _StatCardGlass(
                              isDark: isDark,
                              label: 'profile.tasks_posted'.tr(),
                              value: '$_tasksPosted',
                              icon: HugeIcons.strokeRoundedUpload01,
                            ),
                            const SizedBox(width: 12),
                            _StatCardGlass(
                              isDark: isDark,
                              label: 'profile.completed'.tr(),
                              value: '$_tasksCompleted',
                              icon: HugeIcons.strokeRoundedTick01,
                            ),
                            const SizedBox(width: 12),
                            _StatCardGlass(
                              isDark: isDark,
                              label: 'profile.rating'.tr(),
                              value: _rating > 0
                                  ? _rating.toStringAsFixed(1)
                                  : 'profile.new_rating'.tr(),
                              icon: HugeIcons.strokeRoundedStar,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ─── Akaun ───────────────────────────────────────────
                        _buildSectionHeader("profile.account".tr()),
                        _buildGlassSection(
                          isDark,
                          Column(
                            children: [
                              _buildSettingsTile(
                                isDark,
                                HugeIcons.strokeRoundedUserEdit01,
                                "profile.account_details".tr(),
                                trailing: _buildArrow(),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AccountDetailsScreen(),
                                  ),
                                ),
                              ),
                              _buildDivider(isDark),
                              _buildSettingsTile(
                                isDark,
                                Icons.wallet_rounded,
                                "wallet.title".tr(),
                                trailing: _buildArrow(),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const WalletScreen(),
                                  ),
                                ),
                              ),
                              _buildDivider(isDark),
                              _buildSettingsTile(
                                isDark,
                                HugeIcons.strokeRoundedShield01,
                                "profile.privacy_security".tr(),
                                trailing: _buildArrow(),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const PrivacySecurityScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ─── Pilihan ──────────────────────────────────────────
                        _buildSectionHeader("profile.preferences".tr()),
                        _buildGlassSection(
                          isDark,
                          Column(
                            children: [
                              _buildThemeToggleTile(isDark, themeProvider),
                              _buildDivider(isDark),
                              _buildSettingsTile(
                                isDark,
                                HugeIcons.strokeRoundedGlobe02,
                                "profile.language".tr(),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      context.locale.languageCode == 'ms'
                                          ? 'Bahasa Melayu'
                                          : 'English',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildArrow(),
                                  ],
                                ),
                                onTap: () => _showLanguageSelector(context),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ─── Sokongan (Bantuan) ──────────────────────────────
                        _buildSectionHeader("profile.support".tr()),
                        _buildGlassSection(
                          isDark,
                          Column(
                            children: [
                              _buildSettingsTile(
                                isDark,
                                HugeIcons.strokeRoundedCustomerService,
                                'profile.help_center'.tr(),
                                trailing: _buildArrow(),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const HelpCenterScreen(),
                                  ),
                                ),
                              ),
                              _buildDivider(isDark),
                              _buildSettingsTile(
                                isDark,
                                HugeIcons.strokeRoundedMessageQuestion,
                                'profile.contact_us'.tr(),
                                trailing: _buildArrow(),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ContactUsScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ─── Tentang Kita ────────────────────────────────────
                        _buildSectionHeader("profile.about".tr()),
                        _buildGlassSection(
                          isDark,
                          Column(
                            children: [
                              _buildSettingsTile(
                                isDark,
                                HugeIcons.strokeRoundedInformationCircle,
                                'profile.terms'.tr(),
                                trailing: _buildArrow(),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LegalTextScreen(
                                      title: 'profile.terms'.tr(),
                                      content: ngamTermsText,
                                    ),
                                  ),
                                ),
                              ),
                              _buildDivider(isDark),
                              _buildSettingsTile(
                                isDark,
                                HugeIcons.strokeRoundedShield01,
                                'profile.privacy'.tr(),
                                trailing: _buildArrow(),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LegalTextScreen(
                                      title: 'profile.privacy'.tr(),
                                      content: ngamPrivacyText,
                                    ),
                                  ),
                                ),
                              ),
                              _buildDivider(isDark),
                              _buildSettingsTile(
                                isDark,
                                HugeIcons.strokeRoundedStar,
                                'profile.rate_app'.tr(),
                                trailing: _buildArrow(),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RateAppScreen(),
                                    fullscreenDialog: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),
                        // ─── Kaki / Footer Bawah ─────────────────────────────
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'Ngam v1.0.0',
                                style: TextStyle(
                                  color: Colors.grey.withValues(alpha: 0.5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'profile.made_with_love'.tr(),
                                style: TextStyle(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ─── Butang Log Keluar ───────────────────────────────
                        _buildGlassButton(
                          isDark,
                          'profile.logout'.tr(),
                          AppTheme.error,
                          () async {
                            await authProvider.signOut();
                            if (context.mounted) {
                              showGlassToast(
                                context,
                                'profile.logout_success'.tr(),
                              );
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/login',
                                (route) => false,
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── UI Helper (Widget Bantuan) ──────────────────────────────

  String _getRankName(int completed) {
    if (completed >= 50) return "rank.platinum".tr();
    if (completed >= 30) return "rank.gold".tr();
    if (completed >= 10) return "rank.silver".tr();
    return "rank.bronze".tr();
  }
  
  List<Color> _getRankColors(int completed) {
    if (completed >= 50) return [const Color(0xFFE5E4E2), const Color(0xFFB0B0B0), const Color(0xFFE5E4E2)]; // Platinum
    if (completed >= 30) return [const Color(0xFFFFD700), const Color(0xFFDAA520), const Color(0xFFFFD700)]; // Emas
    if (completed >= 10) return [const Color(0xFFC0C0C0), const Color(0xFF808080), const Color(0xFFC0C0C0)]; // Perak
    return [const Color(0xFFCD7F32), const Color(0xFF8B4513), const Color(0xFFCD7F32)]; // Gangsa
  }

  int _getNextRankTarget(int completed) {
    if (completed >= 50) return 100;
    if (completed >= 30) return 50;
    if (completed >= 10) return 30;
    return 10;
  }

  Widget _buildNgamRankSection(bool isDark) {
    final user = context.read<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("profile.ngam_rank".tr()),
        StreamBuilder<int>(
          stream: GigService.streamCompletedCount(user.id),
          initialData: _tasksCompleted,
          builder: (context, snapshot) {
            int completed = snapshot.data ?? 0;
            String rankName = _getRankName(completed);
            List<Color> colors = _getRankColors(completed);
            int target = _getNextRankTarget(completed);
            double progress = (completed / target).clamp(0.0, 1.0);
            int xp = completed * 50;

            return GlassContainer(
              useOwnLayer: true,
              quality: GlassQuality.standard,
              shape: LiquidRoundedSuperellipse(borderRadius: 24.0),
              settings: _getGlassSettings(isDark),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      isDark ? colors.first.withValues(alpha: 0.15) : colors.first.withValues(alpha: 0.3),
                      isDark ? colors.last.withValues(alpha: 0.05) : colors.last.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(
                    color: colors.first.withValues(alpha: isDark ? 0.3 : 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withValues(alpha: isDark ? 0.2 : 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                            boxShadow: [
                              BoxShadow(color: colors.first.withValues(alpha: 0.6), blurRadius: 20, spreadRadius: 4),
                              BoxShadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1),
                            ],
                          ),
                          child: const HugeIcon(icon: HugeIcons.strokeRoundedAward01, color: Colors.white, size: 40),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(rankName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: 0.5)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colors.first.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: colors.first.withValues(alpha: 0.5)),
                                ),
                                child: Text('Level $completed  •  $xp XP', style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 14,
                        color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.1),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(colors: [colors.last, colors.first]),
                              boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.8), blurRadius: 12)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$completed / $target Tasks', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                        Text('${(target - completed) * 50} XP to next rank', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.first)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
        ),
      ],
    );
  }

  Widget _buildGlassButton(
    bool isDark,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        useOwnLayer: true,
        quality: GlassQuality.standard,
        shape: LiquidRoundedSuperellipse(borderRadius: 24.0),
        settings: _getGlassSettings(isDark),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.1 : 0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.3 : 0.5),
              width: 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassSection(bool isDark, Widget child) {
    return GlassContainer(
      useOwnLayer: true,
      quality: GlassQuality.standard,
      shape: LiquidRoundedSuperellipse(borderRadius: 24.0),
      settings: _getGlassSettings(isDark),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.6),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  LiquidGlassSettings _getGlassSettings(bool isDark) {
    return LiquidGlassSettings(
      thickness: 0.1,
      blur: 15,
      refractiveIndex: 1.0,
      glassColor: Colors.transparent,
      lightAngle: 45.0,
      lightIntensity: isDark ? 0.1 : 0.2,
      ambientStrength: 1.0,
      saturation: 1.0,
      chromaticAberration: 0.0,
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 12),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    ),
  );


  void _showLanguageSelector(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF262626) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'profile.choose_language'.tr(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 24),
            _buildLanguageOption(
              context,
              "English",
              "en",
              HugeIcons.strokeRoundedTranslate,
              AppTheme.primary,
            ),
            const SizedBox(height: 12),
            _buildLanguageOption(
              context,
              "Bahasa Melayu",
              "ms",
              HugeIcons.strokeRoundedTranslate,
              AppTheme.primary,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    String title,
    String code,
    dynamic icon,
    Color color,
  ) {
    final currentLang = context.locale.languageCode;
    final isSelected = currentLang == code;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? color : Colors.transparent,
          width: 1.5,
        ),
      ),
      tileColor: color.withValues(alpha: 0.05),
      leading: HugeIcon(icon: icon, color: color, size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? HugeIcon(
              icon: HugeIcons.strokeRoundedTick01,
              color: color,
              size: 20,
            )
          : null,
      onTap: () async {
        await context.setLocale(Locale(code));
        if (context.mounted) {
          Navigator.pop(context);
          showGlassToast(context, 'profile.language_changed'.tr(args: [title]));
        }
      },
    );
  }

  Widget _buildSettingsTile(
    bool isDark,
    dynamic icon,
    String title, {
    Widget? trailing,
    VoidCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: icon is IconData
                  ? Icon(
                      icon,
                      color: isDark ? Colors.white : Colors.black87,
                      size: 20,
                    )
                  : HugeIcon(
                      icon: icon,
                      color: isDark ? Colors.white : Colors.black87,
                      size: 20,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailing != null) ...[trailing, const SizedBox(width: 8)],
            if (trailing == null)
              const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: Colors.grey,
                size: 20,
              ),
          ],
        ),
      ),
    ),
  );

  Widget _buildThemeToggleTile(bool isDark, ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: HugeIcon(
              icon: isDark
                  ? HugeIcons.strokeRoundedMoon02
                  : HugeIcons.strokeRoundedSun01,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'profile.dark_mode'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Switch.adaptive(
            value: isDark,
            activeColor: AppTheme.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            thumbIcon: WidgetStateProperty.all(const Icon(Icons.circle, color: Colors.transparent)),
            onChanged: (_) => themeProvider.toggleTheme(),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) => Padding(
    padding: const EdgeInsets.only(left: 60, right: 16),
    child: Divider(
      height: 1,
      color: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.05),
    ),
  );

  Widget _buildArrow() => const HugeIcon(
    icon: HugeIcons.strokeRoundedArrowRight01,
    color: Colors.grey,
    size: 20,
  );
}

// ─── Butang Glass untuk Tukar Role ───────────────────────────
class _RoleToggle extends StatelessWidget {
  final String label;
  final dynamic icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _RoleToggle({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              HugeIcon(
                icon: icon,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white54 : Colors.black54),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white54 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Kad Stat jenis Glass ────────────────────────────────────
class _StatCardGlass extends StatelessWidget {
  final String label;
  final String value;
  final dynamic icon;
  final bool isDark;

  const _StatCardGlass({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassContainer(
        useOwnLayer: true,
        quality: GlassQuality.standard,
        shape: LiquidRoundedSuperellipse(borderRadius: 24.0),
        settings: LiquidGlassSettings(
          thickness: 0.1,
          blur: 15,
          refractiveIndex: 1.0,
          glassColor: Colors.transparent,
          lightAngle: 45.0,
          lightIntensity: isDark ? 0.1 : 0.2,
          ambientStrength: 1.0,
          saturation: 1.0,
          chromaticAberration: 0.0,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.6),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              HugeIcon(icon: icon, size: 22, color: AppTheme.primary),
              const SizedBox(height: 8),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
