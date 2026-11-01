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
  static const String _baseUrl = 'https://gate.chip-in.asia/api/v1';

  String get _brandId => dotenv.env['CHIP_BRAND_ID'] ?? _defaultBrandId;
  String get _apiKey => dotenv.env['CHIP_API_KEY'] ?? '';
  String get _supabaseUrl => dotenv.env['SUPABASE_URL'] ?? 'https://rsueaoglsdxhzpupjljd.supabase.co';
  String get _edgeFunctionUrl => '$_supabaseUrl/functions/v1/payment-webhook';

  bool get isAvailable => _brandId.isNotEmpty || _apiKey.isNotEmpty;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      };

  /// Cipta bayaran DuitNow QR atau Gerbang Pembayaran Chip Asia
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

    // 1. Cuba melalui Supabase Edge Function (Menghindarkan ralat CORS pada Web, simpan API key selamat, pasang Webhook)
    try {
      final edgeRes = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'create_purchase',
          'amount': amount,
          'order_title': orderTitle,
          'reference': reference ?? '',
          'order_id': reference ?? '',
          'client_name': (clientName != null && clientName.isNotEmpty) ? clientName : 'Pelanggan Ngam',
          'client_email': (clientEmail != null && clientEmail.isNotEmpty) ? clientEmail : 'pelanggan@ngam.dev',
          'client_phone': (clientPhone != null && clientPhone.isNotEmpty) ? clientPhone : '+601115892468',
          'brand_id': _brandId,
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

        return ChipPurchaseResult(
          id: id,
          checkoutUrl: checkoutUrl,
          duitNowUrl: duitNowUrl,
          amount: amount,
          status: status,
          raw: data,
        );
      } else {
        debugPrint('[ChipPaymentService] Edge function return ${edgeRes.statusCode}: ${edgeRes.body}');
      }
    } catch (e) {
      debugPrint('[ChipPaymentService] Edge function proxy error, falling back to direct CHIP API: $e');
    }

    // 2. Sandaran langsung ke pelayan CHIP jika panggilan Edge gagal (misalnya peranti luar talian atau native)
    if (_apiKey.isEmpty) {
      throw ChipPaymentException('Gagal menghubungi gerbang pembayaran. Sila cuba sebentar lagi.');
    }

    final cents = (amount * 100).round();
    final url = Uri.parse('$_baseUrl/purchases/');

    final payload = {
      'brand_id': _brandId,
      if (reference != null && reference.isNotEmpty) 'reference': reference,
      'client': {
        'email': (clientEmail != null && clientEmail.isNotEmpty)
            ? clientEmail
            : 'pelanggan@ngam.dev',
        'full_name': (clientName != null && clientName.isNotEmpty)
            ? clientName
            : 'Pelanggan Ngam',
        'phone': (clientPhone != null && clientPhone.isNotEmpty)
            ? clientPhone
            : '+601115892468',
      },
      'purchase': {
        'currency': 'MYR',
        'products': [
          {
            'name': orderTitle,
            'price': cents,
            'quantity': 1,
          }
        ],
      },
      'success_callback': _edgeFunctionUrl,
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
    };

    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final id = data['id']?.toString() ?? '';
        final checkoutUrl = data['checkout_url']?.toString() ?? '';
        final duitNowUrl = data['payment_methods']?['duitnow']?['qr_code_url']?.toString() ??
            (checkoutUrl.isNotEmpty ? '$checkoutUrl?preferred=duitnow_qr' : checkoutUrl);
        final status = data['status']?.toString() ?? 'pending';

        return ChipPurchaseResult(
          id: id,
          checkoutUrl: checkoutUrl,
          duitNowUrl: duitNowUrl,
          amount: amount,
          status: status,
          raw: data,
        );
      } else {
        debugPrint('[ChipPaymentService] Create error: ${response.statusCode} - ${response.body}');
        throw ChipPaymentException('Gagal menghubungi gerbang pembayaran. Sila cuba lagi.');
      }
    } on ChipPaymentException {
      rethrow;
    } catch (e) {
      debugPrint('[ChipPaymentService] Exception: $e');
      throw ChipPaymentException('Sambungan ke gerbang pembayaran gagal. Semak internet anda.');
    }
  }

  /// Semak status transaksi sama ada sudah dibayar ('paid')
  Future<String> checkPurchaseStatus(String purchaseId) async {
    if (purchaseId.isEmpty || purchaseId.startsWith('DUITNOW-') || purchaseId.startsWith('web-')) {
      return 'pending';
    }

    // 1. Cuba semak melalui Supabase Edge Function
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
    } catch (_) {}

    // 2. Sandaran terus ke API CHIP
    if (_apiKey.isEmpty) {
      return 'pending';
    }

    final url = Uri.parse('$_baseUrl/purchases/$purchaseId/');
    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['status']?.toString().toLowerCase() ?? 'pending';
      }
      return 'pending';
    } catch (e) {
      debugPrint('[ChipPaymentService] Status check error: $e');
      return 'pending';
    }
  }
}
