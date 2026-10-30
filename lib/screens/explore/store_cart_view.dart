import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:ngam/widgets/glass_box.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product_model.dart';
import '../../widgets/glass_toast.dart';
import '../../widgets/customer_payment_modal.dart';

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
  final String? tableNumber;
  final String? promoCode;
  final bool isStoreOpen;
  final String? storeStatusText;
  final bool isHoliday;
  final Function(ProductModel product, int delta)? onUpdateQuantity;
  final VoidCallback? onClearCart;

  const StoreCartView({
    super.key,
    required this.shop,
    required this.cartItems,
    this.tableNumber,
    this.promoCode,
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
  bool _isApplyingVoucher = false;
  double _discountAmount = 0.0;
  Map<String, dynamic>? _voucher;
  bool _isProcessing = false;
  bool _isPreOrder = false;

  /// Delivery is not offered yet (no address capture / rider flow), so only
  /// Pickup / Dine-In is available for the soft launch.
  static const bool _deliveryEnabled = false;
  final List<String> _orderTypes =
      _deliveryEnabled ? ['Pickup / Dine-In', 'Delivery'] : ['Pickup / Dine-In'];

  @override
  void initState() {
    super.initState();
    // Copy each CartItem: the view mutates quantities locally and reports the
    // delta to the parent via onUpdateQuantity (sharing instances double-counted).
    _items = widget.cartItems
        .map((c) => CartItem(product: c.product, quantity: c.quantity))
        .toList();
    if (widget.tableNumber != null && widget.tableNumber!.isNotEmpty) {
      _orderTypeIndex = 0; // Dine-in
    }
    if (widget.promoCode != null && widget.promoCode!.isNotEmpty) {
      _voucherController.text = widget.promoCode!;
      _applyVoucher();
    }
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

  String _escapeLike(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

  /// Base amount a voucher applies to (whole cart, or only specific products).
  double _voucherBase(Map<String, dynamic> v) {
    if ((v['applicable_scope'] ?? 'all') == 'specific_products') {
      final ids = (v['applicable_ids'] is List)
          ? (v['applicable_ids'] as List).map((e) => e.toString()).toSet()
          : <String>{};
      return _items
          .where((i) => ids.contains(i.product.id.toString()))
          .fold(0.0, (s, i) => s + i.totalPrice);
    }
    return _subtotal;
  }

  double _computeDiscount(Map<String, dynamic> v) {
    final base = _voucherBase(v);
    if (base <= 0) return 0.0;
    final value = (v['discount_value'] as num?)?.toDouble() ?? 0.0;
    double d;
    if (v['discount_type'] == 'percentage') {
      d = base * value / 100.0;
      final cap = (v['max_discount_amount'] as num?)?.toDouble();
      if (cap != null && cap > 0 && d > cap) d = cap;
    } else {
      d = value;
    }
    if (d > base) d = base;
    return double.parse(d.toStringAsFixed(2));
  }

  /// Validates the promo code against the merchant's real vouchers.
  Future<void> _applyVoucher() async {
    final code = _voucherController.text.trim();
    if (code.isEmpty || _isApplyingVoucher) return;
    final bizId = widget.shop['id']?.toString();
    if (bizId == null || bizId.isEmpty) return;

    setState(() => _isApplyingVoucher = true);
    try {
      final v = await Supabase.instance.client
          .from('vouchers')
          .select()
          .eq('business_id', bizId)
          .eq('is_active', true)
          .ilike('code', _escapeLike(code))
          .maybeSingle();

      if (!mounted) return;
      String? error;
      if (v == null) {
        error = 'Kod promo tidak sah.';
      } else {
        final now = DateTime.now().toUtc();
        final start = DateTime.tryParse('${v['start_date']}');
        final endD = v['end_date'] == null ? null : DateTime.tryParse('${v['end_date']}');
        final limit = v['total_usage_limit'] as num?;
        final used = (v['times_used'] as num?) ?? 0;
        final minSpend = (v['min_spend'] as num?)?.toDouble() ?? 0.0;
        final scope = (v['applicable_scope'] ?? 'all').toString();
        final eligibility = (v['customer_eligibility'] ?? 'all').toString();

        if (start != null && start.toUtc().isAfter(now)) {
          error = 'Kod promo belum bermula.';
        } else if (endD != null && endD.toUtc().isBefore(now)) {
          error = 'Kod promo telah tamat tempoh.';
        } else if (limit != null && used >= limit) {
          error = 'Kuota kod promo telah habis.';
        } else if (eligibility != 'all') {
          error = 'Kod promo ini hanya untuk pelanggan tertentu.';
        } else if (scope == 'category') {
          error = 'Kod promo ini tidak boleh digunakan di sini.';
        } else if (_subtotal < minSpend) {
          error = 'Belanja minimum RM ${minSpend.toStringAsFixed(2)} diperlukan.';
        } else if (_computeDiscount(Map<String, dynamic>.from(v)) <= 0) {
          error = 'Kod promo tidak terpakai untuk item dalam troli.';
        }
      }

      if (error != null) {
        setState(() {
          _voucher = null;
          _voucherApplied = false;
          _discountAmount = 0.0;
          _isApplyingVoucher = false;
        });
        showGlassToast(context, error, isError: true);
        return;
      }

      final voucher = Map<String, dynamic>.from(v!);
      setState(() {
        _voucher = voucher;
        _voucherApplied = true;
        _discountAmount = _computeDiscount(voucher);
        _isApplyingVoucher = false;
      });
      showGlassToast(context, 'Promo digunakan! Diskaun RM ${_discountAmount.toStringAsFixed(2)}.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isApplyingVoucher = false);
      showGlassToast(context, 'Tidak dapat semak kod promo. Cuba lagi.', isError: true);
    }
  }

  /// Re-evaluates the applied voucher after the cart changes.
  void _refreshVoucher() {
    final v = _voucher;
    if (v == null) return;
    final minSpend = (v['min_spend'] as num?)?.toDouble() ?? 0.0;
    final d = _computeDiscount(v);
    if (_subtotal < minSpend || d <= 0) {
      _voucher = null;
      _voucherApplied = false;
      _discountAmount = 0.0;
      showGlassToast(context, 'Kod promo dibatalkan kerana troli tidak lagi layak.', isError: true);
    } else {
      _discountAmount = d;
    }
  }

  void _updateQuantity(CartItem item, int delta) {
    setState(() {
      item.quantity += delta;
      if (item.quantity <= 0) {
        _items.remove(item);
      }
      _refreshVoucher();
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

    var user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      // Try anonymous sign-in for seamless table dine-in ordering
      try {
        final authRes = await Supabase.instance.client.auth.signInAnonymously();
        user = authRes.user;
      } catch (anonErr) {
        debugPrint('Anonymous sign-in unavailable: $anonErr');
      }
    }

    if (user == null) {
      if (!mounted) return;
      showGlassToast(context, 'Sila log masuk untuk menghantar pesanan.', isError: true);
      Navigator.pushNamed(context, '/login');
      return;
    }

    if (!widget.isStoreOpen && !_isPreOrder) {
      if (!mounted) return;
      showGlassToast(context, 'Kedai sedang tutup. Sila aktifkan pilihan Pesanan Awal (Pre-Order) untuk teruskan.', isError: true);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final String rawName = (user.userMetadata?['full_name'] as String?) ??
          (user.userMetadata?['name'] as String?) ??
          (user.email?.split('@').first) ??
          '';

      final String customerName = rawName.isNotEmpty
          ? rawName
          : ((widget.tableNumber != null && widget.tableNumber!.isNotEmpty)
              ? 'Pelanggan Meja #${widget.tableNumber}'
              : 'Pelanggan Walk-In');

      final String tablePrefix = (widget.tableNumber != null && widget.tableNumber!.isNotEmpty)
          ? '[Meja #${widget.tableNumber}] '
          : '';

      final String source = (widget.tableNumber != null && widget.tableNumber!.isNotEmpty)
          ? 'table'
          : (_isPreOrder ? 'pre_order' : 'online');

      final String voucherNote = (_voucherApplied && _voucher != null)
          ? '[PROMO ${_voucher!['code']} -RM${_discountAmount.toStringAsFixed(2)}] '
          : '';

      final orderData = {
        'business_id': widget.shop['id'],
        'owner_user_id': user.id,
        'customer_name': customerName,
        'total': _total,
        'status': 'pending',
        'source': source,
        'payment_method': 'cash',
        'notes': (tablePrefix +
                (_isPreOrder ? '[PRE-ORDER] ' : '') +
                voucherNote +
                _notesController.text.trim())
            .trim(),
      };

      final orderRes = await Supabase.instance.client
          .from('orders')
          .insert(orderData)
          .select('id')
          .single();

      final String orderId = orderRes['id'].toString();

      // Items MUST be saved with the order. If they fail, withdraw the order so
      // the merchant never receives an empty/unpreparable order.
      try {
        final itemsData = _items
            .map((item) => {
                  'order_id': orderId,
                  'product_id': item.product.id,
                  'product_name': item.product.name,
                  'quantity': item.quantity,
                  'unit_price': item.product.price,
                  'subtotal': item.totalPrice,
                })
            .toList();
        await Supabase.instance.client.from('order_items').insert(itemsData);
      } catch (itemErr) {
        debugPrint('order_items insert failed, cancelling order #$orderId: $itemErr');
        await _cancelOrder(orderId);
        throw Exception('Item pesanan gagal disimpan. Sila cuba lagi.');
      }

      if (!mounted) return;
      setState(() => _isProcessing = false);

      final bool completed = await CustomerPaymentModal.show(
        context: context,
        amount: _total,
        orderTitle: 'Pesanan #${orderId.length > 6 ? orderId.substring(0, 6).toUpperCase() : orderId} - ${widget.shop['name'] ?? 'Kedai'}',
        shopName: widget.shop['name']?.toString() ?? 'Kedai Ngam',
        orderId: orderId,
        items: _items
            .map((i) => {
                  'name': i.product.name,
                  'qty': i.quantity,
                  'price': i.totalPrice,
                })
            .toList(),
        customerName: customerName,
      );

      if (!mounted) return;
      if (!completed) {
        // Customer left before the order was confirmed → withdraw it, keep cart.
        await _cancelOrder(orderId);
        if (!mounted) return;
        showGlassToast(context, 'Pesanan dibatalkan. Troli anda masih disimpan.', isError: true);
        return;
      }

      widget.onClearCart?.call();
      Navigator.pop(context); // Return to store
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      showGlassToast(context, 'Pesanan gagal dihantar: ${e.toString().replaceFirst('Exception: ', '')}', isError: true);
    }
  }

  /// Customers may only move their own pending orders to 'cancelled' (RLS).
  Future<void> _cancelOrder(String orderId) async {
    try {
      await Supabase.instance.client
          .from('orders')
          .update({'status': 'cancelled'})
          .eq('id', orderId);
    } catch (e) {
      debugPrint('[StoreCartView] cancel order failed: $e');
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
                            child: HugeIcon(icon: HugeIcons.strokeRoundedDelete02, color: Colors.redAccent, size: 22),
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
                            icon: const HugeIcon(icon: HugeIcons.strokeRoundedStore01, size: 18),
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

                        if (widget.tableNumber != null && widget.tableNumber!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF00E676).withValues(alpha: 0.18),
                                  const Color(0xFF00B0FF).withValues(alpha: 0.12),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.45)),
                            ),
                            child: Row(
                              children: [
                                const HugeIcon(icon: HugeIcons.strokeRoundedDesk01, color: Color(0xFF00E676), size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pesanan Dine-In: Meja #${widget.tableNumber}',
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Makanan akan dihantar terus ke meja anda.',
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Order Type Selector (hidden while only one option exists)
                        if (_orderTypes.length > 1) ...[
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
                        ],

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
                                                  child: const HugeIcon(icon: HugeIcons.strokeRoundedShoppingBag01, color: Colors.blue),
                                                ),
                                              )
                                            : Container(
                                                color: Colors.blue.withValues(alpha: 0.1),
                                                child: const HugeIcon(icon: HugeIcons.strokeRoundedShoppingBag01, color: Colors.blue),
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
                                              child: HugeIcon(icon: HugeIcons.strokeRoundedMinusSign, size: 16, color: textPrimary),
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
                                              child: HugeIcon(icon: HugeIcons.strokeRoundedAdd01, size: 16, color: Colors.white),
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
                              prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                               prefixIcon: UnconstrainedBox(child: HugeIcon(icon: HugeIcons.strokeRoundedTaskEdit01, color: textSecondary, size: 20)),
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
                                    hintText: 'Kod Promo (jika ada)',
                                    hintStyle: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.normal),
                                    border: InputBorder.none,
                                    prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                     prefixIcon: UnconstrainedBox(child: HugeIcon(icon: HugeIcons.strokeRoundedDiscount01, color: textSecondary, size: 18)),
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
                              onPressed: _isApplyingVoucher ? null : _applyVoucher,
                              child: _isApplyingVoucher
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text(_voucherApplied ? 'Applied' : 'Apply', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                _summaryRow('Diskaun${_voucher != null ? ' (${_voucher!['code']})' : ''}', '-RM ${_discountAmount.toStringAsFixed(2)}', Colors.green, Colors.green),
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
                                      : (_isPreOrder ? 'Hantar Pre-Order' : 'Hantar Pesanan'),
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
