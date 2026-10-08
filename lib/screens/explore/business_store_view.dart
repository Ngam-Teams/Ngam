import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:ngam/widgets/glass_box.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product_model.dart';
import '../../widgets/glass_toast.dart';
import 'business_products_view.dart';
import 'bookings_view.dart';
import 'store_cart_view.dart';
import 'store_info_view.dart';
import 'store_reviews_view.dart';

// ============================================================
// BusinessStoreView — Main store landing page
// Shows business logo, welcome, status, categories, products
// Glassmorphism matching Ngam default style
// ============================================================

enum _StoreStatus { open, closingSoon, closed, holiday }

class BusinessStoreView extends StatefulWidget {
  final Map<String, dynamic> shop;

  const BusinessStoreView({super.key, required this.shop});

  @override
  State<BusinessStoreView> createState() => _BusinessStoreViewState();
}

class _BusinessStoreViewState extends State<BusinessStoreView>
    with TickerProviderStateMixin {
  StreamSubscription? _productSub;

  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];
  bool _isLoading = true;
  String _selectedCategory = 'All items';

  int? _syncedOpenHour;
  int? _syncedOpenMinute;
  int? _syncedCloseHour;
  int? _syncedCloseMinute;
  String? _syncedCoverUrl;
  Map<String, dynamic>? _syncedOperatingHours;
  bool? _syncedIsOpen;
  List<Map<String, dynamic>> _syncedWeeklySchedule = [];
  List<Map<String, dynamic>> _syncedSpecialHolidays = [];
  String? _activeHolidayName;

  int get _openHour => _syncedOpenHour ?? widget.shop['openHour'] ?? 9;
  int get _openMinute => _syncedOpenMinute ?? widget.shop['openMinute'] ?? 0;
  int get _closeHour => _syncedCloseHour ?? widget.shop['closeHour'] ?? 22;
  int get _closeMinute => _syncedCloseMinute ?? widget.shop['closeMinute'] ?? 0;
  String get _coverUrl {
    if (_syncedCoverUrl != null && _syncedCoverUrl!.isNotEmpty) {
      return _syncedCoverUrl!;
    }
    final c = widget.shop['cover'] ?? widget.shop['business_cover_url'];
    if (c != null && c.toString().isNotEmpty) {
      return c.toString();
    }
    return widget.shop['image']?.toString() ?? '';
  }

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  bool _isLiked = false;
  final List<CartItem> _cart = [];

  int get _cartItemCount => _cart.fold(0, (sum, item) => sum + item.quantity);

  void _addToCart(ProductModel product) {
    setState(() {
      final index = _cart.indexWhere((c) => c.product.id == product.id);
      if (index >= 0) {
        _cart[index].quantity += 1;
      } else {
        _cart.add(CartItem(product: product, quantity: 1));
      }
    });
    showGlassToast(context, 'Added "${product.name}" to cart!');
  }

  // ── Status Helpers ───────────────────────────────────────────

  _StoreStatus get _status {
    final now = DateTime.now();

    // 1. Check special holidays
    final todayDateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    for (final h in _syncedSpecialHolidays) {
      final hDate = h['date']?.toString();
      final bool isClosed = h['isClosed'] == true || h['is_closed'] == true;
      if (hDate == todayDateStr && isClosed) {
        _activeHolidayName = h['name']?.toString() ?? 'Cuti Perayaan';
        return _StoreStatus.holiday;
      }
    }

    // 2. Check if business is manually marked closed or in rush mode
    if (_syncedIsOpen == false) {
      return _StoreStatus.closed;
    }
    if (_syncedOperatingHours?['is_rush_mode'] == true) {
      return _StoreStatus.closed;
    }

    // 3. Check weekly schedule for current day
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final todayName = dayNames[now.weekday - 1];

    if (_syncedWeeklySchedule.isNotEmpty) {
      final todayItem = _syncedWeeklySchedule.firstWhere(
        (s) => s['day']?.toString().toLowerCase() == todayName.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );

      if (todayItem.isNotEmpty) {
        final bool isOpenToday =
            todayItem['isOpen'] != false && todayItem['is_open'] != false;
        if (!isOpenToday) {
          return _StoreStatus.closed;
        }

        final openStr = todayItem['open']?.toString();
        final closeStr = todayItem['close']?.toString();
        int? openH, openM, closeH, closeM;
        if (openStr != null && openStr.contains(':')) {
          final p = openStr.split(':');
          openH = int.tryParse(p[0]);
          openM = int.tryParse(p[1]);
        }
        if (closeStr != null && closeStr.contains(':')) {
          final p = closeStr.split(':');
          closeH = int.tryParse(p[0]);
          closeM = int.tryParse(p[1]);
        }

        if (openH != null && openM != null && closeH != null && closeM != null) {
          DateTime open = DateTime(now.year, now.month, now.day, openH, openM);
          DateTime close = DateTime(now.year, now.month, now.day, closeH, closeM);

          if (close.isBefore(open)) {
            if (now.isAfter(open)) {
              close = close.add(const Duration(days: 1));
            } else {
              open = open.subtract(const Duration(days: 1));
            }
          }

          if (now.isBefore(open) || now.isAfter(close)) return _StoreStatus.closed;
          if (close.difference(now).inMinutes <= 30) return _StoreStatus.closingSoon;
          return _StoreStatus.open;
        }
      }
    }

    // 4. Fallback to default openHour / closeHour
    final int openH = _openHour;
    final int openM = _openMinute;
    final int closeH = _closeHour;
    final int closeM = _closeMinute;

    DateTime open = DateTime(now.year, now.month, now.day, openH, openM);
    DateTime close = DateTime(now.year, now.month, now.day, closeH, closeM);

    if (close.isBefore(open)) {
      if (now.isAfter(open)) {
        close = close.add(const Duration(days: 1));
      } else {
        open = open.subtract(const Duration(days: 1));
      }
    }

    if (now.isBefore(open) || now.isAfter(close)) return _StoreStatus.closed;
    if (close.difference(now).inMinutes <= 30) return _StoreStatus.closingSoon;
    return _StoreStatus.open;
  }

  String _formatTime(int h, int m) {
    final period = h >= 12 ? 'PM' : 'AM';
    int hour = h % 12;
    if (hour == 0) hour = 12;
    return '${hour.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  String get _statusText {
    final st = _status;
    final closeStr = _formatTime(_closeHour, _closeMinute);
    final openStr = _formatTime(_openHour, _openMinute);

    if (_syncedOperatingHours?['is_rush_mode'] == true) {
      return 'Tutup Sementara (Rush Hour)';
    }
    if (_syncedIsOpen == false) {
      return 'Tutup Sementara';
    }

    switch (st) {
      case _StoreStatus.open:
        return 'Open Now · Closes $closeStr';
      case _StoreStatus.closingSoon:
        return 'Closing Soon · $closeStr';
      case _StoreStatus.closed:
        return 'Closed · Opens $openStr';
      case _StoreStatus.holiday:
        return 'Holiday · ${_activeHolidayName ?? "Store Holiday"}';
    }
  }

  Color get _statusColor {
    switch (_status) {
      case _StoreStatus.open:
        return Colors.blue;
      case _StoreStatus.closingSoon:
        return Colors.orange;
      case _StoreStatus.closed:
        return Colors.red;
      case _StoreStatus.holiday:
        return Colors.purpleAccent;
    }
  }

  dynamic get _statusIcon {
    switch (_status) {
      case _StoreStatus.open:
        return HugeIcons.strokeRoundedStore01;
      case _StoreStatus.closingSoon:
        return HugeIcons.strokeRoundedTime02;
      case _StoreStatus.closed:
        return HugeIcons.strokeRoundedUnavailable;
      case _StoreStatus.holiday:
        return HugeIcons.strokeRoundedCalendar03;
    }
  }

  List<String> get _categories {
    final cats = _allProducts
        .map((e) => e.category)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    cats.sort();
    return ['All items', ...cats];
  }

  // ── Lifecycle ────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _initStream();
  }

  @override
  void dispose() {
    _productSub?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _initStream() {
    final shopId = widget.shop['id']?.toString();
    if (shopId == null || shopId.isEmpty) {
      if (mounted) {
        setState(() {
          _allProducts = [];
          _filterProducts();
          _isLoading = false;
        });
        _fadeCtrl.forward();
      }
      return;
    }

    // 🟢 SYNC COVER & OPERATING HOURS FROM SUPABASE
    _syncBusinessDetails(shopId);

    _productSub?.cancel();
    _productSub = Supabase.instance.client
        .from('business_products')
        .stream(primaryKey: ['id'])
        .eq('shop_id', shopId)
        .order('created_at', ascending: false)
        .listen(
      (data) {
        final activeProducts = data
            .where((item) =>
                item['is_active'] == true || item['is_active'] == null)
            .map((json) => ProductModel.fromJson(json))
            .toList();

        if (mounted) {
          setState(() {
            _allProducts = activeProducts;
            _filterProducts();
            _isLoading = false;
          });
          _fadeCtrl.forward();
        }
      },
      onError: (err) {
        debugPrint('Error streaming products for shop $shopId: $err');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _fadeCtrl.forward();
        }
      },
    );
  }

  Future<void> _syncBusinessDetails(String shopId) async {
    try {
      final biz = await Supabase.instance.client
          .from('businesses')
          .select('business_cover_url, business_logo_url, is_open')
          .eq('id', shopId)
          .maybeSingle();

      if (biz != null && mounted) {
        final cover = biz['business_cover_url'] as String?;
        if (cover != null && cover.isNotEmpty) {
          _syncedCoverUrl = cover;
        }
        if (biz['is_open'] != null) {
          _syncedIsOpen = biz['is_open'] == true;
        }
      }

      final settings = await Supabase.instance.client
          .from('business_settings')
          .select('operating_hours')
          .eq('business_id', shopId)
          .maybeSingle();

      if (settings != null && settings['operating_hours'] is Map && mounted) {
        final op = settings['operating_hours'] as Map;
        _syncedOperatingHours = Map<String, dynamic>.from(op);
        final openStr = op['open_time'] as String?;
        final closeStr = op['close_time'] as String?;

        if (openStr != null && openStr.contains(':')) {
          final p = openStr.split(':');
          _syncedOpenHour = int.tryParse(p[0]);
          _syncedOpenMinute = int.tryParse(p[1]);
        }
        if (closeStr != null && closeStr.contains(':')) {
          final p = closeStr.split(':');
          _syncedCloseHour = int.tryParse(p[0]);
          _syncedCloseMinute = int.tryParse(p[1]);
        }

        final weekly = op['weekly_schedule'] as List?;
        if (weekly != null) {
          _syncedWeeklySchedule =
              weekly.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }

        final holidays = op['special_holidays'] as List?;
        if (holidays != null) {
          _syncedSpecialHolidays =
              holidays.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error syncing business details: $e');
    }
  }

  void _filterProducts() {
    _filteredProducts = _allProducts.where((p) {
      return _selectedCategory == 'All items' ||
          p.category == _selectedCategory;
    }).toList();
  }

  // ── Glass Helpers ────────────────────────────────────────────

  LiquidGlassSettings _glassSettings(bool isDark, {double blur = 2.0}) {
    return isDark
        ? LiquidGlassSettings(
            thickness: 0.1,
            blur: blur,
            refractiveIndex: 1.0,
            glassColor: Colors.transparent,
            lightAngle: 45.0,
            lightIntensity: 0.1,
            ambientStrength: 1.0,
            saturation: 1.0,
            chromaticAberration: 0.0,
          )
        : LiquidGlassSettings(
            thickness: 0.1,
            blur: blur,
            refractiveIndex: 1.0,
            glassColor: Colors.transparent,
            lightAngle: 45.0,
            lightIntensity: 0.2,
            ambientStrength: 1.0,
            saturation: 1.0,
            chromaticAberration: 0.0,
          );
  }

  Widget _glassBox({
    required bool isDark,
    required Widget child,
    double radius = 16.0,
    EdgeInsetsGeometry? padding,
    Color? overrideColor,
    Color? overrideBorder,
    double blur = 4.0,
  }) {
    return GlassContainer(
      useOwnLayer: true,
      quality: GlassQuality.standard,
      shape: LiquidRoundedSuperellipse(borderRadius: radius),
      settings: _glassSettings(isDark, blur: blur),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: overrideColor ??
              (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white
                  .withValues(alpha: 0.4)),
          border: Border.all(
            color: overrideBorder ??
                Colors.white.withValues(alpha: isDark ? 0.15 : 0.4),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
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



  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textPrimary =
        isDark ? Colors.white : const Color(0xFF1C1C1E);
    final Color textSecondary = isDark
        ? Colors.white60
        : const Color(0xFF3A3A3C).withValues(alpha: 0.7);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SizedBox.expand(
        child: SafeArea(
          child: Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── 1. HEADER WITH BUSINESS COVER BANNER ───────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 75, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🟢 Hero Cover Card with Logo, Name & Status Badge
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Stack(
                                children: [
                                  // Background Cover Image
                                  Positioned.fill(
                                    child: _coverUrl.isNotEmpty
                                        ? Image.network(
                                            _coverUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => _buildCoverFallback(isDark),
                                          )
                                        : _buildCoverFallback(isDark),
                                  ),

                                  // Gradient & Frosted Overlay for optimal contrast
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.black.withValues(alpha: 0.25),
                                            Colors.black.withValues(alpha: 0.78),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.35),
                                          width: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Content: Logo + Info
                                  Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Business Logo Avatar with crisp glass/white border
                                        Container(
                                          width: 70,
                                          height: 70,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.4),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: ClipOval(
                                            child: widget.shop['image'] != null &&
                                                    widget.shop['image'].toString().isNotEmpty
                                                ? Image.network(
                                                    widget.shop['image'],
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => _logoFallback(isDark),
                                                  )
                                                : _logoFallback(isDark),
                                          ),
                                        ),
                                        const SizedBox(width: 14),

                                        // Business Name, Welcome & Status
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Welcome to',
                                                style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.85),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  shadows: const [
                                                    Shadow(color: Colors.black54, blurRadius: 4),
                                                  ],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                widget.shop['name'] ?? 'Business',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: -0.3,
                                                  shadows: [
                                                    Shadow(color: Colors.black54, blurRadius: 6),
                                                  ],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 8),
                                              GestureDetector(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => StoreInfoView(shop: {
                                                        ...widget.shop,
                                                        'openHour': _openHour,
                                                        'openMinute': _openMinute,
                                                        'closeHour': _closeHour,
                                                        'closeMinute': _closeMinute,
                                                        'cover': _coverUrl,
                                                        'operating_hours': _syncedOperatingHours ?? widget.shop['operating_hours'],
                                                      }),
                                                    ),
                                                  );
                                                },
                                                child: _buildStatusBadge(isDark),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── 3 QUICK REDIRECTION CARDS ──
                          Row(
                            children: [
                              // 1. Book Service
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BookingsView(
                                          shopId: widget.shop['id']?.toString() ?? '1',
                                          shopName: widget.shop['name'] ?? 'Store',
                                          category: widget.shop['category']?.toString().toUpperCase() ?? 'SERVICE',
                                          shopImage: widget.shop['image'] ?? 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=400',
                                        ),
                                      ),
                                    );
                                  },
                                  child: _glassBox(
                                    isDark: isDark,
                                    radius: 16,
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.calendar_month_rounded, color: Colors.blue, size: 15),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'Book Slot',
                                              style: TextStyle(
                                                color: textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 2. Store Info
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => StoreInfoView(shop: {
                                          ...widget.shop,
                                          'openHour': _openHour,
                                          'openMinute': _openMinute,
                                          'closeHour': _closeHour,
                                          'closeMinute': _closeMinute,
                                          'cover': _coverUrl,
                                          'operating_hours': _syncedOperatingHours ?? widget.shop['operating_hours'],
                                        }),
                                      ),
                                    );
                                  },
                                  child: _glassBox(
                                    isDark: isDark,
                                    radius: 16,
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 15),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'Info & Hours',
                                              style: TextStyle(
                                                color: textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 3. Reviews
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => StoreReviewsView(shop: widget.shop),
                                      ),
                                    );
                                  },
                                  child: _glassBox(
                                    isDark: isDark,
                                    radius: 16,
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'Reviews',
                                              style: TextStyle(
                                                color: textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // ── 2. SEARCH BAR → navigates to BusinessProductsView
                          Row(
                            children: [
                              Expanded(
                                child: GlassContainer(
                              useOwnLayer: true,
                              quality: GlassQuality.standard,
                              shape: LiquidRoundedSuperellipse(borderRadius: 24),
                              settings: _glassSettings(isDark),
                              child: Container(
                                height: 50,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.white.withValues(alpha: 0.28),
                                ),
                                child: Row(
                                  children: [
                                    HugeIcon(
                                      icon: HugeIcons.strokeRoundedSearch01,
                                      color: isDark
                                          ? Colors.white54
                                          : const Color(0xFF3A3A3C)
                                              .withValues(alpha: 0.5),
                                      size: 20,
                                      strokeWidth: 2.0,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        textInputAction: TextInputAction.search,
                                        onSubmitted: (val) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => BusinessProductsView(
                                                shopId: widget.shop['id']?.toString() ?? 'unknown',
                                                shopName: widget.shop['name'] ?? 'Store',
                                                initialSearchQuery: val,
                                              ),
                                            ),
                                          );
                                        },
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        cursorColor: textPrimary,
                                        decoration: InputDecoration(
                                          hintText: 'Search products...',
                                          hintStyle: TextStyle(
                                            color: isDark
                                                ? Colors.white38
                                                : const Color(0xFF3A3A3C)
                                                    .withValues(alpha: 0.45),
                                            fontSize: 15,
                                            fontWeight: FontWeight.w400,
                                          ),
                                          border: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          errorBorder: InputBorder.none,
                                          disabledBorder: InputBorder.none,
                                          filled: false,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _liquidGlassBox(
                            isDark: isDark,
                            radius: 100,
                            child: SizedBox(
                              width: 50,
                              height: 50,
                              child: Center(
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedMoreHorizontal,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                  size: 22,
                                  strokeWidth: 2.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── 3. CATEGORY CHIPS ─────────────────────────────
                      SizedBox(
                        height: 38,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final cat = _categories[index];
                            final isSelected = _selectedCategory == cat;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCategory = cat;
                                  _filterProducts();
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                                margin: const EdgeInsets.only(right: 10),
                                child: isSelected
                                    ? _liquidGlassBox(
                                        isDark: isDark,
                                        radius: 20,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 18, vertical: 8),
                                        child: Text(
                                          cat,
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF1C1C1E),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 18, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          cat,
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white54
                                                : const Color(0xFF3A3A3C)
                                                    .withValues(alpha: 0.55),
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // ── 4. PRODUCT GRID ────────────────────────────────
              if (_isLoading)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childCount: 6,
                    itemBuilder: (context, index) {
                      final double height = index.isEven ? 200.0 : 250.0;
                      return Shimmer.fromColors(
                        baseColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.05),
                        highlightColor: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.1),
                        child: Container(
                          height: height,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      );
                    },
                  ),
                )
              else if (_filteredProducts.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedShoppingBag01,
                          color: isDark ? Colors.white24 : Colors.black26,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No products available',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      return FadeTransition(
                        opacity: _fadeAnim,
                        child: _buildProductCard(
                          _filteredProducts[index],
                          isDark,
                          textPrimary,
                          textSecondary,
                          index,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          
          // ── FLOATING TOP BAR (Nav Back + Cart) ──
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                          size: 22,
                          strokeWidth: 2.0,
                        ),
                      ),
                    ),
                  ),
                ),
                _liquidGlassBox(
                  isDark: isDark,
                  radius: 100,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Like button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isLiked = !_isLiked;
                          });
                        },
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                              child: Icon(
                                _isLiked ? Icons.favorite : Icons.favorite_border_rounded,
                                key: ValueKey(_isLiked),
                                color: _isLiked ? Colors.red : (isDark ? Colors.white : const Color(0xFF1C1C1E)),
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Divider removed as per user request
                      // Cart button
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StoreCartView(
                                shop: widget.shop,
                                cartItems: _cart,
                                isStoreOpen: _status == _StoreStatus.open || _status == _StoreStatus.closingSoon,
                                storeStatusText: _statusText,
                                isHoliday: _status == _StoreStatus.holiday,
                                onUpdateQuantity: (product, delta) {
                                  setState(() {
                                    final idx = _cart.indexWhere((c) => c.product.id == product.id);
                                    if (idx >= 0) {
                                      _cart[idx].quantity += delta;
                                      if (_cart[idx].quantity <= 0) _cart.removeAt(idx);
                                    }
                                  });
                                },
                                onClearCart: () => setState(() => _cart.clear()),
                              ),
                            ),
                          );
                        },
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedShoppingBag01,
                                color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                                size: 22,
                                strokeWidth: 2.0,
                              ),
                              if (_cartItemCount > 0)
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                    child: Text(
                                      '$_cartItemCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
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
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
  }

  // ── Sub-widgets ──────────────────────────────────────────────

  Widget _logoFallback(bool isDark) {
    return Container(
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.blue.withValues(alpha: 0.12),
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedStore01,
          color: isDark ? Colors.white54 : Colors.blue,
          size: 28,
          strokeWidth: 2.0,
        ),
      ),
    );
  }

  Widget _buildCoverFallback(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E242B), const Color(0xFF0F1216)]
              : [const Color(0xFF2563EB), const Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          color: Colors.white.withValues(alpha: 0.15),
          size: 64,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _statusColor.withValues(alpha: 0.7),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: _statusIcon,
            color: _statusColor,
            size: 11,
            strokeWidth: 2.5,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              _statusText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white70,
            size: 14,
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    ProductModel product,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    int index,
  ) {
    return GestureDetector(
      onTap: () => _showProductDetail(product, isDark),
      child: GlassContainer(
        useOwnLayer: true,
        quality: GlassQuality.standard,
        shape: LiquidRoundedSuperellipse(borderRadius: 24),
        settings: _glassSettings(isDark),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.28),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.7),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: product.imageUrl.isNotEmpty
                        ? Image.network(
                            product.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _imageFallback(isDark),
                          )
                        : _imageFallback(isDark),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  product.name,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (product.category.isNotEmpty)
                  Text(
                    product.category,
                    style: TextStyle(
                      color: Colors.blue.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RM ${product.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
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
  }

  Widget _imageFallback(bool isDark) {
    return Container(
      color: isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.blue.withValues(alpha: 0.06),
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedImage01,
          color: isDark ? Colors.white24 : Colors.black26,
          size: 32,
        ),
      ),
    );
  }

  void _showProductDetail(ProductModel product, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      elevation: 0,
      useSafeArea: false,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 1.0,
          expand: false,
          builder: (context, scrollController) {
            bool isProductLiked = false;
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setSheetState) {
                double sheetExtent = 0.72;
                return NotificationListener<DraggableScrollableNotification>(
                  onNotification: (notification) {
                    if (sheetExtent != notification.extent) {
                      setSheetState(() => sheetExtent = notification.extent);
                    }
                    return false;
                  },
                  child: Builder(builder: (context) {
                    double currentRadius = ((1.0 - sheetExtent) * 150).clamp(0.0, 32.0);
                    return ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(currentRadius)),
                      child: Stack(
                        children: [
                          // ── LAYER 1: Outer frosted glass background ──
                          Positioned.fill(
                            child: GlassContainer(
                              useOwnLayer: true,
                              quality: GlassQuality.standard,
                              shape: LiquidRoundedSuperellipse(borderRadius: currentRadius),
                              settings: _glassSettings(isDark, blur: 4.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.4),
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
                              ),
                            ),
                          ),
                          // ── LAYER 2: Scrollable content ──
                          SingleChildScrollView(
                            controller: scrollController,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 40),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Drag handle
                                  AnimatedOpacity(
                                    duration: const Duration(milliseconds: 150),
                                    opacity: sheetExtent > 0.95 ? 0.0 : 1.0,
                                    child: Center(
                                      child: Container(
                                        width: 40,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Product image
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: product.imageUrl.isNotEmpty
                                        ? Image.network(
                                            product.imageUrl,
                                            height: 240,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              height: 240,
                                              color: isDark
                                                  ? Colors.white.withValues(alpha: 0.05)
                                                  : Colors.blue.withValues(alpha: 0.08),
                                              child: const Center(
                                                child: Icon(Icons.image, size: 50, color: Colors.grey),
                                              ),
                                            ),
                                          )
                                        : Container(
                                            height: 240,
                                            color: isDark
                                                ? Colors.white.withValues(alpha: 0.05)
                                                : Colors.blue.withValues(alpha: 0.08),
                                            child: const Center(
                                              child: Icon(Icons.image, size: 50, color: Colors.grey),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 20),
                                  // ── INNER GLASS CARD: Product info ──
                                  _glassBox(
                                    isDark: isDark,
                                    radius: 24,
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (product.category.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Text(
                                              product.category.toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ),
                                        Text(
                                          product.name,
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'RM ${product.price.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.blue,
                                          ),
                                        ),
                                        Divider(
                                          height: 28,
                                          color: isDark ? Colors.white12 : Colors.black12,
                                        ),
                                        Text(
                                          'Description',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          product.description.isEmpty
                                              ? 'No description provided.'
                                              : product.description,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // ── Action Buttons ──
                                  Row(
                                    children: [
                                      // Like Button
                                      GestureDetector(
                                        onTap: () {
                                          setSheetState(() => isProductLiked = !isProductLiked);
                                        },
                                        child: _glassBox(
                                          isDark: isDark,
                                          radius: 18, // matches cart button radius
                                          padding: const EdgeInsets.all(16),
                                          child: AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 300),
                                            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                                            child: Icon(
                                              isProductLiked ? Icons.favorite : Icons.favorite_border_rounded,
                                              key: ValueKey(isProductLiked),
                                              color: isProductLiked ? Colors.red : (isDark ? Colors.white : Colors.black87),
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Add to Cart Button
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            Navigator.pop(context);
                                            _addToCart(product);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 18),
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                              borderRadius: BorderRadius.circular(18),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.blue.withValues(alpha: 0.35),
                                                  blurRadius: 16,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: const Center(
                                              child: Text(
                                                'Add to Cart',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                   const SizedBox(height: 12),
                                   // Book Service / Appointment Button
                                   GestureDetector(
                                     onTap: () {
                                       Navigator.pop(context);
                                       Navigator.push(
                                         context,
                                         MaterialPageRoute(
                                           builder: (_) => BookingsView(
                                             shopId: widget.shop['id']?.toString() ?? '1',
                                             shopName: widget.shop['name'] ?? 'Store',
                                             category: widget.shop['category']?.toString().toUpperCase() ?? 'SERVICE',
                                             shopImage: widget.shop['image'] ?? 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=400',
                                           ),
                                         ),
                                       );
                                     },
                                     child: _glassBox(
                                       isDark: isDark,
                                       radius: 18,
                                       padding: const EdgeInsets.symmetric(vertical: 16),
                                       child: Center(
                                         child: Row(
                                           mainAxisAlignment: MainAxisAlignment.center,
                                           children: [
                                             Icon(Icons.calendar_today_rounded, color: isDark ? Colors.white : Colors.black87, size: 18),
                                             const SizedBox(width: 8),
                                             Text(
                                               'Book Appointment / Slot',
                                               style: TextStyle(
                                                 color: isDark ? Colors.white : Colors.black87,
                                                 fontSize: 15,
                                                 fontWeight: FontWeight.bold,
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
                          ),
                        ],
                      ),
                    );
                  }),
                );
              },
            );
          },
        );
      },
    );
  }
}

