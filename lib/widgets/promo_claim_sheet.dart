import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/voucher_service.dart';
import '../utils/glass_toast.dart';

class PromoResolutionResult {
  final Map<String, dynamic> voucher;
  final Map<String, dynamic>? shop;
  final bool isSaved;

  const PromoResolutionResult({
    required this.voucher,
    this.shop,
    required this.isSaved,
  });
}

class PromoClaimResolver {
  PromoClaimResolver._();

  static Future<Map<String, dynamic>?> resolveBusiness(String? identifier) async {
    final raw = (identifier ?? '').replaceAll('@', '').trim();
    if (raw.isEmpty) return null;
    final clean = raw.toLowerCase();
    final client = Supabase.instance.client;

    try {
      Map<String, dynamic>? res = await client
          .from('businesses')
          .select()
          .eq('business_handle', clean)
          .maybeSingle();

      if (res == null) {
        final isUuid = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(raw);
        if (isUuid) {
          res = await client
              .from('businesses')
              .select()
              .eq('id', raw)
              .maybeSingle();
        }
      }

      res ??= await client
          .from('businesses')
          .select()
          .ilike('business_name', clean)
          .maybeSingle();

      if (res != null) return Map<String, dynamic>.from(res);
    } catch (_) {}
    return null;
  }

  static Future<PromoResolutionResult> resolvePromo({
    required String promoCode,
    String? businessIdentifier,
    Map<String, dynamic>? preloadedShop,
  }) async {
    await VoucherService.init();
    final cleanCode = promoCode.trim().toUpperCase();
    final shop = preloadedShop ?? await resolveBusiness(businessIdentifier);
    final shopId = shop?['id']?.toString();
    final shopName = (shop?['business_name'] ??
            shop?['name'] ??
            businessIdentifier?.replaceAll('@', '') ??
            'ereceipt.default_shop'.tr())
        .toString()
        .trim();
    final shopLogo =
        (shop?['business_logo_url'] ?? shop?['logo_url'])?.toString();

    Map<String, dynamic>? resolvedVoucher;
    final client = Supabase.instance.client;

    // 1. Check live Supabase vouchers table
    try {
      final rows = await client
          .from('vouchers')
          .select('*, businesses(id, business_name, business_logo_url, business_industry)')
          .ilike('code', cleanCode)
          .eq('is_active', true)
          .limit(5);

      if ((rows as List).isNotEmpty) {
        Map<String, dynamic>? chosen;
        if (shopId != null && shopId.isNotEmpty) {
          for (final r in rows) {
            if (r['business_id']?.toString() == shopId) {
              chosen = Map<String, dynamic>.from(r as Map);
              break;
            }
          }
        }
        chosen ??= Map<String, dynamic>.from(rows.first as Map);
        final biz = chosen['businesses'] is Map
            ? Map<String, dynamic>.from(chosen['businesses'] as Map)
            : shop;
        final rawScope =
            (chosen['applicable_scope'] ?? 'all').toString().toLowerCase();
        List<String> appCats = [];
        if (chosen['applicable_categories'] is List) {
          appCats = (chosen['applicable_categories'] as List)
              .map((e) => e.toString().toLowerCase())
              .toList();
        } else if (rawScope == 'category' && chosen['applicable_ids'] is List) {
          appCats = (chosen['applicable_ids'] as List)
              .map((e) => e.toString().toLowerCase())
              .toList();
        }

        resolvedVoucher = {
          'id': chosen['id']?.toString() ?? 'v_$cleanCode',
          'code': chosen['code']?.toString().toUpperCase() ?? cleanCode,
          'title': chosen['title']?.toString() ?? 'Baucar $cleanCode',
          'shop_name': (biz?['business_name'] ?? biz?['name'] ?? shopName).toString(),
          'shop_logo': biz?['business_logo_url']?.toString() ?? shopLogo,
          'business_id': chosen['business_id']?.toString() ?? shopId,
          'discount_type': chosen['discount_type'] ?? 'fixed',
          'discount_value': (chosen['discount_value'] as num?)?.toDouble() ?? 0.0,
          'min_spend': (chosen['min_spend'] as num?)?.toDouble() ?? 0.0,
          'max_discount_amount': (chosen['max_discount_amount'] as num?)?.toDouble(),
          'start_date': chosen['start_date'],
          'end_date': chosen['end_date'],
          'description':
              chosen['description']?.toString() ?? 'promo_claim.default_desc'.tr(),
          'is_platform': chosen['business_id'] == null,
          'applicable_scope': rawScope,
          'applicable_categories': appCats,
          'applicable_ids': chosen['applicable_ids'],
        };
      }
    } catch (_) {}

    // 2. Check curated platform promos
    if (resolvedVoucher == null) {
      final curated = VoucherService.curatedPromos.firstWhere(
        (p) => (p['code'] ?? '').toString().toUpperCase() == cleanCode,
        orElse: () => <String, dynamic>{},
      );
      if (curated.isNotEmpty) {
        resolvedVoucher = Map<String, dynamic>.from(curated);
      }
    }

    // 3. Fallback for receipt/standee promo codes (e.g. NGAM10) tied to the merchant
    if (resolvedVoucher == null) {
      String discType = 'percentage';
      double discValue = 10.0;

      final rmMatch = RegExp(r'RM\s*(\d+)', caseSensitive: false).firstMatch(cleanCode);
      final trailingDigits = RegExp(r'(\d+)$').firstMatch(cleanCode);
      if (rmMatch != null) {
        discType = 'fixed';
        discValue = double.tryParse(rmMatch.group(1) ?? '5') ?? 5.0;
      } else if (trailingDigits != null) {
        final numVal = int.tryParse(trailingDigits.group(1) ?? '10') ?? 10;
        if (numVal > 0 && numVal <= 80) {
          discType = 'percentage';
          discValue = numVal.toDouble();
        }
      }

      resolvedVoucher = {
        'id': 'receipt_promo_${cleanCode}_${shopId ?? 'shop'}',
        'code': cleanCode,
        'title': discType == 'percentage'
            ? 'promo_claim.store_promo_title'.tr(args: [discValue.toInt().toString(), shopName])
            : 'promo_claim.store_promo_title_rm'.tr(args: [discValue.toStringAsFixed(0), shopName]),
        'shop_name': shopName,
        'shop_logo': shopLogo,
        if (shopId != null && shopId.isNotEmpty) 'business_id': shopId,
        'discount_type': discType,
        'discount_value': discValue,
        'min_spend': 0.0,
        'description': 'promo_claim.default_desc'.tr(),
        'is_platform': shopId == null || shopId.isEmpty,
        'applicable_scope': 'all',
        'applicable_categories': <String>[],
      };
    }

    final isSaved = VoucherService.isVoucherSaved(
      id: resolvedVoucher['id']?.toString(),
      code: cleanCode,
    );

    return PromoResolutionResult(
      voucher: resolvedVoucher,
      shop: shop,
      isSaved: isSaved,
    );
  }
}

