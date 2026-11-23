import '../utils/file_saver/file_saver.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'glass_box.dart';
import '../services/chip_payment_service.dart';
import '../services/receipt_pdf_service.dart';
import 'glass_toast.dart';

enum PaymentStep { selectMethod, duitNowQr, receipt }

// =============================================================================
// CustomerPaymentModal
// Menggunakan gaya GlassConfirmDialog (Logout Popup Style):
// - Dialog terapung berpusat (Center Dialog) dengan Liquid Glass container
// - Pill action buttons dengan gradient bercahaya & frosted glass
// - Sifar hardcoded text (100% l10n via .tr())
// =============================================================================

class CustomerPaymentModal extends StatefulWidget {
  final double amount;
  final String orderTitle;
  final String shopName;
  final String orderId;
  final List<Map<String, dynamic>> items;
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? voucherCode;
  final double? discountAmount;
  final String? initialMethod;
  final bool startAtMethodSelect;
  final Future<void> Function(String method, String transactionRef)? onPaymentSuccess;

  const CustomerPaymentModal({
    super.key,
    required this.amount,
    required this.orderTitle,
    required this.shopName,
    required this.orderId,
    this.items = const [],
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.voucherCode,
    this.discountAmount,
    this.initialMethod,
    this.startAtMethodSelect = false,
    this.onPaymentSuccess,
  });

  static bool _isModalOpen = false;

  static Future<bool> show({
    required BuildContext context,
    required double amount,
    required String orderTitle,
    required String shopName,
    required String orderId,
    List<Map<String, dynamic>> items = const [],
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    String? voucherCode,
    double? discountAmount,
    String? initialMethod,
    bool startAtMethodSelect = false,
    Future<void> Function(String method, String transactionRef)? onPaymentSuccess,
  }) async {
    if (_isModalOpen) return false;
    _isModalOpen = true;
    try {
      final res = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        barrierDismissible: false,
        builder: (ctx) => CustomerPaymentModal(
          amount: amount,
          orderTitle: orderTitle,
          shopName: shopName,
          orderId: orderId,
          items: items,
          customerName: customerName,
          customerEmail: customerEmail,
          customerPhone: customerPhone,
          voucherCode: voucherCode,
          discountAmount: discountAmount,
          initialMethod: initialMethod,
          startAtMethodSelect: startAtMethodSelect,
          onPaymentSuccess: onPaymentSuccess,
        ),
      );
      return res ?? false;
    } finally {
      _isModalOpen = false;
    }
  }

  @override
  State<CustomerPaymentModal> createState() => _CustomerPaymentModalState();
}

