import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Single item within a GlassNavPill
class GlassNavPillItem {
  final dynamic icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? iconColor;
  final Widget? badge;
  final bool isLoading;

  const GlassNavPillItem({
    required this.icon,
    this.onTap,
    this.tooltip,
    this.iconColor,
    this.badge,
    this.isLoading = false,
  });
}

/// A connected glass-morphism pill container that merges 2 (or more) buttons into
/// a single sleek pill, matching the top-right button on the Home screen (QR + Saved + Notification).
class GlassNavPill extends StatelessWidget {
  final List<GlassNavPillItem> items;
  final bool? isDark;
  final double height;
  final EdgeInsetsGeometry? margin;

  const GlassNavPill({
    super.key,
    required this.items,
    this.isDark,
    this.height = 44.0,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final bool effectiveDark =
        isDark ?? (Theme.of(context).brightness == Brightness.dark);

    Widget pill = ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            color: effectiveDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.70),
            border: Border.all(
              color: effectiveDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: effectiveDark ? 0.25 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: items.map((it) => _buildItem(it, effectiveDark)).toList(),
          ),
        ),
      ),
    );

    if (margin != null) {
      pill = Padding(padding: margin!, child: pill);
    }

    return pill;
  }

  Widget _buildItem(GlassNavPillItem item, bool effectiveDark) {
    final Color effectiveIconColor = item.iconColor ??
        (effectiveDark ? Colors.white.withValues(alpha: 0.90) : const Color(0xFF1E293B));

    Widget content = Center(
      child: item.icon is IconData
          ? Icon(
              item.icon as IconData,
              size: 20,
              color: effectiveIconColor,
            )
          : HugeIcon(
              icon: item.icon,
              size: 20,
              color: effectiveIconColor,
            ),
    );

    if (item.badge != null) {
      content = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          content,
          Positioned(
            top: 2,
            right: 2,
            child: item.badge!,
          ),
        ],
      );
    }

    Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(100),
        splashColor: effectiveDark ? Colors.white12 : Colors.black12,
        highlightColor: effectiveDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        child: SizedBox(
          width: height,
          height: height,
          child: content,
        ),
      ),
    );

    if (item.tooltip != null && item.tooltip!.isNotEmpty) {
      button = Tooltip(message: item.tooltip!, child: button);
    }

    return button;
  }
}

/// A premium, reusable glass-morphism circular navigation button.
/// Matches the design aesthetic of the Home screen top bar buttons:
/// circular shape with backdrop blur, subtle frosted surface, gentle border and shadow.
class GlassNavButton extends StatelessWidget {
  final dynamic icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final bool? isDark;
  final EdgeInsetsGeometry? margin;
  final bool isLoading;
  final Widget? badge;

