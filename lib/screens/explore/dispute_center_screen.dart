import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/dispute_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/glass_toast.dart';
import '../../widgets/glass_box.dart';
import '../../widgets/glass_nav_button.dart';

// =============================================================================
// Ngam App — Dispute Filing Modal & 3-Way Mediation Room Screen
// Shopee-style Escrow Hold, Customer <-> Business <-> Ngam Admin Mediator Room
// =============================================================================

Future<DisputeCase?> showOpenDisputeSheet({
  required BuildContext context,
  required String targetType, // 'order' | 'booking'
  String? orderId,
  String? bookingId,
  String? bookingRef,
  required String businessId,
  required String businessName,
  required double totalAmount,
  String? itemSummary,
}) {
  return showModalBottomSheet<DisputeCase>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OpenDisputeModal(
      targetType: targetType,
      orderId: orderId,
      bookingId: bookingId,
      bookingRef: bookingRef,
      businessId: businessId,
      businessName: businessName,
      totalAmount: totalAmount,
      itemSummary: itemSummary,
    ),
  );
}

class _OpenDisputeModal extends StatefulWidget {
  final String targetType;
  final String? orderId;
  final String? bookingId;
  final String? bookingRef;
  final String businessId;
  final String businessName;
  final double totalAmount;
  final String? itemSummary;

  const _OpenDisputeModal({
    required this.targetType,
    this.orderId,
    this.bookingId,
    this.bookingRef,
    required this.businessId,
    required this.businessName,
    required this.totalAmount,
    this.itemSummary,
  });

  @override
  State<_OpenDisputeModal> createState() => _OpenDisputeModalState();
}

