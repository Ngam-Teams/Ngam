import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Single item within a GlassNavPill
class GlassNavPillItem {
  final dynamic icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? iconColor;
  final Widget? badge;

  const GlassNavPillItem({
    required this.icon,
    this.onTap,
    this.tooltip,
    this.iconColor,
    this.badge,
  });
}

/// A connected glass-morphism pill container that merges 2 (or more) buttons into
/// a single sleek pill, matching the top-right button on the Home screen (QR + Saved + Notification).
class GlassNavPill extends StatelessWidget {
  final List<GlassNavPillItem> items;
  final bool isDark;
  final double height;
  final EdgeInsetsGeometry? margin;

  const GlassNavPill({
    super.key,
    required this.items,
    required this.isDark,
    this.height = 44.0,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    Widget pill = ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.70),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _buildItem(items[i]),
                if (i < items.length - 1)
                  Container(
                    width: 1.0,
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
              ],
            ],
          ),
        ),
      ),
    );

    if (margin != null) {
      pill = Padding(padding: margin!, child: pill);
    }

    return pill;
  }

  Widget _buildItem(GlassNavPillItem item) {
    final Color effectiveIconColor = item.iconColor ??
        (isDark ? Colors.white.withValues(alpha: 0.90) : const Color(0xFF1E293B));

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
        splashColor: isDark ? Colors.white12 : Colors.black12,
        highlightColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
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
  final bool isDark;
  final EdgeInsetsGeometry? margin;

  const GlassNavButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 44.0,
    this.iconSize = 20.0,
    this.iconColor,
    required this.isDark,
    this.margin,
  });

  /// Factory constructor for a standard back navigation button
  factory GlassNavButton.back({
    Key? key,
    required BuildContext context,
    required bool isDark,
    VoidCallback? onBack,
    double size = 44.0,
    double iconSize = 20.0,
    EdgeInsetsGeometry? margin,
  }) {
    return GlassNavButton(
      key: key,
      icon: HugeIcons.strokeRoundedArrowLeft01,
      onTap: onBack ?? () => Navigator.pop(context),
      isDark: isDark,
      size: size,
      iconSize: iconSize,
      tooltip: 'Kembali',
      margin: margin,
    );
  }

  /// Factory constructor for a standard close/cancel navigation button
  factory GlassNavButton.close({
    Key? key,
    required BuildContext context,
    required bool isDark,
    VoidCallback? onClose,
    double size = 44.0,
    double iconSize = 20.0,
    EdgeInsetsGeometry? margin,
  }) {
    return GlassNavButton(
      key: key,
      icon: HugeIcons.strokeRoundedCancel01,
      onTap: onClose ?? () => Navigator.pop(context),
      isDark: isDark,
      size: size,
      iconSize: iconSize,
      tooltip: 'Tutup',
      margin: margin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color effectiveIconColor = iconColor ??
        (isDark ? Colors.white.withValues(alpha: 0.90) : const Color(0xFF1E293B));

    Widget button = ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.70),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
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
              splashColor: isDark ? Colors.white12 : Colors.black12,
              highlightColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              child: Center(
                child: icon is IconData
                    ? Icon(
                        icon as IconData,
                        size: iconSize,
                        color: effectiveIconColor,
                      )
                    : HugeIcon(
                        icon: icon,
                        size: iconSize,
                        color: effectiveIconColor,
                      ),
              ),
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

/// A floating top bar overlay placed inside a `Stack` (`Positioned(top: ..., left: ..., right: ...)`).
/// All elements have standardized height (44px) matching the Home screen top bar buttons.
/// When multiple action buttons are provided, they can be merged into a single pill using `GlassNavPill`.
class FloatingTopBar extends StatelessWidget {
  final Widget? leading;
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool isDark;
  final double top;
  final double horizontal;
  final bool centerTitle;

  const FloatingTopBar({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.actions,
    required this.isDark,
    this.top = 12.0,
    this.horizontal = 16.0,
    this.centerTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);

    Widget? titleWidget;
    if (title != null && title!.isNotEmpty) {
      titleWidget = ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 44, // Standard 44px height matching all nav buttons
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.75),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
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
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: (subtitle != null && subtitle!.isNotEmpty) ? 14 : 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Positioned(
      top: top,
      left: horizontal,
      right: horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          leading ??
              GlassNavButton.back(
                context: context,
                isDark: isDark,
                size: 44,
                iconSize: 20,
              ),
          if (titleWidget != null) ...[
            const SizedBox(width: 10),
            Flexible(
              child: centerTitle
                  ? Center(child: titleWidget)
                  : Align(alignment: Alignment.centerLeft, child: titleWidget),
            ),
            const SizedBox(width: 10),
          ] else
            const Spacer(),
          if (actions != null && actions!.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: actions!,
            )
          else if (titleWidget != null && centerTitle)
            const SizedBox(width: 44),
        ],
      ),
    );
  }
}