  const GlassNavButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 44.0,
    this.iconSize = 20.0,
    this.iconColor,
    this.isDark,
    this.margin,
    this.isLoading = false,
    this.badge,
  });

  /// Safely navigates back without throwing Navigator errors, leaving the app,
  /// or unexpectedly dropping out to Google Search.
  static void safeNavBack(
    BuildContext context, {
    VoidCallback? onBack,
    String? fallbackRoute,
  }) {
    if (onBack != null) {
      onBack();
      return;
    }

    // 1. Try popping the nearest or root Navigator (for dialogs, modal sheets, stacked routes)
    if (Navigator.of(context, rootNavigator: false).canPop()) {
      Navigator.of(context, rootNavigator: false).pop();
      return;
    }
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
      return;
    }

    // 2. Intelligently determine fallback parent route based on current path/route
    String resolvedFallback = fallbackRoute ?? '/customer-home';
    if (fallbackRoute == null) {
      try {
        final currentRouteName = ModalRoute.of(context)?.settings.name;
        if (currentRouteName != null) {
          if (const {
            '/profile',
            '/privacy',
            '/terms',
            '/about',
            '/help',
            '/support',
            '/contact',
          }.contains(currentRouteName)) {
            resolvedFallback = '/tab/profile';
          } else {
            resolvedFallback = '/customer-home';
          }
        }
      } catch (_) {
        resolvedFallback = '/customer-home';
      }
    }

    // 3. Safely navigate to fallback parent route
    if (context.mounted) {
      try {
        Navigator.of(context).pushReplacementNamed(resolvedFallback);
      } catch (_) {
        try {
          Navigator.of(context).pushNamedAndRemoveUntil(resolvedFallback, (route) => false);
        } catch (_) {}
      }
    }
  }

  /// Factory constructor for a standard back navigation button
  factory GlassNavButton.back({
    Key? key,
    required BuildContext context,
    bool? isDark,
    VoidCallback? onBack,
    String? fallbackRoute,
    double size = 44.0,
    double iconSize = 20.0,
    EdgeInsetsGeometry? margin,
  }) {
    final bool effectiveDark =
        isDark ?? (Theme.of(context).brightness == Brightness.dark);
    return GlassNavButton(
      key: key,
      icon: HugeIcons.strokeRoundedArrowLeft01,
      onTap: () => safeNavBack(
        context,
        onBack: onBack,
        fallbackRoute: fallbackRoute,
      ),
      isDark: effectiveDark,
      size: size,
      iconSize: iconSize,
      tooltip: 'common.back'.tr(),
      margin: margin,
    );
  }

  /// Factory constructor for a standard close/cancel navigation button
  factory GlassNavButton.close({
    Key? key,
    required BuildContext context,
    bool? isDark,
    VoidCallback? onClose,
    String? fallbackRoute,
    double size = 44.0,
    double iconSize = 20.0,
    EdgeInsetsGeometry? margin,
  }) {
    final bool effectiveDark =
        isDark ?? (Theme.of(context).brightness == Brightness.dark);
    return GlassNavButton(
      key: key,
      icon: HugeIcons.strokeRoundedCancel01,
      onTap: () => safeNavBack(
        context,
        onBack: onClose,
        fallbackRoute: fallbackRoute,
      ),
      isDark: effectiveDark,
      size: size,
      iconSize: iconSize,
      tooltip: 'common.close'.tr(),
      margin: margin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool effectiveDark =
        isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final Color effectiveIconColor = iconColor ??
        (effectiveDark ? Colors.white.withValues(alpha: 0.90) : const Color(0xFF1E293B));

    Widget content = isLoading
        ? SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(effectiveIconColor),
            ),
          )
        : (icon is IconData
            ? Icon(
                icon as IconData,
                size: iconSize,
                color: effectiveIconColor,
              )
            : HugeIcon(
                icon: icon,
                size: iconSize,
                color: effectiveIconColor,
              ));

    if (badge != null) {
      content = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          content,
          Positioned(
            top: 2,
            right: 2,
            child: badge!,
          ),
        ],
      );
    }

    Widget button = ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: effectiveDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.70),
            border: Border.all(
              color: effectiveDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: effectiveDark ? 0.25 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              splashColor: effectiveDark ? Colors.white12 : Colors.black12,
              highlightColor: effectiveDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );

    if (margin != null) {
      button = Padding(padding: margin!, child: button);
    }

    if (tooltip != null && tooltip!.isNotEmpty) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}

/// Centered frosted glass capsule for title and subtitle.
class GlassTitlePill extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool? isDark;
  final bool centerTitle;
  final double height;
  final EdgeInsetsGeometry padding;

  const GlassTitlePill({
    super.key,
    required this.title,
    this.subtitle,
    this.isDark,
    this.centerTitle = true,
    this.height = 44.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 18),
  });

  @override
  Widget build(BuildContext context) {
    final bool effectiveDark =
        isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final textPrimary =
        effectiveDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        effectiveDark ? Colors.white70 : const Color(0xFF64748B);
    final bool hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    final double effectiveHeight = hasSubtitle ? (height < 48.0 ? 48.0 : height) : height;

    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: effectiveHeight,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            color: effectiveDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.75),
            border: Border.all(
              color: effectiveDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: effectiveDark ? 0.25 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: centerTitle
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: hasSubtitle ? 13.5 : 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              if (hasSubtitle) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A floating top bar overlay placed inside a `Stack` (`Positioned(top: ..., left: ..., right: ...)`).
/// Standardized height (44px) matching Home screen top bar buttons.
class FloatingTopBar extends StatelessWidget {
  final Widget? leading;
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final List<GlassNavPillItem>? actionItems;
  final bool? isDark;
  final double top;
  final double horizontal;
  final bool centerTitle;
  final VoidCallback? onBack;
  final bool showBack;
  final String? fallbackRoute;
  final PreferredSizeWidget? bottomTabBar;

  const FloatingTopBar({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.actions,
    this.actionItems,
    this.isDark,
    this.top = 12.0,
    this.horizontal = 16.0,
    this.centerTitle = true,
    this.onBack,
    this.showBack = true,
    this.fallbackRoute,
    this.bottomTabBar,
  });

  @override
  Widget build(BuildContext context) {
    final bool effectiveDark =
        isDark ?? (Theme.of(context).brightness == Brightness.dark);

    Widget? rightWidget;
    if (actionItems != null && actionItems!.isNotEmpty) {
      if (actionItems!.length == 1) {
        final it = actionItems!.first;
        rightWidget = GlassNavButton(
          icon: it.icon,
          onTap: it.onTap,
          tooltip: it.tooltip,
          iconColor: it.iconColor ??
              (effectiveDark ? Colors.white : const Color(0xFF0F172A)),
          badge: it.badge,
          isLoading: it.isLoading,
          isDark: effectiveDark,
          size: 44,
        );
      } else {
        rightWidget = GlassNavPill(
          items: actionItems!,
          isDark: effectiveDark,
          height: 44,
        );
      }
    } else if (actions != null && actions!.isNotEmpty) {
      if (actions!.length == 1) {
        rightWidget = actions!.first;
      } else {
        rightWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: actions!,
        );
      }
    }

    Widget? leftWidget = leading;
    if (leftWidget == null && showBack) {
      leftWidget = GlassNavButton.back(
        context: context,
        isDark: effectiveDark,
        onBack: onBack,
        fallbackRoute: fallbackRoute,
        size: 44,
        iconSize: 20,
      );
    }

    Widget? titleWidget;
    if (title != null && title!.isNotEmpty) {
      titleWidget = GlassTitlePill(
        title: title!,
        subtitle: subtitle,
        isDark: effectiveDark,
        centerTitle: centerTitle,
      );
    }

    return Positioned(
      top: top,
      left: horizontal,
      right: horizontal,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leftWidget ?? const SizedBox(width: 44, height: 44),
              if (titleWidget != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: centerTitle
                      ? Center(child: titleWidget)
                      : Align(alignment: Alignment.centerLeft, child: titleWidget),
                ),
                const SizedBox(width: 10),
              ] else
                const Spacer(),
              rightWidget ??
                  (centerTitle
                      ? const SizedBox(width: 44, height: 44)
                      : const SizedBox.shrink()),
            ],
          ),
          if (bottomTabBar != null) ...[
            const SizedBox(height: 10),
            bottomTabBar!,
          ],
        ],
      ),
    );
  }
}

