import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
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
import 'package:shimmer/shimmer.dart';

import 'home_search_screen.dart';
import 'notifications_sheet.dart';
import '../../models/notification_data.dart';
import '../../models/product_model.dart';
import '../../services/voucher_service.dart';
import '../../widgets/glass_toast.dart';
import '../../widgets/natural_aspect_image.dart';
import '../explore/business_store_view.dart';
import '../explore/explore_view.dart';
import '../explore/my_bookings_view.dart';
import '../explore/order_status_tracker_screen.dart';
import '../explore/product_detail_screen.dart';
import '../explore/qr_scanner_screen.dart';
import '../shared/voucher_screen.dart';
import '../../utils/ngam_ref.dart';
import '../../utils/qr_route_helper.dart';

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
  // ignore: unused_field
  String _userName = 'Pelanggan';
  List<Map<String, dynamic>> _nearbyShops = [];
  List<ProductModel> _discoveryProducts = [];
  List<Map<String, dynamic>> _liveVouchers = [];
  bool _isLoadingShops = true;
  bool _isLoadingDiscovery = true;
  bool _hasFetchError = false;
  // ignore: unused_field
  bool _isUsingCachedData = false;
  bool _isFetchingLocation = false;
  bool _offlineDialogShown = false;
  int _selectedDiscoveryTab = 0; // 0: All, 1: Services, 2: Products, 3: Under RM15, 4: Deals
  int _discoveryPageLimit = 10;
  bool _isLoadingMoreDiscovery = false;
  double? _userLat;
  double? _userLng;
  double _categoryScrollProgress = 0.0;

  final ScrollController _scrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  Timer? _shopsRetryTimer;
  Timer? _discoveryBatchTimer;
  StreamSubscription? _shopsSubscription;
  StreamSubscription<AuthState>? _authSubscription;

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
    _scrollController.addListener(_onHomeScroll);
    _categoryScrollController.addListener(_onCategoryScroll);
    _loadUserInfoAndLocation();
    _loadCachedHomeData();
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
    _shopsRetryTimer?.cancel();
    _discoveryBatchTimer?.cancel();
    _shopsSubscription?.cancel();
    _authSubscription?.cancel();
    _scrollController.removeListener(_onHomeScroll);
    _scrollController.dispose();
    _categoryScrollController.removeListener(_onCategoryScroll);
    _categoryScrollController.dispose();
    super.dispose();
  }

  void _onCategoryScroll() {
    if (!_categoryScrollController.hasClients) return;
    final maxExtent = _categoryScrollController.position.maxScrollExtent;
    final double next = maxExtent > 0
        ? (_categoryScrollController.offset / maxExtent).clamp(0.0, 1.0)
        : 0.0;
    if ((next - _categoryScrollProgress).abs() >= 0.02 && mounted) {
      setState(() => _categoryScrollProgress = next);
    }
  }

  String get _shortLocationLabel {
    final trimmed = _locationName.trim();
    if (trimmed.isEmpty) return 'customer.location'.tr();
    final firstPart = trimmed.split(',').first.trim();
    return firstPart.isNotEmpty ? firstPart : trimmed;
  }

  List<ProductModel> get _filteredDiscoveryProducts {
    return _discoveryProducts.where((p) {
      if (_selectedDiscoveryTab == 1) return p.isService;
      if (_selectedDiscoveryTab == 2) return p.isProduct;
      if (_selectedDiscoveryTab == 3) return p.minPrice > 0 && p.minPrice <= 15.0;
      if (_selectedDiscoveryTab == 4) return p.hasDiscount;
      return true;
    }).toList();
  }

  void _onHomeScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 340) return;

    final int total = _filteredDiscoveryProducts.length;
    if (_discoveryPageLimit >= total || _isLoadingMoreDiscovery) return;

    setState(() {
      _isLoadingMoreDiscovery = true;
    });
    _discoveryBatchTimer?.cancel();
    _discoveryBatchTimer = Timer(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      setState(() {
        _discoveryPageLimit = min(total, _discoveryPageLimit + 10);
        _isLoadingMoreDiscovery = false;
      });
    });
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

  Future<void> _loadCachedHomeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      List<Map<String, dynamic>>? cachedShops;
      final shopsJson = prefs.getString('cached_nearby_shops_v1');
      if (shopsJson != null && shopsJson.trim().isNotEmpty) {
        final List decoded = jsonDecode(shopsJson);
        final list = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        if (list.isNotEmpty) {
          _updateDistancesForList(list);
          cachedShops = list;
        }
      }

      List<ProductModel>? cachedProducts;
      final productsJson = prefs.getString('cached_discovery_products_v1');
      if (productsJson != null && productsJson.trim().isNotEmpty) {
        final List decoded = jsonDecode(productsJson);
        final list = decoded
            .whereType<Map>()
            .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
            .where((p) => p.name.trim().isNotEmpty && !p.isOutOfStock)
            .toList();
        if (list.isNotEmpty) {
          cachedProducts = list;
        }
      }

      List<Map<String, dynamic>>? cachedVouchers;
      final vouchersJson = prefs.getString('cached_live_vouchers_v1');
      if (vouchersJson != null && vouchersJson.trim().isNotEmpty) {
        final List decoded = jsonDecode(vouchersJson);
        final list = decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (list.isNotEmpty) {
          cachedVouchers = list;
        }
      }

      if (!mounted) return;
      if (cachedShops != null || cachedProducts != null || cachedVouchers != null) {
        setState(() {
          if (cachedShops != null) {
            _nearbyShops = cachedShops;
            _isLoadingShops = false;
            _isUsingCachedData = true;
          }
          if (cachedProducts != null) {
            _discoveryProducts = cachedProducts;
            _isLoadingDiscovery = false;
          }
          if (cachedVouchers != null) {
            _liveVouchers = cachedVouchers;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading cached home data: $e');
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

  Future<void> _saveDiscoveryCache(
    List<ProductModel> products,
    List<Map<String, dynamic>> vouchers,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (products.isNotEmpty) {
        final serializedProducts = products.take(30).map((p) => p.toJson()).toList();
        await prefs.setString(
          'cached_discovery_products_v1',
          jsonEncode(serializedProducts),
        );
      }
      if (vouchers.isNotEmpty) {
        await prefs.setString(
          'cached_live_vouchers_v1',
          jsonEncode(vouchers.take(12).toList()),
        );
      }
    } catch (e) {
      debugPrint('Error caching discovery feed: $e');
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

  void _applyLoadedShops(List<dynamic> data) {
    if (!mounted) return;
    _offlineDialogShown = false;
    _shopsRetryTimer?.cancel();

    if (data.isNotEmpty) {
      final List<Map<String, dynamic>> loaded = [];
      for (var row in data) {
        if (row is! Map) continue;
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
  }

  void _startShopsRealtimeStream() {
    try {
      _shopsSubscription?.cancel();
      _shopsSubscription = Supabase.instance.client
          .from('businesses')
          .stream(primaryKey: ['id'])
          .eq('status', 'active')
          .listen(
            (data) {
              _applyLoadedShops(data);
            },
            onError: (err) {
              // Abaikan ralat WebSocket sementara — data cache/REST kekal dipaparkan seperti Shopee
              debugPrint('Supabase realtime stream transient error (ignored): $err');
            },
          );
    } catch (e) {
      debugPrint('Error setting up shops realtime stream: $e');
    }
  }

  Future<void> _fetchShops({bool isRetry = false}) async {
    try {
      final data = await Supabase.instance.client
          .from('businesses')
          .select()
          .eq('status', 'active')
          .timeout(const Duration(seconds: 6));

      if (!mounted) return;
      _applyLoadedShops(data as List<dynamic>);
      _startShopsRealtimeStream();
    } catch (e) {
      debugPrint('REST fetch shops error (retry=$isRetry): $e');
      if (!mounted) return;

      if (!isRetry) {
        // Shopee-style: kekalkan cache & cuba reload senyap selepas 3 saat dahulu sebelum anggap offline
        _shopsRetryTimer?.cancel();
        _shopsRetryTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            _fetchShops(isRetry: true);
          }
        });
        return;
      }

      setState(() {
        _isLoadingShops = false;
        _hasFetchError = true;
      });

      // Hanya papar popup offline jika tiada langsung data cache untuk ditunjukkan kepada pengguna
      if (_nearbyShops.isEmpty && _discoveryProducts.isEmpty) {
        _showOfflinePopupIfNeeded();
      }
    }
  }

  Future<void> _fetchHomeDiscoveryData({bool isRetry = false}) async {
    try {
      final client = Supabase.instance.client;
      final results = await Future.wait([
        client
            .from('business_products')
            .select()
            .eq('is_active', true)
            .order('is_featured', ascending: false)
            .order('created_at', ascending: false)
            .limit(30),
        client
            .from('vouchers')
            .select()
            .eq('is_active', true)
            .order('created_at', ascending: false)
            .limit(12)
            .catchError((_) => <dynamic>[]),
      ]).timeout(const Duration(seconds: 7));

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

      _saveDiscoveryCache(parsedProducts, activeVouchers);

      if (!mounted) return;
      setState(() {
        _discoveryProducts = parsedProducts;
        _liveVouchers = activeVouchers;
        _isLoadingDiscovery = false;
        _discoveryPageLimit = min(max(_discoveryPageLimit, 10), max(parsedProducts.length, 10));
      });
    } catch (e) {
      debugPrint('Error fetching home discovery data (retry=$isRetry): $e');
      if (!mounted) return;
      if (!isRetry) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _fetchHomeDiscoveryData(isRetry: true);
          }
        });
        return;
      }
      setState(() => _isLoadingDiscovery = false);
    }
  }

  Future<void> _handleRefresh() async {
    _offlineDialogShown = false;
    _shopsRetryTimer?.cancel();
    setState(() {
      _hasFetchError = false;
    });
    await Future.wait([
      _fetchShops(),
      _fetchHomeDiscoveryData(),
    ]);
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
                  constraints: BoxConstraints(maxWidth: isDesktop ? 860 : double.infinity),
                  child: Stack(
                    children: [
                      RefreshIndicator(
                        onRefresh: _handleRefresh,
                        color: const Color(0xFF3B82F6),
                        edgeOffset: 58,
                        child: CustomScrollView(
                          controller: _scrollController,
                          cacheExtent: 300,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          slivers: [
                            // Top spacing for compact floating glass search bar
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 58),
                            ),

                            // 1. Compact Horizontal Scrollable Utility Row (TikTok Shop style)
                            SliverToBoxAdapter(
                              child: _buildScrollableUtilityRow(isDark),
                            ),

                            const SliverToBoxAdapter(child: SizedBox(height: 8)),

                            // 2. Single-Row Horizontal Scrollable Category Glass Card + Indicator
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: _buildScrollableCategoryCard(isDark),
                              ),
                            ),

                            const SliverToBoxAdapter(child: SizedBox(height: 10)),

                            // 3. Live Active Order Banner (Only shown if user has active order)
                            if (Supabase.instance.client.auth.currentUser != null)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: _buildActiveOrderBanner(isDark),
                                ),
                              ),

                            // 4. Side-by-Side 2-Column Bento Spotlight Row (Nearby Spots | Hot Deals)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: _buildSpotlightBentoRow(isDark),
                              ),
                            ),

                            const SliverToBoxAdapter(child: SizedBox(height: 10)),

                            // 5. Compact Horizontal Scrollable Discovery Filter Tabs (Underline Style)
                            SliverToBoxAdapter(
                              child: _buildDiscoveryFilterTabs(isDark),
                            ),

                            const SliverToBoxAdapter(child: SizedBox(height: 10)),

                            // 6. Responsive 2/3-Column Natural-Aspect Masonry Discovery Feed
                            ..._buildDiscoveryFeedSlivers(isDark, isDesktop),

                            // Bottom Spacer
                            SliverToBoxAdapter(child: SizedBox(height: isDesktop ? 40 : 120)),
                          ],
                        ),
                      ),

                      // Compact Floating Liquid Glass Search + Actions Header
                      Positioned(
                        top: 8,
                        left: 12,
                        right: 12,
                        child: _buildTopSearchHeader(isDark),
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

  // --- WIDGET 1: COMPACT FLOATING LIQUID GLASS SEARCH + ACTIONS HEADER ---
  Widget _buildTopSearchHeader(bool isDark) {
    final bool isLoggedIn = Supabase.instance.client.auth.currentUser != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Integrated Liquid Glass Search Pill (Search + QR + Search CTA)
        Expanded(
          child: GestureDetector(
            onTap: () => _openSearchPage(),
            child: GlassContainer(
              useOwnLayer: true,
              quality: GlassQuality.standard,
              shape: const LiquidRoundedSuperellipse(borderRadius: 24.0),
              settings: LiquidGlassSettings(
                thickness: 0.1,
                blur: 10.0,
                lightIntensity: isDark ? 0.1 : 0.2,
                glassColor: Colors.transparent,
              ),
              child: Container(
                height: 42,
                padding: const EdgeInsets.only(left: 12, right: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: isDark
                      ? const Color(0xFF141926).withValues(alpha: 0.82)
                      : Colors.white.withValues(alpha: 0.88),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.35)
                        : const Color(0xFF3B82F6).withValues(alpha: 0.28),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedSearch01,
                      color: Color(0xFF38BDF8),
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'search.hint'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _openQrScanner,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedQrCode01,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                          size: 17,
                        ),
                      ),
                    ),
                    Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          'customer.search_btn'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
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

        const SizedBox(width: 8),

        // Compact Right Liquid Glass Action Pill (Notification + Orders OR Guest Login)
        GlassContainer(
          useOwnLayer: true,
          quality: GlassQuality.standard,
          shape: const LiquidRoundedSuperellipse(borderRadius: 24.0),
          settings: LiquidGlassSettings(
            thickness: 0.1,
            blur: 10.0,
            lightIntensity: isDark ? 0.1 : 0.2,
            glassColor: Colors.transparent,
          ),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: isDark
                  ? const Color(0xFF141926).withValues(alpha: 0.82)
                  : Colors.white.withValues(alpha: 0.88),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.70),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isLoggedIn)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pushNamed('/login'),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: Tooltip(
                          message: 'customer.login_tooltip'.tr(),
                          child: const HugeIcon(
                            icon: HugeIcons.strokeRoundedLogin02,
                            color: Color(0xFF3B82F6),
                            size: 19,
                          ),
                        ),
                      ),
                    ),
                  )
                else ...[
                  // Notifications Bell with Live Unread Badge
                  GestureDetector(
                    onTap: () => CustomerNotificationCenterSheet.show(context),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 38,
                      height: 40,
                      child: Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedNotification01,
                              color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                              size: 19,
                            ),
                            ValueListenableBuilder<int>(
                              valueListenable: NotificationData.unreadCount,
                              builder: (context, unread, _) {
                                if (unread <= 0) return const SizedBox.shrink();
                                return Positioned(
                                  top: -5,
                                  right: -6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF4757),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF141926) : Colors.white,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        unread > 9 ? '9+' : unread.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                          height: 1.0,
                                        ),
                                      ),
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
                  Container(
                    width: 1,
                    height: 18,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  // Quick Filter Search Button
                  GestureDetector(
                    onTap: () => _openSearchPage(openFilters: true),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 38,
                      height: 40,
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedSlidersHorizontal,
                          color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                          size: 17,
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

  void _openSearchPage({bool openFilters = false}) {
    Navigator.push(
      context,
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) => HomeSearchScreen(
          initialShops: _nearbyShops,
          initialProducts: _discoveryProducts,
          userLat: _userLat,
          userLng: _userLng,
          openFiltersOnStart: openFilters,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  // --- WIDGET 2: HORIZONTAL SCROLLABLE UTILITY ROW (TIKTOK SHOP STYLE) ---
  Widget _buildScrollableUtilityRow(bool isDark) {
    final int voucherCount = _liveVouchers.length;

    final List<({
      dynamic icon,
      Color color,
      String label,
      String? badge,
      bool isLoading,
      VoidCallback onTap,
    })> items = [
      (
        icon: HugeIcons.strokeRoundedLocation01,
        color: const Color(0xFFEF4444),
        label: _shortLocationLabel,
        badge: null,
        isLoading: _isFetchingLocation,
        onTap: () => _fetchAndApplyLiveLocation(silent: false, requestPermission: true),
      ),
      (
        icon: HugeIcons.strokeRoundedShoppingBag02,
        color: const Color(0xFF3B82F6),
        label: 'customer.utility_orders'.tr(),
        badge: null,
        isLoading: false,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyBookingsView()),
        ),
      ),
      (
        icon: HugeIcons.strokeRoundedTicket01,
        color: const Color(0xFFEC4899),
        label: 'customer.utility_vouchers'.tr(),
        badge: voucherCount > 0 ? voucherCount.toString() : null,
        isLoading: false,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VoucherScreen()),
        ),
      ),
      (
        icon: HugeIcons.strokeRoundedQrCode01,
        color: const Color(0xFF10B981),
        label: 'customer.utility_scan'.tr(),
        badge: null,
        isLoading: false,
        onTap: _openQrScanner,
      ),
      (
        icon: HugeIcons.strokeRoundedPlayCircle,
        color: const Color(0xFF8B5CF6),
        label: 'customer.utility_feed'.tr(),
        badge: null,
        isLoading: false,
        onTap: () => widget.onSwitchTab?.call(2),
      ),
      (
        icon: HugeIcons.strokeRoundedMapsLocation01,
        color: const Color(0xFF06B6D4),
        label: 'customer.utility_nearby'.tr(),
        badge: null,
        isLoading: false,
        onTap: () => widget.onSwitchTab?.call(1),
      ),
      (
        icon: HugeIcons.strokeRoundedMessage01,
        color: const Color(0xFFF59E0B),
        label: 'customer.utility_messages'.tr(),
        badge: null,
        isLoading: false,
        onTap: () => widget.onSwitchTab?.call(3),
      ),
    ];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final item = items[index];
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: item.onTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 66,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        if (item.isLoading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
                            ),
                          )
                        else
                          HugeIcon(
                            icon: item.icon,
                            color: isDark ? Colors.white.withValues(alpha: 0.90) : const Color(0xFF1E293B),
                            size: 19,
                          ),
                        if (item.badge != null)
                          Positioned(
                            top: -6,
                            right: -11,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                              decoration: BoxDecoration(
                                color: item.color,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF0A0A14) : const Color(0xFFF8F9FA),
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                item.badge!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
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

  // --- WIDGET 3: SINGLE-ROW SCROLLABLE CATEGORY GLASS CARD + SCROLL INDICATOR ---
  Widget _buildScrollableCategoryCard(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isDark
                ? const Color(0xFF141926).withValues(alpha: 0.72)
                : Colors.white.withValues(alpha: 0.86),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.11 : 0.75),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.045),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 74,
                child: ListView.separated(
                  controller: _categoryScrollController,
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _quickIntents.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
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
                          ExploreView.pendingSearch.value =
                              ExploreSearchRequest(categoryId: catKey);
                          widget.onSwitchTab?.call(1);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: 64,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      color: isDark
                                          ? catColor.withValues(alpha: 0.16)
                                          : catColor.withValues(alpha: 0.11),
                                      border: Border.all(
                                        color: catColor.withValues(
                                          alpha: isDark ? 0.34 : 0.24,
                                        ),
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
                                  if (count > 0)
                                    Positioned(
                                      top: -4,
                                      right: -6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4.5,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: catColor,
                                          borderRadius: BorderRadius.circular(9),
                                          border: Border.all(
                                            color: isDark
                                                ? const Color(0xFF141926)
                                                : Colors.white,
                                            width: 1.3,
                                          ),
                                        ),
                                        child: Text(
                                          count.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w800,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                (cat['titleKey'] as String).tr(),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.88)
                                      : const Color(0xFF1E293B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Shopee / TikTok Shop style live scroll indicator pill
              Padding(
                padding: const EdgeInsets.only(bottom: 7, top: 1),
                child: Container(
                  width: 34,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Align(
                    alignment: Alignment(-1.0 + 2.0 * _categoryScrollProgress, 0),
                    child: Container(
                      width: 16,
                      height: 3.5,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF38BDF8), Color(0xFF3B82F6)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET 4: LIVE ACTIVE ORDER BANNER (COMPACT FROSTED GLASS) ---
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
        final createdDt = DateTime.tryParse((latest['created_at'] ?? '').toString());
        final bool isPos = (latest['source']?.toString().toLowerCase() == 'pos');
        final String shortId = isPos
            ? NgamRef.pos(orderId, createdDt)
            : NgamRef.order(orderId, createdAt: createdDt);

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
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderStatusTrackerScreen(
                    orderId: orderId,
                    shopName: 'customer.order_short_title'.tr(args: [shortId]),
                    totalAmount: total,
                    shopId: latest['business_id']?.toString(),
                  ),
                ),
              );
            },
            child: GlassContainer(
              useOwnLayer: true,
              quality: GlassQuality.standard,
              shape: const LiquidRoundedSuperellipse(borderRadius: 18.0),
              settings: LiquidGlassSettings(
                thickness: 0.1,
                blur: 10.0,
                lightIntensity: isDark ? 0.1 : 0.2,
                glassColor: Colors.transparent,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      statusColor.withValues(alpha: isDark ? 0.16 : 0.12),
                      Colors.white.withValues(alpha: isDark ? 0.04 : 0.65),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 1.0),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: HugeIcon(
                        icon: status == 'ready'
                            ? HugeIcons.strokeRoundedShoppingCart02
                            : HugeIcons.strokeRoundedClock01,
                        color: statusColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'customer.active_order'.tr(args: [shortId]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• RM ${total.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            statusLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'customer.track_qr'.tr(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10.5,
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

  // --- WIDGET 5: 2-COLUMN BENTO SPOTLIGHT ROW (NEARBY SPOTS | HOT DEALS) ---
  Widget _buildSpotlightBentoRow(bool isDark) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildNearbyBentoCard(isDark)),
          const SizedBox(width: 10),
          Expanded(child: _buildDealsBentoCard(isDark)),
        ],
      ),
    );
  }

  Widget _buildBentoGlassContainer({
    required bool isDark,
    required Widget child,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isDark
                ? const Color(0xFF141926).withValues(alpha: 0.78)
                : Colors.white.withValues(alpha: 0.88),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.11 : 0.75),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.045),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildBentoNetworkThumb(String url, {required String fallbackText, required bool isDark}) {
    Widget fallback() => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF2563EB).withValues(alpha: 0.45), const Color(0xFF1E293B)]
                  : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : 'N',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        );

    if (url.isEmpty) return fallback();
    if (kIsWeb) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => fallback(),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 240,
      placeholder: (_, __) => _buildImageShimmer(isDark, 64),
      errorWidget: (_, __, ___) => fallback(),
    );
  }

  String _formatCompactDist(dynamic dist) {
    if (dist == null) return '';
    final d = (dist is num) ? dist.toDouble() : double.tryParse(dist.toString());
    if (d == null) return '';
    return d < 1.0 ? '${(d * 1000).round()}m' : '${d.toStringAsFixed(1)}km';
  }

  Widget _buildNearbyBentoCard(bool isDark) {
    final shops = _nearbyShops.take(2).toList();

    return _buildBentoGlassContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => widget.onSwitchTab?.call(1),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3B82F6),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0xFF3B82F6), blurRadius: 6, spreadRadius: 1),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'customer.nearby_bento_title'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  size: 13,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_isLoadingShops && shops.isEmpty)
            Row(
              children: List.generate(2, (i) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 1 ? 6 : 0),
                    child: Column(
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: _buildImageShimmer(isDark, 56),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            width: 48,
                            height: 10,
                            child: _buildImageShimmer(isDark, 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            )
          else if (_hasFetchError && shops.isEmpty)
            SizedBox(
              height: 74,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isLoadingShops = true;
                      _hasFetchError = false;
                    });
                    _fetchShops();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedRefresh,
                          color: Color(0xFF3B82F6),
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'common.retry'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF3B82F6),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else if (shops.isEmpty)
            SizedBox(
              height: 74,
              child: Center(
                child: Text(
                  'customer.no_nearby_shops'.tr(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(shops.length, (idx) {
                final shop = shops[idx];
                final String name =
                    (shop['business_name'] ?? shop['name'] ?? 'Ngam').toString().trim();
                final String cat =
                    (shop['business_industry'] ?? shop['category'] ?? 'services')
                        .toString()
                        .toUpperCase();
                final String rawImg = (shop['business_logo_url'] ??
                        shop['business_cover_url'] ??
                        shop['cover'] ??
                        shop['image'] ??
                        '')
                    .toString()
                    .trim();
                final String img =
                    rawImg.contains('photo-1503951914875-452162b0f3f1') ? '' : rawImg;
                final String dist = _formatCompactDist(shop['distanceKm']);

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: idx == 1 ? 6 : 0),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          final shopWithCat = {
                            ...shop,
                            'category': cat,
                            'business_industry': shop['business_industry'] ?? cat,
                          };
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BusinessStoreView(shop: shopWithCat),
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 58,
                                  height: 58,
                                  padding: const EdgeInsets.all(2.2),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF38BDF8), Color(0xFF2563EB)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(1.5),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark ? const Color(0xFF141926) : Colors.white,
                                    ),
                                    child: ClipOval(
                                      child: _buildBentoNetworkThumb(
                                        img,
                                        fallbackText: name,
                                        isDark: isDark,
                                      ),
                                    ),
                                  ),
                                ),
                                if (dist.isNotEmpty)
                                  Positioned(
                                    bottom: -3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5.5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF141926)
                                              : Colors.white,
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Text(
                                        dist,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildDealsBentoCard(bool isDark) {
    final Map<String, Map<String, dynamic>> shopById = {
      for (final s in _nearbyShops)
        if (s['id'] != null) s['id'].toString(): s,
    };

    // Prioritize discounted items, then top available discovery items
    final List<ProductModel> dealCandidates = [
      ..._discoveryProducts.where((p) => p.hasDiscount),
      ..._discoveryProducts.where((p) => !p.hasDiscount),
    ].take(2).toList();

    return _buildBentoGlassContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              if (_liveVouchers.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VoucherScreen()),
                );
              } else {
                setState(() {
                  _selectedDiscoveryTab = 4;
                  _discoveryPageLimit = 10;
                });
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedSparkles,
                  color: Color(0xFFEC4899),
                  size: 14,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'customer.deals_bento_title'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  size: 13,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_isLoadingDiscovery && dealCandidates.isEmpty)
            Row(
              children: List.generate(2, (i) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 1 ? 6 : 0),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 58,
                            width: double.infinity,
                            child: _buildImageShimmer(isDark, 58),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            width: 44,
                            height: 10,
                            child: _buildImageShimmer(isDark, 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            )
          else if (dealCandidates.isEmpty)
            SizedBox(
              height: 74,
              child: Center(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VoucherScreen()),
                  ),
                  child: Text(
                    'customer.deals_empty_hint'.tr(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(dealCandidates.length, (idx) {
                final product = dealCandidates[idx];
                final shop = shopById[product.shopId] ??
                    {
                      'id': product.shopId,
                      'name': 'Ngam Partner',
                      'category':
                          product.category.isNotEmpty ? product.category : 'Service',
                    };
                final String badgeLabel = product.hasDiscount
                    ? '-${product.discountPercent}%'
                    : 'customer.deals_hot_badge'.tr();

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: idx == 1 ? 6 : 0),
                    child: MouseRegion(
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
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                height: 58,
                                width: double.infinity,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _buildBentoNetworkThumb(
                                      product.imageUrl,
                                      fallbackText: product.name,
                                      isDark: isDark,
                                    ),
                                    Positioned(
                                      left: 4,
                                      bottom: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: product.hasDiscount
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFFEC4899),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          badgeLabel,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w900,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                product.hasPriceRange
                                    ? 'RM${product.minPrice.toStringAsFixed(2)}+'
                                    : 'RM${product.minPrice.toStringAsFixed(2)}',
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  // --- WIDGET 6: COMPACT SCROLLABLE DISCOVERY FILTER TABS (UNDERLINE STYLE) ---
  Widget _buildDiscoveryFilterTabs(bool isDark) {
    final List<String> tabLabels = [
      'customer.feed_tab_all'.tr(),
      'customer.feed_tab_services'.tr(),
      'customer.feed_tab_products'.tr(),
      'customer.feed_tab_budget'.tr(),
      'customer.feed_tab_deals'.tr(),
    ];

    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            width: 1.0,
          ),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: tabLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, idx) {
          final bool isSel = _selectedDiscoveryTab == idx;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedDiscoveryTab = idx;
                _discoveryPageLimit = 10;
              }),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Text(
                    tabLabels[idx],
                    style: TextStyle(
                      color: isSel
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                      fontSize: 13,
                      fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 2.5,
                    width: isSel ? 24 : 0,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildDiscoveryFeedSlivers(bool isDark, bool isDesktop) {
    final List<ProductModel> filtered = _filteredDiscoveryProducts;

    if (_isLoadingDiscovery && _discoveryProducts.isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: isDesktop ? 3 : 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childCount: 6,
            itemBuilder: (_, idx) => _buildDiscoveryShimmerCard(isDark, idx),
          ),
        ),
      ];
    }

    if (filtered.isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverToBoxAdapter(
            child: Container(
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
            ),
          ),
        ),
      ];
    }

    final Map<String, Map<String, dynamic>> shopById = {
      for (final s in _nearbyShops)
        if (s['id'] != null) s['id'].toString(): s,
    };

    final int visibleCount = min(_discoveryPageLimit, filtered.length);
    final bool hasMore = visibleCount < filtered.length;

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverMasonryGrid.count(
          crossAxisCount: isDesktop ? 3 : 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childCount: visibleCount + (hasMore ? 2 : 0),
          itemBuilder: (context, index) {
            if (index >= visibleCount) {
              return _buildDiscoveryShimmerCard(isDark, index);
            }
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
      ),
    ];
  }

  Widget _buildImageShimmer(bool isDark, double height) {
    final Color baseColor =
        isDark ? const Color(0xFF1A2033) : const Color(0xFFE2E8F0);
    final Color highlightColor =
        isDark ? const Color(0xFF28324E) : const Color(0xFFF8FAFC);
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(milliseconds: 1150),
      child: Container(
        height: height,
        width: double.infinity,
        color: baseColor,
      ),
    );
  }

  Widget _buildDiscoveryShimmerCard(bool isDark, int index) {
    final Color baseColor =
        isDark ? const Color(0xFF1A2033) : const Color(0xFFE2E8F0);
    final Color highlightColor =
        isDark ? const Color(0xFF28324E) : const Color(0xFFF8FAFC);
    final double imgHeight = index.isEven ? 148 : 178;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark
            ? const Color(0xFF141926).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.88),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.70),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        period: const Duration(milliseconds: 1150),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: imgHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 13,
              width: double.infinity,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 12,
              width: 96,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 14,
              width: 72,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 10,
              width: 110,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ],
        ),
      ),
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

    return KeyedSubtree(
      key: ValueKey('discovery_${product.id}'),
      child: MouseRegion(
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
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: isDark
                  ? const Color(0xFF141926).withValues(alpha: 0.86)
                  : Colors.white.withValues(alpha: 0.88),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.75),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.055),
                  blurRadius: 16,
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
                  // Natural-height Masonry Image Container (follows true photo aspect ratio)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: NaturalAspectNetworkImage(
                      imageUrl: product.imageUrl,
                      defaultAspectRatio: 1.0,
                      minAspectRatio: 0.45,
                      maxAspectRatio: 2.2,
                      placeholderBuilder: (_, height) =>
                          _buildImageShimmer(isDark, height),
                      errorBuilder: (_, height) => imageFallback(height),
                      overlayChildren: [
                        Positioned(
                          top: 7,
                          left: 7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
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
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            product.formattedPriceRange,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Color(0xFF3B82F6),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
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
