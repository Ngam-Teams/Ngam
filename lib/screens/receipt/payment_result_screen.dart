import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../explore/business_store_view.dart';
import '../explore/order_status_tracker_screen.dart';
import '../../models/product_model.dart';
import '../../services/chip_payment_service.dart';
import '../../services/store_cart_service.dart';
import 'ereceipt_screen.dart';

class PaymentResultScreen extends StatefulWidget {
  final String status; // 'success', 'failed', 'cancel'
  final String? orderId;

  const PaymentResultScreen({
    super.key,
    required this.status,
    this.orderId,
  });

  @override
  State<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends State<PaymentResultScreen> {
  Map<String, dynamic>? _orderData;
  Map<String, dynamic>? _businessData;
  List<Map<String, dynamic>> _orderItems = [];
  String? _fulfillmentLabel;
  bool _verifiedPaidOverride = false;

  bool get isSuccess =>
      _verifiedPaidOverride ||
      widget.status.toLowerCase() == 'success' ||
      widget.status.toLowerCase() == 'paid' ||
      (_orderData?['payment_status']?.toString().toLowerCase() == 'paid');
  bool get isCancelled =>
      !isSuccess &&
      (widget.status.toLowerCase() == 'cancel' || widget.status.toLowerCase() == 'cancelled');

  @override
  void initState() {
    super.initState();
    if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      _fetchOrderDetails();
    }
  }

