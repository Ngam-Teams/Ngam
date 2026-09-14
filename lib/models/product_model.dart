class ProductModel {
  final String id;
  final String shopId;
  final String name;
  final String description;
  final String category;
  final double price;
  final String imageUrl;
  final int stock;
  final bool isActive;

  ProductModel({
    required this.id,
    required this.shopId,
    required this.name,
    this.description = '',
    this.category = '',
    required this.price,
    this.imageUrl = '',
    this.stock = 0,
    this.isActive = true,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'] as String? ?? '',
      stock: json['stock'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_id': shopId,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'image_url': imageUrl,
      'stock': stock,
      'is_active': isActive,
    };
  }
}
