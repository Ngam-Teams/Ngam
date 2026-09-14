import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/product_model.dart';
import 'business_products_view.dart';

// ============================================================
// BusinessStoreView — Main store landing page
// Shows business logo, welcome, status, categories, products
// Glassmorphism matching Ngam default style
// ============================================================

enum _StoreStatus { open, closingSoon, closed }

class BusinessStoreView extends StatefulWidget {
  final Map<String, dynamic> shop;

  const BusinessStoreView({super.key, required this.shop});

  @override
  State<BusinessStoreView> createState() => _BusinessStoreViewState();
}

class _BusinessStoreViewState extends State<BusinessStoreView>
    with TickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription? _productSub;

  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];
  bool _isLoading = true;
  String _selectedCategory = 'All items';

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // ── Status Helpers ───────────────────────────────────────────

  _StoreStatus get _status {
    final int openH = widget.shop['openHour'] ?? 9;
    final int openM = widget.shop['openMinute'] ?? 0;
    final int closeH = widget.shop['closeHour'] ?? 22;
    final int closeM = widget.shop['closeMinute'] ?? 0;

    final now = DateTime.now();
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
    final closeStr =
        _formatTime(widget.shop['closeHour'] ?? 22, widget.shop['closeMinute'] ?? 0);
    final openStr =
        _formatTime(widget.shop['openHour'] ?? 9, widget.shop['openMinute'] ?? 0);
    switch (st) {
      case _StoreStatus.open:
        return 'Open Now · Closes $closeStr';
      case _StoreStatus.closingSoon:
        return 'Closing Soon · $closeStr';
      case _StoreStatus.closed:
        return 'Closed · Opens $openStr';
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
    // HARDCODED FOR UI TESTING
    Future.delayed(const Duration(milliseconds: 500), () {
      final loaded = [
        ProductModel(
          id: '1',
          shopId: '1',
          name: 'Premium Haircut',
          description: 'A stylish and clean premium haircut by professional barbers.',
          price: 35.0,
          category: 'Haircut',
          imageUrl: 'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?q=80&w=400',
          isActive: true,
        ),
        ProductModel(
          id: '2',
          shopId: '1',
          name: 'Classic Shave',
          description: 'Hot towel classic shave for a smooth finish.',
          price: 25.0,
          category: 'Shaving',
          imageUrl: 'https://images.unsplash.com/photo-1621605815971-fbc98d665033?q=80&w=400',
          isActive: true,
        ),
        ProductModel(
          id: '3',
          shopId: '1',
          name: 'Beard Trim',
          description: 'Keep your beard looking sharp and well-groomed.',
          price: 15.0,
          category: 'Shaving',
          imageUrl: 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=400',
          isActive: true,
        ),
        ProductModel(
          id: '4',
          shopId: '1',
          name: 'Hair Coloring',
          description: 'Full hair coloring using premium dyes.',
          price: 80.0,
          category: 'Coloring',
          imageUrl: 'https://images.unsplash.com/photo-1619233543640-af09c173763b?q=80&w=1170',
          isActive: true,
        ),
        ProductModel(
          id: '5',
          shopId: '1',
          name: 'Facial Treatment',
          description: 'Refreshing facial to cleanse and rejuvenate your skin.',
          price: 45.0,
          category: 'Facial',
          imageUrl: 'https://plus.unsplash.com/premium_photo-1661290481306-4841edd49719?q=80&w=1332',
          isActive: true,
        ),
      ];
      if (mounted) {
        setState(() {
          _allProducts = loaded;
          _filterProducts();
          _isLoading = false;
        });
        _fadeCtrl.forward();
      }
    });
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
    double radius = 20,
    EdgeInsetsGeometry? padding,
    Color? overrideColor,
    Color? overrideBorder,
    double blur = 16,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: overrideColor ??
                (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: overrideBorder ??
                  Colors.white.withValues(alpha: isDark ? 0.15 : 0.5),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
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
                  // ── 1. HEADER ─────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Business Logo + Name + Status
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Business logo – glassmorphic circle avatar
                              _liquidGlassBox(
                                isDark: isDark,
                                radius: 100,
                                child: SizedBox(
                                  width: 68,
                                  height: 68,
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
                              ),
                              const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome to',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.shop['name'] ?? 'Business',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                _buildStatusBadge(isDark),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

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
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedShoppingBag01,
                        color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                        size: 22,
                        strokeWidth: 2.0,
                      ),
                    ),
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

  Widget _buildStatusBadge(bool isDark) {
    return _glassBox(
      isDark: isDark,
      radius: 10,
      blur: 12,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      overrideColor: _statusColor.withValues(alpha: 0.12),
      overrideBorder: _statusColor.withValues(alpha: 0.35),
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
              style: TextStyle(
                color: _statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.chevron_right_rounded,
            color: _statusColor,
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
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GlassContainer(
                      useOwnLayer: true,
                      quality: GlassQuality.standard,
                      shape: LiquidRoundedSuperellipse(borderRadius: 32.0),
                      settings: _glassSettings(isDark, blur: 4.0),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.6),
                              width: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      Center(
                        child: Container(
                          margin:
                              const EdgeInsets.only(top: 14, bottom: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white24
                                : Colors.black.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: product.imageUrl.isNotEmpty
                                  ? Image.network(
                                      product.imageUrl,
                                      height: 240,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      height: 240,
                                      color: isDark
                                          ? Colors.white
                                              .withValues(alpha: 0.05)
                                          : Colors.blue
                                              .withValues(alpha: 0.08),
                                      child: const Icon(Icons.image,
                                          size: 50, color: Colors.grey),
                                    ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              product.name,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1C1C1E),
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
                            const SizedBox(height: 20),
                            Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1C1C1E),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.description.isEmpty
                                  ? 'No description provided.'
                                  : product.description,
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.black87,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 28),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius:
                                      BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue
                                          .withValues(alpha: 0.35),
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
                            const SizedBox(height: 32),

                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
