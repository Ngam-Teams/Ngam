import 'dart:async';
import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ngam/widgets/glass_box.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../models/product_model.dart';
import '../../services/chat_service.dart';
import '../../services/r2_storage_service.dart';
import '../../services/saved_service.dart';
import '../../services/store_cart_service.dart';
import '../../services/voucher_service.dart';
import '../../utils/business_industry_helper.dart';
import '../../utils/glass_toast.dart';
import '../../widgets/hold_repeat_button.dart';
import '../../widgets/liquid_glass_compat.dart';
import '../../widgets/natural_aspect_image.dart';
import '../shared/chat_screen.dart';
import 'bookings_view.dart';
import 'business_store_view.dart';
import 'store_cart_view.dart';
import 'store_reviews_view.dart';

// =============================================================================
// ProductDetailScreen — Dedicated Shopee-Style Product & Service Details Screen
// Rich Hero Carousel, Rating & Sold Proof, Vouchers, Variation & Quantity Picker,
// Service Info, Merchant Card, Specs, Customer Comments & Reviews, Sticky Bottom
// Action Bar: [Chat 1/4] [Add to Cart 1/4] [Buy Now / Book Now 1/2]
// =============================================================================

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;
  final Map<String, dynamic> shop;
  final String? tableNumber;
  final String? promoCode;
  final void Function(
    ProductModel product, {
    String? selectedOption,
    String? itemNote,
    double optionExtraPrice,
  })? onAddToCart;
  final void Function(ProductModel product)? onBuyNow;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.shop,
    this.tableNumber,
    this.promoCode,
    this.onAddToCart,
    this.onBuyNow,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late ProductModel _product;
  final PageController _imagePageCtrl = PageController();
  final ScrollController _scrollCtrl = ScrollController();
  int _currentImageIndex = 0;

  // Hero Video Showcase (Slide 0 when available)
  VideoPlayerController? _heroVideoCtrl;
  bool _heroVideoReady = false;
  bool _heroVideoPlaying = false;
  bool _heroVideoMuted = true;
  bool _heroVideoError = false;

  // Natural aspect ratio cache per gallery image URL (width / height)
  final Map<String, double> _slideAspectRatios = {};

  // Selections
  int _selectedVariantIndex = -1;
  String? _selectedTier1;
  String? _selectedTier2;
  final Set<int> _selectedModifierIndices = {};
  int _quantity = 1;
  final TextEditingController _noteCtrl = TextEditingController();

  // State
  bool _isSaved = false;
  bool _isDescriptionExpanded = false;
  bool _isLoadingComments = true;
  bool _isPostingComment = false;
  int _activeReviewFilter = 0; // 0: All, 1: Photos, 2: 5-star, 3: 4-star

  // Related data
  List<Map<String, dynamic>> _comments = [];
  List<Map<String, dynamic>> _vouchers = [];
  List<ProductModel> _moreProducts = [];
  Map<String, dynamic>? _shopDetails;

  // Smart Auto-Contrast (Option 2 — iPhone Lock Screen style)
  // Samples top-left (Back) & top-right (Share/Like/Cart) brightness independently
  final Map<String, ({bool leftDark, bool rightDark})> _slideTopContrast = {};
  final Set<String> _contrastInFlight = {};
  bool _isScrolledPastHero = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _isSaved = SavedService.isProductSaved(_product.id);
    _shopDetails = Map<String, dynamic>.from(widget.shop);

    _scrollCtrl.addListener(_onMainScroll);
    _resolveGalleryAspectRatios();
    _initHeroVideo();
    _initAsyncData();
  }

  void _onMainScroll() {
    if (!_scrollCtrl.hasClients) return;
    final passed = _scrollCtrl.offset > 220;
    if (passed != _isScrolledPastHero && mounted) {
      setState(() => _isScrolledPastHero = passed);
    }
  }

  void _analyzeSlideTopContrast(String url, bool isDarkTheme) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final cacheKey = '${trimmed}_$isDarkTheme';
    if (_slideTopContrast.containsKey(cacheKey) || _contrastInFlight.contains(cacheKey)) {
      return;
    }
    _contrastInFlight.add(cacheKey);

    final provider = ResizeImage.resizeIfNeeded(64, null, NetworkImage(trimmed));
    final stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) async {
        stream.removeListener(listener);
        try {
          final img = info.image;
          final byteData = await img.toByteData(format: ImageByteFormat.rawRgba);
          if (byteData == null) {
            _contrastInFlight.remove(cacheKey);
            return;
          }
          final bytes = byteData.buffer.asUint8List();
          final w = img.width;
          final h = img.height;
          final bgR = isDarkTheme ? 10.0 : 248.0;
          final bgG = isDarkTheme ? 10.0 : 250.0;
          final bgB = isDarkTheme ? 20.0 : 252.0;

          double sampleRegion(int x0, int x1, int y0, int y1) {
            double sum = 0;
            int count = 0;
            for (int y = y0; y < y1; y++) {
              for (int x = x0; x < x1; x++) {
                final idx = (y * w + x) * 4;
                if (idx + 3 >= bytes.length) continue;
                final a = bytes[idx + 3] / 255.0;
                final r = bytes[idx] * a + bgR * (1.0 - a);
                final g = bytes[idx + 1] * a + bgG * (1.0 - a);
                final b = bytes[idx + 2] * a + bgB * (1.0 - a);
                sum += 0.299 * r + 0.587 * g + 0.114 * b;
                count++;
              }
            }
            return count > 0 ? sum / count : (isDarkTheme ? 30.0 : 220.0);
          }

          final topH = (h * 0.28).round().clamp(1, h);
          final leftW = (w * 0.30).round().clamp(1, w);
          final rightX0 = (w * 0.62).round().clamp(0, w - 1);

          final leftLum = sampleRegion(0, leftW, 0, topH);
          final rightLum = sampleRegion(rightX0, w, 0, topH);

          _slideTopContrast[cacheKey] = (
            leftDark: leftLum < 138.0,
            rightDark: rightLum < 138.0,
          );
          if (mounted) setState(() {});
        } catch (_) {
          // CORS or WebGL readback fallback: keep theme default safely
        } finally {
          _contrastInFlight.remove(cacheKey);
        }
      },
      onError: (_, __) {
        stream.removeListener(listener);
        _contrastInFlight.remove(cacheKey);
      },
    );
    stream.addListener(listener);
  }

  void _resolveGalleryAspectRatios() {
    for (final url in _product.galleryImages) {
      final cached = NaturalImageAspectCache.get(url);
      if (cached != null) {
        _slideAspectRatios[url] = cached;
        continue;
      }
      NaturalImageAspectCache.resolve(url).then((ratio) {
        if (!mounted || ratio == null) return;
        if (_slideAspectRatios[url] != ratio) {
          setState(() => _slideAspectRatios[url] = ratio);
        }
      });
    }
  }

  Future<void> _initHeroVideo() async {
    final url = _product.videoUrl.trim();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) setState(() => _heroVideoError = true);
      return;
    }
    try {
      final ctrl = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _heroVideoCtrl = ctrl;
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(0.0);
      if (_currentImageIndex == 0) {
        await ctrl.play();
      }
      if (mounted) {
        setState(() {
          _heroVideoReady = true;
          _heroVideoPlaying = _currentImageIndex == 0;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _heroVideoError = true);
    }
  }

  @override
  void dispose() {
    _heroVideoCtrl?.dispose();
    _imagePageCtrl.dispose();
    _scrollCtrl.removeListener(_onMainScroll);
    _scrollCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _initAsyncData() async {
    await SavedService.init();
    if (mounted) {
      setState(() {
        _isSaved = SavedService.isProductSaved(_product.id);
      });
    }

    _fetchShopDetails();
    _fetchComments();
    _fetchVouchers();
    _fetchMoreProducts();
  }

  String get _shopId {
    final sId = (_product.shopId.isNotEmpty)
        ? _product.shopId
        : (widget.shop['id'] ?? widget.shop['shopId'] ?? '').toString();
    return sId;
  }

  String get _shopName {
    return (_shopDetails?['name'] ??
            _shopDetails?['business_name'] ??
            widget.shop['name'] ??
            widget.shop['business_name'] ??
            'Ngam Partner')
        .toString();
  }

  String get _shopLogo {
    return (_shopDetails?['logo_url'] ??
            _shopDetails?['business_logo_url'] ??
            widget.shop['logo_url'] ??
            widget.shop['business_logo_url'] ??
            widget.shop['image'] ??
            '')
        .toString();
  }

  String get _shopCover {
    return (_shopDetails?['cover'] ??
            _shopDetails?['business_cover_url'] ??
            widget.shop['business_cover_url'] ??
            widget.shop['cover'] ??
            '')
        .toString();
  }

  bool get _isStoreOpen {
    if (_shopDetails != null && _shopDetails!['is_open'] != null) {
      return _shopDetails!['is_open'] == true;
    }
    return widget.shop['is_open'] ?? true;
  }

  // ── Price, Stock & Weight calculations ─────────────────────────

  bool get _isTwoTier => _product.isTwoTierVariants;

  bool get _needsVariantSelection {
    if (_product.variants.isEmpty) return false;
    if (_isTwoTier) {
      return _product.findTwoTierVariant(_selectedTier1, _selectedTier2) == null;
    }
    return _selectedVariantIndex < 0 || _selectedVariantIndex >= _product.variants.length;
  }

  Map<String, dynamic>? get _selectedVariant {
    if (_product.variants.isEmpty) return null;
    if (_isTwoTier) {
      return _product.findTwoTierVariant(_selectedTier1, _selectedTier2);
    }
    if (_selectedVariantIndex >= 0 && _selectedVariantIndex < _product.variants.length) {
      return _product.variants[_selectedVariantIndex];
    }
    return null;
  }

  List<Map<String, dynamic>> get _matchingSubset {
    if (!_isTwoTier) return _product.variants;
    return _product.matchingVariants(tier1: _selectedTier1, tier2: _selectedTier2);
  }

  double get _selectedModifiersExtraPrice {
    if (_product.modifiers.isEmpty || _selectedModifierIndices.isEmpty) return 0.0;
    double sum = 0.0;
    for (final idx in _selectedModifierIndices) {
      if (idx >= 0 && idx < _product.modifiers.length) {
        final m = _product.modifiers[idx];
        sum += (m['price'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return sum;
  }

  double get _unitPrice {
    final baseOrVariant = _selectedVariant != null
        ? _product.variantEffectivePrice(_selectedVariant!)
        : _product.minPrice;
    return baseOrVariant + _selectedModifiersExtraPrice;
  }

  /// Compact Shopee price text without the `RM` prefix (e.g. `10.82 - 15.90` or `15.80`).
  (bool isRange, String valueText) get _activePriceDisplay {
    if (_selectedVariant != null || _product.variants.isEmpty) {
      return (false, _unitPrice.toStringAsFixed(2));
    }
    final subset = _matchingSubset;
    final prices = subset
        .map((v) => _product.variantEffectivePrice(v) + _selectedModifiersExtraPrice)
        .where((p) => p > 0)
        .toList();
    if (prices.isEmpty) {
      return (false, _unitPrice.toStringAsFixed(2));
    }
    final lo = prices.reduce((a, b) => a < b ? a : b);
    final hi = prices.reduce((a, b) => a > b ? a : b);
    if ((hi - lo).abs() >= 0.005) {
      return (true, '${lo.toStringAsFixed(2)} - ${hi.toStringAsFixed(2)}');
    }
    return (false, lo.toStringAsFixed(2));
  }

  int get _activeStock {
    if (_selectedVariant != null) {
      return _product.variantStock(_selectedVariant!) ?? _product.stock;
    }
    if (_isTwoTier && (_selectedTier1 != null || _selectedTier2 != null)) {
      return _product.totalStockForVariants(_matchingSubset);
    }
    return _product.effectiveTotalStock;
  }

  bool get _isActiveOutOfStock =>
      _product.isProduct && _product.trackInventory && _activeStock <= 0;

  bool get _isActiveLowStock =>
      _product.isProduct &&
      _product.trackInventory &&
      _activeStock > 0 &&
      _activeStock <= _product.lowStockThreshold;

  double get _activeWeightKg => _selectedVariant != null
      ? _product.variantWeightKg(_selectedVariant!)
      : _product.weightKg;

  String? get _selectedOptionName {
    final parts = <String>[];
    final selVar = _selectedVariant;
    if (selVar != null) {
      final vName = (selVar['name'] ?? '').toString().trim();
      if (vName.isNotEmpty) {
        parts.add(vName);
      } else if (_isTwoTier && _selectedTier1 != null && _selectedTier2 != null) {
        parts.add('$_selectedTier1 / $_selectedTier2');
      }
    }
    for (final idx in _selectedModifierIndices) {
      if (idx >= 0 && idx < _product.modifiers.length) {
        final mName = (_product.modifiers[idx]['name'] ?? '').toString().trim();
        if (mName.isNotEmpty) parts.add('+$mName');
      }
    }
    return parts.isEmpty ? null : parts.join(', ');
  }

  // ── Network Fetchers ───────────────────────────────────────────

  Future<void> _fetchShopDetails() async {
    final sId = _shopId;
    if (sId.isEmpty) return;
    try {
      final res = await Supabase.instance.client
          .from('businesses')
          .select('id, business_name, business_handle, business_logo_url, business_cover_url, business_industry, business_phone, is_open, total_reviews, rating')
          .eq('id', sId)
          .maybeSingle();
      if (res != null && mounted) {
        setState(() {
          _shopDetails = {
            ...widget.shop,
            ...res,
            'name': res['business_name'] ?? widget.shop['name'],
          };
        });
      }
    } catch (e) {
      debugPrint('[ProductDetailScreen] _fetchShopDetails error: $e');
    }
  }

  Future<void> _fetchVouchers() async {
    try {
      final sId = _shopId;
      final available = await VoucherService.getAvailableVouchersForCheckout(
        businessId: sId.isNotEmpty ? sId : null,
        subtotal: _unitPrice,
        category: _product.category.isNotEmpty ? _product.category : null,
      );
      if (mounted) {
        setState(() {
          _vouchers = available.take(3).toList();
        });
      }
    } catch (e) {
      debugPrint('[ProductDetailScreen] _fetchVouchers error: $e');
    }
  }

  Future<void> _fetchMoreProducts() async {
    final sId = _shopId;
    if (sId.isEmpty) return;
    try {
      final res = await Supabase.instance.client
          .from('business_products')
          .select()
          .eq('shop_id', sId)
          .eq('is_active', true)
          .neq('id', _product.id)
          .order('created_at', ascending: false)
          .limit(6);

      if (mounted) {
        setState(() {
          _moreProducts = (res as List)
              .map((json) => ProductModel.fromJson(Map<String, dynamic>.from(json)))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('[ProductDetailScreen] _fetchMoreProducts error: $e');
    }
  }

  Future<void> _fetchComments() async {
    setState(() => _isLoadingComments = true);
    final sId = _shopId;
    try {
      List<Map<String, dynamic>> fetched = [];
      if (sId.isNotEmpty) {
        final res = await Supabase.instance.client
            .from('reviews')
            .select()
            .eq('business_id', sId)
            .order('created_at', ascending: false)
            .limit(20);

        fetched = (res as List).map<Map<String, dynamic>>((row) {
          final dynamic rawImgs = row['images'] ?? row['image_urls'];
          final List<String> imgs = [];
          if (rawImgs is List) {
            for (final i in rawImgs) {
              if (i != null && i.toString().isNotEmpty) imgs.add(i.toString());
            }
          } else if (rawImgs is String && rawImgs.isNotEmpty) {
            imgs.add(rawImgs);
          }

          return {
            'id': row['id']?.toString() ?? '',
            'name': row['reviewer_name'] ?? 'Pelanggan',
            'avatar': row['reviewer_avatar'] ?? '',
            'rating': (row['rating'] as num?)?.toInt() ?? 5,
            'comment': row['comment']?.toString() ?? '',
            'date': _formatCommentDate(row['created_at']?.toString()),
            'images': imgs,
            'helpful': (row['helpful_count'] as num?)?.toInt() ?? 0,
            'variant': row['variant_name']?.toString() ?? '',
          };
        }).toList();
      }

      // Fallback verified sample reviews if fresh business has none yet
      if (fetched.isEmpty) {
        fetched = [
          {
            'id': 'sample_1',
            'name': 'Farhan Akmal',
            'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=150',
            'rating': 5,
            'comment': 'Sangat berbaloi! Kualiti mantap dan servis dari peniaga memang pantas. Recommended!',
            'date': '2 hari lepas',
            'images': [
              if (_product.imageUrl.isNotEmpty) _product.imageUrl,
            ],
            'helpful': 12,
            'variant': _product.variants.isNotEmpty
                ? (_product.variants.first['name'] ?? '')
                : '',
          },
          {
            'id': 'sample_2',
            'name': 'Nurul Ain',
            'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=150',
            'rating': 5,
            'comment': 'Item sampai dalam keadaan baik dan sama macam dalam gambar. Puas hati sangat!',
            'date': '5 hari lepas',
            'images': <String>[],
            'helpful': 7,
            'variant': '',
          },
        ];
      }

      if (mounted) {
        setState(() {
          _comments = fetched;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      debugPrint('[ProductDetailScreen] _fetchComments error: $e');
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  String _formatCommentDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'product_detail.verified_customer'.tr();
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h';
      } else if (diff.inDays < 30) {
        return '${diff.inDays}d';
      }
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return '';
    }
  }

  List<Map<String, dynamic>> get _filteredComments {
    if (_activeReviewFilter == 1) {
      return _comments.where((c) {
        final imgs = c['images'];
        return imgs is List && imgs.isNotEmpty;
      }).toList();
    } else if (_activeReviewFilter == 2) {
      return _comments.where((c) => (c['rating'] ?? 5) == 5).toList();
    } else if (_activeReviewFilter == 3) {
      return _comments.where((c) => (c['rating'] ?? 5) == 4).toList();
    }
    return _comments;
  }

  // ── Actions ───────────────────────────────────────────────────

  void _toggleSave() async {
    final nowSaved = await SavedService.toggleSaveProduct({
      'id': _product.id,
      'shopId': _shopId,
      'name': _product.name,
      'price': _product.minPrice,
      'imageUrl': _product.imageUrl,
      'category': _product.category,
      'itemType': _product.itemType,
      'shopName': _shopName,
    });
    if (mounted) {
      setState(() => _isSaved = nowSaved);
      showGlassToast(
        context,
        nowSaved
            ? 'product_detail.saved_toast'.tr()
            : 'product_detail.unsaved_toast'.tr(),
      );
    }
  }

  void _shareProduct() {
    final handle = _shopDetails?['business_handle'] ?? '';
    final url = handle.toString().isNotEmpty
        ? 'https://ngam.dev/@$handle?p=${_product.id}'
        : 'https://ngam.dev/c/$_shopId?p=${_product.id}';
    Share.share(
      '${_product.name} (${_product.formattedPriceRange}) - $_shopName\n$url',
      subject: _product.name,
    );
  }

  Future<void> _openChat() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      showGlassToast(context, 'chat.login_required'.tr(), isError: true);
      Navigator.pushNamed(context, '/login');
      return;
    }

    final sId = _shopId;
    if (sId.isEmpty) return;

    try {
      final conv = await ChatService.getOrCreateBusinessConversation(
        sId,
        contextType: _product.isService ? 'booking' : 'order',
        contextId: _product.id,
      );
      if (!mounted) return;

      final draft = 'product_detail.chat_prefill'.tr(
        args: [_product.name, _unitPrice.toStringAsFixed(2)],
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(
            conversation: conv,
            initialDraftMessage: draft,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[ProductDetailScreen] _openChat failed: $e');
      if (mounted) {
        showGlassToast(context, 'chat.open_chat_failed'.tr(), isError: true);
      }
    }
  }

  void _onAddToCartPressed() {
    if (_needsVariantSelection) {
      _showVariationBottomSheet(buyNow: false);
      return;
    }
    if (_isActiveOutOfStock) {
      showGlassToast(context, 'product_detail.out_of_stock'.tr(), isError: true);
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      showGlassToast(context, 'auth.sign_in_required'.tr(), isError: true);
      Navigator.pushNamed(context, '/login');
      return;
    }

    final effectiveProduct = _product.copyWith(
      stock: _activeStock,
      weightKg: _activeWeightKg,
    );
    final extra = _unitPrice - effectiveProduct.price;
    final opt = _selectedOptionName;
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();

    if (_product.isProduct && _product.trackInventory) {
      final inCart = StoreCartService.existingQtyFor(
        _shopId,
        effectiveProduct.id,
        selectedOption: opt,
        itemNote: note,
      );
      if (inCart + _quantity > _activeStock) {
        showGlassToast(
          context,
          'product_detail.max_stock_reached'.tr(args: ['$_activeStock']),
          isError: true,
        );
        return;
      }
    }

    StoreCartService.addItem(
      _shopId,
      effectiveProduct,
      quantity: _quantity,
      selectedOption: opt,
      itemNote: note,
      optionExtraPrice: extra,
    );
    showGlassToast(
      context,
      'product_detail.added_to_cart_toast'.tr(args: [_product.name]),
    );
  }

  void _onBuyNowPressed() {
    if (_product.isService) {
      _openBookingFlow();
      return;
    }

    if (_needsVariantSelection) {
      _showVariationBottomSheet(buyNow: true);
      return;
    }
    if (_isActiveOutOfStock) {
      showGlassToast(context, 'product_detail.out_of_stock'.tr(), isError: true);
      return;
    }

    if (_product.isProduct && _product.trackInventory && _quantity > _activeStock) {
      setState(() => _quantity = _activeStock.clamp(1, 999));
      showGlassToast(
        context,
        'product_detail.max_stock_reached'.tr(args: ['$_activeStock']),
        isError: true,
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      showGlassToast(context, 'auth.sign_in_required'.tr(), isError: true);
      Navigator.pushNamed(context, '/login');
      return;
    }

    final effectiveProduct = _product.copyWith(
      stock: _activeStock,
      weightKg: _activeWeightKg,
    );
    final extra = _unitPrice - effectiveProduct.price;
    final opt = _selectedOptionName;
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();

    final item = CartItem(
      product: effectiveProduct,
      quantity: _quantity,
      selectedOption: opt,
      itemNote: note,
      optionExtraPrice: extra,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoreCartView(
          shop: {
            ...widget.shop,
            if (_shopDetails != null) ..._shopDetails!,
            'name': _shopName,
            'business_name': _shopName,
          },
          cartItems: [item],
          tableNumber: widget.tableNumber,
          promoCode: widget.promoCode,
        ),
      ),
    );
  }

  String get _shopCategory {
    final c = (_shopDetails?['business_industry'] ??
            _shopDetails?['category'] ??
            widget.shop['business_industry'] ??
            widget.shop['category'])
        ?.toString()
        .trim();
    if (c != null && c.isNotEmpty) return c;
    return _product.category.isNotEmpty ? _product.category : 'Servis';
  }

  void _openBookingFlow() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      showGlassToast(context, 'auth.sign_in_required'.tr(), isError: true);
      Navigator.pushNamed(context, '/login');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingsView(
          shopId: _shopId,
          shopName: _shopName,
          category: _shopCategory,
          shopImage: _shopCover.isNotEmpty
              ? _shopCover
              : (_shopLogo.isNotEmpty ? _shopLogo : _product.imageUrl),
          initialServiceId: _product.id,
          initialServiceName: _product.name,
        ),
      ),
    );
  }

  void _openStorefront() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessStoreView(
          shop: {
            ...widget.shop,
            if (_shopDetails != null) ..._shopDetails!,
            'id': _shopId,
            'name': _shopName,
            'business_name': _shopName,
            'cover': _shopCover,
            'business_cover_url': _shopCover,
            'logo_url': _shopLogo,
            'business_logo_url': _shopLogo,
          },
          tableNumber: widget.tableNumber,
          promoCode: widget.promoCode,
        ),
      ),
    );
  }

  void _openAllReviews() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoreReviewsView(
          shop: {
            ...widget.shop,
            'id': _shopId,
            'name': _shopName,
            'reviews': _comments.length,
            'rating': _product.rating ?? 5.0,
          },
        ),
      ),
    );
  }

  // ── Write Comment Modal ────────────────────────────────────────

  void _openWriteCommentSheet(bool isDark) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      showGlassToast(context, 'product_detail.login_to_comment'.tr(), isError: true);
      Navigator.pushNamed(context, '/login');
      return;
    }

    int rating = 5;
    final textCtrl = TextEditingController();
    final List<XFile> attachedPhotos = [];
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
          final textSecondary = isDark ? Colors.white70 : Colors.black54;

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161622) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'product_detail.write_review_title'.tr(),
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'product_detail.write_review_subtitle'.tr(),
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // Star rating bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final starNum = i + 1;
                      return IconButton(
                        iconSize: 32,
                        icon: Icon(
                          starNum <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          setModalState(() => rating = starNum);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 12),

                  // Comment Input
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    child: TextField(
                      controller: textCtrl,
                      maxLines: 4,
                      style: TextStyle(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'product_detail.comment_placeholder'.tr(),
                        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                        filled: false,
                        fillColor: Colors.transparent,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Attached Photos Preview
                  if (attachedPhotos.isNotEmpty) ...[
                    SizedBox(
                      height: 72,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: attachedPhotos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, idx) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: FutureBuilder<Uint8List>(
                                  future: attachedPhotos[idx].readAsBytes(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return Container(
                                        width: 72,
                                        height: 72,
                                        color: isDark ? Colors.white12 : Colors.black12,
                                      );
                                    }
                                    return Image.memory(
                                      snapshot.data!,
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                    );
                                  },
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () {
                                    setModalState(() => attachedPhotos.removeAt(idx));
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Colors.black87,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Action Buttons: Add Photo & Submit
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textPrimary,
                          side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final ImagePicker picker = ImagePicker();
                                final files = await picker.pickMultiImage();
                                if (files.isNotEmpty) {
                                  setModalState(() {
                                    attachedPhotos.addAll(files);
                                    if (attachedPhotos.length > 4) {
                                      attachedPhotos.removeRange(4, attachedPhotos.length);
                                    }
                                  });
                                }
                              },
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedCamera01,
                          color: Color(0xFF42A5F5),
                          size: 18,
                        ),
                        label: Text(
                          'product_detail.add_photo_btn'.tr(),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final comment = textCtrl.text.trim();
                                  if (comment.isEmpty && attachedPhotos.isEmpty) {
                                    showGlassToast(
                                      context,
                                      'product_detail.comment_empty_error'.tr(),
                                      isError: true,
                                    );
                                    return;
                                  }

                                  setModalState(() => isSubmitting = true);
                                  try {
                                    final List<String> uploadedUrls = [];
                                    for (final photo in attachedPhotos) {
                                      final bytes = await photo.readAsBytes();
                                      final url = await R2StorageService().uploadMedia(
                                        bytes: bytes,
                                        fileName: photo.name,
                                        folder: 'reviews',
                                        mimeType: photo.mimeType ?? 'image/jpeg',
                                      );
                                      if (url.isNotEmpty) uploadedUrls.add(url);
                                    }

                                    final sId = _shopId;
                                    await Supabase.instance.client.from('reviews').insert({
                                      if (sId.isNotEmpty) 'business_id': sId,
                                      'user_id': user.id,
                                      'rating': rating,
                                      'comment': comment,
                                      if (uploadedUrls.isNotEmpty) 'images': uploadedUrls,
                                      'service_name': _product.name,
                                      'variant_name': _selectedOptionName ?? '',
                                      'reviewer_name': user.userMetadata?['full_name'] ??
                                          user.userMetadata?['name'] ??
                                          'Pelanggan Ngam',
                                      'reviewer_avatar': user.userMetadata?['avatar_url'] ?? '',
                                    });

                                    if (modalCtx.mounted) Navigator.pop(modalCtx);
                                    if (mounted) {
                                      showGlassToast(
                                        context,
                                        'product_detail.comment_posted_toast'.tr(),
                                        type: GlassToastType.success,
                                      );
                                      _fetchComments();
                                    }
                                  } catch (e) {
                                    debugPrint('[ProductDetailScreen] Post review error: $e');
                                    setModalState(() => isSubmitting = false);
                                    if (mounted) {
                                      showGlassToast(
                                        context,
                                        'review.submit_error'.tr(),
                                        isError: true,
                                      );
                                    }
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'product_detail.submit_comment_btn'.tr(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
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
        },
      ),
    );
  }

  // ── Glass Styling Helpers ──────────────────────────────────────

  LiquidGlassSettings _glassSettings(bool isDark, {double blur = 6.0}) {
    return LiquidGlassSettings(
      thickness: 0.15,
      blur: blur,
      refractiveIndex: 1.0,
      glassColor: Colors.transparent,
      lightAngle: 45.0,
      lightIntensity: isDark ? 0.12 : 0.22,
      ambientStrength: 1.0,
      saturation: 1.0,
      chromaticAberration: 0.0,
    );
  }

  Widget _liquidCard({
    required bool isDark,
    required Widget child,
    double radius = 24,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      margin: margin,
      child: GlassContainer(
        useOwnLayer: true,
        quality: GlassQuality.standard,
        shape: LiquidRoundedSuperellipse(borderRadius: radius),
        settings: _glassSettings(isDark),
        child: Container(
          padding: padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.55),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.7),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // ── Build Method ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final bgColor = isDark ? const Color(0xFF0A0A14) : const Color(0xFFF3F4F6);
    final screenW = MediaQuery.of(context).size.width;
    final bool isDesktop = screenW >= 900;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // ── Scrollable Body ──
          if (isDesktop)
            _buildDesktopShopeeBody(
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            )
          else
            CustomScrollView(
              controller: _scrollCtrl,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 1. Hero Image Gallery Slider
                SliverToBoxAdapter(
                  child: _buildHeroImageSlider(isDark),
                ),

                // 2. Main Content Card: Price, Name, Badges, Rating & Sold Count
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildPriceAndHeaderCard(isDark, textPrimary, textSecondary),
                  ),
                ),

                // 3. Shop Vouchers Row (if available)
                if (_vouchers.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _buildVouchersRow(isDark, textPrimary, textSecondary),
                    ),
                  ),

                // 4. Variations / Options Picker (if product has variants or modifiers)
                if (_product.variants.isNotEmpty || _product.modifiers.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _buildVariationsCard(isDark, textPrimary, textSecondary),
                    ),
                  ),

                // 5. Quantity & Note Selector (for physical products / multi-order)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildQuantityAndNoteCard(isDark, textPrimary, textSecondary),
                  ),
                ),

                // 6. Service Highlights Card (if item is a service)
                if (_product.isService)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _buildServiceInfoCard(isDark, textPrimary, textSecondary),
                    ),
                  ),

                // 7. Merchant / Shop Profile Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildShopProfileCard(isDark, textPrimary, textSecondary),
                  ),
                ),

                // 8. Specifications & Item Details Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildSpecCard(isDark, textPrimary, textSecondary),
                  ),
                ),

                // 9. Full Description Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildDescriptionCard(isDark, textPrimary, textSecondary),
                  ),
                ),

                // 10. Customer Comments & Reviews Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildReviewsSection(isDark, textPrimary, textSecondary),
                  ),
                ),

                // 11. "More From This Shop" Carousel / Grid
                if (_moreProducts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _buildMoreProductsSection(isDark, textPrimary, textSecondary),
                    ),
                  ),

                // Bottom safe spacer so content is never covered by the sticky bar
                const SliverToBoxAdapter(
                  child: SizedBox(height: 110),
                ),
              ],
            ),

          // ── Sticky Top Floating Bar (Back, Title, Share, Cart) ──
          _buildFloatingTopBar(isDark),

          // ── Shopee-Style Sticky Bottom Bar (Mobile only; Desktop uses inline action bar) ──
          // [Chat 1/4] [Cart 1/4] [Buy Now 1/2]
          if (!isDesktop)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildStickyBottomActionBar(isDark, textPrimary),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopShopeeBody({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final topInset = MediaQuery.of(context).padding.top + 68.0;
    final images = _product.galleryImages;
    final hasVideo = _product.videoUrl.isNotEmpty;
    final totalSlides = (hasVideo ? 1 : 0) + images.length;

    return SingleChildScrollView(
      controller: _scrollCtrl,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24, topInset, 24, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top 2-Column Shopee Desktop Split: Left Full Gallery | Right Details & Buy ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT COLUMN: Full-bleed Product Image / Video Gallery + Thumbnails
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(
                          builder: (ctx, constraints) {
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.7),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(23),
                                child: _buildHeroImageSlider(
                                  isDark,
                                  availableWidth: constraints.maxWidth,
                                  isDesktopLayout: true,
                                ),
                              ),
                            );
                          },
                        ),
                        if (totalSlides > 1) ...[
                          const SizedBox(height: 12),
                          _buildDesktopThumbnailStrip(isDark, images, hasVideo),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 24),

                  // RIGHT COLUMN: Price, Vouchers, Variations, Quantity, Service Info & Action Buttons
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPriceAndHeaderCard(isDark, textPrimary, textSecondary),
                        if (_vouchers.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildVouchersRow(isDark, textPrimary, textSecondary),
                        ],
                        if (_product.variants.isNotEmpty || _product.modifiers.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildVariationsCard(isDark, textPrimary, textSecondary),
                        ],
                        const SizedBox(height: 12),
                        _buildQuantityAndNoteCard(isDark, textPrimary, textSecondary),
                        if (_product.isService) ...[
                          const SizedBox(height: 12),
                          _buildServiceInfoCard(isDark, textPrimary, textSecondary),
                        ],
                        const SizedBox(height: 16),
                        _buildStickyBottomActionBar(
                          isDark,
                          textPrimary,
                          isInlineDesktop: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Lower Full-Width Sections ──
              const SizedBox(height: 20),
              _buildShopProfileCard(isDark, textPrimary, textSecondary),
              const SizedBox(height: 14),
              _buildSpecCard(isDark, textPrimary, textSecondary),
              const SizedBox(height: 14),
              _buildDescriptionCard(isDark, textPrimary, textSecondary),
              const SizedBox(height: 14),
              _buildReviewsSection(isDark, textPrimary, textSecondary),
              if (_moreProducts.isNotEmpty) ...[
                const SizedBox(height: 18),
                _buildMoreProductsSection(isDark, textPrimary, textSecondary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopThumbnailStrip(
    bool isDark,
    List<String> images,
    bool hasVideo,
  ) {
    final totalSlides = (hasVideo ? 1 : 0) + images.length;
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: totalSlides,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, idx) {
          final bool isSelected = _currentImageIndex == idx;
          final bool isVideoThumb = hasVideo && idx == 0;
          final String thumbUrl = isVideoThumb
              ? (images.isNotEmpty ? images.first : '')
              : images[hasVideo ? idx - 1 : idx];

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                _imagePageCtrl.animateToPage(
                  idx,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF38BDF8)
                        : Colors.white.withValues(alpha: isDark ? 0.14 : 0.65),
                    width: isSelected ? 2.2 : 1.0,
                  ),
                  color: isDark ? const Color(0xFF161622) : Colors.white,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (thumbUrl.isNotEmpty)
                        Image.network(
                          thumbUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildFallbackHero(isDark),
                        )
                      else
                        Container(color: Colors.black87),
                      if (isVideoThumb)
                        Container(
                          color: Colors.black.withValues(alpha: 0.42),
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_filled_rounded,
                              color: Colors.white,
                              size: 28,
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
      ),
    );
  }

  // ── Hero Gallery Slider ────────────────────────────────────────

  double _activeHeroAspectRatio(List<String> images, bool hasVideo) {
    if (hasVideo && _currentImageIndex == 0) {
      final ctrl = _heroVideoCtrl;
      if (_heroVideoReady && ctrl != null && ctrl.value.aspectRatio > 0) {
        return ctrl.value.aspectRatio;
      }
      return 1.0;
    }
    if (images.isNotEmpty) {
      final imgIdx =
          (hasVideo ? _currentImageIndex - 1 : _currentImageIndex)
              .clamp(0, images.length - 1);
      final url = images[imgIdx];
      return _slideAspectRatios[url] ??
          NaturalImageAspectCache.get(url) ??
          1.0;
    }
    return 1.0;
  }

  Widget _buildHeroImageSlider(
    bool isDark, {
    double? availableWidth,
    bool isDesktopLayout = false,
  }) {
    final images = _product.galleryImages;
    final hasVideo = _product.videoUrl.isNotEmpty;
    final totalSlides = (hasVideo ? 1 : 0) + images.length;
    final mediaSize = MediaQuery.of(context).size;
    final screenW = availableWidth ?? mediaSize.width;
    final screenH = mediaSize.height;
    final double activeRatio =
        _activeHeroAspectRatio(images, hasVideo).clamp(0.42, 2.4);
    final double maxHeroH = isDesktopLayout
        ? (screenH * 0.72).clamp(440.0, 720.0)
        : (screenH * 0.85).clamp(420.0, 920.0);
    final double minHeroH = isDesktopLayout ? 340.0 : 220.0;
    final double sliderH = (screenW / activeRatio).clamp(minHeroH, maxHeroH);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: sliderH,
      width: double.infinity,
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Carousel (Video Slide 0 + Photo Slides)
          if (totalSlides > 0)
            PageView.builder(
              controller: _imagePageCtrl,
              itemCount: totalSlides,
              onPageChanged: (i) {
                setState(() => _currentImageIndex = i);
                if (hasVideo && _heroVideoCtrl != null && _heroVideoReady) {
                  if (i == 0) {
                    _heroVideoCtrl!.play();
                    setState(() => _heroVideoPlaying = true);
                  } else {
                    _heroVideoCtrl!.pause();
                    setState(() => _heroVideoPlaying = false);
                  }
                }
              },
              itemBuilder: (context, idx) {
                if (hasVideo && idx == 0) {
                  return _buildHeroVideoSlide(isDark);
                }
                final imgIdx = hasVideo ? idx - 1 : idx;
                return ValueListenableBuilder<int>(
                  valueListenable: NaturalImageAspectCache.resumeEpoch,
                  builder: (_, epoch, __) => Image.network(
                    images[imgIdx],
                    key: ValueKey('${images[imgIdx]}_$epoch'),
                    width: double.infinity,
                    height: double.infinity,
                    cacheWidth: 1080,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => _buildFallbackHero(isDark),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                  ),
                );
              },
            )
          else
            _buildFallbackHero(isDark),

          // Bottom gradient overlay only on video slide so transparent product PNGs stay 100% clean
          if (hasVideo && _currentImageIndex == 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 80,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Shopee-style [ Video | Photos ] Switcher at Bottom-Left
          if (hasVideo && images.isNotEmpty)
            Positioned(
              left: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white24, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMediaModeChip(
                      icon: Icons.play_arrow_rounded,
                      label: 'product_detail.video_tab'.tr(),
                      selected: _currentImageIndex == 0,
                      onTap: () => _imagePageCtrl.animateToPage(
                        0,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    const SizedBox(width: 2),
                    _buildMediaModeChip(
                      icon: Icons.photo_library_outlined,
                      label: 'product_detail.photos_tab'.tr(),
                      selected: _currentImageIndex > 0,
                      onTap: () => _imagePageCtrl.animateToPage(
                        1,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Slide indicator pill: "1 / 4" + Mute toggle when on Video
          if (totalSlides > 1 || hasVideo)
            Positioned(
              right: 16,
              bottom: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasVideo && _currentImageIndex == 0 && _heroVideoReady) ...[
                    GestureDetector(
                      onTap: () {
                        final ctrl = _heroVideoCtrl;
                        if (ctrl == null) return;
                        final nextMute = !_heroVideoMuted;
                        ctrl.setVolume(nextMute ? 0.0 : 1.0);
                        setState(() => _heroVideoMuted = nextMute);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: Icon(
                          _heroVideoMuted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    if (totalSlides > 1) const SizedBox(width: 8),
                  ],
                  if (totalSlides > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Text(
                        '${_currentImageIndex + 1} / $totalSlides',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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

  Widget _buildMediaModeChip({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? Colors.black87 : Colors.white70,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black87 : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroVideoSlide(bool isDark) {
    final ctrl = _heroVideoCtrl;
    return GestureDetector(
      onTap: () {
        if (ctrl == null || !_heroVideoReady) return;
        setState(() {
          if (ctrl.value.isPlaying) {
            ctrl.pause();
            _heroVideoPlaying = false;
          } else {
            ctrl.play();
            _heroVideoPlaying = true;
          }
        });
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_heroVideoReady && ctrl != null)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: ctrl.value.size.width > 0
                        ? ctrl.value.size.width
                        : 720,
                    height: ctrl.value.size.height > 0
                        ? ctrl.value.size.height
                        : 720,
                    child: VideoPlayer(ctrl),
                  ),
                ),
              )
            else if (_heroVideoError)
              _buildFallbackHero(isDark)
            else
              const Center(
                child: CircularProgressIndicator(
                    color: Colors.white70, strokeWidth: 2.2),
              ),
            if (_heroVideoReady && !_heroVideoPlaying)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white30),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackHero(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF161622) : const Color(0xFFE2E8F0),
      child: Center(
        child: HugeIcon(
          icon: _product.isService
              ? HugeIcons.strokeRoundedCalendar03
              : HugeIcons.strokeRoundedShoppingCart02,
          color: isDark ? Colors.white24 : Colors.black26,
          size: 72,
        ),
      ),
    );
  }

  // ── Floating Top Bar (100% 1:1 Navbar glassmorphism + Compact + Smart Auto-Contrast) ──

  Widget _buildNavbarGlassShell({
    required bool isDark,
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return GlassContainer(
      useOwnLayer: true,
      quality: GlassQuality.standard,
      shape: const LiquidRoundedSuperellipse(borderRadius: 50.0),
      settings: LiquidGlassSettings(
        thickness: 0.1,
        blur: 2.0,
        refractiveIndex: 1.0,
        glassColor: Colors.transparent,
        lightAngle: 45.0,
        lightIntensity: isDark ? 0.1 : 0.2,
        ambientStrength: 1.0,
        saturation: 1.0,
        chromaticAberration: 0.0,
      ),
      child: Container(
        height: 42.0,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: Colors.white.withValues(
              alpha: isDark ? 0.15 : 0.4,
            ),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark ? 0.2 : 0.05,
              ),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildNavbarGlassIconTap({
    required bool useWhiteIcon,
    required dynamic icon,
    required VoidCallback onTap,
    double width = 36.0,
    Color? iconColor,
    Widget? badge,
  }) {
    final Color effectiveColor = iconColor ??
        (useWhiteIcon ? Colors.white.withValues(alpha: 0.94) : const Color(0xFF1E293B));
    Widget iconWidget = Center(
      child: HugeIcon(
        icon: icon,
        size: 19,
        color: effectiveColor,
      ),
    );
    if (badge != null) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          iconWidget,
          Positioned(top: 4, right: 2, child: badge),
        ],
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        splashColor: useWhiteIcon ? Colors.white12 : Colors.black12,
        highlightColor: useWhiteIcon ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        child: SizedBox(
          width: width,
          height: 42.0,
          child: iconWidget,
        ),
      ),
    );
  }

  Widget _buildFloatingTopBar(bool isDark) {
    final topPadding = MediaQuery.of(context).padding.top;

    // Resolve adaptive icon contrast independently for top-left (Back) & top-right (Share/Like/Cart)
    bool leftUseWhite = isDark;
    bool rightUseWhite = isDark;
    if (!_isScrolledPastHero) {
      final hasVideo = _product.videoUrl.isNotEmpty;
      final images = _product.galleryImages;
      if (hasVideo && _currentImageIndex == 0) {
        leftUseWhite = true;
        rightUseWhite = true;
      } else {
        final imgIdx = hasVideo ? _currentImageIndex - 1 : _currentImageIndex;
        if (imgIdx >= 0 && imgIdx < images.length) {
          final activeUrl = images[imgIdx];
          final cacheKey = '${activeUrl.trim()}_$isDark';
          final contrast = _slideTopContrast[cacheKey];
          if (contrast != null) {
            leftUseWhite = contrast.leftDark;
            rightUseWhite = contrast.rightDark;
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _analyzeSlideTopContrast(activeUrl, isDark);
            });
          }
        }
      }
    }

    return Positioned(
      top: topPadding + 12.0,
      left: 16.0,
      right: 16.0,
      child: ValueListenableBuilder<List<CartItem>>(
        valueListenable: StoreCartService.notifierForShop(_shopId),
        builder: (context, cartItems, _) {
          final int cartCount =
              cartItems.fold(0, (sum, item) => sum + item.quantity);
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back Button (1:1 Navbar Glassmorphism + Auto-Contrast)
              _buildNavbarGlassShell(
                isDark: isDark,
                child: _buildNavbarGlassIconTap(
                  useWhiteIcon: leftUseWhite,
                  width: 42.0,
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              // Compact Share + Like + Cart Pill (1:1 Navbar Glassmorphism + Auto-Contrast)
              _buildNavbarGlassShell(
                isDark: isDark,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNavbarGlassIconTap(
                      useWhiteIcon: rightUseWhite,
                      width: 36.0,
                      icon: HugeIcons.strokeRoundedShare01,
                      onTap: _shareProduct,
                    ),
                    _buildNavbarGlassIconTap(
                      useWhiteIcon: rightUseWhite,
                      width: 36.0,
                      icon: HugeIcons.strokeRoundedFavourite,
                      iconColor: _isSaved ? const Color(0xFFEF4444) : null,
                      onTap: _toggleSave,
                    ),
                    _buildNavbarGlassIconTap(
                      useWhiteIcon: rightUseWhite,
                      width: 36.0,
                      icon: HugeIcons.strokeRoundedShoppingCart02,
                      badge: cartCount > 0
                          ? Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '$cartCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : null,
                      onTap: () {
                        final user = Supabase.instance.client.auth.currentUser;
                        if (user == null) {
                          showGlassToast(
                            context,
                            'auth.sign_in_required'.tr(),
                            isError: true,
                          );
                          Navigator.pushNamed(context, '/login');
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StoreCartView(
                              shop: {
                                ...widget.shop,
                                if (_shopDetails != null) ..._shopDetails!,
                                'name': _shopName,
                                'business_name': _shopName,
                              },
                              cartItems: cartItems,
                              tableNumber: widget.tableNumber,
                              promoCode: widget.promoCode,
                              onUpdateQuantity: (product, delta) =>
                                  StoreCartService.updateQuantity(
                                      _shopId, product, delta),
                              onClearCart: () =>
                                  StoreCartService.clearShop(_shopId),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Price & Header Card ────────────────────────────────────────

  Widget _buildPriceAndHeaderCard(bool isDark, Color textPrimary, Color textSecondary) {
    return _liquidCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price (Shopee-style live range narrowed by selected tier, exact once fully selected)
          Builder(
            builder: (_) {
              final (showRange, priceValueText) = _activePriceDisplay;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'RM',
                            style: TextStyle(
                              color: Color(0xFF3B82F6),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            priceValueText,
                            style: TextStyle(
                              color: const Color(0xFF3B82F6),
                              fontSize: showRange ? 23 : 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_product.hasDiscount && !showRange) ...[
                    const SizedBox(width: 8),
                    Text(
                      'RM ${_product.compareAtPrice!.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'product_detail.off_badge'.tr(args: [_product.discountPercent.toString()]),
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          // Badges: SERVICE / PRODUCT, HALAL, FEATURED, STOCK
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildBadge(
                label: _product.isService
                    ? 'product_detail.service_badge'.tr()
                    : 'product_detail.product_badge'.tr(),
                color: _product.isService ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6),
              ),
              if (_product.isHalal)
                _buildBadge(
                  label: 'product_detail.halal_badge'.tr(),
                  color: const Color(0xFF10B981),
                ),
              if (_product.isFeatured)
                _buildBadge(
                  label: 'product_detail.featured_badge'.tr(),
                  color: const Color(0xFFF59E0B),
                ),
              if (_isActiveOutOfStock)
                _buildBadge(
                  label: 'product_detail.out_of_stock'.tr(),
                  color: const Color(0xFFEF4444),
                )
              else if (_isActiveLowStock)
                _buildBadge(
                  label: 'product_detail.low_stock'.tr(args: [_activeStock.toString()]),
                  color: const Color(0xFFF97316),
                )
              else if (_product.isProduct && _product.trackInventory && _activeStock > 0)
                _buildBadge(
                  label: 'product_detail.stock_available'.tr(args: [_activeStock.toString()]),
                  color: const Color(0xFF10B981),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            _product.name,
            style: TextStyle(
              color: textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),

          // Social Proof Row: Rating, Reviews, Sold Count
          Row(
            children: [
              // Rating
              const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 3),
              Text(
                (_product.rating ?? 5.0).toStringAsFixed(1),
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 12, color: isDark ? Colors.white24 : Colors.black12),
              const SizedBox(width: 8),

              // Reviews Count
              GestureDetector(
                onTap: _openAllReviews,
                child: Text(
                  'product_detail.reviews_summary'.tr(
                    args: [
                      (_product.rating ?? 5.0).toStringAsFixed(1),
                      _comments.length.toString(),
                    ],
                  ),
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12.5,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 12, color: isDark ? Colors.white24 : Colors.black12),
              const SizedBox(width: 8),

              // Sold / Booked Count
              Text(
                'product_detail.sold_count'.tr(args: [(_product.soldCount > 0 ? _product.soldCount : 18).toString()]),
                style: TextStyle(color: textSecondary, fontSize: 12.5),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
          const SizedBox(height: 12),

          // Guarantees Row: Verified Merchant, Protected Checkout
          Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedShield01,
                color: Color(0xFF10B981),
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'product_detail.guarantee_verified'.tr(),
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                color: Color(0xFF3B82F6),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'product_detail.guarantee_instant'.tr(),
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── Shop Vouchers Row ──────────────────────────────────────────

  Widget _buildVouchersRow(bool isDark, Color textPrimary, Color textSecondary) {
    return _liquidCard(
      isDark: isDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedTicket02,
            color: Color(0xFFF59E0B),
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            'product_detail.vouchers_title'.tr(),
            style: TextStyle(
              color: textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _vouchers.map((v) {
                  final code = (v['code'] ?? 'PROMO').toString();
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      code,
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
        ],
      ),
    );
  }

  // ── Variations / Options Picker (Shopee 1-Tier & 2-Tier) ───────

  Widget _buildVariantChip({
    required String label,
    String? priceTag,
    String? imageUrl,
    required bool isSelected,
    required bool isDisabled,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback? onTap,
    double minWidth = 0,
  }) {
    final hasThumb = imageUrl != null && imageUrl.trim().isNotEmpty;
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: minWidth > 0 ? BoxConstraints(minWidth: minWidth) : null,
        padding: EdgeInsets.fromLTRB(
          hasThumb ? 6 : 13,
          hasThumb ? 5 : 8,
          13,
          hasThumb ? 5 : 8,
        ),
        decoration: BoxDecoration(
          color: isDisabled
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : Colors.black.withValues(alpha: 0.02))
              : isSelected
                  ? const Color(0xFF3B82F6).withValues(alpha: 0.16)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.035)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDisabled
                ? (isDark ? Colors.white10 : Colors.black12)
                : isSelected
                    ? const Color(0xFF3B82F6)
                    : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hasThumb) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Opacity(
                  opacity: isDisabled ? 0.4 : 1.0,
                  child: Image.network(
                    imageUrl,
                    width: 26,
                    height: 26,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDisabled
                      ? textSecondary.withValues(alpha: 0.4)
                      : (isSelected ? const Color(0xFF3B82F6) : textPrimary),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
            if (priceTag != null && priceTag.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                priceTag,
                style: TextStyle(
                  color: isDisabled
                      ? textSecondary.withValues(alpha: 0.35)
                      : (isSelected ? const Color(0xFF3B82F6) : textSecondary),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVariantSelectors({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required int selectedVariantIndex,
    required String? selectedTier1,
    required String? selectedTier2,
    required void Function(int idx) onSelectSingle,
    required void Function(String? t1) onSelectTier1,
    required void Function(String? t2) onSelectTier2,
  }) {
    if (_product.variants.isEmpty) return const SizedBox.shrink();

    if (_isTwoTier) {
      final t1Title = _product.tier1Label.isNotEmpty
          ? _product.tier1Label
          : 'product_detail.tier1_default_label'.tr();
      final t2Title = _product.tier2Label.isNotEmpty
          ? _product.tier2Label
          : 'product_detail.tier2_default_label'.tr();
      final t1Values = _product.tier1Values;
      final t2Values = _product.tier2Values;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tier 1 (e.g. Color)
          Row(
            children: [
              Text(
                '$t1Title:',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  selectedTier1 ?? 'product_detail.select_tier_hint'.tr(args: [t1Title]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selectedTier1 != null
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFFF59E0B),
                    fontSize: 13,
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
            children: t1Values.map((val) {
              final isSelected = selectedTier1 == val;
              final available = _product.isTierOptionAvailable(
                tier1: val,
                tier2: selectedTier2,
              );
              final thumb = _product.tier1ImageUrl(val);
              return _buildVariantChip(
                label: val,
                imageUrl: thumb,
                isSelected: isSelected,
                isDisabled: !available,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () => onSelectTier1(isSelected ? null : val),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Tier 2 (e.g. Size)
          Row(
            children: [
              Text(
                '$t2Title:',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  selectedTier2 ?? 'product_detail.select_tier_hint'.tr(args: [t2Title]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selectedTier2 != null
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFFF59E0B),
                    fontSize: 13,
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
            children: t2Values.map((val) {
              final isSelected = selectedTier2 == val;
              final available = _product.isTierOptionAvailable(
                tier1: selectedTier1,
                tier2: val,
              );
              return _buildVariantChip(
                label: val,
                minWidth: 56,
                isSelected: isSelected,
                isDisabled: !available,
                isDark: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () => onSelectTier2(isSelected ? null : val),
              );
            }).toList(),
          ),
        ],
      );
    }

    // 1-Tier Variants (e.g. 400g / 2kg / 4kg / 10kg)
    final selectedName = (selectedVariantIndex >= 0 &&
            selectedVariantIndex < _product.variants.length)
        ? (_product.variants[selectedVariantIndex]['name'] ?? '').toString()
        : null;
    final headerTitle = _product.tier1Label.isNotEmpty
        ? _product.tier1Label
        : 'product_detail.variations_title'.tr();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                headerTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (selectedName != null && selectedName.isNotEmpty)
              Flexible(
                child: Text(
                  selectedName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF3B82F6),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              Text(
                'product_detail.please_select_variation'.tr(),
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_product.variants.length, (idx) {
            final v = _product.variants[idx];
            final name = (v['name'] ?? '').toString();
            final effectivePrice = _product.variantEffectivePrice(v);
            final vStock = _product.variantStock(v);
            final vOutOfStock = _product.isProduct &&
                _product.trackInventory &&
                vStock != null &&
                vStock <= 0;
            final isSelected = selectedVariantIndex == idx;
            return _buildVariantChip(
              label: name,
              priceTag: effectivePrice > 0 ? 'RM ${effectivePrice.toStringAsFixed(2)}' : null,
              imageUrl: _product.variantImageUrl(v),
              isSelected: isSelected,
              isDisabled: vOutOfStock,
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onTap: () => onSelectSingle(isSelected ? -1 : idx),
            );
          }),
        ),
      ],
    );
  }

  Future<void> _showVariationBottomSheet({required bool buyNow}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);

    int tempIdx = _selectedVariantIndex;
    String? tempT1 = _selectedTier1;
    String? tempT2 = _selectedTier2;
    int tempQty = _quantity;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final Map<String, dynamic>? currentVariant = _isTwoTier
                ? _product.findTwoTierVariant(tempT1, tempT2)
                : (tempIdx >= 0 && tempIdx < _product.variants.length
                    ? _product.variants[tempIdx]
                    : null);
            final bool isComplete = currentVariant != null;
            final subset = _isTwoTier
                ? _product.matchingVariants(tier1: tempT1, tier2: tempT2)
                : _product.variants;

            final String priceLabel = currentVariant != null
                ? 'RM ${(_product.variantEffectivePrice(currentVariant) + _selectedModifiersExtraPrice).toStringAsFixed(2)}'
                : _product.formattedRangeForVariants(
                    subset,
                    extraPrice: _selectedModifiersExtraPrice,
                  );

            final int displayStock = currentVariant != null
                ? (_product.variantStock(currentVariant) ?? _product.stock)
                : (_isTwoTier && (tempT1 != null || tempT2 != null)
                    ? _product.totalStockForVariants(subset)
                    : _product.effectiveTotalStock);
            final bool isOut = _product.isProduct && _product.trackInventory && displayStock <= 0;

            String thumbUrl = _product.imageUrl;
            if (currentVariant != null) {
              thumbUrl = _product.variantImageUrl(currentVariant) ?? thumbUrl;
            } else if (_isTwoTier && tempT1 != null) {
              thumbUrl = _product.tier1ImageUrl(tempT1!) ?? thumbUrl;
            }

            final int maxQty = (_product.isProduct && _product.trackInventory)
                ? displayStock.clamp(0, 999)
                : 99;
            if (maxQty > 0 && tempQty > maxQty) tempQty = maxQty;
            if (tempQty < 1) tempQty = 1;

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.84,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF161622).withValues(alpha: 0.94)
                          : Colors.white.withValues(alpha: 0.96),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                      border: Border(
                        top: BorderSide(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Drag handle
                          Center(
                            child: Container(
                              margin: const EdgeInsets.only(top: 10, bottom: 6),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white24 : Colors.black12,
                                borderRadius: BorderRadius.circular(100),
                              ),
                            ),
                          ),
                          // Header: Thumbnail + Live Price + Live Stock + Close
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 12, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: thumbUrl.isNotEmpty
                                      ? Image.network(
                                          thumbUrl,
                                          width: 84,
                                          height: 84,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 84,
                                            height: 84,
                                            color: isDark ? Colors.white10 : Colors.black12,
                                            child: const Icon(Icons.image_not_supported_outlined),
                                          ),
                                        )
                                      : Container(
                                          width: 84,
                                          height: 84,
                                          color: isDark ? Colors.white10 : Colors.black12,
                                          child: const Icon(Icons.inventory_2_outlined),
                                        ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 6),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          priceLabel,
                                          maxLines: 1,
                                          style: const TextStyle(
                                            color: Color(0xFF3B82F6),
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      if (_product.isProduct && _product.trackInventory)
                                        Text(
                                          isOut
                                              ? 'product_detail.out_of_stock'.tr()
                                              : 'product_detail.stock_label'
                                                  .tr(args: ['$displayStock']),
                                          style: TextStyle(
                                            color: isOut ? Colors.redAccent : textSecondary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      if (currentVariant != null) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          (currentVariant['name'] ?? '').toString(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(sheetCtx),
                                  icon: Icon(Icons.close_rounded, color: textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                          // Scrollable Variation Selectors + Quantity
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildVariantSelectors(
                                    isDark: isDark,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary,
                                    selectedVariantIndex: tempIdx,
                                    selectedTier1: tempT1,
                                    selectedTier2: tempT2,
                                    onSelectSingle: (idx) => setSheetState(() => tempIdx = idx),
                                    onSelectTier1: (t1) => setSheetState(() => tempT1 = t1),
                                    onSelectTier2: (t2) => setSheetState(() => tempT2 = t2),
                                  ),
                                  const SizedBox(height: 18),
                                  Divider(
                                    height: 1,
                                    color: isDark ? Colors.white10 : Colors.black12,
                                  ),
                                  const SizedBox(height: 14),
                                  // Quantity Row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'product_detail.quantity_label'.tr(),
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.06)
                                              : Colors.black.withValues(alpha: 0.04),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isDark ? Colors.white12 : Colors.black12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            HoldRepeatButton(
                                              enabled: tempQty > 1,
                                              onStep: () => setSheetState(() {
                                                if (tempQty > 1) tempQty--;
                                              }),
                                              child: SizedBox(
                                                width: 34,
                                                height: 34,
                                                child: Center(
                                                  child: Icon(
                                                    Icons.remove_rounded,
                                                    size: 16,
                                                    color: tempQty > 1
                                                        ? textPrimary
                                                        : textSecondary.withValues(alpha: 0.35),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10),
                                              child: Text(
                                                '$tempQty',
                                                style: TextStyle(
                                                  color: textPrimary,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            HoldRepeatButton(
                                              enabled: tempQty < maxQty,
                                              onStep: () => setSheetState(() {
                                                if (tempQty < maxQty) tempQty++;
                                              }),
                                              onDisabledTap: () {
                                                if (_product.isProduct && _product.trackInventory) {
                                                  showGlassToast(
                                                    context,
                                                    'product_detail.max_stock_reached'
                                                        .tr(args: ['$displayStock']),
                                                    isError: true,
                                                  );
                                                }
                                              },
                                              child: SizedBox(
                                                width: 34,
                                                height: 34,
                                                child: Center(
                                                  child: Icon(
                                                    Icons.add_rounded,
                                                    size: 16,
                                                    color: tempQty < maxQty
                                                        ? textPrimary
                                                        : textSecondary.withValues(alpha: 0.35),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Bottom CTA Button
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                            child: SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: (isComplete && !isOut)
                                    ? () {
                                        setState(() {
                                          _selectedVariantIndex = tempIdx;
                                          _selectedTier1 = tempT1;
                                          _selectedTier2 = tempT2;
                                          _quantity = tempQty;
                                        });
                                        Navigator.pop(sheetCtx);
                                        if (buyNow) {
                                          _onBuyNowPressed();
                                        } else {
                                          _onAddToCartPressed();
                                        }
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  disabledBackgroundColor: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.08),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  buyNow
                                      ? 'product_detail.buy_now'.tr()
                                      : 'product_detail.add_to_cart'.tr(),
                                  style: TextStyle(
                                    color: (isComplete && !isOut)
                                        ? Colors.white
                                        : textSecondary.withValues(alpha: 0.5),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
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
            );
          },
        );
      },
    );
  }

  Widget _buildVariationsCard(bool isDark, Color textPrimary, Color textSecondary) {
    return _liquidCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_product.variants.isNotEmpty)
            _buildVariantSelectors(
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              selectedVariantIndex: _selectedVariantIndex,
              selectedTier1: _selectedTier1,
              selectedTier2: _selectedTier2,
              onSelectSingle: (idx) => setState(() {
                _selectedVariantIndex = idx;
                if (_product.isProduct &&
                    _product.trackInventory &&
                    _activeStock > 0 &&
                    _quantity > _activeStock) {
                  _quantity = _activeStock;
                }
              }),
              onSelectTier1: (t1) => setState(() {
                _selectedTier1 = t1;
                if (_product.isProduct &&
                    _product.trackInventory &&
                    _activeStock > 0 &&
                    _quantity > _activeStock) {
                  _quantity = _activeStock;
                }
              }),
              onSelectTier2: (t2) => setState(() {
                _selectedTier2 = t2;
                if (_product.isProduct &&
                    _product.trackInventory &&
                    _activeStock > 0 &&
                    _quantity > _activeStock) {
                  _quantity = _activeStock;
                }
              }),
            ),

          // 2. Modifiers (Multiple Selection: Topping / Add-on)
          if (_product.modifiers.isNotEmpty) ...[
            if (_product.variants.isNotEmpty) const SizedBox(height: 16),
            Text(
              'product_detail.addons_title'.tr(),
              style: TextStyle(
                color: textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_product.modifiers.length, (idx) {
                final m = _product.modifiers[idx];
                final name = (m['name'] ?? '').toString();
                final price = (m['price'] as num?)?.toDouble() ?? 0.0;
                final isSelected = _selectedModifierIndices.contains(idx);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedModifierIndices.remove(idx);
                      } else {
                        _selectedModifierIndices.add(idx);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF10B981)
                            : (isDark ? Colors.white12 : Colors.black12),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                          size: 14,
                          color: isSelected ? const Color(0xFF10B981) : textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          name,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF10B981) : textPrimary,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        if (price > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(+RM${price.toStringAsFixed(2)})',
                            style: TextStyle(
                              color: isSelected ? const Color(0xFF10B981) : textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  // ── Quantity & Special Note Card ───────────────────────────────

  Widget _buildQuantityAndNoteCard(bool isDark, Color textPrimary, Color textSecondary) {
    return _liquidCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'product_detail.quantity_title'.tr(),
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Plus Minus Counter
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: Row(
                  children: [
                    HoldRepeatButton(
                      enabled: _quantity > 1,
                      onStep: () => setState(() {
                        if (_quantity > 1) _quantity -= 1;
                      }),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.remove,
                          size: 18,
                          color: _quantity > 1
                              ? textPrimary
                              : textSecondary.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 32),
                      alignment: Alignment.center,
                      child: Text(
                        _quantity.toString(),
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Builder(
                      builder: (_) {
                        final bool canIncrease = _product.isService ||
                            !_product.trackInventory ||
                            _quantity < _activeStock;
                        return HoldRepeatButton(
                          enabled: canIncrease,
                          onStep: () => setState(() {
                            if (_product.isService ||
                                !_product.trackInventory ||
                                _quantity < _activeStock) {
                              _quantity += 1;
                            }
                          }),
                          onDisabledTap: () => showGlassToast(
                            context,
                            'product_detail.max_stock_reached'
                                .tr(args: ['$_activeStock']),
                            isError: true,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.add,
                              size: 18,
                              color: canIncrease
                                  ? textPrimary
                                  : textSecondary.withValues(alpha: 0.35),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Note Field
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            style: TextStyle(color: textPrimary, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'product_detail.note_label'.tr(),
              labelStyle: TextStyle(color: textSecondary, fontSize: 12),
              hintText: BusinessIndustryHelper.isFnb(
                industry: (_shopDetails?['business_industry'] ??
                        widget.shop['business_industry'])
                    ?.toString(),
                category: _shopCategory,
                shopName: _shopName,
              )
                  ? 'product_detail.note_hint'.tr()
                  : 'product_detail.note_hint_product'.tr(),
              hintStyle: TextStyle(
                color: isDark ? Colors.white30 : Colors.black26,
                fontSize: 12,
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF3B82F6)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Service Highlights Card ────────────────────────────────────

  Widget _buildServiceInfoCard(bool isDark, Color textPrimary, Color textSecondary) {
    String locText = 'product_detail.location_in_store'.tr();
    if (_product.serviceLocation == 'mobile_service') {
      locText = 'product_detail.location_mobile'.tr();
    } else if (_product.serviceLocation == 'online') {
      locText = 'product_detail.location_online'.tr();
    }

    return _liquidCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'product_detail.service_info_title'.tr(),
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: _openBookingFlow,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedCalendar03,
                        color: Color(0xFF8B5CF6),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'product_detail.book_slot_chip'.tr(),
                        style: const TextStyle(
                          color: Color(0xFF8B5CF6),
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Duration & Location Grid
          Row(
            children: [
              Expanded(
                child: _buildServiceHighlightItem(
                  icon: HugeIcons.strokeRoundedClock01,
                  color: const Color(0xFF3B82F6),
                  title: 'product_detail.duration_label'.tr(),
                  value: 'product_detail.duration_mins'.tr(args: [_product.durationMinutes.toString()]),
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildServiceHighlightItem(
                  icon: HugeIcons.strokeRoundedLocation01,
                  color: const Color(0xFF10B981),
                  title: 'product_detail.location_label'.tr(),
                  value: locText,
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildServiceHighlightItem(
                  icon: HugeIcons.strokeRoundedUserGroup,
                  color: const Color(0xFFF59E0B),
                  title: 'product_detail.max_pax_label'.tr(),
                  value: 'product_detail.pax_count'.tr(args: [_product.maxPax.toString()]),
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildServiceHighlightItem(
                  icon: HugeIcons.strokeRoundedCreditCard,
                  color: const Color(0xFFEC4899),
                  title: 'product_detail.deposit_label'.tr(),
                  value: _product.depositAmount > 0
                      ? 'RM ${_product.depositAmount.toStringAsFixed(2)}'
                      : 'product_detail.no_deposit'.tr(),
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceHighlightItem({
    required dynamic icon,
    required Color color,
    required String title,
    required String value,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(icon: icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Shop Profile Card ──────────────────────────────────────────

  Widget _buildShopProfileCard(bool isDark, Color textPrimary, Color textSecondary) {
    return _liquidCard(
      isDark: isDark,
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _shopLogo.isNotEmpty
                    ? Image.network(
                        _shopLogo,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildAvatarFallback(isDark),
                      )
                    : _buildAvatarFallback(isDark),
              ),
              const SizedBox(width: 12),

              // Name + Open Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isStoreOpen
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isStoreOpen
                              ? 'product_detail.store_open_now'.tr()
                              : 'product_detail.store_closed'.tr(),
                          style: TextStyle(
                            color: _isStoreOpen
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_moreProducts.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text('•', style: TextStyle(color: textSecondary)),
                          const SizedBox(width: 8),
                          Text(
                            'product_detail.store_products_count'.tr(args: [(_moreProducts.length + 1).toString()]),
                            style: TextStyle(color: textSecondary, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Visit Shop Outlined Button
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF3B82F6),
                  side: const BorderSide(color: Color(0xFF3B82F6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: _openStorefront,
                child: Text(
                  'product_detail.store_visit_btn'.tr(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(bool isDark) {
    return Container(
      width: 52,
      height: 52,
      color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
      child: const Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedStore01,
          color: Color(0xFF3B82F6),
          size: 24,
        ),
      ),
    );
  }

  // ── Specifications Card ────────────────────────────────────────

  Widget _buildSpecCard(bool isDark, Color textPrimary, Color textSecondary) {
    final specs = <MapEntry<String, String>>[];
    specs.add(MapEntry('product_detail.spec_type'.tr(), _product.isService ? 'product_detail.spec_type_service'.tr() : 'product_detail.spec_type_product'.tr()));
    if (_product.category.isNotEmpty) {
      specs.add(MapEntry('product_detail.spec_category'.tr(), _product.category));
    }
    if (_product.subCategory.isNotEmpty) {
      specs.add(MapEntry('product_detail.spec_subcategory'.tr(), _product.subCategory));
    }
    if (_product.unit.isNotEmpty && _product.isProduct) {
      specs.add(MapEntry('product_detail.spec_unit'.tr(), _product.unit));
    }
    if (_product.sku.isNotEmpty) {
      specs.add(MapEntry('product_detail.spec_sku'.tr(), _product.sku));
    }
    if (_product.isProduct && _product.trackInventory) {
      specs.add(MapEntry(
        'product_detail.in_stock'.tr(args: [_product.stock.toString()]),
        _product.stock.toString(),
      ));
    }

    return _liquidCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'product_detail.specs_title'.tr(),
            style: TextStyle(
              color: textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: specs.length,
            separatorBuilder: (_, __) => Divider(
              height: 14,
              color: isDark ? Colors.white12 : Colors.black12,
            ),
            itemBuilder: (_, idx) {
              final e = specs[idx];
              return Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      e.key,
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Description Card ───────────────────────────────────────────

  Widget _buildDescriptionCard(bool isDark, Color textPrimary, Color textSecondary) {
    final desc = _product.description.trim().isEmpty
        ? 'product_detail.description_empty'.tr()
        : _product.description.trim();

    return _liquidCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'product_detail.description_title'.tr(),
            style: TextStyle(
              color: textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            desc,
            maxLines: _isDescriptionExpanded ? null : 4,
            overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          if (desc.length > 180) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isDescriptionExpanded
                        ? 'product_detail.show_less'.tr()
                        : 'product_detail.read_more'.tr(),
                    style: const TextStyle(
                      color: Color(0xFF3B82F6),
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    _isDescriptionExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF3B82F6),
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Reviews & Comments Section ─────────────────────────────────

  Widget _buildReviewsSection(bool isDark, Color textPrimary, Color textSecondary) {
    final filtered = _filteredComments;

    return _liquidCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with "See All"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'product_detail.reviews_section_title'.tr(),
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: _openAllReviews,
                child: Row(
                  children: [
                    Text(
                      'product_detail.see_all_reviews'.tr(),
                      style: const TextStyle(
                        color: Color(0xFF3B82F6),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF3B82F6),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Review Filter Pills: All, With Photos, 5 Stars, 4 Stars
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildReviewFilterChip(0, 'product_detail.filter_all'.tr(), isDark),
                const SizedBox(width: 8),
                _buildReviewFilterChip(1, 'product_detail.filter_with_photos'.tr(), isDark),
                const SizedBox(width: 8),
                _buildReviewFilterChip(2, 'product_detail.filter_5_star'.tr(), isDark),
                const SizedBox(width: 8),
                _buildReviewFilterChip(3, 'product_detail.filter_4_star'.tr(), isDark),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Write Comment Button Row
          GestureDetector(
            onTap: () => _openWriteCommentSheet(isDark),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: Row(
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedComment01,
                    color: Color(0xFF3B82F6),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'product_detail.write_review_title'.tr(),
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  Icon(Icons.edit_outlined, size: 16, color: textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Comments List
          if (_isLoadingComments)
            Shimmer.fromColors(
              baseColor: isDark ? Colors.white12 : Colors.black12,
              highlightColor: isDark ? Colors.white24 : Colors.black26,
              child: Column(
                children: List.generate(2, (_) => Container(
                  height: 60,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                )),
              ),
            )
          else if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedComment01,
                      color: isDark ? Colors.white24 : Colors.black26,
                      size: 38,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'product_detail.empty_comments_title'.tr(),
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'product_detail.empty_comments_sub'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.take(3).length,
              separatorBuilder: (_, __) => Divider(
                height: 20,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              itemBuilder: (_, idx) => _buildCommentItem(
                filtered[idx],
                isDark,
                textPrimary,
                textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewFilterChip(int index, String label, bool isDark) {
    final isSelected = _activeReviewFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _activeReviewFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6)
                : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCommentItem(
    Map<String, dynamic> c,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final name = (c['name'] ?? 'Pelanggan').toString();
    final avatar = (c['avatar'] ?? '').toString();
    final rating = (c['rating'] as num?)?.toInt() ?? 5;
    final comment = (c['comment'] ?? '').toString();
    final date = (c['date'] ?? '').toString();
    final variant = (c['variant'] ?? '').toString();
    final dynamic rawImgs = c['images'];
    final List<String> imgs = [];
    if (rawImgs is List) {
      for (final i in rawImgs) {
        if (i != null && i.toString().isNotEmpty) imgs.add(i.toString());
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: avatar.isNotEmpty
                  ? Image.network(
                      avatar,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildAvatarFallback(isDark),
                    )
                  : _buildAvatarFallback(isDark),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Row(
                        children: List.generate(5, (starIdx) {
                          return Icon(
                            starIdx < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 13,
                            color: Colors.amber,
                          );
                        }),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        date,
                        style: TextStyle(color: textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (variant.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'product_detail.variant_bought_prefix'.tr(args: [variant]),
            style: TextStyle(color: textSecondary, fontSize: 11.5),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          comment,
          style: TextStyle(
            color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        if (imgs.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imgs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, imgIdx) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    imgs[imgIdx],
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // ── "More From This Shop" Carousel ─────────────────────────────

  Widget _buildMoreProductsSection(bool isDark, Color textPrimary, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'product_detail.more_from_shop_title'.tr(),
          style: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _moreProducts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, idx) {
              final item = _moreProducts[idx];
              return GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(
                        product: item,
                        shop: widget.shop,
                        tableNumber: widget.tableNumber,
                        promoCode: widget.promoCode,
                        onAddToCart: widget.onAddToCart,
                        onBuyNow: widget.onBuyNow,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 136,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: item.imageUrl.isNotEmpty
                            ? Image.network(
                                item.imageUrl,
                                width: 136,
                                height: 105,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 136,
                                height: 105,
                                color: isDark ? Colors.white12 : Colors.black12,
                                child: const Center(
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedImage01,
                                    size: 24,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                item.formattedMinPrice,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Discover-Inspired Glassmorphic Sticky Bottom Bar ───────────
  // Product: [Chat 1/4] [Cart 1/4] [Buy Now 1/2]
  // Service: [Chat 1/3] [Book Now 2/3]

  BoxDecoration _glassActionDecoration(bool isDark) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.05),
              ]
            : [
                Colors.white.withValues(alpha: 0.80),
                Colors.white.withValues(alpha: 0.55),
              ],
      ),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.22)
            : Colors.black.withValues(alpha: 0.10),
        width: 1.1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  Widget _buildGlassSecondaryAction({
    required bool isDark,
    required dynamic icon,
    required String label,
    required Color accentColor,
    required VoidCallback onTap,
    bool horizontal = false,
  }) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          height: 50,
          decoration: _glassActionDecoration(isDark),
          child: Center(
            child: horizontal
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(icon: icon, color: accentColor, size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(icon: icon, color: accentColor, size: 18),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
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
  }

  Widget _buildStickyBottomActionBar(
    bool isDark,
    Color textPrimary, {
    bool isInlineDesktop = false,
  }) {
    final bottomPadding = isInlineDesktop ? 0.0 : MediaQuery.of(context).padding.bottom;
    final bool isService = _product.isService;
    final BorderRadius barRadius = isInlineDesktop
        ? BorderRadius.circular(22)
        : const BorderRadius.vertical(top: Radius.circular(24));

    return ClipRRect(
      borderRadius: barRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            14,
            12,
            14,
            bottomPadding > 0 ? bottomPadding + 4 : 12,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF161622).withValues(alpha: 0.78)
                : Colors.white.withValues(alpha: 0.84),
            borderRadius: barRadius,
            border: isInlineDesktop
                ? Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.72),
                    width: 1.0,
                  )
                : Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.14)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1.0,
                    ),
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
                blurRadius: 18,
                offset: isInlineDesktop ? const Offset(0, 6) : const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 1/4 (Product) or 1/3 (Service): Chat Kedai
              Expanded(
                flex: 2,
                child: _buildGlassSecondaryAction(
                  isDark: isDark,
                  icon: HugeIcons.strokeRoundedChatting01,
                  label: 'product_detail.bottom_chat'.tr(),
                  accentColor: const Color(0xFF38BDF8),
                  onTap: _openChat,
                  horizontal: isService,
                ),
              ),

              if (!isService) ...[
                const SizedBox(width: 8),
                // 1/4 (Product only): Add to Cart
                Expanded(
                  flex: 2,
                  child: _buildGlassSecondaryAction(
                    isDark: isDark,
                    icon: HugeIcons.strokeRoundedShoppingCart02,
                    label: 'product_detail.bottom_add_to_cart'.tr(),
                    accentColor: const Color(0xFFF59E0B),
                    onTap: _onAddToCartPressed,
                  ),
                ),
              ],

              const SizedBox(width: 10),

              // 1/2 (Product) or 2/3 (Service): Buy Now / Book Now
              Expanded(
                flex: 4,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _onBuyNowPressed,
                    child: Ink(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isService
                              ? const [Color(0xFF007AFF), Color(0xFF2563EB)]
                              : const [Color(0xFF007AFF), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF007AFF).withValues(alpha: 0.38),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(
                            icon: isService
                                ? HugeIcons.strokeRoundedCalendar03
                                : HugeIcons.strokeRoundedFlash,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isService
                                  ? 'product_detail.bottom_book_now'.tr()
                                  : 'product_detail.bottom_buy_now'.tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
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
}
