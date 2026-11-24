import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../services/ereceipt_service.dart';
import '../../utils/ngam_ref.dart';
import '../../utils/qr_route_helper.dart';
import '../../widgets/glass_nav_button.dart';
import '../explore/qr_scanner_screen.dart';
import 'ereceipt_screen.dart';

class MyReceiptsScreen extends StatefulWidget {
  const MyReceiptsScreen({super.key});

  @override
  State<MyReceiptsScreen> createState() => _MyReceiptsScreenState();
}

class _MyReceiptsScreenState extends State<MyReceiptsScreen> {
  List<Map<String, dynamic>> _receipts = [];
  bool _isLoading = true;
  int _filterIndex = 0; // 0: All, 1: Scanned POS, 2: Online

  @override
  void initState() {
    super.initState();
    EreceiptService.savedReceiptsNotifier.addListener(_onLocalReceiptsChanged);
    _loadReceipts();
  }

  @override
  void dispose() {
    EreceiptService.savedReceiptsNotifier.removeListener(_onLocalReceiptsChanged);
    super.dispose();
  }

  void _onLocalReceiptsChanged() {
    if (mounted) {
      _loadReceipts();
    }
  }

  Future<void> _loadReceipts() async {
    final list = await EreceiptService.fetchMergedReceipts();
    if (!mounted) return;
    setState(() {
      _receipts = list;
      _isLoading = false;
    });
  }

  Future<void> _openScanner() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
    if (scanned == null || scanned.trim().isEmpty || !mounted) return;
    NgamQrRouteHelper.handleScannedQr(context, scanned);
  }

  List<Map<String, dynamic>> get _filteredReceipts {
    if (_filterIndex == 0) return _receipts;
    if (_filterIndex == 1) {
      return _receipts
          .where((r) => (r['source'] ?? 'scanned').toString() != 'online')
          .toList();
    }
    return _receipts
        .where((r) => (r['source'] ?? '').toString() == 'online')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0D16) : const Color(0xFFF4F7FC);
    final cardColor = isDark ? const Color(0xFF131926) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : Colors.black.withValues(alpha: 0.07);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);

    final filtered = _filteredReceipts;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  GlassNavButton.back(context: context, isDark: isDark),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ereceipt.my_receipts_title'.tr(),
                      style: GoogleFonts.outfit(
                        color: textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  GlassNavButton(
                    icon: HugeIcons.strokeRoundedQrCode,
                    tooltip: 'ereceipt.scan_receipt_btn'.tr(),
                    isDark: isDark,
                    onTap: _openScanner,
                  ),
                ],
              ),
            ),

            // Summary Banner
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.14),
                      const Color(0xFF00E5FF).withValues(alpha: isDark ? 0.10 : 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ereceipt.total_saved_label'.tr(),
                            style: TextStyle(color: textSecondary, fontSize: 11.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_receipts.length}',
                            style: GoogleFonts.outfit(
                              color: textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: borderColor,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: ValueListenableBuilder<int>(
                          valueListenable: EreceiptService.totalPointsNotifier,
                          builder: (context, pts, _) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ereceipt.total_points_label'.tr(),
                                  style: TextStyle(color: textSecondary, fontSize: 11.5),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ereceipt.balance_pill'.tr(args: [pts.toString()]),
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF10B981),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Filter Pills
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildFilterChip(0, 'ereceipt.filter_all'.tr(), isDark, textPrimary),
                  const SizedBox(width: 8),
                  _buildFilterChip(1, 'ereceipt.filter_scanned'.tr(), isDark, textPrimary),
                  const SizedBox(width: 8),
                  _buildFilterChip(2, 'ereceipt.filter_online'.tr(), isDark, textPrimary),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // List Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedInvoice01,
                                    color: Color(0xFF3B82F6),
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'ereceipt.empty_title'.tr(),
                                  style: GoogleFonts.outfit(
                                    color: textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'ereceipt.empty_subtitle'.tr(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _openScanner,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedQrCode,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'ereceipt.scan_receipt_btn'.tr(),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadReceipts,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final r = filtered[idx];
                              return _buildReceiptCard(
                                r,
                                isDark,
                                cardColor,
                                borderColor,
                                textPrimary,
                                textSecondary,
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(int idx, String label, bool isDark, Color textPrimary) {
    final selected = _filterIndex == idx;
    return GestureDetector(
      onTap: () => setState(() => _filterIndex = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2563EB)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF2563EB)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : textPrimary,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptCard(
    Map<String, dynamic> receipt,
    bool isDark,
    Color cardColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final shopName = (receipt['shop_name'] ?? 'ereceipt.default_shop'.tr()).toString();
    final rawRef = (receipt['ref'] ?? '').toString().trim().replaceAll('#', '');
    final oid = (receipt['order_id'] ?? '').toString().trim();
    final createdDt = DateTime.tryParse((receipt['created_at'] ?? receipt['date'] ?? '').toString());
    final isOnline = (receipt['source'] ?? '').toString() == 'online';
    final isPos = (receipt['source'] ?? '').toString() == 'pos';
    final refNo = NgamRef.isValid(rawRef)
        ? rawRef.toUpperCase()
        : (oid.isNotEmpty
            ? (isPos ? NgamRef.pos(oid, createdDt) : NgamRef.order(oid, createdAt: createdDt))
            : NgamRef.pos(rawRef.isNotEmpty ? rawRef : null, createdDt));
    final total = (receipt['total'] as num?)?.toDouble() ?? 0.0;
    final claimed = receipt['points_claimed'] == true;
    final pts = (receipt['points_earned'] as num?)?.toInt() ??
        EreceiptService.computePoints(total);
    final itemsCount = (receipt['items'] is List) ? (receipt['items'] as List).length : 0;
    final dt = DateTime.tryParse((receipt['date'] ?? '').toString())?.toLocal() ?? DateTime.now();
    final dateStr = DateFormat('dd MMM yyyy • hh:mm a').format(dt);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EreceiptScreen(
              initialReceipt: receipt,
              openedFromArchive: true,
            ),
          ),
        );
        _loadReceipts();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: (isOnline ? const Color(0xFF3B82F6) : const Color(0xFF10B981))
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: HugeIcon(
                  icon: isOnline
                      ? HugeIcons.strokeRoundedShoppingCart02
                      : HugeIcons.strokeRoundedInvoice01,
                  color: isOnline ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          shopName,
                          style: GoogleFonts.outfit(
                            color: textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'RM ${total.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '#$refNo • $dateStr',
                          style: TextStyle(color: textSecondary, fontSize: 11.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isOnline
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFF8B5CF6))
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isOnline
                              ? 'ereceipt.source_online'.tr()
                              : 'ereceipt.source_scanned'.tr(),
                          style: TextStyle(
                            color: isOnline
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF8B5CF6),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (itemsCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'ereceipt.items_count'.tr(args: [itemsCount.toString()]),
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (claimed)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'ereceipt.points_earned_badge'.tr(args: [pts.toString()]),
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
