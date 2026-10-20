import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../widgets/liquid_glass_compat.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/shop_data.dart';
import '../../widgets/glass_toast.dart';
import '../explore/business_store_view.dart';
import '../explore/my_bookings_view.dart';
import '../explore/qr_scanner_screen.dart';
import '../explore/store_route_loader.dart';
import '../shared/my_queue_ticket_screen.dart';
import 'package:flutter/services.dart';

// =============================================================================
// CustomerHomeFeedView — Laman Utama (Home) Pelanggan Serba Baru & Ultra Modern
// Sapaan, Carian, Story Tawaran, Kategori Pantas, Kad Live Giliran/Setem, Radar
// =============================================================================

class CustomerHomeFeedView extends StatefulWidget {
  final void Function(int index)? onSwitchTab;

  const CustomerHomeFeedView({super.key, this.onSwitchTab});

  @override
  State<CustomerHomeFeedView> createState() => _CustomerHomeFeedViewState();
}

class _CustomerHomeFeedViewState extends State<CustomerHomeFeedView> {
  String _locationName = 'Bangi Sentral, Selangor';
  String _userName = 'Pelanggan';
  List<Map<String, dynamic>> _nearbyShops = [];
  bool _isLoadingShops = true;
  double? _userLat;
  double? _userLng;

  StreamSubscription? _shopsSubscription;

