import 'dart:async';
import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/chip_payment_service.dart';
import '../../services/receipt_pdf_service.dart';
import '../../services/chat_service.dart';
import '../../services/dispute_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/ngam_ref.dart';
import '../../utils/payment_method_formatter.dart';
import '../../widgets/customer_payment_modal.dart';
import '../../widgets/glass_nav_button.dart';
import '../../widgets/glass_toast.dart';
import '../receipt/ereceipt_screen.dart';
import '../shared/chat_screen.dart';
import 'dispute_center_screen.dart';

class OrderStatusTrackerScreen extends StatefulWidget {
  final String orderId;
  final String shopName;
  final double totalAmount;
  final String? pickupTime;
  final String? fulfillmentType;
  final List<Map<String, dynamic>> items;
  final String? shopId;
  final String? paymentMethod;

  const OrderStatusTrackerScreen({
    super.key,
    required this.orderId,
    this.shopName = 'Pesanan Ngam',
    this.totalAmount = 0.0,
    this.pickupTime,
    this.fulfillmentType,
    this.items = const [],
    this.shopId,
    this.paymentMethod,
  });

  @override
  State<OrderStatusTrackerScreen> createState() => _OrderStatusTrackerScreenState();
}

class _OrderStatusTrackerScreenState extends State<OrderStatusTrackerScreen> {
  static const int _paymentWindowSeconds = 15 * 60; // 15 minit tempoh bayaran (gaya Shopee / TikTok Shop)

  String _status = 'pending'; // 'pending', 'preparing', 'ready', 'completed', 'cancelled'
  String _paymentStatus = 'paid';
  String _paymentMethod = '';
  String _shopName = '';
  String? _shopPhone;
  String? _shopAddress;
  String? _shopId;
  double _totalAmount = 0.0;
  double _subtotal = 0.0;
  double _tax = 0.0;
  double _discount = 0.0;
  DateTime? _orderCreatedAt;
  DateTime? _orderPaidAt;
  String? _customerName;
  String? _customerPhone;
  String? _notes;
  String? _cancelReason;
  String? _chipPurchaseId;
  String? _fulfillmentLabel;
  String? _bookingTime;
  String? _bookingDate;
  String? _providerName;
  String? _serviceName;
  int? _pax;
  List<Map<String, dynamic>> _loadedItems = [];
  bool _isCancelling = false;
  bool _hasReviewed = false;
  bool _isDownloadingPdf = false;
  bool _isBookingRecord = false;
  bool _isPosOrder = false;
  String? _explicitBookingRef;
  Timer? _paymentExpiryTimer;
  int _expiryRemainingSeconds = _paymentWindowSeconds;
  DisputeCase? _activeDispute;

  String get _displayOrderRef {
    if (_explicitBookingRef != null && NgamRef.isValid(_explicitBookingRef)) {
      return _explicitBookingRef!.replaceAll('#', '').toUpperCase();
    }
    if (_isBookingRecord || NgamRef.isBookingReference(widget.orderId)) {
      return NgamRef.booking(widget.orderId, _orderCreatedAt);
    }
    if (_isPosOrder) {
      return NgamRef.pos(widget.orderId, _orderCreatedAt);
    }
    return NgamRef.order(widget.orderId, createdAt: _orderCreatedAt);
  }

  bool get _isCashMethod {
    final m = _paymentMethod.trim().toLowerCase();
    return m == 'cash' || m == 'tunai' || m == 'counter' || m.contains('cash') || m.contains('tunai');
  }

  bool get _isAwaitingOnlinePayment =>
      _status == 'pending' && _paymentStatus == 'pending' && !_isCashMethod;

  Map<String, dynamic> _normalizeItem(Map<String, dynamic> raw) {
    final name = raw['name'] ?? raw['product_name'] ?? raw['title'] ?? raw['service_name'] ?? 'Item';
    final qtyNum = (raw['qty'] ?? raw['quantity'] ?? 1);
    final qty = (qtyNum is num) ? qtyNum.toInt() : (int.tryParse(qtyNum.toString()) ?? 1);
    final subNum = (raw['price'] ?? raw['subtotal']);
    final unitNum = raw['unit_price'];

    double unitPrice = 0.0;
    double price = 0.0;

    if (unitNum != null && unitNum is num) {
      unitPrice = unitNum.toDouble();
      price = (subNum != null && subNum is num) ? subNum.toDouble() : (unitPrice * qty);
    } else if (subNum != null && subNum is num) {
      price = subNum.toDouble();
      unitPrice = qty > 0 ? (price / qty) : price;
    }

    return {
      'name': name.toString(),
      'qty': qty,
      'unit_price': unitPrice,
      'price': price,
    };
  }

  String _formatPaymentMethod(String raw) {
    return PaymentMethodFormatter.format(raw);
  }

  @override
  void initState() {
    super.initState();
    _shopName = widget.shopName;
    _totalAmount = widget.totalAmount;
    _shopId = widget.shopId;
    _fulfillmentLabel = widget.fulfillmentType;
    if (widget.paymentMethod != null && widget.paymentMethod!.trim().isNotEmpty) {
      _paymentMethod = widget.paymentMethod!.trim();
    }
    if (widget.items.isNotEmpty) {
      _loadedItems = widget.items.map((it) => _normalizeItem(it)).toList();
      _subtotal = _loadedItems.fold(0.0, (acc, it) => acc + ((it['price'] as num?)?.toDouble() ?? 0.0));
    }
    _loadOrderData();
  }

  @override
  void dispose() {
    _paymentExpiryTimer?.cancel();
    super.dispose();
  }

  String? _extractCancelReason(String? rawNotes) {
    if (rawNotes == null || rawNotes.isEmpty) return null;
    final match = RegExp(r'\[Sebab Batal:\s*([^\]]+)\]', caseSensitive: false).firstMatch(rawNotes);
    return match?.group(1)?.trim();
  }

