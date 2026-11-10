import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/glass_nav_button.dart';
import '../../widgets/glass_toast.dart';
import 'booking_ticket_screen.dart';
import 'order_status_tracker_screen.dart';
import '../shared/my_queue_ticket_screen.dart';

class MyBookingsView extends StatefulWidget {
  final int initialCategoryFilter; // 0 = Semua, 1 = Tempahan, 2 = Pesanan
  const MyBookingsView({super.key, this.initialCategoryFilter = 0});

  @override
  State<MyBookingsView> createState() => _MyBookingsViewState();
}

class _MyBookingsViewState extends State<MyBookingsView> {
  int _selectedTab = 0; // 0 = Aktif / Akan Datang, 1 = Sejarah
  late int _categoryFilter; // 0 = Semua, 1 = Tempahan (Booking), 2 = Pesanan (Order)

  late final Stream<List<Map<String, dynamic>>> _bookingsStream;
  late final Stream<List<Map<String, dynamic>>> _ordersStream;
  final Map<String, Map<String, dynamic>> _businessCache = {};
  final Map<String, List<Map<String, dynamic>>> _orderItemsCache = {};
  final Set<String> _pendingOrderItemFetches = {};
  final Set<String> _pendingBizFetches = {};

  void _loadOrderItemsForIds(List<String> orderIds) async {
    final toFetch = orderIds
        .map((id) => id.trim().toLowerCase())
        .where((id) => id.isNotEmpty && !_orderItemsCache.containsKey(id) && !_pendingOrderItemFetches.contains(id))
        .toSet()
        .toList();
    if (toFetch.isEmpty) return;
    _pendingOrderItemFetches.addAll(toFetch);

    try {
      final rows = await Supabase.instance.client
          .from('order_items')
          .select('order_id, product_name, quantity, unit_price, subtotal')
          .inFilter('order_id', toFetch);

      if (!mounted) return;
      setState(() {
        for (final id in toFetch) {
          _orderItemsCache[id] = [];
        }
        for (final r in (rows as List)) {
          final oid = (r['order_id']?.toString() ?? '').trim().toLowerCase();
          if (oid.isNotEmpty) {
            _orderItemsCache.putIfAbsent(oid, () => []).add(Map<String, dynamic>.from(r as Map));
          }
        }
      });
    } catch (e) {
      debugPrint('[MyBookingsView] Error loading order items: $e');
    } finally {
      _pendingOrderItemFetches.removeAll(toFetch);
    }
  }

  void _loadBusinessIfNeeded(String bizId) async {
    if (bizId.isEmpty || _businessCache.containsKey(bizId) || _pendingBizFetches.contains(bizId)) return;
    _pendingBizFetches.add(bizId);

    try {
      final row = await Supabase.instance.client
          .from('businesses')
          .select('id, business_name, business_industry, business_logo_url, business_cover_url')
          .eq('id', bizId)
          .maybeSingle();

      if (row != null && mounted) {
        setState(() {
          _businessCache[bizId] = Map<String, dynamic>.from(row);
        });
      }
    } catch (_) {
    } finally {
      _pendingBizFetches.remove(bizId);
    }
  }

