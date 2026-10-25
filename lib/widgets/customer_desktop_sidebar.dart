import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/app_theme.dart';
import '../utils/glass_toast.dart';

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
    final themeProvider = context.watch<ThemeProvider>();
    final user = authProvider.user;

    return ValueListenableBuilder<bool>(
      valueListenable: isExpandedNotifier,
      builder: (context, isExpanded, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                width: isExpanded ? 240 : 72,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // ─── 1. Header Atas (Logo & Butang Kembang / Kecil) ───
                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/splash.png',
                                width: 34,
                                height: 34,
                                fit: BoxFit.cover,
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
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Text(
                                    'Komuniti',
                                    style: TextStyle(
                                      color: Color(0xFF2196F3),
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

                    const SizedBox(height: 14),

                    // ─── 2. Profil Pengguna / Kad Tetamu ─────────────────
                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: InkWell(
                          onTap: () {
                            if (user != null) {
                              onNavTap(4); // Pergi ke skrin Profil
                            } else {
                              Navigator.pushNamed(context, '/login');
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 17,
                                  backgroundColor: const Color(0xFF2196F3).withValues(alpha: 0.2),
                                  backgroundImage: user?.userAvatarUrl != null
                                      ? CachedNetworkImageProvider(user!.userAvatarUrl!)
                                      : null,
                                  child: user?.userAvatarUrl == null
                                      ? const HugeIcon(
                                          icon: HugeIcons.strokeRoundedUser,
                                          color: Color(0xFF2196F3),
                                          size: 16,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        user != null
                                            ? ((user.userName?.isNotEmpty ?? false)
                                                ? user.userName!
                                                : 'Pelanggan')
                                            : 'Akaun Tetamu',
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        user != null ? 'Ahli Ngam' : 'Log Masuk Segera',
                                        style: TextStyle(
                                          color: user != null
                                              ? const Color(0xFF2196F3)
                                              : (isDark ? Colors.white54 : Colors.black45),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Tooltip(
                        message: user != null
                            ? (user.userName ?? 'Profil')
                            : 'Log Masuk Tetamu',
                        child: InkWell(
                          onTap: () {
                            if (user != null) {
                              onNavTap(4);
                            } else {
                              Navigator.pushNamed(context, '/login');
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF2196F3).withValues(alpha: 0.2),
                            backgroundImage: user?.userAvatarUrl != null
                                ? CachedNetworkImageProvider(user!.userAvatarUrl!)
                                : null,
                            child: user?.userAvatarUrl == null
                                ? const HugeIcon(
                                    icon: HugeIcons.strokeRoundedUser,
                                    color: Color(0xFF2196F3),
                                    size: 18,
                                  )
                                : null,
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        height: 1,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ─── 3. Senarai Navigasi Menu (5 Tabs) ────────────────
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        physics: const ClampingScrollPhysics(),
                        itemCount: navItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final item = navItems[index];
                          final selected = index == selectedIndex;
                          return _SidebarNavItem(
                            icon: item.icon,
                            label: item.label,
                            selected: selected,
                            isExpanded: isExpanded,
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
                    const SizedBox(height: 6),

                    // ─── 4. Butang Bawah (Tema / Log Keluar / Log Masuk) ──
                    _SidebarNavItem(
                      icon: isDark
                          ? HugeIcons.strokeRoundedSun01
                          : HugeIcons.strokeRoundedMoon02,
                      label: isDark ? 'Mod Cerah' : 'Mod Gelap',
                      selected: false,
                      isExpanded: isExpanded,
                      onTap: () => themeProvider.toggleTheme(),
                    ),

                    if (user != null)
                      _SidebarNavItem(
                        icon: HugeIcons.strokeRoundedLogout02,
                        label: 'Log Keluar',
                        selected: false,
                        isExpanded: isExpanded,
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: isDark ? const Color(0xFF141420) : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.black12,
                                ),
                              ),
                              title: const Row(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedLogout02,
                                    color: Colors.redAccent,
                                    size: 22,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Log Keluar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              content: const Text(
                                'Adakah anda pasti mahu log keluar daripada akaun ini?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Batal'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.error,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Log Keluar'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await authProvider.signOut();
                            if (context.mounted) {
                              showGlassToast(context, 'Berjaya log keluar');
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
                        label: 'Log Masuk / Daftar',
                        selected: false,
                        isExpanded: isExpanded,
                        onTap: () => Navigator.pushNamed(context, '/login'),
                      ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
      message: _isHovered ? 'Kembangkan Sidebar' : 'Ngam Komuniti',
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
                        'assets/splash.png',
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
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
    return Tooltip(
      message: 'Kecilkan Sidebar',
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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _isHovered
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isHovered
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedSidebarLeft,
                color: Colors.white70,
                size: 17,
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
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isExpanded) {
      // Shrunk mode: Icon only with Tooltip
      return Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 300),
        child: Center(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: selected
                    ? const Color(0xFF2196F3).withValues(alpha: 0.18)
                    : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF2196F3).withValues(alpha: 0.35)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Center(
                child: HugeIcon(
                  icon: icon,
                  color: selected
                      ? const Color(0xFF2196F3)
                      : (isDark ? Colors.white38 : Colors.black45),
                  size: 21,
                  strokeWidth: selected ? 2.3 : 1.9,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Expanded mode: Icon + Label
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? const Color(0xFF2196F3).withValues(alpha: 0.18)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? const Color(0xFF2196F3).withValues(alpha: 0.35)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: icon,
              color: selected
                  ? const Color(0xFF2196F3)
                  : (isDark ? Colors.white54 : Colors.black45),
              size: 20,
              strokeWidth: selected ? 2.3 : 1.9,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? (isDark ? Colors.white : const Color(0xFF1976D2))
                      : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13.5,
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
