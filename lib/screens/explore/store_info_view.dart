import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:ngam/widgets/glass_box.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/glass_toast.dart';

// ============================================================
// StoreInfoView — Store Information, Realtime 7-Day Hours & Holiday Closures
// ============================================================
class StoreInfoView extends StatefulWidget {
  final Map<String, dynamic> shop;

  const StoreInfoView({super.key, required this.shop});

  @override
  State<StoreInfoView> createState() => _StoreInfoViewState();
}

class _StoreInfoViewState extends State<StoreInfoView> {
  Map<String, dynamic>? _operatingHours;

  @override
  void initState() {
    super.initState();
    if (widget.shop['operating_hours'] is Map) {
      _operatingHours = Map<String, dynamic>.from(widget.shop['operating_hours'] as Map);
    }
    _fetchLiveOperatingHours();
  }

  Future<void> _fetchLiveOperatingHours() async {
    final businessId = widget.shop['id'] ?? widget.shop['business_id'];
    if (businessId == null) return;

    try {
      final res = await Supabase.instance.client
          .from('business_settings')
          .select('operating_hours')
          .eq('business_id', businessId)
          .maybeSingle();

      if (res != null && res['operating_hours'] is Map && mounted) {
        setState(() {
          _operatingHours = Map<String, dynamic>.from(res['operating_hours'] as Map);
        });
      }
    } catch (e) {
      debugPrint('Error loading live operating hours in StoreInfoView: $e');
    }
  }

  LiquidGlassSettings _glassSettings(bool isDark, {double blur = 2.0}) {
    return LiquidGlassSettings(
      thickness: 0.1,
      blur: blur,
      refractiveIndex: 1.0,
      glassColor: Colors.transparent,
      lightAngle: 45.0,
      lightIntensity: isDark ? 0.1 : 0.2,
      ambientStrength: 1.0,
      saturation: 1.0,
      chromaticAberration: 0.0,
    );
  }

