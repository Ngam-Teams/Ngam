import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../services/voucher_service.dart';
import '../../utils/glass_toast.dart';
import '../../widgets/glass_nav_button.dart';
import '../../widgets/promo_claim_sheet.dart';
import '../explore/business_store_view.dart';
import '../explore/store_route_loader.dart';
import 'voucher_screen.dart';

class PromoClaimScreen extends StatefulWidget {
  final String promoCode;
  final String? businessIdentifier;
  final String? tableNumber;

  const PromoClaimScreen({
    super.key,
    required this.promoCode,
    this.businessIdentifier,
    this.tableNumber,
  });

  @override
  State<PromoClaimScreen> createState() => _PromoClaimScreenState();
}

class _PromoClaimScreenState extends State<PromoClaimScreen> {
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
    final code = widget.promoCode.trim();
    if (code.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final res = await PromoClaimResolver.resolvePromo(
      promoCode: code,
      businessIdentifier: widget.businessIdentifier,
    );
    if (!mounted) return;
    setState(() {
      _result = res;
      _isSaved = res.isSaved;
      _isLoading = false;
    });
  }

  Future<void> _claimVoucher({bool silentIfAlreadySaved = false}) async {
    final v = _result?.voucher;
    if (v == null || _isClaiming) return;
    final code = (v['code'] ?? widget.promoCode).toString().toUpperCase();

    if (_isSaved) {
      if (!silentIfAlreadySaved) {
        Clipboard.setData(ClipboardData(text: code));
        showGlassToast(
          context,
          'promo_claim.already_claimed_toast'.tr(args: [code]),
        );
      }
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
    showGlassToast(
      context,
      'promo_claim.claim_success_toast'.tr(args: [code]),
    );
  }

  Future<void> _shopNow() async {
    await _claimVoucher(silentIfAlreadySaved: true);
    if (!mounted) return;

    final v = _result?.voucher;
    final code = (v?['code'] ?? widget.promoCode).toString().toUpperCase();
    final shop = _result?.shop;
    final bizId = shop?['id']?.toString() ??
        v?['business_id']?.toString() ??
        widget.businessIdentifier?.trim() ??
        '';

    if (shop != null && shop['id'] != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BusinessStoreView(
            shop: {
              ...shop,
              'name': shop['business_name'] ?? shop['name'] ?? 'Peniaga Ngam',
            },
            tableNumber: widget.tableNumber,
            promoCode: code,
            autoShowPromoPopup: false,
          ),
        ),
      );
      return;
    }

