import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VoucherService {
  static const String _savedVouchersKey = 'ngam_saved_vouchers';

  static final ValueNotifier<List<Map<String, dynamic>>> savedVouchersNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  static bool _initialized = false;

  /// Inisialisasi senarai baucar tersimpan dari peranti tempatan (SharedPreferences)
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_savedVouchersKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        savedVouchersNotifier.value =
            decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[VoucherService] Gagal muat baucar tersimpan: $e');
    }
  }

  /// Semak sama ada sesuatu baucar telah disimpan (berdasarkan ID atau Kod)
  static bool isVoucherSaved({String? id, String? code}) {
    if ((id == null || id.isEmpty) && (code == null || code.isEmpty)) {
      return false;
    }
    return savedVouchersNotifier.value.any((v) {
      final vId = v['id']?.toString();
      final vCode = v['code']?.toString().toUpperCase();
      if (id != null && id.isNotEmpty && vId == id) return true;
      if (code != null &&
          code.isNotEmpty &&
          vCode == code.trim().toUpperCase()) {
        return true;
      }
      return false;
    });
  }

  /// Simpan / Buang Baucar (Toggle Save)
  static Future<bool> toggleSaveVoucher(Map<String, dynamic> voucher) async {
    await init();
    final vId = voucher['id']?.toString() ?? '';
    final vCode = (voucher['code'] ?? '').toString().trim().toUpperCase();
    if (vId.isEmpty && vCode.isEmpty) return false;

    final current = List<Map<String, dynamic>>.from(savedVouchersNotifier.value);
    final existingIndex = current.indexWhere((v) {
      final curId = v['id']?.toString() ?? '';
      final curCode = (v['code'] ?? '').toString().trim().toUpperCase();
      if (vId.isNotEmpty && curId == vId) return true;
      if (vCode.isNotEmpty && curCode == vCode) return true;
      return false;
    });

    bool isNowSaved = false;
    if (existingIndex >= 0) {
      current.removeAt(existingIndex);
      isNowSaved = false;
    } else {
      final entry = Map<String, dynamic>.from(voucher);
      entry['saved_at'] = DateTime.now().toIso8601String();
      current.insert(0, entry);
      isNowSaved = true;
    }

    savedVouchersNotifier.value = current;
    await _persist();
    return isNowSaved;
  }

  /// Tambah baucar secara manual menggunakan kod (cari di Supabase dahulu jika ada)
  static Future<Map<String, dynamic>> saveVoucherByCode(String code) async {
    await init();
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      return {'success': false, 'message': 'Sila masukkan kod baucar.'};
    }

    if (isVoucherSaved(code: cleanCode)) {
      return {'success': false, 'message': 'Baucar ini sudah ada dalam simpanan anda.'};
    }

    // Cuba semak di pangkalan data Supabase
    try {
      final res = await Supabase.instance.client
          .from('vouchers')
          .select('*, businesses(name, business_logo_url)')
          .ilike('code', cleanCode)
          .eq('is_active', true)
          .maybeSingle();

      if (res != null) {
        final Map<String, dynamic> v = Map<String, dynamic>.from(res);
        final biz = v['businesses'] as Map<String, dynamic>?;
        final shopName = biz?['name']?.toString() ?? 'Kedai Rakan Niaga';
        final shopLogo = biz?['business_logo_url']?.toString();

        final entry = {
          'id': v['id']?.toString(),
          'code': v['code']?.toString() ?? cleanCode,
          'title': v['title']?.toString() ?? 'Baucar Diskaun $cleanCode',
          'shop_name': shopName,
          'shop_logo': shopLogo,
          'business_id': v['business_id']?.toString(),
          'discount_type': v['discount_type'] ?? 'fixed',
          'discount_value': v['discount_value'] ?? 0,
          'min_spend': v['min_spend'] ?? 0,
          'max_discount_amount': v['max_discount_amount'],
          'end_date': v['end_date'],
          'saved_at': DateTime.now().toIso8601String(),
        };

        await toggleSaveVoucher(entry);
        return {'success': true, 'voucher': entry, 'message': 'Baucar berjaya disimpan!'};
      }
    } catch (e) {
      debugPrint('[VoucherService] Semakan Supabase gagal: $e');
    }

    // Jika kod promosi tiada di table atau dibuat secara kempen/umum (cth: NGAMBARU, NGAM5, JOMNGAM)
    final fallbackEntry = {
      'id': 'local_$cleanCode',
      'code': cleanCode,
      'title': 'Baucar Promosi Komuniti',
      'shop_name': 'Baucar Rasmi Ngam',
      'discount_type': cleanCode.contains('50') || cleanCode.contains('PERCENT') ? 'percentage' : 'fixed',
      'discount_value': cleanCode.contains('50') ? 50 : 5,
      'min_spend': 10,
      'end_date': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'saved_at': DateTime.now().toIso8601String(),
    };

    await toggleSaveVoucher(fallbackEntry);
    return {'success': true, 'voucher': fallbackEntry, 'message': 'Baucar $cleanCode berjaya disimpan!'};
  }

  /// Padam baucar tersimpan mengikut ID atau Kod
  static Future<void> removeSavedVoucher(String idOrCode) async {
    await init();
    final current = List<Map<String, dynamic>>.from(savedVouchersNotifier.value);
    current.removeWhere((v) =>
        v['id']?.toString() == idOrCode ||
        (v['code'] ?? '').toString().toUpperCase() == idOrCode.toUpperCase());
    savedVouchersNotifier.value = current;
    await _persist();
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(savedVouchersNotifier.value);
      await prefs.setString(_savedVouchersKey, encoded);
    } catch (e) {
      debugPrint('[VoucherService] Gagal simpan ke SharedPreferences: $e');
    }
  }
}
