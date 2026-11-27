import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerCourierRate {
  final String serviceId;
  final String serviceName;
  final String serviceDetail; // pickup / dropoff / dropoff/pickup
  final String courierId;
  final String courierKey;
  final String courierName;
  final String courierLogo;
  final String delivery;
  final int estimatedDays;
  final bool isPreferred;
  final double price;

  const CustomerCourierRate({
    required this.serviceId,
    required this.serviceName,
    required this.serviceDetail,
    required this.courierId,
    this.courierKey = '',
    required this.courierName,
    required this.courierLogo,
    required this.delivery,
    this.estimatedDays = 3,
    this.isPreferred = false,
    required this.price,
  });

  static String _formatDelivery(dynamic raw) {
    if (raw == null) return '1-3 working day(s)';
    Map<String, dynamic>? obj;
    if (raw is Map) {
      obj = Map<String, dynamic>.from(raw);
    } else if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty) return '1-3 working day(s)';
      if (t.startsWith('{')) {
        try {
          final decoded = jsonDecode(t);
          if (decoded is Map) obj = Map<String, dynamic>.from(decoded);
        } catch (_) {
          return t;
        }
      } else {
        return t;
      }
    }
    if (obj != null && obj['value'] != null) {
      final val = obj['value'].toString().trim();
      final type = (obj['type'] ?? 'days').toString().toLowerCase();
      if (type.contains('hour')) return '$val hour(s)';
      return '$val working day(s)';
    }
    return raw.toString();
  }

  static int _parseDays(dynamic rawDays, String deliveryText) {
    if (rawDays is num) return rawDays.toInt();
    final lower = deliveryText.toLowerCase();
    if (lower.contains('hour') || lower.contains('same day')) return 0;
    final m = RegExp(r'(\d+)').firstMatch(lower);
    return m != null ? (int.tryParse(m.group(1) ?? '3') ?? 3) : 3;
  }

  factory CustomerCourierRate.fromJson(Map<String, dynamic> json) {
    final deliveryText = _formatDelivery(json['delivery']);
    return CustomerCourierRate(
      serviceId: json['service_id']?.toString() ?? '',
      serviceName: json['service_name']?.toString() ?? '',
      serviceDetail: json['service_detail']?.toString() ?? 'pickup',
      courierId: json['courier_id']?.toString() ?? '',
      courierKey: json['courier_key']?.toString() ?? '',
      courierName: json['courier_name']?.toString() ?? '',
      courierLogo: json['courier_logo']?.toString() ?? '',
      delivery: deliveryText,
      estimatedDays: _parseDays(json['estimated_days'], deliveryText),
      isPreferred: json['is_preferred'] == true,
      price: (json['price'] as num?)?.toDouble() ??
          double.tryParse(json['price']?.toString() ?? '0') ??
          0.0,
    );
  }
}

class CustomerRatesResult {
  final bool easyparcelEnabled;
  final bool needsPostcode;
  final String checkoutMode; // 'customer_choice' | 'auto_best'
  final List<CustomerCourierRate> rates;
  final String? error;

  const CustomerRatesResult({
    required this.easyparcelEnabled,
    this.needsPostcode = false,
    this.checkoutMode = 'customer_choice',
    this.rates = const [],
    this.error,
  });
}

class EasyParcelCustomerService {
  static String extractPostcode(String? address) {
    if (address == null || address.isEmpty) return '';
    final match = RegExp(r'\b\d{5}\b').firstMatch(address);
    return match?.group(0) ?? '';
  }

