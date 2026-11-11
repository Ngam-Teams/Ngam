import 'package:easy_localization/easy_localization.dart';
import '../l10n/generated/app_localizations.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../utils/glass_toast.dart';
import 'glass_dialog.dart';

// =============================================================================
// CustomerDesktopSidebar — Master Responsive Sidebar untuk Ngam Customer
// Diadaptasi khas mengikut seni bina berkualiti tinggi dari Ngam Business:
// - Shrunk mode (72px): Ultra-slim rail dengan ikon kemas & interaksi hover logo
// - Expanded mode (240px): Sidebar penuh dengan penjenamaan, profil pengguna/tetamu,
//   label menu & kawalan tema
// =============================================================================

class CustomerDesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavTap;

  const CustomerDesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.onNavTap,
  });

  /// Status kembang/kecil sidebar kekal semasa navigasi
  static final ValueNotifier<bool> isExpandedNotifier = ValueNotifier<bool>(true);

  /// Kiraan lebar keseluruhan sidebar untuk digunakan oleh laman-laman bersebelahan (Peta, Laman Utama, dll)
  static double getSidebarTotalWidth(BuildContext context, bool isExpanded) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isCompactHeight = screenHeight < 500;
    final double expandedWidth = (screenWidth * 0.35).clamp(180.0, 260.0);
    final double collapsedWidth = isCompactHeight ? 64.0 : 72.0;
    final double paddingLeft = isCompactHeight ? 10.0 : 16.0;
    return (isExpanded ? expandedWidth : collapsedWidth) + paddingLeft;
  }

  static const List<({dynamic icon, String label})> navItems = [
    (icon: HugeIcons.strokeRoundedHome11, label: 'Laman Utama'),
    (icon: HugeIcons.strokeRoundedMaps, label: 'Terokai Peta'),
    (icon: HugeIcons.strokeRoundedPlayCircle02, label: 'Ngam Feed'),
    (icon: HugeIcons.strokeRoundedMessage02, label: 'Mesej'),
    (icon: HugeIcons.strokeRoundedUser, label: 'Profil Saya'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final l10n = AppLocalizations.of(context);

    final localizedNavItems = [
      (icon: HugeIcons.strokeRoundedHome11, label: l10n?.navHome ?? 'Laman Utama'),
      (icon: HugeIcons.strokeRoundedMaps, label: l10n?.navDiscover ?? 'Terokai Peta'),
      (icon: HugeIcons.strokeRoundedPlayCircle02, label: l10n?.navFeed ?? 'Ngam Feed'),
      (icon: HugeIcons.strokeRoundedMessage02, label: l10n?.navInbox ?? 'Mesej'),
      (icon: HugeIcons.strokeRoundedUser, label: l10n?.navProfile ?? 'Profil Saya'),
    ];

    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isCompactHeight = screenHeight < 500;
    final double expandedWidth = (screenWidth * 0.35).clamp(180.0, 260.0);
    final double collapsedWidth = isCompactHeight ? 64.0 : 72.0;

    return ValueListenableBuilder<bool>(
      valueListenable: isExpandedNotifier,
      builder: (context, isExpanded, _) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            isCompactHeight ? 10 : 16,
            isCompactHeight ? 8 : 16,
            0,
            isCompactHeight ? 8 : 16,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isCompactHeight ? 22 : 28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                width: isExpanded ? expandedWidth : collapsedWidth,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF1E2838).withValues(alpha: 0.58),
                            const Color(0xFF101622).withValues(alpha: 0.45),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.58),
                            Colors.white.withValues(alpha: 0.38),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(isCompactHeight ? 22 : 28),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.75),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SizedBox(height: isCompactHeight ? 8 : 16),

                    // ─── 1. Header Atas (Logo & Butang Kembang / Kecil) ───
                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/app.png',
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Image.asset(
                                  'assets/splash.png',
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2196F3),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'N',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Ngam',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                   Text(
                                    'common.community'.tr(),
                                    style: const TextStyle(
                                      color: Color(0xFF42A5F5),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            _CollapseSidebarButton(
                              onTap: () => isExpandedNotifier.value = false,
                            ),
                          ],
                        ),
                      )
                    else
                      // Shrunk mode: Logo hover swap
                      _LogoExpandButton(
                        onTap: () => isExpandedNotifier.value = true,
                      ),

                    SizedBox(height: isCompactHeight ? 8 : 14),

                    // ─── 2. Profil Pengguna / Kad Tetamu ─────────────────
                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: InkWell(
                          onTap: () {
                            if (user != null) {
                              onNavTap(4); // Pergi ke skrin Profil
                            } else {
                              Navigator.pushNamed(context, '/login');
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          hoverColor: Colors.white.withValues(alpha: 0.08),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: isCompactHeight ? 5 : 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Row(
                              children: [
                                _buildSidebarAvatar(user, isCompactHeight ? 14 : 17, isDark),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        user != null
                                            ? ((user.userName?.isNotEmpty ?? false)
                                                ? user.userName!
                                                : 'account.badge_customer'.tr())
                                            : 'profile.guest_account'.tr(),
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 1.5),
                                      Text(
                                        user != null ? 'profile.member_badge'.tr() : 'profile.login_now'.tr(),
                                        style: TextStyle(
                                          color: isDark ? Colors.white.withValues(alpha: 0.45) : Colors.black45,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black26,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Tooltip(
                        message: user != null
                            ? (user.userName ?? 'profile.account'.tr())
                            : 'profile.guest_login_tooltip'.tr(),
                        child: InkWell(
                          onTap: () {
                            if (user != null) {
                              onNavTap(4);
                            } else {
                              Navigator.pushNamed(context, '/login');
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: _buildSidebarAvatar(user, isCompactHeight ? 16 : 19, isDark),
                        ),
                      ),

                    SizedBox(height: isCompactHeight ? 6 : 12),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        height: 1,
                      ),
                    ),

                    SizedBox(height: isCompactHeight ? 4 : 8),

                    // ─── 3. Senarai Navigasi Menu (5 Tabs) ────────────────
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        physics: const ClampingScrollPhysics(),
                        itemCount: localizedNavItems.length,
                        separatorBuilder: (_, __) => SizedBox(height: isCompactHeight ? 2 : 4),
                        itemBuilder: (context, index) {
                          final item = localizedNavItems[index];
                          final selected = index == selectedIndex;
                          return _SidebarNavItem(
                            icon: item.icon,
                            label: item.label,
                            selected: selected,
                            isExpanded: isExpanded,
                            isCompactHeight: isCompactHeight,
                            onTap: () => onNavTap(index),
                          );
                        },
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        height: 1,
                      ),
                    ),
                    SizedBox(height: isCompactHeight ? 4 : 6),

                    // ─── 4. Butang Bawah (Log Keluar / Log Masuk) ──
                    if (user != null)
                      _SidebarNavItem(
                        icon: HugeIcons.strokeRoundedLogout02,
                        label: l10n?.logOut ?? 'common.log_out'.tr(),
                        selected: false,
                        isExpanded: isExpanded,
                        isCompactHeight: isCompactHeight,
                        onTap: () async {
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
                              showGlassToast(context, 'profile.logout_success'.tr());
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/customer-home',
                                (route) => false,
                              );
                            }
                          }
                        },
                      )
                    else
                      _SidebarNavItem(
                        icon: HugeIcons.strokeRoundedLogin02,
                        label: 'profile.login_register'.tr(),
                        selected: false,
                        isExpanded: isExpanded,
                        isCompactHeight: isCompactHeight,
                        onTap: () => Navigator.pushNamed(context, '/login'),
                      ),

                    SizedBox(height: isCompactHeight ? 6 : 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebarAvatar(UserModel? user, double radius, bool isDark) {
    final hasImage = user?.userAvatarUrl != null && user!.userAvatarUrl!.trim().isNotEmpty;
    final String name = (user?.userName?.trim().isNotEmpty ?? false) ? user!.userName!.trim() : 'P';
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2A2B3D),
                Color(0xFF161622),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1.2,
            ),
            image: hasImage
                ? DecorationImage(
                    image: CachedNetworkImageProvider(user.userAvatarUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: !hasImage
              ? Text(
                  initial,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: radius * 0.95,
                    letterSpacing: -0.5,
                  ),
                )
              : null,
        ),
        if (user != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius > 18 ? 9 : 8,
              height: radius > 18 ? 9 : 8,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF161622),
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo / Expand Button (Gemini Style: Hover over logo transforms into expand icon)
// ─────────────────────────────────────────────────────────────────────────────
class _LogoExpandButton extends StatefulWidget {
  final VoidCallback onTap;

  const _LogoExpandButton({required this.onTap});

  @override
  State<_LogoExpandButton> createState() => _LogoExpandButtonState();
}

class _LogoExpandButtonState extends State<_LogoExpandButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _isHovered ? 'common.expand_sidebar'.tr() : 'Ngam',
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _isHovered
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovered
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: _isHovered
                  ? const HugeIcon(
                      key: ValueKey('expand_icon'),
                      icon: HugeIcons.strokeRoundedSidebarLeft01,
                      color: Colors.white,
                      size: 20,
                      strokeWidth: 2.1,
                    )
                  : ClipRRect(
                      key: const ValueKey('logo_img'),
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/app.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/splash.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'N',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Collapse Button (Gemini Style: Top right icon button to collapse sidebar)
// ─────────────────────────────────────────────────────────────────────────────
class _CollapseSidebarButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CollapseSidebarButton({required this.onTap});

  @override
  State<_CollapseSidebarButton> createState() => _CollapseSidebarButtonState();
}

class _CollapseSidebarButtonState extends State<_CollapseSidebarButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: 'common.collapse_sidebar'.tr(),
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _isHovered
                  ? (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08))
                  : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isHovered
                    ? (isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black12)
                    : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                width: 1,
              ),
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedSidebarLeft,
                color: isDark ? Colors.white70 : Colors.black87,
                size: 18,
                strokeWidth: 2.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar Nav Item (Dual Mode: Icon + Text in Expand, Icon Only in Shrink)
