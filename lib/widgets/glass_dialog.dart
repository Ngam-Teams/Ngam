import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:easy_localization/easy_localization.dart';

import 'glass_box.dart';
import '../utils/app_theme.dart';

// =============================================================================
// GlassConfirmDialog
// Replicates the exact Liquid Glass styling from Discover Page Carousel Card:
// - GlassContainer with LiquidGlassSettings & LiquidRoundedSuperellipse
// - Crystal-clear frosted transparency (no heavy opaque dark tint)
// - Frosted text glow and delicate specular borders
// - Smooth pill action buttons with subtle luminous gradients
// =============================================================================

class GlassConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? confirmText;
  final String? cancelText;
  final dynamic icon;
  final bool isDestructive;
  final Color? customAccentColor;

  const GlassConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText,
    this.cancelText,
    this.icon,
    this.isDestructive = false,
    this.customAccentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveAccent = customAccentColor ??
        (isDestructive ? const Color(0xFFEF4444) : AppTheme.primary);

    final frostedGlow = [
      Shadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 8),
      Shadow(
        color: Colors.black.withValues(alpha: 0.2),
        offset: const Offset(0.5, 0.5),
        blurRadius: 0,
      ),
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: GlassContainer(
            useOwnLayer: true,
            quality: GlassQuality.standard,
            shape: const LiquidRoundedSuperellipse(borderRadius: 24.0),
            settings: LiquidGlassSettings(
              thickness: 0.1,
              blur: 16.0,
              glassColor: Colors.transparent,
              lightAngle: 45.0,
              lightIntensity: 0.1,
              ambientStrength: 1.0,
              saturation: 1.0,
              chromaticAberration: 0.0,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.45),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Unboxed clean icon + title with frosted glow
                  Row(
                    children: [
                      if (icon != null) ...[
                        icon is IconData
                            ? Icon(
                                icon as IconData,
                                color: effectiveAccent,
                                size: 22,
                              )
                            : HugeIcon(
                                icon: icon,
                                color: effectiveAccent,
                                size: 22,
                                strokeWidth: 2.2,
                              ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                            shadows: isDark ? frostedGlow : [],
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Message Body
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.78)
                          : const Color(0xFF3A3A3C).withValues(alpha: 0.85),
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Cancel Button (Frosted Glass Pill)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, false),
                          borderRadius: BorderRadius.circular(100),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.35),
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              cancelText ?? 'common.cancel'.tr(),
                              style: TextStyle(
                                color: isDark ? Colors.white70 : const Color(0xFF3A3A3C),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Confirm Action Button (Vibrant Pill matching Discover actions)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, true),
                          borderRadius: BorderRadius.circular(100),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isDestructive
                                    ? [
                                        const Color(0xFFEF4444).withValues(alpha: isDark ? 0.85 : 0.95),
                                        const Color(0xFFDC2626).withValues(alpha: isDark ? 0.70 : 0.85),
                                      ]
                                    : [
                                        const Color(0xFF0284C7).withValues(alpha: isDark ? 0.85 : 0.95),
                                        const Color(0xFF0369A1).withValues(alpha: isDark ? 0.70 : 0.85),
                                      ],
                              ),
                              border: Border.all(
                                color: isDestructive
                                    ? const Color(0xFFFCA5A5).withValues(alpha: 0.60)
                                    : const Color(0xFF38BDF8).withValues(alpha: 0.60),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isDestructive
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF0284C7))
                                      .withValues(alpha: 0.30),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              confirmText ??
                                  (isDestructive
                                      ? 'common.log_out'.tr()
                                      : 'common.confirm'.tr()),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper function to display the glass confirmation dialog easily from any screen
Future<bool?> showGlassConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmText,
  String? cancelText,
  dynamic icon,
  bool isDestructive = false,
  Color? customAccentColor,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) => GlassConfirmDialog(
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      icon: icon,
      isDestructive: isDestructive,
      customAccentColor: customAccentColor,
    ),
  );
}
