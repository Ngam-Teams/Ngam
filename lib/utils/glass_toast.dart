import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

// ============================================================
// Ngam App — Glass Toast / Snackbar (Alert Cantik)
// Popup alert kaca yang boleh custom letak ikon, warna dengan ayat
// ============================================================

enum GlassToastType { success, error, warning, info }

void showGlassToast(
  BuildContext context,
  String message, {
  bool isError = false,
  GlassToastType? type,
  Color? color,
  Color? customColor,
  dynamic icon,
  dynamic customIcon,
  bool showIcon = true,
  Duration duration = const Duration(seconds: 4),
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  // Resolve jenis toast
  final resolvedType = type ?? (isError ? GlassToastType.error : GlassToastType.success);

  // Cari warna yang sesuai
  final resolvedColor = customColor ?? color ?? _colorForType(resolvedType);

  // Cari icon yang sesuai
  final resolvedIcon = customIcon ?? icon ?? _iconForType(resolvedType);

  // Bersihkan mesej error
  final displayMessage = resolvedType == GlassToastType.error
      ? _cleanErrorMessage(message)
      : message;

  final scaffoldMessenger = ScaffoldMessenger.of(context);
  scaffoldMessenger.removeCurrentSnackBar();
  scaffoldMessenger.showSnackBar(
    SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      duration: duration,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      content: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: isDark
                  ? resolvedColor.withValues(alpha: 0.18)
                  : resolvedColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: resolvedColor.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: resolvedColor.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => scaffoldMessenger.hideCurrentSnackBar(),
              child: Row(
                children: [
                  if (showIcon) ...[
                    _ToastIcon(icon: resolvedIcon, color: resolvedColor),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      displayMessage,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ToastIcon extends StatelessWidget {
  final dynamic icon;
  final Color color;

  const _ToastIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    if (icon is IconData) {
      return Icon(icon as IconData, color: color, size: 20);
    }
    try {
      return HugeIcon(icon: icon, color: color, size: 20);
    } catch (_) {
      return Icon(Icons.info_outline_rounded, color: color, size: 20);
    }
  }
}

Color _colorForType(GlassToastType type) {
  switch (type) {
    case GlassToastType.success:
      return const Color(0xFF2ECC71);
    case GlassToastType.error:
      return Colors.redAccent;
    case GlassToastType.warning:
      return const Color(0xFFF39C12);
    case GlassToastType.info:
      return const Color(0xFF3498DB);
  }
}

dynamic _iconForType(GlassToastType type) {
  switch (type) {
    case GlassToastType.success:
      return HugeIcons.strokeRoundedCheckmarkCircle02;
    case GlassToastType.error:
      return HugeIcons.strokeRoundedAlertCircle;
    case GlassToastType.warning:
      return HugeIcons.strokeRoundedAlert02;
    case GlassToastType.info:
      return HugeIcons.strokeRoundedInformationCircle;
  }
}

String _cleanErrorMessage(String raw) {
  if (raw.contains('Invalid login credentials')) {
    return 'E-mel atau kata laluan tidak sah.';
  }
  if (raw.contains('User already registered')) {
    return 'E-mel ini sudah berdaftar. Sila log masuk.';
  }
  if (raw.contains('Network request failed') || raw.contains('SocketException')) {
    return 'Masalah sambungan internet. Sila cuba lagi.';
  }
  if (raw.contains('Password should be')) {
    return 'Kata laluan terlalu lemah (minimum 6 aksara).';
  }
  return raw.replaceAll(RegExp(r'^Exception:\s*'), '').trim();
}
