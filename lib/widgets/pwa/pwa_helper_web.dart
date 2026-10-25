// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:js' as js;

bool isPwaInstallSupported() {
  try {
    final ua = html.window.navigator.userAgent.toLowerCase();
    final isMobile = ua.contains('mobile') || ua.contains('android') || ua.contains('iphone');
    final isStandalone = html.window.matchMedia('(display-mode: standalone)').matches;
    return isMobile && !isStandalone;
  } catch (_) {
    return false;
  }
}

bool isRunningStandalone() {
  try {
    return html.window.matchMedia('(display-mode: standalone)').matches;
  } catch (_) {
    return false;
  }
}

bool isIosSafari() {
  try {
    final ua = html.window.navigator.userAgent.toLowerCase();
    final isIos = ua.contains('iphone') || ua.contains('ipad');
    final isSafari = ua.contains('safari') && !ua.contains('chrome') && !ua.contains('crios');
    return isIos && isSafari;
  } catch (_) {
    return false;
  }
}

void triggerPwaPrompt() {
  try {
    js.context.callMethod('triggerPWAInstall');
  } catch (_) {}
}
