import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/product_model.dart';
import '../explore/business_store_view.dart';
import '../explore/product_detail_screen.dart';
import 'post_route_loader.dart';

// =============================================================================
// HomeSearchScreen — Halaman Carian Khas Ngam (Kedai, Servis, Produk & Video)
// Gaya Liquid Glass Ngam × Super-Search (Shopee × TikTok)
// =============================================================================

enum _SearchTypeFilter { all, services, products }

enum _SearchSortMode { relevance, nearest, priceLow, priceHigh }

class HomeSearchScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialShops;
  final List<ProductModel> initialProducts;
  final List<Map<String, dynamic>> initialFeedPosts;
  final double? userLat;
  final double? userLng;
  final bool openFiltersOnStart;
  final int initialResultTab; // 0: All, 1: Stores, 2: Products & Services, 3: Videos
  final bool isVideoFocused;

  const HomeSearchScreen({
    super.key,
    this.initialShops = const [],
    this.initialProducts = const [],
    this.initialFeedPosts = const [],
    this.userLat,
    this.userLng,
    this.openFiltersOnStart = false,
    this.initialResultTab = 0,
    this.isVideoFocused = false,
  });

  @override
  State<HomeSearchScreen> createState() => _HomeSearchScreenState();
}

class _HomeSearchScreenState extends State<HomeSearchScreen> {
  static const String _recentPrefsKey = 'home_recent_searches_v1';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  Timer? _debounceTimer;
  List<String> _recentSearches = [];

  List<Map<String, dynamic>> _allShops = [];
  List<ProductModel> _allProducts = [];
  List<Map<String, dynamic>> _allFeedPosts = [];
  List<Map<String, dynamic>> _remoteShops = [];
  List<ProductModel> _remoteProducts = [];
  List<Map<String, dynamic>> _remoteFeedPosts = [];

  bool _isSearchingRemote = false;
  int _selectedResultTab = 0; // 0: All, 1: Stores, 2: Products & Services, 3: Videos
  _SearchTypeFilter _typeFilter = _SearchTypeFilter.all;
  _SearchSortMode _sortMode = _SearchSortMode.relevance;
  double? _maxBudget;
  String? _selectedCategoryFilter;

  String get _query => _searchController.text.trim();

  bool get _hasActiveFilters =>
      _typeFilter != _SearchTypeFilter.all ||
      _sortMode != _SearchSortMode.relevance ||
      _maxBudget != null ||
      _selectedCategoryFilter != null;

  bool get _isSearchMode => _query.isNotEmpty || _hasActiveFilters;

