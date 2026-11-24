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

import '../utils/ngam_ref.dart';
import '../utils/payment_method_formatter.dart';
import '../services/chip_payment_service.dart';
import '../services/receipt_pdf_service.dart';
import 'glass_toast.dart';

enum PaymentStep { selectMethod, duitNowQr, receipt }

// =============================================================================
// CustomerPaymentModal (Full-Screen Shopee-Style Payment Page)
// - Stays directly inside a dedicated full-screen page (NO floating popup dialog)
// - DuitNow QR: crisp embedded QR card + Save QR PNG + 3-step guide + auto-verify
// - DuitNow Online Banking & Card: dedicated banking/card screen (ZERO QR shown!)
// - Zero gateway branding ("CHIP Asia" / "razer") and zero ugly slashes
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
      final res = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
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
  String? _resolvedPaidMethod;
  bool get _isCash => _selectedMethod == 'cash';
  bool get _isOnlineBanking => _selectedMethod == 'fpx_card';

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

  String get _canonicalMethodCode {
    if (_selectedMethod == 'cash') return 'cash';
    if (_selectedMethod == 'fpx_card') return 'duitnow_obw';
    return 'duitnow_qr';
  }

  String get _displayMethodLabel =>
      PaymentMethodFormatter.format(_resolvedPaidMethod ?? _canonicalMethodCode);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initMethod = (widget.initialMethod ?? 'duitnow').trim().toLowerCase();
    if (initMethod.contains('fpx') ||
        initMethod.contains('obw') ||
        initMethod.contains('online') ||
        initMethod.contains('card') ||
        initMethod.contains('kad')) {
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
      final shortId = NgamRef.isBookingReference(widget.orderId)
          ? NgamRef.booking(widget.orderId)
          : NgamRef.order(widget.orderId);
      _transactionRef = shortId;
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
          final dbMethod = row['payment_method']?.toString().trim();
          final resolved = (dbMethod != null &&
                  dbMethod.isNotEmpty &&
                  dbMethod.toLowerCase() != 'razer' &&
                  dbMethod.toLowerCase() != 'chip_online')
              ? dbMethod
              : _canonicalMethodCode;
          _handleSuccessPayment(resolved, ref);
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
        _handleSuccessPayment(_canonicalMethodCode, purchaseId);
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
        _resolvedPaidMethod = method;
        _transactionRef = ref.isNotEmpty ? ref : 'NGAM-${DateTime.now().millisecondsSinceEpoch}';
        _currentStep = PaymentStep.receipt;
      });
    }

    if (widget.onPaymentSuccess != null) {
      await widget.onPaymentSuccess!(PaymentMethodFormatter.format(method), _transactionRef);
    }
  }

  Future<void> _handleSafeCancel({bool isExpired = false}) async {
    if (_isCancelling || _hasHandledSuccess) return;
    _statusTimer?.cancel();
    _countdownTimer?.cancel();

    final purchaseId = _purchase?.id ?? '';
    if (mounted) {
      setState(() => _isCancelling = true);
    }

    try {
      if (purchaseId.isNotEmpty) {
        final cancelRes = await ChipPaymentService.instance.cancelPurchase(
          purchaseId,
          orderId: widget.orderId,
        );
        if (!mounted || _hasHandledSuccess) return;
        if (cancelRes == 'paid') {
          await _handleSuccessPayment(_canonicalMethodCode, purchaseId);
          if (mounted) {
            showGlassToast(context, 'payment_modal.already_paid_detected'.tr());
          }
          return;
        }
      }

      final paidInDb = await _isOrderAlreadyPaidInDb();
      if (!mounted || _hasHandledSuccess) return;
      if (paidInDb) {
        await _handleSuccessPayment(
          _canonicalMethodCode,
          purchaseId.isNotEmpty ? purchaseId : widget.orderId,
        );
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
        await _handleSuccessPayment(_canonicalMethodCode, res.id);
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

      // Untuk DuitNow Online Banking & Kad: terus buka halaman bank/kad (In-App Browser / Same-Tab Web)
      // Untuk DuitNow QR: KEKAL pada halaman QR ini (gaya Shopee) tanpa popup!
      if (_isOnlineBanking && res.checkoutUrl.isNotEmpty) {
        if (mounted) {
          showGlassToast(
            context,
            'payment_modal.opening_chip_gateway'.tr(),
            icon: HugeIcons.strokeRoundedLinkSquare01,
          );
        }
        await _launchGatewayUrl(res.checkoutUrl);
      }
    } catch (e) {
      debugPrint('[CustomerPaymentModal] createPurchase error: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingQr = false;
        _gatewayError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      _isCreatingPurchase = false;
    }
  }

  Future<void> _launchGatewayUrl(String rawUrl) async {
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

  Future<void> _saveQrCodeImage() async {
    if (_isSavingQr || _isCancelling) return;
    setState(() => _isSavingQr = true);
    HapticFeedback.lightImpact();

    try {
      Uint8List? pngBytes;

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

      final shortId = NgamRef.isBookingReference(widget.orderId)
          ? NgamRef.booking(widget.orderId)
          : NgamRef.order(widget.orderId);
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
        await _handleSuccessPayment(_canonicalMethodCode, purchaseId);
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

  String get _pageTitle {
    if (_currentStep == PaymentStep.selectMethod) {
      return 'payment_modal.choose_method'.tr();
    }
    if (_currentStep == PaymentStep.receipt) {
      return _isCash ? 'payment_modal.order_placed'.tr() : 'payment_modal.payment_success'.tr();
    }
    if (_gatewayError != null) {
      return 'payment_modal.gateway_error_title'.tr();
    }
    return _isOnlineBanking
        ? 'payment_modal.fpx_gateway_title'.tr()
        : 'payment_modal.scan_duitnow_title'.tr();
  }

  Widget _buildLoadingShimmer(bool isDark) {
    final baseColor = isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05);
    final highlightColor = isDark ? Colors.white.withValues(alpha: 0.16) : Colors.black.withValues(alpha: 0.11);

    return Column(
      children: [
        Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151C2C) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 24,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                ),
                const SizedBox(height: 18),
                Container(
                  width: _isOnlineBanking ? 88 : 210,
                  height: _isOnlineBanking ? 88 : 210,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_isOnlineBanking ? 44 : 18),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: 140,
                  height: 28,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 230,
                  height: 13,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
            ),
            const SizedBox(width: 10),
            Text(
              'payment_modal.preparing_session'.tr(),
              style: TextStyle(
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                fontSize: 12.5,
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
    final pageBg = isDark ? const Color(0xFF0A0F1A) : const Color(0xFFF4F7FB);
    final cardBg = isDark ? const Color(0xFF131B2E) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);

    final bool showCountdown =
        _currentStep == PaymentStep.duitNowQr && _gatewayError == null && !_isLoadingQr;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentStep == PaymentStep.receipt) {
          Navigator.pop(context, true);
          return;
        }
        if (_currentStep == PaymentStep.duitNowQr && _gatewayError == null) {
          _handleSafeCancel();
        } else {
          Navigator.pop(context, false);
        }
      },
      child: Scaffold(
        backgroundColor: pageBg,
        appBar: AppBar(
          backgroundColor: pageBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            onPressed: _isCancelling
                ? null
                : () {
                    if (_currentStep == PaymentStep.receipt) {
                      Navigator.pop(context, true);
                    } else if (_currentStep == PaymentStep.duitNowQr && _gatewayError == null) {
                      _handleSafeCancel();
                    } else {
                      Navigator.pop(context, false);
                    }
                  },
            icon: _isCancelling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                  )
                : Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 19,
                    color: textPrimary,
                  ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _pageTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              Text(
                widget.shopName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            if (showCountdown)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      color: const Color(0xFF00E5FF).withValues(alpha: isDark ? 0.14 : 0.12),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedTime02,
                          color: Color(0xFF00B8D4),
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // =========================================================
                    // STEP 1: PILIH KAEDAH BAYARAN
                    // =========================================================
                    if (_currentStep == PaymentStep.selectMethod) ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'payment_modal.amount_to_pay'.tr(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  currencyFormat.format(widget.amount),
                                  style: const TextStyle(
                                    color: Color(0xFF00B8D4),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
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
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),

                            _buildPaymentOption(
                              isDark: isDark,
                              value: 'duitnow',
                              title: 'payment_modal.duitnow_title'.tr(),
                              subtitle: 'payment_modal.duitnow_subtitle'.tr(),
                              icon: HugeIcons.strokeRoundedQrCode,
                              badge: 'payment_modal.duitnow_badge'.tr(),
                              badgeColor: const Color(0xFFED0058),
                            ),
                            const SizedBox(height: 10),

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
                            const SizedBox(height: 10),

                            _buildPaymentOption(
                              isDark: isDark,
                              value: 'cash',
                              title: 'payment_modal.cash_title'.tr(),
                              subtitle: 'payment_modal.cash_subtitle'.tr(),
                              icon: HugeIcons.strokeRoundedMoney01,
                            ),
                            const SizedBox(height: 20),

                            SizedBox(
                              width: double.infinity,
                              child: _buildActionButton(
                                label: 'payment_modal.proceed_payment'.tr(),
                                onTap: () {
                                  if (_selectedMethod == 'fpx_card' && widget.amount < 10.0) {
                                    showGlassToast(context, 'cart.fpx_min_spend_error'.tr(), isError: true);
                                    return;
                                  }
                                  if (_selectedMethod == 'cash') {
                                    final formattedRef = NgamRef.isBookingReference(widget.orderId)
                                        ? NgamRef.booking(widget.orderId)
                                        : NgamRef.order(widget.orderId);
                                    _handleSuccessPayment('cash', formattedRef);
                                  } else {
                                    _startGatewayFlow();
                                  }
                                },
                                isDark: isDark,
                                isPrimary: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: _buildActionButton(
                                label: 'payment_modal.cancel'.tr(),
                                onTap: () => Navigator.pop(context, false),
                                isDark: isDark,
                                isPrimary: false,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // =========================================================
                    // STEP 2: HALAMAN PEMBAYARAN (DUITNOW QR ATAU ONLINE BANKING)
                    // =========================================================
                    if (_currentStep == PaymentStep.duitNowQr) ...[
                      if (_gatewayError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const HugeIcon(
                                    icon: HugeIcons.strokeRoundedAlert02,
                                    color: Color(0xFFEF4444),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'payment_modal.gateway_error_title'.tr(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _gatewayError!,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: textSecondary,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: _buildActionButton(
                                  label: 'payment_modal.try_again'.tr(),
                                  onTap: _startGatewayFlow,
                                  isDark: isDark,
                                  isPrimary: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: _buildActionButton(
                                  label: 'payment_modal.back_to_cart'.tr(),
                                  onTap: () => Navigator.pop(context, false),
                                  isDark: isDark,
                                  isPrimary: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_isLoadingQr) ...[
                        _buildLoadingShimmer(isDark),
                      ] else if (_isOnlineBanking) ...[
                        // -----------------------------------------------------
                        // 2A. DUITNOW ONLINE BANKING & KAD (TIADA QR!)
                        // -----------------------------------------------------
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                                  ),
                                ),
                                child: const Center(
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedCreditCard,
                                    color: Color(0xFF38BDF8),
                                    size: 30,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'payment_modal.fpx_bank_badge'.tr(),
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                currencyFormat.format(_purchase?.amount ?? widget.amount),
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'payment_modal.fpx_redirect_desc'.tr(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12.5,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 13,
                                      height: 13,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF38BDF8),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'payment_modal.waiting_realtime_conf'.tr(),
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
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

                        if (_purchase?.checkoutUrl.isNotEmpty == true) ...[
                          _buildActionButton(
                            label: 'payment_modal.reopen_fpx_gateway'.tr(),
                            onTap: _isCancelling
                                ? null
                                : () => _launchGatewayUrl(_purchase!.checkoutUrl),
                            isDark: isDark,
                            isPrimary: true,
                          ),
                          const SizedBox(height: 10),
                        ],

                        _buildActionButton(
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
                        const SizedBox(height: 10),

                        _buildActionButton(
                          label: 'payment_modal.change_method_btn'.tr(),
                          onTap: _isCancelling
                              ? null
                              : () {
                                  _statusTimer?.cancel();
                                  _countdownTimer?.cancel();
                                  setState(() => _currentStep = PaymentStep.selectMethod);
                                },
                          isDark: isDark,
                          isPrimary: false,
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: TextButton(
                            onPressed: _isCancelling ? null : () => _handleSafeCancel(),
                            child: Text(
                              _isCancelling
                                  ? 'payment_modal.cancelling_session'.tr()
                                  : 'payment_modal.pay_later_btn'.tr(),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        // -----------------------------------------------------
                        // 2B. DUITNOW QR — KEKAL DALAM HALAMAN (GAYA SHOPEE)
                        // -----------------------------------------------------
                        RepaintBoundary(
                          key: _qrCardBoundaryKey,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFED0058).withValues(alpha: isDark ? 0.18 : 0.10),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFED0058),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'DuitNow QR',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12.5,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.shopName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF334155),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFFED0058).withValues(alpha: 0.22),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: SizedBox(
                                    width: 220,
                                    height: 220,
                                    child: QrImageView(
                                      data: (_purchase?.duitNowUrl.isNotEmpty == true)
                                          ? _purchase!.duitNowUrl
                                          : (_purchase?.checkoutUrl.isNotEmpty == true
                                              ? _purchase!.checkoutUrl
                                              : 'https://gate.chip-in.asia'),
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
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  currencyFormat.format(_purchase?.amount ?? widget.amount),
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFED0058),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'payment_modal.waiting_realtime_conf'.tr(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Primary Actions (Shopee-style Save QR + Verify Paid)
                        _buildActionButton(
                          label: _isSavingQr
                              ? 'payment_modal.saving_qr'.tr()
                              : 'payment_modal.save_qr_btn'.tr(),
                          onTap: (_isSavingQr || _isCancelling) ? null : _saveQrCodeImage,
                          isDark: isDark,
                          isPrimary: true,
                          customGradient: const [Color(0xFFED0058), Color(0xFFC8004B)],
                          customBorderColor: const Color(0xFFFF4D8D),
                          textColor: Colors.white,
                        ),
                        const SizedBox(height: 10),

                        _buildActionButton(
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
                          textColor: Colors.white,
                        ),
                        const SizedBox(height: 14),

                        // Shopee-style 3-step DuitNow QR guide card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'payment_modal.qr_how_to_pay'.tr(),
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildStepLine('1', 'payment_modal.qr_step_1'.tr(), textSecondary),
                              const SizedBox(height: 8),
                              _buildStepLine('2', 'payment_modal.qr_step_2'.tr(), textSecondary),
                              const SizedBox(height: 8),
                              _buildStepLine('3', 'payment_modal.qr_step_3'.tr(), textSecondary),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        _buildActionButton(
                          label: 'payment_modal.change_method_btn'.tr(),
                          onTap: _isCancelling
                              ? null
                              : () {
                                  _statusTimer?.cancel();
                                  _countdownTimer?.cancel();
                                  setState(() => _currentStep = PaymentStep.selectMethod);
                                },
                          isDark: isDark,
                          isPrimary: false,
                        ),
                        const SizedBox(height: 6),

                        Center(
                          child: TextButton(
                            onPressed: _isCancelling ? null : () => _handleSafeCancel(),
                            child: Text(
                              _isCancelling
                                  ? 'payment_modal.cancelling_session'.tr()
                                  : 'payment_modal.pay_later_btn'.tr(),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],

                    // =========================================================
                    // STEP 3: RESIT DIGITAL LENGKAP
                    // =========================================================
                    if (_currentStep == PaymentStep.receipt) ...[
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF10B981).withValues(alpha: 0.14),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.60),
                                  width: 2,
                                ),
                              ),
                              child: const Center(
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedCheckmarkCircle03,
                                  color: Color(0xFF10B981),
                                  size: 36,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _isCash ? 'payment_modal.order_placed'.tr() : 'payment_modal.payment_success'.tr(),
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isCash
                                  ? 'payment_modal.cash_success_desc'.tr()
                                  : 'payment_modal.online_success_desc'.tr(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 20),

                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Column(
                                children: [
                                  _buildReceiptRow(
                                    'payment_modal.order_number'.tr(),
                                    '#${NgamRef.isBookingReference(widget.orderId) ? NgamRef.booking(widget.orderId) : NgamRef.order(widget.orderId)}',
                                    isDark,
                                  ),
                                  const Divider(height: 18),
                                  _buildReceiptRow('payment_modal.store'.tr(), widget.shopName, isDark),
                                  const Divider(height: 18),
                                  _buildReceiptRow(
                                    'payment_modal.payment_method'.tr(),
                                    _displayMethodLabel,
                                    isDark,
                                    valueColor: const Color(0xFF00B8D4),
                                  ),
                                  const Divider(height: 18),
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
                            const SizedBox(height: 20),

                            _buildActionButton(
                              label: 'payment_modal.done'.tr(),
                              onTap: () => Navigator.pop(context, true),
                              isDark: isDark,
                              isPrimary: true,
                            ),
                            const SizedBox(height: 10),
                            _buildActionButton(
                              label: 'payment_modal.download_and_copy'.tr(),
                              onTap: () async {
                                final receiptTitle = 'payment_modal.receipt_title'.tr();
                                final receiptOrder = 'payment_modal.receipt_order'.tr();
                                final receiptAmount = 'payment_modal.receipt_amount'.tr();
                                final receiptRef = 'payment_modal.receipt_ref'.tr();
                                final receiptStatus = 'payment_modal.receipt_status'.tr();
                                final receiptDate = 'payment_modal.receipt_date'.tr();
                                final statusStr = _isCash
                                    ? 'payment_modal.receipt_unpaid_cash'.tr()
                                    : 'payment_modal.receipt_paid'.tr();
                                final thanksStr = 'payment_modal.receipt_thanks'.tr();
                                final storeStr = 'payment_modal.store'.tr();

                                final formattedRef = NgamRef.isBookingReference(widget.orderId)
                                    ? NgamRef.booking(widget.orderId)
                                    : NgamRef.order(widget.orderId);
                                final receiptStr = '''
========================================
         $receiptTitle          
========================================
$storeStr   : ${widget.shopName}
$receiptOrder : #$formattedRef
$receiptAmount  : ${currencyFormat.format(widget.amount)}
$receiptRef : ${_transactionRef.isNotEmpty ? _transactionRef : formattedRef}
$receiptStatus  : $statusStr
$receiptDate  : ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now())}
========================================
$thanksStr
''';
                                Clipboard.setData(ClipboardData(text: receiptStr));
                                try {
                                  await ReceiptPdfService.downloadReceiptPdf(
                                    orderId: formattedRef,
                                    shopName: widget.shopName,
                                    customerName: widget.customerName,
                                    customerPhone: widget.customerPhone,
                                    orderCreatedAt: DateTime.now(),
                                    paymentTime: DateTime.now(),
                                    paymentMethod: _displayMethodLabel,
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
                                    fileName: 'Resit_Ngam_$formattedRef.txt',
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
                          ],
                        ),
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

  Widget _buildStepLine(String numText, String text, Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFFED0058).withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              numText,
              style: const TextStyle(
                color: Color(0xFFED0058),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
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
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              fontSize: isBold ? 15 : 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback? onTap,
    required bool isDark,
    required bool isPrimary,
    List<Color>? customGradient,
    Color? customBorderColor,
    Color? textColor,
  }) {
    if (!isPrimary) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final gradientColors = customGradient ?? const [Color(0xFF00E5FF), Color(0xFF0284C7)];
    final borderColor = customBorderColor ?? const Color(0xFF38BDF8).withValues(alpha: 0.60);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: textColor ?? Colors.black,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
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
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: isSelected
                ? (const Color(0xFF00E5FF).withValues(alpha: 0.08))
                : (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF00E5FF)
                  : (isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
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
                        : (isSelected
                            ? const Color(0xFF00E5FF)
                            : (isDark ? Colors.white70 : const Color(0xFF475569))),
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (badge != null)
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
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isEnabled)
                Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: isDark ? Colors.white38 : Colors.black38,
                )
              else
                Container(
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00E5FF)
                          : (isDark ? Colors.white24 : Colors.black26),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 9,
                            height: 9,
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
