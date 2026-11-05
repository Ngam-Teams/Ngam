import 'package:easy_localization/easy_localization.dart';
import '../../widgets/glass_nav_button.dart';
import '../../widgets/glass_toast.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'booking_ticket_screen.dart';
import 'order_status_tracker_screen.dart';
import '../shared/my_queue_ticket_screen.dart';
import 'package:ngam/l10n/generated/app_localizations.dart';

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
          .select('id, business_name, business_type, logo_url, cover_url');
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
    final loc = AppLocalizations.of(context);

    return Scaffold(
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
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Giliran Walk-In Langsung (Queue)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Semak nombor giliran live anda di kedai',
                                  style: TextStyle(
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
                      _buildCategoryChip('Semua', 0, HugeIcons.strokeRoundedLayers01, isDark),
                      const SizedBox(width: 8),
                      _buildCategoryChip('Tempahan Slot', 1, HugeIcons.strokeRoundedCalendar03, isDark),
                      const SizedBox(width: 8),
                      _buildCategoryChip('Pesanan Kedai', 2, HugeIcons.strokeRoundedShoppingBag01, isDark),
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
                        _buildTabButton(loc?.tabUpcoming ?? "Aktif & Akan Datang", 0, isDark),
                        _buildTabButton(loc?.tabHistory ?? "Sejarah", 1, isDark),
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

                              return {
                                'record_type': 'booking',
                                'created_at': dbItem['created_at']?.toString() ?? '',
                                'db_id': dbItem['id'],
                                'shopId': bizId,
                                'id': meta['booking_id'] ?? meta['short_ref'] ?? 'BK-0000',
                                'title': meta['shop_name'] ?? biz?['business_name'] ?? 'Kedai Ngam',
                                'category': meta['category'] ?? biz?['business_type'] ?? 'Servis',
                                'img': meta['shop_image'] ??
                                    biz?['cover_url'] ??
                                    biz?['logo_url'] ??
                                    'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=400',
                                'providerName': meta['provider_name'] ?? 'Staf',
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
                              return o['owner_user_id'] == myUid;
                            }).toList();

                            final formattedOrders = myOrders.map<Map<String, dynamic>>((o) {
                              final bizId = o['business_id']?.toString() ?? '';
                              final biz = _businessCache[bizId];
                              final String rawNotes = o['notes']?.toString() ?? '';
                              String fulfillment = 'Bungkus / Takeaway';
                              final match = RegExp(r'\[([^\]]+)\]').firstMatch(rawNotes);
                              if (match != null) {
                                fulfillment = match.group(1) ?? fulfillment;
                              } else if (o['source'] == 'table') {
                                fulfillment = 'Dine-In (Meja)';
                              } else if (o['source'] == 'delivery') {
                                fulfillment = 'Delivery';
                              } else if (o['source'] == 'pre_order') {
                                fulfillment = 'Pre-Order';
                              }

                              String formattedTime = '';
                              final createdStr = o['created_at']?.toString() ?? '';
                              if (createdStr.isNotEmpty) {
                                try {
                                  final dt = DateTime.parse(createdStr).toLocal();
                                  formattedTime = DateFormat('d MMM, h:mm a').format(dt);
                                } catch (_) {}
                              }

                              final double totalVal = (o['total'] as num?)?.toDouble() ?? 0.0;
                              final String oid = o['id']?.toString() ?? '';

                              return {
                                'record_type': 'order',
                                'created_at': createdStr,
                                'db_id': oid,
                                'shopId': bizId,
                                'id': oid.length > 8 ? oid.substring(0, 8).toUpperCase() : oid.toUpperCase(),
                                'title': biz?['business_name']?.toString() ?? 'Kedai Ngam',
                                'category': fulfillment,
                                'img': biz?['cover_url'] ??
                                    biz?['logo_url'] ??
                                    'https://images.unsplash.com/photo-1504674900247-0877df9cc836?q=80&w=400',
                                'date': formattedTime,
                                'time': fulfillment,
                                'totalAmount': totalVal,
                                'totalPrice': 'RM ${totalVal.toStringAsFixed(2)}',
                                'status': (o['status']?.toString() ?? 'pending').toLowerCase(),
                                'paymentStatus': (o['payment_status']?.toString() ?? 'paid').toLowerCase(),
                                'notes': rawNotes,
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
              leading: Navigator.canPop(context)
                  ? GlassNavButton.back(
                      context: context,
                      isDark: isDark,
                      size: 44,
                      iconSize: 20,
                    )
                  : const SizedBox(width: 44, height: 44),
              title: "Tempahan & Pesanan",
            ),
          ],
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

  Widget _buildTabButton(String title, int index, bool isDark) {
    final bool isSelected = _selectedTab == index;
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
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? Colors.white54 : Colors.grey.shade600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> items, bool isDark, {required bool isHistory}) {
    if (items.isEmpty) {
      final emptyText = isHistory
          ? "Tiada sejarah tempahan atau pesanan yang lepas."
          : "Tiada tempahan atau pesanan aktif buat masa ini.";
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
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: NetworkImage(item['img']),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
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
                              'PESANAN #${item['id']}',
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
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                          decoration: isCancelled ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${item['category']} • ${item['totalPrice']}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isHistory) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildOrderProgressTracker(status, isDark),
            ),
            const SizedBox(height: 12),
          ],
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
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
                                  "Batal Pesanan?",
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                content: Text(
                                  "Pesanan ini masih menunggu pengesahan kedai. Adakah anda mahu membatalkannya?",
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    fontSize: 13,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text("common.back".tr(), style: TextStyle(color: Colors.grey)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text(
                                      "Ya, Batalkan",
                                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
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
                            showGlassToast(context, 'Pesanan berjaya dibatalkan.');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showGlassToast(context, 'Gagal membatalkan pesanan.', isError: true);
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            "Batal",
                            style: TextStyle(
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
                            shopName: item['title'] ?? 'Kedai Ngam',
                            totalAmount: (item['totalAmount'] as num?)?.toDouble() ?? 0.0,
                            fulfillmentType: item['category'],
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
                        child: Text(
                          isHistory ? "Lihat Resit & Butiran" : "Jejak Pesanan & QR Ambil",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
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

    final steps = ['Diterima', 'Dimasak', 'Sedia Diambil', 'Selesai'];

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
                  'Ubah Tarikh & Masa Tempahan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item['title'] ?? 'Kedai',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Pilih Tarikh Baru',
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
                  'Pilih Waktu Baru',
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
                    child: const Text(
                      'Simpan Waktu Baru',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
      showGlassToast(context, 'Tarikh & masa tempahan berjaya dikemas kini!');
    }
  }

  Widget _buildUpcomingTicket(BuildContext context, Map<String, dynamic> item, bool isDark) {
    final loc = AppLocalizations.of(context);
    final String status = (item['status'] as String? ?? 'pending').toLowerCase();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(image: NetworkImage(item['img']), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(item['category'].toString().toUpperCase(), style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          _buildStatusBadge(status, isDark),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      const SizedBox(height: 4),
                      Text(
                        "${item['date']} • ${item['time']}${item['pax'] != null && (item['pax'] as num) > 1 ? ' • ${item['pax']} Pax' : ''}",
                        style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
                          "Dalam Pertikaian",
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
                            "Ubah Waktu",
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
                      decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]),
                      child: Center(child: Text(loc?.viewTicketBtn ?? "Lihat Tiket & QR", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5))),
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
        label = 'Menunggu';
        icon = HugeIcons.strokeRoundedTime02;
        break;
      case 'preparing':
      case 'in_progress':
        color = const Color(0xFF8B5CF6);
        label = 'Disediakan';
        icon = HugeIcons.strokeRoundedHourglass;
        break;
      case 'ready':
        color = const Color(0xFF10B981);
        label = 'Sedia Diambil';
        icon = HugeIcons.strokeRoundedShoppingBag01;
        break;
      case 'completed':
        color = const Color(0xFF10B981);
        label = 'Selesai';
        icon = HugeIcons.strokeRoundedCheckmarkCircle02;
        break;
      case 'disputed':
        color = const Color(0xFFF97316);
        label = 'Pertikaian';
        icon = HugeIcons.strokeRoundedAlert02;
        break;
      case 'cancelled':
        color = const Color(0xFFEF4444);
        label = 'Dibatalkan';
        icon = HugeIcons.strokeRoundedCancel01;
        break;
      case 'confirmed':
      default:
        color = const Color(0xFF3B82F6);
        label = 'Disahkan';
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
            Text(
              "Aduan pertikaian sedang disiasat oleh Sokongan Ngam",
              style: TextStyle(fontSize: 11, color: Colors.amber.shade400, fontWeight: FontWeight.bold),
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

    final steps = ['Diterima', 'Disahkan', 'Sedia'];

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
    final loc = AppLocalizations.of(context);
    bool isCancelled = item["status"] == "cancelled";

    return GestureDetector(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => BookingTicketScreen(
              shopId: item['shopId'] ?? '',
              shopName: item['title'],
              category: item['category'],
              shopImage: item['img'],
              providerName: item['providerName'],
              date: item['date'],
              time: item['time'],
              totalPrice: item['totalPrice'],
              bookingId: item['id'],
              isCancelled: isCancelled,
              status: item['status'] ?? (isCancelled ? 'cancelled' : 'completed'),
              bookingDbId: item['db_id']?.toString(),
            ),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[100],
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                image: DecorationImage(image: NetworkImage(item['img']), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: isCancelled ? 0.6 : 0.3), BlendMode.darken)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['category'].toString().toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black87, decoration: isCancelled ? TextDecoration.lineThrough : null)),
                  const SizedBox(height: 4),
                  Text("${item['date']} • ${item['time']}", style: TextStyle(color: isDark ? Colors.white30 : Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: isCancelled ? Colors.redAccent.withValues(alpha: 0.1) : (isDark ? Colors.white10 : Colors.grey[300]), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  isCancelled ? (loc?.statusCancelled ?? "Cancelled") : (loc?.statusDone ?? "Done"),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isCancelled ? Colors.redAccent : (isDark ? Colors.white54 : Colors.black54)),
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