  Future<void> _fetchOrderDetails() async {
    final rawId = widget.orderId!.trim();
    if (rawId.isEmpty) return;

    final db = Supabase.instance.client;
    Map<String, dynamic>? orderRow;
    Map<String, dynamic>? bizRow;
    List<Map<String, dynamic>> items = [];
    bool isBookingRecord = false;

    // 1. Fetch order row (joined with valid businesses columns; fallback to plain select)
    try {
      orderRow = await db
          .from('orders')
          .select('*, businesses(*)')
          .eq('id', rawId)
          .maybeSingle();
    } catch (_) {
      try {
        orderRow = await db
            .from('orders')
            .select('*, businesses(id, business_name, business_phone, address_line)')
            .eq('id', rawId)
            .maybeSingle();
      } catch (_) {
        try {
          orderRow = await db
              .from('orders')
              .select('*')
              .eq('id', rawId)
              .maybeSingle();
        } catch (_) {}
      }
    }

    // 2. Fallback to bookings table if not found in orders (e.g. RZRV-... booking checkout redirect)
    if (orderRow == null) {
      try {
        Map<String, dynamic>? bRes;
        try {
          bRes = await db
              .from('bookings')
              .select('*, businesses(*)')
              .eq('id', rawId)
              .maybeSingle();
        } catch (_) {}
        bRes ??= await db
            .from('bookings')
            .select('*, businesses(*)')
            .eq('booking_metadata->>short_ref', rawId)
            .maybeSingle();
        if (bRes != null) {
          isBookingRecord = true;
          orderRow = {
            ...bRes,
            'total': bRes['total_price'],
          };
        }
      } catch (_) {}
    }

    if (orderRow != null) {
      if (orderRow['businesses'] is Map) {
        bizRow = Map<String, dynamic>.from(orderRow['businesses'] as Map);
      } else if (orderRow['business_id'] != null) {
        try {
          final fetchedBiz = await db
              .from('businesses')
              .select('*')
              .eq('id', orderRow['business_id'].toString())
              .maybeSingle();
          if (fetchedBiz != null) {
            bizRow = Map<String, dynamic>.from(fetchedBiz);
          }
        } catch (_) {}
      }

      // 3. Fetch order_items independently so item list is always preserved
      if (!isBookingRecord) {
        try {
          final itemsRes = await db
              .from('order_items')
              .select()
              .eq('order_id', orderRow['id'].toString());
          if ((itemsRes as List).isNotEmpty) {
            items = itemsRes.map<Map<String, dynamic>>((row) {
              return Map<String, dynamic>.from(row as Map);
            }).toList();
          }
        } catch (_) {}
      }

      // 4. Verify & settle CHIP purchase status on Same-Tab Redirect (_self)
      final String chipPurchaseId = isBookingRecord
          ? ((orderRow['booking_metadata'] is Map
                      ? (orderRow['booking_metadata'] as Map)['chip_purchase_id']
                      : null)
                  ?.toString()
                  .trim() ??
              '')
          : (orderRow['chip_purchase_id']?.toString().trim() ?? '');

      bool confirmedPaid = widget.status.toLowerCase() == 'success' ||
          widget.status.toLowerCase() == 'paid' ||
          orderRow['payment_status']?.toString().toLowerCase() == 'paid';

      if (chipPurchaseId.isNotEmpty) {
        if (confirmedPaid) {
          // Trigger server-side verification & settlement in case webhook is still in flight
          try {
            await ChipPaymentService.instance.checkPurchaseStatus(chipPurchaseId);
          } catch (_) {}
        } else {
          // User returned via /receipt/cancel or /receipt/failed -> check & cancel CHIP session safely
          try {
            final cancelStatus = await ChipPaymentService.instance.cancelPurchase(
              chipPurchaseId,
              orderId: orderRow['id']?.toString() ?? rawId,
            );
            if (cancelStatus == 'paid') {
              confirmedPaid = true;
              _verifiedPaidOverride = true;
            }
          } catch (_) {}
        }
      }

      final bizId = orderRow['business_id']?.toString() ?? '';
      if (confirmedPaid) {
        if (!isBookingRecord && orderRow['payment_status']?.toString().toLowerCase() != 'paid') {
          try {
            await db
                .from('orders')
                .update({'payment_status': 'paid'})
                .eq('id', orderRow['id'].toString());
            orderRow['payment_status'] = 'paid';
          } catch (_) {}
        }
        if (bizId.isNotEmpty) {
          StoreCartService.clearShop(bizId);
        }
      } else {
        // Payment was cancelled or failed on CHIP redirect:
        // Cancel unpaid draft order / holding booking so merchant doesn't receive a ghost order,
        // and restore cart items into StoreCartService so user can retry immediately.
        if (!isBookingRecord) {
          try {
            await db
                .from('orders')
                .update({'status': 'cancelled', 'payment_status': 'pending'})
                .eq('id', orderRow['id'].toString())
                .neq('payment_status', 'paid');
          } catch (_) {}
          if (bizId.isNotEmpty && items.isNotEmpty && StoreCartService.countForShop(bizId) == 0) {
            for (final it in items) {
              final pId = it['product_id']?.toString() ?? it['id']?.toString() ?? '';
              final pName = it['product_name']?.toString() ?? it['name']?.toString() ?? 'Item';
              final qtyNum = it['quantity'] ?? it['qty'] ?? 1;
              final int qty = qtyNum is num ? qtyNum.toInt() : (int.tryParse(qtyNum.toString()) ?? 1);
              final double unitPrice = (it['unit_price'] as num?)?.toDouble() ??
                  (((it['subtotal'] ?? it['price']) as num?)?.toDouble() ?? 0.0) / (qty > 0 ? qty : 1);
              StoreCartService.addItem(
                bizId,
                ProductModel(
                  id: pId,
                  shopId: bizId,
                  name: pName,
                  price: unitPrice,
                ),
                quantity: qty,
              );
            }
          }
        } else if (orderRow['status']?.toString().toLowerCase() == 'holding') {
          final meta = orderRow['booking_metadata'];
          final metaPaid = meta is Map && meta['payment_status']?.toString().toLowerCase() == 'paid';
          if (!metaPaid) {
            try {
              await db.from('bookings').delete().eq('id', orderRow['id'].toString());
            } catch (_) {
              try {
                await db.from('bookings').update({'status': 'cancelled'}).eq('id', orderRow['id'].toString());
              } catch (_) {}
            }
          }
        }
      }
    }

    String? parsedFulfillment;
    final notesStr = orderRow?['notes']?.toString();
    if (notesStr != null && notesStr.isNotEmpty) {
      final match = RegExp(r'\[([^\]]+)\]').firstMatch(notesStr);
      if (match != null) {
        parsedFulfillment = match.group(1);
      }
    }

    if (mounted) {
      setState(() {
        _orderData = orderRow;
        _businessData = bizRow;
        _orderItems = items;
        _fulfillmentLabel = parsedFulfillment;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final DateTime? orderDate = _orderData?['paid_at'] != null
        ? DateTime.tryParse(_orderData!['paid_at'].toString())?.toLocal()
        : (_orderData?['created_at'] != null
            ? DateTime.tryParse(_orderData!['created_at'].toString())?.toLocal()
            : null);
    final nowStr = DateFormat('dd MMM yyyy, hh:mm a').format(orderDate ?? DateTime.now());

    final totalAmount = (_orderData?['total'] as num?)?.toDouble();
    final shopName = _businessData?['business_name']?.toString() ?? 'Kedai Ngam';
    final displayOrderId = widget.orderId?.isNotEmpty == true ? widget.orderId! : 'CHIP-TEST';

    final Color statusColor = isSuccess
        ? const Color(0xFF10B981)
        : (isCancelled ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    final String titleText = isSuccess
        ? 'payment_result.success_title'.tr()
        : (isCancelled ? 'payment_result.cancelled_title'.tr() : 'payment_result.failed_title'.tr());

    final String subtitleText = isSuccess
        ? 'payment_result.success_subtitle'.tr()
        : (isCancelled
            ? 'payment_result.cancelled_subtitle'.tr()
            : 'payment_result.failed_subtitle'.tr());

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      },
      child: Scaffold(
        backgroundColor: dark ? const Color(0xFF0A0E17) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Status Header Badge
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withValues(alpha: 0.12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.25),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: isSuccess
                          ? HugeIcons.strokeRoundedCheckmarkCircle02
                          : (isCancelled
                              ? HugeIcons.strokeRoundedAlertCircle
                              : HugeIcons.strokeRoundedCancel01),
                      color: statusColor,
                      size: 46,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  titleText,
                  style: TextStyle(
                    color: dark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    subtitleText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: dark ? Colors.white70 : const Color(0xFF64748B),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Digital Receipt Card (Glassmorphism)
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF131D2E).withValues(alpha: 0.75) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedTicket01,
                                    color: dark ? Colors.white70 : Colors.black54,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'RESIT PEMBAYARAN',
                                    style: TextStyle(
                                      color: dark ? Colors.white60 : Colors.black45,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isSuccess ? 'SELESAI' : (isCancelled ? 'BATAL' : 'GAGAL'),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 28),

                          _buildReceiptRow('payment_result.order_id'.tr(), displayOrderId, dark),
                          const SizedBox(height: 12),
                          _buildReceiptRow('store.store_information'.tr(), shopName, dark),
                          const SizedBox(height: 12),
                          _buildReceiptRow('payment_result.date_time'.tr(), nowStr, dark),
                          const SizedBox(height: 12),
                          _buildReceiptRow('payment_result.payment_method'.tr(), 'CHIP DuitNow QR / FPX', dark),

                          if (totalAmount != null) ...[
                            const Divider(height: 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'payment_result.total_paid'.tr(),
                                  style: TextStyle(
                                    color: dark ? Colors.white70 : const Color(0xFF475569),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'RM ${totalAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
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
                const SizedBox(height: 32),

                // Action Buttons
                if (isSuccess && widget.orderId != null && widget.orderId!.isNotEmpty) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => OrderStatusTrackerScreen(
                              orderId: _orderData?['id']?.toString() ?? widget.orderId!,
                              shopId: _orderData?['business_id']?.toString(),
                              shopName: shopName,
                              totalAmount: totalAmount ?? 0.0,
                              paymentMethod: _orderData?['payment_method']?.toString(),
                              fulfillmentType: _fulfillmentLabel,
                              items: _orderItems,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedDeliveryTruck01,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: Text(
                        'payment_result.track_order_btn'.tr(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EreceiptScreen(orderId: widget.orderId!),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        side: BorderSide(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedInvoice01,
                        color: Color(0xFF38BDF8),
                        size: 19,
                      ),
                      label: Text(
                        'payment_result.view_ereceipt_btn'.tr(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (!isSuccess && _businessData != null) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => BusinessStoreView(
                              shop: _businessData!,
                              autoShowPromoPopup: false,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedStore01,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: Text(
                        'payment_result.return_to_store_btn'.tr(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: dark ? Colors.white : const Color(0xFF0F172A),
                      side: BorderSide(
                        color: dark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'payment_result.back_home_btn'.tr(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildReceiptRow(String label, String value, bool dark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: dark ? Colors.white60 : const Color(0xFF64748B),
            fontSize: 13,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: dark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
