import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VoucherService {
  static const String _savedVouchersKey = 'ngam_saved_vouchers';
  static const String _seededDefaultKey = 'ngam_vouchers_seeded_v1';

  static final ValueNotifier<List<Map<String, dynamic>>> savedVouchersNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  static bool _initialized = false;

  /// Default curated community & platform promo vouchers
  static final List<Map<String, dynamic>> curatedPromos = [
    {
      'id': 'promo_ngam_welcome',
      'code': 'NGAMBARU',
      'title': 'Diskaun Pengguna Baru RM5',
      'shop_name': 'Semua Rakan Niaga Ngam',
      'shop_logo': null,
      'discount_type': 'fixed',
      'discount_value': 5.0,
      'min_spend': 15.0,
      'end_date': DateTime.now().add(const Duration(days: 90)).toIso8601String(),
      'description': 'Diskaun RM5 untuk sebarang tempahan atau pesanan di aplikasi Ngam.',
      'badge': 'Paling Hangat',
      'is_platform': true,
    },
    {
      'id': 'promo_barber_cut',
      'code': 'STYLE10',
      'title': 'Potongan 10% Servis Gunting & Grooming',
      'shop_name': 'Semua Rakan Barber & Salon',
      'shop_logo': null,
      'discount_type': 'percentage',
      'discount_value': 10.0,
      'min_spend': 20.0,
      'max_discount_amount': 5.0,
      'end_date': DateTime.now().add(const Duration(days: 60)).toIso8601String(),
      'description': 'Potongan 10% untuk pakej servis dandanan dan gunting rambut.',
      'badge': 'Servis Barber',
      'is_platform': true,
    },
    {
      'id': 'promo_coffee_fever',
      'code': 'KOPINGAM',
      'title': 'Jimat RM3 Segelas Kopi & Pastri',
      'shop_name': 'Semua Kafe & F&B',
      'shop_logo': null,
      'discount_type': 'fixed',
      'discount_value': 3.0,
      'min_spend': 10.0,
      'end_date': DateTime.now().add(const Duration(days: 45)).toIso8601String(),
      'description': 'Nikmati jimat RM3 bila pesan minuman artisan atau makanan.',
      'badge': 'Kafe & Minuman',
      'is_platform': true,
    },
    {
      'id': 'promo_carwash_shine',
      'code': 'KILAT5',
      'title': 'Rebat RM5 Cuci Salji & Wax Kenderaan',
      'shop_name': 'Semua Carwash & Auto Detailing',
      'shop_logo': null,
      'discount_type': 'fixed',
      'discount_value': 5.0,
      'min_spend': 20.0,
      'end_date': DateTime.now().add(const Duration(days: 60)).toIso8601String(),
      'description': 'Rebat segera RM5 untuk carwash pakej Snow Wash & Wax.',
      'badge': 'Cuci Kenderaan',
      'is_platform': true,
    },
  ];

  /// Inisialisasi senarai baucar tersimpan dari peranti tempatan (SharedPreferences)
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_savedVouchersKey);
      final seeded = prefs.getBool(_seededDefaultKey) ?? false;

      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        final loaded =
            decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        // Bersihkan sebarang baucar mock 'local_' yang pernah disimpan sebelum ini
        final int beforeCount = loaded.length;
        loaded.removeWhere((v) {
          final id = v['id']?.toString() ?? '';
          return id.startsWith('local_');
        });
        savedVouchersNotifier.value = loaded;
        if (loaded.length != beforeCount) {
          await _persist();
        }
      }

      // Auto-seed welcome voucher if user doesn't have it yet
      if (!seeded && !isVoucherSaved(code: 'NGAMBARU')) {
        final welcome = Map<String, dynamic>.from(curatedPromos.first);
        welcome['saved_at'] = DateTime.now().toIso8601String();
        final current = List<Map<String, dynamic>>.from(savedVouchersNotifier.value);
        current.insert(0, welcome);
        savedVouchersNotifier.value = current;
        await _persist();
        await prefs.setBool(_seededDefaultKey, true);
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

  /// Simpan baucar secara terus jika belum tersimpan
  static Future<bool> saveVoucher(Map<String, dynamic> voucher) async {
    final code = (voucher['code'] ?? '').toString().toUpperCase();
    final id = voucher['id']?.toString();
    if (isVoucherSaved(id: id, code: code)) return true;
    return await toggleSaveVoucher(voucher);
  }

  /// Kira jumlah diskaun berdasarkan jenis (peratusan atau nilai tetap)
  static double computeDiscount(Map<String, dynamic> voucher, double subtotal) {
    if (subtotal <= 0) return 0.0;
    final type = (voucher['discount_type'] ?? 'fixed').toString().toLowerCase();
    final value = (voucher['discount_value'] as num?)?.toDouble() ?? 0.0;
    double d = 0.0;

    if (type == 'percentage') {
      d = subtotal * value / 100.0;
      final cap = (voucher['max_discount_amount'] as num?)?.toDouble();
      if (cap != null && cap > 0 && d > cap) {
        d = cap;
      }
    } else {
      d = value;
    }

    if (d > subtotal) d = subtotal;
    return double.parse(d.toStringAsFixed(2));
  }

  /// Semak kelayakan baucar untuk subtotal dan kedai semasa
  static Map<String, dynamic> checkVoucherEligibility(
    Map<String, dynamic> voucher, {
    String? businessId,
    required double subtotal,
    String? category,
  }) {
    final vBizId = voucher['business_id']?.toString();
    final bool isPlatform = voucher['is_platform'] == true || vBizId == null || vBizId.isEmpty;

    // 1. Semakan kedai
    if (!isPlatform && businessId != null && businessId.isNotEmpty && vBizId != businessId) {
      return {
        'isEligible': false,
        'discountAmount': 0.0,
        'shortfall': 0.0,
        'reason': 'Hanya untuk kedai ${voucher['shop_name'] ?? 'terpilih'}',
      };
    }

    // 2. Semakan tarikh luput
    final endDateStr = voucher['end_date']?.toString();
    if (endDateStr != null && endDateStr.isNotEmpty) {
      final end = DateTime.tryParse(endDateStr);
      if (end != null && end.toUtc().isBefore(DateTime.now().toUtc())) {
        return {
          'isEligible': false,
          'discountAmount': 0.0,
          'shortfall': 0.0,
          'reason': 'Baucar telah tamat tempoh',
        };
      }
    }

    // 3. Semakan belanja minimum
    final minSpend = (voucher['min_spend'] as num?)?.toDouble() ?? 0.0;
    if (subtotal < minSpend) {
      final shortfall = minSpend - subtotal;
      return {
        'isEligible': false,
        'discountAmount': 0.0,
        'shortfall': shortfall,
        'reason': 'Tambah lagi RM ${shortfall.toStringAsFixed(2)} untuk guna (Min RM ${minSpend.toStringAsFixed(0)})',
      };
    }

    final discount = computeDiscount(voucher, subtotal);
    if (discount <= 0) {
      return {
        'isEligible': false,
        'discountAmount': 0.0,
        'shortfall': 0.0,
        'reason': 'Tiada diskaun terpakai untuk pesanan ini',
      };
    }

    return {
      'isEligible': true,
      'discountAmount': discount,
      'shortfall': 0.0,
      'reason': 'Layak Digunakan',
    };
  }

  /// Dapatkan semua baucar yang tersedia untuk pembayaran (termasuk saved, curated, & live db)
  static Future<List<Map<String, dynamic>>> getAvailableVouchersForCheckout({
    String? businessId,
    required double subtotal,
    String? category,
  }) async {
    await init();
    final List<Map<String, dynamic>> combined = [];
    final Set<String> seenCodes = {};

    // 1. Baucar Live dari Supabase (termasuk baucar kedai & baucar platform)
    try {
      var query = Supabase.instance.client
          .from('vouchers')
          .select('*, businesses(name, business_logo_url)')
          .eq('is_active', true);

      if (businessId != null && businessId.isNotEmpty) {
        query = query.or('business_id.eq.$businessId,business_id.is.null');
      }

      final res = await query.limit(25);
      for (var r in res) {
        final m = Map<String, dynamic>.from(r);
        final code = (m['code'] ?? '').toString().trim().toUpperCase();
        if (code.isEmpty || seenCodes.contains(code)) continue;
        seenCodes.add(code);
        final biz = m['businesses'] as Map<String, dynamic>?;
        combined.add({
          'id': m['id']?.toString() ?? 'v_$code',
          'code': code,
          'title': m['title']?.toString() ?? 'Baucar Diskaun $code',
          'shop_name': biz?['name']?.toString() ?? (m['business_id'] == null ? 'Semua Rakan Niaga Ngam' : 'Kedai Rakan Niaga'),
          'shop_logo': biz?['business_logo_url']?.toString(),
          'business_id': m['business_id']?.toString(),
          'discount_type': m['discount_type'] ?? 'fixed',
          'discount_value': (m['discount_value'] as num?)?.toDouble() ?? 0.0,
          'min_spend': (m['min_spend'] as num?)?.toDouble() ?? 0.0,
          'max_discount_amount': (m['max_discount_amount'] as num?)?.toDouble(),
          'end_date': m['end_date'],
          'description': m['description']?.toString() ?? 'Diskaun untuk pesanan anda di Ngam.',
          'badge': m['business_id'] == null ? 'Rasmi Ngam' : 'Kedai Ini',
          'is_platform': m['business_id'] == null,
        });
      }
    } catch (e) {
      debugPrint('[VoucherService] Gagal tarik baucar Supabase: $e');
    }

    // 2. Baucar tersimpan pengguna
    for (var v in savedVouchersNotifier.value) {
      final code = (v['code'] ?? '').toString().trim().toUpperCase();
      if (code.isEmpty || seenCodes.contains(code)) continue;
      seenCodes.add(code);
      combined.add(Map<String, dynamic>.from(v));
    }

    // 3. Baucar curated promosi komuniti
    for (var p in curatedPromos) {
      final code = (p['code'] ?? '').toString().trim().toUpperCase();
      if (code.isEmpty || seenCodes.contains(code)) continue;
      seenCodes.add(code);
      combined.add(Map<String, dynamic>.from(p));
    }

    // 4. Semak status kelayakan setiap baucar untuk subtotal semasa
    final List<Map<String, dynamic>> enriched = [];
    for (var v in combined) {
      final status = checkVoucherEligibility(
        v,
        businessId: businessId,
        subtotal: subtotal,
        category: category,
      );
      final entry = Map<String, dynamic>.from(v);
      entry['is_eligible'] = status['isEligible'];
      entry['calculated_discount'] = status['discountAmount'];
      entry['eligibility_reason'] = status['reason'];
      entry['shortfall'] = status['shortfall'] ?? 0.0;
      enriched.add(entry);
    }

    // 5. Susun: Yang layak di atas (diskaun tertinggi dahulu), diikuti belum layak
    enriched.sort((a, b) {
      final bool aElig = a['is_eligible'] == true;
      final bool bElig = b['is_eligible'] == true;
      if (aElig && !bElig) return -1;
      if (!aElig && bElig) return 1;
      if (aElig && bElig) {
        final double aDisc = (a['calculated_discount'] as num?)?.toDouble() ?? 0.0;
        final double bDisc = (b['calculated_discount'] as num?)?.toDouble() ?? 0.0;
        return bDisc.compareTo(aDisc);
      }
      final double aShortfall = (a['shortfall'] as num?)?.toDouble() ?? 0.0;
      final double bShortfall = (b['shortfall'] as num?)?.toDouble() ?? 0.0;
      return aShortfall.compareTo(bShortfall);
    });

    return enriched;
  }

  /// Cari baucar terbaik yang layak secara automatik (Auto-Apply)
  static Future<Map<String, dynamic>?> getBestAutoVoucher({
    String? businessId,
    required double subtotal,
    String? category,
  }) async {
    final list = await getAvailableVouchersForCheckout(
      businessId: businessId,
      subtotal: subtotal,
      category: category,
    );
    final eligible = list
        .where((v) =>
            v['is_eligible'] == true &&
            ((v['calculated_discount'] as num?)?.toDouble() ?? 0) > 0)
        .toList();
    if (eligible.isEmpty) return null;
    return eligible.first; // Yang pertama sentiasa diskaun paling tinggi
  }

  /// Sahkan kod baucar secara langsung (jika ditaip secara manual semasa checkout)
  static Future<Map<String, dynamic>> validateAndApplyCode({
    required String code,
    String? businessId,
    required double subtotal,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      return {'success': false, 'message': 'Sila masukkan kod baucar.'};
    }

    final list = await getAvailableVouchersForCheckout(
      businessId: businessId,
      subtotal: subtotal,
    );

    final match = list.firstWhere(
      (v) => (v['code'] ?? '').toString().toUpperCase() == cleanCode,
      orElse: () => <String, dynamic>{},
    );

    if (match.isEmpty) {
      // Cuba semak & simpan dari kod fallback/supabase
      final saveRes = await saveVoucherByCode(cleanCode);
      if (saveRes['success'] == true && saveRes['voucher'] != null) {
        final v = Map<String, dynamic>.from(saveRes['voucher'] as Map);
        final status = checkVoucherEligibility(v, businessId: businessId, subtotal: subtotal);
        if (status['isEligible'] == true) {
          v['is_eligible'] = true;
          v['calculated_discount'] = status['discountAmount'];
          return {'success': true, 'voucher': v, 'message': 'Baucar $cleanCode berjaya digunakan!'};
        } else {
          return {'success': false, 'message': status['reason'] ?? 'Baucar ini tidak layak untuk pesanan ini.'};
        }
      }
      return {'success': false, 'message': saveRes['message'] ?? 'Kod baucar "$cleanCode" tidak sah atau tidak dijumpai.'};
    }

    if (match['is_eligible'] != true) {
      return {
        'success': false,
        'message': match['eligibility_reason'] ?? 'Baucar ini tidak layak digunakan.',
      };
    }

    return {
      'success': true,
      'voucher': match,
      'message': 'Baucar $cleanCode berjaya digunakan!',
    };
  }

  /// Tambah baucar secara manual menggunakan kod
  static Future<Map<String, dynamic>> saveVoucherByCode(String code) async {
    await init();
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      return {'success': false, 'message': 'Sila masukkan kod baucar.'};
    }

    if (isVoucherSaved(code: cleanCode)) {
      return {'success': false, 'message': 'Baucar ini sudah ada dalam simpanan anda.'};
    }

    // Semak di senarai curated
    final curatedMatch = curatedPromos.firstWhere(
      (p) => (p['code'] ?? '').toString().toUpperCase() == cleanCode,
      orElse: () => <String, dynamic>{},
    );
    if (curatedMatch.isNotEmpty) {
      final entry = Map<String, dynamic>.from(curatedMatch);
      await toggleSaveVoucher(entry);
      return {'success': true, 'voucher': entry, 'message': 'Baucar $cleanCode berjaya disimpan!'};
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
          'discount_value': (v['discount_value'] as num?)?.toDouble() ?? 0.0,
          'min_spend': (v['min_spend'] as num?)?.toDouble() ?? 0.0,
          'max_discount_amount': (v['max_discount_amount'] as num?)?.toDouble(),
          'end_date': v['end_date'],
          'saved_at': DateTime.now().toIso8601String(),
        };

        await saveVoucher(entry);
        return {'success': true, 'voucher': entry, 'message': 'Baucar berjaya disimpan!'};
      }
    } catch (e) {
      debugPrint('[VoucherService] Semakan Supabase gagal: $e');
    }

    // Jika tiada dalam senarai curated atau Supabase, kod adalah tidak sah
    return {
      'success': false,
      'message': 'Kod baucar "$cleanCode" tidak sah atau tidak wujud.',
    };
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