  static String guessStateCode(String? address) {
    final text = (address ?? '').toLowerCase();
    if (text.contains('kuala lumpur') || text.contains(' kl')) return 'kul';
    if (text.contains('putrajaya')) return 'pjy';
    if (text.contains('selangor') ||
        text.contains('shah alam') ||
        text.contains('petaling') ||
        text.contains('subang') ||
        text.contains('klang') ||
        text.contains('kajang') ||
        text.contains('puchong')) {
      return 'sgr';
    }
    if (text.contains('johor')) return 'jhr';
    if (text.contains('penang') || text.contains('pulau pinang')) return 'png';
    if (text.contains('perak') || text.contains('ipoh') || text.contains('taiping')) return 'prk';
    if (text.contains('kedah') || text.contains('alor setar') || text.contains('sungai petani')) return 'kdh';
    if (text.contains('perlis')) return 'pls';
    if (text.contains('negeri sembilan') || text.contains('seremban')) return 'nsn';
    if (text.contains('melaka') || text.contains('malacca')) return 'mlk';
    if (text.contains('pahang') || text.contains('kuantan')) return 'phg';
    if (text.contains('terengganu')) return 'trg';
    if (text.contains('kelantan') || text.contains('kota bharu')) return 'ktn';
    if (text.contains('sarawak') || text.contains('kuching')) return 'srw';
    if (text.contains('sabah') || text.contains('kota kinabalu')) return 'sbh';
    if (text.contains('labuan')) return 'lbn';
    return 'sgr';
  }

  static Future<String?> fetchMySavedAddress() async {
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return null;
      final row = await client
          .from('users')
          .select('user_address')
          .eq('id', uid)
          .maybeSingle();
      final addr = row?['user_address']?.toString().trim();
      return (addr != null && addr.isNotEmpty) ? addr : null;
    } catch (_) {
      return null;
    }
  }

  static Future<CustomerRatesResult> checkCourierRates({
    required String businessId,
    required String deliveryAddress,
    required double parcelValue,
    double weightKg = 1.0,
  }) async {
    try {
      final client = Supabase.instance.client;
      final token = client.auth.currentSession?.accessToken;
      if (token == null || token.isEmpty) {
        return const CustomerRatesResult(easyparcelEnabled: false);
      }

      final sendCode = extractPostcode(deliveryAddress);
      final sendState = guessStateCode(deliveryAddress);

      final res = await client.functions.invoke(
        'easyparcel-proxy',
        headers: {'Authorization': 'Bearer $token'},
        body: {
          'action': 'customer_check_rates',
          'business_id': businessId,
          'send_code': sendCode,
          'send_state': sendState,
          'weight': weightKg > 0 ? weightKg : 1.0,
          'parcel_value': parcelValue > 0 ? parcelValue : 50.0,
        },
      );

      Map<String, dynamic> data = {};
      if (res.data is Map) {
        data = Map<String, dynamic>.from(res.data as Map);
      } else if (res.data is String && (res.data as String).trim().startsWith('{')) {
        try {
          final decoded = jsonDecode(res.data as String);
          if (decoded is Map) data = Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }

      final enabled = data['easyparcel_enabled'] == true;
      if (!enabled) {
        return CustomerRatesResult(
          easyparcelEnabled: false,
          error: data['error']?.toString(),
        );
      }

      final checkoutMode =
          data['checkout_mode']?.toString() == 'auto_best' ? 'auto_best' : 'customer_choice';

      if (data['needs_postcode'] == true) {
        return CustomerRatesResult(
          easyparcelEnabled: true,
          needsPostcode: true,
          checkoutMode: checkoutMode,
        );
      }

      if (data['success'] != true) {
        return CustomerRatesResult(
          easyparcelEnabled: true,
          checkoutMode: checkoutMode,
          error: data['error']?.toString(),
        );
      }

      final rawRates = (data['rates'] as List?) ?? [];
      final rates = rawRates
          .whereType<Map>()
          .map((e) => CustomerCourierRate.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      return CustomerRatesResult(
        easyparcelEnabled: true,
        checkoutMode: checkoutMode,
        rates: rates,
      );
    } catch (e) {
      debugPrint('[EasyParcelCustomerService] checkCourierRates error: $e');
      return CustomerRatesResult(
        easyparcelEnabled: false,
        error: e.toString(),
      );
    }
  }
}