// ─────────────────────────────────────────────────────────────────────────────
class _SidebarNavItem extends StatelessWidget {
  final dynamic icon;
  final String label;
  final bool selected;
  final bool isExpanded;
  final bool isCompactHeight;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isExpanded,
    this.isCompactHeight = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isExpanded) {
      // Shrunk mode: Icon only with Tooltip (Identical to Ngam Business)
      return Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 300),
        child: Center(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(isCompactHeight ? 12 : 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isCompactHeight ? 42 : 48,
              height: isCompactHeight ? 42 : 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isCompactHeight ? 12 : 16),
                color: selected
                    ? const Color(0xFF42A5F5).withValues(alpha: 0.18)
                    : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF42A5F5).withValues(alpha: 0.35)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Center(
                child: HugeIcon(
                  icon: icon,
                  color: selected
                      ? const Color(0xFF42A5F5)
                      : (isDark ? Colors.white38 : Colors.black45),
                  size: isCompactHeight ? 20 : 22,
                  strokeWidth: selected ? 2.3 : 1.9,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Expanded mode: Icon + Label (Identical to Ngam Business)
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: isCompactHeight ? 1.5 : 3),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: isCompactHeight ? 7 : 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? const Color(0xFF42A5F5).withValues(alpha: 0.18)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? const Color(0xFF42A5F5).withValues(alpha: 0.35)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: icon,
              color: selected
                  ? const Color(0xFF42A5F5)
                  : (isDark ? Colors.white38 : Colors.black45),
              size: isCompactHeight ? 18 : 20,
              strokeWidth: selected ? 2.3 : 1.9,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? (isDark ? Colors.white : const Color(0xFF1976D2))
                      : (isDark ? Colors.white54 : Colors.black87),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: isCompactHeight ? 13 : 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