  final List<Map<String, dynamic>> _stories = [
    {
      'title': 'Flash RM10',
      'subtitle': 'Potong Rambut',
      'icon': HugeIcons.strokeRoundedScissor,
      'gradient': [Color(0xFF2196F3), Color(0xFF64B5F6)],
      'badge': 'Terhad',
    },
    {
      'title': 'Port Viral',
      'subtitle': 'Kopi & Roti',
      'icon': HugeIcons.strokeRoundedCoffee02,
      'gradient': [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
      'badge': 'Trending',
    },
    {
      'title': 'Nano Detailing',
      'subtitle': 'Diskaun 30%',
      'icon': HugeIcons.strokeRoundedCar01,
      'gradient': [Color(0xFF00ACC1), Color(0xFF0077B6)],
      'badge': 'Jimat',
    },
    {
      'title': 'Daily Promo',
      'subtitle': 'Kupon RM5',
      'icon': HugeIcons.strokeRoundedTicket01,
      'gradient': [Color(0xFF0284C7), Color(0xFF38BDF8)],
      'badge': 'Hari Ini',
    },
    {
      'title': 'Spa & Relaks',
      'subtitle': 'Slot Petang',
      'icon': HugeIcons.strokeRoundedSparkles,
      'gradient': [Color(0xFF6366F1), Color(0xFF4F46E5)],
      'badge': 'Hot',
    },
  ];

  final List<Map<String, dynamic>> _quickIntents = [
    {
      'title': 'Gunting Rambut',
      'categoryKey': 'barber',
      'icon': HugeIcons.strokeRoundedScissor,
      'color': Color(0xFF2196F3),
      'count': '12 Port',
    },
    {
      'title': 'Cuci Kereta',
      'categoryKey': 'carwash',
      'icon': HugeIcons.strokeRoundedCar01,
      'color': Color(0xFF0288D1),
      'count': '8 Port',
    },
    {
      'title': 'Kafe & Port Chill',
      'categoryKey': 'cafe',
      'icon': HugeIcons.strokeRoundedCoffee02,
      'color': Color(0xFF3B82F6),
      'count': '15 Port',
    },
    {
      'title': 'Bengkel & Servis',
      'categoryKey': 'workshop',
      'icon': HugeIcons.strokeRoundedWrench01,
      'color': Color(0xFF0EA5E9),
      'count': '6 Port',
    },
    {
      'title': 'Salun & Spa',
      'categoryKey': 'salon',
      'icon': HugeIcons.strokeRoundedSparkles,
      'color': Color(0xFF6366F1),
      'count': '9 Port',
    },
    {
      'title': 'Klinik & Kesihatan',
      'categoryKey': 'health',
      'icon': HugeIcons.strokeRoundedFirstAidKit,
      'color': Color(0xFF2563EB),
      'count': '5 Port',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserInfoAndLocation();
    _fetchShops();
  }

  @override
  void dispose() {
    _shopsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserInfoAndLocation() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final metaName = user.userMetadata?['full_name'] ??
            user.userMetadata?['name'] ??
            user.email?.split('@').first;
        if (metaName != null && metaName.toString().isNotEmpty) {
          setState(() {
            _userName = metaName.toString();
          });
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final cachedLat = prefs.getDouble('cached_user_lat');
      final cachedLng = prefs.getDouble('cached_user_lng');

      if (cachedLat != null && cachedLng != null) {
        setState(() {
          _userLat = cachedLat;
          _userLng = cachedLng;
          _locationName = 'Lokasi Semasa Dikesan';
        });
      }
    } catch (e) {
      debugPrint('Error loading user/location: $e');
    }
  }

  void _fetchShops() {
    try {
      _shopsSubscription = Supabase.instance.client
          .from('businesses')
          .stream(primaryKey: ['id'])
          .eq('status', 'active')
          .listen(
            (data) {
              if (!mounted) return;
              if (data.isNotEmpty) {
                final List<Map<String, dynamic>> loaded = [];
                for (var row in data) {
                  final map = Map<String, dynamic>.from(row);
                  if (_userLat != null && _userLng != null && map['latitude'] != null && map['longitude'] != null) {
                    final dLat = double.tryParse(map['latitude'].toString()) ?? 0.0;
                    final dLng = double.tryParse(map['longitude'].toString()) ?? 0.0;
                    map['distanceKm'] = _calculateDistance(_userLat!, _userLng!, dLat, dLng);
                  } else {
                    map['distanceKm'] = 0.8;
                  }
                  loaded.add(map);
                }
                loaded.sort((a, b) => ((a['distanceKm'] ?? 999.0) as double).compareTo((b['distanceKm'] ?? 999.0) as double));
                setState(() {
                  _nearbyShops = loaded;
                  _isLoadingShops = false;
                });
              } else {
                _loadFallbackShops();
              }
            },
            onError: (err) {
              debugPrint('Supabase stream error in Home: $err');
              _loadFallbackShops();
            },
          );
    } catch (e) {
      debugPrint('Error setting up shops stream: $e');
      _loadFallbackShops();
    }
  }

  void _loadFallbackShops() {
    if (!mounted) return;
    final List<Map<String, dynamic>> fallback = List.from(ShopData.shops);
    setState(() {
      _nearbyShops = fallback;
      _isLoadingShops = false;
    });
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  String _formatDistance(dynamic dist) {
    if (dist == null) return '800 m';
    final d = (dist is num) ? dist.toDouble() : double.tryParse(dist.toString()) ?? 0.8;
    if (d < 1.0) {
      return '${(d * 1000).round()} m';
    }
    return '${d.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgGradStart = isDark ? const Color(0xFF0A0A14) : const Color(0xFFF8F9FA);
    final Color bgGradEnd = isDark ? const Color(0xFF10101C) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: bgGradStart,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgGradStart, bgGradEnd],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Top Glass Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: _buildTopHeader(isDark),
                ),
              ),

              // 2. Liquid Glass Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSearchBar(isDark),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 18)),

              // 3. Story Rings (Flash Deals / Hot Port)
              SliverToBoxAdapter(
                child: _buildStoriesSection(isDark),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 22)),

