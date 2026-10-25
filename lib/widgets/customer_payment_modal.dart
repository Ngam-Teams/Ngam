import 'dart:async';
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
    Future<void> Function(String method, String transactionRef)? onPaymentSuccess,
  }) async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomerPaymentModal(
        amount: amount,
        orderTitle: orderTitle,
        shopName: shopName,
        orderId: orderId,
        items: items,
        customerName: customerName,
        customerPhone: customerPhone,
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

    if (widget.onPaymentSuccess != null) {
      await widget.onPaymentSuccess!(method, _transactionRef);
    }
  }

  Future<void> _proceedToDuitNow() async {
    setState(() {
      _currentStep = PaymentStep.duitNowQr;
      _isLoadingQr = true;
    });

    final res = await ChipPaymentService.instance.createPurchase(
      amount: widget.amount,
      orderTitle: widget.orderTitle,
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
    }
  }

  Future<void> _proceedToFpxCard() async {
    setState(() => _isLoadingQr = true);
    final res = await ChipPaymentService.instance.createPurchase(
      amount: widget.amount,
      orderTitle: widget.orderTitle,
      clientName: widget.customerName,
      clientPhone: widget.customerPhone,
    );

    setState(() => _isLoadingQr = false);

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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141920) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black87 : Colors.black.withValues(alpha: 0.15),
                blurRadius: 28,
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
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Opsyen 1: DuitNow QR (Chip Asia)
                    _buildPaymentOption(
                      isDark: isDark,
                      value: 'duitnow',
                      title: 'DuitNow QR Pantas (Chip Asia)',
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

                      // Butang Ujian Simulasi / Pautan Web
                      Row(
                        children: [
                          if (_purchase?.checkoutUrl.isNotEmpty == true)
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () {
                                _statusTimer?.cancel();
                                _countdownTimer?.cancel();
                                _handleSuccessPayment('DuitNow QR (Simulasi Berjaya)', _purchase?.id ?? 'SIM-882');
                              },
                              icon: const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, size: 15, color: Colors.white),
                              label: const Text('Simulasi Berjaya', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],

                  // STEP 3: RESIT DIGITAL LENGKAP (DIGITAL RECEIPT)
                  if (_currentStep == PaymentStep.receipt) ...[
                    // Ikon Kejayaan
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF10B981), width: 2),
                      ),
                      child: const Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckmarkBadge01,
                          color: Color(0xFF10B981),
                          size: 34,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Bayaran Berjaya!',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Pesanan anda telah disahkan dan dihantar ke kedai.',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Kotak Resit Digital
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F141A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'No. Pesanan',
                                style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B), fontSize: 12),
                              ),
                              Text(
                                '#${widget.orderId.length > 8 ? widget.orderId.substring(0, 8).toUpperCase() : widget.orderId}',
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Kedai',
                                style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B), fontSize: 12),
                              ),
                              Text(
                                widget.shopName,
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Kaedah Bayaran',
                                style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B), fontSize: 12),
                              ),
                              Text(
                                _selectedMethod == 'duitnow'
                                    ? 'DuitNow QR (Chip)'
                                    : (_selectedMethod == 'fpx_card' ? 'FPX / Kad (Chip)' : 'Tunai Kaunter'),
                                style: const TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Rujukan Transaksi',
                                style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B), fontSize: 12),
                              ),
                              Text(
                                _transactionRef.length > 12 ? _transactionRef.substring(0, 12) : _transactionRef,
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                  fontSize: 11,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Jumlah Dibayar',
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                currencyFormat.format(widget.amount),
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Butang Tindakan Resit
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : Colors.black,
                              side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(
                                text: 'Resit Rasmi Ngam\nKedai: ${widget.shopName}\nOrder: #${widget.orderId}\nJumlah: ${currencyFormat.format(widget.amount)}\nRef: $_transactionRef\nStatus: LULUS BAYAR',
                              ));
                              showGlassToast(context, 'Butiran resit disalin ke papan klip!', icon: HugeIcons.strokeRoundedCopy01);
                            },
                            icon: const HugeIcon(icon: HugeIcons.strokeRoundedCopy01, size: 16),
                            label: const Text('Salin Resit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E5FF),
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Selesai', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
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
