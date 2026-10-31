import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// A premium, reusable glass-morphism circular/pill navigation button.
/// Matches the design aesthetic of the Home screen top bar pill buttons:
/// circular/pill shape with backdrop blur, subtle frosted surface, gentle border and shadow.
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
    this.size = 40.0,
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
    double size = 40.0,
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
    double size = 40.0,
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
/// Does NOT wrap the entire row in a solid/full-width bar container — only the buttons and optional
/// title pill float cleanly over the underlying scrollable content.
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
            padding: EdgeInsets.symmetric(
              horizontal: 18,
              vertical: (subtitle != null && subtitle!.isNotEmpty) ? 6 : 9,
            ),
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
                    fontSize: 15,
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
                      fontSize: 10.5,
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
        children: [
          leading ??
              GlassNavButton.back(
                context: context,
                isDark: isDark,
                size: 42,
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
            const SizedBox(width: 42),
        ],
      ),
    );
  }
}

