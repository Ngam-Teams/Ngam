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
