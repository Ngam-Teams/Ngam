import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shimmer/shimmer.dart';
import 'package:ngam/widgets/glass_box.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/review_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/glass_toast.dart';
import '../../widgets/glass_dialog.dart';
import 'account_details_screen.dart';
import 'support_screens.dart';
import 'report_issue_screen.dart';
import 'about_screens.dart';
import 'privacy_security_screen.dart';
import 'wallet_screen.dart';
import 'saved_screen.dart';
import 'my_stamp_cards_screen.dart';
import 'voucher_screen.dart';
import 'my_queue_ticket_screen.dart';
import '../explore/my_bookings_view.dart';
import '../../services/app_update_service.dart';

import 'package:easy_localization/easy_localization.dart';
import '../../services/ereceipt_service.dart';
import '../receipt/my_receipts_screen.dart';
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
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    EreceiptService.init();
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

  Widget _buildProfileHeaderShimmer(bool isDark) {
    final baseColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final highlightColor = isDark ? Colors.white.withValues(alpha: 0.16) : Colors.black.withValues(alpha: 0.12);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 180,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 96,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 160,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = authProvider.user;
    final isDark = themeProvider.isDarkMode;
    final bool isProfileLoading = user == null && authProvider.isInitializing;


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
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // ─── Header Profil (Shimmer / Tetamu / Log Masuk) ───
                        if (isProfileLoading)
                          _buildProfileHeaderShimmer(isDark)
                        else
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
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

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
                              const SizedBox(width: 10),
                              _StatCardGlass(
                                isDark: isDark,
                                label: 'profile.completed'.tr(),
                                value: '$_tasksCompleted',
                                icon: HugeIcons.strokeRoundedTick01,
                              ),
                              const SizedBox(width: 10),
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
                          const SizedBox(height: 18),

                          // ─── Akaun (Kad Pantas 4x2 = 8 Ikon) ───────────────
                          _buildSectionHeader("profile.account".tr()),
                          _buildGlassSection(
                            isDark,
                            _buildQuickAccountGrid(isDark),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ─── Pilihan & Keselamatan (Senarai Kompak) ───────────
                        _buildSectionHeader("profile.preferences".tr()),
                        _buildGlassSection(
                          isDark,
                          Column(
                            children: [
                              if (user != null) ...[
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
                                _buildDivider(isDark),
                              ],
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
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildArrow(),
                                  ],
                                ),
                                onTap: () => _showLanguageSelector(context),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

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
                              _buildDivider(isDark),
                              _buildSettingsTile(
                                isDark,
                                HugeIcons.strokeRoundedAlert02,
                                'profile.report_issue'.tr(),
                                trailing: _buildArrow(),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ReportIssueScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

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
                                trailing: _isCheckingUpdate
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                                        ),
                                      )
                                    : ValueListenableBuilder<String>(
                                        valueListenable: AppUpdateService.versionNotifier,
                                        builder: (context, ver, _) {
                                          return ValueListenableBuilder<AppReleaseInfo?>(
                                            valueListenable: AppUpdateService.availableUpdateNotifier,
                                            builder: (context, update, _) {
                                              final hasUpdate = update != null;
                                              return Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: hasUpdate
                                                          ? Colors.amber.withValues(alpha: 0.18)
                                                          : const Color(0xFF10B981).withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: hasUpdate
                                                            ? Colors.amber.withValues(alpha: 0.45)
                                                            : const Color(0xFF10B981).withValues(alpha: 0.35),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      hasUpdate
                                                          ? 'app_update.update_pill'.tr(args: [update.version])
                                                          : 'v$ver • ${'app_update.latest_badge'.tr()}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w700,
                                                        color: hasUpdate
                                                            ? (isDark ? Colors.amberAccent : Colors.amber.shade900)
                                                            : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  _buildArrow(),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                      ),
                                onTap: _isCheckingUpdate
                                    ? () {}
                                    : () async {
                                        final pendingUpdate = AppUpdateService.availableUpdateNotifier.value;
                                        if (pendingUpdate != null) {
                                          await AppUpdateService.showUpdateDialog(context, pendingUpdate);
                                          return;
                                        }
                                        setState(() => _isCheckingUpdate = true);
                                        try {
                                          await AppUpdateService.checkManually(context);
                                        } finally {
                                          if (mounted) {
                                            setState(() => _isCheckingUpdate = false);
                                          }
                                        }
                                      },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),
                        // ─── Kaki / Footer Bawah ─────────────────────────────
                        Center(
                          child: ValueListenableBuilder<String>(
                            valueListenable: AppUpdateService.versionNotifier,
                            builder: (context, ver, _) {
                              return Column(
                                children: [
                                  Text(
                                    'app_update.version_footer'.tr(args: [ver]),
                                    style: TextStyle(
                                      color: Colors.grey.withValues(alpha: 0.55),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'profile.made_with_love'.tr(),
                                    style: TextStyle(
                                      color: Colors.grey.withValues(alpha: 0.35),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              );
                            },
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
                              final confirm = await showGlassConfirmDialog(
                                context: context,
                                title: 'common.log_out'.tr(),
                                message: 'profile.confirm_logout'.tr(),
                                confirmText: 'common.log_out'.tr(),
                                cancelText: 'common.cancel'.tr(),
                                icon: HugeIcons.strokeRoundedLogout02,
                                isDestructive: true,
                              );
                              if (confirm == true) {
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

  Widget _buildQuickAccountGrid(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildQuickGridItem(
                  isDark: isDark,
                  icon: HugeIcons.strokeRoundedCalendar03,
                  label: 'profile.grid_bookings'.tr(),
                  accent: const Color(0xFF38BDF8),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyBookingsView()),
                  ),
                ),
              ),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: EreceiptService.totalPointsNotifier,
                  builder: (context, pts, _) {
                    return _buildQuickGridItem(
                      isDark: isDark,
                      icon: HugeIcons.strokeRoundedInvoice01,
                      label: 'profile.grid_receipts'.tr(),
                      accent: const Color(0xFF10B981),
                      badgeText: pts > 0 ? '$pts' : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyReceiptsScreen(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: _buildQuickGridItem(
                  isDark: isDark,
                  icon: HugeIcons.strokeRoundedTicket01,
                  label: 'profile.grid_queue'.tr(),
                  accent: const Color(0xFFF59E0B),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyQueueTicketScreen(),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _buildQuickGridItem(
                  isDark: isDark,
                  icon: HugeIcons.strokeRoundedCreditCard,
                  label: 'profile.grid_wallet'.tr(),
                  accent: AppTheme.primary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WalletScreen()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            indent: 8,
            endIndent: 8,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildQuickGridItem(
                  isDark: isDark,
                  icon: HugeIcons.strokeRoundedBookmark02,
                  label: 'profile.grid_saved'.tr(),
                  accent: const Color(0xFF8B5CF6),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SavedScreen()),
                  ),
                ),
              ),
              Expanded(
                child: _buildQuickGridItem(
                  isDark: isDark,
                  icon: HugeIcons.strokeRoundedLoyaltyCard,
                  label: 'profile.grid_stamps'.tr(),
                  accent: const Color(0xFFEC4899),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyStampCardsScreen(),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _buildQuickGridItem(
                  isDark: isDark,
                  icon: HugeIcons.strokeRoundedDiscount01,
                  label: 'profile.grid_vouchers'.tr(),
                  accent: const Color(0xFFF97316),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VoucherScreen()),
                  ),
                ),
              ),
              Expanded(
                child: _buildQuickGridItem(
                  isDark: isDark,
                  icon: HugeIcons.strokeRoundedUserEdit01,
                  label: 'profile.grid_account'.tr(),
                  accent: const Color(0xFF6366F1),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountDetailsScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickGridItem({
    required bool isDark,
    required dynamic icon,
    required String label,
    required Color accent,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.14 : 0.11),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accent.withValues(alpha: isDark ? 0.25 : 0.22),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: icon,
                        color: isDark ? Colors.white : accent,
                        size: 20,
                      ),
                    ),
                  ),
                  if (badgeText != null)
                    Positioned(
                      top: -5,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.18,
                  color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 11.5,
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
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: icon is IconData
                  ? Icon(
                      icon,
                      color: isDark ? Colors.white : Colors.black87,
                      size: 18,
                    )
                  : HugeIcon(
                      icon: icon,
                      color: isDark ? Colors.white : Colors.black87,
                      size: 18,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailing != null) ...[trailing, const SizedBox(width: 4)],
            if (trailing == null)
              const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: Colors.grey,
                size: 17,
              ),
          ],
        ),
      ),
    ),
  );

  Widget _buildThemeToggleTile(bool isDark, ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(
              icon: isDark
                  ? HugeIcons.strokeRoundedMoon02
                  : HugeIcons.strokeRoundedSun01,
              color: AppTheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'profile.dark_mode'.tr(),
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            height: 28,
            child: Switch.adaptive(
              value: isDark,
              activeColor: AppTheme.primary,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) => null),
              onChanged: (_) => themeProvider.toggleTheme(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) => Padding(
    padding: const EdgeInsets.only(left: 50, right: 14),
    child: Divider(
      height: 1,
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.05),
    ),
  );

  Widget _buildArrow() => const HugeIcon(
    icon: HugeIcons.strokeRoundedArrowRight01,
    color: Colors.grey,
    size: 17,
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
