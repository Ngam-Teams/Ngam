import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../services/voucher_service.dart';
import '../utils/app_theme.dart';
import 'glass_toast.dart';

class VoucherSelectionSheet extends StatefulWidget {
  final String? businessId;
  final double subtotal;
  final String? currentVoucherCode;
  final String? category;

  const VoucherSelectionSheet({
    super.key,
    this.businessId,
    required this.subtotal,
    this.currentVoucherCode,
    this.category,
  });

  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    String? businessId,
    required double subtotal,
    String? currentVoucherCode,
    String? category,
  }) async {
    return await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoucherSelectionSheet(
        businessId: businessId,
        subtotal: subtotal,
        currentVoucherCode: currentVoucherCode,
        category: category,
      ),
    );
  }

  @override
  State<VoucherSelectionSheet> createState() => _VoucherSelectionSheetState();
}

class _VoucherSelectionSheetState extends State<VoucherSelectionSheet> {
  final TextEditingController _customCodeController = TextEditingController();
  bool _isLoading = true;
  bool _isCheckingCode = false;
  List<Map<String, dynamic>> _vouchers = [];

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  @override
  void dispose() {
    _customCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadVouchers() async {
    setState(() => _isLoading = true);
    final list = await VoucherService.getAvailableVouchersForCheckout(
      businessId: widget.businessId,
      subtotal: widget.subtotal,
      category: widget.category,
    );
    if (!mounted) return;
    setState(() {
      _vouchers = list;
      _isLoading = false;
    });
  }

  Future<void> _applyCustomCode() async {
    final code = _customCodeController.text.trim();
    if (code.isEmpty) {
      showGlassToast(context, 'Sila masukkan kod baucar', isError: true);
      return;
    }

    setState(() => _isCheckingCode = true);
    final res = await VoucherService.validateAndApplyCode(
      code: code,
      businessId: widget.businessId,
      subtotal: widget.subtotal,
    );
    if (!mounted) return;
    setState(() => _isCheckingCode = false);

    if (res['success'] == true && res['voucher'] != null) {
      final v = Map<String, dynamic>.from(res['voucher'] as Map);
      showGlassToast(context, res['message'] ?? 'Baucar digunakan!');
      Navigator.pop(context, v);
    } else {
      showGlassToast(context, res['message'] ?? 'Kod tidak sah untuk pesanan ini', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF141920) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);

    final currencyFmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

    final eligible = _vouchers.where((v) => v['is_eligible'] == true).toList();
    final ineligible = _vouchers.where((v) => v['is_eligible'] != true).toList();

    final currentCode = widget.currentVoucherCode?.trim().toUpperCase();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.86,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F141A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle Bar
            Container(
              width: 44,
              height: 4.5,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedDiscount01,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih Baucar Diskaun',
                          style: GoogleFonts.outfit(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Jumlah Pesanan: ${currencyFmt.format(widget.subtotal)}',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (currentCode != null && currentCode.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const HugeIcon(icon: HugeIcons.strokeRoundedDelete02, size: 14, color: Colors.redAccent),
                      label: const Text('Batal Guna', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => Navigator.pop(context, {'clear': true}),
                    ),
                ],
              ),
            ),

            // Promo Code Input Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _customCodeController,
                        textCapitalization: TextCapitalization.characters,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ada kod promo khas? Taip di sini...',
                          hintStyle: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                            letterSpacing: 0,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: _isCheckingCode ? null : _applyCustomCode,
                      child: _isCheckingCode
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Guna',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Content List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        if (eligible.isNotEmpty) ...[
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Baucar Layak Digunakan (${eligible.length})',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...eligible.map((v) => _buildVoucherTile(
                                v: v,
                                isDark: isDark,
                                cardBg: cardBg,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                isEligible: true,
                                isCurrent: currentCode == (v['code'] ?? '').toString().toUpperCase(),
                              )),
                          const SizedBox(height: 16),
                        ],

                        if (ineligible.isNotEmpty) ...[
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white30 : Colors.black26,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Belum Layak / Baucar Lain (${ineligible.length})',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...ineligible.map((v) => _buildVoucherTile(
                                v: v,
                                isDark: isDark,
                                cardBg: cardBg,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                isEligible: false,
                                isCurrent: false,
                              )),
                        ],

                        if (_vouchers.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Column(
                                children: [
                                  const HugeIcon(
                                    icon: HugeIcons.strokeRoundedTicket01,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Tiada baucar dijumpai buat masa ini.',
                                    style: TextStyle(color: textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoucherTile({
    required Map<String, dynamic> v,
    required bool isDark,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
    required bool isEligible,
    required bool isCurrent,
  }) {
    final code = (v['code'] ?? '').toString().toUpperCase();
    final title = v['title']?.toString() ?? 'Baucar Diskaun $code';
    final shopName = v['shop_name']?.toString() ?? 'Rakan Niaga Ngam';
    final discType = v['discount_type']?.toString() ?? 'fixed';
    final discVal = (v['discount_value'] as num?)?.toDouble() ?? 0.0;
    final minSpend = (v['min_spend'] as num?)?.toDouble() ?? 0.0;
    final calcDisc = (v['calculated_discount'] as num?)?.toDouble() ?? 0.0;
    final reason = v['eligibility_reason']?.toString() ?? '';

    String valueBadge = discType == 'percentage'
        ? '${discVal.toInt()}%'
        : 'RM${discVal.toStringAsFixed(0)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFF10B981)
              : (isEligible
                  ? (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08))
                  : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03))),
          width: isCurrent ? 1.8 : 1.0,
        ),
        boxShadow: isEligible
            ? [
                BoxShadow(
                  color: isCurrent
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Stub
              Container(
                width: 84,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isEligible
                        ? (isCurrent
                            ? const [Color(0xFF059669), Color(0xFF10B981)]
                            : const [AppTheme.primary, Color(0xFF1D4ED8)])
                        : [
                            Colors.grey.shade600,
                            Colors.grey.shade700,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      valueBadge,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'DISKAUN',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Divider notch look
              Container(
                width: 1,
                color: isDark ? Colors.white10 : Colors.black12,
              ),

              // Right details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              shopName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : (isEligible
                                      ? AppTheme.primary.withValues(alpha: 0.1)
                                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              code,
                              style: GoogleFonts.spaceMono(
                                color: isCurrent
                                    ? const Color(0xFF10B981)
                                    : (isEligible ? AppTheme.primary : textSecondary),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: isEligible ? textPrimary : textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        minSpend > 0
                            ? 'Min belanja RM ${minSpend.toStringAsFixed(0)}'
                            : 'Tiada belanja minimum',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (isEligible)
                            Text(
                              'Jimat RM ${calcDisc.toStringAsFixed(2)}!',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            Flexible(
                              child: Text(
                                reason,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, color: Color(0xFF10B981), size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'Digunakan',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (isEligible)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                Navigator.pop(context, v);
                              },
                              child: const Text(
                                'Gunakan',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
