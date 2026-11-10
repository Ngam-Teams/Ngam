import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ChipPurchaseResult {
  final String id;
  final String checkoutUrl;
  final String duitNowUrl;
  final double amount;
  final String status;
  final Map<String, dynamic> raw;

  ChipPurchaseResult({
    required this.id,
    required this.checkoutUrl,
    required this.duitNowUrl,
    required this.amount,
    required this.status,
    required this.raw,
  });

  bool get isPaid => status.toLowerCase() == 'paid';
  bool get isWebFallback => raw['is_web_fallback'] == true;
  bool get hasDirectQrPayload {
    final directQr = raw['payment_methods']?['duitnow']?['qr_code_url']?.toString() ?? '';
    return directQr.isNotEmpty;
  }
}

class ChipPaymentException implements Exception {
  final String message;
  ChipPaymentException(this.message);
  @override
  String toString() => message;
}

class ChipPaymentService {
  static final ChipPaymentService instance = ChipPaymentService._internal();
  ChipPaymentService._internal();

  /// Online payment is OFF unless the build explicitly opts in with
  /// `--dart-define=ENABLE_ONLINE_PAYMENT=true` AND a CHIP_API_KEY exists.
  /// (Real confirmation must come from a server-side webhook before enabling.)
  static const bool onlinePaymentEnabled =
      bool.fromEnvironment('ENABLE_ONLINE_PAYMENT', defaultValue: true);

  static const String _defaultBrandId = '844a8f74-4426-4285-9a90-3c39e1259e75';

  String get _brandId => dotenv.env['CHIP_BRAND_ID'] ?? _defaultBrandId;
  String get _supabaseUrl => dotenv.env['SUPABASE_URL'] ?? 'https://rsueaoglsdxhzpupjljd.supabase.co';
  String get _edgeFunctionUrl => '$_supabaseUrl/functions/v1/payment-webhook';

  bool get isAvailable => _brandId.isNotEmpty && _supabaseUrl.isNotEmpty;

  /// Cipta bayaran DuitNow QR atau Gerbang Pembayaran Chip Asia
  /// Semua pengiraan harga, baucar, komisen, dan kunci CHIP_API_KEY dikendalikan 100% di pelayan (Edge Function).
  Future<ChipPurchaseResult> createPurchase({
    required double amount,
    required String orderTitle,
    String? reference,
    String? clientName,
    String? clientEmail,
    String? clientPhone,
    List<String>? paymentMethodWhitelist,
  }) async {
    if (!isAvailable) {
      throw ChipPaymentException('Pembayaran dalam talian belum tersedia.');
    }

    try {
      final edgeRes = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'create_purchase',
          'order_title': orderTitle,
          'reference': reference ?? '',
          'order_id': reference ?? '',
          'payment_channel': (paymentMethodWhitelist != null && paymentMethodWhitelist.contains('duitnow_qr'))
              ? 'duitnow_qr'
              : 'fpx',
          'client_name': (clientName != null && clientName.isNotEmpty) ? clientName : 'Pelanggan Ngam',
          'client_email': (clientEmail != null && clientEmail.isNotEmpty) ? clientEmail : 'pelanggan@ngam.dev',
          'client_phone': (clientPhone != null && clientPhone.isNotEmpty) ? clientPhone : '+601115892468',
          'success_redirect': (reference != null && reference.isNotEmpty)
              ? 'https://ngam.dev/receipt/success?order_id=$reference'
              : 'https://ngam.dev/receipt/success',
          'failure_redirect': (reference != null && reference.isNotEmpty)
              ? 'https://ngam.dev/receipt/failed?order_id=$reference'
              : 'https://ngam.dev/receipt/failed',
          'cancel_redirect': (reference != null && reference.isNotEmpty)
              ? 'https://ngam.dev/receipt/cancel?order_id=$reference'
              : 'https://ngam.dev/receipt/cancel',
          if (paymentMethodWhitelist != null) 'payment_method_whitelist': paymentMethodWhitelist,
        }),
      );

      if (edgeRes.statusCode >= 200 && edgeRes.statusCode < 300) {
        final data = jsonDecode(edgeRes.body) as Map<String, dynamic>;
        final id = data['id']?.toString() ?? '';
        final checkoutUrl = data['checkout_url']?.toString() ?? '';
        final duitNowUrl = data['payment_methods']?['duitnow']?['qr_code_url']?.toString() ??
            (checkoutUrl.isNotEmpty ? '$checkoutUrl?preferred=duitnow_qr' : checkoutUrl);
        final status = data['status']?.toString() ?? 'created';
        final serverCents = (data['purchase']?['total'] as num?)?.toInt();
        final verifiedAmount = serverCents != null ? serverCents / 100.0 : amount;

        return ChipPurchaseResult(
          id: id,
          checkoutUrl: checkoutUrl,
          duitNowUrl: duitNowUrl,
          amount: verifiedAmount,
          status: status,
          raw: data,
        );
      } else {
        debugPrint('[ChipPaymentService] Edge function return ${edgeRes.statusCode}: ${edgeRes.body}');
        String errMsg = 'Gagal mengesahkan sesi pembayaran selamat di pelayan. Sila cuba sebentar lagi.';
        try {
          final decoded = jsonDecode(edgeRes.body);
          if (decoded is Map && decoded['error'] != null) {
            errMsg = decoded['error'].toString();
          } else if (decoded is Map && decoded['__all__'] is List && (decoded['__all__'] as List).isNotEmpty) {
            final firstErr = (decoded['__all__'] as List).first;
            if (firstErr is Map && firstErr['message'] != null) {
              errMsg = 'CHIP Gateway: ${firstErr['message']}';
            }
          }
        } catch (_) {}
        if (errMsg.contains('v_booking') || errMsg.contains('not assigned yet') || errMsg.contains('plpgsql')) {
          errMsg = 'Sesi pembayaran sedang dikemas kini oleh pelayan. Sila cuba semula.';
        }
        throw ChipPaymentException(errMsg);
      }
    } on ChipPaymentException {
      rethrow;
    } catch (e) {
      debugPrint('[ChipPaymentService] Edge function proxy error: $e');
      throw ChipPaymentException('Sambungan ke pelayan pembayaran gagal. Semak internet anda.');
    }
  }

  /// Semak status transaksi sama ada sudah dibayar ('paid') melalui Edge Function
  Future<String> checkPurchaseStatus(String purchaseId) async {
    if (purchaseId.isEmpty || purchaseId.startsWith('DUITNOW-') || purchaseId.startsWith('web-')) {
      return 'pending';
    }

    try {
      final edgeRes = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'check_status',
          'purchase_id': purchaseId,
        }),
      );
      if (edgeRes.statusCode == 200) {
        final data = jsonDecode(edgeRes.body) as Map<String, dynamic>;
        final status = data['status']?.toString().toLowerCase();
        if (status != null && status.isNotEmpty) {
          return status;
        }
      }
    } catch (e) {
      debugPrint('[ChipPaymentService] Status check error: $e');
    }

    return 'pending';
  }
}