  @override
  void initState() {
    super.initState();
    _selectedResultTab = widget.initialResultTab.clamp(0, 3);
    _allShops = List<Map<String, dynamic>>.from(widget.initialShops);
    _allProducts = List<ProductModel>.from(widget.initialProducts);
    _allFeedPosts = widget.initialFeedPosts
        .map((e) => _normalizeSingleFeedPost(Map<String, dynamic>.from(e)))
        .toList();
    _loadRecentSearches();

    if (_allShops.isEmpty || _allProducts.isEmpty || _allFeedPosts.isEmpty) {
      _warmFallbackCatalog();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.openFiltersOnStart) {
        _openFilterSheet();
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_recentPrefsKey) ?? [];
      if (mounted) {
        setState(() => _recentSearches = list);
      }
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
    }
  }

  Future<void> _saveRecentSearch(String term) async {
    final clean = term.trim();
    if (clean.length < 2) return;
    try {
      final updated = <String>[
        clean,
        ..._recentSearches.where((e) => e.toLowerCase() != clean.toLowerCase()),
      ].take(8).toList();
      if (mounted) {
        setState(() => _recentSearches = updated);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentPrefsKey, updated);
    } catch (e) {
      debugPrint('Error saving recent search: $e');
    }
  }

  Future<void> _clearRecentSearches() async {
    try {
      setState(() => _recentSearches = []);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentPrefsKey);
    } catch (e) {
      debugPrint('Error clearing recent searches: $e');
    }
  }

  static const String _feedPostSelect = '''
    id,
    business_id,
    title,
    caption,
    media_url,
    media_type,
    category,
    service_tag,
    likes_count,
    views_count,
    created_at,
    businesses (
      id,
      business_name,
      business_handle,
      business_logo_url,
      business_cover_url,
      business_industry
    )
  ''';

  Future<void> _warmFallbackCatalog() async {
    try {
      final client = Supabase.instance.client;
      final futures = await Future.wait([
        if (_allShops.isEmpty)
          client
              .from('businesses')
              .select()
              .eq('status', 'active')
              .limit(40)
              .catchError((_) => <dynamic>[])
        else
          Future.value(<dynamic>[]),
        if (_allProducts.isEmpty)
          client
              .from('business_products')
              .select()
              .eq('is_active', true)
              .order('is_featured', ascending: false)
              .limit(40)
              .catchError((_) => <dynamic>[])
        else
          Future.value(<dynamic>[]),
        if (_allFeedPosts.isEmpty)
          client
              .from('feed_posts')
              .select(_feedPostSelect)
              .eq('status', 'published')
              .order('is_pinned', ascending: false)
              .order('created_at', ascending: false)
              .limit(24)
              .catchError((_) => <dynamic>[])
        else
          Future.value(<dynamic>[]),
      ]).timeout(const Duration(seconds: 6));

      if (!mounted) return;
      final rawShops = futures[0] as List;
      final rawProducts = futures[1] as List;
      final rawPosts = futures[2] as List;

      setState(() {
        if (rawShops.isNotEmpty && _allShops.isEmpty) {
          _allShops = _normalizeShops(rawShops);
        }
        if (rawProducts.isNotEmpty && _allProducts.isEmpty) {
          _allProducts = rawProducts
              .whereType<Map>()
              .map((r) => ProductModel.fromJson(Map<String, dynamic>.from(r)))
              .where((p) => p.name.trim().isNotEmpty && !p.isOutOfStock)
              .toList();
        }
        if (rawPosts.isNotEmpty && _allFeedPosts.isEmpty) {
          _allFeedPosts = _normalizeFeedPosts(rawPosts);
        }
      });
    } catch (e) {
      debugPrint('Search catalog warm error: $e');
    }
  }

  Map<String, dynamic> _normalizeSingleFeedPost(Map<String, dynamic> row) {
    final biz = row['businesses'] is Map
        ? Map<String, dynamic>.from(row['businesses'] as Map)
        : <String, dynamic>{};

    final String id = (row['id'] ?? '').toString();
    final String shopName = (row['shopName'] ?? biz['business_name'] ?? 'Ngam').toString();
    final String shopAvatar = (row['shopAvatar'] ?? biz['business_logo_url'] ?? '').toString().trim();
    final String mediaType = (row['mediaType'] ?? row['media_type'] ?? 'image').toString().toLowerCase();
    final bool isVideo = mediaType.contains('video');

    String thumb = (row['thumbnail'] ?? row['cover'] ?? '').toString().trim();
    if (thumb.isEmpty) {
      final rawMedia = (row['image'] ?? row['media_url'] ?? '').toString().trim();
      final bool mediaLooksVideo = isVideo ||
          rawMedia.toLowerCase().endsWith('.mp4') ||
          rawMedia.toLowerCase().endsWith('.mov') ||
          rawMedia.toLowerCase().endsWith('.webm');
      if (!mediaLooksVideo && rawMedia.startsWith('http')) {
        thumb = rawMedia;
      } else {
        thumb = (biz['business_cover_url'] ?? biz['business_logo_url'] ?? shopAvatar).toString().trim();
      }
    }

    return {
      'id': id,
      'title': (row['title'] ?? '').toString().trim(),
      'caption': (row['caption'] ?? '').toString().trim(),
      'category': (row['category'] ?? biz['business_industry'] ?? '').toString().trim(),
      'serviceTag': (row['serviceTag'] ?? row['service_tag'] ?? '').toString().trim(),
      'shopName': shopName,
      'shopHandle': (row['shopHandle'] ?? biz['business_handle'] ?? '').toString().trim(),
      'shopAvatar': shopAvatar,
      'thumbnail': thumb,
      'isVideo': isVideo,
      'likes': (row['likes'] ?? row['likes_count'] ?? 0) is num
          ? ((row['likes'] ?? row['likes_count'] ?? 0) as num).toInt()
          : 0,
      'views': (row['views'] ?? row['views_count'] ?? 0) is num
          ? ((row['views'] ?? row['views_count'] ?? 0) as num).toInt()
          : 0,
    };
  }

  List<Map<String, dynamic>> _normalizeFeedPosts(List<dynamic> raw) {
    return raw
        .whereType<Map>()
        .map((r) => _normalizeSingleFeedPost(Map<String, dynamic>.from(r)))
        .where((p) => (p['id']?.toString().isNotEmpty ?? false))
        .toList();
  }

  List<Map<String, dynamic>> get _filteredFeedPosts {
    final q = _query.toLowerCase();
    final byId = <String, Map<String, dynamic>>{};
    for (final p in _allFeedPosts) {
      final id = p['id']?.toString() ?? '';
      if (id.isNotEmpty) byId[id] = p;
    }
    for (final p in _remoteFeedPosts) {
      final id = p['id']?.toString() ?? '';
      if (id.isNotEmpty) byId[id] = p;
    }

    final list = byId.values.where((p) {
      final title = (p['title'] ?? '').toString();
      final caption = (p['caption'] ?? '').toString();
      final cat = (p['category'] ?? '').toString();
      final tag = (p['serviceTag'] ?? '').toString();
      final shopName = (p['shopName'] ?? '').toString();
      final handle = (p['shopHandle'] ?? '').toString();

      if (_selectedCategoryFilter != null &&
          !_matchesCategoryKey('$cat $title $caption $tag', _selectedCategoryFilter!)) {
        return false;
      }
      if (q.isEmpty) return true;
      final hay = '$title $caption $cat $tag $shopName $handle'.toLowerCase();
      return hay.contains(q);
    }).toList();

    list.sort((a, b) => ((b['likes'] as int?) ?? 0).compareTo((a['likes'] as int?) ?? 0));
    return list;
  }

  List<Map<String, dynamic>> _normalizeShops(List<dynamic> raw) {
    final List<Map<String, dynamic>> list = [];
    for (final row in raw) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      map['name'] = map['business_name'] ?? map['trading_name'] ?? map['name'] ?? 'Kedai Pilihan';
      map['category'] = map['business_industry'] ?? map['category'] ?? 'Service';
      if (widget.userLat != null &&
          widget.userLng != null &&
          map['latitude'] != null &&
          map['longitude'] != null) {
        final dLat = double.tryParse(map['latitude'].toString()) ?? 0.0;
        final dLng = double.tryParse(map['longitude'].toString()) ?? 0.0;
        map['distanceKm'] = _calculateDistance(widget.userLat!, widget.userLng!, dLat, dLng);
      } else {
        map['distanceKm'] ??= 0.8;
      }
      list.add(map);
    }
    return list;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  void _onQueryChanged(String value) {
    setState(() {});
    _debounceTimer?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _remoteShops = [];
        _remoteProducts = [];
        _remoteFeedPosts = [];
        _isSearchingRemote = false;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 280), () {
      _runRemoteSearch(q);
    });
  }

  void _applyKeywordSearch(String keyword, {double? maxBudget}) {
    _searchController.text = keyword;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: _searchController.text.length),
    );
    setState(() {
      if (maxBudget != null) {
        _maxBudget = maxBudget;
      }
      _selectedCategoryFilter = null;
    });
    _saveRecentSearch(keyword);
    _runRemoteSearch(keyword);
    _searchFocusNode.unfocus();
  }

  Future<void> _runRemoteSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    if (mounted) {
      setState(() => _isSearchingRemote = true);
    }

    try {
      final client = Supabase.instance.client;
      final safePattern = '%${clean.replaceAll('%', '').replaceAll(',', ' ')}%';

      final results = await Future.wait([
        client
            .from('businesses')
            .select()
            .eq('status', 'active')
            .or(
              'business_name.ilike.$safePattern,'
              'trading_name.ilike.$safePattern,'
              'business_industry.ilike.$safePattern,'
              'address_city.ilike.$safePattern',
            )
            .limit(20)
            .catchError((_) => <dynamic>[]),
        client
            .from('business_products')
            .select()
            .eq('is_active', true)
            .or(
              'name.ilike.$safePattern,'
              'category.ilike.$safePattern,'
              'description.ilike.$safePattern',
            )
            .order('is_featured', ascending: false)
            .limit(40)
            .catchError((_) => <dynamic>[]),
        client
            .from('feed_posts')
            .select(_feedPostSelect)
            .eq('status', 'published')
            .or(
              'title.ilike.$safePattern,'
              'caption.ilike.$safePattern,'
              'category.ilike.$safePattern,'
              'service_tag.ilike.$safePattern',
            )
            .order('created_at', ascending: false)
            .limit(24)
            .catchError((_) => <dynamic>[]),
      ]).timeout(const Duration(seconds: 6));

      if (!mounted || _query.toLowerCase() != clean.toLowerCase()) return;

      final shops = _normalizeShops(results[0] as List);
      final products = (results[1] as List)
          .whereType<Map>()
          .map((r) => ProductModel.fromJson(Map<String, dynamic>.from(r)))
          .where((p) => p.name.trim().isNotEmpty && !p.isOutOfStock)
          .toList();
      final feedPosts = _normalizeFeedPosts(results[2] as List);

      setState(() {
        _remoteShops = shops;
        _remoteProducts = products;
        _remoteFeedPosts = feedPosts;
        _isSearchingRemote = false;
      });
    } catch (e) {
      debugPrint('Remote search error: $e');
      if (mounted) {
        setState(() => _isSearchingRemote = false);
      }
    }
  }

  bool _matchesCategoryKey(String text, String catKey) {
    final c = text.toLowerCase();
    switch (catKey) {
      case 'barber':
        return c.contains('barber') || c.contains('rambut') || c.contains('gunting') || c.contains('hair');
      case 'cafe':
        return c.contains('cafe') || c.contains('kafe') || c.contains('kopi') || c.contains('coffee') || c.contains('food') || c.contains('makan') || c.contains('fnb');
      case 'carwash':
        return c.contains('carwash') || c.contains('cuci') || c.contains('kereta') || c.contains('detailing') || c.contains('auto');
      case 'workshop':
        return c.contains('workshop') || c.contains('bengkel') || c.contains('servis') || c.contains('motor');
      case 'salon':
        return c.contains('salon') || c.contains('salun') || c.contains('spa') || c.contains('beauty');
      case 'health':
        return c.contains('health') || c.contains('klinik') || c.contains('clinic') || c.contains('farmasi');
      default:
        return c.contains(catKey.toLowerCase());
    }
  }

  Map<String, Map<String, dynamic>> get _mergedShopById {
    final map = <String, Map<String, dynamic>>{};
    for (final s in _allShops) {
      final id = s['id']?.toString();
      if (id != null && id.isNotEmpty) map[id] = s;
    }
    for (final s in _remoteShops) {
      final id = s['id']?.toString();
      if (id != null && id.isNotEmpty) map[id] = s;
    }
    return map;
  }

  List<Map<String, dynamic>> get _filteredShops {
    if (_typeFilter == _SearchTypeFilter.products && _query.isEmpty) {
      // tetap benarkan kedai jika ada padanan carian nama kedai
    }
    final q = _query.toLowerCase();
    final combined = _mergedShopById.values.toList();

    final matches = combined.where((s) {
      final name = (s['business_name'] ?? s['trading_name'] ?? s['name'] ?? '').toString();
      final cat = (s['business_industry'] ?? s['category'] ?? '').toString();
      final city = (s['address_city'] ?? s['address_line'] ?? '').toString();

      if (_selectedCategoryFilter != null && !_matchesCategoryKey('$cat $name', _selectedCategoryFilter!)) {
        return false;
      }
      if (q.isEmpty) return true;
      return name.toLowerCase().contains(q) ||
          cat.toLowerCase().contains(q) ||
          city.toLowerCase().contains(q);
    }).toList();

    matches.sort((a, b) {
      final da = (a['distanceKm'] is num) ? (a['distanceKm'] as num).toDouble() : 999.0;
      final db = (b['distanceKm'] is num) ? (b['distanceKm'] as num).toDouble() : 999.0;
      return da.compareTo(db);
    });
    return matches;
  }

  List<ProductModel> get _filteredProducts {
    final q = _query.toLowerCase();
    final byId = <String, ProductModel>{};
    for (final p in _allProducts) {
      byId[p.id] = p;
    }
    for (final p in _remoteProducts) {
      byId[p.id] = p;
    }

    final shopMap = _mergedShopById;
    final list = byId.values.where((p) {
      if (_typeFilter == _SearchTypeFilter.services && !p.isService) return false;
      if (_typeFilter == _SearchTypeFilter.products && !p.isProduct) return false;
      if (_maxBudget != null && (p.price <= 0 || p.price > _maxBudget!)) return false;

      final shop = shopMap[p.shopId];
      final shopName = (shop?['name'] ?? shop?['business_name'] ?? '').toString();
      final shopCat = (shop?['category'] ?? shop?['business_industry'] ?? '').toString();

      if (_selectedCategoryFilter != null &&
          !_matchesCategoryKey('${p.category} ${p.name} $shopCat', _selectedCategoryFilter!)) {
        return false;
      }

      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          shopName.toLowerCase().contains(q) ||
          p.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();

    switch (_sortMode) {
      case _SearchSortMode.nearest:
        list.sort((a, b) {
          final da = (shopMap[a.shopId]?['distanceKm'] as num?)?.toDouble() ?? 999.0;
          final db = (shopMap[b.shopId]?['distanceKm'] as num?)?.toDouble() ?? 999.0;
          return da.compareTo(db);
        });
        break;
      case _SearchSortMode.priceLow:
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case _SearchSortMode.priceHigh:
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case _SearchSortMode.relevance:
        if (q.isNotEmpty) {
          list.sort((a, b) {
            final aExact = a.name.toLowerCase().startsWith(q) ? 0 : 1;
            final bExact = b.name.toLowerCase().startsWith(q) ? 0 : 1;
            if (aExact != bExact) return aExact.compareTo(bExact);
            return (b.isFeatured ? 1 : 0).compareTo(a.isFeatured ? 1 : 0);
          });
        }
        break;
    }

    return list;
  }

  void _resetAllFilters() {
    setState(() {
      _typeFilter = _SearchTypeFilter.all;
      _sortMode = _SearchSortMode.relevance;
      _maxBudget = null;
      _selectedCategoryFilter = null;
    });
  }

  void _openFilterSheet() {
    _SearchTypeFilter tempType = _typeFilter;
    _SearchSortMode tempSort = _sortMode;
    double? tempBudget = _maxBudget;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Widget buildOptionChip({
              required String label,
              required bool selected,
              required VoidCallback onTap,
            }) {
              return GestureDetector(
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                          )
                        : null,
                    color: selected
                        ? null
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.black.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF60A5FA)
                          : (isDark ? Colors.white12 : Colors.black12),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : (isDark ? Colors.white70 : const Color(0xFF334155)),
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              );
            }

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    14,
                    20,
                    MediaQuery.of(ctx).padding.bottom + 20,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF121726).withValues(alpha: 0.92)
                        : Colors.white.withValues(alpha: 0.94),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.6),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black26,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'search.filter_title'.tr(),
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempType = _SearchTypeFilter.all;
                                tempSort = _SearchSortMode.relevance;
                                tempBudget = null;
                              });
                            },
                            child: Text(
                              'search.reset_filters'.tr(),
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Text(
                        'search.filter_type_label'.tr(),
                        style: TextStyle(
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          buildOptionChip(
                            label: 'search.filter_type_all'.tr(),
                            selected: tempType == _SearchTypeFilter.all,
                            onTap: () => setModalState(() => tempType = _SearchTypeFilter.all),
                          ),
                          buildOptionChip(
                            label: 'search.filter_type_services'.tr(),
                            selected: tempType == _SearchTypeFilter.services,
                            onTap: () => setModalState(() => tempType = _SearchTypeFilter.services),
                          ),
                          buildOptionChip(
                            label: 'search.filter_type_products'.tr(),
                            selected: tempType == _SearchTypeFilter.products,
                            onTap: () => setModalState(() => tempType = _SearchTypeFilter.products),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'search.filter_sort_label'.tr(),
                        style: TextStyle(
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          buildOptionChip(
                            label: 'search.sort_relevance'.tr(),
                            selected: tempSort == _SearchSortMode.relevance,
                            onTap: () => setModalState(() => tempSort = _SearchSortMode.relevance),
                          ),
                          buildOptionChip(
                            label: 'search.sort_nearest'.tr(),
                            selected: tempSort == _SearchSortMode.nearest,
                            onTap: () => setModalState(() => tempSort = _SearchSortMode.nearest),
                          ),
                          buildOptionChip(
                            label: 'search.sort_price_low'.tr(),
                            selected: tempSort == _SearchSortMode.priceLow,
                            onTap: () => setModalState(() => tempSort = _SearchSortMode.priceLow),
                          ),
                          buildOptionChip(
                            label: 'search.sort_price_high'.tr(),
                            selected: tempSort == _SearchSortMode.priceHigh,
                            onTap: () => setModalState(() => tempSort = _SearchSortMode.priceHigh),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'search.filter_price_label'.tr(),
                        style: TextStyle(
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          buildOptionChip(
                            label: 'search.price_any'.tr(),
                            selected: tempBudget == null,
                            onTap: () => setModalState(() => tempBudget = null),
                          ),
                          buildOptionChip(
                            label: 'search.price_under_15'.tr(),
                            selected: tempBudget == 15.0,
                            onTap: () => setModalState(() => tempBudget = 15.0),
                          ),
                          buildOptionChip(
                            label: 'search.price_under_50'.tr(),
                            selected: tempBudget == 50.0,
                            onTap: () => setModalState(() => tempBudget = 50.0),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            setState(() {
                              _typeFilter = tempType;
                              _sortMode = tempSort;
                              _maxBudget = tempBudget;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(
                            'search.apply_filters'.tr(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isLandscape = media.size.width > media.size.height;
    final bool isDesktop = media.size.width >= 768 || (isLandscape && media.size.width >= 500);
    final Color bgStart = isDark ? const Color(0xFF0A0A14) : const Color(0xFFF8F9FA);
    final Color bgEnd = isDark ? const Color(0xFF10101C) : const Color(0xFFF1F5F9);

    final matchedShops = _filteredShops;
    final matchedProducts = _filteredProducts;
    final matchedVideos = _filteredFeedPosts;
    final shopById = _mergedShopById;

    return Scaffold(
      backgroundColor: bgStart,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgStart, bgEnd],
          ),
        ),
        child: Stack(
          children: [
            // Subtle ambient glow
            Positioned(
              top: -70,
              right: -60,
              child: IgnorePointer(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF2196F3).withValues(alpha: isDark ? 0.14 : 0.09),
                        const Color(0xFF2196F3).withValues(alpha: 0.0),
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
                  child: Column(
                    children: [
                      // Top Liquid Glass Search Bar Row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                        child: Row(
                          children: [
                            _buildGlassCircleBtn(
                              isDark: isDark,
                              icon: HugeIcons.strokeRoundedArrowLeft01,
                              onTap: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildLiveSearchInput(isDark),
                            ),
                          ],
                        ),
                      ),

                      // Body: either Pre-search discovery OR Live filtered results
                      Expanded(
                        child: _isSearchMode
                            ? _buildSearchResultsScroll(
                                isDark: isDark,
                                isDesktop: isDesktop,
                                matchedShops: matchedShops,
                                matchedProducts: matchedProducts,
                                matchedVideos: matchedVideos,
                                shopById: shopById,
                              )
                            : _buildPreSearchDiscovery(
                                isDark: isDark,
                                isDesktop: isDesktop,
                                shopById: shopById,
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

  Widget _buildGlassCircleBtn({
    required bool isDark,
    required dynamic icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.85),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.65),
          ),
        ),
        child: Center(
          child: HugeIcon(
            icon: icon,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveSearchInput(bool isDark) {
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.88),
        border: Border.all(
          color: _searchFocusNode.hasFocus
              ? const Color(0xFF38BDF8).withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: isDark ? 0.14 : 0.65),
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
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onSubmitted: (val) {
                _saveRecentSearch(val);
                _runRemoteSearch(val);
              },
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: widget.isVideoFocused
                    ? 'search.hint_videos'.tr()
                    : 'search.hint'.tr(),
                hintStyle: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_query.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                _onQueryChanged('');
                _searchFocusNode.requestFocus();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  color: isDark ? Colors.white54 : Colors.black45,
                  size: 17,
                ),
              ),
            ),
          GestureDetector(
            onTap: _openFilterSheet,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _hasActiveFilters
                        ? const Color(0xFF2563EB).withValues(alpha: 0.22)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05)),
                    border: Border.all(
                      color: _hasActiveFilters
                          ? const Color(0xFF38BDF8)
                          : Colors.white.withValues(alpha: isDark ? 0.10 : 0.4),
                    ),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedSlidersHorizontal,
                      color: _hasActiveFilters
                          ? const Color(0xFF38BDF8)
                          : (isDark ? Colors.white70 : Colors.black54),
                      size: 15,
                    ),
                  ),
                ),
                if (_hasActiveFilters)
                  Positioned(
                    top: -1,
                    right: -1,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFF38BDF8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreSearchDiscovery({
    required bool isDark,
    required bool isDesktop,
    required Map<String, Map<String, dynamic>> shopById,
  }) {
    final List<Map<String, dynamic>> popularKeywords = [
      {'label': 'search.kw_barber'.tr(), 'query': 'Barber', 'icon': HugeIcons.strokeRoundedScissor},
      {'label': 'search.kw_coffee'.tr(), 'query': 'Kopi', 'icon': HugeIcons.strokeRoundedCoffee02},
      {'label': 'search.kw_carwash'.tr(), 'query': 'Car Wash', 'icon': HugeIcons.strokeRoundedCar01},
      {'label': 'search.kw_workshop'.tr(), 'query': 'Workshop', 'icon': HugeIcons.strokeRoundedWrench01},
      {'label': 'search.kw_salon'.tr(), 'query': 'Salon', 'icon': HugeIcons.strokeRoundedSparkles},
      {'label': 'search.kw_budget'.tr(), 'query': '', 'budget': 15.0, 'icon': HugeIcons.strokeRoundedTicket01},
    ];

    final List<Map<String, dynamic>> categories = [
      {'title': 'customer.cat_haircut'.tr(), 'key': 'barber', 'icon': HugeIcons.strokeRoundedScissor, 'color': const Color(0xFF3B82F6)},
      {'title': 'customer.cat_fnb'.tr(), 'key': 'cafe', 'icon': HugeIcons.strokeRoundedCoffee02, 'color': const Color(0xFFF59E0B)},
      {'title': 'customer.cat_carwash'.tr(), 'key': 'carwash', 'icon': HugeIcons.strokeRoundedCar01, 'color': const Color(0xFF06B6D4)},
      {'title': 'customer.cat_workshop'.tr(), 'key': 'workshop', 'icon': HugeIcons.strokeRoundedWrench01, 'color': const Color(0xFF0EA5E9)},
      {'title': 'customer.cat_salon'.tr(), 'key': 'salon', 'icon': HugeIcons.strokeRoundedSparkles, 'color': const Color(0xFF8B5CF6)},
      {'title': 'customer.cat_clinic'.tr(), 'key': 'health', 'icon': HugeIcons.strokeRoundedFirstAidKit, 'color': const Color(0xFF10B981)},
    ];

    final suggestedProducts = _allProducts.take(8).toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_recentSearches.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'search.recent_title'.tr(),
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      GestureDetector(
                        onTap: _clearRecentSearches,
                        child: Text(
                          'search.clear_all'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _recentSearches.map((term) {
                      return GestureDetector(
                        onTap: () => _applyKeywordSearch(term),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.white.withValues(alpha: 0.85),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedClock01,
                                color: isDark ? Colors.white54 : Colors.black45,
                                size: 13,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                term,
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // Popular / Trending keywords
                Text(
                  'search.trending_title'.tr(),
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: popularKeywords.map((item) {
                    return GestureDetector(
                      onTap: () {
                        final b = item['budget'] as double?;
                        final q = (item['query'] ?? '').toString();
                        if (q.isEmpty && b != null) {
                          setState(() => _maxBudget = b);
                        } else {
                          _applyKeywordSearch(q, maxBudget: b);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: isDark
                              ? const Color(0xFF141B2D).withValues(alpha: 0.85)
                              : Colors.white.withValues(alpha: 0.90),
                          border: Border.all(
                            color: const Color(0xFF38BDF8).withValues(alpha: isDark ? 0.25 : 0.30),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HugeIcon(
                              icon: item['icon'],
                              color: const Color(0xFF38BDF8),
                              size: 13,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              item['label'].toString(),
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Browse by category strip
                Text(
                  'search.categories_title'.tr(),
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, idx) {
                      final cat = categories[idx];
                      final color = cat['color'] as Color;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategoryFilter = cat['key'].toString();
                          });
                        },
                        child: Container(
                          width: 82,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.white.withValues(alpha: 0.86),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.16),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: HugeIcon(
                                    icon: cat['icon'],
                                    color: color,
                                    size: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                cat['title'].toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                if (widget.isVideoFocused && _allFeedPosts.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(
                    'search.suggested_videos_title'.tr(),
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (suggestedProducts.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(
                    'search.suggested_title'.tr(),
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
        if (widget.isVideoFocused && _allFeedPosts.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 3 : 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.70,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, idx) => _buildVideoResultCard(_allFeedPosts[idx], isDark),
                childCount: min(_allFeedPosts.length, 8),
              ),
            ),
          )
        else if (suggestedProducts.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: isDesktop ? 3 : 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childCount: suggestedProducts.length,
              itemBuilder: (context, idx) {
                final p = suggestedProducts[idx];
                final shop = shopById[p.shopId] ??
                    {
                      'id': p.shopId,
                      'name': 'Ngam Partner',
                      'category': p.category.isNotEmpty ? p.category : 'Service',
                    };
                return _buildProductResultCard(p, shop, isDark);
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildSearchResultsScroll({
    required bool isDark,
    required bool isDesktop,
    required List<Map<String, dynamic>> matchedShops,
    required List<ProductModel> matchedProducts,
    required List<Map<String, dynamic>> matchedVideos,
    required Map<String, Map<String, dynamic>> shopById,
  }) {
    final bool showStores = _selectedResultTab == 0 || _selectedResultTab == 1;
    final bool showItems = _selectedResultTab == 0 || _selectedResultTab == 2;
    final bool showVideos = _selectedResultTab == 0 || _selectedResultTab == 3;
    final bool nothingFound = (!showStores || matchedShops.isEmpty) &&
        (!showItems || matchedProducts.isEmpty) &&
        (!showVideos || matchedVideos.isEmpty) &&
        !_isSearchingRemote;

    final tabs = [
      'search.tab_all'.tr(),
      'search.tab_stores'.tr(),
      'search.tab_items'.tr(),
      'search.tab_videos'.tr(),
    ];

    return Column(
      children: [
        // Result tabs & active filter pills
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            children: [
              for (int i = 0; i < tabs.length; i++) ...[
                GestureDetector(
                  onTap: () => setState(() => _selectedResultTab = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: _selectedResultTab == i
                          ? const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                            )
                          : null,
                      color: _selectedResultTab == i
                          ? null
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.white.withValues(alpha: 0.85)),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _selectedResultTab == i
                            ? const Color(0xFF60A5FA)
                            : (isDark ? Colors.white12 : Colors.black12),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        tabs[i],
                        style: TextStyle(
                          color: _selectedResultTab == i
                              ? Colors.white
                              : (isDark ? Colors.white70 : const Color(0xFF334155)),
                          fontSize: 12,
                          fontWeight: _selectedResultTab == i ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (_hasActiveFilters)
                GestureDetector(
                  onTap: _resetAllFilters,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          color: Color(0xFFEF4444),
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'search.reset_filters'.tr(),
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_isSearchingRemote)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: Color(0xFF38BDF8),
            ),
          )
        else
          const SizedBox(height: 8),

        Expanded(
          child: nothingFound
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.14),
                          ),
                          child: const Center(
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedSearch01,
                              color: Color(0xFF38BDF8),
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'search.empty_title'.tr(),
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'search.empty_desc'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                        if (_hasActiveFilters) ...[
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _resetAllFilters,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text('search.reset_filters'.tr()),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    if (showStores && matchedShops.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                          child: Text(
                            'search.stores_section'.tr(
                              args: [matchedShops.length.toString()],
                            ),
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      if (_selectedResultTab == 0)
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 92,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              physics: const BouncingScrollPhysics(),
                              itemCount: min(matchedShops.length, 10),
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (_, idx) => _buildStoreTile(
                                matchedShops[idx],
                                isDark,
                                compactWidth: 235,
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, idx) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildStoreTile(matchedShops[idx], isDark),
                              ),
                              childCount: matchedShops.length,
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],

                    if (showVideos && matchedVideos.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: Text(
                            'search.videos_section'.tr(
                              args: [matchedVideos.length.toString()],
                            ),
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      if (_selectedResultTab == 0)
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 224,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              physics: const BouncingScrollPhysics(),
                              itemCount: min(matchedVideos.length, 10),
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (_, idx) => SizedBox(
                                width: 152,
                                child: _buildVideoResultCard(matchedVideos[idx], isDark),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isDesktop ? 3 : 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.70,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (_, idx) => _buildVideoResultCard(matchedVideos[idx], isDark),
                              childCount: matchedVideos.length,
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],

                    if (showItems && matchedProducts.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: Text(
                            'search.items_section'.tr(
                              args: [matchedProducts.length.toString()],
                            ),
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverMasonryGrid.count(
                          crossAxisCount: isDesktop ? 3 : 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childCount: matchedProducts.length,
                          itemBuilder: (_, idx) {
                            final product = matchedProducts[idx];
                            final shop = shopById[product.shopId] ??
                                {
                                  'id': product.shopId,
                                  'name': 'Ngam Partner',
                                  'category': product.category.isNotEmpty
                                      ? product.category
                                      : 'Service',
                                };
                            return _buildProductResultCard(product, shop, isDark);
                          },
                        ),
                      ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildVideoResultCard(Map<String, dynamic> post, bool isDark) {
    final String postId = (post['id'] ?? '').toString();
    final String title = (post['title'] ?? '').toString();
    final String caption = (post['caption'] ?? '').toString();
    final String displayTitle = title.isNotEmpty
        ? title
        : (caption.isNotEmpty ? caption : (post['shopName'] ?? 'Ngam').toString());
    final String shopName = (post['shopName'] ?? 'Ngam').toString();
    final String thumb = (post['thumbnail'] ?? '').toString().trim();
    final bool isVideo = post['isVideo'] == true;
    final int likes = (post['likes'] as int?) ?? 0;

    return GestureDetector(
      onTap: () {
        if (_query.isNotEmpty) {
          _saveRecentSearch(_query);
        }
        if (postId.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostRouteLoader(postId: postId)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark
              ? const Color(0xFF141926).withValues(alpha: 0.90)
              : Colors.white.withValues(alpha: 0.92),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.75),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumb.isNotEmpty)
                (kIsWeb
                    ? Image.network(
                        thumb,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        frameBuilder: (_, child, frame, sync) {
                          if (sync || frame != null) return child;
                          return _buildImageShimmer(isDark, 220);
                        },
                        errorBuilder: (_, __, ___) => _buildVideoFallbackPoster(isVideo),
                      )
                    : CachedNetworkImage(
                        imageUrl: thumb,
                        fit: BoxFit.cover,
                        memCacheWidth: 420,
                        placeholder: (_, __) => _buildImageShimmer(isDark, 220),
                        errorWidget: (_, __, ___) => _buildVideoFallbackPoster(isVideo),
                      ))
              else
                _buildVideoFallbackPoster(isVideo),

              // Gradient overlay for legibility
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.20),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.82),
                    ],
                    stops: const [0.0, 0.42, 1.0],
                  ),
                ),
              ),

              // Top badge (VIDEO / POST)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HugeIcon(
                        icon: isVideo
                            ? HugeIcons.strokeRoundedPlay
                            : HugeIcons.strokeRoundedImage01,
                        color: const Color(0xFF38BDF8),
                        size: 11,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isVideo ? 'search.video_badge'.tr() : 'search.post_badge'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom caption, creator & likes
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            shopName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedFavourite,
                          color: Color(0xFFF43F5E),
                          size: 11,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          likes.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
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

  Widget _buildVideoFallbackPoster(bool isVideo) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
        ),
      ),
      child: Center(
        child: HugeIcon(
          icon: isVideo ? HugeIcons.strokeRoundedPlayCircle : HugeIcons.strokeRoundedImage01,
          color: Colors.white.withValues(alpha: 0.45),
          size: 38,
        ),
      ),
    );
  }

  Widget _buildStoreTile(
    Map<String, dynamic> shop,
    bool isDark, {
    double? compactWidth,
  }) {
    final String name = (shop['business_name'] ?? shop['name'] ?? 'Ngam').toString();
    final String cat = (shop['business_industry'] ?? shop['category'] ?? 'Service').toString();
    final String imgUrl = (shop['business_logo_url'] ?? shop['business_cover_url'] ?? '').toString().trim();
    final dynamic distRaw = shop['distanceKm'];
    String distLabel = '';
    if (distRaw is num) {
      final d = distRaw.toDouble();
      distLabel = d < 1.0 ? '${(d * 1000).round()} m' : '${d.toStringAsFixed(1)} km';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BusinessStoreView(shop: shop)),
        );
      },
      child: Container(
        width: compactWidth,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark
              ? const Color(0xFF141926).withValues(alpha: 0.88)
              : Colors.white.withValues(alpha: 0.90),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.7),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 60,
                height: 60,
                child: imgUrl.isEmpty
                    ? Container(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.18),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'N',
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      )
                    : (kIsWeb
                        ? Image.network(
                            imgUrl,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            frameBuilder: (_, child, frame, sync) {
                              if (sync || frame != null) return child;
                              return _buildImageShimmer(isDark, 60);
                            },
                            errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded),
                          )
                        : CachedNetworkImage(
                            imageUrl: imgUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 200,
                            placeholder: (_, __) => _buildImageShimmer(isDark, 60),
                            errorWidget: (_, __, ___) => const Icon(Icons.storefront_rounded),
                          )),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    cat,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (distLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedLocation01,
                          color: Color(0xFF94A3B8),
                          size: 11,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          distLabel,
                          style: TextStyle(
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: Color(0xFF64748B),
              size: 16,
            ),
          ],
        ),
      ),
    );
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
      child: Container(height: height, width: double.infinity, color: baseColor),
    );
  }

  Widget _buildProductResultCard(
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
              icon: isService ? HugeIcons.strokeRoundedSparkles : HugeIcons.strokeRoundedStore01,
              color: typeColor.withValues(alpha: 0.7),
              size: 28,
            ),
          ),
        );

    return KeyedSubtree(
      key: ValueKey('search_prod_${product.id}'),
      child: GestureDetector(
        onTap: () {
          if (_query.isNotEmpty) {
            _saveRecentSearch(_query);
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product, shop: shop),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: isDark
                ? const Color(0xFF141926).withValues(alpha: 0.86)
                : Colors.white.withValues(alpha: 0.90),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.75),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.05),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    final width = constraints.maxWidth;
                    final double factor = switch (product.id.hashCode.abs() % 3) {
                      0 => 1.0,
                      1 => 1.15,
                      _ => 0.88,
                    };
                    final double imgHeight = (width * factor).clamp(width * 0.78, width * 1.28);
                    return SizedBox(
                      width: double.infinity,
                      height: imgHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (product.imageUrl.isEmpty)
                            imageFallback(imgHeight)
                          else if (kIsWeb)
                            Image.network(
                              product.imageUrl,
                              width: double.infinity,
                              height: imgHeight,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              frameBuilder: (_, child, frame, sync) {
                                if (sync || frame != null) return child;
                                return _buildImageShimmer(isDark, imgHeight);
                              },
                              errorBuilder: (_, __, ___) => imageFallback(imgHeight),
                            )
                          else
                            CachedNetworkImage(
                              imageUrl: product.imageUrl,
                              width: double.infinity,
                              height: imgHeight,
                              fit: BoxFit.cover,
                              memCacheWidth: 500,
                              placeholder: (_, __) => _buildImageShimmer(isDark, imgHeight),
                              errorWidget: (_, __, ___) => imageFallback(imgHeight),
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
              const SizedBox(height: 9),
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
              const SizedBox(height: 5),
              Text(
                'RM${product.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF3B82F6),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                ),
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
    );
  }
}