class PromoClaimSheet extends StatefulWidget {
  final String promoCode;
  final Map<String, dynamic>? shop;
  final VoidCallback? onClaimed;

  const PromoClaimSheet({
    super.key,
    required this.promoCode,
    this.shop,
    this.onClaimed,
  });

  static Future<void> show(
    BuildContext context, {
    required String promoCode,
    Map<String, dynamic>? shop,
    VoidCallback? onClaimed,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PromoClaimSheet(
        promoCode: promoCode,
        shop: shop,
        onClaimed: onClaimed,
      ),
    );
  }

  @override
  State<PromoClaimSheet> createState() => _PromoClaimSheetState();
}

class _PromoClaimSheetState extends State<PromoClaimSheet> {
  PromoResolutionResult? _result;
  bool _isLoading = true;
  bool _isClaiming = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _loadPromo();
  }

  Future<void> _loadPromo() async {
    final res = await PromoClaimResolver.resolvePromo(
      promoCode: widget.promoCode,
      businessIdentifier: widget.shop?['id']?.toString(),
      preloadedShop: widget.shop,
    );
    if (!mounted) return;
    setState(() {
      _result = res;
      _isSaved = res.isSaved;
      _isLoading = false;
    });
  }

  Future<void> _claim() async {
    final v = _result?.voucher;
    if (v == null || _isClaiming) return;
    final code = (v['code'] ?? widget.promoCode).toString().toUpperCase();

    if (_isSaved) {
      Clipboard.setData(ClipboardData(text: code));
      showGlassToast(context, 'promo_claim.already_claimed_toast'.tr(args: [code]));
      Navigator.pop(context);
      return;
    }

    setState(() => _isClaiming = true);
    await VoucherService.saveVoucher(v);
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() {
      _isClaiming = false;
      _isSaved = true;
    });
    widget.onClaimed?.call();
    showGlassToast(context, 'promo_claim.claim_success_toast'.tr(args: [code]));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF131926) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);

    final v = _result?.voucher;
    final code = (v?['code'] ?? widget.promoCode).toString().toUpperCase();
    final shopName = (v?['shop_name'] ??
            widget.shop?['business_name'] ??
            widget.shop?['name'] ??
            'ereceipt.default_shop'.tr())
        .toString();
    final discType = (v?['discount_type'] ?? 'percentage').toString();
    final discVal = (v?['discount_value'] as num?)?.toDouble() ?? 10.0;
    final minSpend = (v?['min_spend'] as num?)?.toDouble() ?? 0.0;

    final discHeadline = discType == 'percentage'
        ? 'promo_claim.discount_off_pct'.tr(args: [discVal.toInt().toString()])
        : 'promo_claim.discount_off_rm'.tr(args: [discVal.toStringAsFixed(0)]);

    return Container(
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        MediaQuery.of(context).viewPadding.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: border),
      ),
      child: _isLoading
          ? SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text('promo_claim.loading_text'.tr(), style: TextStyle(color: textSecondary)),
                  ],
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedDiscount01,
                        color: Color(0xFFF59E0B),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'promo_claim.popup_title'.tr(),
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  discHeadline,
                  style: GoogleFonts.outfit(
                    color: textPrimary,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  shopName,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    showGlassToast(context, 'promo_claim.copy_code_toast'.tr(args: [code]));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${'promo_claim.code_label'.tr()}: ',
                          style: TextStyle(color: textSecondary, fontSize: 12.5),
                        ),
                        Text(
                          code,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF3B82F6),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedCopy01,
                          color: Color(0xFF3B82F6),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  minSpend > 0
                      ? 'promo_claim.min_spend_badge'.tr(args: [minSpend.toStringAsFixed(0)])
                      : 'promo_claim.no_min_spend'.tr(),
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isClaiming ? null : _claim,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSaved
                          ? const Color(0xFF10B981)
                          : const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: HugeIcon(
                      icon: _isSaved
                          ? HugeIcons.strokeRoundedCheckmarkCircle02
                          : HugeIcons.strokeRoundedTicket02,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: Text(
                      _isSaved
                          ? 'promo_claim.claimed_btn'.tr()
                          : 'promo_claim.claim_btn'.tr(),
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
