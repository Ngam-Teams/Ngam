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
  bool get hasDiscount => compareAtPrice != null && compareAtPrice! > price;
  int get discountPercent =>
      hasDiscount ? (((compareAtPrice! - price) / compareAtPrice!) * 100).round().clamp(1, 99) : 0;
  bool get isLowStock => isProduct && trackInventory && stock > 0 && stock <= lowStockThreshold;
  bool get isOutOfStock => isProduct && trackInventory && stock <= 0;

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
