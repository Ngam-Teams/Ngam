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

class ChipPaymentService {
  static final ChipPaymentService instance = ChipPaymentService._internal();
  ChipPaymentService._internal();

  static const String _baseUrl = 'https://gate.chip-in.asia/api/v1';

  String get _brandId => dotenv.env['CHIP_BRAND_ID'] ?? 'a3471018-b715-4fa3-9db8-b57faee960d7';

  String get _apiKey => dotenv.env['CHIP_API_KEY'] ?? '';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      };

  /// Cipta bayaran DuitNow QR atau Gerbang Pembayaran Chip Asia
  Future<ChipPurchaseResult> createPurchase({
    required double amount,
    required String orderTitle,
    String? clientName,
    String? clientEmail,
    String? clientPhone,
  }) async {
    final cents = (amount * 100).round();
    final url = Uri.parse('$_baseUrl/purchases/');

    final payload = {
      'brand_id': _brandId,
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
      'success_redirect': 'https://ngam.dev/receipt/success',
      'failure_redirect': 'https://ngam.dev/receipt/failed',
      'cancel_redirect': 'https://ngam.dev/receipt/cancel',
    };

    if (_apiKey.isEmpty) {
      debugPrint('[ChipPaymentService] CHIP_API_KEY tidak dikonfigurasi. Menggunakan mod simulasi.');
      return _generateFallbackResult(amount, orderTitle);
    }

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
        final duitNowUrl = data['payment_methods']?['duitnow']?['qr_code_url']?.toString() ?? checkoutUrl;
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
        return _generateFallbackResult(amount, orderTitle);
      }
    } catch (e) {
      debugPrint('[ChipPaymentService] Exception: $e. Mengaktifkan mod simulasi selamat.');
      return _generateFallbackResult(amount, orderTitle);
    }
  }

  /// Semak status transaksi sama ada sudah dibayar ('paid')
  Future<String> checkPurchaseStatus(String purchaseId) async {
    if (purchaseId.startsWith('sim_') || _apiKey.isEmpty) {
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

  ChipPurchaseResult _generateFallbackResult(double amount, String orderTitle) {
    final simId = 'sim_${DateTime.now().millisecondsSinceEpoch}';
    final qrData = '00020101021226580014my.com.duitnow0118NGAMPAYMENTGATEWAY520458125303458540${amount.toStringAsFixed(2)}5802MY5910NGAMSTORE6005BANGI62150111NGAM${simId.substring(4, 10)}6304A1B2';

    return ChipPurchaseResult(
      id: simId,
      checkoutUrl: 'https://gate.chip-in.asia/p/$simId',
      duitNowUrl: qrData,
      amount: amount,
      status: 'pending',
      raw: {
        'is_web_fallback': true,
        'simulated_qr_data': qrData,
      },
    );
  }
}
