import '../utils/file_saver/file_saver.dart';
import 'dart:async';
import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';

import '../services/chip_payment_service.dart';
import '../services/receipt_pdf_service.dart';
import 'glass_toast.dart';

enum PaymentStep { selectMethod, duitNowQr, receipt }

class CustomerPaymentModal extends StatefulWidget {
  final double amount;
  final String orderTitle;
  final String shopName;
  final String orderId;
  final List<Map<String, dynamic>> items;
  final String? customerName;
  final String? customerPhone;
  final String? voucherCode;
  final double? discountAmount;
  final String? initialMethod;
  final Future<void> Function(String method, String transactionRef)? onPaymentSuccess;

  const CustomerPaymentModal({
    super.key,
    required this.amount,
    required this.orderTitle,
    required this.shopName,
    required this.orderId,
    this.items = const [],
    this.customerName,
    this.customerPhone,
    this.voucherCode,
    this.discountAmount,
    this.initialMethod,
    this.onPaymentSuccess,
  });

  static Future<bool> show({
    required BuildContext context,
    required double amount,
    required String orderTitle,
    required String shopName,
    required String orderId,
    List<Map<String, dynamic>> items = const [],
    String? customerName,
    String? customerPhone,
    String? voucherCode,
    double? discountAmount,
    String? initialMethod,
    Future<void> Function(String method, String transactionRef)? onPaymentSuccess,
  }) async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomerPaymentModal(
        amount: amount,
        orderTitle: orderTitle,
        shopName: shopName,
        orderId: orderId,
        items: items,
        customerName: customerName,
        customerPhone: customerPhone,
        voucherCode: voucherCode,
        discountAmount: discountAmount,
        initialMethod: initialMethod,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
    return res ?? false;
  }

  @override
  State<CustomerPaymentModal> createState() => _CustomerPaymentModalState();
}

class _CustomerPaymentModalState extends State<CustomerPaymentModal> {
  PaymentStep _currentStep = PaymentStep.duitNowQr;
  String _selectedMethod = 'duitnow'; // 'duitnow', 'fpx_card', 'cash'
  bool get _isCash => _selectedMethod == 'cash';

  ChipPurchaseResult? _purchase;
  bool _isLoadingQr = true;
  bool _isVerifyingManual = false;
  String? _gatewayError;
  Timer? _statusTimer;
  Timer? _countdownTimer;
  int _secondsRemaining = 300; // 5 minit
  String _transactionRef = '';