class _CustomerPaymentModalState extends State<CustomerPaymentModal>
    with WidgetsBindingObserver {
  PaymentStep _currentStep = PaymentStep.duitNowQr;
  String _selectedMethod = 'duitnow'; // 'duitnow', 'fpx_card', 'cash'
  bool get _isCash => _selectedMethod == 'cash';

  ChipPurchaseResult? _purchase;
  bool _isLoadingQr = true;
  bool _isCreatingPurchase = false;
  bool _isCheckingStatus = false;
  bool _isVerifyingManual = false;
  bool _isCancelling = false;
  bool _isSavingQr = false;
  bool _hasHandledSuccess = false;
  final GlobalKey _qrCardBoundaryKey = GlobalKey();
  String? _gatewayError;
  Timer? _statusTimer;
  Timer? _countdownTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _orderStreamSub;
  int _secondsRemaining = 300; // 5 minit
  String _transactionRef = '';

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  String get _methodLabel => _selectedMethod == 'fpx_card'
      ? 'FPX / Kad (CHIP Asia)'
      : 'DuitNow QR (CHIP Asia)';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initMethod = (widget.initialMethod ?? 'duitnow').trim().toLowerCase();
    if (initMethod.contains('fpx') || initMethod.contains('card') || initMethod.contains('kad')) {
      _selectedMethod = widget.amount >= 10.0 ? 'fpx_card' : 'duitnow';
    } else if (initMethod.contains('cash') || initMethod.contains('tunai')) {
      _selectedMethod = 'cash';
    } else {
      _selectedMethod = 'duitnow';
    }

    if (widget.startAtMethodSelect) {
      _isLoadingQr = false;
      _currentStep = PaymentStep.selectMethod;
      _listenOrderPaymentStatus();
    } else if (_selectedMethod == 'cash') {
      _isLoadingQr = false;
      _currentStep = PaymentStep.receipt;
      final shortId = widget.orderId.length > 8 ? widget.orderId.substring(0, 8) : widget.orderId;
      _transactionRef = 'CASH-${shortId.toUpperCase()}';
    } else {
      _currentStep = PaymentStep.duitNowQr;
      _isLoadingQr = true;
      _listenOrderPaymentStatus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startGatewayFlow();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    _countdownTimer?.cancel();
    _orderStreamSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Apabila pengguna kembali dari tab pelayar CHIP Asia / aplikasi bank,
    // semak status bayaran serta-merta tanpa menunggu timer latar belakang.
    if (state == AppLifecycleState.resumed &&
        mounted &&
        !_hasHandledSuccess &&
        !_isCancelling &&
        _currentStep == PaymentStep.duitNowQr) {
      _pollStatusOnce();
    }
  }

  void _listenOrderPaymentStatus() {
    final oid = widget.orderId.trim();
    if (!_uuidPattern.hasMatch(oid)) return;
    try {
      _orderStreamSub?.cancel();
      _orderStreamSub = Supabase.instance.client
          .from('orders')
          .stream(primaryKey: ['id'])
          .eq('id', oid)
          .listen((rows) {
        if (!mounted || _hasHandledSuccess || rows.isEmpty) return;
        final row = rows.first;
        final payStatus = row['payment_status']?.toString().toLowerCase() ?? '';
        if (payStatus == 'paid') {
          final ref = row['chip_purchase_id']?.toString() ?? _purchase?.id ?? oid;
          _handleSuccessPayment(_methodLabel, ref);
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  Future<bool> _isOrderAlreadyPaidInDb() async {
    final oid = widget.orderId.trim();
    if (oid.isEmpty) return false;
    try {
      if (_uuidPattern.hasMatch(oid)) {
        final row = await Supabase.instance.client
            .from('orders')
            .select('payment_status')
            .eq('id', oid)
            .maybeSingle();
        if (row?['payment_status']?.toString().toLowerCase() == 'paid') {
          return true;
        }
      } else {
        final row = await Supabase.instance.client
            .from('bookings')
            .select('booking_metadata')
            .or('booking_metadata->>short_ref.eq.$oid,booking_metadata->>booking_id.eq.$oid')
            .maybeSingle();
        final meta = row?['booking_metadata'];
        if (meta is Map &&
            meta['payment_status']?.toString().toLowerCase() == 'paid') {
          return true;
        }
      }
    } catch (_) {}
    return false;
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
          if (_currentStep == PaymentStep.duitNowQr && !_hasHandledSuccess) {
            _handleSafeCancel(isExpired: true);
          }
        }
      }
    });
  }

  Future<void> _pollStatusOnce() async {
    final purchaseId = _purchase?.id ?? '';
    if (purchaseId.isEmpty || _isCheckingStatus || _hasHandledSuccess || !mounted) {
      return;
    }
    _isCheckingStatus = true;
    try {
      final status = await ChipPaymentService.instance.checkPurchaseStatus(purchaseId);
      if (!mounted || _hasHandledSuccess) return;
      if (status == 'paid') {
        _handleSuccessPayment(_methodLabel, purchaseId);
      }
    } finally {
      _isCheckingStatus = false;
    }
  }

  void _startPollingStatus(String purchaseId) {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) async {
      if (!mounted || _hasHandledSuccess) {
        timer.cancel();
        return;
      }
      await _pollStatusOnce();
    });
  }

  Future<void> _handleSuccessPayment(String method, String ref) async {
    if (_hasHandledSuccess) return;
    _hasHandledSuccess = true;
    _statusTimer?.cancel();
    _countdownTimer?.cancel();
    _orderStreamSub?.cancel();

    HapticFeedback.heavyImpact();
    if (mounted) {
      setState(() {
        _isCancelling = false;
        _isVerifyingManual = false;
        _isLoadingQr = false;
        _transactionRef = ref.isNotEmpty ? ref : 'CHIP-${DateTime.now().millisecondsSinceEpoch}';
        _currentStep = PaymentStep.receipt;
      });
    }

    if (widget.onPaymentSuccess != null) {
      await widget.onPaymentSuccess!(method, _transactionRef);
    }
  }

  /// Pembatalan selamat:
  /// 1. Semak status sebenar di CHIP Asia & Supabase dahulu.
  /// 2. Jika bayaran SUDAH berjaya, JANGAN batal — terus paparkan resit!
  /// 3. Jika belum bayar, batalkan purchase di pelayan CHIP supaya tab/QR lama tidak lagi boleh dibayar.
  Future<void> _handleSafeCancel({bool isExpired = false}) async {
    if (_isCancelling || _hasHandledSuccess) return;
    _statusTimer?.cancel();
    _countdownTimer?.cancel();

    final purchaseId = _purchase?.id ?? '';
    if (mounted) {
      setState(() => _isCancelling = true);
    }

    try {
      // Semak CHIP dahulu dan batalkan sesi di pelayan CHIP jika belum dibayar
      if (purchaseId.isNotEmpty) {
        final cancelRes = await ChipPaymentService.instance.cancelPurchase(
          purchaseId,
          orderId: widget.orderId,
        );
        if (!mounted || _hasHandledSuccess) return;
        if (cancelRes == 'paid') {
          await _handleSuccessPayment(_methodLabel, purchaseId);
          if (mounted) {
            showGlassToast(context, 'payment_modal.already_paid_detected'.tr());
          }
          return;
        }
      }

      // Semak juga status di Supabase (sekiranya webhook baru sahaja mengesahkan bayaran)
      final paidInDb = await _isOrderAlreadyPaidInDb();
      if (!mounted || _hasHandledSuccess) return;
      if (paidInDb) {
        await _handleSuccessPayment(_methodLabel, purchaseId.isNotEmpty ? purchaseId : widget.orderId);
        if (mounted) {
          showGlassToast(context, 'payment_modal.already_paid_detected'.tr());
        }
        return;
      }

      if (mounted) {
        if (isExpired) {
          showGlassToast(context, 'payment_modal.session_expired'.tr(), isError: true);
        }
        Navigator.pop(context, false);
      }
    } finally {
      if (mounted && !_hasHandledSuccess) {
        setState(() => _isCancelling = false);
      }
    }
  }

  Future<void> _startGatewayFlow() async {
    if (_isCreatingPurchase || _hasHandledSuccess) return;
    _isCreatingPurchase = true;
    setState(() {
      _currentStep = PaymentStep.duitNowQr;
      _isLoadingQr = true;
      _gatewayError = null;
    });

    try {
      final resolvedEmail =
          (widget.customerEmail != null && widget.customerEmail!.trim().isNotEmpty)
              ? widget.customerEmail!.trim()
              : Supabase.instance.client.auth.currentUser?.email;

      final res = await ChipPaymentService.instance.createPurchase(
        amount: widget.amount,
        orderTitle: widget.orderTitle,
        reference: widget.orderId,
        clientName: widget.customerName,
        clientEmail: resolvedEmail,
        clientPhone: widget.customerPhone,
        paymentMethodWhitelist: _selectedMethod == 'duitnow' ? const ['duitnow_qr'] : null,
      );

      if (!mounted) return;
      if (res.isPaid) {
        _purchase = res;
        await _handleSuccessPayment(_methodLabel, res.id);
        if (mounted) {
          showGlassToast(context, 'payment_modal.already_paid_detected'.tr());
        }
        return;
      }

      setState(() {
        _purchase = res;
        _isLoadingQr = false;
      });
      _startCountdown();
      _startPollingStatus(res.id);

      // Hanya buka gerbang CHIP secara automatik untuk FPX / Kad:
      // - Di Android/iOS: buka dalam In-App Browser (Chrome Custom Tabs / SFSafariViewController) di dalam Ngam.
      // - Di Web/PWA: buka dalam tab yang sama (_self) seperti Shopee / TikTok Shop supaya tiada 2 tab bertindih.
      if (_selectedMethod == 'fpx_card' && res.checkoutUrl.isNotEmpty) {
        if (mounted) {
          showGlassToast(
            context,
            'payment_modal.opening_chip_gateway'.tr(),
            icon: HugeIcons.strokeRoundedLinkSquare01,
          );
        }
        await _launchChipGatewayUrl(res.checkoutUrl);
      }
    } catch (e) {
      debugPrint('[CustomerPaymentModal] CHIP createPurchase error: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingQr = false;
        _gatewayError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      _isCreatingPurchase = false;
    }
  }

  /// Buka halaman gerbang CHIP Asia mengikut gaya Shopee / TikTok Shop:
  /// - Android / iOS: In-App Browser (`LaunchMode.inAppBrowserView`) terus di dalam aplikasi Ngam.
  /// - Web / PWA (`ngam.dev`): Same-Tab Redirect (`_self`) supaya tidak membuka tab kedua yang mengelirukan.
  Future<void> _launchChipGatewayUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return;

    try {
      if (kIsWeb) {
        await launchUrl(
          uri,
          webOnlyWindowName: '_self',
        );
        return;
      }

      final openedInApp = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
        browserConfiguration: const BrowserConfiguration(showTitle: true),
      );
      if (!openedInApp) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: kIsWeb ? '_self' : null,
      );
    }
  }

  /// Simpan / muat turun kad DuitNow QR sebagai gambar PNG resolusi tinggi
  /// supaya pengguna boleh terus muat naik dari galeri dalam aplikasi bank / e-Dompet (MAE, TNG, CIMB, GrabPay).
  Future<void> _saveQrCodeImage() async {
    if (_isSavingQr || _isCancelling) return;
    setState(() => _isSavingQr = true);
    HapticFeedback.lightImpact();

    try {
      Uint8List? pngBytes;

      // 1. Tangkap kad DuitNow QR penuh melalui RepaintBoundary
      try {
        final boundary = _qrCardBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            pngBytes = byteData.buffer.asUint8List();
          }
        }
      } catch (_) {}

      // 2. Fallback: Jana gambar QR terus melalui QrPainter jika RepaintBoundary tidak tersedia
      if (pngBytes == null) {
        final qrData = (_purchase?.duitNowUrl.isNotEmpty == true)
            ? _purchase!.duitNowUrl
            : (_purchase?.checkoutUrl.isNotEmpty == true
                ? _purchase!.checkoutUrl
                : 'https://gate.chip-in.asia');
        final painter = QrPainter(
          data: qrData,
          version: QrVersions.auto,
          gapless: true,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Color(0xFFED0058),
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Colors.black,
          ),
        );
        final picData = await painter.toImageData(600, format: ui.ImageByteFormat.png);
        if (picData != null) {
          pngBytes = picData.buffer.asUint8List();
        }
      }

      if (pngBytes == null) {
        throw Exception('QR PNG bytes null');
      }

      final shortId = widget.orderId.length > 8
          ? widget.orderId.substring(0, 8).toUpperCase()
          : widget.orderId.toUpperCase();
      await saveAndDownloadFile(
        bytes: pngBytes,
        fileName: 'DuitNow_QR_Ngam_$shortId.png',
        mimeType: 'image/png',
      );

      if (mounted) {
        showGlassToast(
          context,
          'payment_modal.qr_saved_toast'.tr(),
          icon: HugeIcons.strokeRoundedDownload04,
        );
      }
    } catch (e) {
      debugPrint('[CustomerPaymentModal] Save QR image error: $e');
      if (mounted) {
        showGlassToast(
          context,
          'payment_modal.qr_save_failed'.tr(),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingQr = false);
      }
    }
  }

  Future<void> _verifyPaymentStatusNow() async {
    final purchaseId = _purchase?.id ?? '';
    if (purchaseId.isEmpty || _isVerifyingManual || _isCancelling || _hasHandledSuccess) return;

    setState(() => _isVerifyingManual = true);
    HapticFeedback.mediumImpact();
    try {
      final status = await ChipPaymentService.instance.checkPurchaseStatus(purchaseId);
      final paidInDb = status == 'paid' ? true : await _isOrderAlreadyPaidInDb();
      if (!mounted || _hasHandledSuccess) return;
      setState(() => _isVerifyingManual = false);

      if (status == 'paid' || paidInDb) {
        await _handleSuccessPayment(_methodLabel, purchaseId);
        if (mounted) {
          showGlassToast(context, 'payment_modal.payment_verified'.tr());
        }
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
        Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161F2E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                width: 1.0,
              ),
            ),
            child: Column(
              children: [
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
                Container(
                  width: 130,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

    final frostedGlow = [
      Shadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 8),
      Shadow(
        color: Colors.black.withValues(alpha: 0.2),
        offset: const Offset(0.5, 0.5),
        blurRadius: 0,
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentStep == PaymentStep.receipt) return;
        if (_currentStep == PaymentStep.duitNowQr && _gatewayError == null) {
          _handleSafeCancel();
        } else {
          Navigator.pop(context, false);
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: GlassContainer(
              useOwnLayer: true,
              quality: GlassQuality.standard,
              shape: const LiquidRoundedSuperellipse(borderRadius: 24.0),
              settings: LiquidGlassSettings(
                thickness: 0.1,
                blur: 16.0,
                glassColor: Colors.transparent,
                lightAngle: 45.0,
                lightIntensity: 0.1,
                ambientStrength: 1.0,
                saturation: 1.0,
                chromaticAberration: 0.0,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.28)
                      : Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.45),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // =======================================================
                      // STEP 1: PILIH KAEDAH BAYARAN
                      // =======================================================
                      if (_currentStep == PaymentStep.selectMethod) ...[
                        Row(
                          children: [
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedCreditCard,
                              color: Color(0xFF00E5FF),
                              size: 22,
                              strokeWidth: 2.2,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'payment_modal.choose_method'.tr(),
                                    style: TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                                      shadows: isDark ? frostedGlow : [],
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  Text(
                                    widget.shopName,
                                    style: TextStyle(
                                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
                              ),
                              child: Text(
                                currencyFormat.format(widget.amount),
                                style: const TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (widget.discountAmount != null && widget.discountAmount! > 0) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'payment_modal.savings'.tr(args: [
                                widget.discountAmount!.toStringAsFixed(2),
                                widget.voucherCode ?? 'payment_modal.voucher'.tr(),
                              ]),
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Opsyen 1: DuitNow QR
                        _buildPaymentOption(
                          isDark: isDark,
                          value: 'duitnow',
                          title: 'payment_modal.duitnow_title'.tr(),
                          subtitle: 'payment_modal.duitnow_subtitle'.tr(),
                          icon: HugeIcons.strokeRoundedQrCode,
                          badge: 'payment_modal.duitnow_badge'.tr(),
                          badgeColor: const Color(0xFFE91E63),
                        ),

                        const SizedBox(height: 8),

                        // Opsyen 2: FPX Online Banking & Kad (Had Minima RM 10.00 selepas diskaun/baucar)
                        _buildPaymentOption(
                          isDark: isDark,
                          value: 'fpx_card',
                          title: 'payment_modal.fpx_title'.tr(),
                          subtitle: widget.amount >= 10.0
                              ? 'payment_modal.fpx_subtitle'.tr()
                              : 'cart.fpx_min_spend_subtitle'.tr(),
                          icon: HugeIcons.strokeRoundedCreditCard,
                          badge: widget.amount >= 10.0 ? null : 'cart.fpx_min_spend_badge'.tr(),
                          badgeColor: Colors.amber.shade800,
                          isEnabled: widget.amount >= 10.0,
                        ),

                        const SizedBox(height: 8),

                        // Opsyen 3: Bayar Tunai di Kaunter
                        _buildPaymentOption(
                          isDark: isDark,
                          value: 'cash',
                          title: 'payment_modal.cash_title'.tr(),
                          subtitle: 'payment_modal.cash_subtitle'.tr(),
                          icon: HugeIcons.strokeRoundedMoney01,
                        ),

                        const SizedBox(height: 18),

                        // Butang Tindakan (Logout Popup Pill Style)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildPillButton(
                              label: 'payment_modal.cancel'.tr(),
                              onTap: () => Navigator.pop(context, false),
                              isDark: isDark,
                              isPrimary: false,
                            ),
                            const SizedBox(width: 10),
                            _buildPillButton(
                              label: 'payment_modal.proceed_payment'.tr(),
                              onTap: () {
                                if (_selectedMethod == 'fpx_card' && widget.amount < 10.0) {
                                  showGlassToast(context, 'cart.fpx_min_spend_error'.tr(), isError: true);
                                  return;
                                }
                                if (_selectedMethod == 'cash') {
                                  final shortId = widget.orderId.length > 8 ? widget.orderId.substring(0, 8).toUpperCase() : widget.orderId.toUpperCase();
                                  _handleSuccessPayment('cash', 'CASH-$shortId');
                                } else {
                                  _startGatewayFlow();
                                }
                              },
                              isDark: isDark,
                              isPrimary: true,
                            ),
                          ],
                        ),
                      ],

                      // =======================================================
                      // STEP 2: PAPARAN GERBANG CHIP ASIA / DUITNOW QR
                      // =======================================================
                      if (_currentStep == PaymentStep.duitNowQr) ...[
                        // Keadaan Ralat: Tiru 100% gaya GlassConfirmDialog (Logout Popup Style)
                        if (_gatewayError != null) ...[
                          Row(
                            children: [
                              const HugeIcon(
                                icon: HugeIcons.strokeRoundedAlert02,
                                color: Color(0xFFEF4444),
                                size: 22,
                                strokeWidth: 2.2,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'payment_modal.gateway_error_title'.tr(),
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                                    shadows: isDark ? frostedGlow : [],
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: HugeIcon(
                                  icon: HugeIcons.strokeRoundedCancel01,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  size: 18,
                                ),
                                onPressed: () => Navigator.pop(context, false),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _gatewayError!,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.78)
                                  : const Color(0xFF3A3A3C).withValues(alpha: 0.85),
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Action Buttons (Logout Popup Pill Style)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _buildPillButton(
                                label: 'payment_modal.back_to_cart'.tr(),
                                onTap: () => Navigator.pop(context, false),
                                isDark: isDark,
                                isPrimary: false,
                              ),
                              const SizedBox(width: 10),
                              _buildPillButton(
                                label: 'payment_modal.try_again'.tr(),
                                onTap: _startGatewayFlow,
                                isDark: isDark,
                                isPrimary: true,
                              ),
                            ],
                          ),
                        ] else ...[
                          // Header Normal: Icon + Title + Countdown + Close
                          Row(
                            children: [
                              HugeIcon(
                                icon: _selectedMethod == 'fpx_card'
                                    ? HugeIcons.strokeRoundedCreditCard
                                    : HugeIcons.strokeRoundedQrCode,
                                color: const Color(0xFF00E5FF),
                                size: 22,
                                strokeWidth: 2.2,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedMethod == 'fpx_card'
                                          ? 'payment_modal.fpx_gateway_title'.tr()
                                          : 'payment_modal.scan_duitnow_title'.tr(),
                                      style: TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                                        shadows: isDark ? frostedGlow : [],
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    Text(
                                      widget.shopName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Countdown Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(100),
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.05),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.35),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const HugeIcon(icon: HugeIcons.strokeRoundedTime02, color: Color(0xFF00E5FF), size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: _isCancelling
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF00E5FF),
                                        ),
                                      )
                                    : HugeIcon(
                                        icon: HugeIcons.strokeRoundedCancel01,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                        size: 18,
                                      ),
                                onPressed: _isCancelling ? null : () => _handleSafeCancel(),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          if (_isLoadingQr)
                            _buildQrShimmer(isDark)
                          else ...[
                            // Kad DuitNow QR Rasmi (Dibungkus dengan RepaintBoundary untuk Simpan/Muat Turun Gambar QR)
                            RepaintBoundary(
                              key: _qrCardBoundaryKey,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_selectedMethod == 'fpx_card')
                                          ? const Color(0xFF0F172A).withValues(alpha: 0.10)
                                          : const Color(0xFFED0058).withValues(alpha: 0.16),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
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
                                    const SizedBox(height: 12),
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
                                    const SizedBox(height: 3),
                                    Text(
                                      'payment_modal.waiting_realtime_conf'.tr(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.black45, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Butang Simpan / Muat Turun Gambar QR (Gaya Shopee & TikTok Shop)
                            if (_selectedMethod != 'fpx_card') ...[
                              SizedBox(
                                width: double.infinity,
                                child: _buildPillButton(
                                  label: _isSavingQr
                                      ? 'payment_modal.saving_qr'.tr()
                                      : 'payment_modal.save_qr_btn'.tr(),
                                  onTap: (_isSavingQr || _isCancelling) ? null : _saveQrCodeImage,
                                  isDark: isDark,
                                  isPrimary: true,
                                  customGradient: const [Color(0xFFED0058), Color(0xFFC8004B)],
                                  customBorderColor: const Color(0xFFFF4D8D),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Butang Tindakan Buka CHIP (In-App Browser di Mobile / Tab Sama di Web)
                            if (_purchase?.checkoutUrl.isNotEmpty == true) ...[
                              SizedBox(
                                width: double.infinity,
                                child: _buildPillButton(
                                  label: _selectedMethod == 'fpx_card'
                                      ? 'payment_modal.reopen_fpx_gateway'.tr()
                                      : 'payment_modal.open_chip_gateway'.tr(),
                                  onTap: _isCancelling
                                      ? null
                                      : () => _launchChipGatewayUrl(_purchase!.checkoutUrl),
                                  isDark: isDark,
                                  isPrimary: _selectedMethod == 'fpx_card',
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Butang Semak Status (Emerald Pill)
                            SizedBox(
                              width: double.infinity,
                              child: _buildPillButton(
                                label: _isVerifyingManual
                                    ? 'payment_modal.checking_status'.tr()
                                    : 'payment_modal.i_have_paid'.tr(),
                                onTap: (_isVerifyingManual || _isCancelling)
                                    ? null
                                    : _verifyPaymentStatusNow,
                                isDark: isDark,
                                isPrimary: true,
                                customGradient: const [Color(0xFF10B981), Color(0xFF059669)],
                                customBorderColor: const Color(0xFF34D399),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Butang Tukar Kaedah Bayaran (Shopee / TikTok Shop Style)
                            SizedBox(
                              width: double.infinity,
                              child: _buildPillButton(
                                label: 'payment_modal.change_method_btn'.tr(),
                                onTap: _isCancelling
                                    ? null
                                    : () {
                                        _statusTimer?.cancel();
                                        _countdownTimer?.cancel();
                                        setState(() {
                                          _currentStep = PaymentStep.selectMethod;
                                        });
                                      },
                                isDark: isDark,
                                isPrimary: false,
                              ),
                            ),

                            const SizedBox(height: 6),

                            // Butang Bayar Kemudian (Simpan Pesanan sebagai Menunggu Pembayaran)
                            Center(
                              child: TextButton(
                                onPressed: _isCancelling ? null : () => _handleSafeCancel(),
                                child: Text(
                                  _isCancelling
                                      ? 'payment_modal.cancelling_session'.tr()
                                      : 'payment_modal.pay_later_btn'.tr(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],

                      // =======================================================
                      // STEP 3: RESIT DIGITAL LENGKAP
                      // =======================================================
                      if (_currentStep == PaymentStep.receipt) ...[
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
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
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedCheckmarkCircle03,
                                color: Color(0xFF10B981),
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            _isCash ? 'payment_modal.order_placed'.tr() : 'payment_modal.payment_success'.tr(),
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            _isCash
                                ? 'payment_modal.cash_success_desc'.tr()
                                : 'payment_modal.online_success_desc'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Kotak Maklumat Resit
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.35),
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildReceiptRow('payment_modal.order_number'.tr(), '#${widget.orderId.length > 8 ? widget.orderId.substring(0, 8).toUpperCase() : widget.orderId}', isDark),
                              const Divider(height: 16),
                              _buildReceiptRow('payment_modal.store'.tr(), widget.shopName, isDark),
                              const Divider(height: 16),
                              _buildReceiptRow(
                                'payment_modal.payment_method'.tr(),
                                _selectedMethod == 'duitnow'
                                    ? 'payment_modal.duitnow_qr_chip'.tr()
                                    : (_selectedMethod == 'fpx_card'
                                        ? 'payment_modal.fpx_card_chip'.tr()
                                        : 'payment_modal.cash_counter'.tr()),
                                isDark,
                                valueColor: const Color(0xFF00E5FF),
                              ),
                              const Divider(height: 16),
                              _buildReceiptRow(
                                _isCash ? 'payment_modal.amount_to_pay'.tr() : 'payment_modal.amount_paid'.tr(),
                                currencyFormat.format(widget.amount),
                                isDark,
                                isBold: true,
                                valueColor: const Color(0xFF10B981),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildPillButton(
                              label: 'payment_modal.download_and_copy'.tr(),
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
                              isDark: isDark,
                              isPrimary: false,
                            ),
                            const SizedBox(width: 10),
                            _buildPillButton(
                              label: 'payment_modal.done'.tr(),
                              onTap: () => Navigator.pop(context, true),
                              isDark: isDark,
                              isPrimary: true,
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
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, bool isDark, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            fontSize: isBold ? 14 : 12.5,
          ),
        ),
      ],
    );
  }

  /// Butang Gaya Pill Seiras GlassConfirmDialog (Logout Popup)
  Widget _buildPillButton({
    required String label,
    required VoidCallback? onTap,
    required bool isDark,
    required bool isPrimary,
    List<Color>? customGradient,
    Color? customBorderColor,
  }) {
    if (!isPrimary) {
      // Frosted Glass Pill
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.35),
                width: 1.0,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF3A3A3C),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Radiant Gradient Pill
    final gradientColors = customGradient ?? const [Color(0xFF00E5FF), Color(0xFF0284C7)];
    final borderColor = customBorderColor ?? const Color(0xFF38BDF8).withValues(alpha: 0.60);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withValues(alpha: 0.30),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
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
    bool isEnabled = true,
  }) {
    final bool isSelected = isEnabled && _selectedMethod == value;

    return GestureDetector(
      onTap: () {
        if (!isEnabled) {
          HapticFeedback.heavyImpact();
          showGlassToast(context, 'cart.fpx_min_spend_error'.tr(), isError: true);
          return;
        }
        HapticFeedback.selectionClick();
        setState(() => _selectedMethod = value);
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isEnabled ? 1.0 : 0.42,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? (const Color(0xFF00E5FF).withValues(alpha: 0.08))
                : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF00E5FF)
                  : Colors.white.withValues(alpha: isDark ? 0.10 : 0.30),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF00E5FF).withValues(alpha: 0.18)
                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: HugeIcon(
                    icon: icon,
                    color: !isEnabled
                        ? Colors.grey
                        : (isSelected ? const Color(0xFF00E5FF) : (isDark ? Colors.white70 : const Color(0xFF475569))),
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? const Color(0xFF00E5FF)).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: (badgeColor ?? const Color(0xFF00E5FF)).withValues(alpha: 0.45),
                              ),
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
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isEnabled)
                Icon(
                  Icons.lock_outline_rounded,
                  size: 17,
                  color: isDark ? Colors.white38 : Colors.black38,
                )
              else
                Container(
                  width: 18,
                  height: 18,
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
                            width: 8,
                            height: 8,
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
      ),
    );
  }
}