class _OpenDisputeModalState extends State<_OpenDisputeModal> {
  late String _selectedReason;
  late final TextEditingController _amountCtrl;
  final TextEditingController _detailsCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<String> _evidenceUrls = [];
  bool _isUploading = false;
  bool _isSubmitting = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _selectedReason = widget.targetType == 'booking'
        ? 'service_not_rendered'
        : 'not_received';
    _amountCtrl = TextEditingController(
      text: widget.totalAmount > 0 ? widget.totalAmount.toStringAsFixed(2) : '0.00',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  List<Map<String, String>> get _reasonOptions => [
        {'code': 'not_received', 'label': 'dispute.reason_not_received'.tr()},
        {'code': 'damaged_defective', 'label': 'dispute.reason_damaged'.tr()},
        {'code': 'wrong_item', 'label': 'dispute.reason_wrong_item'.tr()},
        {'code': 'service_not_rendered', 'label': 'dispute.reason_service_not_rendered'.tr()},
        {'code': 'poor_quality', 'label': 'dispute.reason_poor_quality'.tr()},
        {'code': 'overcharged', 'label': 'dispute.reason_overcharged'.tr()},
        {'code': 'other', 'label': 'dispute.reason_other'.tr()},
      ];

  Future<void> _pickPhoto() async {
    if (_evidenceUrls.length >= 4 || _isUploading) return;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 82,
      );
      if (picked == null) return;
      setState(() {
        _isUploading = true;
        _inlineError = null;
      });
      final bytes = await picked.readAsBytes();
      final url = await DisputeService.uploadEvidenceImage(bytes, picked.name);
      if (mounted) {
        setState(() => _evidenceUrls.add(url));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _inlineError = 'dispute.attach_photo_failed'.tr());
        showGlassToast(context, 'dispute.attach_photo_failed'.tr(), type: GlassToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _submit() async {
    final reasonText = _detailsCtrl.text.trim();
    if (reasonText.isEmpty) {
      final msg = 'dispute.details_required'.tr();
      setState(() => _inlineError = msg);
      showGlassToast(context, msg, type: GlassToastType.warning);
      return;
    }
    final reqAmount = double.tryParse(_amountCtrl.text.trim());
    if (reqAmount == null || reqAmount < 0) {
      final msg = 'dispute.invalid_amount'.tr();
      setState(() => _inlineError = msg);
      showGlassToast(context, msg, type: GlassToastType.warning);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });
    try {
      final dispute = await DisputeService.openDispute(
        targetType: widget.targetType,
        orderId: widget.orderId,
        bookingId: widget.bookingId,
        bookingRef: widget.bookingRef,
        businessId: widget.businessId,
        reasonCode: _selectedReason,
        reasonText: reasonText,
        requestedRefundAmount: reqAmount,
        evidenceUrls: List<String>.from(_evidenceUrls),
        itemSummary: widget.itemSummary,
      );
      if (mounted) {
        showGlassToast(context, 'dispute.submit_success'.tr(), type: GlassToastType.warning);
        Navigator.pop(context, dispute);
      }
    } catch (e) {
      if (mounted) {
        final msg = 'dispute.submit_error'.tr(args: [e.toString().replaceAll('Exception: ', '')]);
        setState(() {
          _isSubmitting = false;
          _inlineError = msg;
        });
        showGlassToast(context, msg, type: GlassToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF141824) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF475569);
    final fieldFill = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.45), width: 1.4),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedShield01,
                      color: Colors.orangeAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'dispute.open_title'.tr(),
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.businessName,
                          style: TextStyle(fontSize: 12.5, color: textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.28)),
                ),
                child: Row(
                  children: [
                    const HugeIcon(icon: HugeIcons.strokeRoundedLockPassword, color: Colors.orangeAccent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'dispute.open_subtitle'.tr(),
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.orange.shade200 : Colors.orange.shade900, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              Text('dispute.reason_label'.tr(), style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: fieldFill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedReason,
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1D2234) : Colors.white,
                    style: TextStyle(color: textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
                    items: _reasonOptions
                        .map((e) => DropdownMenuItem(value: e['code'], child: Text(e['label']!)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedReason = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text('dispute.refund_amount_label'.tr(), style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _amountCtrl,
                onChanged: (_) {
                  if (_inlineError != null) setState(() => _inlineError = null);
                },
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
                decoration: InputDecoration(
                  prefixText: 'RM ',
                  prefixStyle: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900, fontSize: 16),
                  filled: true,
                  fillColor: fieldFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              Text('dispute.details_label'.tr(), style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _detailsCtrl,
                onChanged: (_) {
                  if (_inlineError != null) setState(() => _inlineError = null);
                },
                maxLines: 4,
                style: TextStyle(color: textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'dispute.details_hint'.tr(),
                  hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 13),
                  filled: true,
                  fillColor: fieldFill,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: _inlineError != null && _detailsCtrl.text.trim().isEmpty
                        ? const BorderSide(color: Colors.redAccent, width: 1.4)
                        : BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.orangeAccent, width: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text('dispute.evidence_label'.tr(), style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ..._evidenceUrls.asMap().entries.map((e) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: e.value,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => setState(() => _evidenceUrls.removeAt(e.key)),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      )),
                  if (_evidenceUrls.length < 4)
                    GestureDetector(
                      onTap: _isUploading ? null : _pickPhoto,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: fieldFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.4),
                            width: 1.2,
                          ),
                        ),
                        child: _isUploading
                            ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const HugeIcon(icon: HugeIcons.strokeRoundedCamera01, color: AppTheme.primary, size: 22),
                                  const SizedBox(height: 4),
                                  Text(
                                    'dispute.add_photo'.tr(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                  ),
                                ],
                              ),
                      ),
                    ),
                ],
              ),
              if (_inlineError != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _inlineError!,
                          style: TextStyle(
                            color: isDark ? Colors.red.shade200 : Colors.red.shade900,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                            const SizedBox(width: 10),
                            Text('dispute.submitting'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        )
                      : Text('dispute.submit_btn'.tr(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 3-Way Mediation Room Screen (Customer + Store + Ngam Mediator)
// =============================================================================

class DisputeRoomScreen extends StatefulWidget {
  final DisputeCase initialDispute;

  const DisputeRoomScreen({super.key, required this.initialDispute});

  @override
  State<DisputeRoomScreen> createState() => _DisputeRoomScreenState();
}

class _DisputeRoomScreenState extends State<DisputeRoomScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _isSending = false;
  bool _isEscalating = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _statusLabel(String status) {
    return switch (status) {
      'open' => 'dispute.status_open'.tr(),
      'business_responded' => 'dispute.status_business_responded'.tr(),
      'escalated' => 'dispute.status_escalated'.tr(),
      'under_review' => 'dispute.status_under_review'.tr(),
      'resolved_refund_full' => 'dispute.status_resolved_refund_full'.tr(),
      'resolved_refund_partial' => 'dispute.status_resolved_refund_partial'.tr(),
      'resolved_release_business' => 'dispute.status_resolved_release_business'.tr(),
      'withdrawn' => 'dispute.status_withdrawn'.tr(),
      _ => status,
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'open' => const Color(0xFFF59E0B),
      'business_responded' => const Color(0xFF38BDF8),
      'escalated' || 'under_review' => const Color(0xFFA855F7),
      'resolved_refund_full' || 'resolved_refund_partial' => const Color(0xFF10B981),
      'resolved_release_business' => const Color(0xFF3B82F6),
      'withdrawn' => const Color(0xFF94A3B8),
      _ => const Color(0xFFF59E0B),
    };
  }

  int _stepIndex(DisputeCase d) {
    if (d.isResolved) return 3;
    if (d.isEscalated) return 2;
    if (d.status == 'business_responded') return 1;
    return 0;
  }

  Future<void> _sendText(DisputeCase dispute) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _msgCtrl.clear();
    try {
      await DisputeService.sendMessage(
        disputeId: dispute.id,
        message: text,
        senderName: AuthProvider.userName ?? dispute.customerName,
      );
    } catch (e) {
      if (mounted) {
        showGlassToast(context, e.toString(), type: GlassToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendPhoto(DisputeCase dispute) async {
    if (_isSending) return;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 82,
      );
      if (picked == null) return;
      setState(() => _isSending = true);
      final bytes = await picked.readAsBytes();
      final url = await DisputeService.uploadEvidenceImage(bytes, picked.name);
      await DisputeService.sendMessage(
        disputeId: dispute.id,
        message: 'dispute.customer_evidence'.tr(),
        senderName: AuthProvider.userName ?? dispute.customerName,
        attachments: [url],
      );
    } catch (_) {
      if (mounted) {
        showGlassToast(context, 'dispute.attach_photo_failed'.tr(), type: GlassToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _promptEscalate(DisputeCase dispute, bool isDark) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161622) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            const HugeIcon(icon: HugeIcons.strokeRoundedCrown02, color: Color(0xFFA855F7), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'dispute.escalate_confirm_title'.tr(),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'dispute.escalate_confirm_body'.tr(),
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'dispute.escalate_note_hint'.tr(),
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12.5),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('dispute.escalate_confirm_btn'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _isEscalating = true);
    try {
      await DisputeService.escalateToAdmin(dispute.id, note: noteCtrl.text.trim());
      if (mounted) {
        showGlassToast(context, 'dispute.escalate_success'.tr(), type: GlassToastType.info);
      }
    } catch (e) {
      if (mounted) showGlassToast(context, e.toString(), type: GlassToastType.error);
    } finally {
      if (mounted) setState(() => _isEscalating = false);
    }
  }

  void _openLightbox(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF64748B);
    final currFmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A14) : const Color(0xFFF4F6FA),
      body: StreamBuilder<DisputeCase>(
        stream: DisputeService.watchDispute(widget.initialDispute.id),
        initialData: widget.initialDispute,
        builder: (context, dispSnap) {
          final dispute = dispSnap.data ?? widget.initialDispute;
          final sColor = _statusColor(dispute.status);
          final step = _stepIndex(dispute);

          return Stack(
            children: [
              Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).padding.top + 66),

                  // ── Summary & Escrow Progress Card ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: GlassBox(
                      borderRadius: 20,
                      blur: 14,
                      color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.72),
                      padding: const EdgeInsets.all(14),
                      border: Border.all(color: sColor.withValues(alpha: 0.35), width: 1.1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: sColor.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _statusLabel(dispute.status),
                                  style: TextStyle(color: sColor, fontSize: 11, fontWeight: FontWeight.w800),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                currFmt.format(dispute.approvedRefundAmount ?? dispute.requestedRefundAmount),
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: dispute.isResolved ? const Color(0xFF10B981) : textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // 4-step Shopee timeline bar
                          Row(
                            children: [
                              _stepDot('dispute.step_opened'.tr(), step >= 0, sColor, textSecondary),
                              _stepLine(step >= 1, sColor, isDark),
                              _stepDot('dispute.step_responded'.tr(), step >= 1, sColor, textSecondary),
                              _stepLine(step >= 2, sColor, isDark),
                              _stepDot('dispute.step_escalated'.tr(), step >= 2, sColor, textSecondary),
                              _stepLine(step >= 3, sColor, isDark),
                              _stepDot('dispute.step_resolved'.tr(), step >= 3, sColor, textSecondary),
                            ],
                          ),

                          if (dispute.moderatorNote != null && dispute.moderatorNote!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'dispute.verdict_title'.tr(),
                                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    dispute.moderatorNote!,
                                    style: TextStyle(color: textPrimary, fontSize: 12.5, height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (dispute.isEscalated) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFA855F7).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const HugeIcon(icon: HugeIcons.strokeRoundedCrown02, color: Color(0xFFA855F7), size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'dispute.awaiting_verdict'.tr(),
                                      style: TextStyle(color: isDark ? Colors.purple.shade200 : Colors.purple.shade900, fontSize: 11.5, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Evidence Strip
                          if (dispute.customerEvidenceUrls.isNotEmpty || dispute.businessEvidenceUrls.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 48,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  ...dispute.customerEvidenceUrls.map((u) => _evidenceThumb(u, Colors.blue)),
                                  ...dispute.businessEvidenceUrls.map((u) => _evidenceThumb(u, Colors.amber)),
                                ],
                              ),
                            ),
                          ],

                          // Escalate & Withdraw Action Row
                          if (!dispute.isResolved) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (!dispute.isEscalated)
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFA855F7),
                                        side: const BorderSide(color: Color(0xFFA855F7)),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: _isEscalating ? null : () => _promptEscalate(dispute, isDark),
                                      icon: const HugeIcon(icon: HugeIcons.strokeRoundedCrown02, color: Color(0xFFA855F7), size: 16),
                                      label: Text('dispute.escalate_btn'.tr(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ── 3-Way Mediation Chat Stream ──
                  Expanded(
                    child: StreamBuilder<List<DisputeMessage>>(
                      stream: DisputeService.watchMessages(dispute.id),
                      builder: (context, msgSnap) {
                        final msgs = msgSnap.data ?? const <DisputeMessage>[];
                        return ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                          itemCount: msgs.length,
                          itemBuilder: (_, i) => _buildMessageBubble(msgs[i], isDark, textPrimary, textSecondary),
                        );
                      },
                    ),
                  ),

                  // ── Message Composer ──
                  if (!dispute.isResolved)
                    ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: EdgeInsets.fromLTRB(
                            12,
                            10,
                            12,
                            MediaQuery.of(context).padding.bottom > 0
                                ? MediaQuery.of(context).padding.bottom + 4
                                : 12,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF121624).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.92),
                            border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _isSending ? null : () => _sendPhoto(dispute),
                                icon: const HugeIcon(icon: HugeIcons.strokeRoundedImage01, color: AppTheme.primary, size: 22),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _msgCtrl,
                                  style: TextStyle(color: textPrimary, fontSize: 13.5),
                                  decoration: InputDecoration(
                                    hintText: 'dispute.message_hint'.tr(),
                                    hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 13),
                                    filled: true,
                                    fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                                  ),
                                  onSubmitted: (_) => _sendText(dispute),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Material(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(18),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: _isSending ? null : () => _sendText(dispute),
                                  child: const SizedBox(
                                    width: 42,
                                    height: 42,
                                    child: Center(
                                      child: HugeIcon(icon: HugeIcons.strokeRoundedSent02, color: Colors.white, size: 19),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              FloatingTopBar(
                isDark: isDark,
                top: MediaQuery.of(context).padding.top + 10,
                onBack: () => Navigator.pop(context),
                title: 'dispute.case_prefix'.tr(args: [dispute.caseNumber]),
                subtitle: dispute.businessName,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _evidenceThumb(String url, Color borderCol) {
    return GestureDetector(
      onTap: () => _openLightbox(url),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderCol.withValues(alpha: 0.7), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(imageUrl: url, width: 44, height: 44, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _stepDot(String label, bool active, Color activeCol, Color textSecondary) {
    return Column(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? activeCol : Colors.grey.withValues(alpha: 0.25),
          ),
          child: active ? const Icon(Icons.check, size: 11, color: Colors.white) : null,
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(fontSize: 9.5, fontWeight: active ? FontWeight.bold : FontWeight.w500, color: active ? activeCol : textSecondary),
        ),
      ],
    );
  }

  Widget _stepLine(bool active, Color activeCol, bool isDark) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 14, left: 4, right: 4),
        color: active ? activeCol : (isDark ? Colors.white12 : Colors.black12),
      ),
    );
  }

  Widget _buildMessageBubble(DisputeMessage m, bool isDark, Color textPrimary, Color textSecondary) {
    if (m.senderRole == 'system') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Text(
          m.message,
          textAlign: TextAlign.center,
          style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600, height: 1.35),
        ),
      );
    }

    final bool isMe = m.senderRole == 'customer';
    final bool isMediator = m.senderRole == 'moderator';
    final timeStr = DateFormat('hh:mm a').format(m.createdAt);

    Color bubbleBg;
    Color borderColor;
    if (isMediator) {
      bubbleBg = const Color(0xFF7C3AED).withValues(alpha: isDark ? 0.24 : 0.12);
      borderColor = const Color(0xFFA855F7).withValues(alpha: 0.55);
    } else if (isMe) {
      bubbleBg = AppTheme.primary.withValues(alpha: isDark ? 0.25 : 0.14);
      borderColor = AppTheme.primary.withValues(alpha: 0.40);
    } else {
      bubbleBg = isDark ? Colors.white.withValues(alpha: 0.07) : Colors.white;
      borderColor = isDark ? Colors.white12 : Colors.black12;
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isMediator) ...[
                  const HugeIcon(icon: HugeIcons.strokeRoundedCrown02, color: Color(0xFFC084FC), size: 13),
                  const SizedBox(width: 4),
                ],
                Text(
                  isMediator
                      ? 'dispute.mediator_badge'.tr()
                      : (isMe ? m.senderName : '${m.senderName} (${'dispute.business_badge'.tr()})'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isMediator
                        ? const Color(0xFFC084FC)
                        : (isMe ? AppTheme.primary : Colors.amber),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(m.message, style: TextStyle(color: textPrimary, fontSize: 13.5, height: 1.35)),
            if (m.attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: m.attachments
                    .map((u) => GestureDetector(
                          onTap: () => _openLightbox(u),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(imageUrl: u, width: 120, height: 120, fit: BoxFit.cover),
                          ),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 4),
            Text(timeStr, style: TextStyle(fontSize: 9.5, color: textSecondary.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}
