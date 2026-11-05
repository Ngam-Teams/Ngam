import 'package:easy_localization/easy_localization.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String? _shopId;
  double _totalAmount = 0.0;
  String? _notes;
  String? _fulfillmentLabel;
  List<Map<String, dynamic>> _loadedItems = [];
  bool _isCancelling = false;
  bool _hasReviewed = false;

  @override
  void initState() {
    super.initState();
    _shopName = widget.shopName;
    _totalAmount = widget.totalAmount;
    _shopId = widget.shopId;
    _fulfillmentLabel = widget.fulfillmentType;
    _loadedItems = List<Map<String, dynamic>>.from(widget.items);
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

            final biz = res['businesses'];
            if (biz is Map) {
              final bName = biz['business_name']?.toString() ?? '';
              if (bName.isNotEmpty) _shopName = bName;
              _shopPhone = biz['business_phone']?.toString();
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
              return {
                'name': row['product_name']?.toString() ?? 'Item',
                'qty': (row['quantity'] as num?)?.toInt() ?? 1,
                'price': (row['subtotal'] as num?)?.toDouble() ??
                    ((row['unit_price'] as num?)?.toDouble() ?? 0.0),
              };
            }).toList();
          }
        });
      }
    } catch (e) {
      debugPrint('[OrderStatusTracker] Load order error: $e');
    }
  }

  Future<void> _contactShopWhatsApp() async {
    final phoneRaw = _shopPhone ?? '';
    if (phoneRaw.trim().isEmpty) {
      showGlassToast(context, 'Nombor telefon kedai tidak dinyatakan.', isError: true);
      return;
    }
    String phone = phoneRaw.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.startsWith('0')) {
      phone = '6$phone';
    } else if (!phone.startsWith('60') && phone.length >= 9) {
      phone = '60$phone';
    }
    final shortId = widget.orderId.length > 6
        ? widget.orderId.substring(0, 6).toUpperCase()
        : widget.orderId.toUpperCase();
    final msg = Uri.encodeComponent(
      'Hai $_shopName, saya ingin bertanya tentang pesanan saya #$shortId (RM ${_totalAmount.toStringAsFixed(2)}).',
    );
    final url = Uri.parse('https://wa.me/$phone?text=$msg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      showGlassToast(context, 'Tidak dapat membuka WhatsApp.', isError: true);
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
              'Batalkan Pesanan?',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              _paymentStatus == 'paid'
                  ? 'Pesanan ini belum mula disediakan oleh dapur. Jika dibatalkan, pemulangan wang (refund) akan direkodkan untuk pesanan anda.'
                  : 'Adakah anda pasti mahu membatalkan pesanan ini sebelum kedai mula menyediakannya?',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('common.back'.tr(), style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('queue.confirm_cancel'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
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
        showGlassToast(context, 'Pesanan telah dibatalkan.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCancelling = false);
        showGlassToast(context, 'Gagal membatalkan pesanan: $e', isError: true);
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
            'Beri Ulasan kepada $_shopName',
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
                  hintText: 'Kongsi pengalaman makanan / servis anda...',
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
              child: Text('common.cancel'.tr(), style: TextStyle(color: Colors.grey)),
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
              child: Text('review.submit_review'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (submitted == true && mounted) {
      setState(() => _hasReviewed = true);
      showGlassToast(context, 'Terima kasih atas ulasan anda!');
    }
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
        return 'Pesanan Diterima';
      case 'preparing':
      case 'in_progress':
        return 'Sedang Disediakan';
      case 'ready':
        return 'Sedia Untuk Diambil!';
      case 'completed':
        return 'Pesanan Selesai';
      case 'cancelled':
        return 'Pesanan Dibatalkan';
      default:
        return 'Memproses Pesanan';
    }
  }

  String get _statusSubtitle {
    switch (_status) {
      case 'pending':
        return 'Menunggu pihak kedai mengesahkan dan memproses pesanan anda.';
      case 'preparing':
      case 'in_progress':
        return 'Staf dapur sedang menyiapkan hidangan anda dengan teliti.';
      case 'ready':
        return 'Pesanan anda sudah sedia di kaunter. Sila tunjukkan kod QR semasa mengambil.';
      case 'completed':
        return 'Terima kasih! Pesanan anda telah berjaya diambil.';
      case 'cancelled':
        return _paymentStatus == 'refund_pending'
            ? 'Pesanan telah dibatalkan. Pemulangan wang (refund) sedang diproses.'
            : 'Pesanan ini telah dibatalkan.';
      default:
        return 'Status pesanan sedang dikemas kini secara langsung.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

    final String displayOrderNum = widget.orderId.length > 8
        ? widget.orderId.substring(0, 8).toUpperCase()
        : widget.orderId.toUpperCase();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF4F6F9),
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
                  padding: const EdgeInsets.fromLTRB(20, 78, 20, 32),
                  child: Column(
                    children: [
                      // Status Hero Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161B22) : Colors.white,
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
                                  _buildStepNode('Diterima', 0, isDark),
                                  _buildStepLine(0, isDark),
                                  _buildStepNode('Disediakan', 1, isDark),
                                  _buildStepLine(1, isDark),
                                  _buildStepNode('Sedia', 2, isDark),
                                  _buildStepLine(2, isDark),
                                  _buildStepNode('Selesai', 3, isDark),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // QR Verification Code Card (hide if cancelled)
                      if (_status != 'cancelled') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161B22) : Colors.white,
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Kod Imbas Pengambilan',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tunjukkan kepada staf kedai di kaunter',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
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
                              Text(
                                'ID: ${widget.orderId}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Order Details & Itemized Breakdown
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161B22) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Butiran Pesanan',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          HugeIcon(
                                            icon: HugeIcons.strokeRoundedWhatsapp,
                                            color: Color(0xFF25D366),
                                            size: 14,
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            'Hubungi Kedai',
                                            style: TextStyle(
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
                            const SizedBox(height: 14),
                            _detailRow('Kedai', _shopName, isDark),
                            _divider(isDark),
                            _detailRow('Pilihan Ambil', _fulfillmentLabel ?? 'Takeaway / Bungkus', isDark),
                            if (widget.pickupTime != null && widget.pickupTime!.isNotEmpty) ...[
                              _divider(isDark),
                              _detailRow('Waktu Ambil', widget.pickupTime!, isDark, isHighlight: true),
                            ],
                            _divider(isDark),
                            _detailRow(
                              'Status Bayaran',
                              _paymentStatus == 'paid'
                                  ? 'SUDAH DIBAYAR (${_paymentMethod.toUpperCase()})'
                                  : (_paymentStatus == 'refund_pending'
                                      ? 'PEMULANGAN WANG (REFUND)'
                                      : 'BAYAR DI KAUNTER (${_paymentStatus.toUpperCase()})'),
                              isDark,
                              isSuccess: _paymentStatus == 'paid',
                            ),
                            if (_loadedItems.isNotEmpty) ...[
                              _divider(isDark),
                              Text(
                                'Senarai Item (${_loadedItems.length})',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ..._loadedItems.map((item) {
                                final qty = item['qty'] ?? 1;
                                final name = item['name']?.toString() ?? 'Item';
                                final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                                return Padding(
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
                                        child: Text(
                                          '${qty}x',
                                          style: const TextStyle(
                                            color: Color(0xFF00E5FF),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
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
                            ],
                            _divider(isDark),
                            _detailRow('Jumlah Keseluruhan', currency.format(_totalAmount), isDark,
                                isBold: true),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Contextual Action Buttons (Cancel if pending, Review if completed)
                      if (_status == 'pending') ...[
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.6)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _isCancelling ? null : _cancelPendingOrder,
                            icon: const HugeIcon(
                              icon: HugeIcons.strokeRoundedCancel01,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            label: Text(
                              _isCancelling ? 'Membatalkan...' : 'Batalkan Pesanan Ini',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (_status == 'completed' && !_hasReviewed) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFB300),
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _showReviewDialog,
                            icon: const Icon(Icons.star_rounded, color: Colors.black, size: 22),
                            label: const Text(
                              'Beri Ulasan & Bintang Kedai',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Return Home Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            }
                          },
                          child: const Text(
                            'Kembali',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Floating Glass Top Navigation Bar
                FloatingTopBar(
                  isDark: isDark,
                  leading: GlassNavButton.back(
                    context: context,
                    isDark: isDark,
                    size: 44,
                    iconSize: 20,
                  ),
                  title: _shopName,
                  subtitle: 'Penjejakan Pesanan',
                  actions: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100),
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.75),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : Colors.black.withValues(alpha: 0.08),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _statusColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _statusTitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
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
            fontSize: 10,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent
                ? (isDark ? Colors.white : Colors.black)
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