/// Standardized Edge-to-Edge Scaffold with Floating Glass Header and built-in PopScope
class GlassScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final bool showBack;
  final VoidCallback? onBack;
  final String? fallbackRoute;
  final List<Widget>? actions;
  final List<GlassNavPillItem>? actionItems;
  final PreferredSizeWidget? bottomTabBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool? isDark;
  final Color? backgroundColor;
  final bool centerTitle;
  final double contentTopPadding;

  const GlassScaffold({
    super.key,
    required this.body,
    this.title,
    this.subtitle,
    this.leading,
    this.showBack = true,
    this.onBack,
    this.fallbackRoute,
    this.actions,
    this.actionItems,
    this.bottomTabBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.isDark,
    this.backgroundColor,
    this.centerTitle = true,
    this.contentTopPadding = 64.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool effectiveDark =
        isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final scaffold = Scaffold(
      backgroundColor: backgroundColor ??
          (effectiveDark ? const Color(0xFF0A0A14) : const Color(0xFFF8FAFC)),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: body,
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: bottomTabBar != null ? 120.0 : 76.0,
              child: IgnorePointer(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            (backgroundColor ??
                                (effectiveDark ? const Color(0xFF0A0A14) : const Color(0xFFF8FAFC))),
                            (backgroundColor ??
                                    (effectiveDark ? const Color(0xFF0A0A14) : const Color(0xFFF8FAFC)))
                                .withValues(alpha: 0.85),
                            (backgroundColor ??
                                    (effectiveDark ? const Color(0xFF0A0A14) : const Color(0xFFF8FAFC)))
                                .withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.65, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            FloatingTopBar(
              title: title,
              subtitle: subtitle,
              leading: leading,
              showBack: showBack,
              onBack: onBack,
              fallbackRoute: fallbackRoute,
              actionItems: actionItems,
              actions: actions,
              isDark: effectiveDark,
              centerTitle: centerTitle,
              bottomTabBar: bottomTabBar,
            ),
          ],
        ),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        GlassNavButton.safeNavBack(
          context,
          onBack: onBack,
          fallbackRoute: fallbackRoute,
        );
      },
      child: scaffold,
    );
  }
}