  Widget _liquidGlassBox({
    required bool isDark,
    required Widget child,
    double radius = 20,
    EdgeInsetsGeometry? padding,
  }) {
    return GlassContainer(
      useOwnLayer: true,
      quality: GlassQuality.standard,
      shape: LiquidRoundedSuperellipse(borderRadius: radius),
      settings: _glassSettings(isDark),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.4),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.5),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  void _launchUrlHelper(BuildContext context, String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) showGlassToast(context, 'Could not open link', isError: true);
      }
    } catch (e) {
      if (context.mounted) showGlassToast(context, 'Error opening application', isError: true);
    }
  }

  String _formatTimeString(String? timeStr) {
    if (timeStr == null || !timeStr.contains(':')) return '9:00 AM';
    final parts = timeStr.split(':');
    final int h = int.tryParse(parts[0]) ?? 9;
    final int m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final period = h >= 12 ? 'PM' : 'AM';
    int hour = h % 12;
    if (hour == 0) hour = 12;
    return '$hour:${m.toString().padLeft(2, '0')} $period';
  }

  String _formatTime(int h, int m) {
    final period = h >= 12 ? 'PM' : 'AM';
    int hour = h % 12;
    if (hour == 0) hour = 12;
    return '${hour.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final Color textSecondary = isDark ? Colors.white60 : const Color(0xFF3A3A3C).withValues(alpha: 0.7);

    final shop = widget.shop;
    final String shopName = shop['name'] ?? 'Store Information';
    final String category = (shop['category'] ?? 'Business').toString().toUpperCase();
    final String address = shop['address'] ?? 'Lot 12, Jalan Telawi 3, Bangsar, 59100 Kuala Lumpur';
    final String phone = shop['phone'] ?? '+60 12-345 6789';
    final String desc = shop['description'] ??
        'Welcome to $shopName. We provide quality services and premium products crafted with dedication and authentic craftsmanship.';

    int effectiveOpenH = shop['openHour'] ?? 9;
    int effectiveOpenM = shop['openMinute'] ?? 0;
    int effectiveCloseH = shop['closeHour'] ?? 22;
    int effectiveCloseM = shop['closeMinute'] ?? 0;

    final String? liveOpenStr = _operatingHours?['open_time']?.toString();
    final String? liveCloseStr = _operatingHours?['close_time']?.toString();
    if (liveOpenStr != null && liveOpenStr.contains(':')) {
      final p = liveOpenStr.split(':');
      effectiveOpenH = int.tryParse(p[0]) ?? effectiveOpenH;
      effectiveOpenM = p.length > 1 ? int.tryParse(p[1]) ?? effectiveOpenM : effectiveOpenM;
    }
    if (liveCloseStr != null && liveCloseStr.contains(':')) {
      final p = liveCloseStr.split(':');
      effectiveCloseH = int.tryParse(p[0]) ?? effectiveCloseH;
      effectiveCloseM = p.length > 1 ? int.tryParse(p[1]) ?? effectiveCloseM : effectiveCloseM;
    }

    final String fallbackDailyHours = '${_formatTime(effectiveOpenH, effectiveOpenM)} - ${_formatTime(effectiveCloseH, effectiveCloseM)}';

    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final currentDayIndex = DateTime.now().weekday - 1; // 0 for Monday

    // Parse live schedule and rush mode
    final bool isRushMode = _operatingHours?['is_rush_mode'] == true;
    final List? weeklySchedule = _operatingHours?['weekly_schedule'] as List?;
    final List? specialHolidays = _operatingHours?['special_holidays'] as List?;

    final amenities = [
      {'icon': Icons.mosque_outlined, 'label': 'Surau Available'},
      {'icon': Icons.wifi_rounded, 'label': 'High-Speed Wi-Fi'},
      {'icon': Icons.local_parking_rounded, 'label': 'Dedicated Parking'},
      {'icon': Icons.ac_unit_rounded, 'label': 'Air Conditioned'},
      {'icon': Icons.verified_rounded, 'label': 'Halal Certified'},
      {'icon': Icons.qr_code_rounded, 'label': 'Cashless & DuitNow'},
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: _liquidGlassBox(
                      isDark: isDark,
                      radius: 100,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedArrowLeft01,
                            color: textPrimary,
                            size: 22,
                            strokeWidth: 2.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Store Information',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          shopName,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchLiveOperatingHours,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  children: [
                  // Store Hero Card
                  _liquidGlassBox(
                    isDark: isDark,
                    radius: 24,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: shop['image'] != null && shop['image'].toString().isNotEmpty
                                    ? Image.network(shop['image'], fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackAvatar())
                                    : _fallbackAvatar(),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    shopName,
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    category,
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          desc,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick Action Buttons (Call, WhatsApp)
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _launchUrlHelper(context, 'tel:${phone.replaceAll(RegExp(r'\s+'), '')}'),
                          child: _liquidGlassBox(
                            isDark: isDark,
                            radius: 18,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.call_rounded, color: Colors.blue, size: 18),
                                const SizedBox(width: 8),
                                Text('Call Store', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
                            _launchUrlHelper(context, 'https://wa.me/$cleanPhone');
                          },
                          child: _liquidGlassBox(
                            isDark: isDark,
                            radius: 18,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green, size: 18),
                                const SizedBox(width: 8),
                                Text('WhatsApp', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Rush Hour / Paused Store Banner (if active)
                  if (isRushMode) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.pause_circle_filled_rounded, color: Colors.redAccent, size: 22),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kedai Sibuk Sementara Waktu',
                                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Pesanan & tempahan baru ditangguhkan seketika oleh peniaga.',
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Operating Hours (Full 7 Days)
                  _liquidGlassBox(
                    isDark: isDark,
                    radius: 24,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const HugeIcon(icon: HugeIcons.strokeRoundedTime02, color: Colors.blue, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Waktu Operasi Mingguan',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...days.asMap().entries.map((entry) {
                          final int idx = entry.key;
                          final String day = entry.value;
                          final bool isToday = idx == currentDayIndex;

                          // Extract day specific hours from weekly schedule
                          bool isOpen = true;
                          String dayHours = fallbackDailyHours;

                          if (weeklySchedule != null && weeklySchedule.isNotEmpty) {
                            final match = weeklySchedule.firstWhere(
                              (item) => item is Map && item['day']?.toString().toLowerCase() == day.toLowerCase(),
                              orElse: () => null,
                            );

                            if (match != null && match is Map) {
                              isOpen = match['isOpen'] != false;
                              if (isOpen) {
                                final o = match['open']?.toString();
                                final c = match['close']?.toString();
                                dayHours = '${_formatTimeString(o)} – ${_formatTimeString(c)}';
                              } else {
                                dayHours = 'TUTUP / CLOSED';
                              }
                            }
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? (isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.08))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: isToday ? Border.all(color: Colors.blue.withValues(alpha: 0.3)) : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      day,
                                      style: TextStyle(
                                        color: isToday ? Colors.blue : textPrimary,
                                        fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (isToday) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('Hari Ini', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  dayHours,
                                  style: TextStyle(
                                    color: !isOpen
                                        ? Colors.redAccent
                                        : (isToday ? Colors.blue : textSecondary),
                                    fontWeight: (!isOpen || isToday) ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Cuti Peristiwa & Perayaan (Festive & Holiday Closures)
                  _liquidGlassBox(
                    isDark: isDark,
                    radius: 24,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const HugeIcon(icon: HugeIcons.strokeRoundedCalendar03, color: Colors.amber, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Cuti Peristiwa & Perayaan',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Makluman penutupan khas sempena perayaan atau cuti peristiwa am.',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 14),

                        if (specialHolidays == null || specialHolidays.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Tiada cuti peristiwa khas dijadualkan. Kedai dibuka mengikut jadual mingguan biasa.',
                                    style: TextStyle(color: textSecondary, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...specialHolidays.map((holiday) {
                            if (holiday is! Map) return const SizedBox.shrink();
                            final name = holiday['name']?.toString() ?? 'Cuti Khas';
                            final date = holiday['date']?.toString() ?? '';
                            final isClosed = holiday['isClosed'] != false;
                            final note = holiday['note']?.toString();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: isDark ? 0.08 : 0.05),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.celebration_rounded, color: Colors.amber, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$date • ${isClosed ? 'Tutup Sepanjang Hari' : 'Waktu Terhad'}${note != null && note.isNotEmpty ? ' ($note)' : ''}',
                                          style: TextStyle(color: textSecondary, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Location & Address
                  _liquidGlassBox(
                    isDark: isDark,
                    radius: 24,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const HugeIcon(icon: HugeIcons.strokeRoundedLocation01, color: Colors.blue, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Location & Address',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          address,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () {
                              final query = Uri.encodeComponent('$shopName $address');
                              _launchUrlHelper(context, 'https://www.google.com/maps/search/?api=1&query=$query');
                            },
                            icon: const Icon(Icons.directions_rounded, size: 18),
                            label: const Text('Get Directions in Maps', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Store Facilities / Amenities
                  _liquidGlassBox(
                    isDark: isDark,
                    radius: 24,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkBadge01, color: Colors.blue, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Store Facilities & Features',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: amenities.map((item) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(item['icon'] as IconData, color: Colors.blue, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    item['label'] as String,
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: Colors.blue.withValues(alpha: 0.1),
      child: const Center(
        child: Icon(Icons.storefront_rounded, color: Colors.blue, size: 28),
      ),
    );
  }
}
