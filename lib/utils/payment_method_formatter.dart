import 'package:easy_localization/easy_localization.dart';

/// Formats raw database / gateway payment method codes (including legacy CHIP /
/// Razer Merchant Services tokens like `razer`, `razer_tng`, `chip_online`,
/// `CHIP DuitNow QR / FPX`) into clean, user-friendly labels with NO internal
/// gateway branding and NO slashes.
class PaymentMethodFormatter {
  PaymentMethodFormatter._();

  static String format(String? raw) {
    final trimmed = (raw ?? '').trim();
    final lower = trimmed.toLowerCase();

    if (lower.isEmpty ||
        lower == 'online' ||
        lower == 'chip' ||
        lower == 'chip_online' ||
        lower == 'chip_asia' ||
        lower == 'razer' ||
        lower == 'razerpay' ||
        lower == 'rms' ||
        lower == 'molpay') {
      return 'order_status.method_online_fallback'.tr();
    }

    // Specific e-Wallets (including CHIP Razer connector codes)
    if (lower == 'razer_tng' ||
        lower == 'tng' ||
        lower.contains('touch') ||
        lower.contains('tng')) {
      return "Touch 'n Go eWallet";
    }
    if (lower == 'razer_grabpay' || lower == 'grabpay' || lower.contains('grab')) {
      return 'GrabPay';
    }
    if (lower == 'razer_shopeepay' || lower == 'shopeepay' || lower.contains('shopee')) {
      return 'ShopeePay';
    }
    if (lower == 'razer_boost' || lower == 'boost' || lower.contains('boost')) {
      return 'Boost';
    }
    if (lower == 'razer_atome' || lower == 'atome' || lower.contains('atome')) {
      return 'Atome';
    }

    // DuitNow QR (pure QR — never slashed with FPX or CHIP)
    if (lower == 'duitnow' ||
        lower == 'duitnow_qr' ||
        lower == 'razer_maybankqr' ||
        lower == 'maybankqr' ||
        lower == 'maybank_qr' ||
        lower == 'qr' ||
        (lower.contains('duitnow') &&
            !lower.contains('obw') &&
            !lower.contains('online') &&
            !lower.contains('transfer') &&
            !lower.contains('fpx'))) {
      return 'order_status.method_duitnow'.tr();
    }

    // DuitNow Online Banking / FPX
    if (lower == 'duitnow_obw' ||
        lower == 'duitnow_transfer' ||
        lower == 'fpx' ||
        lower == 'fpx_b2b1' ||
        lower == 'fpx_card' ||
        lower == 'online_banking' ||
        lower.contains('duitnow online') ||
        lower.contains('duitnow transfer') ||
        lower.contains('fpx')) {
      return 'order_status.method_fpx'.tr();
    }

    // Cards
    if (lower == 'visa') return 'Visa';
    if (lower == 'mastercard') return 'Mastercard';
    if (lower == 'card' ||
        lower.contains('credit') ||
        lower.contains('debit') ||
        lower.contains('visa') ||
        lower.contains('mastercard') ||
        lower.contains('kad')) {
      return 'order_status.method_card'.tr();
    }

    // NgamPay / Wallet
    if (lower == 'ngampay' || lower == 'wallet' || lower.contains('ngampay')) {
      return 'order_status.method_ngampay'.tr();
    }

    // Generic e-Wallet
    if (lower == 'ewallet' || lower == 'e-wallet' || lower.contains('ewallet')) {
      return 'order_status.method_ewallet'.tr();
    }

    // Cash / Counter / COD
    if (lower == 'cash' ||
        lower == 'tunai' ||
        lower == 'counter' ||
        lower == 'cod' ||
        lower.contains('cash') ||
        lower.contains('tunai')) {
      return 'order_status.method_cash'.tr();
    }

    // Strip any accidental legacy "(CHIP)" or "(CHIP Asia)" suffix
    final cleaned = trimmed
        .replaceAll(RegExp(r'\s*\(?chip(\s+asia)?\)?', caseSensitive: false), '')
        .trim();
    return cleaned.isNotEmpty ? cleaned : 'order_status.method_online_fallback'.tr();
  }
}
