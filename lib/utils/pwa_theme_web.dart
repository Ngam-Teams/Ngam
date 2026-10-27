// =============================================================================
// pwa_theme_web.dart
// Web implementation — calls window.updatePwaThemeColor to update PWA meta tags.
// =============================================================================

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

void syncPwaThemeColor(bool isDark) {
  try {
    js.context.callMethod('updatePwaThemeColor', [isDark]);
  } catch (_) {}
}
