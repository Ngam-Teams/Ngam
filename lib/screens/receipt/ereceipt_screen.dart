import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/ereceipt_service.dart';
import '../../services/receipt_pdf_service.dart';
import '../../utils/glass_toast.dart';
import '../../utils/ngam_ref.dart';
import '../../utils/payment_method_formatter.dart';
import '../../widgets/glass_nav_button.dart';
import '../explore/store_route_loader.dart';
import 'my_receipts_screen.dart';

class EreceiptScreen extends StatefulWidget {
  final Uri? uri;
  final String? orderId;
  final Map<String, dynamic>? initialReceipt;
  final bool openedFromArchive;

  const EreceiptScreen({
    super.key,
    this.uri,
    this.orderId,
    this.initialReceipt,
    this.openedFromArchive = false,
  });

  @override
  State<EreceiptScreen> createState() => _EreceiptScreenState();
}

class _EreceiptScreenState extends State<EreceiptScreen> {
  late Map<String, dynamic> _receipt;
  bool _isLoading = true;
  bool _isClaiming = false;
  bool _isDownloadingPdf = false;
  bool _isClaimed = false;
  int _pointsEarned = 0;

  @override
  void initState() {
    super.initState();
    _initReceipt();
  }

  String _resolveReceiptRef(Map<String, dynamic> r) {
    final existingRef = (r['ref'] ?? '').toString().trim().replaceAll('#', '');
    if (NgamRef.isValid(existingRef)) {
      return existingRef.toUpperCase();
    }
    final oid = (r['order_id'] ?? widget.orderId ?? '').toString().trim();
    final createdDt = DateTime.tryParse((r['created_at'] ?? r['date'] ?? '').toString());
    final src = (r['source'] ?? '').toString().toLowerCase();
    if (oid.isNotEmpty) {
      if (NgamRef.isBookingReference(oid)) {
        return NgamRef.booking(oid, createdDt);
      }
      if (src == 'pos') {
        return NgamRef.pos(oid, createdDt);
      }
      return NgamRef.order(oid, createdAt: createdDt);
    }
    if (existingRef.isNotEmpty) {
      return src == 'online'
          ? NgamRef.order(existingRef, createdAt: createdDt)
          : NgamRef.pos(existingRef, createdDt);
    }
    return NgamRef.pos(null, createdDt);
  }

  Future<void> _initReceipt() async {
    await EreceiptService.init();

    Map<String, dynamic> base;
    if (widget.initialReceipt != null) {
      base = Map<String, dynamic>.from(widget.initialReceipt!);
    } else if (widget.uri != null) {
      base = EreceiptService.buildReceiptFromUri(widget.uri!);
    } else {
      final oid = (widget.orderId ?? '').trim();
      final shortRef = oid.isNotEmpty ? NgamRef.order(oid) : NgamRef.pos();
      base = {
        if (oid.isNotEmpty) 'order_id': oid,
        'ref': shortRef,
        'shop_name': 'ereceipt.default_shop'.tr(),
        'total': 0.0,
        'subtotal': 0.0,
        'payment_method': 'DuitNow QR',
        'payment_status': 'paid',
        'date': DateTime.now().toIso8601String(),
        'items': <Map<String, dynamic>>[],
        'source': oid.isNotEmpty ? 'online' : 'scanned',
      };
    }

    final existingSaved = EreceiptService.findSavedReceipt(base);
    if (existingSaved != null) {
      base = {
        ...base,
        ...existingSaved,
        if ((base['items'] is List) && (base['items'] as List).isNotEmpty &&
            ((existingSaved['items'] as List?)?.isEmpty ?? true))
          'items': base['items'],
      };
    }
    base['ref'] = _resolveReceiptRef(base);

    _receipt = base;
    _refreshClaimState();
    if (mounted) setState(() => _isLoading = false);

    await _enrichFromSupabase();
    await _autoClaimIfEligible();
  }

  bool get _isEligibleForPoints => EreceiptService.isReceiptEligibleForPoints(_receipt);

  void _refreshClaimState() {
    final total = (_receipt['total'] as num?)?.toDouble() ?? 0.0;
    final claimed = _receipt['points_claimed'] == true ||
        EreceiptService.isReceiptSavedOrClaimed(_receipt);
    final savedMatch = EreceiptService.findSavedReceipt(_receipt);
    _isClaimed = claimed;
    _pointsEarned = (savedMatch?['points_earned'] as num?)?.toInt() ??
        (_receipt['points_earned'] as num?)?.toInt() ??
        EreceiptService.computePoints(total);
  }