/// Standard in-body Glass Top Bar for screens that build headers inside a Column or SafeArea
class GlassTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool showBack;
  final VoidCallback? onBack;
  final String? fallbackRoute;
  final List<Widget>? actions;
  final List<GlassNavPillItem>? actionItems;
  final bool? isDark;
  final bool centerTitle;
  final EdgeInsetsGeometry padding;

  const GlassTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.showBack = true,
    this.onBack,
    this.fallbackRoute,
    this.actions,
    this.actionItems,
    this.isDark,
    this.centerTitle = true,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
  });

  @override
  Widget build(BuildContext context) {
    final bool effectiveDark =
        isDark ?? (Theme.of(context).brightness == Brightness.dark);

    Widget? rightWidget;
    if (actionItems != null && actionItems!.isNotEmpty) {
      if (actionItems!.length == 1) {
        final it = actionItems!.first;
        rightWidget = GlassNavButton(
          icon: it.icon,
          onTap: it.onTap,
          tooltip: it.tooltip,
          iconColor: it.iconColor ??
              (effectiveDark ? Colors.white : const Color(0xFF0F172A)),
          badge: it.badge,
          isLoading: it.isLoading,
          isDark: effectiveDark,
          size: 44,
        );
      } else {
        rightWidget = GlassNavPill(
          items: actionItems!,
          isDark: effectiveDark,
          height: 44,
        );
      }
    } else if (actions != null && actions!.isNotEmpty) {
      if (actions!.length == 1) {
        rightWidget = actions!.first;
      } else {
        rightWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: actions!,
        );
      }
    }

    Widget? leftWidget = leading;
    if (leftWidget == null && showBack) {
      leftWidget = GlassNavButton.back(
        context: context,
        isDark: effectiveDark,
        onBack: onBack,
        fallbackRoute: fallbackRoute,
        size: 44,
        iconSize: 20,
      );
    }

    return Padding(
      padding: padding,
      child: SizedBox(
        height: 44,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            leftWidget ?? const SizedBox(width: 44, height: 44),
            const SizedBox(width: 10),
            Expanded(
              child: centerTitle
                  ? Center(
                      child: GlassTitlePill(
                        title: title,
                        subtitle: subtitle,
                        isDark: effectiveDark,
                        centerTitle: centerTitle,
                      ),
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: GlassTitlePill(
                        title: title,
                        subtitle: subtitle,
                        isDark: effectiveDark,
                        centerTitle: centerTitle,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            rightWidget ??
                (centerTitle
                    ? const SizedBox(width: 44, height: 44)
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

/// Standard Drop-in PreferredSize Glass AppBar for Scaffolds
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool showBack;
  final VoidCallback? onBack;
  final String? fallbackRoute;
  final List<Widget>? actions;
  final List<GlassNavPillItem>? actionItems;
  final bool? isDark;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;
  final double toolbarHeight;

  const GlassAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.showBack = true,
    this.onBack,
    this.fallbackRoute,
    this.actions,
    this.actionItems,
    this.isDark,
    this.centerTitle = true,
    this.bottom,
    this.toolbarHeight = 64.0,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(toolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context) {
    final bool effectiveDark =
        isDark ?? (Theme.of(context).brightness == Brightness.dark);

    Widget? rightWidget;
    if (actionItems != null && actionItems!.isNotEmpty) {
      if (actionItems!.length == 1) {
        final it = actionItems!.first;
        rightWidget = GlassNavButton(
          icon: it.icon,
          onTap: it.onTap,
          tooltip: it.tooltip,
          iconColor: it.iconColor ??
              (effectiveDark ? Colors.white : const Color(0xFF0F172A)),
          badge: it.badge,
          isLoading: it.isLoading,
          isDark: effectiveDark,
          size: 44,
        );
      } else {
        rightWidget = GlassNavPill(
          items: actionItems!,
          isDark: effectiveDark,
          height: 44,
        );
      }
    } else if (actions != null && actions!.isNotEmpty) {
      if (actions!.length == 1) {
        rightWidget = actions!.first;
      } else {
        rightWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: actions!,
        );
      }
    }

    Widget? leftWidget = leading;
    if (leftWidget == null && showBack) {
      leftWidget = GlassNavButton.back(
        context: context,
        isDark: effectiveDark,
        onBack: onBack,
        fallbackRoute: fallbackRoute,
        size: 44,
        iconSize: 20,
      );
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: toolbarHeight,
      titleSpacing: 16,
      title: SizedBox(
        height: 44,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            leftWidget ?? const SizedBox(width: 44, height: 44),
            const SizedBox(width: 10),
            Expanded(
              child: centerTitle
                  ? Center(
                      child: GlassTitlePill(
                        title: title,
                        subtitle: subtitle,
                        isDark: effectiveDark,
                        centerTitle: centerTitle,
                      ),
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: GlassTitlePill(
                        title: title,
                        subtitle: subtitle,
                        isDark: effectiveDark,
                        centerTitle: centerTitle,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            rightWidget ??
                (centerTitle
                    ? const SizedBox(width: 44, height: 44)
                    : const SizedBox.shrink()),
          ],
        ),
      ),
      bottom: bottom,
    );
  }
}
