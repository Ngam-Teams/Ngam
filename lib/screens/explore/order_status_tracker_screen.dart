import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../widgets/glass_nav_button.dart';

class OrderStatusTrackerScreen extends StatefulWidget {
  final String orderId;
  final String shopName;
  final double totalAmount;
  final String? pickupTime;
  final String? fulfillmentType;
  final List<Map<String, dynamic>> items;

  const OrderStatusTrackerScreen({
    super.key,
    required this.orderId,
    required this.shopName,
    required this.totalAmount,
    this.pickupTime,
    this.fulfillmentType,
    this.items = const [],
  });

  @override
  State<OrderStatusTrackerScreen> createState() => _OrderStatusTrackerScreenState();
}

class _OrderStatusTrackerScreenState extends State<OrderStatusTrackerScreen> {
  String _status = 'pending'; // 'pending', 'preparing', 'ready', 'completed', 'cancelled'
  String _paymentStatus = 'paid';

  @override
  void initState() {
    super.initState();
    _loadOrderData();
  }

  void _loadOrderData() async {
    try {
      final res = await Supabase.instance.client
          .from('orders')
          .select('*, businesses(business_name, business_phone, business_address)')
          .eq('id', widget.orderId)
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
                    _status = res['status']?.toString().toLowerCase() ?? 'pending';
          _paymentStatus = res['payment_status']?.toString().toLowerCase() ?? 'paid';
                  });
      } else if (mounted) {
        // loaded
      }
    } catch (e) {
      debugPrint('[OrderStatusTracker] Load order error: $e');
      if (mounted) {}
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
        return 'Pesanan ini telah dibatalkan.';
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
                                  icon: _status == 'ready' || _status == 'completed'
                                      ? HugeIcons.strokeRoundedCheckmarkCircle03
                                      : (_status == 'preparing' || _status == 'in_progress'
                                          ? HugeIcons.strokeRoundedRestaurant01
                                          : HugeIcons.strokeRoundedTime02),
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
                        ),
                      ),

                      const SizedBox(height: 18),

                      // QR Verification Code Card
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

                      // Order Details Breakdown
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
                            Text(
                              'Butiran Pesanan',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _detailRow('Kedai', widget.shopName, isDark),
                            _divider(isDark),
                            _detailRow('Pilihan Ambil', widget.fulfillmentType ?? 'Takeaway / Bungkus', isDark),
                            if (widget.pickupTime != null && widget.pickupTime!.isNotEmpty) ...[
                              _divider(isDark),
                              _detailRow('Waktu Ambil', widget.pickupTime!, isDark, isHighlight: true),
                            ],
                            _divider(isDark),
                            _detailRow('Status Bayaran', _paymentStatus.toUpperCase(), isDark,
                                isSuccess: _paymentStatus == 'paid'),
                            _divider(isDark),
                            _detailRow('Jumlah Keseluruhan', currency.format(widget.totalAmount), isDark,
                                isBold: true),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

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
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          },
                          child: const Text(
                            'Kembali ke Halaman Utama',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Floating Glass Top Navigation Bar
                Positioned(
                  top: 12,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GlassNavButton(
                        icon: HugeIcons.strokeRoundedArrowLeft01,
                        isDark: isDark,
                        onTap: () => Navigator.pop(context),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
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
                              'Penjejakan Langsung',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 44), // Balances the left button
                    ],
                  ),
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
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 12.5,
            fontWeight: isBold ? FontWeight.w900 : (isHighlight ? FontWeight.bold : FontWeight.w600),
            color: valColor,
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
