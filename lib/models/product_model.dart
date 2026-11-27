class ProductModel {
  final String id;
  final String shopId;
  final String name;
  final String description;
  final String category;
  final String subCategory;
  final double price;
  final double? compareAtPrice;
  final String imageUrl;
  final List<String> imageUrls;
  final String videoUrl;
  final int stock;
  final bool trackInventory;
  final int lowStockThreshold;
  final String unit;
  final double weightKg;
  final String sku;
  final String barcode;
  final bool isActive;
  final String itemType; // 'product' or 'service'
  final bool isFeatured;
  final bool isHalal;
  final List<String> tags;
  final List<Map<String, dynamic>> variants;
  final List<Map<String, dynamic>> modifiers;

  // Service-specific attributes
  final int durationMinutes;
  final int bufferMinutes;
  final double depositAmount;
  final String serviceLocation; // 'in_store', 'mobile_service', 'online'
  final int maxPax;

  // Optional engagement / social proof
  final int soldCount;
  final double? rating;
  final int reviewCount;

  ProductModel({
    required this.id,
    required this.shopId,
    required this.name,
    this.description = '',
    this.category = '',
    this.subCategory = '',
    required this.price,
    this.compareAtPrice,
    this.imageUrl = '',
    this.imageUrls = const [],
    this.videoUrl = '',
    this.stock = 0,
    this.trackInventory = true,
    this.lowStockThreshold = 5,
    this.unit = 'pcs',
    this.weightKg = 0.5,
    this.sku = '',
    this.barcode = '',
    this.isActive = true,
    this.itemType = 'product',
    this.isFeatured = false,
    this.isHalal = false,
    this.tags = const [],
    this.variants = const [],
    this.modifiers = const [],
    this.durationMinutes = 30,
    this.bufferMinutes = 0,
    this.depositAmount = 0.0,
    this.serviceLocation = 'in_store',
    this.maxPax = 1,
    this.soldCount = 0,
    this.rating,
    this.reviewCount = 0,
  });

  bool get isService => itemType.toLowerCase() == 'service';
  bool get isProduct => !isService;

  /// Exact selling price of a single variant (falls back to base `price` if variant price <= 0).
  double variantEffectivePrice(Map<String, dynamic> v) {
    final vp = (v['price'] as num?)?.toDouble() ??
        double.tryParse(v['price']?.toString() ?? '') ??
        0.0;
    return vp > 0 ? vp : price;
  }

  /// Per-variant stock if explicitly stored on the variant, else null.
  int? variantStock(Map<String, dynamic> v) {
    final raw = v['stock'];
    if (raw == null) return null;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  /// Per-variant shipping weight (kg): uses explicit `weight_kg`, else smart-parses
  /// common weight units from variant name (e.g. `400g` -> 0.4, `2kg` -> 2.0), else product `weightKg`.
  double variantWeightKg(Map<String, dynamic> v) {
    final raw = v['weight_kg'];
    final explicit = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
    if (explicit != null && explicit > 0) return explicit;
    final name = (v['name'] ?? '').toString().toLowerCase();
    final kgMatch = RegExp(r'(\d+(?:\.\d+)?)\s*kg\b').firstMatch(name);
    if (kgMatch != null) {
      final parsed = double.tryParse(kgMatch.group(1) ?? '');
      if (parsed != null && parsed > 0) return parsed;
    }
    final gMatch = RegExp(r'(\d+(?:\.\d+)?)\s*g(?:m|ram|rams)?\b').firstMatch(name);
    if (gMatch != null) {
      final parsed = double.tryParse(gMatch.group(1) ?? '');
      if (parsed != null && parsed > 0) return (parsed / 1000.0).clamp(0.05, 500.0);
    }
    return weightKg > 0 ? weightKg : 0.5;
  }

  bool get hasVariants => variants.isNotEmpty;

  double get minPrice {
    if (variants.isEmpty) return price;
    final prices = variants.map(variantEffectivePrice).where((p) => p > 0).toList();
    if (prices.isEmpty) return price;
    return prices.reduce((a, b) => a < b ? a : b);
  }

  double get maxPrice {
    if (variants.isEmpty) return price;
    final prices = variants.map(variantEffectivePrice).where((p) => p > 0).toList();
    if (prices.isEmpty) return price;
    return prices.reduce((a, b) => a > b ? a : b);
  }

  bool get hasPriceRange => variants.isNotEmpty && (maxPrice - minPrice).abs() >= 0.005;

  /// Shopee-style price string: `RM 17.90 - RM 280.80` when variants span a range, else `RM 17.90`.
  String get formattedPriceRange {
    if (hasPriceRange) {
      return 'RM ${minPrice.toStringAsFixed(2)} - RM ${maxPrice.toStringAsFixed(2)}';
    }
    return 'RM ${minPrice.toStringAsFixed(2)}';
  }

  /// True if at least one variant defines its own per-variant stock count.
  bool get hasVariantStock => variants.any((v) => variantStock(v) != null);

  /// Combined stock across variants (if per-variant stock is tracked), else product `stock`.
  int get effectiveTotalStock {
    if (variants.isNotEmpty && hasVariantStock) {
      return variants.fold<int>(0, (sum, v) => sum + ((variantStock(v) ?? 0).clamp(0, 999999)));
    }
    return stock;
  }

  bool get hasDiscount => compareAtPrice != null && compareAtPrice! > minPrice && minPrice > 0;
  int get discountPercent =>
      hasDiscount ? (((compareAtPrice! - minPrice) / compareAtPrice!) * 100).round().clamp(1, 99) : 0;
  bool get isLowStock =>
      isProduct && trackInventory && effectiveTotalStock > 0 && effectiveTotalStock <= lowStockThreshold;
  bool get isOutOfStock => isProduct && trackInventory && effectiveTotalStock <= 0;

  ProductModel copyWith({
    double? price,
    double? weightKg,
    int? stock,
  }) {
    return ProductModel(
      id: id,
      shopId: shopId,
      name: name,
      description: description,
      category: category,
      subCategory: subCategory,
      price: price ?? this.price,
      compareAtPrice: compareAtPrice,
      imageUrl: imageUrl,
      imageUrls: imageUrls,
      videoUrl: videoUrl,
      stock: stock ?? this.stock,
      trackInventory: trackInventory,
      lowStockThreshold: lowStockThreshold,
      unit: unit,
      weightKg: weightKg ?? this.weightKg,
      sku: sku,
      barcode: barcode,
      isActive: isActive,
      itemType: itemType,
      isFeatured: isFeatured,
      isHalal: isHalal,
      tags: tags,
      variants: variants,
      modifiers: modifiers,
      durationMinutes: durationMinutes,
      bufferMinutes: bufferMinutes,
      depositAmount: depositAmount,
      serviceLocation: serviceLocation,
      maxPax: maxPax,
      soldCount: soldCount,
      rating: rating,
      reviewCount: reviewCount,
    );
  }

  List<String> get galleryImages {
    final out = <String>[];
    if (imageUrl.trim().isNotEmpty) out.add(imageUrl.trim());
    for (final u in imageUrls) {
      final clean = u.trim();
      if (clean.isNotEmpty && !out.contains(clean)) {
        out.add(clean);
      }
    }
    return out;
  }

  static List<String> _parseImageList(Map<String, dynamic> json) {
    final result = <String>[];
    final primary = json['image_url']?.toString().trim() ?? '';
    if (primary.isNotEmpty) result.add(primary);

    for (final key in ['image_urls', 'images', 'gallery', 'media_urls']) {
      final raw = json[key];
      if (raw is List) {
        for (final entry in raw) {
          final url = entry is Map
              ? (entry['url'] ?? entry['image_url'] ?? '').toString().trim()
              : entry.toString().trim();
          if (url.isNotEmpty && !result.contains(url)) {
            result.add(url);
          }
        }
      }
    }
    return result;
  }

  static List<Map<String, dynamic>> _parseMapList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final imgs = _parseImageList(json);
    return ProductModel(
      id: json['id']?.toString() ?? '',
      shopId: json['shop_id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      subCategory: json['sub_category'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      compareAtPrice: (json['compare_at_price'] as num?)?.toDouble(),
      imageUrl: imgs.isNotEmpty ? imgs.first : '',
      imageUrls: imgs,
      videoUrl: (json['video_url'] ?? '').toString().trim(),
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      trackInventory: json['track_inventory'] as bool? ?? true,
      lowStockThreshold: (json['low_stock_threshold'] as num?)?.toInt() ?? 5,
      unit: json['unit'] as String? ?? 'pcs',
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0.5,
      sku: json['sku'] as String? ?? '',
      barcode: json['barcode'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? (json['is_available'] as bool? ?? true),
      itemType: json['item_type'] as String? ?? 'product',
      isFeatured: json['is_featured'] as bool? ?? false,
      isHalal: json['is_halal'] as bool? ?? false,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      variants: _parseMapList(json['variants']),
      modifiers: _parseMapList(json['modifiers']),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 30,
      bufferMinutes: (json['buffer_minutes'] as num?)?.toInt() ?? 0,
      depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0.0,
      serviceLocation: json['service_location'] as String? ?? 'in_store',
      maxPax: (json['max_pax'] as num?)?.toInt() ?? 1,
      soldCount: (json['sold_count'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: (json['total_reviews'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'name': name,
      'description': description,
      'category': category,
      'sub_category': subCategory,
      'price': price,
      if (compareAtPrice != null) 'compare_at_price': compareAtPrice,
      'image_url': imageUrl,
      'image_urls': imageUrls,
      if (videoUrl.isNotEmpty) 'video_url': videoUrl,
      'stock': stock,
      'track_inventory': trackInventory,
      'low_stock_threshold': lowStockThreshold,
      'unit': unit,
      'weight_kg': weightKg,
      'sku': sku,
      'barcode': barcode,
      'is_active': isActive,
      'item_type': itemType,
      'is_featured': isFeatured,
      'is_halal': isHalal,
      'tags': tags,
      'variants': variants,
      'modifiers': modifiers,
      'duration_minutes': durationMinutes,
      'buffer_minutes': bufferMinutes,
      'deposit_amount': depositAmount,
      'service_location': serviceLocation,
      'max_pax': maxPax,
      'sold_count': soldCount,
      if (rating != null) 'rating': rating,
      'total_reviews': reviewCount,
    };
  }
}