              // 4. Quick Intent Kategori Grid
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildQuickIntentGrid(isDark),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 22)),

              // 5. Live Active Queue & Digital Stamp Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildDigitalStampAndQueueCard(isDark),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // 6. Live Radar & Port Berdekatan Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2196F3),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF2196F3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Live Radar Port Terdekat',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          // Switch to Discover tab (tab index 1)
                          widget.onSwitchTab?.call(1);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Text(
                                'Buka Peta',
                                style: TextStyle(
                                  color: Color(0xFF2196F3),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 4),
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedArrowRight01,
                                color: Color(0xFF2196F3),
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // 7. Horizontal List of Nearby Shops (Live Radar Cards)
              SliverToBoxAdapter(
                child: _buildNearbyRadarCards(isDark),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // 8. Promo Banner / Port Viral
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildPromoBanner(isDark),
                ),
              ),

              // Bottom Spacer to prevent floating navbar from obscuring content
              const SliverToBoxAdapter(child: SizedBox(height: 130)),
            ],
          ),
        ),
      ),
    );
  }

  void _openQrScanner() async {
    final scannedData = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );

    if (scannedData == null || scannedData.isEmpty || !mounted) return;
    _handleScannedQr(scannedData);
  }

  void _handleScannedQr(String rawData) {
    final query = rawData.trim();

    // 1. WiFi QR format
    if (query.startsWith('WIFI:')) {
      String ssid = 'WiFi Tetamu';
      String pass = '';
      final parts = query.replaceFirst('WIFI:', '').split(';');
      for (final part in parts) {
        if (part.startsWith('S:')) ssid = part.substring(2);
        if (part.startsWith('P:')) pass = part.substring(2);
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF141424),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white12),
          ),
          title: const Row(
            children: [
              Icon(Icons.wifi_rounded, color: Color(0xFF42A5F5), size: 22),
              SizedBox(width: 10),
              Text(
                'WiFi Tetamu Kedai',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Maklumat WiFi dikesan daripada imbasan:',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SSID: $ssid',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kata Laluan: $pass',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF42A5F5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: pass));
                Navigator.pop(ctx);
                showGlassToast(context, 'Kata laluan WiFi disalin ke papan klip!');
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Salin Kata Laluan'),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Smart Queue format
    if (query.startsWith('NGAM_QUEUE:') || query.contains('/queue/')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyQueueTicketScreen()),
      );
      showGlassToast(context, 'Membuka Giliran Pintar Kedai...');
      return;
    }

    // 3. Storefront / Table / Promo format
    final uri = Uri.tryParse(query);
    String identifier = query;
    String? table;
    String? promo;

    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'ngam')) {
      table = uri.queryParameters['table'];
      promo = uri.queryParameters['promo'];
      if (uri.pathSegments.isNotEmpty) {
        identifier = uri.pathSegments.last;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoreRouteLoader(
          businessId: identifier,
          tableNumber: table,
          promoCode: promo,
        ),
      ),
    );
  }

  // --- WIDGET 1: TOP HEADER ---
  Widget _buildTopHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left: Clean Greeting & Location (NO CONTAINER - Clean & Spacious)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hai, $_userName 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              GestureDetector(
                onTap: () {
                  showGlassToast(
                    context,
                    'Lokasi semasa: $_locationName',
                    icon: HugeIcons.strokeRoundedLocation01,
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedLocation01,
                      color: Color(0xFFFF5252),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _locationName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowDown01,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      size: 13,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // Right: Connected Twin Glass Pill (QR Scan + Divider + Notification)
        GlassContainer(
          useOwnLayer: true,
          quality: GlassQuality.standard,
          shape: const LiquidRoundedSuperellipse(borderRadius: 50.0),
          settings: LiquidGlassSettings(
            thickness: 0.1,
            blur: 2.0,
            lightIntensity: isDark ? 0.1 : 0.2,
            glassColor: Colors.transparent,
          ),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.65),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.65),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // QR Button
                GestureDetector(
                  onTap: _openQrScanner,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedQrCode01,
                      color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                      size: 20,
                    ),
                  ),
                ),

                // Notification Bell Button with Red Dot
                GestureDetector(
                  onTap: () {
                    showGlassToast(
                      context,
                      'Tiada notifikasi baru hari ini',
                      icon: HugeIcons.strokeRoundedNotification01,
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedNotification01,
                          color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                          size: 20,
                        ),
                        Positioned(
                          top: -1,
                          right: -1,
                          child: Container(
                            width: 7.5,
                            height: 7.5,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF4757),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFFFF4757),
                                  blurRadius: 4,
                                  spreadRadius: 0.5,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- WIDGET 2: SEARCH BAR ---
  Widget _buildSearchBar(bool isDark) {
    return GestureDetector(
      onTap: () {
        // Switch to Discover tab to search on map
        widget.onSwitchTab?.call(1);
      },
      child: GlassContainer(
        useOwnLayer: true,
        quality: GlassQuality.standard,
        shape: const LiquidRoundedSuperellipse(borderRadius: 30.0),
        settings: LiquidGlassSettings(
          thickness: 0.1,
          blur: 2.0,
          lightIntensity: isDark ? 0.1 : 0.2,
          glassColor: Colors.transparent,
        ),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.85),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                color: const Color(0xFF2196F3),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cari barber, servis kereta, kafe...',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey.shade500,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedSlidersHorizontal,
                      color: isDark ? Colors.white70 : Colors.black54,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tapis',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET 3: STORIES SECTION ---
  Widget _buildStoriesSection(bool isDark) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final story = _stories[index];
          final List<Color> gradientColors = story['gradient'];

          return GestureDetector(
            onTap: () {
              showGlassToast(
                context,
                '${story['title']}: ${story['subtitle']}',
                icon: story['icon'],
              );
            },
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Outer glowing animated border ring
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: gradientColors[0].withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(2.0),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF161624) : Colors.white,
                        ),
                        padding: const EdgeInsets.all(2.5),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                gradientColors[0].withValues(alpha: isDark ? 0.25 : 0.15),
                                gradientColors[1].withValues(alpha: isDark ? 0.08 : 0.04),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: HugeIcon(
                              icon: story['icon'],
                              color: gradientColors[0],
                              size: 19,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Small floating badge
                    Positioned(
                      bottom: -2.5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: gradientColors),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: Text(
                          story['badge'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.0,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  story['title'],
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET 4: KATEGORI PILIHAN GRID ---
  Widget _buildQuickIntentGrid(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Kategori Pilihan',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            GestureDetector(
              onTap: () => widget.onSwitchTab?.call(1),
              child: const Text(
                'Semua Kategori',
                style: TextStyle(
                  color: Color(0xFF2196F3),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _quickIntents.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.22,
          ),
          itemBuilder: (context, index) {
            final cat = _quickIntents[index];
            final Color catColor = cat['color'];

            return GestureDetector(
              onTap: () {
                // Switch to Discover tab (tab 1)
                widget.onSwitchTab?.call(1);
              },
              child: GlassContainer(
                useOwnLayer: true,
                quality: GlassQuality.standard,
                shape: const LiquidRoundedSuperellipse(borderRadius: 18.0),
                settings: LiquidGlassSettings(
                  thickness: 0.1,
                  blur: 2.0,
                  lightIntensity: isDark ? 0.1 : 0.2,
                  glassColor: Colors.transparent,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: isDark
                        ? const Color(0xFF161624).withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.85),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: catColor.withValues(alpha: isDark ? 0.18 : 0.12),
                          border: Border.all(
                            color: catColor.withValues(alpha: isDark ? 0.35 : 0.25),
                            width: 1.0,
                          ),
                        ),
                        child: Center(
                          child: HugeIcon(
                            icon: cat['icon'],
                            color: catColor,
                            size: 19,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            cat['title'],
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cat['count'],
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                          fontSize: 9.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // --- WIDGET 5: DIGITAL STAMP CARD & LIVE QUEUE STATUS (FROSTED GLASS) ---
  Widget _buildDigitalStampAndQueueCard(bool isDark) {
    return GlassContainer(
      useOwnLayer: true,
      quality: GlassQuality.standard,
      shape: const LiquidRoundedSuperellipse(borderRadius: 24.0),
      settings: LiquidGlassSettings(
        thickness: 0.1,
        blur: 2.0,
        lightIntensity: isDark ? 0.1 : 0.2,
        glassColor: Colors.transparent,
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.55),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.65),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Avatar + Name + Floating Reward Ribbon
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF2196F3),
                      width: 1.5,
                    ),
                    image: const DecorationImage(
                      image: NetworkImage(
                        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=200',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Barber Danial',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2196F3),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Kad Setem • 4/5 Bintang',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Elegant Frosted Reward Ribbon (Ngam Blue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: isDark ? 0.16 : 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '1 Lagi Setem',
                        style: TextStyle(
                          color: Color(0xFF2196F3),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 3),
                      Text('🎁', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Stamp circles row (Expanded to guarantee 0 overflow on any screen)
            Row(
              children: List.generate(5, (i) {
                final isFilled = i < 4;
                final isTarget = i == 4;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? 0 : 3.5,
                      right: i == 4 ? 0 : 3.5,
                    ),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: isFilled
                            ? const Color(0xFF2196F3).withValues(alpha: isDark ? 0.20 : 0.12)
                            : (isTarget
                                ? const Color(0xFF00E5FF).withValues(alpha: isDark ? 0.18 : 0.10)
                                : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03))),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFilled
                              ? const Color(0xFF2196F3).withValues(alpha: 0.5)
                              : (isTarget
                                  ? const Color(0xFF00E5FF).withValues(alpha: 0.55)
                                  : (isDark ? Colors.white12 : Colors.black12)),
                          width: isTarget ? 1.3 : 1.0,
                        ),
                        boxShadow: isFilled
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: isFilled
                            ? const Icon(
                                Icons.star_rounded,
                                color: Color(0xFF2196F3),
                                size: 24,
                              )
                            : (isTarget
                                ? const Icon(
                                    Icons.card_giftcard_rounded,
                                    color: Color(0xFF00E5FF),
                                    size: 20,
                                  )
                                : Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  )),
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 14),

            // Action Buttons: Semak Tiket Giliran & Tempahan
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MyQueueTicketScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedTicket01,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Semak Tiket Giliran',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
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
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyBookingsView()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    child: Text(
                      'Sejarah',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String? cat) {
    final c = cat?.toLowerCase() ?? '';
    if (c.contains('barber') || c.contains('gunting')) return const Color(0xFFFF6D00);
    if (c.contains('carwash') || c.contains('cuci') || c.contains('detailing')) return const Color(0xFF2196F3);
    if (c.contains('cafe') || c.contains('kafe') || c.contains('kopi')) return const Color(0xFFFFB300);
    if (c.contains('workshop') || c.contains('bengkel') || c.contains('servis')) return const Color(0xFF00C853);
    if (c.contains('salon') || c.contains('spa')) return const Color(0xFFAA00FF);
    if (c.contains('health') || c.contains('klinik')) return const Color(0xFFFF1744);
    return const Color(0xFF2196F3);
  }

  // --- WIDGET 6: LIVE RADAR NEARBY CARDS ---
  Widget _buildNearbyRadarCards(bool isDark) {
    if (_isLoadingShops) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
          ),
        ),
      );
    }

    final displayList = _nearbyShops.take(6).toList();

    return SizedBox(
      height: 236,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: displayList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final shop = displayList[index];
          final String name = shop['name'] ?? 'Kedai Servis';
          final String cat = shop['category']?.toString().toUpperCase() ?? 'BARBER';
          final Color catAccent = _getCategoryColor(cat);
          final String rating = shop['rating']?.toString() ?? '4.9';
          final String dist = _formatDistance(shop['distanceKm']);
          final String img = shop['image'] ??
              'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=400';

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BusinessStoreView(shop: shop)),
              );
            },
            child: Container(
              width: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: isDark ? const Color(0xFF161C24) : Colors.white,
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Image with badges
                    Stack(
                      children: [
                        SizedBox(
                          height: 125,
                          width: double.infinity,
                          child: CachedNetworkImage(
                            imageUrl: img,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: isDark ? Colors.grey.shade900 : Colors.grey.shade300,
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: isDark ? Colors.grey.shade900 : Colors.grey.shade300,
                              child: const Icon(Icons.storefront, color: Colors.grey),
                            ),
                          ),
                        ),
                        // Dark overlay gradient
                        Container(
                          height: 125,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.3),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.6),
                              ],
                            ),
                          ),
                        ),
                        // Queue Status Pill (Ngam Blue)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.bolt_rounded, size: 12, color: Colors.white),
                                SizedBox(width: 2),
                                Text(
                                  'Line Clear (0 Queue)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Distance Pill
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const HugeIcon(
                                  icon: HugeIcons.strokeRoundedLocation01,
                                  color: Colors.white,
                                  size: 11,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  dist,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Bottom info
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                cat,
                                style: TextStyle(
                                  color: catAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 14),
                                  const SizedBox(width: 2),
                                  Text(
                                    rating,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Buka Sekarang',
                                style: TextStyle(
                                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                                decoration: BoxDecoration(
                                  color: catAccent.withValues(alpha: isDark ? 0.16 : 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: catAccent.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  'Ambil Giliran',
                                  style: TextStyle(
                                    color: catAccent,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET 7: PROMO BANNER ---
  Widget _buildPromoBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F2038), const Color(0xFF162D4E)]
              : [const Color(0xFFE3EDF9), const Color(0xFFD4E3F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9100), Color(0xFFFF5252)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6D00).withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedSparkles,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kongsi Port Ngam Anda',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Dapatkan diskaun RM5 untuk tempahan seterusnya apabila anda reviu kedai.',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.grey.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
