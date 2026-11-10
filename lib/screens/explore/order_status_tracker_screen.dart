import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/receipt_pdf_service.dart';
import '../../widgets/glass_nav_button.dart';
import '../../widgets/glass_toast.dart';

class OrderStatusTrackerScreen extends StatefulWidget {
  final String orderId;
  final String shopName;
  final double totalAmount;
  final String? pickupTime;
  final String? fulfillmentType;
  final List<Map<String, dynamic>> items;
  final String? shopId;

  const OrderStatusTrackerScreen({
    super.key,
    required this.orderId,
    this.shopName = 'Pesanan Ngam',
    this.totalAmount = 0.0,
    this.pickupTime,
    this.fulfillmentType,
    this.items = const [],
    this.shopId,
  });

  @override
  State<OrderStatusTrackerScreen> createState() => _OrderStatusTrackerScreenState();
}

class _OrderStatusTrackerScreenState extends State<OrderStatusTrackerScreen> {
  String _status = 'pending'; // 'pending', 'preparing', 'ready', 'completed', 'cancelled'
  String _paymentStatus = 'paid';
  String _paymentMethod = 'online';
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

  @override
  void initState() {
    super.initState();
    _shopName = widget.shopName;
    _totalAmount = widget.totalAmount;
    _shopId = widget.shopId;
    _fulfillmentLabel = widget.fulfillmentType;
    if (widget.items.isNotEmpty) {
      _loadedItems = widget.items.map((it) => _normalizeItem(it)).toList();
      _subtotal = _loadedItems.fold(0.0, (acc, it) => acc + ((it['price'] as num?)?.toDouble() ?? 0.0));
    }
    _loadOrderData();
  }

  void _loadOrderData() async {
    try {
      final res = await Supabase.instance.client
          .from('orders')
          .select('*, businesses(id, business_name, business_phone, business_address)')
          .eq('id', widget.orderId)
          .maybeSingle();

      final itemsRes = await Supabase.instance.client
          .from('order_items')
          .select()
          .eq('order_id', widget.orderId);

      if (mounted) {
        setState(() {
          if (res != null) {
            _status = res['status']?.toString().toLowerCase() ?? 'pending';
            _paymentStatus = res['payment_status']?.toString().toLowerCase() ?? 'paid';
            _paymentMethod = res['payment_method']?.toString().toLowerCase() ?? 'online';
            _totalAmount = (res['total'] as num?)?.toDouble() ?? _totalAmount;
            _notes = res['notes']?.toString();
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

            final biz = res['businesses'];
            if (biz is Map) {
              final bName = biz['business_name']?.toString() ?? '';
              if (bName.isNotEmpty) _shopName = bName;
              _shopPhone = biz['business_phone']?.toString();
              _shopAddress = biz['business_address']?.toString();
            }

            if ((_fulfillmentLabel == null || _fulfillmentLabel!.isEmpty) && _notes != null) {
              final match = RegExp(r'\[([^\]]+)\]').firstMatch(_notes!);
              if (match != null) {
                _fulfillmentLabel = match.group(1);
              }
            }
          }

          if ((itemsRes as List).isNotEmpty) {
            _loadedItems = itemsRes.map<Map<String, dynamic>>((row) {
              return _normalizeItem(Map<String, dynamic>.from(row as Map));
            }).toList();
          }

          if (res == null) {
            _loadBookingFallback();
          } else {
            _calculateSubtotal();
          }
        });
      }
    } catch (e) {
      debugPrint('[OrderStatusTracker] Load order error: $e');
      if (mounted) {
        _loadBookingFallback();
      }
    }
  }

