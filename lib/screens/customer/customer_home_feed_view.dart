import 'package:easy_localization/easy_localization.dart';
import 'package:ngam/l10n/generated/app_localizations.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../widgets/liquid_glass_compat.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'notifications_sheet.dart';
import '../../models/notification_data.dart';
import '../../widgets/glass_toast.dart';
import '../explore/business_store_view.dart';
import '../explore/explore_view.dart';
import '../explore/my_bookings_view.dart';
import '../explore/order_status_tracker_screen.dart';
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
  bool _hasFetchError = false;
  bool _isUsingCachedData = false;
  bool _isFetchingLocation = false;
  double? _userLat;
  double? _userLng;

  StreamSubscription? _shopsSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  final List<Map<String, dynamic>> _stories = [
    {
      'titleKey': 'customer.story_flash_title',
      'subtitleKey': 'customer.story_flash_subtitle',
      'icon': HugeIcons.strokeRoundedScissor,
      'gradient': [Color(0xFF2196F3), Color(0xFF64B5F6)],
      'badgeKey': 'customer.story_flash_badge',
      'categoryKey': 'barber',
    },
    {
      'titleKey': 'customer.story_viral_title',
      'subtitleKey': 'customer.story_viral_subtitle',
      'icon': HugeIcons.strokeRoundedCoffee02,
      'gradient': [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
      'badgeKey': 'customer.story_viral_badge',
      'categoryKey': 'cafe',
    },
    {
      'titleKey': 'customer.story_detailing_title',
      'subtitleKey': 'customer.story_detailing_subtitle',
      'icon': HugeIcons.strokeRoundedCar01,
      'gradient': [Color(0xFF00ACC1), Color(0xFF0077B6)],
      'badgeKey': 'customer.story_detailing_badge',
      'categoryKey': 'carwash',
    },
    {
      'titleKey': 'customer.story_promo_title',
      'subtitleKey': 'customer.story_promo_subtitle',
      'icon': HugeIcons.strokeRoundedTicket01,
      'gradient': [Color(0xFF0284C7), Color(0xFF38BDF8)],
      'badgeKey': 'customer.story_promo_badge',
      'categoryKey': 'workshop',
    },
    {
      'titleKey': 'customer.story_spa_title',
      'subtitleKey': 'customer.story_spa_subtitle',
      'icon': HugeIcons.strokeRoundedSparkles,
      'gradient': [Color(0xFF6366F1), Color(0xFF4F46E5)],
      'badgeKey': 'customer.story_spa_badge',
      'categoryKey': 'salon',
    },
  ];

  final List<Map<String, dynamic>> _quickIntents = [
    {
      'titleKey': 'customer.cat_haircut',
      'categoryKey': 'barber',
      'icon': HugeIcons.strokeRoundedScissor,
      'color': Color(0xFF2196F3),
    },
    {
      'titleKey': 'customer.cat_carwash',
      'categoryKey': 'carwash',
      'icon': HugeIcons.strokeRoundedCar01,
      'color': Color(0xFF0288D1),
    },
    {
      'titleKey': 'customer.cat_cafe',
      'categoryKey': 'cafe',
      'icon': HugeIcons.strokeRoundedCoffee02,
      'color': Color(0xFF3B82F6),
    },
    {
      'titleKey': 'customer.cat_workshop',
      'categoryKey': 'workshop',
      'icon': HugeIcons.strokeRoundedWrench01,
      'color': Color(0xFF0EA5E9),
    },
    {
      'titleKey': 'customer.cat_salon',
      'categoryKey': 'salon',
      'icon': HugeIcons.strokeRoundedSparkles,
      'color': Color(0xFF6366F1),
    },
    {
      'titleKey': 'customer.cat_clinic',
      'categoryKey': 'health',
      'icon': HugeIcons.strokeRoundedFirstAidKit,
      'color': Color(0xFF2563EB),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserInfoAndLocation();
    _loadCachedShops();
    _fetchShops();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) {
        setState(() {
          _loadUserInfoAndLocation();
        });
      }
    });
  }

  @override
  void dispose() {
    _shopsSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserInfoAndLocation() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        String resolvedName = 'Pelanggan';

        // 1. Keutamaan Pertama: Semak metadata display_name / nickname yang ditetapkan pengguna
        final metaDisplayName = user.userMetadata?['display_name'] ??
            user.userMetadata?['nickname'] ??
            user.userMetadata?['short_name'];

        if (metaDisplayName != null && metaDisplayName.toString().trim().isNotEmpty) {
          resolvedName = metaDisplayName.toString().trim();
        } else {
          // 2. Keutamaan Kedua: Jika tiada display_name, ambil nama panggilan / nama pertama (bukan nama penuh panjang)
          final rawName = user.userMetadata?['full_name'] ??
              user.userMetadata?['name'] ??
              user.email?.split('@').first;

          if (rawName != null && rawName.toString().trim().isNotEmpty) {
            final trimmed = rawName.toString().trim();
            final parts = trimmed.split(RegExp(r'\s+'));
            resolvedName = parts.isNotEmpty ? parts.first : trimmed;
          }
        }

        if (mounted) {
          setState(() {
            _userName = resolvedName;
          });
        }
      }

      // 1. Muat semula lokasi & nama dari cache SharedPreferences untuk tindak balas pantas
      final prefs = await SharedPreferences.getInstance();
      final cachedLat = prefs.getDouble('cached_user_lat');
      final cachedLng = prefs.getDouble('cached_user_lng');
      final cachedName = prefs.getString('cached_location_name');

      if (cachedName != null && cachedName.trim().isNotEmpty) {
        if (mounted) {
          setState(() {
            _locationName = cachedName.trim();
          });
        }
      }

      if (cachedLat != null && cachedLng != null) {
        _userLat = cachedLat;
        _userLng = cachedLng;
        _updateShopDistances();
      }

      // 2. Dapatkan lokasi GPS sebenar secara senyap jika pengguna sudah memberi kebenaran (permission)
      await _fetchAndApplyLiveLocation(silent: true, requestPermission: false);
    } catch (e) {
      debugPrint('Error loading user/location: $e');
    }
  }

  /// Mendapatkan lokasi GPS sebenar dan mengemas kini nama kawasan & jarak kedai
  Future<void> _fetchAndApplyLiveLocation({bool silent = false, bool requestPermission = false}) async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent && mounted) {
          showGlassToast(
            context,
            'Sila hidupkan perkhidmatan GPS / Lokasi pada telefon anda.',
            type: GlassToastType.warning,
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (requestPermission && (permission == LocationPermission.denied)) {
        permission = await Geolocator.requestPermission();
      }

      // Jika tiada kebenaran lokasi, berhenti tanpa mengganggu pengguna
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        if (!silent && mounted) {
          showGlassToast(
            context,
            'Kebenaran lokasi diperlukan untuk mengesan kawasan semasa anda.',
            type: GlassToastType.warning,
          );
        }
        return;
      }

      if (mounted) {
        setState(() => _isFetchingLocation = true);
      }

      // 1. Guna kedudukan terakhir yang diketahui untuk respons serta-merta jika ada
      try {
        final Position? lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null && mounted) {
          await _applyPosition(lastPos);
        }
      } catch (_) {}

      // 2. Dapatkan kedudukan GPS segar yang tepat
      final Position freshPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) {
        await _applyPosition(freshPos);
        if (!silent && mounted) {
          showGlassToast(
            context,
            'Lokasi dikesan: $_locationName',
            icon: HugeIcons.strokeRoundedLocation01,
            type: GlassToastType.success,
          );
        }
      }
    } catch (e) {
      debugPrint('Error retrieving live location: $e');
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  /// Menyimpan koordinat, mengira semula jarak kedai, dan menyelesaikan nama kawasan (reverse geocoding)
  Future<void> _applyPosition(Position pos) async {
    _userLat = pos.latitude;
    _userLng = pos.longitude;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('cached_user_lat', pos.latitude);
    await prefs.setDouble('cached_user_lng', pos.longitude);

    _updateShopDistances();

    final resolvedName = await _reverseGeocode(pos.latitude, pos.longitude);
    if (resolvedName != null && resolvedName.trim().isNotEmpty && mounted) {
      setState(() {
        _locationName = resolvedName.trim();
      });
      await prefs.setString('cached_location_name', resolvedName.trim());
    }
  }

  /// Mengira semula jarak setiap kedai berdasarkan kedudukan GPS terkini
  void _updateShopDistances() {
    if (_userLat == null || _userLng == null || _nearbyShops.isEmpty) return;
    for (var map in _nearbyShops) {
      if (map['latitude'] != null && map['longitude'] != null) {
        final dLat = double.tryParse(map['latitude'].toString()) ?? 0.0;
        final dLng = double.tryParse(map['longitude'].toString()) ?? 0.0;
        map['distanceKm'] = _calculateDistance(_userLat!, _userLng!, dLat, dLng);
      }
    }
    _nearbyShops.sort((a, b) => ((a['distanceKm'] ?? 999.0) as double).compareTo((b['distanceKm'] ?? 999.0) as double));
    if (mounted) setState(() {});
  }

  /// Menyelesaikan koordinat GPS kepada nama tempat/bandar sebenar
  Future<String?> _reverseGeocode(double lat, double lng) async {
    // 1. Enjin Utama: BigDataCloud Client Reverse Geocoding (Pantas, tiada had & format kemas)
    try {
      final uri = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lng&localityLanguage=ms',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final locality = data['locality']?.toString().trim();
        final city = data['city']?.toString().trim();
        final state = data['principalSubdivision']?.toString().trim();

        final parts = <String>[];
        if (locality != null && locality.isNotEmpty && locality != city) {
          parts.add(locality);
        } else if (city != null && city.isNotEmpty) {
          parts.add(city);
        }
        if (state != null && state.isNotEmpty) {
          parts.add(state);
        }
        if (parts.isNotEmpty) {
          return parts.join(', ');
        }
      }
    } catch (e) {
      debugPrint('BigDataCloud reverse geocode error: $e');
    }

    // 2. Enjin Sandaran: OpenStreetMap Nominatim
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&addressdetails=1',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'NgamApp/1.0 (com.ngam.app)',
      }).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final addr = data['address'] as Map<String, dynamic>?;
        if (addr != null) {
          final sub = addr['suburb'] ??
              addr['neighbourhood'] ??
              addr['residential'] ??
              addr['village'] ??
              addr['city_district'];
          final city = addr['city'] ??
              addr['town'] ??
              addr['municipality'] ??
              addr['county'];
          final state = addr['state'];

          final parts = <String>[];
          if (sub != null && sub.toString().trim().isNotEmpty) {
            parts.add(sub.toString().trim());
          } else if (city != null && city.toString().trim().isNotEmpty) {
            parts.add(city.toString().trim());
          }
          if (state != null && state.toString().trim().isNotEmpty) {
            parts.add(state.toString().trim());
          }
          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }
      }
    } catch (e) {
      debugPrint('Nominatim reverse geocode error: $e');
    }

    return null;
  }

  Future<void> _loadCachedShops() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('cached_nearby_shops_v1');
      if (jsonStr != null && jsonStr.trim().isNotEmpty) {
        final List decoded = jsonDecode(jsonStr);
        final List<Map<String, dynamic>> cached =
            decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        if (cached.isNotEmpty && mounted) {
          _updateDistancesForList(cached);
          setState(() {
            _nearbyShops = cached;
            _isLoadingShops = false;
            _isUsingCachedData = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading cached shops: $e');
    }
  }

  Future<void> _saveShopsToCache(List<Map<String, dynamic>> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serializable = list.take(20).map((s) => {
            'id': s['id'],
            'name': s['name'],
            'business_name': s['business_name'],
            'category': s['category'],
            'business_industry': s['business_industry'],
            'business_logo_url': s['business_logo_url'],
            'business_cover_url': s['business_cover_url'],
            'rating_average': s['rating_average'],
            'total_reviews': s['total_reviews'],
            'latitude': s['latitude'],
            'longitude': s['longitude'],
            'distanceKm': s['distanceKm'],
            'address_line': s['address_line'],
            'address_city': s['address_city'],
          }).toList();
      await prefs.setString('cached_nearby_shops_v1', jsonEncode(serializable));
    } catch (e) {
      debugPrint('Error caching shops: $e');
    }
  }

  void _updateDistancesForList(List<Map<String, dynamic>> list) {
    if (_userLat == null || _userLng == null) return;
    for (var map in list) {
      if (map['latitude'] != null && map['longitude'] != null) {
        final dLat = double.tryParse(map['latitude'].toString()) ?? 0.0;
        final dLng = double.tryParse(map['longitude'].toString()) ?? 0.0;
        map['distanceKm'] = _calculateDistance(_userLat!, _userLng!, dLat, dLng);
      }
    }
    list.sort((a, b) => ((a['distanceKm'] ?? 999.0) as double).compareTo((b['distanceKm'] ?? 999.0) as double));
  }

  int _getCategoryShopCount(String catKey) {
    if (_nearbyShops.isEmpty) return 0;
    return _nearbyShops.where((shop) {
      final cat = (shop['category'] ?? shop['business_industry'] ?? '').toString().toLowerCase();
      switch (catKey) {
        case 'barber':
          return cat.contains('barber') || cat.contains('rambut') || cat.contains('gunting');
        case 'carwash':
          return cat.contains('carwash') || cat.contains('cuci') || cat.contains('kereta') || cat.contains('auto') || cat.contains('detailing');
        case 'cafe':
          return cat.contains('cafe') || cat.contains('kafe') || cat.contains('kopi') || cat.contains('food') || cat.contains('makan') || cat.contains('restoran');
        case 'workshop':
          return cat.contains('workshop') || cat.contains('bengkel') || cat.contains('servis') || cat.contains('motor');
        case 'salon':
          return cat.contains('salon') || cat.contains('salun') || cat.contains('spa');
        case 'health':
          return cat.contains('health') || cat.contains('klinik') || cat.contains('clinic') || cat.contains('kesihatan') || cat.contains('farmasi');
        default:
          return cat.contains(catKey);
      }
    }).length;
  }

  void _fetchShops() {
    try {
      _shopsSubscription?.cancel();
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
                  map['name'] = map['business_name'] ?? map['trading_name'] ?? map['name'] ?? 'Kedai Pilihan';
                  map['category'] = map['business_industry'] ?? map['category'] ?? 'Service';
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
                _saveShopsToCache(loaded);
                setState(() {
                  _nearbyShops = loaded;
                  _isLoadingShops = false;
                  _hasFetchError = false;
                  _isUsingCachedData = false;
                });
              } else {
                setState(() {
                  _nearbyShops = [];
                  _isLoadingShops = false;
                  _hasFetchError = false;
                  _isUsingCachedData = false;
                });
              }
            },
            onError: (err) {
              debugPrint('Supabase stream error in Home: $err');
              if (!mounted) return;
              setState(() {
                _isLoadingShops = false;
                _hasFetchError = true;
              });
            },
          );
    } catch (e) {
      debugPrint('Error setting up shops stream: $e');
      if (mounted) {
        setState(() {
          _isLoadingShops = false;
          _hasFetchError = true;
        });
      }
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bool isLandscape = media.size.width > media.size.height;
    final bool isDesktop = media.size.width >= 768 || (isLandscape && media.size.width >= 500);
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
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 780 : double.infinity),
              child: Stack(
                children: [
                  CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // Top spacing for floating glass header
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 68),
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

              // 5. Live Active Order Banner (Hanya dipaparkan jika ada pesanan aktif pengguna)
              if (Supabase.instance.client.auth.currentUser != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildActiveOrderBanner(isDark),
                  ),
                ),

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
                            AppLocalizations.of(context)?.homeNearbyStores ?? 'Live Radar Port Terdekat',
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
                          child: Row(
                            children: [
                              Text(
                                AppLocalizations.of(context)?.navDiscover ?? 'Buka Peta',
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

              // Bottom Spacer (Only on mobile so floating navbar doesn't obscure content)
              SliverToBoxAdapter(child: SizedBox(height: isDesktop ? 40 : 130)),
                    ],
                  ),

                  // Floating Top Header (Transparent parent, liquid glass buttons float & refract content)
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Container(
                      color: Colors.transparent,
                      child: _buildTopHeader(isDark),
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
              HugeIcon(icon: HugeIcons.strokeRoundedWifi01, color: Color(0xFF42A5F5), size: 22),
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
              child: Text('common.close'.tr(), style: TextStyle(color: Colors.white54)),
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
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedCopy01, color: Colors.blue, size: 16),
              label: Text('common.copy_password'.tr()),
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
      promo = uri.queryParameters['promo'] ?? uri.queryParameters['voucher'];
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
        // Left: Greeting & Location in Liquid Glass Pill Container
        Expanded(
          child: GlassContainer(
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context)?.homeGreeting(_userName) ?? 'Hai, $_userName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () {
                      _fetchAndApplyLiveLocation(silent: false, requestPermission: true);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedLocation01,
                          color: Color(0xFFFF5252),
                          size: 11,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            _locationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        if (_isFetchingLocation)
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.4,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5252)),
                            ),
                          )
                        else
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedArrowDown01,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            size: 11,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Right: Connected Twin Glass Pill (QR Scan + Login if Guest, or Bookings + Notification if Logged In)
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
            padding: const EdgeInsets.symmetric(horizontal: 2),
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
                // QR Button (Sentiasa kelihatan, 44x44 tepat)
                GestureDetector(
                  onTap: _openQrScanner,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedQrCode01,
                        color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                        size: 20,
                      ),
                    ),
                  ),
                ),

                // Jika tetamu / belum log masuk: Gabungkan butang Log Masuk di sini (ikon sahaja tanpa teks)
                if (Supabase.instance.client.auth.currentUser == null) ...[
                  GestureDetector(
                    onTap: () => Navigator.of(context).pushNamed('/login'),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Tooltip(
                          message: 'Log Masuk / Daftar',
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedLogin02,
                            color: const Color(0xFF2196F3),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // My Bookings (Tempahan Saya) Quick Button (44x44 tepat)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MyBookingsView()),
                      );
                    },
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedCalendar03,
                          color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                  // Notification Bell Button with Live Badge (44x44 tepat)
                  GestureDetector(
                    onTap: () {
                      CustomerNotificationCenterSheet.show(context);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedNotification01,
                              color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                              size: 20,
                            ),
                            ValueListenableBuilder<int>(
                              valueListenable: NotificationData.unreadCount,
                              builder: (context, unread, _) {
                                if (unread <= 0) return const SizedBox.shrink();
                                return Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFF4757),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFFFF4757),
                                          blurRadius: 5,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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
        // Switch to Discover tab and focus its search bar
        ExploreView.pendingSearch.value = const ExploreSearchRequest(focusSearch: true);
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
                  AppLocalizations.of(context)?.homeSearchPlaceholder ?? 'Cari servis, kedai, barangan...',
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
              final catKey = story['categoryKey'] as String?;
              if (catKey != null) {
                ExploreView.pendingSearch.value = ExploreSearchRequest(categoryId: catKey);
                widget.onSwitchTab?.call(1);
              }
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
                          (story['badgeKey'] as String).tr(),
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
                  (story['titleKey'] as String).tr(),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        // On desktop / wide displays (>= 580), display all 6 categories in 1 sleek, balanced row!
        // On mobile (< 580), display 3 columns (2 rows of 3).
        final int crossAxisCount = width >= 580 ? 6 : 3;
        final double spacing = width >= 580 ? 8.0 : 10.0;
        final double itemWidth = (width - ((crossAxisCount - 1) * spacing)) / crossAxisCount;

        // Keep the card compact and proportional (~84-88px height) on both mobile and desktop
        final double targetHeight = width >= 580 ? 86.0 : 82.0;
        final double childAspectRatio = (itemWidth / targetHeight).clamp(1.10, 1.45);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'customer.featured_categories'.tr(),
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => widget.onSwitchTab?.call(1),
                    child: Text(
                      'customer.all_categories'.tr(),
                      style: const TextStyle(
                        color: Color(0xFF2196F3),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: childAspectRatio,
              ),
              itemBuilder: (context, index) {
                final cat = _quickIntents[index];
                final Color catColor = cat['color'];

                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      // Switch to Discover tab filtered by this category
                      ExploreView.pendingSearch.value = ExploreSearchRequest(categoryId: cat['categoryKey'] as String);
                      widget.onSwitchTab?.call(1);
                    },
                    child: GlassContainer(
                      useOwnLayer: true,
                      quality: GlassQuality.standard,
                      shape: const LiquidRoundedSuperellipse(borderRadius: 16.0),
                      settings: LiquidGlassSettings(
                        thickness: 0.1,
                        blur: 2.0,
                        lightIntensity: isDark ? 0.1 : 0.2,
                        glassColor: Colors.transparent,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
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
                              width: 36,
                              height: 36,
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
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  (cat['titleKey'] as String).tr(),
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
                            Builder(
                              builder: (_) {
                                final int count = _getCategoryShopCount(cat['categoryKey'] as String);
                                final String countText = _isLoadingShops && _nearbyShops.isEmpty
                                    ? '...'
                                    : (count > 0
                                        ? 'customer.port_count'.tr(args: [count.toString()])
                                        : 'customer.no_port'.tr());
                                return Text(
                                  countText,
                                  style: TextStyle(
                                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // --- WIDGET 5: DIGITAL STAMP CARD & LIVE QUEUE STATUS (FROSTED GLASS) ---
  Widget _buildActiveOrderBanner(bool isDark) {
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    if (myUid == null) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('orders')
          .stream(primaryKey: ['id'])
          .eq('owner_user_id', myUid)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        final activeOrders = (snapshot.data ?? []).where((o) {
          final st = (o['status']?.toString() ?? '').toLowerCase();
          return st == 'pending' || st == 'preparing' || st == 'in_progress' || st == 'ready';
        }).toList();

        if (activeOrders.isEmpty) return const SizedBox.shrink();
        final latest = activeOrders.first;
        final String orderId = latest['id']?.toString() ?? '';
        final String status = (latest['status']?.toString() ?? 'pending').toLowerCase();
        final double total = (latest['total'] as num?)?.toDouble() ?? 0.0;
        final String shortId = orderId.length > 6 ? orderId.substring(0, 6).toUpperCase() : orderId.toUpperCase();

        final String statusLabel = status == 'ready'
            ? 'customer.order_status_ready'.tr()
            : (status == 'preparing' || status == 'in_progress'
                ? 'customer.order_status_preparing'.tr()
                : 'customer.order_status_received'.tr());
        final Color statusColor = status == 'ready'
            ? const Color(0xFF00E676)
            : (status == 'preparing' || status == 'in_progress'
                ? const Color(0xFF00B0FF)
                : const Color(0xFFFFB300));

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderStatusTrackerScreen(
                    orderId: orderId,
                    shopName: 'Pesanan #$shortId',
                    totalAmount: total,
                    shopId: latest['business_id']?.toString(),
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusColor.withValues(alpha: isDark ? 0.22 : 0.15),
                    const Color(0xFF2196F3).withValues(alpha: isDark ? 0.16 : 0.10),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.45), width: 1.3),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: HugeIcon(
                      icon: status == 'ready'
                          ? HugeIcons.strokeRoundedShoppingBag01
                          : HugeIcons.strokeRoundedRestaurant01,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'customer.active_order'.tr(args: [shortId]),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '• RM ${total.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'customer.track_qr'.tr(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- WIDGET 6: LIVE RADAR NEARBY CARDS ---
  Widget _buildNearbyRadarCards(bool isDark) {
    if (_isLoadingShops && _nearbyShops.isEmpty) {
      return SizedBox(
        height: 236,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (context, _) => _buildRadarCardSkeleton(isDark),
        ),
      );
    }

    if (_hasFetchError && _nearbyShops.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: isDark ? const Color(0xFF161624).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.85),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedWifiDisconnected01,
                    color: Color(0xFFEF4444),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'common.offline_title'.tr(),
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'common.offline_desc'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isLoadingShops = true;
                      _hasFetchError = false;
                    });
                    _fetchShops();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedRefresh,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'common.retry'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_nearbyShops.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: isDark ? const Color(0xFF161624).withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.8),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedStore01,
                    color: Color(0xFF2196F3),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'customer.no_nearby_shops'.tr(),
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'customer.no_nearby_shops_desc'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final displayList = _nearbyShops.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isUsingCachedData || _hasFetchError)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedWifiDisconnected01,
                    color: Color(0xFFF59E0B),
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'common.offline_cached_banner'.tr(),
                      style: TextStyle(
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isLoadingShops = true;
                          _hasFetchError = false;
                        });
                        _fetchShops();
                      },
                      child: Text(
                        'common.retry'.tr(),
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        SizedBox(
          height: 236,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            cacheExtent: 3000,
            addAutomaticKeepAlives: true,
            itemCount: displayList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final shop = displayList[index];
              final shopId = shop['id']?.toString() ?? index.toString();
              return _NearbyRadarCardItem(
                key: ValueKey('radar_shop_$shopId'),
                shop: shop,
                isDark: isDark,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRadarCardSkeleton(bool isDark) {
    return Container(
      width: 172,
      height: 236,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isDark ? const Color(0xFF161624).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.7),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 104,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 12,
            width: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 14,
            width: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          const Spacer(),
          Container(
            height: 28,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
            ),
          ),
        ],
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
                  'customer.share_spot_title'.tr(),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'customer.share_spot_desc'.tr(),
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


// =============================================================================
// _NearbyRadarCardItem — Kad Radar dengan AutomaticKeepAlive & Image Caching
// Menjamin imej TIDAK AKAN hilang/menjadi hitam apabila di-scroll ke kiri/kanan
// =============================================================================
class _NearbyRadarCardItem extends StatefulWidget {
  final Map<String, dynamic> shop;
  final bool isDark;

  const _NearbyRadarCardItem({
    super.key,
    required this.shop,
    required this.isDark,
  });

  @override
  State<_NearbyRadarCardItem> createState() => _NearbyRadarCardItemState();
}

class _NearbyRadarCardItemState extends State<_NearbyRadarCardItem>
    with AutomaticKeepAliveClientMixin {
  // Kekalkan state kad dalam memori supaya widget tidak dimusnahkan ketika scroll
  @override
  bool get wantKeepAlive => true;

  Color _getCategoryColor(String? cat) {
    final c = cat?.toLowerCase() ?? '';
    if (c.contains('barber') || c.contains('gunting')) return const Color(0xFFFF6D00);
    if (c.contains('carwash') || c.contains('cuci') || c.contains('detailing')) return const Color(0xFF2196F3);
    if (c.contains('cafe') || c.contains('kafe') || c.contains('kopi')) return const Color(0xFFFFB300);
    if (c.contains('workshop') || c.contains('bengkel') || c.contains('servis')) return const Color(0xFF00C853);
    return const Color(0xFF2196F3);
  }

  String _formatDistance(dynamic dist) {
    if (dist == null) return '800 m';
    final d = (dist is num) ? dist.toDouble() : double.tryParse(dist.toString()) ?? 0.8;
    if (d < 1.0) {
      return '${(d * 1000).round()} m';
    }
    return '${d.toStringAsFixed(1)} km';
  }

  Widget _buildFallbackBanner(String name, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2A2B3D), const Color(0xFF161622)]
              : [const Color(0xFF2563EB), const Color(0xFF1E40AF)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'S',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 32,
        ),
      ),
    );
  }

  Widget _buildCardImage(String imgUrl, String name, bool isDark) {
    if (imgUrl.isEmpty) {
      return _buildFallbackBanner(name, isDark);
    }

    if (kIsWeb) {
      return Image.network(
        imgUrl,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _buildFallbackBanner(name, isDark),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildFallbackBanner(name, isDark);
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: imgUrl,
      fit: BoxFit.cover,
      useOldImageOnUrlChange: true,
      placeholder: (_, __) => _buildFallbackBanner(name, isDark),
      errorWidget: (_, __, ___) => _buildFallbackBanner(name, isDark),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final shop = widget.shop;
    final isDark = widget.isDark;

    final String name = (shop['business_name'] ?? shop['name']) ?? 'Kedai Servis';
    final String cat = (shop['business_industry'] ?? shop['category'] ?? 'FNB').toString().toUpperCase();
    final Color catAccent = _getCategoryColor(cat);
    final String rating = shop['rating']?.toString() ?? '4.9';
    final String dist = _formatDistance(shop['distanceKm']);

    // Utamakan gambar cover untuk banner kad mendatar; sekiranya tiada, gunakan logo
    final String rawImg = (shop['business_cover_url'] ??
            shop['cover'] ??
            shop['business_logo_url'] ??
            shop['image'] ??
            '')
        .toString();
    final String img = rawImg.contains('photo-1503951914875-452162b0f3f1') ? '' : rawImg.trim();

    return GestureDetector(
      onTap: () {
        final shopWithCat = {
          ...shop,
          'category': cat,
          'business_industry': shop['business_industry'] ?? cat,
        };
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BusinessStoreView(shop: shopWithCat)),
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
                    child: _buildCardImage(img, name, isDark),
                  ),
                  // Dark overlay gradient
                  Container(
                    height: 125,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.25),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
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
                          HugeIcon(icon: HugeIcons.strokeRoundedFlash, size: 12, color: Colors.white),
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
                            const HugeIcon(icon: HugeIcons.strokeRoundedStar, color: Color(0xFFFFB300), size: 14),
                            const SizedBox(width: 2),
                            Text(
                              rating,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
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
                          'customer.open_now'.tr(),
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
                            'customer.take_turn'.tr(),
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
  }
}
