import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../screens/explore/store_cart_view.dart';

/// Shared reactive cart store keyed by shop ID so BusinessStoreView,
/// ProductDetailScreen, and StoreCartView stay in real-time sync.
class StoreCartService {
  StoreCartService._();

  static final Map<String, ValueNotifier<List<CartItem>>> _shopCarts = {};

  static String _keyFor(String shopId) =>
      shopId.trim().isEmpty ? '_default_shop' : shopId.trim();

  static ValueNotifier<List<CartItem>> notifierForShop(String shopId) {
    final key = _keyFor(shopId);
    return _shopCarts.putIfAbsent(key, () => ValueNotifier<List<CartItem>>([]));
  }

  static List<CartItem> itemsForShop(String shopId) {
    return notifierForShop(shopId).value;
  }

  static int countForShop(String shopId) {
    return itemsForShop(shopId).fold(0, (sum, item) => sum + item.quantity);
  }

  static void addItem(
    String shopId,
    ProductModel product, {
    int quantity = 1,
    String? selectedOption,
    String? itemNote,
    double optionExtraPrice = 0.0,
  }) {
    if (quantity <= 0) return;
    final notifier = notifierForShop(shopId);
    final updated = List<CartItem>.from(notifier.value);
    final index = updated.indexWhere((c) =>
        c.product.id == product.id &&
        (c.selectedOption ?? '') == (selectedOption ?? '') &&
        (c.itemNote ?? '') == (itemNote ?? ''));
    if (index >= 0) {
      updated[index].quantity += quantity;
    } else {
      updated.add(CartItem(
        product: product,
        quantity: quantity,
        selectedOption: selectedOption,
        itemNote: itemNote,
        optionExtraPrice: optionExtraPrice,
      ));
    }
    notifier.value = updated;
  }

  static void updateQuantity(
    String shopId,
    ProductModel product,
    int delta, {
    String? selectedOption,
    String? itemNote,
  }) {
    final notifier = notifierForShop(shopId);
    final updated = List<CartItem>.from(notifier.value);
    final index = (selectedOption != null || itemNote != null)
        ? updated.indexWhere((c) =>
            c.product.id == product.id &&
            (c.selectedOption ?? '') == (selectedOption ?? '') &&
            (c.itemNote ?? '') == (itemNote ?? ''))
        : updated.indexWhere((c) => c.product.id == product.id);
    if (index >= 0) {
      updated[index].quantity += delta;
      if (updated[index].quantity <= 0) {
        updated.removeAt(index);
      }
      notifier.value = updated;
    }
  }

  static void clearShop(String shopId) {
    notifierForShop(shopId).value = [];
  }
}
