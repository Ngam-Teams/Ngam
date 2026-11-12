import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'order_status_tracker_screen.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:ngam/widgets/glass_box.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product_model.dart';
import '../../services/voucher_service.dart';
import '../../widgets/glass_toast.dart';
import '../../widgets/glass_nav_button.dart';
import '../../widgets/customer_payment_modal.dart';
import '../../widgets/voucher_selection_sheet.dart';

// ============================================================
// CartItem Model
// ============================================================
class CartItem {
  final ProductModel product;
  int quantity;
  String? selectedOption;
  String? itemNote;
  double optionExtraPrice;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.selectedOption,
    this.itemNote,
    this.optionExtraPrice = 0.0,
  });

  double get unitPriceWithOption => product.price + optionExtraPrice;
  double get totalPrice => unitPriceWithOption * quantity;

  String get formattedProductName {
    final parts = <String>[];
    if (selectedOption != null && selectedOption!.trim().isNotEmpty) {
      parts.add(selectedOption!.trim());
    }
    if (itemNote != null && itemNote!.trim().isNotEmpty) {
      parts.add(itemNote!.trim());
    }
    if (parts.isEmpty) return product.name;
    return '${product.name} (${parts.join(' • ')})';
  }
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
  int _fulfillmentMode = 0; // 0: Bungkus (Takeaway), 1: Dine-in, 2: Pre-Order, 3: Delivery
  String _selectedPickupTime = 'Segera (~15 minit)';
  String _selectedPickupDate = 'Hari Ini';
  DateTime? _customSelectedDate;
  TimeOfDay? _customSelectedTime;
  final TextEditingController _deliveryAddressController = TextEditingController();
  bool _voucherApplied = false;
  bool _isApplyingVoucher = false;
  bool _userDismissedVoucher = false;
  double _discountAmount = 0.0;
  Map<String, dynamic>? _voucher;
  bool _isProcessing = false;
  bool _isPreOrder = false;
  String _selectedPaymentMethod = 'duitnow'; // 'duitnow', 'fpx_card', 'cash'
  String? _syncedShopName;

  String get _shopName {
    if (_syncedShopName != null && _syncedShopName!.trim().isNotEmpty) {
      return _syncedShopName!.trim();
    }
    for (final key in ['business_name', 'trading_name', 'shop_name', 'name', 'title']) {
      final val = widget.shop[key]?.toString().trim() ?? '';
      if (val.isNotEmpty &&
          val.toLowerCase() != 'kedai ngam' &&
          val.toLowerCase() != 'store' &&
          val.toLowerCase() != 'kedai') {
        return val;
      }
    }
    final fallback = (widget.shop['business_name'] ?? widget.shop['name'])?.toString().trim() ?? '';
    return fallback.isNotEmpty ? fallback : 'Kedai Pilihan';
  }

  Future<void> _ensureShopNameLoaded() async {
    final current = _shopName;
    if (current != 'Kedai Pilihan' && current != 'Kedai Ngam' && current != 'Store') return;
    final shopId = widget.shop['id']?.toString() ?? '';
    if (shopId.length < 20) return;
    try {
      final row = await Supabase.instance.client
          .from('businesses')
          .select('business_name')
          .eq('id', shopId)
          .maybeSingle();
      final fetched = row?['business_name']?.toString().trim() ?? '';
      if (fetched.isNotEmpty && mounted) {
        setState(() => _syncedShopName = fetched);
      }
    } catch (_) {}
  }

  final List<String> _quickTimeSlots = [
    'Segera (~15 minit)',
    '30 minit lagi',
    '45 minit lagi',
    '1 jam lagi',
    '1 jam 30 min',
    '2 jam lagi',
  ];

  @override
  void initState() {
    super.initState();
    // Copy each CartItem: the view mutates quantities locally and reports the
    // delta to the parent via onUpdateQuantity (sharing instances double-counted).
    _items = widget.cartItems
        .map((c) => CartItem(
              product: c.product,
              quantity: c.quantity,
              selectedOption: c.selectedOption,
              itemNote: c.itemNote,
              optionExtraPrice: c.optionExtraPrice,
            ))
        .toList();
    if (widget.tableNumber != null && widget.tableNumber!.isNotEmpty) {
      _fulfillmentMode = 1; // Dine-in
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Supabase.instance.client.auth.currentUser == null && mounted) {
        showGlassToast(context, 'Sila log masuk untuk membuat pesanan & membeli.', isError: true);
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      if (widget.promoCode != null && widget.promoCode!.isNotEmpty) {
        _voucherController.text = widget.promoCode!;
        _applyVoucher();
      } else {
        _autoApplyBestVoucher();
      }
      _ensureShopNameLoaded();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _voucherController.dispose();
    _deliveryAddressController.dispose();
    super.dispose();
  }

  double get _subtotal =>
      _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get _deliveryFee => _fulfillmentMode == 3 ? (_subtotal >= 50.0 ? 0.0 : 5.00) : 0.00;

  double get _total => (_subtotal + _deliveryFee - _discountAmount).clamp(0.0, 999999.0);

  String? get _shopCategory =>
      (widget.shop['business_industry'] ?? widget.shop['category'] ?? widget.shop['type'])?.toString();



  /// Cari dan auto-apply baucar terbaik untuk troli semasa
  Future<void> _autoApplyBestVoucher() async {
    if (_userDismissedVoucher || _voucherApplied || _items.isEmpty) return;
    try {
      final best = await VoucherService.getBestAutoVoucher(
        businessId: widget.shop['id']?.toString(),
        subtotal: _subtotal,
        category: _shopCategory,
      );
      if (best != null && mounted && !_userDismissedVoucher && !_voucherApplied) {
        final d = (best['calculated_discount'] as num?)?.toDouble() ??
            VoucherService.computeDiscount(best, _subtotal);
        if (d > 0) {
          setState(() {
            _voucher = best;
            _voucherApplied = true;
            _discountAmount = d;
            _voucherController.text = (best['code'] ?? '').toString();
          });
          showGlassToast(context, 'Baucar ${best['code']} (Jimat RM ${d.toStringAsFixed(2)}) auto-digunakan! 🎟️');
        }
      }
    } catch (e) {
      debugPrint('[StoreCartView] Auto-apply voucher error: $e');
    }
  }

  /// Buka sheet pilihan baucar
  Future<void> _openVoucherPicker() async {
    final selected = await VoucherSelectionSheet.show(
      context: context,
      businessId: widget.shop['id']?.toString(),
      subtotal: _subtotal,
      currentVoucherCode: _voucher?['code']?.toString(),
      category: _shopCategory,
    );

    if (selected == null) return;
    if (selected['clear'] == true) {
      setState(() {
        _voucher = null;
        _voucherApplied = false;
        _discountAmount = 0.0;
        _userDismissedVoucher = true;
        _voucherController.clear();
      });
      if (mounted) showGlassToast(context, 'Baucar telah dibatalkan');
      return;
    }

    final d = (selected['calculated_discount'] as num?)?.toDouble() ??
        VoucherService.computeDiscount(selected, _subtotal);
    if (!mounted) return;
    setState(() {
      _voucher = selected;
      _voucherApplied = true;
      _discountAmount = d;
      _userDismissedVoucher = false;
      _voucherController.text = (selected['code'] ?? '').toString();
    });
    showGlassToast(context, 'Baucar ${selected['code']} digunakan! Jimat RM ${d.toStringAsFixed(2)}');
  }

  /// Validates the promo code against available vouchers.
  Future<void> _applyVoucher() async {
    final code = _voucherController.text.trim();
    if (code.isEmpty || _isApplyingVoucher) return;

    setState(() => _isApplyingVoucher = true);
    final res = await VoucherService.validateAndApplyCode(
      code: code,
      businessId: widget.shop['id']?.toString(),
      subtotal: _subtotal,
      category: _shopCategory,
    );

    if (!mounted) return;
    setState(() => _isApplyingVoucher = false);

    if (res['success'] == true && res['voucher'] != null) {
      final v = Map<String, dynamic>.from(res['voucher'] as Map);
      final d = (v['calculated_discount'] as num?)?.toDouble() ??
          VoucherService.computeDiscount(v, _subtotal);
      setState(() {
        _voucher = v;
        _voucherApplied = true;
        _discountAmount = d;
        _userDismissedVoucher = false;
      });
      showGlassToast(context, 'Promo digunakan! Diskaun RM ${d.toStringAsFixed(2)}.');
    } else {
      setState(() {
        _voucher = null;
        _voucherApplied = false;
        _discountAmount = 0.0;
      });
      showGlassToast(context, res['message'] ?? 'Kod promo tidak sah.', isError: true);
    }
  }

  /// Re-evaluates the applied voucher after the cart changes.
  void _refreshVoucher() {
    if (_total < 10.0 && _selectedPaymentMethod == 'fpx_card') {
      _selectedPaymentMethod = 'duitnow';
    }
    if (_voucher == null) {
      if (!_userDismissedVoucher && _items.isNotEmpty) {
        _autoApplyBestVoucher();
      }
      return;
    }
    final status = VoucherService.checkVoucherEligibility(
      _voucher!,
      businessId: widget.shop['id']?.toString(),
      subtotal: _subtotal,
      category: _shopCategory,
    );
    if (status['isEligible'] != true) {
      _voucher = null;
      _voucherApplied = false;
      _discountAmount = 0.0;
      showGlassToast(context, status['reason'] ?? 'Baucar tidak lagi layak untuk troli semasa.', isError: true);
      if (!_userDismissedVoucher) {
        _autoApplyBestVoucher();
      }
    } else {
      _discountAmount = (status['discountAmount'] as num?)?.toDouble() ??
          VoucherService.computeDiscount(_voucher!, _subtotal);
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

    if (_fulfillmentMode == 3 && _deliveryAddressController.text.trim().isEmpty) {
      if (!mounted) return;
      showGlassToast(context, 'cart.delivery_address_required'.tr(), isError: true);
      return;
    }

    if (_selectedPaymentMethod == 'fpx_card' && _total < 10.0) {
      if (!mounted) return;
      setState(() => _selectedPaymentMethod = 'duitnow');
      showGlassToast(context, 'cart.fpx_min_spend_error'.tr(), isError: true);
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

      final String deliveryAddress = _deliveryAddressController.text.trim();
      final String scheduleInfo = _fulfillmentMode == 2
          ? 'Pre-Order: $_selectedPickupDate, $_selectedPickupTime'
          : (_fulfillmentMode == 3
              ? 'Delivery: $_selectedPickupDate, $_selectedPickupTime${deliveryAddress.isNotEmpty ? " (Alamat: $deliveryAddress)" : ""}'
              : (_fulfillmentMode == 1 ? 'Dine-In' : 'Bungkus (Ambil Pantas)'));

      final String fulfillmentLabel = scheduleInfo;

      final String source = (widget.tableNumber != null && widget.tableNumber!.isNotEmpty) || _fulfillmentMode == 1
          ? 'table'
          : (_fulfillmentMode == 3
              ? 'delivery'
              : (_isPreOrder || _fulfillmentMode == 2 ? 'pre_order' : 'online'));

      final String voucherNote = (_voucherApplied && _voucher != null)
          ? '[PROMO ${_voucher!['code']} -RM${_discountAmount.toStringAsFixed(2)}] '
          : '';

      final String finalNotes = '$tablePrefix[$fulfillmentLabel] $voucherNote${_notesController.text.trim()}'.trim();

      final String customerPhone = (user.phone?.isNotEmpty == true)
          ? user.phone!
          : ((user.userMetadata?['phone'] as String?) ??
              (user.userMetadata?['phone_number'] as String?) ??
              '');

      final baseOrderData = {
        'business_id': widget.shop['id'],
        'owner_user_id': user.id,
        'customer_name': customerName,
        if (customerPhone.isNotEmpty) 'customer_phone': customerPhone,
        'total': _total,
        'status': 'pending',
        'source': source,
        'notes': finalNotes,
        'payment_method': _selectedPaymentMethod,
        'payment_status': _selectedPaymentMethod == 'cash' ? 'unpaid' : 'pending',
      };

      Map<String, dynamic> orderRes;
      try {
        orderRes = await Supabase.instance.client
            .from('orders')
            .insert(baseOrderData)
            .select('id')
            .single();
      } catch (insertErr) {
        debugPrint('[StoreCartView] Insert failed ($insertErr), attempting fallback...');
        try {
          // If check constraint on source or payment fails, fallback gracefully
          orderRes = await Supabase.instance.client
              .from('orders')
              .insert({
                ...baseOrderData,
                'source': 'online',
              })
              .select('id')
              .single();
        } catch (sourceErr) {
          debugPrint('[StoreCartView] Fallback without payment_status: $sourceErr');
          orderRes = await Supabase.instance.client
              .from('orders')
              .insert({
                'business_id': widget.shop['id'],
                'owner_user_id': user.id,
                'customer_name': customerName,
                'total': _total,
                'status': 'pending',
                'source': 'online',
                'notes': finalNotes,
              })
              .select('id')
              .single();
        }
      }

      final String orderId = orderRes['id'].toString();

      // Items MUST be saved with the order. If they fail, withdraw the order so
      // the merchant never receives an empty/unpreparable order.
      try {
        final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
        final itemsData = _items
            .map((item) {
                  final rawPid = item.product.id.trim();
                  final isValidUuid = uuidRegex.hasMatch(rawPid);
                  return {
                    'order_id': orderId,
                    if (isValidUuid) 'product_id': rawPid,
                    'product_name': item.formattedProductName,
                    'quantity': item.quantity,
                    'unit_price': item.unitPriceWithOption,
                    'subtotal': item.totalPrice,
                  };
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

      // Jika Bayar di Kaunter (Tunai), terus hantar pesanan ke kedai tanpa buka modal pembayaran kedua!
      if (_selectedPaymentMethod != 'cash' && _total > 0) {
        final bool paid = await CustomerPaymentModal.show(
          context: context,
          amount: _total,
          orderTitle: 'Pesanan #${orderId.length > 6 ? orderId.substring(0, 6).toUpperCase() : orderId} - $_shopName',
          shopName: _shopName,
          orderId: orderId,
          items: _items
              .map((i) => {
                    'name': i.formattedProductName,
                    'qty': i.quantity,
                    'price': i.totalPrice,
                  })
              .toList(),
          customerName: customerName,
          customerPhone: customerPhone,
          voucherCode: (_voucherApplied && _voucher != null) ? _voucher!['code']?.toString() : null,
          discountAmount: (_voucherApplied && _discountAmount > 0) ? _discountAmount : null,
          initialMethod: _selectedPaymentMethod,
          onPaymentSuccess: (method, txRef) async {
            try {
              await Supabase.instance.client
                  .from('orders')
                  .update({'payment_status': 'paid'})
                  .eq('id', orderId);
            } catch (_) {}
          },
        );

        if (!mounted) return;
        if (!paid) {
          // Pelanggan membatalkan bayaran sebelum selesai -> batalkan draf pesanan supaya kedai tidak menerima pesanan belum bayar
          try {
            await Supabase.instance.client
                .from('orders')
                .update({'status': 'cancelled', 'payment_status': 'pending'})
                .eq('id', orderId);
          } catch (_) {
            await _cancelOrder(orderId);
          }
          if (!mounted) return;
          showGlassToast(context, 'Pembayaran dibatalkan. Troli anda masih disimpan.', isError: true);
          return;
        }
        try {
          await Supabase.instance.client
              .from('orders')
              .update({'payment_status': 'paid'})
              .eq('id', orderId);
        } catch (_) {}
      }

      // Rekod penebusan baucar supaya kuota tidak boleh diguna tanpa had
      if (_voucherApplied && _voucher != null && _discountAmount > 0) {
        await VoucherService.recordVoucherRedemption(
          voucher: _voucher!,
          discountAmount: _discountAmount,
          orderSubtotal: _subtotal,
          businessId: widget.shop['id']?.toString(),
          orderId: orderId,
          customerPhone: customerPhone,
        );
      }

      // Tolak stok inventori bagi produk fizikal yang menjejak stok
      for (final item in _items) {
        if (item.product.id.isNotEmpty) {
          try {
            final prodRow = await Supabase.instance.client
                .from('business_products')
                .select('stock, track_inventory, item_type')
                .eq('id', item.product.id)
                .maybeSingle();
            if (prodRow != null &&
                prodRow['item_type'] != 'service' &&
                (prodRow['track_inventory'] as bool? ?? true)) {
              final curStock = (prodRow['stock'] as num?)?.toInt() ?? 0;
              final newStock = (curStock - item.quantity).clamp(0, 999999);
              await Supabase.instance.client
                  .from('business_products')
                  .update({'stock': newStock})
                  .eq('id', item.product.id);
            }
          } catch (_) {}
        }
      }

      widget.onClearCart?.call();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderStatusTrackerScreen(
            orderId: orderId,
            shopName: _shopName,
            totalAmount: _total,
            pickupTime: (_fulfillmentMode == 2 || _fulfillmentMode == 3)
                ? '$_selectedPickupDate, $_selectedPickupTime'
                : (_fulfillmentMode == 1 ? 'Dine-In (Meja)' : _selectedPickupTime),
            fulfillmentType: fulfillmentLabel,
            items: _items.map((i) => {'name': i.formattedProductName, 'qty': i.quantity, 'price': i.totalPrice}).toList(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      showGlassToast(context, 'Pesanan gagal dihantar: ${e.toString().replaceFirst('Exception: ', '')}', isError: true);
    }
  }

  Future<void> _editItemOptionDialog(CartItem item, bool isDark) async {
    final options = ['Biasa', 'Kurang Manis', 'Lebih Pedas', 'Kurang Ais', 'Besar (+RM2.00)', 'Tambah Cheese (+RM2.00)'];
    String selectedOpt = item.selectedOption ?? '';
    final noteCtrl = TextEditingController(text: item.itemNote ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding: EdgeInsets.fromLTRB(22, 22, 22, MediaQuery.of(ctx).viewInsets.bottom + 22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilihan & Nota: ${item.product.name}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options.map((opt) {
                  final isSel = selectedOpt == opt;
                  return GestureDetector(
                    onTap: () => setModal(() => selectedOpt = isSel ? '' : opt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? Colors.blue : (isDark ? Colors.white10 : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteCtrl,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Nota khas item (cth: Tak nak bawang / Asing kuah)...',
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    setState(() {
                      item.selectedOption = selectedOpt.isEmpty ? null : selectedOpt;
                      item.itemNote = noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim();
                      item.optionExtraPrice = selectedOpt.contains('+RM2.00') ? 2.0 : 0.0;
                      _refreshVoucher();
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text('cart.save_options'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        safeNavBack(context, fallbackRoute: '/customer-home');
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
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
                            'Add items from $_shopName to get started.',
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
                            label: Text('cart.browse_products'.tr(), style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 68, 20, 12),
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

                        // Seksyen Pilihan Kaedah Pengambilan & Waktu Ambil (Fulfillment & Pickup Time)
                        _buildFulfillmentCard(isDark, textPrimary, textSecondary),
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
                                            'RM ${item.unitPriceWithOption.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.blue,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          GestureDetector(
                                            onTap: () => _editItemOptionDialog(item, isDark),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                (item.selectedOption?.isNotEmpty == true || item.itemNote?.isNotEmpty == true)
                                                    ? '${item.selectedOption ?? ''}${item.selectedOption != null && item.itemNote != null ? ' • ' : ''}${item.itemNote ?? ''}'
                                                    : '+ Pilihan / Nota Item',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.blue,
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
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

                        // Interactive Voucher Section
                        _buildVoucherSection(isDark, textPrimary, textSecondary),

                        const SizedBox(height: 18),

                        // Seksyen Pilihan Kaedah Pembayaran (Payment Method Selection)
                        _buildPaymentMethodSection(isDark, textPrimary, textSecondary),

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
                              if (_fulfillmentMode == 3) ...[
                                const SizedBox(height: 8),
                                _summaryRow(
                                  'Caj Penghantaran (Delivery)',
                                  _deliveryFee == 0 ? 'PERCUMA' : 'RM ${_deliveryFee.toStringAsFixed(2)}',
                                  textSecondary,
                                  _deliveryFee == 0 ? Colors.green : textPrimary,
                                ),
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
                          Text('cart.total_price'.tr(), style: TextStyle(color: textSecondary, fontSize: 11)),
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
            FloatingTopBar(
              isDark: isDark,
              fallbackRoute: '/customer-home',
              title: 'cart.title'.tr(),
              subtitle: _shopName,
              actions: _items.isNotEmpty
                  ? [
                      GlassNavButton(
                        icon: HugeIcons.strokeRoundedDelete02,
                        iconColor: Colors.redAccent,
                        isDark: isDark,
                        size: 42,
                        iconSize: 20,
                        onTap: () {
                          setState(() => _items.clear());
                          widget.onClearCart?.call();
                        },
                      ),
                    ]
                  : null,
            ),
          ],
        ),
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

  Widget _buildVoucherSection(bool isDark, Color textPrimary, Color textSecondary) {
    if (_voucherApplied && _voucher != null) {
      final code = (_voucher!['code'] ?? '').toString().toUpperCase();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedTicket01,
                color: Color(0xFF10B981),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        code,
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Digunakan',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Jimat RM ${_discountAmount.toStringAsFixed(2)} untuk pesanan ini',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _openVoucherPicker,
              child: Text('common.change'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                setState(() {
                  _voucher = null;
                  _voucherApplied = false;
                  _discountAmount = 0.0;
                  _userDismissedVoucher = true;
                  _voucherController.clear();
                });
                showGlassToast(context, 'Baucar dibatalkan');
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: const HugeIcon(icon: HugeIcons.strokeRoundedCancel01, size: 14, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _openVoucherPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedDiscount01,
                color: Colors.blue,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Baucar & Kod Diskaun',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Pilih baucar atau masukkan kod promo',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pilih Baucar',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 4),
                  HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: Colors.blue, size: 12),
                ],
              ),
            ),
          ],
        ),
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

  Widget _buildFulfillmentCard(bool isDark, Color textPrimary, Color textSecondary) {
    // Check if store supports delivery
    final bool supportsDelivery = widget.shop['supports_delivery'] == true ||
        widget.shop['enable_delivery'] == true ||
        widget.shop['is_delivery_enabled'] == true;

    return _liquidGlassBox(
      isDark: isDark,
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HugeIcon(icon: HugeIcons.strokeRoundedClock01, color: Color(0xFF00E5FF), size: 20),
              const SizedBox(width: 8),
              Text(
                'Pilihan & Waktu Pengambilan',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Fulfillment Tabs: Bungkus, Dine-in, Pre-Order, and Delivery (if supported)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildFulfillmentTab(0, 'Bungkus', HugeIcons.strokeRoundedShoppingBag01, isDark, textPrimary, textSecondary),
                _buildFulfillmentTab(1, 'Dine-In', HugeIcons.strokeRoundedDesk01, isDark, textPrimary, textSecondary),
                _buildFulfillmentTab(2, 'Pre-Order', HugeIcons.strokeRoundedCalendar02, isDark, textPrimary, textSecondary),
                if (supportsDelivery)
                  _buildFulfillmentTab(3, 'Delivery', HugeIcons.strokeRoundedDeliveryTruck01, isDark, textPrimary, textSecondary),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Details depending on fulfillment mode
          if (_fulfillmentMode == 0) ...[
            // Takeaway Quick Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle03, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pesanan bungkus segera. Anggaran masa siap: ~15 minit di kaunter.',
                      style: TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_fulfillmentMode == 1) ...[
            // Dine-in Table
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF00B0FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00B0FF).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const HugeIcon(icon: HugeIcons.strokeRoundedDesk01, color: Color(0xFF00B0FF), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.tableNumber != null && widget.tableNumber!.isNotEmpty
                          ? 'Dine-In di Meja #${widget.tableNumber}. Pesanan dihantar ke meja anda.'
                          : 'Dine-In di Kedai. Masukkan No. Meja dalam nota di bawah jika ada.',
                      style: TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Pre-Order & Delivery: Date & Time Picker
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_fulfillmentMode == 3) ...[
                  // Delivery Address field
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    child: TextField(
                      controller: _deliveryAddressController,
                      style: TextStyle(color: textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        icon: const HugeIcon(icon: HugeIcons.strokeRoundedLocation01, color: Color(0xFF00E5FF), size: 18),
                        hintText: 'Masukkan alamat penghantaran...',
                        hintStyle: TextStyle(color: textSecondary, fontSize: 12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],

                // Date Selector (Hari Ini / Esok / Pilih Tarikh)
                Row(
                  children: [
                    _buildDatePill('Hari Ini', isDark, textPrimary, textSecondary),
                    const SizedBox(width: 8),
                    _buildDatePill('Esok', isDark, textPrimary, textSecondary),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _customSelectedDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          setState(() {
                            _customSelectedDate = picked;
                            _selectedPickupDate = '${picked.day}/${picked.month}/${picked.year}';
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: (_selectedPickupDate != 'Hari Ini' && _selectedPickupDate != 'Esok')
                              ? Colors.deepPurpleAccent.withValues(alpha: 0.18)
                              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (_selectedPickupDate != 'Hari Ini' && _selectedPickupDate != 'Esok')
                                ? Colors.deepPurpleAccent
                                : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedCalendar03,
                              color: (_selectedPickupDate != 'Hari Ini' && _selectedPickupDate != 'Esok')
                                  ? Colors.deepPurpleAccent
                                  : textSecondary,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              (_selectedPickupDate != 'Hari Ini' && _selectedPickupDate != 'Esok')
                                  ? _selectedPickupDate
                                  : 'Pilih Tarikh',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: (_selectedPickupDate != 'Hari Ini' && _selectedPickupDate != 'Esok')
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: (_selectedPickupDate != 'Hari Ini' && _selectedPickupDate != 'Esok')
                                    ? Colors.deepPurpleAccent
                                    : textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fulfillmentMode == 3 ? 'Pilih Waktu Hantar:' : 'Pilih Slot Masa Ambil:',
                      style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w600),
                    ),
                    // Custom Time Picker Button
                    GestureDetector(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _customSelectedTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _customSelectedTime = picked;
                            final period = picked.hour >= 12 ? 'PM' : 'AM';
                            int h = picked.hour % 12;
                            if (h == 0) h = 12;
                            _selectedPickupTime = '${h.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')} $period';
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4), width: 0.8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HugeIcon(icon: HugeIcons.strokeRoundedClock01, color: Color(0xFF00E5FF), size: 13),
                            SizedBox(width: 4),
                            Text(
                              'Masa Khusus',
                              style: TextStyle(fontSize: 11, color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._quickTimeSlots.map((slot) {
                      final bool isSel = _selectedPickupTime == slot;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedPickupTime = slot),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSel
                                ? const Color(0xFF00E5FF).withValues(alpha: 0.18)
                                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSel ? const Color(0xFF00E5FF) : Colors.transparent,
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            slot,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                              color: isSel ? const Color(0xFF00E5FF) : textPrimary,
                            ),
                          ),
                        ),
                      );
                    }),
                    if (!_quickTimeSlots.contains(_selectedPickupTime))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF00E5FF), width: 1.2),
                        ),
                        child: Text(
                          _selectedPickupTime,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00E5FF),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFulfillmentTab(int index, String label, dynamic icon, bool isDark, Color textPrimary, Color textSecondary) {
    final bool isSelected = _fulfillmentMode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _fulfillmentMode = index;
            _isPreOrder = index == 2;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white.withValues(alpha: 0.16) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: icon,
                color: isSelected ? const Color(0xFF00E5FF) : textSecondary,
                size: 15,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? textPrimary : textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePill(String label, bool isDark, Color textPrimary, Color textSecondary) {
    final bool isSel = _selectedPickupDate == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedPickupDate = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSel
              ? Colors.deepPurpleAccent.withValues(alpha: 0.18)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSel ? Colors.deepPurpleAccent : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
            color: isSel ? Colors.deepPurpleAccent : textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSection(bool isDark, Color textPrimary, Color textSecondary) {
    final bool isFpxEligible = _total >= 10.0;
    return _liquidGlassBox(
      isDark: isDark,
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HugeIcon(icon: HugeIcons.strokeRoundedWallet01, color: Color(0xFF00E5FF), size: 20),
              const SizedBox(width: 8),
              Text(
                'Pilihan Kaedah Pembayaran',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Option 1: DuitNow QR (Disyorkan)
          _buildPaymentChoiceTile(
            value: 'duitnow',
            title: 'DuitNow QR Pantas (Zero Fee)',
            subtitle: 'Imbas guna sebarang aplikasi Bank atau e-Wallet (TNG, GrabPay, ShopeePay)',
            icon: HugeIcons.strokeRoundedQrCode,
            iconColor: const Color(0xFFED0058),
            badge: 'DISYORKAN',
            badgeColor: const Color(0xFFED0058),
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 10),

          // Option 2: FPX & Kad (Had Minima RM 10.00)
          _buildPaymentChoiceTile(
            value: 'fpx_card',
            title: 'Perbankan FPX & Kad Debit/Kredit',
            subtitle: isFpxEligible
                ? 'Maybank2u, CIMB, Bank Islam, RHB, Visa & Mastercard'
                : 'cart.fpx_min_spend_subtitle'.tr(),
            icon: HugeIcons.strokeRoundedCreditCard,
            iconColor: isFpxEligible ? const Color(0xFF00B0FF) : Colors.grey,
            badge: isFpxEligible ? null : 'cart.fpx_min_spend_badge'.tr(),
            badgeColor: Colors.amber.shade800,
            isEnabled: isFpxEligible,
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 10),

          // Option 3: Tunai di Kaunter / COD
          _buildPaymentChoiceTile(
            value: 'cash',
            title: _fulfillmentMode == 3 ? 'Tunai Semasa Penghantaran (COD)' : 'Bayar di Kaunter (Tunai)',
            subtitle: _fulfillmentMode == 3
                ? 'Bayar tunai kepada penghantar apabila pesanan tiba'
                : 'Bayar secara tunai atau terus di kaunter premis',
            icon: HugeIcons.strokeRoundedCash01,
            iconColor: const Color(0xFF10B981),
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentChoiceTile({
    required String value,
    required String title,
    required String subtitle,
    required dynamic icon,
    required Color iconColor,
    String? badge,
    Color? badgeColor,
    bool isEnabled = true,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final bool isSelected = _selectedPaymentMethod == value;
    return GestureDetector(
      onTap: () {
        if (!isEnabled) {
          HapticFeedback.heavyImpact();
          showGlassToast(context, 'cart.fpx_min_spend_error'.tr(), isError: true);
          return;
        }
        HapticFeedback.selectionClick();
        setState(() => _selectedPaymentMethod = value);
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isEnabled ? 1.0 : 0.45,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00E5FF).withValues(alpha: isDark ? 0.12 : 0.08)
              : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF00E5FF) : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: HugeIcon(icon: icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? const Color(0xFFED0058)).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: (badgeColor ?? const Color(0xFFED0058)).withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: badgeColor ?? const Color(0xFFED0058),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF00E5FF) : Colors.grey.shade500,
                  width: 2,
                ),
                color: isSelected ? const Color(0xFF00E5FF) : Colors.transparent,
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.check, size: 13, color: Colors.black),
                    )
                  : null,
            ),
          ],
        ),
      ),
      ),
    );
  }

}
