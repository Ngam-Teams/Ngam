import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/product_model.dart';

// ============================================================
// BusinessProductsView — Full product search & browse page
// Glassmorphism matching Ngam default style (LiquidGlass)
// ============================================================

class BusinessProductsView extends StatefulWidget {
  final String shopId;
  final String shopName;
  final String initialSearchQuery;

  const BusinessProductsView({
    super.key,
    required this.shopId,
    required this.shopName,
    this.initialSearchQuery = '',
  });

  @override
  State<BusinessProductsView> createState() => _BusinessProductsViewState();
}

class _BusinessProductsViewState extends State<BusinessProductsView>
    with TickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  StreamSubscription? _productSub;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  List<String> get _categories {
    final cats = _allProducts
        .map((e) => e.category)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    cats.sort();
    return ['All', ...cats];
  }

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialSearchQuery;
    _searchCtrl.text = widget.initialSearchQuery;
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _initStream();
  }

  @override
  void dispose() {
    _productSub?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
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
          description:
              'A stylish and clean premium haircut by professional barbers.',
          price: 35.0,
          category: 'Haircut',
          imageUrl:
              'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?q=80&w=400',
          isActive: true,
        ),
        ProductModel(
          id: '2',
          shopId: '1',
          name: 'Classic Shave',
          description: 'Hot towel classic shave for a smooth finish.',
          price: 25.0,
          category: 'Shaving',
          imageUrl:
              'https://images.unsplash.com/photo-1621605815971-fbc98d665033?q=80&w=400',
          isActive: true,
        ),
        ProductModel(
          id: '3',
          shopId: '1',
          name: 'Beard Trim',
          description: 'Keep your beard looking sharp and well-groomed.',
          price: 15.0,
          category: 'Shaving',
          imageUrl:
              'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=400',
          isActive: true,
        ),
        ProductModel(
          id: '4',
          shopId: '1',
          name: 'Hair Coloring',
          description: 'Full hair coloring using premium dyes.',
          price: 80.0,
          category: 'Coloring',
          imageUrl:
              'https://images.unsplash.com/photo-1619233543640-af09c173763b?q=80&w=400',
          isActive: true,
        ),
        ProductModel(
          id: '5',
          shopId: '1',
          name: 'Facial Treatment',
          description: 'Refreshing facial to cleanse and rejuvenate your skin.',
          price: 45.0,
          category: 'Facial',
          imageUrl:
              'https://plus.unsplash.com/premium_photo-1661290481306-4841edd49719?q=80&w=1332',
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
    setState(() {
      _filteredProducts = _allProducts.where((p) {
        final matchesSearch = p.name.toLowerCase().contains(
          _searchQuery.toLowerCase(),
        );
        final matchesCategory =
            _selectedCategory == 'All' || p.category == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  // ── Glass helpers matching Ngam style ────────────────────────

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
            color:
                overrideColor ??
                (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color:
                  overrideBorder ??
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

  void _showProductDetails(ProductModel product, bool isDark) {
    final Color textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
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
                      settings: _glassSettings(isDark, blur: 20.0),
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
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 14, bottom: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white24
                              : Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: product.imageUrl.isNotEmpty
                                  ? Image.network(
                                      product.imageUrl,
                                      height: 250,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      height: 250,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : Colors.blue.withValues(alpha: 0.08),
                                      child: const Icon(
                                        Icons.image,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              product.name,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
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
                            const SizedBox(height: 24),
                            Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.description.isEmpty
                                  ? 'No description provided.'
                                  : product.description,
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? Colors.white70 : Colors.black87,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 32),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withValues(
                                        alpha: 0.35,
                                      ),
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
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: false,
      body: SizedBox.expand(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── APP BAR ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1C1C1E),
                              size: 22,
                              strokeWidth: 2.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      widget.shopName,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1C1C1E),
                            size: 22,
                            strokeWidth: 2.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── SEARCH BAR ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
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
                            // Outline removed per user request
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
                                  controller: _searchCtrl,
                                  focusNode: _searchFocus,
                                  onChanged: (val) {
                                    _searchQuery = val;
                                    _filterProducts();
                                  },
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                  cursorColor: textPrimary,
                                  decoration: InputDecoration(
                                    hintText: 'Search products...',
                                    hintStyle: TextStyle(
                                      color: isDark
                                          ? Colors.white38
                                          : const Color(0xFF3A3A3C)
                                              .withValues(alpha: 0.45),
                                      fontSize: 14,
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
                              if (_searchQuery.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchCtrl.clear();
                                    _searchQuery = '';
                                    _filterProducts();
                                  },
                                  child: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54,
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
              ),

              const SizedBox(height: 20),

              // ── CATEGORY CHIPS ──────────────────────────────────
              if (_categories.length > 1)
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: SizedBox(
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
                                      horizontal: 18,
                                      vertical: 8,
                                    ),
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
                                      horizontal: 18,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      cat,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white54
                                            : const Color(
                                                0xFF3A3A3C,
                                              ).withValues(alpha: 0.55),
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
                ),

              if (_categories.length > 1) const SizedBox(height: 16),

              // ── MASONRY GRID ─────────────────────────────────────
              Expanded(
                child: _isLoading
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: MasonryGridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          itemCount: 6,
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
                    : _filteredProducts.isEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                            child: Text(
                              'Found\n0 Results',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                                letterSpacing: -1.0,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedSearchRemove,
                                    color: isDark ? Colors.white24 : Colors.black26,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No products found.',
                                    style: TextStyle(
                                      color: isDark ? Colors.white54 : Colors.black54,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : FadeTransition(
                        opacity: _fadeAnim,
                        child: MasonryGridView.count(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          itemCount: _filteredProducts.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  top: 10,
                                  bottom: 20,
                                ),
                                child: Text(
                                  'Found\n${_filteredProducts.length} Results',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                    letterSpacing: -1.0,
                                  ),
                                ),
                              );
                            }
                            final product = _filteredProducts[index - 1];
                            return GestureDetector(
                              onTap: () => _showProductDetails(product, isDark),
                              child: GlassContainer(
                                useOwnLayer: true,
                                quality: GlassQuality.standard,
                                shape: LiquidRoundedSuperellipse(
                                  borderRadius: 24,
                                ),
                                settings: _glassSettings(isDark),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.04)
                                        : Colors.white.withValues(alpha: 0.28),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: isDark ? 0.12 : 0.7,
                                      ),
                                      width: 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: isDark ? 0.15 : 0.06,
                                        ),
                                        blurRadius: 20,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: product.imageUrl.isNotEmpty
                                                ? Image.network(
                                                    product.imageUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (_, __, ___) =>
                                                            _imgFallback(
                                                              isDark,
                                                            ),
                                                  )
                                                : _imgFallback(isDark),
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
                                              color: Colors.blue.withValues(
                                                alpha: 0.8,
                                              ),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
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
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imgFallback(bool isDark) {
    return Container(
      height: 120,
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
}