  Widget _buildStoreLogo(String? logoUrl, String storeName, {double size = 60, BorderRadius? borderRadius}) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    final hasUrl = logoUrl != null && logoUrl.trim().isNotEmpty && logoUrl.startsWith('http');
    final initial = storeName.trim().isNotEmpty ? storeName.trim().substring(0, 1).toUpperCase() : 'N';

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: radius,
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
        child: hasUrl
            ? Image.network(
                logoUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildAvatarFallback(initial, size),
              )
            : _buildAvatarFallback(initial, size),
      ),
    );
  }

  Widget _buildAvatarFallback(String initial, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF00E5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.42,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _categoryFilter = widget.initialCategoryFilter;

    _bookingsStream = Supabase.instance.client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    _ordersStream = Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    _preloadBusinesses();
  }

  Future<void> _preloadBusinesses() async {
    try {
      final rows = await Supabase.instance.client
          .from('businesses')
          .select('id, business_name, business_industry, business_logo_url, business_cover_url');
      if (!mounted) return;
      setState(() {
        for (final r in (rows as List)) {
          final id = r['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            _businessCache[id] = Map<String, dynamic>.from(r as Map);
          }
        }
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        safeNavBack(context, fallbackRoute: '/customer-home');
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A14) : const Color(0xFFF8F9FA),
        body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 68, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // --- WALK-IN QUEUE TICKET QUICK ACCESS ---
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyQueueTicketScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2196F3).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const HugeIcon(icon: HugeIcons.strokeRoundedUserGroup, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'my_bookings.walkin_queue_title'.tr(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'my_bookings.walkin_queue_desc'.tr(),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: Colors.white70, size: 14),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- CATEGORY FILTER PILLS (Semua / Tempahan / Pesanan) ---
                  Row(
                    children: [
                      _buildCategoryChip('my_bookings.filter_all'.tr(), 0, HugeIcons.strokeRoundedLayers01, isDark),
                      const SizedBox(width: 8),
                      _buildCategoryChip('my_bookings.filter_slot'.tr(), 1, HugeIcons.strokeRoundedCalendar03, isDark),
                      const SizedBox(width: 8),
                      _buildCategoryChip('my_bookings.filter_orders'.tr(), 2, HugeIcons.strokeRoundedShoppingBag01, isDark),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // --- TAB BAR (Upcoming vs History) ---
                  Container(
                    height: 46,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildTabButton(
                          'my_bookings.tab_active'.tr(),
                          0,
                          isDark,
                          icon: HugeIcons.strokeRoundedFlash,
                        ),
                        _buildTabButton(
                          'my_bookings.tab_history'.tr(),
                          1,
                          isDark,
                          icon: HugeIcons.strokeRoundedTime02,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- COMBINED REALTIME STREAM AREA (BOOKINGS + ORDERS) ---
                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _bookingsStream,
                      builder: (context, bookingSnap) {
                        return StreamBuilder<List<Map<String, dynamic>>>(
                          stream: _ordersStream,
                          builder: (context, orderSnap) {
                            if (bookingSnap.connectionState == ConnectionState.waiting &&
                                orderSnap.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(color: Color(0xFF2196F3)),
                              );
                            }

                            final myUid = Supabase.instance.client.auth.currentUser?.id;

                            // 1. Format Bookings
                            final rawBookings = bookingSnap.data ?? [];
                            final myBookings = rawBookings.where((b) {
                              final meta = b['booking_metadata'] as Map<String, dynamic>?;
                              final belongsToUser =
                                  b['customer_id'] == myUid || meta?['customer_auth_id'] == myUid;
                              return belongsToUser && b['status'] != 'holding';
                            }).toList();

                            final formattedBookings = myBookings.map<Map<String, dynamic>>((dbItem) {
                              final meta = dbItem['booking_metadata'] as Map<String, dynamic>? ?? {};
                              final bizId = dbItem['business_id']?.toString() ?? '';
                              if (bizId.isNotEmpty && !_businessCache.containsKey(bizId)) {
                                _loadBusinessIfNeeded(bizId);
                              }
                              final biz = _businessCache[bizId];

                              String displayDate = dbItem['booking_date'] ?? '';
                              if (displayDate.isNotEmpty) {
                                try {
                                  DateTime parsed = DateTime.parse(displayDate);
                                  const weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
                                  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                                  displayDate = "${weekdays[parsed.weekday - 1]}, ${parsed.day} ${months[parsed.month - 1]}";
                                } catch (_) {}
                              }

                              String displayPrice = meta['total_price']?.toString() ?? 'RM0';
                              if (!displayPrice.startsWith('RM')) displayPrice = 'RM$displayPrice';

                              // Prioritize store logo url
                              final bizLogo = biz?['business_logo_url']?.toString().trim();
                              final bizCover = biz?['business_cover_url']?.toString().trim();
                              final shopImg = (bizLogo != null && bizLogo.isNotEmpty && bizLogo.startsWith('http'))
                                  ? bizLogo
                                  : ((bizCover != null && bizCover.isNotEmpty && bizCover.startsWith('http'))
                                      ? bizCover
                                      : (meta['shop_image']?.toString() ?? ''));

                              final shopName = (meta['shop_name'] != null &&
                                      meta['shop_name'].toString().trim().isNotEmpty &&
                                      meta['shop_name'].toString().toLowerCase() != 'kedai ngam' &&
                                      meta['shop_name'].toString().toLowerCase() != 'store')
                                  ? meta['shop_name']
                                  : (biz?['business_name'] ?? meta['shop_name'] ?? 'my_bookings.default_store'.tr());

                              final serviceName = meta['service_name'] ?? meta['service'] ?? meta['title'] ?? 'my_bookings.default_service'.tr();
                              final providerName = meta['provider_name'] ?? meta['staff_name'] ?? 'my_bookings.default_staff'.tr();
                              final specialRequest = meta['special_request'] ?? meta['notes'] ?? dbItem['notes']?.toString();

                              return {
                                'record_type': 'booking',
                                'created_at': dbItem['created_at']?.toString() ?? '',
                                'db_id': dbItem['id'],
                                'shopId': bizId,
                                'id': meta['booking_id'] ?? meta['short_ref'] ?? 'BK-0000',
                                'title': shopName,
                                'serviceName': serviceName,
                                'providerName': providerName,
                                'specialRequest': specialRequest,
                                'category': meta['category'] ?? biz?['business_industry'] ?? 'my_bookings.default_service'.tr(),
                                'img': shopImg,
                                'date': displayDate,
                                'rawDate': dbItem['booking_date']?.toString() ?? '',
                                'time': dbItem['booking_time'] ?? '',
                                'totalPrice': displayPrice,
                                'status': (dbItem['status']?.toString() ?? 'pending').toLowerCase(),
                                'paymentStatus': (meta['payment_status']?.toString() ?? 'unpaid').toLowerCase(),
                                'pax': dbItem['pax'] ?? meta['pax'],
                                'checkOutDate': meta['check_out_date'],
                              };
                            }).toList();

                            // 2. Format Orders
                            final rawOrders = orderSnap.data ?? [];
                            final myOrders = rawOrders.where((o) {
                              if (myUid == null) return false;
                              if (o['owner_user_id'] != myUid) return false;
                              final src = (o['source'] ?? 'online').toString().toLowerCase();
                              final payMethod = (o['payment_method'] ?? 'cash').toString().toLowerCase();
                              final payStatus = (o['payment_status'] ?? '').toString().toLowerCase();
                              final status = (o['status'] ?? '').toString().toLowerCase();
                              if (src != 'pos' && payMethod != 'cash' && payStatus == 'pending') {
                                return false;
                              }
                              if (status == 'cancelled' && payStatus == 'pending') {
                                return false;
                              }
                              return true;
                            }).toList();

                            // Collect uncached order ids for batch fetch
                            final uncachedOids = myOrders
                                .map((o) => (o['id']?.toString() ?? '').toLowerCase().trim())
                                .where((id) => id.isNotEmpty && !_orderItemsCache.containsKey(id) && !_pendingOrderItemFetches.contains(id))
                                .toSet()
                                .toList();
                            if (uncachedOids.isNotEmpty) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) _loadOrderItemsForIds(uncachedOids);
                              });
                            }

                            final formattedOrders = myOrders.map<Map<String, dynamic>>((o) {
                              final bizId = o['business_id']?.toString() ?? '';
                              if (bizId.isNotEmpty && !_businessCache.containsKey(bizId)) {
                                _loadBusinessIfNeeded(bizId);
                              }
                              final biz = _businessCache[bizId];
                              final String rawNotes = o['notes']?.toString() ?? '';
                              
                              String fulfillment = 'my_bookings.fulfillment_takeaway'.tr();
                              final match = RegExp(r'\[([^\]]+)\]').firstMatch(rawNotes);
                              if (match != null) {
                                fulfillment = match.group(1) ?? fulfillment;
                              } else if (o['source'] == 'table') {
                                fulfillment = 'my_bookings.fulfillment_dine_in'.tr();
                              } else if (o['source'] == 'delivery') {
                                fulfillment = 'my_bookings.fulfillment_delivery'.tr();
                              } else if (o['source'] == 'pre_order') {
                                fulfillment = 'my_bookings.fulfillment_preorder'.tr();
                              }

                              // Extract clean customer note
                              final cleanNote = rawNotes.replaceAll(RegExp(r'\[.*?\]'), '').trim();

                              String formattedTime = '';
                              final createdStr = o['created_at']?.toString() ?? '';
                              if (createdStr.isNotEmpty) {
                                try {
                                  final dt = DateTime.parse(createdStr).toLocal();
                                  formattedTime = DateFormat('d MMM, h:mm a').format(dt);
                                } catch (_) {}
                              }

                              final double totalVal = (o['total'] as num?)?.toDouble() ?? 0.0;
                              final String oid = (o['id']?.toString() ?? '').toLowerCase().trim();

                              // Prioritize store logo url
                              final bizLogo = biz?['business_logo_url']?.toString().trim();
                              final bizCover = biz?['business_cover_url']?.toString().trim();
                              final shopImg = (bizLogo != null && bizLogo.isNotEmpty && bizLogo.startsWith('http'))
                                  ? bizLogo
                                  : ((bizCover != null && bizCover.isNotEmpty && bizCover.startsWith('http'))
                                      ? bizCover
                                      : '');

                              final payMethod = (o['payment_method'] ?? 'cash').toString();
                              final payStatus = (o['payment_status'] ?? 'paid').toString().toLowerCase();

                              return {
                                'record_type': 'order',
                                'created_at': createdStr,
                                'db_id': oid,
                                'shopId': bizId,
                                'id': oid.length > 8 ? oid.substring(0, 8).toUpperCase() : oid.toUpperCase(),
                                'title': biz?['business_name']?.toString() ?? 'my_bookings.default_store'.tr(),
                                'category': fulfillment,
                                'img': shopImg,
                                'date': formattedTime,
                                'time': fulfillment,
                                'totalAmount': totalVal,
                                'totalPrice': 'RM ${totalVal.toStringAsFixed(2)}',
                                'status': (o['status']?.toString() ?? 'pending').toLowerCase(),
                                'paymentMethod': payMethod,
                                'paymentStatus': payStatus,
                                'notes': rawNotes,
                                'customerNote': cleanNote,
                                'items': _orderItemsCache[oid] ?? [],
                              };
                            }).toList();

                            // 3. Merge & Filter by Category
                            List<Map<String, dynamic>> combined = [];
                            if (_categoryFilter == 0) {
                              combined = [...formattedBookings, ...formattedOrders];
                            } else if (_categoryFilter == 1) {
                              combined = formattedBookings;
                            } else {
                              combined = formattedOrders;
                            }

                            combined.sort((a, b) {
                              final ca = a['created_at']?.toString() ?? '';
                              final cb = b['created_at']?.toString() ?? '';
                              return cb.compareTo(ca);
                            });

                            final upcomingList = combined
                                .where((item) =>
                                    item['status'] != 'cancelled' &&
                                    item['status'] != 'completed' &&
                                    item['status'] != 'holding')
                                .toList();
                            final historyList = combined
                                .where((item) =>
                                    item['status'] == 'cancelled' || item['status'] == 'completed')
                                .toList();

                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: _selectedTab == 0
                                  ? _buildListView(upcomingList, isDark, isHistory: false)
                                  : _buildListView(historyList, isDark, isHistory: true),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            FloatingTopBar(
              isDark: isDark,
              fallbackRoute: '/customer-home',
              title: 'my_bookings.title'.tr(),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildCategoryChip(String label, int idx, dynamic icon, bool isDark) {
    final bool selected = _categoryFilter == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _categoryFilter = idx),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF2196F3)
                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF2196F3)
                  : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: icon,
                size: 14,
                color: selected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index, bool isDark, {dynamic icon}) {
    final bool isSelected = _selectedTab == index;
    final Color textColor = isSelected
        ? (isDark ? Colors.white : const Color(0xFF0F172A))
        : (isDark ? Colors.white54 : Colors.grey.shade600);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  icon is IconData
                      ? Icon(icon, size: 16, color: textColor)
                      : HugeIcon(icon: icon, size: 16, color: textColor),
                  const SizedBox(width: 7),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> items, bool isDark, {required bool isHistory}) {
    if (items.isEmpty) {
      final emptyText = isHistory
          ? 'my_bookings.empty_history'.tr()
          : 'my_bookings.empty_active'.tr();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: isHistory ? HugeIcons.strokeRoundedClock01 : HugeIcons.strokeRoundedCalendar03,
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                emptyText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  height: 1.5,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isOrder = item['record_type'] == 'order';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: isOrder
              ? _buildOrderCard(context, item, isDark, isHistory: isHistory)
              : (isHistory
                  ? _buildHistoryTicket(context, item, isDark)
                  : _buildUpcomingTicket(context, item, isDark)),
        );
      },
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> item, bool isDark,
      {required bool isHistory}) {
    final String status = (item['status'] as String? ?? 'pending').toLowerCase();
    final String orderDbId = item['db_id']?.toString() ?? '';
    final bool isCancelled = status == 'cancelled';
    final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(item['items'] ?? []);
    final String customerNote = item['customerNote']?.toString() ?? '';
    final String payMethod = (item['paymentMethod']?.toString() ?? 'cash').toUpperCase();
    final String payStatus = (item['paymentStatus']?.toString() ?? 'paid').toLowerCase();
    final bool isPaid = payStatus == 'paid';

    int totalQty = 0;
    for (final it in items) {
      totalQty += (it['quantity'] as num?)?.toInt() ?? 1;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER: STORE LOGO, ID, STATUS, STORE NAME, TIME ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStoreLogo(item['img'], item['title'] ?? 'my_bookings.default_store'.tr(), size: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'my_bookings.order_badge'.tr(args: [item['id']]),
                              style: const TextStyle(
                                color: Color(0xFF00B8D4),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Spacer(),
                          _buildStatusBadge(status, isDark),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item['title'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                          decoration: isCancelled ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedShoppingBag02,
                            size: 12,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              "${item['category']}${item['date'].toString().isNotEmpty ? ' • ${item['date']}' : ''}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.grey[600],
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- ORDER ITEMS BREAKDOWN CONTAINER ---
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedTag01,
                      size: 13,
                      color: Color(0xFF00B8D4),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'my_bookings.items_ordered'.tr(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white70 : Colors.black87,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B8D4).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        totalQty > 0
                            ? (totalQty == 1
                                ? 'my_bookings.items_count_single'.tr()
                                : 'my_bookings.items_count'.tr(args: [totalQty.toString()]))
                            : 'my_bookings.items_count_single'.tr(),
                        style: const TextStyle(
                          color: Color(0xFF00B8D4),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (items.isEmpty && !_orderItemsCache.containsKey(orderDbId)) ...[
                  Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00B8D4)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'my_bookings.loading_items'.tr(),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white38 : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ] else if (items.isNotEmpty) ...[
                  ...items.take(3).map((it) {
                    final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                    final pName = it['product_name']?.toString() ?? 'Item';
                    final sub = (it['subtotal'] as num?)?.toDouble() ??
                        (((it['unit_price'] as num?)?.toDouble() ?? 0.0) * qty);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${qty}x',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0097A7),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'RM ${sub.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white60 : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (items.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'my_bookings.more_items'.tr(args: [(items.length - 3).toString()]),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white38 : Colors.grey[500],
                        ),
                      ),
                    ),
                ] else ...[
                  // Fallback when order items list is empty in database (e.g. legacy/counter order)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '1x',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0097A7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            customerNote.isNotEmpty
                                ? customerNote
                                : ((item['category'] != null && item['category'].toString().isNotEmpty)
                                    ? 'my_bookings.general_order'.tr(args: [item['category'].toString()])
                                    : 'my_bookings.default_item'.tr()),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item['totalPrice'] ?? 'RM 0.00',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white60 : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // --- CUSTOMER NOTE CONTAINER (IF SPECIFIED) ---
          if (customerNote.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: isDark ? 0.08 : 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.15),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedNote,
                    size: 13,
                    color: Colors.amber[700] ?? Colors.amber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'my_bookings.note'.tr(args: [customerNote]),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // --- PAYMENT METHOD & TOTAL AMOUNT ROW ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HugeIcon(
                        icon: isPaid
                            ? HugeIcons.strokeRoundedCheckmarkCircle02
                            : HugeIcons.strokeRoundedWallet02,
                        size: 12,
                        color: isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPaid
                            ? 'my_bookings.paid_online'.tr(args: [payMethod])
                            : 'my_bookings.pay_at_counter'.tr(args: [payMethod]),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'my_bookings.total_payment'.tr(args: [item['totalPrice']]),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // --- STEP PROGRESS TRACKER ---
          if (!isHistory) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildOrderProgressTracker(status, isDark),
            ),
            const SizedBox(height: 12),
          ],

          Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),

          // --- BOTTOM ACTION BUTTONS ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                if (status == 'pending') ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: isDark ? const Color(0xFF1E242B) : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text(
                                  'my_bookings.cancel_order_title'.tr(),
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                content: Text(
                                  'my_bookings.cancel_order_desc'.tr(),
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    fontSize: 13,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text('common.back'.tr(), style: const TextStyle(color: Colors.grey)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(
                                      'my_bookings.cancel_order_confirm'.tr(),
                                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ) ??
                            false;
                        if (!confirm) return;
                        try {
                          await Supabase.instance.client
                              .from('orders')
                              .update({'status': 'cancelled'}).eq('id', orderDbId);
                          if (context.mounted) {
                            showGlassToast(context, 'my_bookings.cancel_order_success'.tr());
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showGlassToast(context, 'my_bookings.cancel_order_error'.tr(), isError: true);
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            'my_bookings.action_cancel'.tr(),
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) => OrderStatusTrackerScreen(
                            orderId: orderDbId,
                            shopName: item['title'] ?? 'my_bookings.default_store'.tr(),
                            totalAmount: (item['totalAmount'] as num?)?.toDouble() ?? 0.0,
                            fulfillmentType: item['category'],
                            items: items,
                            shopId: item['shopId']?.toString(),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B8D4),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00B8D4).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HugeIcon(
                              icon: isHistory ? HugeIcons.strokeRoundedInvoice01 : HugeIcons.strokeRoundedDeliveryView01,
                              color: Colors.white,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                isHistory ? 'my_bookings.action_view_receipt'.tr() : 'my_bookings.action_track_order'.tr(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
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
        ],
      ),
    );
  }

  Widget _buildOrderProgressTracker(String status, bool isDark) {
    int activeStep = 0;
    if (status == 'preparing' || status == 'in_progress') {
      activeStep = 1;
    } else if (status == 'ready') {
      activeStep = 2;
    } else if (status == 'completed') {
      activeStep = 3;
    }

    final steps = [
      'my_bookings.step_received'.tr(),
      'my_bookings.step_preparing'.tr(),
      'my_bookings.step_ready'.tr(),
      'my_bookings.step_completed'.tr(),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            final lineIndex = index ~/ 2;
            final isDone = lineIndex < activeStep;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: isDone ? const Color(0xFF00B8D4) : (isDark ? Colors.white12 : Colors.grey[300]),
              ),
            );
          }

          final stepIdx = index ~/ 2;
          final isDone = stepIdx < activeStep;
          final isCurrent = stepIdx == activeStep;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: (isDone || isCurrent)
                      ? const Color(0xFF00B8D4)
                      : (isDark ? Colors.white12 : Colors.grey[300]),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isDone
                      ? const HugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 9, color: Colors.white)
                      : isCurrent
                          ? Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            )
                          : null,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                steps[stepIdx],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.white38 : Colors.grey[500]),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _showRescheduleDialog(BuildContext context, Map<String, dynamic> item, bool isDark) async {
    DateTime pickedDate = DateTime.now().add(const Duration(days: 1));
    try {
      if (item['rawDate'] != null && item['rawDate'].toString().isNotEmpty) {
        pickedDate = DateTime.parse(item['rawDate'].toString());
      }
    } catch (_) {}

    String selectedTime = item['time']?.toString().isNotEmpty == true ? item['time'].toString() : '10:00';
    final timeOptions = [
      '09:00',
      '10:00',
      '11:00',
      '12:00',
      '14:00',
      '15:00',
      '16:00',
      '17:00',
      '18:00',
      '20:00',
      '21:00',
    ];
    if (!timeOptions.contains(selectedTime)) {
      timeOptions.insert(0, selectedTime);
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'my_bookings.reschedule_title'.tr(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item['title'] ?? 'my_bookings.default_store'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'my_bookings.reschedule_pick_date'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: pickedDate.isBefore(DateTime.now()) ? DateTime.now() : pickedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (d != null) {
                      setModal(() => pickedDate = d);
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('EEE, d MMM yyyy').format(pickedDate),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedCalendar03,
                          color: Color(0xFF2196F3),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'my_bookings.reschedule_pick_time'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: timeOptions.map((t) {
                    final sel = t == selectedTime;
                    return GestureDetector(
                      onTap: () => setModal(() => selectedTime = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF2196F3)
                              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: sel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      final newDateStr =
                          '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
                      try {
                        await Supabase.instance.client.from('bookings').update({
                          'booking_date': newDateStr,
                          'booking_time': selectedTime,
                        }).eq('id', item['db_id']);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) Navigator.pop(ctx, false);
                      }
                    },
                    child: Text(
                      'my_bookings.reschedule_save_btn'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (saved == true && context.mounted) {
      showGlassToast(context, 'my_bookings.reschedule_success'.tr());
    }
  }

  Widget _buildUpcomingTicket(BuildContext context, Map<String, dynamic> item, bool isDark) {
    final String status = (item['status'] as String? ?? 'pending').toLowerCase();
    final String serviceName = item['serviceName']?.toString() ?? 'my_bookings.default_service'.tr();
    final String providerName = item['providerName']?.toString() ?? 'my_bookings.default_staff'.tr();
    final String? specialRequest = item['specialRequest']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStoreLogo(item['img'], item['title'] ?? 'my_bookings.default_store'.tr(), size: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'my_bookings.booking_badge'.tr(args: [item['id']]),
                              style: const TextStyle(
                                color: Color(0xFF2196F3),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Spacer(),
                          _buildStatusBadge(status, isDark),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item['title'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedCalendar03,
                            size: 12,
                            color: Color(0xFF2196F3),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              "${item['date']} • ${item['time']}${item['pax'] != null && (item['pax'] as num) > 1 ? ' • ${'my_bookings.pax_count'.tr(args: [item['pax'].toString()])}' : ''}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.grey[600],
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- SERVICE & PROVIDER DETAILS CONTAINER ---
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedScissor, size: 13, color: const Color(0xFF2196F3)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'my_bookings.service_booked'.tr(args: [serviceName]),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const HugeIcon(icon: HugeIcons.strokeRoundedUser, size: 13, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'my_bookings.provider_assigned'.tr(args: [providerName]),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white60 : Colors.grey[700],
                        ),
                      ),
                    ),
                    Text(
                      item['totalPrice'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0097A7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- SPECIAL REQUEST (IF ANY) ---
          if (specialRequest != null && specialRequest.trim().isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: isDark ? 0.08 : 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.15),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedNote,
                    size: 13,
                    color: Colors.amber[700] ?? Colors.amber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'my_bookings.special_request'.tr(args: [specialRequest]),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Reactive Step Progress Tracker
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildMiniProgressTracker(status, isDark),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                if (status == 'disputed')
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade900.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.shade600.withValues(alpha: 0.4)),
                      ),
                      child: Center(
                        child: Text(
                          'my_bookings.dispute_in_progress'.tr(),
                          style: TextStyle(color: Colors.amber.shade400, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  )
                else ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showRescheduleDialog(context, item, isDark),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            'my_bookings.action_reschedule'.tr(),
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) => BookingTicketScreen(
                            shopId: item['shopId'],
                            shopName: item['title'],
                            category: item['category'],
                            shopImage: item['img'],
                            providerName: item['providerName'],
                            date: item['date'],
                            time: item['time'],
                            totalPrice: item['totalPrice'],
                            bookingId: item['id'],
                            status: status,
                            bookingDbId: item['db_id']?.toString(),
                          ),
                        ),
                      );
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'my_bookings.action_view_ticket'.tr(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    Color color;
    String label;
    dynamic icon;

    switch (status) {
      case 'pending':
        color = const Color(0xFFF59E0B);
        label = 'my_bookings.status_pending'.tr();
        icon = HugeIcons.strokeRoundedTime02;
        break;
      case 'preparing':
      case 'in_progress':
        color = const Color(0xFF8B5CF6);
        label = 'my_bookings.status_preparing'.tr();
        icon = HugeIcons.strokeRoundedHourglass;
        break;
      case 'ready':
        color = const Color(0xFF10B981);
        label = 'my_bookings.status_ready'.tr();
        icon = HugeIcons.strokeRoundedShoppingBag01;
        break;
      case 'completed':
        color = const Color(0xFF10B981);
        label = 'my_bookings.status_completed'.tr();
        icon = HugeIcons.strokeRoundedCheckmarkCircle02;
        break;
      case 'disputed':
        color = const Color(0xFFF97316);
        label = 'my_bookings.status_disputed'.tr();
        icon = HugeIcons.strokeRoundedAlert02;
        break;
      case 'cancelled':
        color = const Color(0xFFEF4444);
        label = 'my_bookings.status_cancelled'.tr();
        icon = HugeIcons.strokeRoundedCancel01;
        break;
      case 'confirmed':
      default:
        color = const Color(0xFF3B82F6);
        label = 'my_bookings.status_confirmed'.tr();
        icon = HugeIcons.strokeRoundedCheckmarkCircle02;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniProgressTracker(String status, bool isDark) {
    if (status == 'disputed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.shade900.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            HugeIcon(icon: HugeIcons.strokeRoundedAlert02, color: Colors.amber.shade400, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'my_bookings.dispute_notice'.tr(),
                style: TextStyle(fontSize: 11, color: Colors.amber.shade400, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    int activeStep = 0;
    if (status == 'confirmed' || status == 'preparing' || status == 'in_progress') {
      activeStep = 1;
    } else if (status == 'ready' || status == 'completed') {
      activeStep = 2;
    }

    final steps = [
      'my_bookings.step_received'.tr(),
      'my_bookings.step_confirmed'.tr(),
      'my_bookings.step_ready'.tr(),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            final lineIndex = index ~/ 2;
            final isDone = lineIndex < activeStep;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: isDone ? Colors.blue : (isDark ? Colors.white12 : Colors.grey[300]),
              ),
            );
          }

          final stepIdx = index ~/ 2;
          final isDone = stepIdx < activeStep;
          final isCurrent = stepIdx == activeStep;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: (isDone || isCurrent) ? Colors.blue : (isDark ? Colors.white12 : Colors.grey[300]),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isDone
                      ? const HugeIcon(icon: HugeIcons.strokeRoundedTick01, size: 9, color: Colors.white)
                      : isCurrent
                          ? Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))
                          : null,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                steps[stepIdx],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.white38 : Colors.grey[500]),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildHistoryTicket(BuildContext context, Map<String, dynamic> item, bool isDark) {
    final bool isCancelled = item["status"] == "cancelled";
    final String serviceName = item['serviceName']?.toString() ?? item['category']?.toString() ?? 'my_bookings.default_service'.tr();

    return GestureDetector(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => BookingTicketScreen(
              shopId: item['shopId'] ?? '',
              shopName: item['title'] ?? 'my_bookings.default_store'.tr(),
              category: item['category'] ?? 'my_bookings.default_service'.tr(),
              shopImage: item['img'] ?? '',
              providerName: item['providerName'] ?? 'my_bookings.default_staff'.tr(),
              date: item['date'] ?? '',
              time: item['time'] ?? '',
              totalPrice: item['totalPrice'] ?? '',
              bookingId: item['id'] ?? '',
              isCancelled: isCancelled,
              status: item['status'] ?? (isCancelled ? 'cancelled' : 'completed'),
              bookingDbId: item['db_id']?.toString(),
            ),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            _buildStoreLogo(item['img'], item['title'] ?? 'my_bookings.default_store'.tr(), size: 54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serviceName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['title'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "${item['date']}${item['time'].toString().isNotEmpty ? ' • ${item['time']}' : ''}",
                    style: TextStyle(color: isDark ? Colors.white38 : Colors.grey[600], fontSize: 11),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isCancelled ? Colors.redAccent.withValues(alpha: 0.1) : (isDark ? Colors.white10 : Colors.grey[300]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isCancelled ? 'my_bookings.status_cancelled'.tr() : 'my_bookings.status_completed'.tr(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isCancelled ? Colors.redAccent : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Alias for backwards compatibility
typedef MyRezrvView = MyBookingsView;
