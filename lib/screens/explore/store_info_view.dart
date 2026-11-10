import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:ngam/widgets/glass_box.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/glass_toast.dart';
import '../../widgets/glass_nav_button.dart';

// ============================================================
// StoreInfoView — Store Information & Dynamic Operating Schedule
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
    final String shopName = (shop['business_name'] ?? shop['trading_name'] ?? shop['name'] ?? 'store.store_information'.tr()).toString();
    final String category = (shop['business_industry'] ?? shop['category'] ?? 'Business').toString().toUpperCase();
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

    final String fallbackDailyHours = '${_formatTime(effectiveOpenH, effectiveOpenM)} – ${_formatTime(effectiveCloseH, effectiveCloseM)}';

    const daysEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final now = DateTime.now();

    // Parse live schedule and rush mode
    final bool isRushMode = _operatingHours?['is_rush_mode'] == true;
    final List? weeklySchedule = _operatingHours?['weekly_schedule'] as List?;
    final List? specialHolidays = _operatingHours?['special_holidays'] as List?;

    // Build 7-day schedule with TODAY dynamically at the top (Google Maps style)
    final orderedDays = List.generate(7, (offset) {
      final date = now.add(Duration(days: offset));
      final int weekdayIndex = date.weekday - 1; // 0 for Monday .. 6 for Sunday
      final String dayEn = daysEn[weekdayIndex];
      final String dayKey = 'days.${dayEn.toLowerCase()}';
      final String dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final bool isToday = offset == 0;

      // 1. Check if this date has a special holiday or festive closure
      Map<String, dynamic>? matchingHoliday;
      if (specialHolidays != null) {
        for (final h in specialHolidays) {
          if (h is Map && h['date']?.toString().trim() == dateStr) {
            matchingHoliday = Map<String, dynamic>.from(h);
            break;
          }
        }
      }

      bool isOpen = true;
      bool isHoliday = false;
      String? holidayName;
      String dayHours = fallbackDailyHours;

      if (matchingHoliday != null) {
        final bool isClosed =
            matchingHoliday['isClosed'] != false && matchingHoliday['is_closed'] != false;
        holidayName = matchingHoliday['name']?.toString() ?? 'store.holiday_closure'.tr();
        if (isClosed) {
          isOpen = false;
          isHoliday = true;
          dayHours = 'store.closed_holiday'.tr(args: [holidayName]);
        }
      }

      if (!isHoliday) {
        if (weeklySchedule != null && weeklySchedule.isNotEmpty) {
          final match = weeklySchedule.firstWhere(
            (item) => item is Map && item['day']?.toString().toLowerCase() == dayEn.toLowerCase(),
            orElse: () => null,
          );

          if (match != null && match is Map) {
            isOpen = match['isOpen'] != false && match['is_open'] != false;
            if (isOpen) {
              final o = match['open']?.toString();
              final c = match['close']?.toString();
              dayHours = '${_formatTimeString(o)} – ${_formatTimeString(c)}';
            } else {
              dayHours = 'store.closed'.tr();
            }
          }
        }
      }

      return {
        'dayKey': dayKey,
        'date': date,
        'isToday': isToday,
        'isOpen': isOpen,
        'isHoliday': isHoliday,
        'holidayName': holidayName,
        'dayHours': dayHours,
      };
    });

    final amenities = [
      {'icon': HugeIcons.strokeRoundedMosque01, 'labelKey': 'store.amenity_surau'},
      {'icon': HugeIcons.strokeRoundedWifi01, 'labelKey': 'store.amenity_wifi'},
      {'icon': HugeIcons.strokeRoundedCarParking01, 'labelKey': 'store.amenity_parking'},
      {'icon': HugeIcons.strokeRoundedSnow, 'labelKey': 'store.amenity_ac'},
      {'icon': HugeIcons.strokeRoundedHalal, 'labelKey': 'store.amenity_halal'},
      {'icon': HugeIcons.strokeRoundedQrCode, 'labelKey': 'store.amenity_cashless'},
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        safeNavBack(context, fallbackRoute: '/customer-home');
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
        child: Stack(
          children: [
            // Main Content
            RefreshIndicator(
              onRefresh: _fetchLiveOperatingHours,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 68, 20, 12),
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
                                const HugeIcon(icon: HugeIcons.strokeRoundedCall02, color: Colors.blue, size: 18),
                                const SizedBox(width: 8),
                                Text('store.call'.tr(), style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
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
                                const HugeIcon(icon: HugeIcons.strokeRoundedComment01, color: Colors.green, size: 18),
                                const SizedBox(width: 8),
                                Text('store.whatsapp'.tr(), style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
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
                      child: Row(
                        children: [
                          const HugeIcon(icon: HugeIcons.strokeRoundedPauseCircle, color: Colors.redAccent, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'store.busy_temporary'.tr(),
                                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'store.busy_temporary_subtitle'.tr(),
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Operating Hours (Full 7 Days — Unified with Today on Top & Direct Holiday Closures)
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
                              'store.weekly_operating_hours'.tr(),
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...orderedDays.map((dayData) {
                          final bool isToday = dayData['isToday'] as bool;
                          final bool isOpen = dayData['isOpen'] as bool;
                          final bool isHoliday = dayData['isHoliday'] as bool;
                          final String dayKey = dayData['dayKey'] as String;
                          final String dayHours = dayData['dayHours'] as String;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? (isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.08))
                                  : (isHoliday
                                      ? (isDark ? Colors.amber.withValues(alpha: 0.08) : Colors.amber.withValues(alpha: 0.05))
                                      : Colors.transparent),
                              borderRadius: BorderRadius.circular(10),
                              border: isToday
                                  ? Border.all(color: Colors.blue.withValues(alpha: 0.3))
                                  : (isHoliday
                                      ? Border.all(color: Colors.amber.withValues(alpha: 0.25))
                                      : null),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    if (isHoliday) ...[
                                      const HugeIcon(
                                        icon: HugeIcons.strokeRoundedCalendar03,
                                        color: Colors.amber,
                                        size: 15,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      dayKey.tr(),
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
                                        child: Text(
                                          'common.today'.tr(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Flexible(
                                  child: Text(
                                    dayHours,
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      color: isHoliday
                                          ? Colors.amber
                                          : (!isOpen
                                              ? Colors.redAccent
                                              : (isToday ? Colors.blue : textSecondary)),
                                      fontWeight: (!isOpen || isToday || isHoliday)
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 12,
                                    ),
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
                              'store.location_address'.tr(),
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
                            icon: const HugeIcon(icon: HugeIcons.strokeRoundedDirections01, size: 18),
                            label: Text('store.directions'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                              'store.facilities_features'.tr(),
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
                                  HugeIcon(icon: item['icon'] as List<List<dynamic>>, color: Colors.blue, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    (item['labelKey'] as String).tr(),
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
            FloatingTopBar(
              isDark: isDark,
              fallbackRoute: '/customer-home',
              title: 'store.store_information'.tr(),
              subtitle: shopName,
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: Colors.blue.withValues(alpha: 0.1),
      child: const Center(
        child: HugeIcon(icon: HugeIcons.strokeRoundedStore01, color: Colors.blue, size: 28),
      ),
    );
  }
}
