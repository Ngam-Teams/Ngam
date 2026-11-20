import 'dart:ui' as ui;
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
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'notifications_sheet.dart';
import '../../models/notification_data.dart';
import '../../models/product_model.dart';
import '../../services/voucher_service.dart';
import '../../widgets/glass_toast.dart';
import '../explore/business_store_view.dart';
import '../explore/explore_view.dart';
import '../explore/my_bookings_view.dart';
import '../explore/order_status_tracker_screen.dart';
import '../explore/product_detail_screen.dart';
import '../explore/qr_scanner_screen.dart';
import '../shared/voucher_screen.dart';
import '../../utils/qr_route_helper.dart';
import '../../services/app_update_service.dart';

// =============================================================================
// CustomerHomeFeedView — Laman Utama (Home) Pelanggan Serba Baru & Ultra Modern
// Gaya Kompak Shopee × TikTok Shop × Lazada + Glassmorphism Ngam
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
  List<ProductModel> _discoveryProducts = [];
  List<Map<String, dynamic>> _liveVouchers = [];
  bool _isLoadingShops = true;
  bool _isLoadingDiscovery = true;
  bool _hasFetchError = false;
  bool _isUsingCachedData = false;
  bool _isFetchingLocation = false;
  bool _offlineDialogShown = false;
  int _selectedDiscoveryTab = 0; // 0: All, 1: Services, 2: Products, 3: Under RM15
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
      'color': Color(0xFF3B82F6),
    },
    {
      'titleKey': 'customer.cat_fnb',
      'categoryKey': 'cafe',
      'icon': HugeIcons.strokeRoundedCoffee02,
      'color': Color(0xFFF59E0B),
    },
    {
      'titleKey': 'customer.cat_carwash',
      'categoryKey': 'carwash',
      'icon': HugeIcons.strokeRoundedCar01,
      'color': Color(0xFF06B6D4),
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
      'color': Color(0xFF8B5CF6),
    },
    {
      'titleKey': 'customer.cat_clinic',
      'categoryKey': 'health',
      'icon': HugeIcons.strokeRoundedFirstAidKit,
      'color': Color(0xFF10B981),
    },
    {
      'titleKey': 'customer.utility_vouchers',
      'categoryKey': '__vouchers__',
      'icon': HugeIcons.strokeRoundedTicket01,
      'color': Color(0xFFEC4899),
    },
    {
      'titleKey': 'customer.cat_more',
      'categoryKey': '__all__',
      'icon': HugeIcons.strokeRoundedGridView,
      'color': Color(0xFF64748B),
    },
  ];

  @override
  void initState() {
    super.initState();
    VoucherService.init();
    _loadUserInfoAndLocation();
    _loadCachedShops();
    _fetchShops();
    _fetchHomeDiscoveryData();
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
      final response = await http
          .get(
            uri,
            headers: kIsWeb ? null : const {'User-Agent': 'NgamApp/1.0 (com.ngam.app)'},
          )
          .timeout(const Duration(seconds: 5));
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
              _offlineDialogShown = false;
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
              _showOfflinePopupIfNeeded();
            },
          );
    } catch (e) {
      debugPrint('Error setting up shops stream: $e');
      if (mounted) {
        setState(() {
          _isLoadingShops = false;
          _hasFetchError = true;
        });
        _showOfflinePopupIfNeeded();
      }
    }
  }

  Future<void> _fetchHomeDiscoveryData() async {
    try {
      final client = Supabase.instance.client;
      final results = await Future.wait([
        client
            .from('business_products')
            .select()
            .eq('is_active', true)
            .order('is_featured', ascending: false)
            .order('created_at', ascending: false)
            .limit(30)
            .catchError((_) => <dynamic>[]),
        client
            .from('vouchers')
            .select()
            .eq('is_active', true)
            .order('created_at', ascending: false)
            .limit(12)
            .catchError((_) => <dynamic>[]),
      ]);

      final rawProducts = results[0] as List;
      final rawVouchers = results[1] as List;
      final now = DateTime.now();

      final parsedProducts = rawProducts
          .whereType<Map>()
          .map((row) => ProductModel.fromJson(Map<String, dynamic>.from(row)))
          .where((p) => p.name.trim().isNotEmpty && !p.isOutOfStock)
          .toList();

      final activeVouchers = rawVouchers
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .where((v) {
            final expStr = v['expires_at']?.toString() ?? v['valid_until']?.toString();
            if (expStr != null && expStr.isNotEmpty) {
              final exp = DateTime.tryParse(expStr);
              if (exp != null && exp.isBefore(now)) return false;
            }
            return (v['code']?.toString().trim().isNotEmpty ?? false);
          })
          .toList();

      if (!mounted) return;
      setState(() {
        _discoveryProducts = parsedProducts;
        _liveVouchers = activeVouchers;
        _isLoadingDiscovery = false;
      });
    } catch (e) {
      debugPrint('Error fetching home discovery data: $e');
      if (mounted) {
        setState(() => _isLoadingDiscovery = false);
      }
    }
  }

  Future<void> _handleRefresh() async {
    _offlineDialogShown = false;
    setState(() {
      _hasFetchError = false;
    });
    _fetchShops();
    await _fetchHomeDiscoveryData();
  }

  void _showOfflinePopupIfNeeded() {
    if (_offlineDialogShown || !mounted) return;
    _offlineDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bool isDark = Theme.of(context).brightness == Brightness.dark;
      showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        builder: (dialogCtx) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 360),
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF141826).withValues(alpha: 0.90)
                        : Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Center(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedWifiDisconnected01,
                            color: Color(0xFFF59E0B),
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'common.offline_title'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'common.offline_popup_desc'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: isDark ? Colors.white12 : Colors.black12,
                                  ),
                                ),
                              ),
                              child: Text(
                                'common.dismiss'.tr(),
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(dialogCtx);
                                _handleRefresh();
                              },
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedRefresh,
                                color: Colors.white,
                                size: 15,
                              ),
                              label: Text(
                                'common.retry'.tr(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
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
        child: Stack(
          children: [
            // Subtle Ambient Aurora Glows for authentic glassmorphism depth
            Positioned(
              top: -80,
              right: -70,
              child: IgnorePointer(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF2196F3).withValues(alpha: isDark ? 0.14 : 0.10),
                        const Color(0xFF2196F3).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 220,
              left: -90,
              child: IgnorePointer(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF6366F1).withValues(alpha: isDark ? 0.11 : 0.07),
                        const Color(0xFF6366F1).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 820 : double.infinity),
                  child: Stack(
                    children: [
                      RefreshIndicator(
                        onRefresh: _handleRefresh,
                        color: const Color(0xFF3B82F6),
                        edgeOffset: 68,
                        child: CustomScrollView(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          slivers: [
                            // Top spacing for floating glass header
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 64),
                            ),

                            // 1. Liquid Glass Search Bar
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: _buildSearchBar(isDark),
                              ),
                            ),

                            const SliverToBoxAdapter(child: SizedBox(height: 10)),

                            // 2. Compact Shopee-Style Utility Strip (Vouchers | Orders | Scan QR)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: _buildUtilityStrip(isDark),
                              ),
                            ),

                            const SliverToBoxAdapter(child: SizedBox(height: 14)),

                            // 3. Compact 4-Column Category Shortcuts (Shopee / Lazada style)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: _buildQuickIntentGrid(isDark),
                              ),
                            ),

                            const SliverToBoxAdapter(child: SizedBox(height: 16)),

                            // 4. Live Active Order Banner (Only shown if user has active order)
                            if (Supabase.instance.client.auth.currentUser != null)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: _buildActiveOrderBanner(isDark),
                                ),
                              ),

                            // 5. Live Vouchers Strip (Real active Supabase vouchers; hidden if empty)
                            if (_liveVouchers.isNotEmpty) ...[
                              SliverToBoxAdapter(
                                child: _buildLiveVouchersSection(isDark),
                              ),
                              const SliverToBoxAdapter(child: SizedBox(height: 18)),
                            ],

                            // 6. Nearby Stores Header
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
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
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                    GestureDetector(
                                      onTap: () => widget.onSwitchTab?.call(1),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isDark ? Colors.white12 : Colors.black12,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              AppLocalizations.of(context)?.navDiscover ?? 'Buka Peta',
                                              style: const TextStyle(
                                                color: Color(0xFF2196F3),
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            const HugeIcon(
                                              icon: HugeIcons.strokeRoundedArrowRight01,
                                              color: Color(0xFF2196F3),
                                              size: 13,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SliverToBoxAdapter(child: SizedBox(height: 10)),

                            // 7. Horizontal List of Nearby Shops
                            SliverToBoxAdapter(
                              child: _buildNearbyRadarCards(isDark),
                            ),

                            const SliverToBoxAdapter(child: SizedBox(height: 20)),

                            // 8. TikTok Shop / Shopee-Style 2-Column Discovery Feed ("For You Near You")
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: _buildDiscoveryFeedSection(isDark, isDesktop),
                              ),
                            ),

                            // Bottom Spacer
                            SliverToBoxAdapter(child: SizedBox(height: isDesktop ? 40 : 120)),
                          ],
                        ),
                      ),

                      // Floating Top Header
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
          ],
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
    NgamQrRouteHelper.handleScannedQr(context, rawData);
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
        ExploreView.pendingSearch.value = const ExploreSearchRequest(focusSearch: true);
        widget.onSwitchTab?.call(1);
      },
      child: GlassContainer(
        useOwnLayer: true,
        quality: GlassQuality.standard,
        shape: const LiquidRoundedSuperellipse(borderRadius: 26.0),
        settings: LiquidGlassSettings(
          thickness: 0.1,
          blur: 10.0,
          lightIntensity: isDark ? 0.1 : 0.2,
          glassColor: Colors.transparent,
        ),
        child: Container(
          height: 48,
          padding: const EdgeInsets.only(left: 16, right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.78),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.65),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                color: Color(0xFF38BDF8),
                size: 19,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)?.homeSearchPlaceholder ?? 'Cari servis, kedai, barangan...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.4),
                  ),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedSlidersHorizontal,
                    color: isDark ? Colors.white70 : Colors.black54,
                    size: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET 3: QUICK HIGHLIGHTS (MINIMAL GLASS PILLS) ---
  Widget _buildStoriesSection(bool isDark) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final story = _stories[index];
          final List<Color> gradientColors = story['gradient'];
          final Color accent = gradientColors[0];

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                final catKey = story['categoryKey'] as String?;
                if (catKey != null) {
                  ExploreView.pendingSearch.value = ExploreSearchRequest(categoryId: catKey);
                  widget.onSwitchTab?.call(1);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.055)
                      : Colors.white.withValues(alpha: 0.78),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.06),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: isDark ? 0.22 : 0.14),
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: story['icon'],
                          color: accent,
                          size: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (story['titleKey'] as String).tr(),
                      style: TextStyle(
                        color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E293B),
                        fontSize: 12,
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
    );
  }

  // --- WIDGET 2B: COMPACT SHOPEE-STYLE UTILITY STRIP ---
  Widget _buildUtilityStrip(bool isDark) {
    final int voucherBadgeCount = _liveVouchers.length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.055)
                : Colors.white.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.11)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildUtilityItem(
                  isDark: isDark,
                  icon: HugeIcons.strokeRoundedTicket01,
                  color: const Color(0xFFEC4899),
                  label: 'customer.utility_vouchers'.tr(),
                  badge: voucherBadgeCount > 0 ? voucherBadgeCount.toString() : null,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VoucherScreen()),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 20,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              Expanded(
                child: _buildUtilityItem(
                  isDark: isDark,
                  icon: HugeIcons.strokeRoundedCalendar03,
                  color: const Color(0xFF3B82F6),
                  label: 'customer.utility_orders'.tr(),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyBookingsView()),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 20,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              Expanded(
                child: _buildUtilityItem(
                  isDark: isDark,
                  icon: HugeIcons.strokeRoundedQrCode,
                  color: const Color(0xFF10B981),
                  label: 'customer.utility_scan'.tr(),
                  onTap: _openQrScanner,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUtilityItem({
    required bool isDark,
    required dynamic icon,
    required Color color,
    required String label,
    String? badge,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(icon: icon, color: color, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E293B),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: color,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- WIDGET 4: COMPACT 4-COLUMN CATEGORY SHORTCUTS (SHOPEE / LAZADA STYLE) ---
  Widget _buildQuickIntentGrid(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int crossAxisCount = width >= 580 ? 8 : 4;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _quickIntents.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 10,
            mainAxisExtent: 74,
          ),
          itemBuilder: (context, index) {
            final cat = _quickIntents[index];
            final Color catColor = cat['color'] as Color;
            final String catKey = cat['categoryKey'] as String;
            final int count = (catKey == '__vouchers__' || catKey == '__all__')
                ? 0
                : _getCategoryShopCount(catKey);

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  if (catKey == '__vouchers__') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VoucherScreen()),
                    );
                    return;
                  }
                  if (catKey == '__all__') {
                    widget.onSwitchTab?.call(1);
                    return;
                  }
                  ExploreView.pendingSearch.value = ExploreSearchRequest(categoryId: catKey);
                  widget.onSwitchTab?.call(1);
                },
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: isDark
                                ? catColor.withValues(alpha: 0.14)
                                : catColor.withValues(alpha: 0.10),
                            border: Border.all(
                              color: catColor.withValues(alpha: isDark ? 0.30 : 0.22),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: catColor.withValues(alpha: isDark ? 0.12 : 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: HugeIcon(
                              icon: cat['icon'],
                              color: catColor,
                              size: 20,
                            ),
                          ),
                        ),
                        if (count > 0)
                          Positioned(
                            top: -4,
                            right: -6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: catColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF0A0A14) : const Color(0xFFF8F9FA),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                count.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (cat['titleKey'] as String).tr(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF1E293B),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
            child: GlassContainer(
              useOwnLayer: true,
              quality: GlassQuality.standard,
              shape: const LiquidRoundedSuperellipse(borderRadius: 20.0),
              settings: LiquidGlassSettings(
                thickness: 0.1,
                blur: 10.0,
                lightIntensity: isDark ? 0.1 : 0.2,
                glassColor: Colors.transparent,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      statusColor.withValues(alpha: isDark ? 0.16 : 0.12),
                      Colors.white.withValues(alpha: isDark ? 0.04 : 0.65),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 1.0),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: HugeIcon(
                        icon: status == 'ready'
                            ? HugeIcons.strokeRoundedShoppingCart02
                            : HugeIcons.strokeRoundedRestaurant01,
                        color: statusColor,
                        size: 18,
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
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• RM ${total.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'customer.track_qr'.tr(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
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

    return SizedBox(
      height: 224,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        cacheExtent: 3000,
        addAutomaticKeepAlives: true,
        itemCount: displayList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
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

  // --- WIDGET 7: LIVE VOUCHERS STRIP (REAL SUPABASE VOUCHERS) ---
  Widget _buildLiveVouchersSection(bool isDark) {
    if (_liveVouchers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedTicket01,
                    color: Color(0xFFEC4899),
                    size: 16,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'customer.live_vouchers_title'.tr(),
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VoucherScreen()),
                ),
                child: Text(
                  'customer.view_all'.tr(),
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 82,
          child: ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: VoucherService.savedVouchersNotifier,
            builder: (context, _, __) {
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _liveVouchers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final v = _liveVouchers[index];
                  final String id = v['id']?.toString() ?? '';
                  final String code = (v['code'] ?? '').toString().trim().toUpperCase();
                  final String dType = (v['discount_type'] ?? 'fixed').toString().toLowerCase();
                  final double dVal = (v['discount_value'] as num?)?.toDouble() ?? 0.0;
                  final double minSpend = (v['min_spend'] as num?)?.toDouble() ?? 0.0;
                  final String badgeText = dType == 'percentage'
                      ? '${dVal.toStringAsFixed(0)}% OFF'
                      : 'RM${dVal.toStringAsFixed(dVal == dVal.roundToDouble() ? 0 : 2)} OFF';
                  final bool isClaimed = VoucherService.isVoucherSaved(id: id, code: code);

                  return Container(
                    width: 230,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                const Color(0xFFEC4899).withValues(alpha: 0.16),
                                const Color(0xFF6366F1).withValues(alpha: 0.14),
                              ]
                            : [
                                const Color(0xFFFDF2F8),
                                const Color(0xFFEEF2FF),
                              ],
                      ),
                      border: Border.all(
                        color: const Color(0xFFEC4899).withValues(alpha: isDark ? 0.30 : 0.22),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                badgeText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFEC4899),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                code,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                minSpend > 0
                                    ? 'customer.voucher_min_spend'.tr(args: [minSpend.toStringAsFixed(0)])
                                    : 'customer.voucher_no_min'.tr(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            final saved = await VoucherService.toggleSaveVoucher(v);
                            if (saved && mounted) {
                              showGlassToast(
                                context,
                                'customer.voucher_claimed_toast'.tr(args: [code]),
                                type: GlassToastType.success,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                            decoration: BoxDecoration(
                              color: isClaimed
                                  ? const Color(0xFF10B981).withValues(alpha: 0.16)
                                  : const Color(0xFFEC4899),
                              borderRadius: BorderRadius.circular(12),
                              border: isClaimed
                                  ? Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.45))
                                  : null,
                            ),
                            child: Text(
                              isClaimed
                                  ? 'customer.voucher_claimed'.tr()
                                  : 'customer.voucher_claim'.tr(),
                              style: TextStyle(
                                color: isClaimed ? const Color(0xFF10B981) : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- WIDGET 8: TIKTOK SHOP / SHOPEE-STYLE 2-COLUMN DISCOVERY FEED ---
  Widget _buildDiscoveryFeedSection(bool isDark, bool isDesktop) {
    final List<String> tabLabels = [
      'customer.feed_tab_all'.tr(),
      'customer.feed_tab_services'.tr(),
      'customer.feed_tab_products'.tr(),
      'customer.feed_tab_budget'.tr(),
    ];

    final List<ProductModel> filtered = _discoveryProducts.where((p) {
      if (_selectedDiscoveryTab == 1) return p.isService;
      if (_selectedDiscoveryTab == 2) return p.isProduct;
      if (_selectedDiscoveryTab == 3) return p.price > 0 && p.price <= 15.0;
      return true;
    }).toList();

    final Map<String, Map<String, dynamic>> shopById = {
      for (final s in _nearbyShops)
        if (s['id'] != null) s['id'].toString(): s,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'customer.discovery_title'.tr(),
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'customer.discovery_subtitle'.tr(),
                  style: TextStyle(
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => widget.onSwitchTab?.call(1),
              child: Text(
                'customer.view_all'.tr(),
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Filter Pills
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: tabLabels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final bool isSel = _selectedDiscoveryTab == idx;
              return GestureDetector(
                onTap: () => setState(() => _selectedDiscoveryTab = idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: isSel
                        ? const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                          )
                        : null,
                    color: isSel
                        ? null
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.white.withValues(alpha: 0.85)),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSel
                          ? const Color(0xFF60A5FA)
                          : (isDark ? Colors.white12 : Colors.black12),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      tabLabels[idx],
                      style: TextStyle(
                        color: isSel
                            ? Colors.white
                            : (isDark ? Colors.white70 : const Color(0xFF334155)),
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        if (_isLoadingDiscovery && _discoveryProducts.isEmpty)
          MasonryGridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isDesktop ? 3 : 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            itemCount: 4,
            itemBuilder: (_, idx) => Container(
              height: idx.isEven ? 210 : 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
              ),
            ),
          )
        else if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.75),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: Center(
              child: Text(
                'customer.discovery_empty'.tr(),
                style: TextStyle(
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        else
          MasonryGridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isDesktop ? 3 : 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final product = filtered[index];
              final shop = shopById[product.shopId] ??
                  {
                    'id': product.shopId,
                    'name': 'Ngam Partner',
                    'category': product.category.isNotEmpty ? product.category : 'Service',
                  };
              return _buildDiscoveryProductCard(product, shop, isDark);
            },
          ),
      ],
    );
  }

  Widget _buildDiscoveryProductCard(
    ProductModel product,
    Map<String, dynamic> shop,
    bool isDark,
  ) {
    final bool isService = product.isService;
    final Color typeColor = isService ? const Color(0xFF3B82F6) : const Color(0xFF10B981);
    final String shopName = (shop['name'] ?? shop['business_name'] ?? 'Ngam').toString();
    final dynamic distRaw = shop['distanceKm'];
    String distLabel = '';
    if (distRaw is num) {
      final d = distRaw.toDouble();
      distLabel = d < 1.0 ? '${(d * 1000).round()}m' : '${d.toStringAsFixed(1)}km';
    }

    Widget imageFallback(double height) => Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                typeColor.withValues(alpha: 0.22),
                typeColor.withValues(alpha: 0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: HugeIcon(
              icon: isService
                  ? HugeIcons.strokeRoundedSparkles
                  : HugeIcons.strokeRoundedStore01,
              color: typeColor.withValues(alpha: 0.7),
              size: 28,
            ),
          ),
        );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(
                product: product,
                shop: shop,
              ),
            ),
          );
        },
        child: GlassContainer(
          useOwnLayer: true,
          quality: GlassQuality.standard,
          shape: const LiquidRoundedSuperellipse(borderRadius: 24),
          settings: LiquidGlassSettings(
            thickness: 0.1,
            blur: 14.0,
            refractiveIndex: 1.0,
            glassColor: Colors.transparent,
            lightAngle: 45.0,
            lightIntensity: isDark ? 0.1 : 0.2,
            ambientStrength: 1.0,
            saturation: 1.0,
            chromaticAberration: 0.0,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.72),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.7),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pinterest-Safe Masonry Image Container (matches BusinessStoreView)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final minH = width * 0.75;
                        final maxH = width * 1.5;

                        return ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: minH,
                            maxHeight: maxH,
                          ),
                          child: Stack(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: product.imageUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: product.imageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                          height: minH,
                                          color: isDark
                                              ? const Color(0xFF151929)
                                              : const Color(0xFFE2E8F0),
                                        ),
                                        errorWidget: (_, __, ___) => imageFallback(minH),
                                      )
                                    : imageFallback(minH),
                              ),
                              Positioned(
                                top: 7,
                                left: 7,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.90),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isService
                                        ? 'customer.badge_service'.tr()
                                        : 'customer.badge_product'.tr(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              if (product.hasDiscount)
                                Positioned(
                                  top: 7,
                                  right: 7,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '-${product.discountPercent}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'RM${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF3B82F6),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (product.hasDiscount) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'RM${product.compareAtPrice!.toStringAsFixed(0)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 10.5,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedStore01,
                        color: isDark ? Colors.white38 : Colors.black38,
                        size: 11,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (distLabel.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          distLabel,
                          style: TextStyle(
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
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
