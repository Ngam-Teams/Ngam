import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../explore/order_status_tracker_screen.dart';

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

  bool get isSuccess => widget.status.toLowerCase() == 'success' || widget.status.toLowerCase() == 'paid';
  bool get isCancelled => widget.status.toLowerCase() == 'cancel' || widget.status.toLowerCase() == 'cancelled';

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

    try {
      final res = await Supabase.instance.client
          .from('orders')
          .select('*, businesses(id, business_name, business_phone, business_address)')
          .eq('id', rawId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _orderData = res;
          if (res != null && res['businesses'] is Map) {
            _businessData = res['businesses'] as Map<String, dynamic>;
          }
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final nowStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    final totalAmount = (_orderData?['total'] as num?)?.toDouble();
    final shopName = _businessData?['business_name']?.toString() ?? 'Kedai Ngam';
    final displayOrderId = widget.orderId?.isNotEmpty == true ? widget.orderId! : 'CHIP-TEST';

    final Color statusColor = isSuccess
        ? const Color(0xFF10B981)
        : (isCancelled ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    final String titleText = isSuccess
        ? 'Pembayaran Berjaya!'
        : (isCancelled ? 'Pembayaran Dibatalkan' : 'Pembayaran Gagal');

    final String subtitleText = isSuccess
        ? 'Terima kasih, transaksi anda telah disahkan dan diproses dengan selamat.'
        : (isCancelled
            ? 'Anda telah membatalkan sesi pembayaran ini. Sila cuba lagi bila bersedia.'
            : 'Transaksi anda tidak dapat diselesaikan. Sila semak baki atau cuba kaedah lain.');

    return Scaffold(
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

                          _buildReceiptRow('Rujukan Pesanan', displayOrderId, dark),
                          const SizedBox(height: 12),
                          _buildReceiptRow('Peniaga / Kedai', shopName, dark),
                          const SizedBox(height: 12),
                          _buildReceiptRow('Tarikh & Masa', nowStr, dark),
                          const SizedBox(height: 12),
                          _buildReceiptRow('Kaedah Bayaran', 'CHIP (DuitNow QR / FPX)', dark),

                          if (totalAmount != null) ...[
                            const Divider(height: 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Jumlah Dibayar',
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
                              orderId: widget.orderId!,
                              shopName: shopName,
                              totalAmount: totalAmount ?? 0.0,
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
                      label: const Text(
                        'Jejak Pesanan Sekarang',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
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
                    child: const Text(
                      'Kembali ke Laman Utama',
                      style: TextStyle(
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