  void _loadBookingFallback() async {
    try {
      final bRes = await Supabase.instance.client
          .from('bookings')
          .select('*, businesses(id, business_name, business_phone, business_address)')
          .eq('id', widget.orderId)
          .maybeSingle();

      if (bRes != null && mounted) {
        setState(() {
          _status = bRes['status']?.toString().toLowerCase() ?? _status;
          _totalAmount = (bRes['total_price'] as num?)?.toDouble() ?? _totalAmount;
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
          if (meta['payment_status'] != null) {
            _paymentStatus = meta['payment_status'].toString().toLowerCase();
          }
          if (meta['payment_method'] != null) {
            _paymentMethod = meta['payment_method'].toString();
          }
          if (meta['provider_name'] != null) {
            _providerName = meta['provider_name'].toString();
          }
          _fulfillmentLabel = meta['category']?.toString() ?? 'Tempahan Perkhidmatan';

          final biz = bRes['businesses'];
          if (biz is Map) {
            final bName = biz['business_name']?.toString() ?? '';
            if (bName.isNotEmpty) _shopName = bName;
            _shopPhone = biz['business_phone']?.toString() ?? _shopPhone;
            _shopAddress = biz['business_address']?.toString() ?? _shopAddress;
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
    final shortId = widget.orderId.length > 8
        ? widget.orderId.substring(0, 8).toUpperCase()
        : widget.orderId.toUpperCase();
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
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'order_status.cancel_confirm_title'.tr(),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              _paymentStatus == 'paid'
                  ? 'order_status.cancel_confirm_desc_paid'.tr()
                  : 'order_status.cancel_confirm_desc_unpaid'.tr(),
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('order_status.cancel_btn_back'.tr(), style: const TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('order_status.cancel_btn_confirm'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;
    setState(() => _isCancelling = true);
    try {
      await Supabase.instance.client.from('orders').update({
        'status': 'cancelled',
        if (_paymentStatus == 'paid') 'payment_status': 'refund_pending',
      }).eq('id', widget.orderId);

      // Pulihkan stok produk fizikal bagi pesanan yang dibatalkan
      try {
        final items = await Supabase.instance.client
            .from('order_items')
            .select('product_id, quantity')
            .eq('order_id', widget.orderId);
        for (final row in (items as List)) {
          final prodId = row['product_id']?.toString();
          final qty = (row['quantity'] as num?)?.toInt() ?? 0;
          if (prodId != null && prodId.isNotEmpty && qty > 0) {
            final prod = await Supabase.instance.client
                .from('business_products')
                .select('stock, track_inventory, item_type')
                .eq('id', prodId)
                .maybeSingle();
            if (prod != null &&
                prod['item_type'] != 'service' &&
                (prod['track_inventory'] as bool? ?? true)) {
              final curStock = (prod['stock'] as num?)?.toInt() ?? 0;
              await Supabase.instance.client
                  .from('business_products')
                  .update({'stock': curStock + qty})
                  .eq('id', prodId);
            }
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _status = 'cancelled';
          if (_paymentStatus == 'paid') _paymentStatus = 'refund_pending';
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
    final commentCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'order_status.review_dialog_title'.tr(args: [_shopName]),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    onPressed: () => setModal(() => stars = i + 1),
                    icon: Icon(
                      i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: const Color(0xFFFFB300),
                      size: 34,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'order_status.review_placeholder'.tr(),
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common.cancel'.tr(), style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final user = Supabase.instance.client.auth.currentUser;
                try {
                  if (_shopId != null && _shopId!.isNotEmpty) {
                    await Supabase.instance.client.from('reviews').insert({
                      'business_id': _shopId,
                      'user_id': user?.id,
                      'rating': stars,
                      'comment': commentCtrl.text.trim(),
                    });
                  }
                } catch (_) {}
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: Text('review.submit_review'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

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
        orderId: widget.orderId,
        shopName: _shopName,
        shopPhone: _shopPhone,
        shopAddress: _shopAddress,
        customerName: _customerName,
        customerPhone: _customerPhone,
        orderCreatedAt: _orderCreatedAt ?? DateTime.now(),
        paymentTime: _orderPaidAt,
        paymentMethod: _paymentMethod,
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

    final String displayOrderNum = widget.orderId.length > 8
        ? widget.orderId.substring(0, 8).toUpperCase()
        : widget.orderId.toUpperCase();

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
            }

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
                                      : (_status == 'ready' || _status == 'completed'
                                          ? HugeIcons.strokeRoundedCheckmarkCircle03
                                          : (_status == 'preparing' || _status == 'in_progress'
                                              ? HugeIcons.strokeRoundedRestaurant01
                                              : HugeIcons.strokeRoundedTime02)),
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

                      // Pickup Verification or Kitchen Preparation Card (hide if cancelled)
                      if (_status != 'cancelled') ...[
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
                                  onTap: () => _copyOrderRef(widget.orderId),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'ID: #${widget.orderId.length > 12 ? widget.orderId.substring(0, 12).toUpperCase() : widget.orderId.toUpperCase()}',
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
                                          icon: HugeIcons.strokeRoundedRestaurant01,
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
                            // Header: Title & WhatsApp Contact
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
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
                                  onTap: () => _copyOrderRef(widget.orderId),
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
                                  ? 'order_status.payment_paid'.tr(args: [_paymentMethod.toUpperCase()])
                                  : (_paymentStatus == 'refund_pending'
                                      ? 'order_status.payment_refund_pending'.tr()
                                      : 'order_status.payment_unpaid'.tr(args: [_paymentMethod.toUpperCase()])),
                              isDark,
                              isSuccess: _paymentStatus == 'paid',
                            ),
                            _divider(isDark),

                            // 5. Kaedah Bayaran
                            _detailRow(
                              'order_status.payment_method_label'.tr(),
                              _paymentMethod.toUpperCase(),
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
                              _fulfillmentLabel ?? 'Bungkus / Takeaway',
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
                      ],

                      // 2. Star Review Button (Completed only & not reviewed) - Warm Gold Glow Gradient Pill
                      if (_status == 'completed' && !_hasReviewed) ...[
                        Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.30),
                                blurRadius: 16,
                                offset: const Offset(0, 5),
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
                                    const Icon(Icons.star_rounded, color: Colors.white, size: 22),
                                    const SizedBox(width: 8),
                                    Text(
                                      'order_status.action_review_shop'.tr(),
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
                      ],

                      // 3. Primary PDF Receipt Download Button - Signature Ngam Neon Glow Pill
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00E5FF), Color(0xFF0284C7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.28),
                              blurRadius: 18,
                              offset: const Offset(0, 5),
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
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'order_status.action_downloading_pdf'.tr(),
                                          style: const TextStyle(
                                            color: Colors.black,
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
                                          color: Colors.black,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'order_status.action_download_pdf_receipt'.tr(),
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w900,
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
