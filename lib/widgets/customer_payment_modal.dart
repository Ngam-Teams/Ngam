import '../utils/file_saver/file_saver.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/chip_payment_service.dart';
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
      // Terus ke skrin Gerbang Pembayaran tanpa tanya kaedah bayaran buat kali kedua!
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
            showGlassToast(context, 'Sesi pembayaran telah tamat tempoh. Sila cuba semula.', isError: true);
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

      // Jika pelanggan memilih Perbankan FPX / Kad (atau tiada payload QR langsung), terus buka pautan selamat CHIP Asia
      if ((_selectedMethod == 'fpx_card' || !res.hasDirectQrPayload) && res.checkoutUrl.isNotEmpty) {
        final uri = Uri.tryParse(res.checkoutUrl);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (mounted) {
            showGlassToast(
              context,
              'Membuka gerbang selamat CHIP Asia. Selesaikan bayaran untuk pengesahan automatik.',
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
        showGlassToast(context, 'Bayaran disahkan oleh gerbang CHIP Asia!');
      } else {
        showGlassToast(
          context,
          'Bayaran belum diterima daripada bank anda. Sila lengkapkan bayaran terlebih dahulu.',
          isError: true,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isVerifyingManual = false);
      showGlassToast(context, 'Gagal menyemak status bayaran. Sila cuba lagi.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

    return PopScope(
      canPop: _currentStep != PaymentStep.receipt,
      child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF10151E).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.90),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.08),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                    blurRadius: 32,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
          child: SafeArea(
            child: SingleChildScrollView(
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
                              'Pilih Kaedah Bayaran',
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
                                'Jimat RM ${widget.discountAmount!.toStringAsFixed(2)} (${widget.voucherCode ?? 'Baucar'})',
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
                      title: 'DuitNow QR Pantas (Zero Fee)',
                      subtitle: 'Imbas terus guna sebarang aplikasi Bank atau e-Wallet (TNG, GrabPay, ShopeePay)',
                      icon: HugeIcons.strokeRoundedQrCode,
                      badge: 'DISYORKAN',
                      badgeColor: const Color(0xFFE91E63),
                    ),

                    const SizedBox(height: 10),

                    // Opsyen 2: FPX Online Banking & Kad
                    _buildPaymentOption(
                      isDark: isDark,
                      value: 'fpx_card',
                      title: 'Perbankan FPX & Kad Debit / Kredit',
                      subtitle: 'Maybank2u, CIMB Clicks, Bank Islam, Visa & Mastercard',
                      icon: HugeIcons.strokeRoundedCreditCard,
                    ),

                    const SizedBox(height: 10),

                    // Opsyen 3: Bayar Tunai di Kaunter
                    _buildPaymentOption(
                      isDark: isDark,
                      value: 'cash',
                      title: 'Bayar di Kaunter (Tunai)',
                      subtitle: 'Buat bayaran secara fizikal terus kepada staf kedai',
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
                                  _handleSuccessPayment('Tunai di Kaunter', 'CASH-${DateTime.now().millisecondsSinceEpoch}');
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
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Teruskan Pembayaran',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                                  ),
                                  SizedBox(width: 8),
                                  HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: Colors.black, size: 18),
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
                                    ? 'Gerbang FPX & Kad (CHIP Asia)'
                                    : 'Imbas DuitNow QR (CHIP Asia)',
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
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 44),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(color: Color(0xFF00E5FF)),
                            const SizedBox(height: 16),
                            Text(
                              'Menyediakan sesi pembayaran selamat CHIP Asia...',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
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
                                    child: const Text('Kembali ke Troli'),
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
                                    child: const Text('Cuba Semula', style: TextStyle(fontWeight: FontWeight.bold)),
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
                              color: const Color(0xFFE91E63).withValues(alpha: 0.2),
                              blurRadius: 24,
                              offset: const Offset(0, 6),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
                                Text(
                                  _selectedMethod == 'fpx_card' ? 'SECURE CHECKOUT' : 'QR INTEROPERABLE',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // Paparan QR Kod Asli
                            SizedBox(
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

                            const SizedBox(height: 10),

                            Text(
                              currencyFormat.format(_purchase?.amount ?? widget.amount),
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Text(
                              'Menunggu pengesahan bayaran masa-nyata daripada CHIP Asia...',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black45, fontSize: 11),
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
                                  ? 'Buka Semula Gerbang FPX / Kad CHIP'
                                  : 'Bayar Terus di Halaman CHIP Asia',
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
                                ? 'Menyemak Status di CHIP Asia...'
                                : 'Saya Telah Bayar (Semak Status)',
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
                            'Batal & Kembali ke Troli / Tukar Kaedah Bayaran',
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
                      _isCash ? 'Pesanan Diterima!' : 'Bayaran Berjaya!',
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
                            ? 'Pesanan anda telah dihantar ke kedai. Sila bayar di kaunter semasa mengambil pesanan.'
                            : 'Pesanan anda telah disahkan dan dihantar ke kedai.',
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
                                'No. Pesanan',
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
                                'Kedai',
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
                                'Kaedah Bayaran',
                                style: TextStyle(
                                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _selectedMethod == 'duitnow'
                                    ? 'DuitNow QR (Chip)'
                                    : (_selectedMethod == 'fpx_card' ? 'FPX / Kad (Chip)' : 'Tunai Kaunter'),
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
                                'Rujukan Transaksi',
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
                                      'Diskaun Baucar ${widget.voucherCode != null ? "(${widget.voucherCode})" : ""}',
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
                                _isCash ? 'Jumlah Perlu Dibayar' : 'Jumlah Dibayar',
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
                                  final receiptStr = '''
========================================
         RESIT PEMBAYARAN NGAM          
========================================
Kedai   : ${widget.shopName}
Pesanan : #${widget.orderId}
Jumlah  : ${currencyFormat.format(widget.amount)}
Rujukan : $_transactionRef
Status  : ${_isCash ? "BELUM BAYAR (Tunai di Kaunter)" : "LULUS BAYAR"}
Tarikh  : ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now())}
========================================
Terima kasih atas pesanan anda!
''';
                                  Clipboard.setData(ClipboardData(text: receiptStr));
                                  await saveAndDownloadText(
                                    textContent: receiptStr,
                                    fileName: 'Resit_Ngam_${widget.orderId}.txt',
                                  );
                                  if (context.mounted) {
                                    showGlassToast(context, 'Resit digital berjaya disalin & dimuat turun!', icon: HugeIcons.strokeRoundedDownload01);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      HugeIcon(
                                        icon: HugeIcons.strokeRoundedCopy01,
                                        size: 16,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Muat Turun & Salin',
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
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Center(
                                    child: Text(
                                      'Selesai',
                                      style: TextStyle(
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
                    ),                  ],
                ],
              ),
            ),
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
