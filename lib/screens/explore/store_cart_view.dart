import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:ngam/widgets/glass_box.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product_model.dart';
import '../../widgets/glass_toast.dart';

// ============================================================
// CartItem Model
// ============================================================
class CartItem {
  final ProductModel product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get totalPrice => product.price * quantity;
}

// ============================================================
// StoreCartView — Shopping Cart & Checkout Screen
// ============================================================
class StoreCartView extends StatefulWidget {
  final Map<String, dynamic> shop;
  final List<CartItem> cartItems;
  final bool isStoreOpen;
  final String? storeStatusText;
  final bool isHoliday;
  final Function(ProductModel product, int delta)? onUpdateQuantity;
  final VoidCallback? onClearCart;

  const StoreCartView({
    super.key,
    required this.shop,
    required this.cartItems,
    this.isStoreOpen = true,
    this.storeStatusText,
    this.isHoliday = false,
    this.onUpdateQuantity,
    this.onClearCart,
  });

  @override
  State<StoreCartView> createState() => _StoreCartViewState();
}

class _StoreCartViewState extends State<StoreCartView> {
  late List<CartItem> _items;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _voucherController = TextEditingController();
  int _orderTypeIndex = 0; // 0: Pickup / Dine-in, 1: Delivery
  bool _voucherApplied = false;
  double _discountAmount = 0.0;
  bool _isProcessing = false;
  bool _isPreOrder = false;

