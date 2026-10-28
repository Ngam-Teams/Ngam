import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:ngam/widgets/glass_box.dart';

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
import 'saved_screen.dart';
import 'my_stamp_cards_screen.dart';
import 'my_queue_ticket_screen.dart';
import '../../services/app_update_service.dart';

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

                        // ─── Header Profil (Tetamu atau Log Masuk) ───
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
                                  backgroundImage: user?.userAvatarUrl != null 
                                      ? CachedNetworkImageProvider(user!.userAvatarUrl!) 
                                      : null,
                                  child: user?.userAvatarUrl == null 
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
                                user != null
                                    ? ((user.userName?.isNotEmpty ?? false) ? user.userName! : 'User')
                                    : 'profile.guest_user'.tr(),
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
                                  color: user != null ? AppTheme.primary : Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: user == null ? Border.all(color: Colors.white24, width: 0.8) : null,
                                ),
                                child: Text(
                                  user != null
                                      ? (user.role == UserRole.customer
                                          ? "CUSTOMER"
                                          : "CUSTOMER")
                                      : "GUEST ACCOUNT",
                                  style: TextStyle(
                                    color: user != null ? Colors.white : Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                user != null
                                    ? (user.userEmail ?? '')
                                    : 'profile.guest_subtitle'.tr(),
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.grey,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: user != null ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (user == null) ...[
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  onPressed: () => Navigator.pushNamed(context, '/login'),
                                  icon: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedLogin02,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'profile.login_register'.tr(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ─── Bahagian Stat / Statistik (Hanya jika Log Masuk) ───
                        if (user != null) ...[
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
                                  HugeIcons.strokeRoundedCreditCard,
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
                                  HugeIcons.strokeRoundedBookmark02,
                                  "profile.saved".tr(),
                                  trailing: _buildArrow(),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SavedScreen(),
                                    ),
                                  ),
                                ),
                                _buildDivider(isDark),
                                _buildSettingsTile(
                                  isDark,
                                  HugeIcons.strokeRoundedLoyaltyCard,
                                  "profile.stamp_cards".tr(),
                                  trailing: _buildArrow(),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const MyStampCardsScreen(),
                                    ),
                                  ),
                                ),
                                _buildDivider(isDark),
                                _buildSettingsTile(
                                  isDark,
                                  HugeIcons.strokeRoundedTicket01,
                                  "profile.live_queue".tr(),
                                  trailing: _buildArrow(),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const MyQueueTicketScreen(),
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
                        ],

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
                              _buildDivider(isDark),
                              _buildSettingsTile(
                                isDark,
                                HugeIcons.strokeRoundedCloudDownload,
                                'profile.check_updates'.tr(),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'v${AppUpdateService.currentVersion}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white54 : Colors.black45,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildArrow(),
                                  ],
                                ),
                                onTap: () => AppUpdateService.checkManually(context),
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

                        // ─── Butang Log Keluar (Hanya jika Log Masuk) ───────
                        if (user != null)
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
                                  '/customer-home',
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
            thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) => null),
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
