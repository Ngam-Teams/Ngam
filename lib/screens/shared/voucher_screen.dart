import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/voucher_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/glass_toast.dart';
import '../../widgets/glass_nav_button.dart';

class VoucherScreen extends StatefulWidget {
  const VoucherScreen({super.key});

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  int _selectedTab = 0; // 0: Tersimpan, 1: Teroka Baucar (Tawaran Hebat)
  final TextEditingController _claimCodeController = TextEditingController();
  bool _isClaiming = false;
  List<Map<String, dynamic>> _exploreVouchers = [];

  // Default curated demo offers when user opens "Teroka Baucar" tab
  final List<Map<String, dynamic>> _curatedPromos = [
    {
      'id': 'promo_ngam_welcome',
      'code': 'NGAMBARU',
      'title': 'Diskaun Pengguna Baru RM5',
      'shop_name': 'Semua Rakan Niaga Ngam',
      'shop_logo': null,
      'discount_type': 'fixed',
      'discount_value': 5.0,
      'min_spend': 15.0,
      'end_date': DateTime.now().add(const Duration(days: 45)).toIso8601String(),
      'description': 'Diskaun RM5 untuk tempahan atau pesanan pertama anda di aplikasi Ngam.',
      'badge': 'Paling Hangat',
      'gradient': [Color(0xFF2563EB), Color(0xFF1D4ED8)],
    },
    {
      'id': 'promo_barber_cut',
      'code': 'STYLE10',
      'title': 'Potongan 10% Servis Gunting Rambut',
      'shop_name': 'Barber King Studio & Gunting',
      'shop_logo': null,
      'discount_type': 'percentage',
      'discount_value': 10.0,
      'min_spend': 25.0,
      'max_discount_amount': 5.0,
      'end_date': DateTime.now().add(const Duration(days: 20)).toIso8601String(),
      'description': 'Potongan 10% untuk pakej Haircut & Beard Grooming di cawangan terpilih.',
      'badge': 'Servis Barber',
      'gradient': [Color(0xFF7C3AED), Color(0xFF6D28D9)],
    },
    {
      'id': 'promo_coffee_fever',
      'code': 'KOPINGAM',
      'title': 'Jimat RM3 Segelas Kopi & Pastri',
      'shop_name': 'The Daily Grind Cafe & Bistro',
      'shop_logo': null,
      'discount_type': 'fixed',
      'discount_value': 3.0,
      'min_spend': 12.0,
      'end_date': DateTime.now().add(const Duration(days: 14)).toIso8601String(),
      'description': 'Nikmati jimat RM3 bila pesan kopi artisan atau pastry combo petang.',
      'badge': 'Kafe & Minuman',
      'gradient': [Color(0xFF059669), Color(0xFF047857)],
    },
    {
      'id': 'promo_carwash_shine',
      'code': 'KILAT5',
      'title': 'Rebat RM5 Cuci Salji & Wax Kereta',
      'shop_name': 'AutoSpa Carwash & Detailing',
      'shop_logo': null,
      'discount_type': 'fixed',
      'discount_value': 5.0,
      'min_spend': 20.0,
      'end_date': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'description': 'Rebat segera RM5 untuk carwash pakej Snow & Wax cuci kilat.',
      'badge': 'Cuci Kereta',
      'gradient': [Color(0xFFD97706), Color(0xFFB45309)],
    },
  ];

  @override
  void initState() {
    super.initState();
    VoucherService.init();
    _fetchLiveExploreVouchers();
  }

