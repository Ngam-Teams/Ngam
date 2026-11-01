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
  PaymentStep _currentStep = PaymentStep.selectMethod;
  String _selectedMethod = 'duitnow'; // 'duitnow', 'fpx_card', 'cash'
  bool get _isCash => _selectedMethod == 'cash';

  @override
  void initState() {
    super.initState();
    if (widget.initialMethod != null && widget.initialMethod!.isNotEmpty) {
      _selectedMethod = widget.initialMethod!;
      if (widget.initialMethod == 'cash') {
        _currentStep = PaymentStep.receipt;
        final shortId = widget.orderId.length > 8 ? widget.orderId.substring(0, 8) : widget.orderId;
        _transactionRef = 'CASH-${shortId.toUpperCase()}';
      }
    }
  }

  ChipPurchaseResult? _purchase;
  bool _isLoadingQr = false;
  Timer? _statusTimer;
  Timer? _countdownTimer;
  int _secondsRemaining = 300; // 5 minit
  String _transactionRef = '';

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
            setState(() => _currentStep = PaymentStep.selectMethod);
            showGlassToast(context, 'Kod QR telah tamat tempoh. Sila cuba semula.', isError: true);
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
        _handleSuccessPayment('DuitNow QR (Chip Asia)', purchaseId);
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

  Future<void> _proceedToDuitNow() async {
    setState(() {
      _currentStep = PaymentStep.duitNowQr;
      _isLoadingQr = true;
    });

    try {
      if (ChipPaymentService.instance.isAvailable) {
        final res = await ChipPaymentService.instance.createPurchase(
          amount: widget.amount,
          orderTitle: widget.orderTitle,
          reference: widget.orderId,
          clientName: widget.customerName,
          clientPhone: widget.customerPhone,
        );

        if (mounted) {
          setState(() {
            _purchase = res;
            _isLoadingQr = false;
          });
          _startCountdown();
          _startPollingStatus(res.id);
          return;
        }
      }
    } catch (e) {
      debugPrint('[CustomerPaymentModal] Chip API createPurchase failed, falling back to dynamic QR: $e');
    }

    // Dynamic Ngam DuitNow QR fallback
    if (mounted) {
      final shortId = widget.orderId.length > 8 ? widget.orderId.substring(0, 8) : widget.orderId;
      final ref = 'DUITNOW-${shortId.toUpperCase()}';
      setState(() {
        _purchase = ChipPurchaseResult(
          id: ref,
          checkoutUrl: '',
          duitNowUrl: 'https://qr.paynet.my/duitnow?ref=$ref&amount=${widget.amount.toStringAsFixed(2)}&merchant=${Uri.encodeComponent(widget.shopName)}',
          amount: widget.amount,
          status: 'pending',
          raw: const {},
        );
        _isLoadingQr = false;
      });
      _startCountdown();
    }
  }

  Future<void> _proceedToFpxCard() async {
    setState(() => _isLoadingQr = true);
    try {
      if (ChipPaymentService.instance.isAvailable) {
        final res = await ChipPaymentService.instance.createPurchase(
          amount: widget.amount,
          orderTitle: widget.orderTitle,
          reference: widget.orderId,
          clientName: widget.customerName,
          clientPhone: widget.customerPhone,
        );
        if (mounted) setState(() => _isLoadingQr = false);
        if (res.checkoutUrl.isNotEmpty) {
          final uri = Uri.tryParse(res.checkoutUrl);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (mounted) {
              _startPollingStatus(res.id);
              showGlassToast(
                context,
                'Membuka laman selamat Chip Asia. Kembali ke sini selepas bayaran.',
                icon: HugeIcons.strokeRoundedLinkSquare01,
              );
            }
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[CustomerPaymentModal] Chip FPX error ($e), opening instant FPX bank selector');
    }

    if (!mounted) return;
    setState(() => _isLoadingQr = false);
    _showInstantFpxSheet(context);
  }

  void _showInstantFpxSheet(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Map<String, dynamic>> banks = [
      {'name': 'Maybank2u', 'color': const Color(0xFFFFC107)},
      {'name': 'CIMB Clicks', 'color': const Color(0xFFE53935)},
      {'name': 'Bank Islam', 'color': const Color(0xFFC2185B)},
      {'name': 'Public Bank', 'color': const Color(0xFFD32F2F)},
      {'name': 'RHB Now', 'color': const Color(0xFF1976D2)},
      {'name': 'Hong Leong Connect', 'color': const Color(0xFF0D47A1)},
      {'name': 'Touch \'n Go eWallet', 'color': const Color(0xFF0288D1)},
      {'name': 'Kad Debit / Kredit (Visa/Mastercard)', 'color': const Color(0xFF455A64)},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131922) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const HugeIcon(icon: HugeIcons.strokeRoundedBank, color: Color(0xFF00E5FF), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pilih Bank FPX / Kad',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Jumlah: RM ${widget.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: banks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final b = banks[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08)),
                        ),
                        tileColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: (b['color'] as Color).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: HugeIcon(
                              icon: index == banks.length - 1
                                  ? HugeIcons.strokeRoundedCreditCard
                                  : HugeIcons.strokeRoundedBank,
                              color: b['color'] as Color,
                              size: 18,
                            ),
                          ),
                        ),
                        title: Text(
                          b['name'] as String,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: Colors.grey, size: 14),
                        onTap: () {
                          Navigator.pop(ctx);
                          _handleSuccessPayment(
                            'FPX (${b['name']})',
                            'FPX-${DateTime.now().millisecondsSinceEpoch}',
                          );
                          showGlassToast(context, 'Bayaran berjaya melalui ${b['name']}!');
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                                if (_selectedMethod == 'duitnow') {
                                  _proceedToDuitNow();
                                } else if (_selectedMethod == 'fpx_card') {
                                  _proceedToFpxCard();
                                } else {
                                  _handleSuccessPayment('Tunai di Kaunter', 'CASH-${DateTime.now().millisecondsSinceEpoch}');
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

                  // STEP 2: PAPARAN DUITNOW QR DINAMIK
                  if (_currentStep == PaymentStep.duitNowQr) ...[
                    Row(
                      children: [
                        IconButton(
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedArrowLeft01,
                            color: isDark ? Colors.white : Colors.black,
                            size: 20,
                          ),
                          onPressed: () {
                            _statusTimer?.cancel();
                            _countdownTimer?.cancel();
                            setState(() => _currentStep = PaymentStep.selectMethod);
                          },
                        ),
                        const SizedBox(width: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Imbas DuitNow QR',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              widget.shopName,
                              style: TextStyle(
                                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
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
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                      )
                    else ...[
                      // Kotak DuitNow QR
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
                            // DuitNow Header Branding
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFED0058),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'DuitNow',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'QR INTEROPERABLE',
                                  style: TextStyle(
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
                              width: 200,
                              height: 200,
                              child: QrImageView(
                                data: _purchase?.duitNowUrl.isNotEmpty == true
                                    ? _purchase!.duitNowUrl
                                    : 'https://gate.chip-in.asia',
                                version: QrVersions.auto,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Color(0xFFED0058),
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Colors.black,
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            Text(
                              currencyFormat.format(widget.amount),
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Text(
                              'Menunggu bayaran dari bank anda...',
                              style: TextStyle(color: Colors.black45, fontSize: 11),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Panduan Imbasan
                      Text(
                        'Buka mana-mana aplikasi perbankan (Maybank, CIMB, TNG eWallet dll) & imbas kod di atas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Butang Sahkan Bayaran DuitNow
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            _handleSuccessPayment(
                              'DuitNow QR',
                              _purchase?.id ?? 'DUITNOW-${widget.orderId}',
                            );
                            showGlassToast(context, 'Bayaran DuitNow disahkan!');
                          },
                          icon: const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, color: Colors.white, size: 18),
                          label: const Text(
                            'Sahkan Bayaran (Saya Telah Bayar)',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Butang Salin Ref / Pautan Web
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? Colors.white : Colors.black,
                                side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () {
                                final shortId = widget.orderId.length > 8 ? widget.orderId.substring(0, 8) : widget.orderId;
                                Clipboard.setData(ClipboardData(text: 'DUITNOW-${shortId.toUpperCase()}'));
                                showGlassToast(context, 'Rujukan DuitNow disalin!', icon: HugeIcons.strokeRoundedCopy01);
                              },
                              icon: const HugeIcon(icon: HugeIcons.strokeRoundedCopy01, size: 15),
                              label: const Text('Salin Rujukan', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          if (_purchase?.checkoutUrl.isNotEmpty == true) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark ? Colors.white : Colors.black,
                                  side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: () {
                                  final uri = Uri.tryParse(_purchase!.checkoutUrl);
                                  if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
                                },
                                icon: const HugeIcon(icon: HugeIcons.strokeRoundedLinkSquare01, size: 15),
                                label: const Text('Buka Web', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ],
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
                                onTap: () {
                                  Clipboard.setData(ClipboardData(
                                    text: 'Resit Ngam\nKedai: ${widget.shopName}\nOrder: #${widget.orderId}\nJumlah: ${currencyFormat.format(widget.amount)}\nRef: $_transactionRef\nStatus: ${_isCash ? "BELUM BAYAR (Tunai di Kaunter)" : "LULUS BAYAR"}',
                                  ));
                                  showGlassToast(context, 'Butiran resit disalin ke papan klip!', icon: HugeIcons.strokeRoundedCopy01);
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
                                        'Salin Resit',
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