  @override
  void initState() {
    super.initState();
    final initMethod = (widget.initialMethod ?? 'duitnow').trim().toLowerCase();
    if (initMethod == 'fpx' || initMethod == 'card' || initMethod == 'fpx_card') {
      _selectedMethod = 'fpx_card';
    } else if (initMethod == 'cash') {
      _selectedMethod = 'cash';
    } else {
      _selectedMethod = 'duitnow';
    }

    if (_selectedMethod == 'cash') {
      _isLoadingQr = false;
      _currentStep = PaymentStep.receipt;
      final shortId = widget.orderId.length > 8 ? widget.orderId.substring(0, 8) : widget.orderId;
      _transactionRef = 'CASH-${shortId.toUpperCase()}';
    } else {
      // Terus ke skrin Gerbang Pembayaran tanpa tanya kaedah bayaran buat kali kedua
      _currentStep = PaymentStep.duitNowQr;
      _isLoadingQr = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startGatewayFlow();
      });
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _secondsRemaining = 300;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_secondsRemaining > 0) {
          setState(() => _secondsRemaining--);
        } else {
          timer.cancel();
          _statusTimer?.cancel();
          if (_currentStep == PaymentStep.duitNowQr) {
            showGlassToast(context, 'payment_modal.session_expired'.tr(), isError: true);
            Navigator.pop(context, false);
          }
        }
      }
    });
  }

  void _startPollingStatus(String purchaseId) {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final status = await ChipPaymentService.instance.checkPurchaseStatus(purchaseId);
      if (status == 'paid') {
        timer.cancel();
        _countdownTimer?.cancel();
        final label = _selectedMethod == 'fpx_card' ? 'FPX / Kad (CHIP Asia)' : 'DuitNow QR (CHIP Asia)';
        _handleSuccessPayment(label, purchaseId);
      }
    });
  }

  void _handleSuccessPayment(String method, String ref) async {
    HapticFeedback.heavyImpact();
    setState(() {
      _transactionRef = ref.isNotEmpty ? ref : 'CHIP-${DateTime.now().millisecondsSinceEpoch}';
      _currentStep = PaymentStep.receipt;
    });

    if (!_isCash && widget.onPaymentSuccess != null) {
      await widget.onPaymentSuccess!(method, _transactionRef);
    }
  }

  Future<void> _startGatewayFlow() async {
    setState(() {
      _currentStep = PaymentStep.duitNowQr;
      _isLoadingQr = true;
      _gatewayError = null;
    });

    try {
      final res = await ChipPaymentService.instance.createPurchase(
        amount: widget.amount,
        orderTitle: widget.orderTitle,
        reference: widget.orderId,
        clientName: widget.customerName,
        clientPhone: widget.customerPhone,
        paymentMethodWhitelist: _selectedMethod == 'duitnow' ? const ['duitnow_qr'] : null,
      );

      if (!mounted) return;
      setState(() {
        _purchase = res;
        _isLoadingQr = false;
      });
      _startCountdown();
      _startPollingStatus(res.id);

      // Jika pelanggan memilih Perbankan FPX / Kad (atau tiada payload QR langsung), buka pautan selamat CHIP Asia
      if ((_selectedMethod == 'fpx_card' || !res.hasDirectQrPayload) && res.checkoutUrl.isNotEmpty) {
        final uri = Uri.tryParse(res.checkoutUrl);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (mounted) {
            showGlassToast(
              context,
              'payment_modal.opening_chip_gateway'.tr(),
              icon: HugeIcons.strokeRoundedLinkSquare01,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[CustomerPaymentModal] CHIP createPurchase error: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingQr = false;
        _gatewayError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _verifyPaymentStatusNow() async {
    final purchaseId = _purchase?.id ?? '';
    if (purchaseId.isEmpty || _isVerifyingManual) return;

    setState(() => _isVerifyingManual = true);
    HapticFeedback.mediumImpact();
    try {
      final status = await ChipPaymentService.instance.checkPurchaseStatus(purchaseId);
      if (!mounted) return;
      setState(() => _isVerifyingManual = false);

      if (status == 'paid') {
        _statusTimer?.cancel();
        _countdownTimer?.cancel();
        final label = _selectedMethod == 'fpx_card' ? 'FPX / Kad (CHIP Asia)' : 'DuitNow QR (CHIP Asia)';
        _handleSuccessPayment(label, purchaseId);
        showGlassToast(context, 'payment_modal.payment_verified'.tr());
      } else {
        showGlassToast(
          context,
          'payment_modal.payment_not_received'.tr(),
          isError: true,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isVerifyingManual = false);
      showGlassToast(context, 'payment_modal.check_status_failed'.tr(), isError: true);
    }
  }

  /// Shimmer loading placeholder aesthetic untuk skrin penjanaan QR
  Widget _buildQrShimmer(bool isDark) {
    final baseColor = isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05);
    final highlightColor = isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.12);

    return Column(
      children: [
        // Simulated Shimmer Card Container
        Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161F2E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                width: 1.0,
              ),
            ),
            child: Column(
              children: [
                // Header badge placeholder
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 75,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // QR Box placeholder
                Container(
                  width: 196,
                  height: 196,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Amount placeholder
                Container(
                  width: 130,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                // Subtitle placeholder
                Container(
                  width: 220,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Indicator & helper text bawah shimmer
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
            ),
            const SizedBox(width: 8),
            Text(
              'payment_modal.preparing_session'.tr(),
              style: TextStyle(
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Shimmer action buttons placeholders
        Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final bottomPadding = mediaQuery.padding.bottom;

    return PopScope(
      canPop: _currentStep != PaymentStep.receipt,
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: mediaQuery.size.height * 0.90,
            maxWidth: 500,
          ),
          margin: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            bottomInset > 0 ? bottomInset + 12 : (bottomPadding > 0 ? bottomPadding + 8 : 16),
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF10151E).withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.08),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                blurRadius: 32,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle Bar
                    Container(
                      width: 44,
                      height: 4.5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    // STEP 1: PILIH KAEDAH BAYARAN
                    if (_currentStep == PaymentStep.selectMethod) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'payment_modal.choose_method'.tr(),
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.shopName,
                                style: TextStyle(
                                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  currencyFormat.format(widget.amount),
                                  style: const TextStyle(
                                    color: Color(0xFF00E5FF),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (widget.discountAmount != null && widget.discountAmount! > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'payment_modal.savings'.tr(args: [
                                    widget.discountAmount!.toStringAsFixed(2),
                                    widget.voucherCode ?? 'payment_modal.voucher'.tr(),
                                  ]),
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Opsyen 1: DuitNow QR (Pantas & Zero Fee)
                      _buildPaymentOption(
                        isDark: isDark,
                        value: 'duitnow',
                        title: 'payment_modal.duitnow_title'.tr(),
                        subtitle: 'payment_modal.duitnow_subtitle'.tr(),
                        icon: HugeIcons.strokeRoundedQrCode,
                        badge: 'payment_modal.duitnow_badge'.tr(),
                        badgeColor: const Color(0xFFE91E63),
                      ),

                      const SizedBox(height: 10),

                      // Opsyen 2: FPX Online Banking & Kad
                      _buildPaymentOption(
                        isDark: isDark,
                        value: 'fpx_card',
                        title: 'payment_modal.fpx_title'.tr(),
                        subtitle: 'payment_modal.fpx_subtitle'.tr(),
                        icon: HugeIcons.strokeRoundedCreditCard,
                      ),

                      const SizedBox(height: 10),

                      // Opsyen 3: Bayar Tunai di Kaunter
                      _buildPaymentOption(
                        isDark: isDark,
                        value: 'cash',
                        title: 'payment_modal.cash_title'.tr(),
                        subtitle: 'payment_modal.cash_subtitle'.tr(),
                        icon: HugeIcons.strokeRoundedMoney01,
                      ),

                      const SizedBox(height: 22),

                      // Butang Teruskan
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _isLoadingQr
                              ? null
                              : () {
                                  if (_selectedMethod == 'cash') {
                                    _handleSuccessPayment('payment_modal.counter_cash_label'.tr(), 'CASH-${DateTime.now().millisecondsSinceEpoch}');
                                  } else {
                                    _startGatewayFlow();
                                  }
                                },
                          child: _isLoadingQr
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'payment_modal.proceed_payment'.tr(),
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(width: 8),
                                    const HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: Colors.black, size: 18),
                                  ],
                                ),
                        ),
                      ),
                    ],

                    // STEP 2: PAPARAN GERBANG CHIP ASIA / DUITNOW QR
                    if (_currentStep == PaymentStep.duitNowQr) ...[
                      Row(
                        children: [
                          IconButton(
                            icon: HugeIcon(
                              icon: HugeIcons.strokeRoundedCancel01,
                              color: isDark ? Colors.white : Colors.black,
                              size: 20,
                            ),
                            onPressed: () {
                              _statusTimer?.cancel();
                              _countdownTimer?.cancel();
                              Navigator.pop(context, false);
                            },
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedMethod == 'fpx_card'
                                      ? 'payment_modal.fpx_gateway_title'.tr()
                                      : 'payment_modal.scan_duitnow_title'.tr(),
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  widget.shopName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Countdown badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const HugeIcon(icon: HugeIcons.strokeRoundedTime02, color: Color(0xFF00E5FF), size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  '${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      if (_isLoadingQr)
                        _buildQrShimmer(isDark)
                      else if (_gatewayError != null)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            children: [
                              const HugeIcon(icon: HugeIcons.strokeRoundedAlert02, color: Colors.redAccent, size: 36),
                              const SizedBox(height: 12),
                              Text(
                                _gatewayError!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text('payment_modal.back_to_cart'.tr()),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF00E5FF),
                                        foregroundColor: Colors.black,
                                      ),
                                      onPressed: _startGatewayFlow,
                                      child: Text('payment_modal.try_again'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      else ...[
                        // Kotak DuitNow QR / Pautan CHIP Asia
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: (_selectedMethod == 'fpx_card')
                                    ? const Color(0xFF0F172A).withValues(alpha: 0.12)
                                    : const Color(0xFFED0058).withValues(alpha: 0.18),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Header Branding
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: _selectedMethod == 'fpx_card'
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFFED0058),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _selectedMethod == 'fpx_card' ? 'CHIP ASIA FPX / KAD' : 'DuitNow',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _selectedMethod == 'fpx_card'
                                          ? 'payment_modal.secure_checkout'.tr()
                                          : 'payment_modal.qr_interoperable'.tr(),
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 9,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              // Paparan QR Kod Asli dalam card berbingkai
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    width: 1.2,
                                  ),
                                ),
                                child: SizedBox(
                                  width: 196,
                                  height: 196,
                                  child: QrImageView(
                                    data: (_purchase?.duitNowUrl.isNotEmpty == true)
                                        ? _purchase!.duitNowUrl
                                        : (_purchase?.checkoutUrl.isNotEmpty == true
                                            ? _purchase!.checkoutUrl
                                            : 'https://gate.chip-in.asia'),
                                    version: QrVersions.auto,
                                    eyeStyle: QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: _selectedMethod == 'fpx_card'
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFFED0058),
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              Text(
                                currencyFormat.format(_purchase?.amount ?? widget.amount),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'payment_modal.waiting_realtime_conf'.tr(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.black45, fontSize: 11),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Butang Buka Halaman Pembayaran CHIP Asia (Utama untuk Web / Peranti Sama)
                        if (_purchase?.checkoutUrl.isNotEmpty == true) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00E5FF),
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () {
                                final uri = Uri.tryParse(_purchase!.checkoutUrl);
                                if (uri != null) {
                                  launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              icon: const HugeIcon(icon: HugeIcons.strokeRoundedLinkSquare01, color: Colors.black, size: 18),
                              label: Text(
                                _selectedMethod == 'fpx_card'
                                    ? 'payment_modal.reopen_fpx_gateway'.tr()
                                    : 'payment_modal.open_chip_gateway'.tr(),
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Butang Semak Status Bayaran (Disahkan dari Pelayan CHIP)
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _isVerifyingManual ? null : _verifyPaymentStatusNow,
                            icon: _isVerifyingManual
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, color: Colors.white, size: 18),
                            label: Text(
                              _isVerifyingManual
                                  ? 'payment_modal.checking_status'.tr()
                                  : 'payment_modal.i_have_paid'.tr(),
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Butang Batal / Kembali ke Troli
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: TextButton.icon(
                            onPressed: () {
                              _statusTimer?.cancel();
                              _countdownTimer?.cancel();
                              Navigator.pop(context, false);
                            },
                            icon: HugeIcon(
                              icon: HugeIcons.strokeRoundedArrowLeft01,
                              size: 15,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                            label: Text(
                              'payment_modal.cancel_and_return'.tr(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],

                    // STEP 3: RESIT DIGITAL LENGKAP (DIGITAL RECEIPT - GLASSMORPHISM)
                    if (_currentStep == PaymentStep.receipt) ...[
                      // Ikon Kejayaan Glassmorphic (Checkmark Circle 03)
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF10B981).withValues(alpha: 0.14),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.60),
                            width: 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.25),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedCheckmarkCircle03,
                            color: Color(0xFF10B981),
                            size: 36,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        _isCash ? 'payment_modal.order_placed'.tr() : 'payment_modal.payment_success'.tr(),
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _isCash
                              ? 'payment_modal.cash_success_desc'.tr()
                              : 'payment_modal.online_success_desc'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white.withValues(alpha: 0.65) : const Color(0xFF64748B),
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Kotak Resit Digital (Glass Container)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.08),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'payment_modal.order_number'.tr(),
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '#${widget.orderId.length > 8 ? widget.orderId.substring(0, 8).toUpperCase() : widget.orderId}',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Container(
                                height: 1.0,
                                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'payment_modal.store'.tr(),
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  widget.shopName,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Container(
                                height: 1.0,
                                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'payment_modal.payment_method'.tr(),
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _selectedMethod == 'duitnow'
                                      ? 'payment_modal.duitnow_qr_chip'.tr()
                                      : (_selectedMethod == 'fpx_card'
                                          ? 'payment_modal.fpx_card_chip'.tr()
                                          : 'payment_modal.cash_counter'.tr()),
                                  style: const TextStyle(
                                    color: Color(0xFF00E5FF),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Container(
                                height: 1.0,
                                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'payment_modal.transaction_ref'.tr(),
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _transactionRef.length > 12 ? _transactionRef.substring(0, 12) : _transactionRef,
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                            if (widget.discountAmount != null && widget.discountAmount! > 0) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Container(
                                  height: 1.0,
                                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const HugeIcon(icon: HugeIcons.strokeRoundedTicket01, color: Color(0xFF10B981), size: 14),
                                      const SizedBox(width: 6),
                                      Text(
                                        'payment_modal.voucher_discount'.tr(args: [widget.voucherCode != null ? "(${widget.voucherCode})" : ""]),
                                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 12.5, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '-RM ${widget.discountAmount!.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Container(
                                height: 1.0,
                                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _isCash ? 'payment_modal.amount_to_pay'.tr() : 'payment_modal.amount_paid'.tr(),
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  currencyFormat.format(widget.amount),
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // Butang Tindakan Resit (Glass Pills)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.16) : Colors.black.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () async {
                                    final receiptTitle = 'payment_modal.receipt_title'.tr();
                                    final receiptOrder = 'payment_modal.receipt_order'.tr();
                                    final receiptAmount = 'payment_modal.receipt_amount'.tr();
                                    final receiptRef = 'payment_modal.receipt_ref'.tr();
                                    final receiptStatus = 'payment_modal.receipt_status'.tr();
                                    final receiptDate = 'payment_modal.receipt_date'.tr();
                                    final statusStr = _isCash ? 'payment_modal.receipt_unpaid_cash'.tr() : 'payment_modal.receipt_paid'.tr();
                                    final thanksStr = 'payment_modal.receipt_thanks'.tr();
                                    final storeStr = 'payment_modal.store'.tr();

                                    final receiptStr = '''
========================================
         $receiptTitle          
========================================
$storeStr   : ${widget.shopName}
$receiptOrder : #${widget.orderId}
$receiptAmount  : ${currencyFormat.format(widget.amount)}
$receiptRef : $_transactionRef
$receiptStatus  : $statusStr
$receiptDate  : ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now())}
========================================
$thanksStr
''';
                                    Clipboard.setData(ClipboardData(text: receiptStr));
                                    try {
                                      await ReceiptPdfService.downloadReceiptPdf(
                                        orderId: widget.orderId,
                                        shopName: widget.shopName,
                                        customerName: widget.customerName,
                                        customerPhone: widget.customerPhone,
                                        orderCreatedAt: DateTime.now(),
                                        paymentTime: DateTime.now(),
                                        paymentMethod: _isCash ? 'Tunai di Kaunter' : (_selectedMethod ?? 'DuitNow QR'),
                                        paymentStatus: _isCash ? 'unpaid' : 'paid',
                                        items: widget.items,
                                        totalAmount: widget.amount,
                                        discount: widget.discountAmount ?? 0.0,
                                      );
                                      if (context.mounted) {
                                        showGlassToast(
                                          context,
                                          'order_status.receipt_download_success'.tr(),
                                          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                                        );
                                      }
                                    } catch (_) {
                                      await saveAndDownloadText(
                                        textContent: receiptStr,
                                        fileName: 'Resit_Ngam_${widget.orderId}.txt',
                                      );
                                      if (context.mounted) {
                                        showGlassToast(
                                          context,
                                          'payment_modal.receipt_copied'.tr(),
                                          icon: HugeIcons.strokeRoundedDownload01,
                                        );
                                      }
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        HugeIcon(
                                          icon: HugeIcons.strokeRoundedInvoice01,
                                          size: 16,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'order_status.action_download_pdf_receipt'.tr(),
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                                    blurRadius: 18,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => Navigator.pop(context, true),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    child: Center(
                                      child: Text(
                                        'payment_modal.done'.tr(),
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required bool isDark,
    required String value,
    required String title,
    required String subtitle,
    required dynamic icon,
    String? badge,
    Color? badgeColor,
  }) {
    final bool isSelected = _selectedMethod == value;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedMethod = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? (const Color(0xFF00E5FF).withValues(alpha: 0.08))
              : (isDark ? const Color(0xFF0F1318) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00E5FF)
                : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF00E5FF).withValues(alpha: 0.18)
                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: HugeIcon(
                  icon: icon,
                  color: isSelected ? const Color(0xFF00E5FF) : (isDark ? Colors.white70 : const Color(0xFF475569)),
                  size: 20,
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
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? const Color(0xFF00E5FF)).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: badgeColor ?? const Color(0xFF00E5FF),
                              fontWeight: FontWeight.w900,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF00E5FF) : (isDark ? Colors.white24 : Colors.black26),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E5FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
