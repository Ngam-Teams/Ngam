// =============================================================================
// pwa_theme_bridge.dart
// Unified bridge to dynamically adjust status bar and navigation bar colors
// across native mobile (SystemChrome) and PWA Web (meta theme-color).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pwa_theme_stub.dart'
    if (dart.library.js) 'pwa_theme_web.dart';

void applyAppThemeOverlay(bool isDark) {
  final Color bg = isDark ? const Color(0xFF0A0A14) : const Color(0xFFF8F9FA);
  final Brightness iconBrightness = isDark ? Brightness.light : Brightness.dark;

  try {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: iconBrightness,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: bg,
        systemNavigationBarIconBrightness: iconBrightness,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  } catch (_) {}

  try {
    syncPwaThemeColor(isDark);
  } catch (_) {}
}
