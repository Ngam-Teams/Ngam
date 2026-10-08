import 'dart:ui';
import 'package:flutter/material.dart';
export 'glass_card.dart';

enum GlassQuality { standard, high }

class LiquidRoundedSuperellipse {
  final double borderRadius;
  const LiquidRoundedSuperellipse({required this.borderRadius});
}

class LiquidGlassSettings {
  final double thickness;
  final double blur;
  final double refractiveIndex;
  final Color glassColor;
  final double lightAngle;
  final double lightIntensity;
  final double ambientStrength;
  final double saturation;
  final double chromaticAberration;

  const LiquidGlassSettings({
    this.thickness = 0.1,
    this.blur = 16.0,
    this.refractiveIndex = 1.0,
    this.glassColor = Colors.transparent,
    this.lightAngle = 45.0,
    this.lightIntensity = 0.2,
    this.ambientStrength = 1.0,
    this.saturation = 1.0,
    this.chromaticAberration = 0.0,
  });
}

/// Native, high-performance frosted glass container that works flawlessly
/// across Mobile (Android/iOS) and Web without requiring unstable fragment shaders.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final dynamic shape;
  final LiquidGlassSettings? settings;
  final GlassQuality? quality;
  final bool? useOwnLayer;
  final double borderRadius;

  const GlassContainer({
    super.key,
    required this.child,
    this.shape,
    this.settings,
    this.quality,
    this.useOwnLayer,
    this.borderRadius = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    double radius = borderRadius;
    if (shape is LiquidRoundedSuperellipse) {
      radius = (shape as LiquidRoundedSuperellipse).borderRadius;
    }

    final double blurAmount = (settings?.blur != null && settings!.blur > 0)
        ? (settings!.blur < 6 ? 14.0 : settings!.blur)
        : 14.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: child,
      ),
    );
  }
}

/// Direct container with frosted backdrop styling
class GlassBox extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final Color? color;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const GlassBox({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.blur = 16.0,
    this.color,
    this.border,
    this.boxShadow,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: color ??
                (isDark
                    ? Colors.black.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.65)),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ??
                Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.4),
                  width: 1.0,
                ),
            boxShadow: boxShadow ??
                [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
          ),
          child: child,
        ),
      ),
    );
  }
}