  @override
  void dispose() {
    _claimCodeController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveExploreVouchers() async {
    try {
      final res = await Supabase.instance.client
          .from('vouchers')
          .select('*, businesses(name, business_logo_url)')
          .eq('is_active', true)
          .limit(20);

      if (mounted && res.isNotEmpty) {
        final List<Map<String, dynamic>> mapped = [];
        for (var item in res) {
          final m = Map<String, dynamic>.from(item);
          final biz = m['businesses'] as Map<String, dynamic>?;
          mapped.add({
            'id': m['id']?.toString() ?? 'v_${m['code']}',
            'code': m['code']?.toString() ?? '',
            'title': m['title']?.toString() ?? 'Baucar Diskaun ${m['code']}',
            'shop_name': biz?['name']?.toString() ?? 'Rakan Niaga Ngam',
            'shop_logo': biz?['business_logo_url']?.toString(),
            'business_id': m['business_id']?.toString(),
            'discount_type': m['discount_type'] ?? 'fixed',
            'discount_value': (m['discount_value'] as num?)?.toDouble() ?? 0.0,
            'min_spend': (m['min_spend'] as num?)?.toDouble() ?? 0.0,
            'max_discount_amount': (m['max_discount_amount'] as num?)?.toDouble(),
            'end_date': m['end_date'],
            'description': m['description']?.toString() ?? 'Diskaun eksklusif untuk pesanan di Ngam.',
            'badge': 'Disahkan',
            'gradient': [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
          });
        }
        setState(() {
          _exploreVouchers = mapped;
        });
      }
    } catch (e) {
      debugPrint('[VoucherScreen] Gagal tarik baucar langsung: $e');
    }
  }

  Future<void> _claimCode() async {
    final code = _claimCodeController.text.trim();
    if (code.isEmpty) {
      showGlassToast(context, 'Sila taip kod baucar terlebih dahulu', isError: true);
      return;
    }

    setState(() => _isClaiming = true);
    final res = await VoucherService.saveVoucherByCode(code);
    if (!mounted) return;
    setState(() => _isClaiming = false);

    if (res['success'] == true) {
      _claimCodeController.clear();
      FocusScope.of(context).unfocus();
      showGlassToast(context, res['message'] ?? 'Baucar berjaya disimpan!');
    } else {
      showGlassToast(context, res['message'] ?? 'Gagal menyimpan baucar', isError: true);
    }
  }

  void _showVoucherDetailSheet(Map<String, dynamic> voucher, bool isDark) {
    final code = (voucher['code'] ?? '').toString().toUpperCase();
    final title = voucher['title']?.toString() ?? 'Baucar Promosi';
    final shopName = voucher['shop_name']?.toString() ?? 'Rakan Niaga Ngam';
    final discType = voucher['discount_type']?.toString() ?? 'fixed';
    final discVal = (voucher['discount_value'] as num?)?.toDouble() ?? 0.0;
    final minSpend = (voucher['min_spend'] as num?)?.toDouble() ?? 0.0;
    final endDateStr = voucher['end_date']?.toString();
    final desc = voucher['description']?.toString() ?? 'Tebus baucar ini di kaunter bayaran atau troli pesanan.';

    String discLabel = discType == 'percentage'
        ? '${discVal.toInt()}% OFF'
        : 'RM ${discVal.toStringAsFixed(0)} OFF';

    String validDate = 'Sah laku selamanya';
    if (endDateStr != null && endDateStr.isNotEmpty) {
      final dt = DateTime.tryParse(endDateStr);
      if (dt != null) {
        validDate = 'Sah sehingga ${DateFormat('dd MMM yyyy, h:mm a').format(dt.toLocal())}';
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isSaved = VoucherService.isVoucherSaved(
          id: voucher['id']?.toString(),
          code: code,
        );

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141424) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  discLabel,
                  style: GoogleFonts.outfit(
                    color: AppTheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                shopName,
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              // QR Code and Code box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E34) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: 'NGAM_VOUCHER:$code',
                        version: QrVersions.auto,
                        size: 140,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Tunjukkan kod QR atau salin kod ini:',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            code,
                            style: GoogleFonts.spaceMono(
                              color: AppTheme.primary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: code));
                              showGlassToast(context, 'Kod $code berjaya disalin!');
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const HugeIcon(
                                icon: HugeIcons.strokeRoundedCopy01,
                                color: AppTheme.primary,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Rules summary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedInformationCircle,
                          color: isDark ? Colors.white70 : Colors.black54,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Syarat & Terma:',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Belanja minimum: RM ${minSpend.toStringAsFixed(2)}\n• $validDate\n• $desc',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Action Button (Simpan Baucar / Buang Baucar)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : Colors.black87,
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSaved ? Colors.redAccent : AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      icon: HugeIcon(
                        icon: isSaved
                            ? HugeIcons.strokeRoundedDelete02
                            : HugeIcons.strokeRoundedBookmark02,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: Text(
                        isSaved ? 'Padam Baucar' : 'Simpan Baucar',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final savedNow = await VoucherService.toggleSaveVoucher(voucher);
                        if (!mounted) return;
                        showGlassToast(
                          context,
                          savedNow
                              ? 'Baucar $code telah disimpan ke profil!'
                              : 'Baucar $code telah dibuang dari profil.',
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A14) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF141424) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar with standardized GlassNavButton
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GlassNavButton.back(
                    context: context,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Baucar & Ganjaran',
                          style: GoogleFonts.outfit(
                            color: textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Simpan kod promosi & tebus diskaun eksklusif',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Claim Voucher Code Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedDiscount01,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _claimCodeController,
                        textCapitalization: TextCapitalization.characters,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Masukkan kod baucar (cth: NGAMBARU)',
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
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      onPressed: _isClaiming ? null : _claimCode,
                      child: _isClaiming
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Simpan',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Tab Selector (Baucar Saya vs Teroka Baucar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141424) : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: VoucherService.savedVouchersNotifier,
                  builder: (context, savedVouchers, _) {
                    return Row(
                      children: [
                        Expanded(
                          child: _buildTabItem(
                            index: 0,
                            label: 'Baucar Saya',
                            icon: HugeIcons.strokeRoundedBookmark02,
                            count: savedVouchers.length,
                            isDark: isDark,
                          ),
                        ),
                        Expanded(
                          child: _buildTabItem(
                            index: 1,
                            label: 'Tawaran Hebat',
                            icon: HugeIcons.strokeRoundedFire,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Tab Content
            Expanded(
              child: _selectedTab == 0
                  ? _buildSavedVouchersList(isDark, cardBg, textPrimary, textSecondary)
                  : _buildExploreVouchersList(isDark, cardBg, textPrimary, textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required String label,
    required dynamic icon,
    int? count,
    required bool isDark,
  }) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2196F3).withValues(alpha: 0.2) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(
                  color: isDark
                      ? const Color(0xFF2196F3).withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.08),
                )
              : null,
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: icon,
              color: isSelected ? const Color(0xFF2196F3) : (isDark ? Colors.white54 : Colors.black54),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? Colors.white54 : Colors.black54),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2196F3) : (isDark ? Colors.white12 : Colors.black12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSavedVouchersList(
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: VoucherService.savedVouchersNotifier,
      builder: (context, vouchers, _) {
        if (vouchers.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedTicket01,
                        color: AppTheme.primary,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Tiada Baucar Tersimpan',
                    style: GoogleFonts.outfit(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Masukkan kod baucar di atas atau teroka tawaran hebat untuk simpan baucar diskaun anda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedFire,
                      color: Colors.white,
                      size: 16,
                    ),
                    label: const Text(
                      'Teroka Tawaran Hebat',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => setState(() => _selectedTab = 1),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: vouchers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final v = vouchers[index];
            return _buildVoucherCard(v, isDark, cardBg, textPrimary, textSecondary, isSavedTab: true);
          },
        );
      },
    );
  }

  Widget _buildExploreVouchersList(
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
  ) {
    final list = _exploreVouchers.isNotEmpty ? _exploreVouchers : _curatedPromos;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final v = list[index];
        return _buildVoucherCard(v, isDark, cardBg, textPrimary, textSecondary, isSavedTab: false);
      },
    );
  }

  Widget _buildVoucherCard(
    Map<String, dynamic> v,
    bool isDark,
    Color cardBg,
    Color textPrimary,
    Color textSecondary, {
    required bool isSavedTab,
  }) {
    final code = (v['code'] ?? '').toString().toUpperCase();
    final title = v['title']?.toString() ?? 'Baucar Diskaun $code';
    final shopName = v['shop_name']?.toString() ?? 'Rakan Niaga Ngam';
    final discType = v['discount_type']?.toString() ?? 'fixed';
    final discVal = (v['discount_value'] as num?)?.toDouble() ?? 0.0;
    final minSpend = (v['min_spend'] as num?)?.toDouble() ?? 0.0;
    final badge = v['badge']?.toString() ?? 'Diskaun';

    String valueText = discType == 'percentage'
        ? '${discVal.toInt()}%'
        : 'RM${discVal.toStringAsFixed(0)}';

    return InkWell(
      onTap: () => _showVoucherDetailSheet(v, isDark),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Ticket Stub / Coupon Notch
                Container(
                  width: 96,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary,
                        Color(0xFF1D4ED8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        valueText,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'OFF',
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Dashed separator look
                Container(
                  width: 1,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),

                // Right Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
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
                            // Quick Action: Copy Code or Save
                            ValueListenableBuilder<List<Map<String, dynamic>>>(
                              valueListenable: VoucherService.savedVouchersNotifier,
                              builder: (context, _, __) {
                                final isSaved = VoucherService.isVoucherSaved(
                                  id: v['id']?.toString(),
                                  code: code,
                                );
                                return InkWell(
                                  onTap: () async {
                                    final savedNow = await VoucherService.toggleSaveVoucher(v);
                                    if (!context.mounted) return;
                                    showGlassToast(
                                      context,
                                      savedNow
                                          ? 'Baucar $code telah disimpan!'
                                          : 'Baucar $code telah dibuang dari simpanan.',
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: HugeIcon(
                                      icon: isSaved
                                          ? HugeIcons.strokeRoundedBookmark02
                                          : HugeIcons.strokeRoundedBookmarkAdd01,
                                      color: isSaved
                                          ? AppTheme.primary
                                          : (isDark ? Colors.white38 : Colors.black38),
                                      size: 18,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          minSpend > 0
                              ? 'Min belanja RM ${minSpend.toStringAsFixed(0)}'
                              : 'Tiada belanja minimum',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.primary.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    code,
                                    style: GoogleFonts.spaceMono(
                                      color: AppTheme.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: code));
                                      showGlassToast(context, 'Kod $code disalin!');
                                    },
                                    child: const HugeIcon(
                                      icon: HugeIcons.strokeRoundedCopy01,
                                      color: AppTheme.primary,
                                      size: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            const Text(
                              'Lihat Info >',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
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
      ),
    );
  }
}