    if (bizId.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StoreRouteLoader(
            businessId: bizId,
            tableNumber: widget.tableNumber,
            promoCode: code,
            autoShowPromoPopup: false,
          ),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const VoucherScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A14) : const Color(0xFFF4F7FC);
    final cardColor = isDark ? const Color(0xFF131926) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : Colors.black.withValues(alpha: 0.07);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);

    final v = _result?.voucher;
    final code = (v?['code'] ?? widget.promoCode).toString().toUpperCase();
    final shopName = (v?['shop_name'] ?? 'ereceipt.default_shop'.tr()).toString();
    final shopLogo = v?['shop_logo']?.toString();
    final title = (v?['title'] ?? '').toString();
    final desc = (v?['description'] ?? 'promo_claim.default_desc'.tr()).toString();
    final discType = (v?['discount_type'] ?? 'percentage').toString();
    final discVal = (v?['discount_value'] as num?)?.toDouble() ?? 10.0;
    final minSpend = (v?['min_spend'] as num?)?.toDouble() ?? 0.0;
    final endDateStr = v?['end_date']?.toString();
    final isPlatform = v?['is_platform'] == true ||
        (v?['business_id']?.toString().isEmpty ?? true);

    final discHeadline = discType == 'percentage'
        ? 'promo_claim.discount_off_pct'.tr(args: [discVal.toInt().toString()])
        : 'promo_claim.discount_off_rm'.tr(args: [discVal.toStringAsFixed(0)]);

    String validLabel = 'promo_claim.valid_forever'.tr();
    if (endDateStr != null && endDateStr.isNotEmpty) {
      final dt = DateTime.tryParse(endDateStr);
      if (dt != null) {
        validLabel = 'promo_claim.valid_until'.tr(
          args: [DateFormat('dd MMM yyyy').format(dt.toLocal())],
        );
      }
    }

    final hasStoreTarget = (_result?.shop != null) ||
        (v?['business_id']?.toString().trim().isNotEmpty == true) ||
        (widget.businessIdentifier?.trim().isNotEmpty == true);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      'promo_claim.loading_text'.tr(),
                      style: TextStyle(color: textSecondary),
                    ),
                  ],
                ),
              )
            : v == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedTicket01,
                            color: Colors.amber,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'promo_claim.not_found_title'.tr(),
                            style: GoogleFonts.outfit(
                              color: textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'promo_claim.not_found_subtitle'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textSecondary, fontSize: 13.5),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => Navigator.pushReplacementNamed(
                              context,
                              '/customer-home',
                            ),
                            child: Text('promo_claim.back_home_btn'.tr()),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          children: [
                            GlassNavButton.back(context: context, isDark: isDark),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'promo_claim.page_title'.tr(),
                                style: GoogleFonts.outfit(
                                  color: textPrimary,
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            GlassNavButton(
                              icon: HugeIcons.strokeRoundedDiscount01,
                              tooltip: 'promo_claim.view_my_vouchers_btn'.tr(),
                              isDark: isDark,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const VoucherScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: Column(
                                children: [
                                  // Main Voucher Ticket Card
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(color: borderColor),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: isDark ? 0.35 : 0.08,
                                          ),
                                          blurRadius: 24,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF59E0B)
                                                .withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const HugeIcon(
                                                icon: HugeIcons.strokeRoundedSparkles,
                                                color: Color(0xFFF59E0B),
                                                size: 15,
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
                                        const SizedBox(height: 18),

                                        // Shop Avatar + Name
                                        Container(
                                          width: 64,
                                          height: 64,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(20),
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF2563EB), Color(0xFF00E5FF)],
                                            ),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: (shopLogo != null &&
                                                  shopLogo.trim().startsWith('http'))
                                              ? Image.network(
                                                  shopLogo,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      Center(
                                                    child: Text(
                                                      shopName.isNotEmpty
                                                          ? shopName[0].toUpperCase()
                                                          : 'N',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w900,
                                                        fontSize: 26,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : Center(
                                                  child: Text(
                                                    shopName.isNotEmpty
                                                        ? shopName[0].toUpperCase()
                                                        : 'N',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 26,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          shopName,
                                          style: GoogleFonts.outfit(
                                            color: textPrimary,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 14),

                                        // Big Discount Callout
                                        Text(
                                          discHeadline,
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF3B82F6),
                                            fontSize: 34,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        if (title.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            title,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: textPrimary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Text(
                                          desc,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: textSecondary,
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                        ),

                                        Divider(height: 32, color: borderColor),

                                        // Promo Code Pill
                                        GestureDetector(
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(text: code));
                                            showGlassToast(
                                              context,
                                              'promo_claim.copy_code_toast'.tr(args: [code]),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF3B82F6)
                                                  .withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: const Color(0xFF3B82F6)
                                                    .withValues(alpha: 0.35),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '${'promo_claim.code_label'.tr()}: ',
                                                  style: TextStyle(
                                                    color: textSecondary,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                Text(
                                                  code,
                                                  style: GoogleFonts.outfit(
                                                    color: const Color(0xFF3B82F6),
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 1.3,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                const HugeIcon(
                                                  icon: HugeIcons.strokeRoundedCopy01,
                                                  color: Color(0xFF3B82F6),
                                                  size: 18,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 14),

                                        // Conditions
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          alignment: WrapAlignment.center,
                                          children: [
                                            _buildInfoTag(
                                              minSpend > 0
                                                  ? 'promo_claim.min_spend_badge'.tr(
                                                      args: [minSpend.toStringAsFixed(0)],
                                                    )
                                                  : 'promo_claim.no_min_spend'.tr(),
                                              isDark,
                                              textSecondary,
                                            ),
                                            _buildInfoTag(
                                              validLabel,
                                              isDark,
                                              textSecondary,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          isPlatform
                                              ? 'promo_claim.platform_note'.tr()
                                              : 'promo_claim.store_specific_note'
                                                  .tr(args: [shopName]),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Primary Claim CTA
                                  SizedBox(
                                    width: double.infinity,
                                    height: 54,
                                    child: ElevatedButton.icon(
                                      onPressed: _isClaiming ? null : () => _claimVoucher(),
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
                                      icon: _isClaiming
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : HugeIcon(
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
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (hasStoreTarget) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: OutlinedButton.icon(
                                        onPressed: _shopNow,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: textPrimary,
                                          side: BorderSide(color: borderColor),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                        icon: const HugeIcon(
                                          icon: HugeIcons.strokeRoundedStore01,
                                          size: 19,
                                        ),
                                        label: Text(
                                          'promo_claim.visit_store_btn'.tr(),
                                          style: GoogleFonts.outfit(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const VoucherScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'promo_claim.view_my_vouchers_btn'.tr(),
                                      style: const TextStyle(
                                        color: Color(0xFF38BDF8),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildInfoTag(String text, bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