  Future<void> _autoClaimIfEligible() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _isClaimed || !_isEligibleForPoints) return;

    final res = await EreceiptService.saveAndClaimReceipt(_receipt);
    if (!mounted) return;
    setState(() {
      _receipt = Map<String, dynamic>.from(res['receipt'] as Map);
      _isClaimed = true;
      _pointsEarned = (res['pointsEarned'] as num?)?.toInt() ?? _pointsEarned;
    });
    if (res['alreadyClaimed'] != true) {
      showGlassToast(
        context,
        'ereceipt.auto_claimed_toast'.tr(args: [_pointsEarned.toString()]),
        icon: HugeIcons.strokeRoundedSparkles,
      );
    }
  }

  Future<void> _enrichFromSupabase() async {
    final client = Supabase.instance.client;
    final oid = (_receipt['order_id'] ?? widget.orderId ?? '').toString().trim();

    if (oid.isNotEmpty) {
      try {
        final orderRes = await client
            .from('orders')
            .select(
              '*, businesses(id, business_name, business_handle, business_logo_url, business_phone, address_line)',
            )
            .eq('id', oid)
            .maybeSingle();

        if (orderRes != null && mounted) {
          final biz = orderRes['businesses'] is Map
              ? Map<String, dynamic>.from(orderRes['businesses'] as Map)
              : null;

          List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
            (_receipt['items'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
          );
          try {
            final itemRows = await client
                .from('order_items')
                .select('product_name, quantity, unit_price, subtotal')
                .eq('order_id', oid);
            if ((itemRows as List).isNotEmpty) {
              items = itemRows
                  .map((r) => {
                        'name': r['product_name']?.toString() ?? 'ereceipt.default_item'.tr(),
                        'qty': (r['quantity'] as num?)?.toInt() ?? 1,
                        'unit_price': (r['unit_price'] as num?)?.toDouble() ?? 0.0,
                        'price': (r['subtotal'] as num?)?.toDouble() ?? 0.0,
                      })
                  .toList();
            }
          } catch (_) {}

          final createdDt = DateTime.tryParse((orderRes['created_at'] ?? '').toString());
          final isPos = (orderRes['source'] ?? '').toString().toLowerCase() == 'pos';
          final resolvedRef = isPos
              ? NgamRef.pos(oid, createdDt)
              : NgamRef.order(oid, createdAt: createdDt);

          setState(() {
            _receipt['ref'] = resolvedRef;
            _receipt['created_at'] = orderRes['created_at'] ?? _receipt['created_at'];
            _receipt['source'] = isPos ? 'pos' : (_receipt['source'] ?? 'online');
            _receipt['business_id'] = orderRes['business_id']?.toString() ?? _receipt['business_id'];
            if (biz != null) {
              _receipt['shop_name'] = biz['business_name'] ?? _receipt['shop_name'];
              _receipt['store_handle'] = (biz['business_handle'] ?? _receipt['store_handle'] ?? '')
                  .toString()
                  .replaceAll('@', '');
              _receipt['shop_logo'] = biz['business_logo_url'] ?? _receipt['shop_logo'];
              _receipt['shop_phone'] = biz['business_phone'] ?? _receipt['shop_phone'];
              _receipt['shop_address'] = biz['address_line'] ?? _receipt['shop_address'];
            }
            _receipt['total'] = (orderRes['total'] as num?)?.toDouble() ?? _receipt['total'];
            _receipt['subtotal'] = (orderRes['subtotal'] as num?)?.toDouble() ?? _receipt['subtotal'];
            _receipt['payment_method'] = orderRes['payment_method'] ?? _receipt['payment_method'];
            _receipt['payment_status'] = orderRes['payment_status'] ?? _receipt['payment_status'];
            _receipt['status'] = orderRes['status'] ?? _receipt['status'];
            _receipt['date'] = orderRes['paid_at'] ?? orderRes['created_at'] ?? _receipt['date'];
            _receipt['notes'] = orderRes['notes'] ?? _receipt['notes'];
            if (items.isNotEmpty) _receipt['items'] = items;
            _refreshClaimState();
          });
          return;
        }
      } catch (_) {}
    }

    // Try resolving business profile by bid or store_handle
    final bid = (_receipt['business_id'] ?? '').toString().trim();
    final handle = (_receipt['store_handle'] ?? '').toString().replaceAll('@', '').trim().toLowerCase();
    if (bid.isEmpty && handle.isEmpty) return;

    try {
      Map<String, dynamic>? biz;
      if (bid.length >= 20) {
        biz = await client
            .from('businesses')
            .select('id, business_name, business_handle, business_logo_url, business_phone, address_line')
            .eq('id', bid)
            .maybeSingle();
      }
      if (biz == null && handle.isNotEmpty) {
        biz = await client
            .from('businesses')
            .select('id, business_name, business_handle, business_logo_url, business_phone, address_line')
            .eq('business_handle', handle)
            .maybeSingle();
      }
      if (biz != null && mounted) {
        setState(() {
          _receipt['business_id'] = biz!['id']?.toString() ?? _receipt['business_id'];
          final bName = biz['business_name']?.toString().trim() ?? '';
          if (bName.isNotEmpty &&
              (_receipt['shop_name'] == null ||
                  _receipt['shop_name'].toString().trim().isEmpty ||
                  _receipt['shop_name'].toString().toLowerCase() == handle)) {
            _receipt['shop_name'] = bName;
          }
          _receipt['store_handle'] =
              (biz['business_handle'] ?? _receipt['store_handle'] ?? '').toString().replaceAll('@', '');
          _receipt['shop_logo'] = biz['business_logo_url'] ?? _receipt['shop_logo'];
          _receipt['shop_phone'] = biz['business_phone'] ?? _receipt['shop_phone'];
          _receipt['shop_address'] = biz['address_line'] ?? _receipt['shop_address'];
        });
      }
    } catch (_) {}
  }

  Future<void> _handleClaimAndSave() async {
    if (_isClaiming) return;
    if (_isClaimed) {
      showGlassToast(context, 'ereceipt.already_claimed_toast'.tr());
      return;
    }

    setState(() => _isClaiming = true);
    final res = await EreceiptService.saveAndClaimReceipt(_receipt);
    if (!mounted) return;
    setState(() {
      _isClaiming = false;
      _receipt = Map<String, dynamic>.from(res['receipt'] as Map);
      _isClaimed = true;
      _pointsEarned = (res['pointsEarned'] as num?)?.toInt() ?? _pointsEarned;
    });

    if (res['alreadyClaimed'] == true) {
      showGlassToast(context, 'ereceipt.already_claimed_toast'.tr());
    } else {
      showGlassToast(
        context,
        'ereceipt.claimed_toast'.tr(args: [_pointsEarned.toString()]),
      );
    }
  }

  Future<void> _handleDownloadPdf() async {
    if (_isDownloadingPdf) return;
    setState(() => _isDownloadingPdf = true);
    try {
      final rawItems = (_receipt['items'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          <Map<String, dynamic>>[];
      final createdDt = DateTime.tryParse(
            (_receipt['created_at'] ?? _receipt['date'] ?? '').toString(),
          )?.toLocal() ??
          DateTime.now();
      final dt = DateTime.tryParse((_receipt['date'] ?? '').toString())?.toLocal() ?? createdDt;
      final resolvedRef = _resolveReceiptRef(_receipt);
      final tax = ((_receipt['tax'] as num?)?.toDouble() ?? 0.0) +
          ((_receipt['service_charge'] as num?)?.toDouble() ?? 0.0);

      await ReceiptPdfService.downloadReceiptPdf(
        orderId: resolvedRef,
        shopName: (_receipt['shop_name'] ?? 'ereceipt.default_shop'.tr()).toString(),
        shopPhone: _receipt['shop_phone']?.toString(),
        shopAddress: _receipt['shop_address']?.toString(),
        paymentMethod: PaymentMethodFormatter.format(_receipt['payment_method']?.toString()),
        paymentStatus: (_receipt['payment_status'] ?? 'paid').toString(),
        orderCreatedAt: createdDt,
        paymentTime: dt,
        tableNumber: _receipt['table_number']?.toString(),
        notes: _receipt['notes']?.toString(),
        items: rawItems,
        subtotal: (_receipt['subtotal'] as num?)?.toDouble() ??
            (_receipt['total'] as num?)?.toDouble() ??
            0.0,
        tax: tax,
        discount: (_receipt['discount'] as num?)?.toDouble() ?? 0.0,
        totalAmount: (_receipt['total'] as num?)?.toDouble() ?? 0.0,
      );
      if (mounted) {
        showGlassToast(context, 'ereceipt.pdf_success_toast'.tr());
      }
    } catch (_) {
      if (mounted) {
        showGlassToast(context, 'ereceipt.pdf_error_toast'.tr(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isDownloadingPdf = false);
    }
  }

  void _visitStore() {
    final target = (_receipt['business_id']?.toString().trim().isNotEmpty == true)
        ? _receipt['business_id'].toString().trim()
        : (_receipt['store_handle']?.toString().trim() ?? '');
    if (target.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoreRouteLoader(businessId: target),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0D16) : const Color(0xFFF4F7FC);
    final cardColor = isDark ? const Color(0xFF131926) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : Colors.black.withValues(alpha: 0.07);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);

    final shopName = (_receipt['shop_name'] ?? 'ereceipt.default_shop'.tr()).toString();
    final refNo = _resolveReceiptRef(_receipt);
    final method = PaymentMethodFormatter.format(_receipt['payment_method']?.toString());
    final total = (_receipt['total'] as num?)?.toDouble() ?? 0.0;
    final items = (_receipt['items'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        <Map<String, dynamic>>[];
    final rawSubtotal = (_receipt['subtotal'] as num?)?.toDouble() ?? 0.0;
    final itemsSum = items.fold<double>(0.0, (acc, item) {
      final linePrice = ((item['price'] ?? item['subtotal']) as num?)?.toDouble();
      if (linePrice != null && linePrice > 0) return acc + linePrice;
      final qty = (item['qty'] as num?)?.toInt() ?? 1;
      final unit = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
      return acc + (unit * qty);
    });
    final subtotal = rawSubtotal > 0
        ? rawSubtotal
        : (itemsSum > 0 ? itemsSum : total);
    final tax = (_receipt['tax'] as num?)?.toDouble() ?? 0.0;
    final svc = (_receipt['service_charge'] as num?)?.toDouble() ?? 0.0;
    final rounding = (_receipt['rounding'] as num?)?.toDouble() ?? 0.0;
    final rawDiscount = (_receipt['discount'] as num?)?.toDouble() ?? 0.0;
    final discount = rawDiscount > 0
        ? rawDiscount
        : (subtotal > total + 0.009 && tax == 0 && svc == 0
            ? double.parse((subtotal - total).toStringAsFixed(2))
            : 0.0);

    final dt = DateTime.tryParse((_receipt['date'] ?? '').toString())?.toLocal() ?? DateTime.now();
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    final hasStoreTarget =
        (_receipt['business_id']?.toString().trim().isNotEmpty == true) ||
            (_receipt['store_handle']?.toString().trim().isNotEmpty == true);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Top Header Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        GlassNavButton.back(context: context, isDark: isDark),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'ereceipt.title'.tr(),
                            style: GoogleFonts.outfit(
                              color: textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!widget.openedFromArchive)
                          GlassNavButton(
                            icon: HugeIcons.strokeRoundedInvoice01,
                            tooltip: 'ereceipt.view_all_receipts_btn'.tr(),
                            isDark: isDark,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MyReceiptsScreen(),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                            children: [
                              // Ngam Points Banner Card
                              ValueListenableBuilder<int>(
                                valueListenable: EreceiptService.totalPointsNotifier,
                                builder: (context, totalBalance, _) {
                                  final isPending = !_isClaimed && !_isEligibleForPoints;
                                  final accent = _isClaimed
                                      ? const Color(0xFF10B981)
                                      : (isPending
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF3B82F6));
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          accent.withValues(alpha: isDark ? 0.22 : 0.14),
                                          accent.withValues(alpha: isDark ? 0.08 : 0.05),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: accent.withValues(alpha: 0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: HugeIcon(
                                              icon: _isClaimed
                                                  ? HugeIcons.strokeRoundedCheckmarkCircle02
                                                  : (isPending
                                                      ? HugeIcons.strokeRoundedTime02
                                                      : HugeIcons.strokeRoundedSparkles),
                                              color: accent,
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
                                                _isClaimed
                                                    ? 'ereceipt.points_claimed_title'
                                                        .tr(args: [_pointsEarned.toString()])
                                                    : (isPending
                                                        ? 'ereceipt.points_pending_title'
                                                            .tr(args: [_pointsEarned.toString()])
                                                        : 'ereceipt.points_ready_title'
                                                            .tr(args: [_pointsEarned.toString()])),
                                                style: GoogleFonts.outfit(
                                                  color: textPrimary,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _isClaimed
                                                    ? 'ereceipt.points_claimed_subtitle'.tr(
                                                        args: [totalBalance.toString()],
                                                      )
                                                    : (isPending
                                                        ? 'ereceipt.points_pending_subtitle'.tr()
                                                        : 'ereceipt.points_ready_subtitle'.tr()),
                                                style: TextStyle(
                                                  color: textSecondary,
                                                  fontSize: 12,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),

                              // Main Official Digital Receipt Card
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: borderColor),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Merchant Header
                                    Row(
                                      children: [
                                        _buildShopAvatar(
                                          _receipt['shop_logo']?.toString(),
                                          shopName,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                shopName,
                                                style: GoogleFonts.outfit(
                                                  color: textPrimary,
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 3),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981).withValues(alpha: 0.14),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const HugeIcon(
                                                      icon: HugeIcons.strokeRoundedCheckmarkBadge01,
                                                      color: Color(0xFF10B981),
                                                      size: 13,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'ereceipt.verified_badge'.tr(),
                                                      style: const TextStyle(
                                                        color: Color(0xFF10B981),
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    if ((_receipt['shop_address'] ?? '').toString().trim().isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        _receipt['shop_address'].toString(),
                                        style: TextStyle(color: textSecondary, fontSize: 12),
                                      ),
                                    ],

                                    Divider(height: 28, color: borderColor),

                                    // Reference & Date Meta Rows
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'ereceipt.receipt_no_label'.tr(),
                                          style: TextStyle(color: textSecondary, fontSize: 12.5),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(text: refNo));
                                            showGlassToast(
                                              context,
                                              'order_status.copy_ref_success'.tr(),
                                              icon: HugeIcons.strokeRoundedCopy01,
                                            );
                                          },
                                          behavior: HitTestBehavior.opaque,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '#$refNo',
                                                style: TextStyle(
                                                  color: const Color(0xFF00E5FF),
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.4,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              HugeIcon(
                                                icon: HugeIcons.strokeRoundedCopy01,
                                                color: textSecondary,
                                                size: 14,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _buildMetaRow(
                                      'ereceipt.date_time_label'.tr(),
                                      dateStr,
                                      textSecondary,
                                      textPrimary,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildMetaRow(
                                      'ereceipt.payment_method_label'.tr(),
                                      method,
                                      textSecondary,
                                      textPrimary,
                                    ),
                                    if ((_receipt['table_number'] ?? '').toString().trim().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      _buildMetaRow(
                                        'ereceipt.table_label'.tr(),
                                        '#${_receipt['table_number']}',
                                        textSecondary,
                                        textPrimary,
                                      ),
                                    ],

                                    Divider(height: 28, color: borderColor),

                                    // Itemized Section
                                    Text(
                                      'ereceipt.items_header'.tr(),
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (items.isEmpty)
                                      _buildItemRow(
                                        '1x',
                                        'ereceipt.default_item'.tr(),
                                        'RM ${total.toStringAsFixed(2)}',
                                        textPrimary,
                                        textSecondary,
                                      )
                                    else
                                      ...items.map((item) {
                                        final qty = (item['qty'] ?? item['quantity'] ?? 1).toString();
                                        final name = (item['name'] ??
                                                item['product_name'] ??
                                                'ereceipt.default_item'.tr())
                                            .toString();
                                        final lineTotal =
                                            ((item['price'] ?? item['subtotal']) as num?)?.toDouble() ??
                                                0.0;
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: _buildItemRow(
                                            '${qty}x',
                                            name,
                                            'RM ${lineTotal.toStringAsFixed(2)}',
                                            textPrimary,
                                            textSecondary,
                                          ),
                                        );
                                      }),

                                    Divider(height: 26, color: borderColor),

                                    // Totals Breakdown
                                    _buildMetaRow(
                                      'ereceipt.subtotal_label'.tr(),
                                      'RM ${subtotal.toStringAsFixed(2)}',
                                      textSecondary,
                                      textPrimary,
                                    ),
                                    if (tax > 0) ...[
                                      const SizedBox(height: 6),
                                      _buildMetaRow(
                                        'ereceipt.tax_label'.tr(),
                                        'RM ${tax.toStringAsFixed(2)}',
                                        textSecondary,
                                        textPrimary,
                                      ),
                                    ],
                                    if (svc > 0) ...[
                                      const SizedBox(height: 6),
                                      _buildMetaRow(
                                        'ereceipt.service_charge_label'.tr(),
                                        'RM ${svc.toStringAsFixed(2)}',
                                        textSecondary,
                                        textPrimary,
                                      ),
                                    ],
                                    if (rounding != 0) ...[
                                      const SizedBox(height: 6),
                                      _buildMetaRow(
                                        'ereceipt.rounding_label'.tr(),
                                        '${rounding < 0 ? '-' : ''}RM ${rounding.abs().toStringAsFixed(2)}',
                                        textSecondary,
                                        textPrimary,
                                      ),
                                    ],
                                    if (discount > 0) ...[
                                      const SizedBox(height: 6),
                                      _buildMetaRow(
                                        'ereceipt.discount_label'.tr(),
                                        '- RM ${discount.toStringAsFixed(2)}',
                                        textSecondary,
                                        const Color(0xFF10B981),
                                      ),
                                    ],
                                    const SizedBox(height: 14),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.05)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'ereceipt.total_paid_label'.tr(),
                                            style: GoogleFonts.outfit(
                                              color: textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            'RM ${total.toStringAsFixed(2)}',
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFF3B82F6),
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Center(
                                      child: Text(
                                        'ereceipt.footer_verified'.tr(),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),

                              // Primary Claim & Save Button (auto-credited when logged in & paid; manual for guests)
                              if (_isClaimed || _isEligibleForPoints) ...[
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    onPressed: _isClaiming ? null : _handleClaimAndSave,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isClaimed
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    icon: _isClaiming
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : HugeIcon(
                                            icon: _isClaimed
                                                ? HugeIcons.strokeRoundedCheckmarkCircle02
                                                : HugeIcons.strokeRoundedBookmarkAdd02,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                    label: Text(
                                      _isClaimed
                                          ? 'ereceipt.already_saved_btn'
                                              .tr(args: [_pointsEarned.toString()])
                                          : 'ereceipt.claim_save_btn'
                                              .tr(args: [_pointsEarned.toString()]),
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Secondary Action Row: Download PDF & Visit Store / My Receipts
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _isDownloadingPdf ? null : _handleDownloadPdf,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: textPrimary,
                                        side: BorderSide(color: borderColor),
                                        padding: const EdgeInsets.symmetric(vertical: 13),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      icon: _isDownloadingPdf
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const HugeIcon(
                                              icon: HugeIcons.strokeRoundedDownload04,
                                              size: 18,
                                            ),
                                      label: Text(
                                        'ereceipt.download_pdf_btn'.tr(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (hasStoreTarget) ...[
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _visitStore,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: textPrimary,
                                          side: BorderSide(color: borderColor),
                                          padding: const EdgeInsets.symmetric(vertical: 13),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                        icon: const HugeIcon(
                                          icon: HugeIcons.strokeRoundedStore01,
                                          size: 18,
                                        ),
                                        label: Text(
                                          'ereceipt.visit_store_btn'.tr(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (!widget.openedFromArchive) ...[
                                const SizedBox(height: 10),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const MyReceiptsScreen(),
                                      ),
                                    );
                                  },
                                  icon: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedInvoice01,
                                    size: 17,
                                    color: Color(0xFF38BDF8),
                                  ),
                                  label: Text(
                                    'ereceipt.view_all_receipts_btn'.tr(),
                                    style: const TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildShopAvatar(String? logoUrl, String shopName) {
    final initial = shopName.trim().isNotEmpty ? shopName.trim()[0].toUpperCase() : 'N';
    final hasUrl = logoUrl != null && logoUrl.trim().startsWith('http');
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF00E5FF)],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasUrl
          ? Image.network(
              logoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ),
    );
  }

  Widget _buildMetaRow(
    String label,
    String value,
    Color labelColor,
    Color valueColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 13)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: valueColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(
    String qty,
    String name,
    String price,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            qty,
            style: const TextStyle(
              color: Color(0xFF3B82F6),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              color: textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          price,
          style: TextStyle(
            color: textSecondary,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
