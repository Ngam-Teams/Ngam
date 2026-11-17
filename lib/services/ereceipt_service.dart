import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EreceiptService {
  static const String _receiptsKey = 'ngam_saved_ereceipts_v1';
  static const String _pointsKey = 'ngam_points_balance_v1';

  static final ValueNotifier<List<Map<String, dynamic>>> savedReceiptsNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);
  static final ValueNotifier<int> totalPointsNotifier = ValueNotifier<int>(0);

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_receiptsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          savedReceiptsNotifier.value =
              decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }

      int pts = prefs.getInt(_pointsKey) ?? 0;
      if (pts == 0 && savedReceiptsNotifier.value.isNotEmpty) {
        for (final r in savedReceiptsNotifier.value) {
          if (r['points_claimed'] == true) {
            pts += (r['points_earned'] as num?)?.toInt() ?? 0;
          }
        }
      }
      totalPointsNotifier.value = pts;
      _initialized = true;
    } catch (e) {
      debugPrint('[EreceiptService] Init error: $e');
    }
  }

  static int computePoints(double totalAmount) {
    if (totalAmount <= 0) return 1;
    return math.max(1, totalAmount.floor());
  }

  static String buildClaimKey(Map<String, dynamic> receipt) {
    final orderId = (receipt['order_id'] ?? '').toString().trim().toLowerCase();
    if (orderId.isNotEmpty) return 'order:$orderId';
    final ref = (receipt['ref'] ?? '').toString().trim().toUpperCase();
    final store = (receipt['store_handle'] ?? receipt['business_id'] ?? receipt['shop_name'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final total = ((receipt['total'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
    return 'pos:$store|$ref|$total';
  }

  static bool isReceiptSavedOrClaimed(Map<String, dynamic> receipt) {
    final key = buildClaimKey(receipt);
    return savedReceiptsNotifier.value.any((item) {
      final itemKey = (item['claim_key']?.toString().isNotEmpty == true)
          ? item['claim_key'].toString()
          : buildClaimKey(item);
      return itemKey == key;
    });
  }

  static Map<String, dynamic>? findSavedReceipt(Map<String, dynamic> receipt) {
    final key = buildClaimKey(receipt);
    for (final item in savedReceiptsNotifier.value) {
      final itemKey = (item['claim_key']?.toString().isNotEmpty == true)
          ? item['claim_key'].toString()
          : buildClaimKey(item);
      if (itemKey == key) return Map<String, dynamic>.from(item);
    }
    return null;
  }

  static List<Map<String, dynamic>> parseItemsParam(String? rawItems) {
    if (rawItems == null || rawItems.trim().isEmpty) return [];
    final List<Map<String, dynamic>> parsed = [];
    final chunks = rawItems.split(';;');
    for (final chunk in chunks) {
      final cleanChunk = chunk.trim();
      if (cleanChunk.isEmpty) continue;
      final parts = cleanChunk.split('|');
      String label = parts.first.trim();
      double price = 0.0;
      if (parts.length > 1) {
        final rawNum = parts.last.replaceAll(RegExp(r'[^0-9.]'), '');
        price = double.tryParse(rawNum) ?? 0.0;
      }

      int qty = 1;
      final qtyMatch = RegExp(r'^(\d+)\s*[xX]\s+(.+)$').firstMatch(label);
      if (qtyMatch != null) {
        qty = int.tryParse(qtyMatch.group(1) ?? '1') ?? 1;
        label = qtyMatch.group(2)?.trim() ?? label;
      }
      if (qty <= 0) qty = 1;

      parsed.add({
        'name': label,
        'qty': qty,
        'unit_price': price / qty,
        'price': price,
      });
    }
    return parsed;
  }

  static Map<String, dynamic> buildReceiptFromUri(Uri uri) {
    final qp = uri.queryParameters;
    final orderId = (qp['order_id'] ?? qp['id'] ?? '').trim();
    final ref = (qp['ref'] ??
            (orderId.isNotEmpty
                ? (orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase())
                : 'NG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}'))
        .trim();

    final store = (qp['store'] ?? qp['handle'] ?? '').replaceAll('@', '').trim();
    final bizId = (qp['bid'] ?? qp['business_id'] ?? '').trim();
    final shopName = (qp['name'] ?? qp['shop'] ?? (store.isNotEmpty ? store : 'Peniaga Ngam')).trim();

    double parseMoney(String? v) {
      if (v == null || v.trim().isEmpty) return 0.0;
      return double.tryParse(v.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0.0;
    }

    final total = parseMoney(qp['total']);
    final subtotal = parseMoney(qp['subtotal']);
    final tax = parseMoney(qp['tax']);
    final svc = parseMoney(qp['svc'] ?? qp['service_charge']);
    final round = parseMoney(qp['round'] ?? qp['rounding']);
    final discount = parseMoney(qp['discount']);
    final method = (qp['method'] ?? 'DuitNow QR').trim();
    final dateStr = (qp['date'] ?? DateTime.now().toIso8601String()).trim();
    final items = parseItemsParam(qp['items']);

    final resolvedTotal = total > 0
        ? total
        : items.fold<double>(0.0, (sum, it) => sum + ((it['price'] as num?)?.toDouble() ?? 0.0));
    final resolvedSubtotal = subtotal > 0 ? subtotal : resolvedTotal;

    final map = <String, dynamic>{
      if (orderId.isNotEmpty) 'order_id': orderId,
      'ref': ref,
      if (store.isNotEmpty) 'store_handle': store,
      if (bizId.isNotEmpty) 'business_id': bizId,
      'shop_name': shopName,
      'total': resolvedTotal,
      'subtotal': resolvedSubtotal,
      'tax': tax,
      'service_charge': svc,
      'rounding': round,
      'discount': discount,
      'payment_method': method,
      'payment_status': 'paid',
      'date': dateStr,
      'items': items,
      'source': orderId.isNotEmpty ? 'online' : 'scanned',
      if ((qp['table'] ?? '').trim().isNotEmpty) 'table_number': qp['table']!.trim(),
    };
    map['claim_key'] = buildClaimKey(map);
    return map;
  }

  static Future<Map<String, dynamic>> saveAndClaimReceipt(
    Map<String, dynamic> rawReceipt,
  ) async {
    await init();
    final receipt = Map<String, dynamic>.from(rawReceipt);
    final claimKey = buildClaimKey(receipt);
    receipt['claim_key'] = claimKey;

    final existing = findSavedReceipt(receipt);
    if (existing != null && existing['points_claimed'] == true) {
      return {
        'alreadyClaimed': true,
        'pointsEarned': (existing['points_earned'] as num?)?.toInt() ?? 0,
        'totalPoints': totalPointsNotifier.value,
        'receipt': existing,
      };
    }

    final total = (receipt['total'] as num?)?.toDouble() ?? 0.0;
    final pts = computePoints(total);
    receipt['points_claimed'] = true;
    receipt['points_earned'] = pts;
    receipt['claimed_at'] = DateTime.now().toIso8601String();
    receipt['saved_at'] = receipt['saved_at'] ?? DateTime.now().toIso8601String();

    final current = List<Map<String, dynamic>>.from(savedReceiptsNotifier.value);
    current.removeWhere((item) {
      final k = (item['claim_key']?.toString().isNotEmpty == true)
          ? item['claim_key'].toString()
          : buildClaimKey(item);
      return k == claimKey;
    });
    current.insert(0, receipt);

    savedReceiptsNotifier.value = current;
    totalPointsNotifier.value = totalPointsNotifier.value + pts;
    await _persist();

    return {
      'alreadyClaimed': false,
      'pointsEarned': pts,
      'totalPoints': totalPointsNotifier.value,
      'receipt': receipt,
    };
  }

  static Future<List<Map<String, dynamic>>> fetchMergedReceipts() async {
    await init();
    final Map<String, Map<String, dynamic>> byKey = {};

    for (final saved in savedReceiptsNotifier.value) {
      final copy = Map<String, dynamic>.from(saved);
      final key = (copy['claim_key']?.toString().isNotEmpty == true)
          ? copy['claim_key'].toString()
          : buildClaimKey(copy);
      copy['claim_key'] = key;
      byKey[key] = copy;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final rows = await Supabase.instance.client
            .from('orders')
            .select(
              'id, business_id, total, subtotal, status, payment_status, payment_method, created_at, paid_at, notes, businesses(id, business_name, business_handle, business_logo_url, business_phone, address_line)',
            )
            .eq('customer_id', user.id)
            .order('created_at', ascending: false)
            .limit(40);

        final List<String> orderIds = [];
        for (final row in (rows as List)) {
          final id = row['id']?.toString() ?? '';
          if (id.isNotEmpty) orderIds.add(id);
        }

        final Map<String, List<Map<String, dynamic>>> itemsByOrder = {};
        if (orderIds.isNotEmpty) {
          try {
            final itemRows = await Supabase.instance.client
                .from('order_items')
                .select('order_id, product_name, quantity, unit_price, subtotal')
                .inFilter('order_id', orderIds);
            for (final ir in (itemRows as List)) {
              final oid = ir['order_id']?.toString() ?? '';
              if (oid.isEmpty) continue;
              itemsByOrder.putIfAbsent(oid, () => []).add({
                'name': ir['product_name']?.toString() ?? 'Item',
                'qty': (ir['quantity'] as num?)?.toInt() ?? 1,
                'unit_price': (ir['unit_price'] as num?)?.toDouble() ?? 0.0,
                'price': (ir['subtotal'] as num?)?.toDouble() ?? 0.0,
              });
            }
          } catch (_) {}
        }

        for (final raw in rows) {
          final r = Map<String, dynamic>.from(raw as Map);
          final status = (r['status'] ?? '').toString().toLowerCase();
          final payStatus = (r['payment_status'] ?? '').toString().toLowerCase();
          if (status == 'cancelled' || status == 'failed') continue;
          if (payStatus != 'paid' && status != 'completed') continue;

          final oid = r['id']?.toString() ?? '';
          final biz = r['businesses'] is Map
              ? Map<String, dynamic>.from(r['businesses'] as Map)
              : <String, dynamic>{};
          final total = (r['total'] as num?)?.toDouble() ?? 0.0;
          final subtotal = (r['subtotal'] as num?)?.toDouble() ?? total;
          final shortRef = oid.length > 8 ? oid.substring(0, 8).toUpperCase() : oid.toUpperCase();

          final mapped = <String, dynamic>{
            'order_id': oid,
            'ref': shortRef,
            'business_id': r['business_id']?.toString() ?? biz['id']?.toString() ?? '',
            'store_handle': (biz['business_handle'] ?? '').toString().replaceAll('@', ''),
            'shop_name': (biz['business_name'] ?? 'Peniaga Ngam').toString(),
            'shop_logo': biz['business_logo_url']?.toString(),
            'shop_phone': biz['business_phone']?.toString(),
            'shop_address': biz['address_line']?.toString(),
            'total': total,
            'subtotal': subtotal,
            'tax': 0.0,
            'service_charge': 0.0,
            'rounding': 0.0,
            'discount': 0.0,
            'payment_method': (r['payment_method'] ?? 'Online').toString(),
            'payment_status': payStatus.isNotEmpty ? payStatus : 'paid',
            'date': (r['paid_at'] ?? r['created_at'] ?? DateTime.now().toIso8601String()).toString(),
            'notes': r['notes']?.toString(),
            'items': itemsByOrder[oid] ?? <Map<String, dynamic>>[],
            'source': 'online',
          };
          final key = buildClaimKey(mapped);
          mapped['claim_key'] = key;

          if (byKey.containsKey(key)) {
            final existing = byKey[key]!;
            mapped['points_claimed'] = existing['points_claimed'] == true;
            mapped['points_earned'] = existing['points_earned'] ?? computePoints(total);
            mapped['claimed_at'] = existing['claimed_at'];
          } else {
            mapped['points_claimed'] = false;
            mapped['points_earned'] = computePoints(total);
          }
          byKey[key] = mapped;
        }
      } catch (e) {
        debugPrint('[EreceiptService] Fetch Supabase orders error: $e');
      }
    }

    final list = byKey.values.toList();
    list.sort((a, b) {
      final da = DateTime.tryParse((a['claimed_at'] ?? a['date'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final db = DateTime.tryParse((b['claimed_at'] ?? b['date'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return list;
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_receiptsKey, jsonEncode(savedReceiptsNotifier.value));
      await prefs.setInt(_pointsKey, totalPointsNotifier.value);
    } catch (e) {
      debugPrint('[EreceiptService] Persist error: $e');
    }
  }
}