  final List<String> _orderTypes = ['Pickup / Dine-In', 'Delivery'];

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.cartItems);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  double get _subtotal =>
      _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get _deliveryFee =>
      (_orderTypeIndex == 1 && _items.isNotEmpty) ? 5.00 : 0.00;

  double get _total => (_subtotal + _deliveryFee - _discountAmount).clamp(0.0, 999999.0);

  void _applyVoucher() {
    final code = _voucherController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    if (code == 'NGAM10' || code == 'WELCOME') {
      setState(() {
        _voucherApplied = true;
        _discountAmount = (_subtotal * 0.10); // 10% off
      });
      showGlassToast(context, 'Promo applied! 10% discount.');
    } else {
      showGlassToast(context, 'Invalid promo code. Try "NGAM10"', isError: true);
    }
  }

  void _updateQuantity(CartItem item, int delta) {
    setState(() {
      item.quantity += delta;
      if (item.quantity <= 0) {
        _items.remove(item);
      }
      if (_voucherApplied) {
        _discountAmount = (_subtotal * 0.10);
      }
    });
    widget.onUpdateQuantity?.call(item.product, delta);
  }

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

  void _handleCheckout() async {
    if (_items.isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      showGlassToast(context, 'Please sign in or register to place your order.', isError: true);
      Navigator.pushNamed(context, '/login');
      return;
    }

    if (!widget.isStoreOpen && !_isPreOrder) {
      showGlassToast(context, 'Kedai sedang tutup. Sila aktifkan pilihan Pesanan Awal (Pre-Order) untuk teruskan.', isError: true);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final String customerName = (user.userMetadata?['full_name'] as String?) ??
          (user.userMetadata?['name'] as String?) ??
          (user.email?.split('@').first) ??
          'Customer';

      final orderData = {
        'business_id': widget.shop['id'],
        'owner_user_id': user.id,
        'customer_name': customerName,
        'total': _total,
        'status': 'pending',
        'source': _isPreOrder ? 'pre_order' : 'online',
        'notes': _isPreOrder
            ? ('[PRE-ORDER] ${_notesController.text.trim()}').trim()
            : _notesController.text.trim(),
      };

      final orderRes = await Supabase.instance.client
          .from('orders')
          .insert(orderData)
          .select('id')
          .single();

      final String orderId = orderRes['id'].toString();

      if (_items.isNotEmpty) {
        try {
          final itemsData = _items.map((item) => {
            'order_id': orderId,
            'product_id': item.product.id,
            'product_name': item.product.name,
            'quantity': item.quantity,
            'unit_price': item.product.price,
            'subtotal': item.totalPrice,
          }).toList();

          await Supabase.instance.client.from('order_items').insert(itemsData);
        } catch (itemErr) {
          debugPrint('Notice: order_items insert error (order #$orderId still created): $itemErr');
        }
      }

      if (!mounted) return;
      setState(() => _isProcessing = false);

      // Show Order Success Sheet
      final isDark = Theme.of(context).brightness == Brightness.dark;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2228) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: (_isPreOrder ? Colors.purpleAccent : Colors.green).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      _isPreOrder ? Icons.schedule_rounded : Icons.check_circle_rounded,
                      color: _isPreOrder ? Colors.purpleAccent : Colors.green,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _isPreOrder ? 'Pesanan Awal (Pre-Order) Diterima!' : 'Order Placed Successfully!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isPreOrder
                      ? 'Pesanan awal anda untuk ${widget.shop['name'] ?? 'kedai'} telah berjaya dihantar. Pihak peniaga akan menyediakan pesanan ini sebaik sahaja kedai dibuka.'
                      : 'Your order with ${widget.shop['name'] ?? 'the store'} has been received. You will be notified when it is ready.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPreOrder ? Colors.deepPurpleAccent : Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx); // Close modal
                      widget.onClearCart?.call();
                      Navigator.pop(context); // Return to store
                    },
                    child: const Text('Back to Store', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      showGlassToast(context, 'Failed to place order: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final Color textSecondary = isDark ? Colors.white60 : const Color(0xFF3A3A3C).withValues(alpha: 0.7);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
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
                            color: textPrimary,
                            size: 22,
                            strokeWidth: 2.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Cart',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.shop['name'] ?? 'Store',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_items.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() => _items.clear());
                        widget.onClearCart?.call();
                      },
                      child: _liquidGlassBox(
                        isDark: isDark,
                        radius: 100,
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────────────
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _liquidGlassBox(
                            isDark: isDark,
                            radius: 100,
                            padding: const EdgeInsets.all(24),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedShoppingBag01,
                              color: isDark ? Colors.white30 : Colors.black26,
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Your cart is empty',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add items from ${widget.shop['name'] ?? 'the store'} to get started.',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.storefront_rounded, size: 18),
                            label: const Text('Browse Products', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      children: [
                        if (!widget.isStoreOpen) ...[
                          _buildClosedStoreBanner(isDark, textPrimary, textSecondary),
                          const SizedBox(height: 16),
                        ],

                        // Order Type Selector
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: List.generate(_orderTypes.length, (idx) {
                              final isSelected = _orderTypeIndex == idx;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _orderTypeIndex = idx),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: isSelected
                                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]
                                          : [],
                                    ),
                                    child: Center(
                                      child: Text(
                                        _orderTypes[idx],
                                        style: TextStyle(
                                          color: isSelected ? textPrimary : textSecondary,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Item List
                        ..._items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _liquidGlassBox(
                                isDark: isDark,
                                radius: 18,
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        width: 64,
                                        height: 64,
                                        child: item.product.imageUrl.isNotEmpty
                                            ? Image.network(
                                                item.product.imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  color: Colors.blue.withValues(alpha: 0.1),
                                                  child: const Icon(Icons.shopping_bag_outlined, color: Colors.blue),
                                                ),
                                              )
                                            : Container(
                                                color: Colors.blue.withValues(alpha: 0.1),
                                                child: const Icon(Icons.shopping_bag_outlined, color: Colors.blue),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.product.name,
                                            style: TextStyle(
                                              color: textPrimary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'RM ${item.product.price.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.blue,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Stepper
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _updateQuantity(item, -1),
                                          child: Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Icon(Icons.remove, size: 16, color: textPrimary),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          child: Text(
                                            '${item.quantity}',
                                            style: TextStyle(
                                              color: textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => _updateQuantity(item, 1),
                                          child: Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Center(
                                              child: Icon(Icons.add, size: 16, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            )),

                        const SizedBox(height: 12),

                        // Special instructions textfield
                        _liquidGlassBox(
                          isDark: isDark,
                          radius: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: TextField(
                            controller: _notesController,
                            style: TextStyle(color: textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Add notes for store (e.g. less ice, door code)...',
                              hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                              border: InputBorder.none,
                              prefixIcon: Icon(Icons.edit_note_rounded, color: textSecondary, size: 20),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Voucher field
                        Row(
                          children: [
                            Expanded(
                              child: _liquidGlassBox(
                                isDark: isDark,
                                radius: 16,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                child: TextField(
                                  controller: _voucherController,
                                  textCapitalization: TextCapitalization.characters,
                                  style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    hintText: 'Promo Code (e.g. NGAM10)',
                                    hintStyle: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.normal),
                                    border: InputBorder.none,
                                    prefixIcon: Icon(Icons.local_offer_outlined, color: textSecondary, size: 18),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _voucherApplied ? Colors.green : Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              ),
                              onPressed: _applyVoucher,
                              child: Text(_voucherApplied ? 'Applied' : 'Apply', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Bill Summary
                        _liquidGlassBox(
                          isDark: isDark,
                          radius: 20,
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment Summary',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _summaryRow('Subtotal', 'RM ${_subtotal.toStringAsFixed(2)}', textSecondary, textPrimary),
                              if (_orderTypeIndex == 1) ...[
                                const SizedBox(height: 8),
                                _summaryRow('Delivery Fee', 'RM ${_deliveryFee.toStringAsFixed(2)}', textSecondary, textPrimary),
                              ],
                              if (_voucherApplied) ...[
                                const SizedBox(height: 8),
                                _summaryRow('Discount (10%)', '-RM ${_discountAmount.toStringAsFixed(2)}', Colors.green, Colors.green),
                              ],
                              Divider(color: isDark ? Colors.white12 : Colors.black12, height: 24),
                              _summaryRow(
                                'Total Amount',
                                'RM ${_total.toStringAsFixed(2)}',
                                textPrimary,
                                Colors.blue,
                                isBold: true,
                                fontSize: 18,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
            ),

            // ── Bottom Checkout Bar ─────────────────────────────────
            if (_items.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14171C) : Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -3)),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Total Price', style: TextStyle(color: textSecondary, fontSize: 11)),
                          Text(
                            'RM ${_total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !widget.isStoreOpen && !_isPreOrder
                                ? Colors.grey.shade700
                                : (_isPreOrder ? Colors.deepPurpleAccent : Colors.blue),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                          ),
                          onPressed: _isProcessing
                              ? null
                              : (!widget.isStoreOpen && !_isPreOrder
                                  ? () => showGlassToast(context, 'Kedai sedang tutup. Sila aktifkan pilihan Pesanan Awal (Pre-Order) di atas.', isError: true)
                                  : _handleCheckout),
                          child: _isProcessing
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text(
                                  !widget.isStoreOpen && !_isPreOrder
                                      ? 'Kedai Tutup · Aktifkan Pre-Order'
                                      : (_isPreOrder ? 'Hantar Pre-Order' : 'Checkout Now'),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildClosedStoreBanner(bool isDark, Color textPrimary, Color textSecondary) {
    return _liquidGlassBox(
      isDark: isDark,
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (widget.isHoliday ? Colors.purpleAccent : Colors.orangeAccent).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: widget.isHoliday ? HugeIcons.strokeRoundedCalendar03 : HugeIcons.strokeRoundedTime02,
                  color: widget.isHoliday ? Colors.purpleAccent : Colors.orangeAccent,
                  size: 20,
                  strokeWidth: 2.2,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isHoliday ? 'Kedai Sedang Bercuti' : 'Kedai Sedang Ditutup',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.storeStatusText ?? 'Di luar waktu operasi rasmi',
                      style: TextStyle(
                        color: widget.isHoliday ? Colors.purpleAccent : Colors.orangeAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.isHoliday
                ? 'Pihak kedai sedang cuti hari ini. Anda boleh membuat Pesanan Awal (Pre-Order) di bawah supaya kedai memproses pesanan sebaik sahaja dibuka semula.'
                : 'Kedai kini berada di luar waktu operasi. Anda boleh mengaktifkan mod Pesanan Awal (Pre-Order) untuk membolehkan kedai memproses pesanan sebaik sahaja dibuka.',
            style: TextStyle(color: textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isPreOrder
                    ? Colors.deepPurpleAccent.withValues(alpha: 0.5)
                    : (isDark ? Colors.white12 : Colors.black12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedCalendar02,
                      color: _isPreOrder ? Colors.deepPurpleAccent : textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilihan Pesanan Awal (Pre-Order)',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _isPreOrder ? 'Mod Pre-Order Aktif' : 'Tandakan untuk teruskan pesanan',
                          style: TextStyle(
                            color: _isPreOrder ? Colors.greenAccent : textSecondary,
                            fontSize: 11,
                            fontWeight: _isPreOrder ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: _isPreOrder,
                  activeColor: Colors.deepPurpleAccent,
                  onChanged: (val) {
                    setState(() => _isPreOrder = val);
                    if (val) {
                      showGlassToast(context, 'Mod Pre-Order diaktifkan! Anda boleh membuat pesanan sekarang.');
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color labelColor, Color valueColor, {bool isBold = false, double fontSize = 14}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