  void _syncPaymentExpiryTimer() {
    _paymentExpiryTimer?.cancel();
    if (!_isAwaitingOnlinePayment) return;

    final created = _orderCreatedAt ?? DateTime.now();
    final expiresAt = created.add(const Duration(seconds: _paymentWindowSeconds));
    final remaining = expiresAt.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) {
      _expiryRemainingSeconds = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _autoExpireUnpaidOrder();
      });
      return;
    }

    _expiryRemainingSeconds = remaining;
    _paymentExpiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isAwaitingOnlinePayment) {
        timer.cancel();
        return;
      }
      final left = expiresAt.difference(DateTime.now()).inSeconds;
      if (left <= 0) {
        timer.cancel();
        setState(() => _expiryRemainingSeconds = 0);
        _autoExpireUnpaidOrder();
      } else {
        setState(() => _expiryRemainingSeconds = left);
      }
    });
  }

  Future<void> _autoExpireUnpaidOrder() async {
    if (!_isAwaitingOnlinePayment || _isCancelling) return;
    _isCancelling = true;
    try {
      // Semak dengan CHIP Asia dahulu sekiranya pelanggan baru sahaja selesai bayar
      if (_chipPurchaseId != null && _chipPurchaseId!.isNotEmpty) {
        final chipRes = await ChipPaymentService.instance.cancelPurchase(
          _chipPurchaseId!,
          orderId: widget.orderId,
        );
        if (chipRes == 'paid') {
          if (mounted) {
            setState(() {
              _paymentStatus = 'paid';
              _isCancelling = false;
            });
          }
          return;
        }
      }

      final reasonText = 'order_status.cancel_reason_auto_expired'.tr();
      final existingNotes = (_notes ?? '').replaceAll(RegExp(r'\[Sebab Batal:[^\]]*\]'), '').trim();
      final updatedNotes = existingNotes.isEmpty
          ? '[Sebab Batal: $reasonText]'
          : '$existingNotes [Sebab Batal: $reasonText]';

      await Supabase.instance.client
          .from('orders')
          .update({
            'status': 'cancelled',
            'notes': updatedNotes,
          })
          .eq('id', widget.orderId)
          .neq('payment_status', 'paid');

      // Pulihkan stok produk fizikal
      await _restoreInventoryStock();

      if (mounted) {
        setState(() {
          _status = 'cancelled';
          _notes = updatedNotes;
          _cancelReason = reasonText;
          _isCancelling = false;
        });
        showGlassToast(context, 'order_status.order_auto_expired_toast'.tr(), isError: true);
      }
    } catch (_) {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _restoreInventoryStock() async {
    try {
      await Supabase.instance.client.rpc(
        'restore_order_stock',
        params: {'p_order_id': widget.orderId},
      );
    } catch (e) {
      debugPrint('[OrderStatusTracker] restore_order_stock RPC warning: $e');
    }
  }

  Future<void> _retryOrChangePayment({required bool startAtMethodSelect}) async {
    if (_isCancelling || !_isAwaitingOnlinePayment) return;

    String resolvedMethod = _paymentMethod.isNotEmpty ? _paymentMethod : 'duitnow';
    final bool paid = await CustomerPaymentModal.show(
      context: context,
      amount: _totalAmount,
      orderTitle: 'Pesanan #$_displayOrderRef - $_shopName',
      shopName: _shopName,
      orderId: widget.orderId,
      items: _loadedItems,
      customerName: _customerName,
      customerPhone: _customerPhone,
      discountAmount: _discount > 0 ? _discount : null,
      initialMethod: resolvedMethod,
      startAtMethodSelect: startAtMethodSelect,
      onPaymentSuccess: (method, txRef) async {
        if (method.trim().isNotEmpty) {
          resolvedMethod = method.trim();
        }
        final isSwitchedToCash = resolvedMethod.toLowerCase().contains('cash') ||
            resolvedMethod.toLowerCase().contains('tunai');
        final nextPayStatus = isSwitchedToCash ? 'unpaid' : 'paid';
        final nextPayMethod = isSwitchedToCash ? 'cash' : resolvedMethod;
        try {
          await Supabase.instance.client
              .from('orders')
              .update({
                'payment_status': nextPayStatus,
                'payment_method': nextPayMethod,
              })
              .eq('id', widget.orderId);
        } catch (_) {
          try {
            await Supabase.instance.client
                .from('orders')
                .update({'payment_status': nextPayStatus})
                .eq('id', widget.orderId);
          } catch (_) {}
        }
        // Tolak stok inventori secara atomik & idempoten di pelayan (SECURITY DEFINER)
        try {
          await Supabase.instance.client.rpc(
            'deduct_order_stock',
            params: {'p_order_id': widget.orderId},
          );
        } catch (e) {
          debugPrint('[OrderStatusTracker] deduct_order_stock RPC warning: $e');
        }
      },
    );

    if (!mounted) return;
    if (paid) {
      final isSwitchedToCash = resolvedMethod.toLowerCase().contains('cash') ||
          resolvedMethod.toLowerCase().contains('tunai');
      _paymentExpiryTimer?.cancel();
      setState(() {
        _paymentMethod = isSwitchedToCash ? 'cash' : resolvedMethod;
        _paymentStatus = isSwitchedToCash ? 'unpaid' : 'paid';
        if (!isSwitchedToCash) {
          _orderPaidAt = DateTime.now();
        }
      });
      if (isSwitchedToCash) {
        showGlassToast(context, 'order_status.payment_method_updated_cash'.tr());
      }
    }
    _loadOrderData();
  }

  void _loadOrderData() async {
    final db = Supabase.instance.client;
    Map<String, dynamic>? res;
    List<dynamic> itemsRes = [];

    try {
      try {
        res = await db
            .from('orders')
            .select('*, businesses(id, business_name, business_phone, address_line)')
            .eq('id', widget.orderId)
            .maybeSingle();
      } catch (joinErr) {
        debugPrint('[OrderStatusTracker] Orders join query warning: $joinErr');
        try {
          res = await db
              .from('orders')
              .select('*')
              .eq('id', widget.orderId)
              .maybeSingle();
        } catch (plainErr) {
          debugPrint('[OrderStatusTracker] Orders plain query warning: $plainErr');
        }
      }

      // Fetch business info separately if join was omitted or returned null
      Map<String, dynamic>? separateBiz;
      if (res != null && res['businesses'] is! Map && res['business_id'] != null) {
        try {
          separateBiz = await db
              .from('businesses')
              .select('id, business_name, business_phone, address_line')
              .eq('id', res['business_id'].toString())
              .maybeSingle();
        } catch (bizErr) {
          debugPrint('[OrderStatusTracker] Separate business fetch warning: $bizErr');
        }
      }

      // Always fetch order_items independently so items never vanish on a join error
      if (res != null) {
        try {
          final fetchedItems = await db
              .from('order_items')
              .select()
              .eq('order_id', widget.orderId);
          itemsRes = fetchedItems as List<dynamic>;
        } catch (itemErr) {
          debugPrint('[OrderStatusTracker] Order items fetch warning: $itemErr');
        }
      }

      if (mounted) {
        setState(() {
          if (res != null) {
            _isBookingRecord = false;
            _isPosOrder = (res['source']?.toString().toLowerCase() == 'pos');
            _status = res['status']?.toString().toLowerCase() ?? 'pending';
            _paymentStatus = res['payment_status']?.toString().toLowerCase() ?? 'paid';
            final dbMethod = res['payment_method']?.toString().trim() ?? '';
            if (dbMethod.isNotEmpty) {
              _paymentMethod = dbMethod;
            }
            _totalAmount = (res['total'] as num?)?.toDouble() ?? _totalAmount;
            final discountCents = (res['discount_cents'] as num?)?.toDouble();
            final discountRm = (res['discount'] as num?)?.toDouble();
            if (discountCents != null && discountCents > 0) {
              _discount = discountCents / 100.0;
            } else if (discountRm != null && discountRm > 0) {
              _discount = discountRm;
            }
            _notes = res['notes']?.toString();
            _cancelReason = _extractCancelReason(_notes);
            _chipPurchaseId = res['chip_purchase_id']?.toString();
            _shopId = res['business_id']?.toString() ?? _shopId;
            _customerName = res['customer_name']?.toString();
            _customerPhone = res['customer_phone']?.toString();

            if (res['created_at'] != null) {
              _orderCreatedAt = DateTime.tryParse(res['created_at'].toString())?.toLocal();
            }
            if (res['paid_at'] != null) {
              _orderPaidAt = DateTime.tryParse(res['paid_at'].toString())?.toLocal();
            } else if (_paymentStatus == 'paid') {
              _orderPaidAt = _orderCreatedAt ?? DateTime.now();
            }

            final biz = res['businesses'] is Map ? res['businesses'] : separateBiz;
            if (biz is Map) {
              final bName = biz['business_name']?.toString() ?? '';
              if (bName.isNotEmpty) _shopName = bName;
              _shopPhone = biz['business_phone']?.toString();
              _shopAddress = (biz['address_line'] ?? biz['business_address'])?.toString();
            }

            if ((_fulfillmentLabel == null || _fulfillmentLabel!.isEmpty) && _notes != null) {
              final match = RegExp(r'\[([^\]]+)\]').firstMatch(
                _notes!.replaceAll(RegExp(r'\[Sebab Batal:[^\]]*\]'), ''),
              );
              if (match != null) {
                _fulfillmentLabel = match
                    .group(1)
                    ?.replaceAll('Bungkus (Ambil Pantas)', 'Ambil Sendiri (Segera)')
                    .replaceAll('Bungkus:', 'Ambil Sendiri:');
              }
            }
          }

          if (itemsRes.isNotEmpty) {
            _loadedItems = itemsRes.map<Map<String, dynamic>>((row) {
              return _normalizeItem(Map<String, dynamic>.from(row as Map));
            }).toList();
          }

          if (res == null) {
            _loadBookingFallback();
          } else {
            _calculateSubtotal();
            _syncPaymentExpiryTimer();
          }
        });
      }
      final disp = await DisputeService.fetchDisputeByOrder(widget.orderId) ??
          await DisputeService.fetchDisputeByBooking(bookingId: widget.orderId);
      if (mounted && disp != null) {
        setState(() => _activeDispute = disp);
      }
    } catch (e) {
      debugPrint('[OrderStatusTracker] Load order error: $e');
      if (mounted) {
        _loadBookingFallback();
      }
    }
  }

  Future<void> _handleDisputeAction() async {
    if (_activeDispute != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DisputeRoomScreen(initialDispute: _activeDispute!),
        ),
      );
      _loadOrderData();
      return;
    }

    if (_shopId == null || _shopId!.isEmpty) {
      showGlassToast(context, 'Maklumat kedai belum dimuatkan.', type: GlassToastType.warning);
      return;
    }

    final summary = _loadedItems.isNotEmpty
        ? _loadedItems.map((e) => '${e['qty']}x ${e['name']}').join(', ')
        : (_serviceName ?? _shopName);

    final created = await showOpenDisputeSheet(
      context: context,
      targetType: 'order',
      orderId: widget.orderId,
      businessId: _shopId!,
      businessName: _shopName,
      totalAmount: _totalAmount,
      itemSummary: summary,
    );

    if (created != null && mounted) {
      setState(() {
        _activeDispute = created;
        _status = 'disputed';
      });
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DisputeRoomScreen(initialDispute: created),
        ),
      );
      _loadOrderData();
    }
  }

  void _loadBookingFallback() async {
    final db = Supabase.instance.client;
    try {
      Map<String, dynamic>? bRes;
      try {
        bRes = await db
            .from('bookings')
            .select('*, businesses(id, business_name, business_phone, address_line)')
            .eq('id', widget.orderId)
            .maybeSingle();
      } catch (_) {
        try {
          bRes = await db
              .from('bookings')
              .select('*')
              .eq('id', widget.orderId)
              .maybeSingle();
        } catch (_) {}
      }

      // Support short_ref & booking_id (cth: NB261123H4W8X3 atau RZRV-261123-XXXXX)
      if (bRes == null) {
        try {
          bRes = await db
              .from('bookings')
              .select('*, businesses(id, business_name, business_phone, address_line)')
              .or('booking_metadata->>short_ref.eq.${widget.orderId},booking_metadata->>booking_id.eq.${widget.orderId}')
              .maybeSingle();
        } catch (_) {}
      }

      Map<String, dynamic>? separateBiz;
      if (bRes != null && bRes['businesses'] is! Map && bRes['business_id'] != null) {
        try {
          separateBiz = await db
              .from('businesses')
              .select('id, business_name, business_phone, address_line')
              .eq('id', bRes['business_id'].toString())
              .maybeSingle();
        } catch (_) {}
      }

      if (bRes != null && mounted) {
        setState(() {
          _isBookingRecord = true;
          _status = bRes!['status']?.toString().toLowerCase() ?? _status;
          _totalAmount = (bRes['total_price'] as num?)?.toDouble() ?? _totalAmount;
          _shopId = bRes['business_id']?.toString() ?? _shopId;
          _customerName = bRes['customer_name']?.toString() ?? _customerName;
          _serviceName = bRes['service_name']?.toString();
          _bookingDate = bRes['booking_date']?.toString();
          _bookingTime = bRes['booking_time']?.toString();
          final paxNum = bRes['pax'];
          _pax = paxNum is num ? paxNum.toInt() : (int.tryParse(paxNum.toString()) ?? 1);
          _notes = bRes['notes']?.toString() ?? _notes;

          if (bRes['created_at'] != null) {
            _orderCreatedAt = DateTime.tryParse(bRes['created_at'].toString())?.toLocal();
            _orderPaidAt = _orderCreatedAt;
          }

          final meta = bRes['booking_metadata'] as Map<String, dynamic>? ?? {};
          final rawMetaRef = (meta['booking_id'] ?? meta['short_ref'])?.toString().trim();
          if (rawMetaRef != null && NgamRef.isValid(rawMetaRef)) {
            _explicitBookingRef = rawMetaRef.toUpperCase();
          }
          if (meta['payment_status'] != null) {
            _paymentStatus = meta['payment_status'].toString().toLowerCase();
          }
          if (meta['payment_method'] != null) {
            _paymentMethod = meta['payment_method'].toString();
          }
          if (meta['provider_name'] != null) {
            _providerName = meta['provider_name'].toString();
          }
          final metaDiscount = (meta['discount_amount'] as num?)?.toDouble();
          if (metaDiscount != null && metaDiscount > 0) {
            _discount = metaDiscount;
          }
          _fulfillmentLabel = meta['category']?.toString() ?? 'Tempahan Perkhidmatan';

          final biz = bRes['businesses'] is Map ? bRes['businesses'] : separateBiz;
          if (biz is Map) {
            final bName = biz['business_name']?.toString() ?? '';
            if (bName.isNotEmpty) _shopName = bName;
            _shopPhone = biz['business_phone']?.toString() ?? _shopPhone;
            _shopAddress = (biz['address_line'] ?? biz['business_address'])?.toString() ?? _shopAddress;
          }

          if (_loadedItems.isEmpty && _serviceName != null) {
            final qty = _pax ?? 1;
            _loadedItems = [
              {
                'name': _serviceName!,
                'qty': qty,
                'unit_price': qty > 0 ? (_totalAmount / qty) : _totalAmount,
                'price': _totalAmount,
              }
            ];
          }
          _calculateSubtotal();
        });
      }
    } catch (e) {
      debugPrint('[OrderStatusTracker] Load booking error: $e');
    }
  }

  void _calculateSubtotal() {
    if (_loadedItems.isNotEmpty) {
      _subtotal = _loadedItems.fold(0.0, (acc, it) => acc + ((it['price'] as num?)?.toDouble() ?? 0.0));
    }
    if (_subtotal == 0.0) {
      _subtotal = _totalAmount;
    }
    if (_discount <= 0.0 && _subtotal > 0.0 && _totalAmount > 0.0 && (_subtotal - _totalAmount) > 0.009) {
      _discount = double.parse((_subtotal - _totalAmount).toStringAsFixed(2));
    }
  }

  Future<void> _openShopChat() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) showGlassToast(context, 'chat.login_required'.tr(), isError: true);
      return;
    }
    final bizId = _shopId ?? widget.shopId ?? '';
    if (bizId.isEmpty) {
      if (mounted) showGlassToast(context, 'chat.open_chat_failed'.tr(), isError: true);
      return;
    }
    try {
      final conv = await ChatService.getOrCreateBusinessConversation(
        bizId,
        contextType: 'order',
        contextId: widget.orderId,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(conversation: conv),
        ),
      );
    } catch (_) {
      if (mounted) showGlassToast(context, 'chat.open_chat_failed'.tr(), isError: true);
    }
  }

  Future<void> _contactShopWhatsApp() async {
    final phoneRaw = _shopPhone ?? '';
    if (phoneRaw.trim().isEmpty) {
      showGlassToast(context, 'order_status.shop_phone_not_found'.tr(), isError: true);
      return;
    }
    String phone = phoneRaw.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.startsWith('0')) {
      phone = '6$phone';
    } else if (!phone.startsWith('60') && phone.length >= 9) {
      phone = '60$phone';
    }
    final shortId = _displayOrderRef;
    final msg = Uri.encodeComponent(
      'Hai $_shopName, saya ingin bertanya tentang pesanan saya #$shortId (RM ${_totalAmount.toStringAsFixed(2)}).',
    );
    final url = Uri.parse('https://wa.me/$phone?text=$msg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      showGlassToast(context, 'order_status.whatsapp_launch_error'.tr(), isError: true);
    }
  }

  Future<void> _cancelPendingOrder() async {
    if (_status != 'pending' || _isCancelling) return;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isPaidOrder = _paymentStatus == 'paid';

    final List<String> presetReasons = [
      'order_status.cancel_reason_1'.tr(),
      'order_status.cancel_reason_2'.tr(),
      'order_status.cancel_reason_3'.tr(),
      'order_status.cancel_reason_4'.tr(),
      'order_status.cancel_reason_5'.tr(),
      'order_status.cancel_reason_6'.tr(),
    ];

    int selectedIndex = -1;
    final TextEditingController otherReasonCtrl = TextEditingController();

    final String? chosenReason = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final bool isOther = selectedIndex == presetReasons.length - 1;
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141923) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedAlert02,
                                color: Colors.redAccent,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'order_status.cancel_reason_title'.tr(),
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isPaidOrder ? const Color(0xFFF59E0B) : Colors.blue).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (isPaidOrder ? const Color(0xFFF59E0B) : Colors.blue).withValues(alpha: 0.30),
                          ),
                        ),
                        child: Text(
                          isPaidOrder
                              ? 'order_status.cancel_reason_subtitle_paid'.tr()
                              : 'order_status.cancel_reason_subtitle_unpaid'.tr(),
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                            fontSize: 12.5,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...List.generate(presetReasons.length, (idx) {
                        final isSelected = selectedIndex == idx;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setModalState(() => selectedIndex = idx),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.redAccent.withValues(alpha: isDark ? 0.16 : 0.08)
                                    : (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.redAccent.withValues(alpha: 0.6)
                                      : (isDark ? Colors.white12 : Colors.black12),
                                  width: isSelected ? 1.4 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                    size: 18,
                                    color: isSelected ? Colors.redAccent : (isDark ? Colors.white38 : Colors.black38),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      presetReasons[idx],
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      if (isOther) ...[
                        const SizedBox(height: 4),
                        TextField(
                          controller: otherReasonCtrl,
                          maxLines: 2,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'order_status.cancel_reason_other_hint'.tr(),
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 12.5,
                            ),
                            filled: true,
                            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? Colors.white70 : Colors.black87,
                                side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text('order_status.cancel_btn_back'.tr()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () {
                                if (selectedIndex < 0) {
                                  showGlassToast(context, 'order_status.cancel_reason_required_toast'.tr(), isError: true);
                                  return;
                                }
                                String finalReason = presetReasons[selectedIndex];
                                if (isOther) {
                                  final custom = otherReasonCtrl.text.trim();
                                  if (custom.isEmpty) {
                                    showGlassToast(context, 'order_status.cancel_reason_required_toast'.tr(), isError: true);
                                    return;
                                  }
                                  finalReason = custom;
                                }
                                Navigator.pop(ctx, finalReason);
                              },
                              child: Text(
                                'order_status.cancel_btn_confirm'.tr(),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    otherReasonCtrl.dispose();

    if (chosenReason == null || chosenReason.trim().isEmpty) return;
    _paymentExpiryTimer?.cancel();
    setState(() => _isCancelling = true);
    try {
      // Jika pesanan belum dibayar tetapi ada sesi CHIP aktif, batalkan sesi CHIP terlebih dahulu
      if (!isPaidOrder && _chipPurchaseId != null && _chipPurchaseId!.isNotEmpty) {
        try {
          await ChipPaymentService.instance.cancelPurchase(
            _chipPurchaseId!,
            orderId: widget.orderId,
          );
        } catch (_) {}
      }

      final existingNotes = (_notes ?? '').replaceAll(RegExp(r'\[Sebab Batal:[^\]]*\]'), '').trim();
      final updatedNotes = existingNotes.isEmpty
          ? '[Sebab Batal: ${chosenReason.trim()}]'
          : '$existingNotes [Sebab Batal: ${chosenReason.trim()}]';

      await Supabase.instance.client.from('orders').update({
        'status': 'cancelled',
        'notes': updatedNotes,
        if (isPaidOrder) 'payment_status': 'refund_pending',
      }).eq('id', widget.orderId);

      // Pulihkan stok produk fizikal bagi pesanan yang dibatalkan
      await _restoreInventoryStock();

      if (mounted) {
        setState(() {
          _status = 'cancelled';
          _notes = updatedNotes;
          _cancelReason = chosenReason.trim();
          if (isPaidOrder) _paymentStatus = 'refund_pending';
          _isCancelling = false;
        });
        showGlassToast(context, 'order_status.cancel_success'.tr());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCancelling = false);
        showGlassToast(context, 'order_status.cancel_error'.tr(args: [e.toString()]), isError: true);
      }
    }
  }

  Future<void> _showReviewDialog() async {
    int stars = 5;
    bool submitting = false;
    final commentCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final submitted = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF111622).withValues(alpha: 0.92)
                        : Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.14)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                        blurRadius: 32,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Header
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB300).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFFFB300).withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFB300),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'order_status.review_dialog_title'.tr(args: [_shopName]),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'order_status.review_subtitle'.tr(),
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: submitting ? null : () => Navigator.pop(ctx, false),
                            style: IconButton.styleFrom(
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Interactive Star Selector Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (i) {
                                final active = i < stars;
                                return GestureDetector(
                                  onTap: submitting
                                      ? null
                                      : () => setModal(() => stars = i + 1),
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 5),
                                    child: AnimatedScale(
                                      scale: active ? 1.08 : 0.94,
                                      duration: const Duration(milliseconds: 150),
                                      child: Icon(
                                        active
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        color: active
                                            ? const Color(0xFFFFB300)
                                            : (isDark ? Colors.white24 : Colors.black26),
                                        size: 36,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'order_status.rating_$stars'.tr(),
                              style: const TextStyle(
                                color: Color(0xFFFFB300),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Comment Input
                      TextField(
                        controller: commentCtrl,
                        maxLines: 3,
                        enabled: !submitting,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 13.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'order_status.review_placeholder'.tr(),
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppTheme.primary,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: OutlinedButton(
                                onPressed: submitting
                                    ? null
                                    : () => Navigator.pop(ctx, false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark ? Colors.white70 : Colors.black54,
                                  side: BorderSide(
                                    color: isDark ? Colors.white12 : Colors.black12,
                                  ),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  'common.cancel'.tr(),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppTheme.primary, AppTheme.primaryDark],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary.withValues(alpha: 0.30),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: submitting
                                    ? null
                                    : () async {
                                        setModal(() => submitting = true);
                                        final user =
                                            Supabase.instance.client.auth.currentUser;
                                        try {
                                          if (_shopId != null && _shopId!.isNotEmpty) {
                                            await Supabase.instance.client
                                                .from('reviews')
                                                .insert({
                                              'business_id': _shopId,
                                              'user_id': user?.id,
                                              'rating': stars,
                                              'comment': commentCtrl.text.trim(),
                                            });
                                          }
                                        } catch (_) {}
                                        if (ctx.mounted) Navigator.pop(ctx, true);
                                      },
                                child: submitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        'review.submit_review'.tr(),
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    commentCtrl.dispose();

    if (submitted == true && mounted) {
      setState(() => _hasReviewed = true);
      showGlassToast(context, 'order_status.review_thank_you'.tr());
    }
  }

  Future<void> _downloadPdfReceipt() async {
    if (_isDownloadingPdf) return;
    setState(() => _isDownloadingPdf = true);

    try {
      await ReceiptPdfService.downloadReceiptPdf(
        orderId: _displayOrderRef,
        shopName: _shopName,
        shopPhone: _shopPhone,
        shopAddress: _shopAddress,
        customerName: _customerName,
        customerPhone: _customerPhone,
        orderCreatedAt: _orderCreatedAt ?? DateTime.now(),
        paymentTime: _orderPaidAt,
        paymentMethod: _formatPaymentMethod(_paymentMethod),
        paymentStatus: _paymentStatus,
        fulfillmentType: _fulfillmentLabel,
        pickupTime: widget.pickupTime ?? _bookingTime,
        notes: _notes,
        items: _loadedItems,
        subtotal: _subtotal > 0 ? _subtotal : _totalAmount,
        tax: _tax,
        discount: _discount,
        totalAmount: _totalAmount,
      );

      if (mounted) {
        showGlassToast(
          context,
          'order_status.receipt_download_success'.tr(),
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        );
      }
    } catch (e) {
      debugPrint('[OrderStatusTracker] PDF download error: $e');
      if (mounted) {
        showGlassToast(
          context,
          'order_status.receipt_download_error'.tr(),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingPdf = false);
      }
    }
  }

  void _copyOrderRef(String ref) {
    Clipboard.setData(ClipboardData(text: ref));
    showGlassToast(context, 'order_status.copy_ref_success'.tr(), icon: HugeIcons.strokeRoundedCopy01);
  }

  int get _stepIndex {
    switch (_status) {
      case 'pending':
        return 0;
      case 'preparing':
      case 'in_progress':
        return 1;
      case 'ready':
        return 2;
      case 'completed':
        return 3;
      default:
        return 0;
    }
  }

  Color get _statusColor {
    switch (_status) {
      case 'pending':
        return const Color(0xFFFFB300);
      case 'preparing':
      case 'in_progress':
        return const Color(0xFF00B0FF);
      case 'ready':
        return const Color(0xFF00E676);
      case 'completed':
        return const Color(0xFF10B981);
      case 'cancelled':
        return Colors.redAccent;
      default:
        return const Color(0xFF00E5FF);
    }
  }

  String get _statusTitle {
    if (_isAwaitingOnlinePayment) {
      return 'order_status.status_awaiting_payment_title'.tr();
    }
    switch (_status) {
      case 'pending':
        return 'order_status.status_pending_title'.tr();
      case 'preparing':
      case 'in_progress':
        return 'order_status.status_preparing_title'.tr();
      case 'ready':
        return 'order_status.status_ready_title'.tr();
      case 'completed':
        return 'order_status.status_completed_title'.tr();
      case 'cancelled':
        return 'order_status.status_cancelled_title'.tr();
      default:
        return 'order_status.status_processing_title'.tr();
    }
  }

  String get _statusSubtitle {
    if (_isAwaitingOnlinePayment) {
      return 'order_status.status_awaiting_payment_sub'.tr();
    }
    switch (_status) {
      case 'pending':
        return 'order_status.status_pending_sub'.tr();
      case 'preparing':
      case 'in_progress':
        return 'order_status.status_preparing_sub'.tr();
      case 'ready':
        return 'order_status.status_ready_sub'.tr();
      case 'completed':
        return 'order_status.status_completed_sub'.tr();
      case 'cancelled':
        return _paymentStatus == 'refund_pending'
            ? 'order_status.payment_refund_pending'.tr()
            : 'order_status.status_cancelled_sub'.tr();
      default:
        return 'order_status.status_processing_sub'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

    final String displayOrderNum = _displayOrderRef;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        safeNavBack(context, fallbackRoute: '/customer-home');
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF07090E) : const Color(0xFFF4F6F9),
        body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: Supabase.instance.client
              .from('orders')
              .stream(primaryKey: ['id'])
              .eq('id', widget.orderId),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              final latest = snapshot.data!.first;
              _status = latest['status']?.toString().toLowerCase() ?? _status;
              _paymentStatus = latest['payment_status']?.toString().toLowerCase() ?? _paymentStatus;
              final latestNotes = latest['notes']?.toString();
              if (latestNotes != null && latestNotes.isNotEmpty) {
                _notes = latestNotes;
                _cancelReason = _extractCancelReason(_notes) ?? _cancelReason;
              }
            }

            final String countdownStr =
                '${(_expiryRemainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_expiryRemainingSeconds % 60).toString().padLeft(2, '0')}';

            return Stack(
              children: [
                // Scrollable Content
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 78, 20, 36),
                  child: Column(
                    children: [
                      // Status Hero Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF131822) : Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: _statusColor.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _statusColor.withValues(alpha: isDark ? 0.20 : 0.08),
                              blurRadius: 28,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Glowing status badge icon
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _statusColor.withValues(alpha: 0.14),
                                border: Border.all(color: _statusColor.withValues(alpha: 0.6), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: _statusColor.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: HugeIcon(
                                  icon: _status == 'cancelled'
                                      ? HugeIcons.strokeRoundedCancel01
                                      : (_isAwaitingOnlinePayment
                                          ? HugeIcons.strokeRoundedWallet02
                                          : (_status == 'ready' || _status == 'completed'
                                              ? HugeIcons.strokeRoundedCheckmarkCircle03
                                              : (_status == 'preparing' || _status == 'in_progress'
                                                  ? HugeIcons.strokeRoundedPackage
                                                  : HugeIcons.strokeRoundedTime02))),
                                  color: _statusColor,
                                  size: 38,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _statusTitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _statusSubtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                height: 1.4,
                              ),
                            ),

                            if (_status != 'cancelled') ...[
                              const SizedBox(height: 24),

                              // 4-Step Progress Indicator
                              Row(
                                children: [
                                  _buildStepNode('order_status.step_node_received'.tr(), 0, isDark),
                                  _buildStepLine(0, isDark),
                                  _buildStepNode('order_status.step_node_preparing'.tr(), 1, isDark),
                                  _buildStepLine(1, isDark),
                                  _buildStepNode('order_status.step_node_ready'.tr(), 2, isDark),
                                  _buildStepLine(2, isDark),
                                  _buildStepNode('order_status.step_node_completed'.tr(), 3, isDark),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // --- 0. AWAITING PAYMENT CARD (Shopee & TikTok Shop Style) ---
                      if (_isAwaitingOnlinePayment) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF131822) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.18 : 0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: HugeIcon(
                                        icon: HugeIcons.strokeRoundedWallet02,
                                        color: Color(0xFFF59E0B),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'order_status.awaiting_payment_banner_title'.tr(),
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'order_status.awaiting_payment_countdown'.tr(args: [countdownStr]),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFF59E0B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'order_status.awaiting_payment_desc'.tr(),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: () => _retryOrChangePayment(startAtMethodSelect: false),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF59E0B),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedQrCode,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                                  label: Text(
                                    'order_status.pay_now_btn'.tr(args: [currency.format(_totalAmount)]),
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: OutlinedButton.icon(
                                  onPressed: () => _retryOrChangePayment(startAtMethodSelect: true),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF00E5FF),
                                    side: BorderSide(
                                      color: const Color(0xFF00E5FF).withValues(alpha: 0.45),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedCreditCard,
                                    color: Color(0xFF00E5FF),
                                    size: 18,
                                  ),
                                  label: Text(
                                    'order_status.change_payment_method_btn'.tr(),
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ]
                      // Pickup Verification or Kitchen Preparation Card (hide if cancelled or awaiting online payment)
                      else if (_status != 'cancelled') ...[
                        if (_status == 'ready') ...[
                          // --- 1. READY FOR PICKUP: SHOW ACTIVE QR CODE ---
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF131822) : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF).withValues(alpha: isDark ? 0.25 : 0.12),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF00E676),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'order_status.qr_pickup_title'.tr(),
                                                style: TextStyle(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'order_status.qr_pickup_sub'.tr(),
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '#$displayOrderNum',
                                        style: const TextStyle(
                                          color: Color(0xFF00E5FF),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                // QR Box
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.10),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: SizedBox(
                                    width: 170,
                                    height: 170,
                                    child: QrImageView(
                                      data: 'NGAM-ORDER:${widget.orderId}',
                                      version: QrVersions.auto,
                                      eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: Color(0xFF0F172A),
                                      ),
                                      dataModuleStyle: const QrDataModuleStyle(
                                        dataModuleShape: QrDataModuleShape.square,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                GestureDetector(
                                  onTap: () => _copyOrderRef(displayOrderNum),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'ID: #$displayOrderNum',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? Colors.white54 : Colors.black54,
                                          letterSpacing: 0.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.copy_rounded, size: 12, color: isDark ? Colors.white54 : Colors.black54),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_status == 'completed') ...[
                          // --- 2. ORDER COMPLETED: SUCCESS CARD ---
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF131822) : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.greenAccent,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'order_status.completed_title'.tr(),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'order_status.completed_desc'.tr(),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // --- 3. PREPARING / PENDING: KITCHEN PREPARATION CARD ---
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF131822) : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                                  blurRadius: 18,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: HugeIcon(
                                          icon: HugeIcons.strokeRoundedPackage,
                                          color: Color(0xFF00E5FF),
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _status == 'pending'
                                                ? 'order_status.prep_title_pending'.tr()
                                                : 'order_status.prep_title_cooking'.tr(),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _status == 'pending'
                                                ? 'order_status.prep_desc_pending'.tr()
                                                : 'order_status.prep_desc_cooking'.tr(),
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.lock_outline_rounded, size: 15, color: Color(0xFF00E5FF)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'order_status.prep_badge_locked'.tr(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white70 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                      ],

                      // ====================================================
                      // ORDER & PAYMENT DETAILS CONTAINER (EXPANDED & DETAILED)
                      // ====================================================
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF131822) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Title & Quick Actions (e-Resit, Chat, WhatsApp)
                            SizedBox(
                              width: double.infinity,
                              child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const HugeIcon(
                                          icon: HugeIcons.strokeRoundedInvoice02,
                                          color: Color(0xFF00E5FF),
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'order_status.order_details_title'.tr(),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                    if (widget.orderId.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => EreceiptScreen(orderId: widget.orderId),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00E5FF).withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const HugeIcon(
                                                icon: HugeIcons.strokeRoundedInvoice01,
                                                color: Color(0xFF00E5FF),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                'order_status.action_view_ereceipt'.tr(),
                                                style: const TextStyle(
                                                  color: Color(0xFF00E5FF),
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if ((_shopId ?? widget.shopId ?? '').isNotEmpty)
                                      GestureDetector(
                                        onTap: _openShopChat,
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF42A5F5).withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: const Color(0xFF42A5F5).withValues(alpha: 0.35),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const HugeIcon(
                                                icon: HugeIcons.strokeRoundedChatting01,
                                                color: Color(0xFF42A5F5),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                'store.chat_shop'.tr(),
                                                style: const TextStyle(
                                                  color: Color(0xFF42A5F5),
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (_shopPhone != null && _shopPhone!.trim().isNotEmpty)
                                      GestureDetector(
                                        onTap: _contactShopWhatsApp,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF25D366).withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: const Color(0xFF25D366).withValues(alpha: 0.35),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const HugeIcon(
                                                icon: HugeIcons.strokeRoundedWhatsapp,
                                                color: Color(0xFF25D366),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                'order_status.contact_shop'.tr(),
                                                style: const TextStyle(
                                                  color: Color(0xFF25D366),
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            ),
                            const SizedBox(height: 16),

                            // 1. Reference No with Copy button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'order_status.reference_no'.tr(),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _copyOrderRef(displayOrderNum),
                                  behavior: HitTestBehavior.opaque,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '#$displayOrderNum',
                                          style: const TextStyle(
                                            color: Color(0xFF00E5FF),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      HugeIcon(
                                        icon: HugeIcons.strokeRoundedCopy01,
                                        size: 14,
                                        color: isDark ? Colors.white54 : Colors.black45,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            _divider(isDark),

                            // 2. Tarikh & Masa Pesanan Dibuat
                            _detailRow(
                              'order_status.order_created_at'.tr(),
                              _orderCreatedAt != null
                                  ? DateFormat('dd MMM yyyy, hh:mm a').format(_orderCreatedAt!)
                                  : DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                              isDark,
                            ),
                            _divider(isDark),

                            // 3. Tarikh & Masa Bayaran
                            _detailRow(
                              'order_status.payment_time'.tr(),
                              _orderPaidAt != null
                                  ? DateFormat('dd MMM yyyy, hh:mm a').format(_orderPaidAt!)
                                  : (_paymentStatus == 'paid'
                                      ? DateFormat('dd MMM yyyy, hh:mm a').format(_orderCreatedAt ?? DateTime.now())
                                      : 'order_status.payment_time_unpaid'.tr()),
                              isDark,
                              isHighlight: _paymentStatus == 'paid',
                            ),
                            _divider(isDark),

                            // 4. Status Bayaran
                            _detailRow(
                              'order_status.payment_status_label'.tr(),
                              _paymentStatus == 'paid'
                                  ? 'order_status.payment_paid'.tr()
                                  : (_paymentStatus == 'refund_pending'
                                      ? 'order_status.payment_refund_pending'.tr()
                                      : (_paymentStatus == 'refunded'
                                          ? 'order_status.payment_refunded'.tr()
                                          : (_paymentStatus == 'pending' && !_isCashMethod
                                              ? 'order_status.payment_pending'.tr()
                                              : 'order_status.payment_unpaid'.tr()))),
                              isDark,
                              isSuccess: _paymentStatus == 'paid',
                              isHighlight: _paymentStatus == 'pending' || _paymentStatus == 'refund_pending',
                            ),
                            _divider(isDark),

                            // 4b. Sebab Pembatalan (jika pesanan telah dibatalkan)
                            if (_status == 'cancelled' && _cancelReason != null && _cancelReason!.isNotEmpty) ...[
                              _detailRow(
                                'order_status.cancel_reason_label'.tr(),
                                _cancelReason!,
                                isDark,
                                isHighlight: true,
                              ),
                              _divider(isDark),
                            ],

                            // 5. Kaedah Bayaran
                            _detailRow(
                              'order_status.payment_method_label'.tr(),
                              _formatPaymentMethod(_paymentMethod),
                              isDark,
                            ),
                            _divider(isDark),

                            // 6. Kedai & Alamat
                            _detailRow('order_status.store_label'.tr(), _shopName, isDark),
                            if (_shopAddress != null && _shopAddress!.trim().isNotEmpty) ...[
                              _divider(isDark),
                              _detailRow('order_status.store_address'.tr(), _shopAddress!, isDark),
                            ],

                            // 7. Pilihan Ambil / Pemenuhan
                            _divider(isDark),
                            _detailRow(
                              'order_status.fulfillment_option'.tr(),
                              (_fulfillmentLabel != null && _fulfillmentLabel!.trim().isNotEmpty)
                                  ? _fulfillmentLabel!
                                  : 'order_status.fulfillment_default'.tr(),
                              isDark,
                            ),

                            // 8. Waktu Ambil / Slot Temujanji
                            if ((widget.pickupTime != null && widget.pickupTime!.isNotEmpty) ||
                                (_bookingTime != null && _bookingTime!.isNotEmpty)) ...[
                              _divider(isDark),
                              _detailRow(
                                'order_status.pickup_time_label'.tr(),
                                widget.pickupTime ?? '${_bookingDate ?? ''} $_bookingTime'.trim(),
                                isDark,
                                isHighlight: true,
                              ),
                            ],

                            // 9. Staf Bertugas
                            if (_providerName != null && _providerName!.isNotEmpty) ...[
                              _divider(isDark),
                              _detailRow('order_status.staff_assigned'.tr(), _providerName!, isDark),
                            ],

                            // 10. Nota Pelanggan
                            if (_notes != null && _notes!.trim().isNotEmpty) ...[
                              Builder(
                                builder: (_) {
                                  final cleanNote = _notes!.replaceAll(RegExp(r'\[.*?\]'), '').trim();
                                  if (cleanNote.isEmpty) return const SizedBox.shrink();
                                  return Column(
                                    children: [
                                      _divider(isDark),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: isDark ? 0.08 : 0.06),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.amber.withValues(alpha: isDark ? 0.22 : 0.16),
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            HugeIcon(
                                              icon: HugeIcons.strokeRoundedNote,
                                              size: 14,
                                              color: Colors.amber[700] ?? Colors.amber,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'order_status.customer_notes'.tr(),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    cleanNote,
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],

                            _divider(isDark),

                            // 11. Pecahan Item & Kuantiti
                            Text(
                              'order_status.items_list_title'.tr(args: [_loadedItems.length.toString()]),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 10),

                            if (_loadedItems.isNotEmpty) ...[
                              ..._loadedItems.map((item) {
                                final qty = item['qty'] ?? 1;
                                final name = item['name']?.toString() ?? 'Item';
                                final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                                final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? (qty > 0 ? (price / qty) : price);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 9),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00E5FF).withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${qty}x',
                                          style: const TextStyle(
                                            color: Color(0xFF00E5FF),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              ),
                                            ),
                                            if (qty > 1 && unitPrice > 0)
                                              Text(
                                                '@ ${currency.format(unitPrice)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark ? Colors.white38 : Colors.black38,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        currency.format(price),
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ] else ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00E5FF).withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        '1x',
                                        style: TextStyle(
                                          color: Color(0xFF00E5FF),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(
                                        _serviceName ?? 'order_status.general_order'.tr(),
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      currency.format(_totalAmount),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            _divider(isDark),

                            // 12. Financial Summary
                            _detailRow(
                              'order_status.subtotal'.tr(),
                              currency.format(_subtotal > 0 ? _subtotal : _totalAmount),
                              isDark,
                            ),
                            if (_tax > 0) ...[
                              const SizedBox(height: 6),
                              _detailRow('order_status.tax_service'.tr(), currency.format(_tax), isDark),
                            ],
                            if (_discount > 0) ...[
                              const SizedBox(height: 6),
                              _detailRow('order_status.discount'.tr(), '- ${currency.format(_discount)}', isDark, isHighlight: true),
                            ],
                            _divider(isDark),
                            _detailRow(
                              'order_status.total_amount'.tr(),
                              currency.format(_totalAmount),
                              isDark,
                              isBold: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ====================================================
                      // NGAM-STYLE BOTTOM ACTION BUTTONS
                      // ====================================================

                      // 1. Contextual Cancel Button (Pending only) - Glass Danger Style
                      if (_status == 'pending') ...[
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.4),
                              width: 1.2,
                            ),
                            color: Colors.redAccent.withValues(alpha: 0.08),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: _isCancelling ? null : _cancelPendingOrder,
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const HugeIcon(
                                      icon: HugeIcons.strokeRoundedCancel01,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isCancelling
                                          ? 'order_status.action_cancelling'.tr()
                                          : 'order_status.action_cancel_order'.tr(),
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else if ((_status == 'preparing' || _status == 'in_progress' || _status == 'ready') &&
                          _paymentStatus == 'paid') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: isDark ? 0.10 : 0.07),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.30),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'order_status.paid_preparing_cancel_info'.tr(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 42,
                                child: OutlinedButton.icon(
                                  onPressed: _handleDisputeAction,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.amber.shade700,
                                    side: BorderSide(color: Colors.amber.withValues(alpha: 0.55)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: HugeIcon(
                                    icon: HugeIcons.strokeRoundedAlert02,
                                    color: Colors.amber.shade700,
                                    size: 16,
                                  ),
                                  label: Text(
                                    'order_status.request_refund_dispute_btn'.tr(),
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // 2. Star Review Button (Completed only & not reviewed) - Gold-Accented Glass Pill
                      if (_status == 'completed' && !_hasReviewed) ...[
                        Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFFFFB300).withValues(alpha: 0.14)
                                : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFFFB300).withValues(alpha: isDark ? 0.45 : 0.55),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFB300).withValues(alpha: isDark ? 0.12 : 0.10),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: _showReviewDialog,
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      color: Color(0xFFFFB300),
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'order_status.action_review_shop'.tr(),
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF92400E),
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // 2b. Shopee-Style Dispute / 3-Way Mediation Button
                      if (_activeDispute != null ||
                          (_status != 'cancelled' && _status != 'pending')) ...[
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _activeDispute != null
                                ? const Color(0xFFA855F7).withValues(alpha: isDark ? 0.16 : 0.10)
                                : Colors.orangeAccent.withValues(alpha: isDark ? 0.12 : 0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: (_activeDispute != null
                                      ? const Color(0xFFA855F7)
                                      : Colors.orangeAccent)
                                  .withValues(alpha: 0.45),
                              width: 1.2,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: _handleDisputeAction,
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    HugeIcon(
                                      icon: _activeDispute != null
                                          ? HugeIcons.strokeRoundedMessage01
                                          : HugeIcons.strokeRoundedShield01,
                                      color: _activeDispute != null
                                          ? const Color(0xFFC084FC)
                                          : Colors.orangeAccent,
                                      size: 19,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _activeDispute != null
                                            ? 'dispute.action_view_dispute'.tr(args: [_activeDispute!.caseNumber])
                                            : 'dispute.action_open_dispute'.tr(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _activeDispute != null
                                              ? (isDark ? const Color(0xFFE9D5FF) : const Color(0xFF6B21A8))
                                              : (isDark ? Colors.orange.shade200 : Colors.orange.shade900),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // 2.5 View Full Digital e-Receipt Button (save & claim Ngam points)
                      if (widget.orderId.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: isDark ? 0.10 : 0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                              width: 1.2,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => EreceiptScreen(orderId: widget.orderId),
                                  ),
                                );
                              },
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const HugeIcon(
                                      icon: HugeIcons.strokeRoundedInvoice01,
                                      color: Color(0xFF38BDF8),
                                      size: 19,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'payment_result.view_ereceipt_btn'.tr(),
                                      style: const TextStyle(
                                        color: Color(0xFF38BDF8),
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // 3. Primary PDF Receipt Download Button - Signature Ngam Electric Blue Pill
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.34),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: _isDownloadingPdf ? null : _downloadPdfReceipt,
                            child: Center(
                              child: _isDownloadingPdf
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'order_status.action_downloading_pdf'.tr(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const HugeIcon(
                                          icon: HugeIcons.strokeRoundedInvoice01,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'order_status.action_download_pdf_receipt'.tr(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 4. Return Back Button - Signature Ngam Frosted Glass Pill
                      Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.09),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              } else {
                                Navigator.of(context).popUntil((route) => route.isFirst);
                              }
                            },
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedArrowLeft01,
                                    color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF0F172A),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'order_status.action_back'.tr(),
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Floating Glass Top Navigation Bar
                FloatingTopBar(
                  isDark: isDark,
                  fallbackRoute: '/customer-home',
                  leading: GlassNavButton.back(
                    context: context,
                    isDark: isDark,
                    fallbackRoute: '/customer-home',
                    size: 44,
                    iconSize: 20,
                  ),
                  title: _shopName,
                  subtitle: 'order_status.tracker_subtitle'.tr(),
                ),
              ],
            );
          },
        ),
      ),
    ),
    );
  }

  Widget _buildStepNode(String label, int index, bool isDark) {
    final bool isCompleted = _stepIndex >= index;
    final bool isCurrent = _stepIndex == index;

    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? _statusColor
                : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: _statusColor.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.black)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            color: isCurrent
                ? (isDark ? Colors.white : Colors.black87)
                : (isDark ? Colors.white38 : Colors.black38),
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int index, bool isDark) {
    final bool isPassed = _stepIndex > index;
    return Expanded(
      child: Container(
        height: 2.5,
        margin: const EdgeInsets.only(bottom: 16),
        color: isPassed
            ? _statusColor
            : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
      ),
    );
  }

  Widget _detailRow(String label, String value, bool isDark,
      {bool isBold = false, bool isHighlight = false, bool isSuccess = false}) {
    Color valColor = isDark ? Colors.white : const Color(0xFF0F172A);
    if (isHighlight) valColor = const Color(0xFF00E5FF);
    if (isSuccess) valColor = const Color(0xFF10B981);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: isBold ? 15 : 12.5,
              fontWeight: isBold ? FontWeight.w900 : (isHighlight ? FontWeight.bold : FontWeight.w600),
              color: valColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _divider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        height: 1.0,
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
      ),
    );
  }
}
