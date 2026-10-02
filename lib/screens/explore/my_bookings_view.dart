import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'booking_ticket_screen.dart';
import 'package:ngam/l10n/generated/app_localizations.dart';

class MyBookingsView extends StatefulWidget {
  const MyBookingsView({super.key});

  @override
  State<MyBookingsView> createState() => _MyBookingsViewState();
}

class _MyBookingsViewState extends State<MyBookingsView> {
  int _selectedTab = 0;

  // 🟢 1. Declare a permanent stream variable
  late final Stream<List<Map<String, dynamic>>> _bookingsStream;

  @override
  void initState() {
    super.initState();
    // 🟢 2. Start the stream exactly ONCE when the screen first loads.
    // It will now stay awake in the background!
    _bookingsStream = Supabase.instance.client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
                loc?.myBarbrTitle ?? "My Bookings",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                )
            ),
            const SizedBox(height: 24),

            // --- TAB BAR ---
            Container(
              height: 50,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  _buildTabButton(loc?.tabUpcoming ?? "Upcoming", 0, isDark),
                  _buildTabButton(loc?.tabHistory ?? "History", 1, isDark),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- DYNAMIC DATABASE STREAM AREA ---
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                // 🟢 3. Use the permanent stream that never disconnects!
                stream: _bookingsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.blue));
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildListView([], isDark, isHistory: _selectedTab == 1);
                  }

                  final myUid = Supabase.instance.client.auth.currentUser?.id;

                  // 🟢 Filter bookings that belong only to the logged-in user
                  final myBookings = snapshot.data!.where((b) {
                    final meta = b['booking_metadata'] as Map<String, dynamic>?;
                    final belongsToUser = b['customer_id'] == myUid || meta?['customer_auth_id'] == myUid;
                    return belongsToUser && b['status'] != 'holding';
                  }).toList();

                  // Map Database Format back to UI Format so your tickets look perfect
                  final formattedBookings = myBookings.map((dbItem) {
                    final meta = dbItem['booking_metadata'] as Map<String, dynamic>? ?? {};

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
                      'db_id': dbItem['id'],
                      'shopId': dbItem['business_id'] ?? '', // 🟢 Shop ID
                      'id': meta['booking_id'] ?? meta['short_ref'] ?? 'BK-0000',
                      'title': meta['shop_name'] ?? 'Shop',
                      'category': meta['category'] ?? 'Service',
                      'img': meta['shop_image'] ?? 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=400',
                      'providerName': meta['provider_name'] ?? 'Staff',
                      'date': displayDate,
                      'time': dbItem['booking_time'] ?? '',
                      'totalPrice': displayPrice,
                      'status': dbItem['status'],
                    };
                  }).toList();

                  // Split into Upcoming vs History
                  final upcomingList = formattedBookings.where((b) => b['status'] != 'cancelled' && b['status'] != 'completed' && b['status'] != 'holding').toList();
                  final historyList = formattedBookings.where((b) => b['status'] == 'cancelled' || b['status'] == 'completed').toList();

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _selectedTab == 0
                        ? _buildListView(upcomingList, isDark, isHistory: false)
                        : _buildListView(historyList, isDark, isHistory: true),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index, bool isDark) {
    bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected && !isDark ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white54 : Colors.black54),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> items, bool isDark, {required bool isHistory}) {
    if (items.isEmpty) {
      final loc = AppLocalizations.of(context);
      final emptyText = isHistory
          ? (loc?.noPastReservations ?? "No past or cancelled bookings.")
          : (loc?.noUpcomingReservations ?? "No upcoming bookings yet.\nBook a service to see it here!");
      return Center(
        child: Text(
          emptyText,
          textAlign: TextAlign.center,
          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, height: 1.5, fontSize: 15),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: isHistory
              ? _buildHistoryTicket(context, item, isDark)
              : _buildUpcomingTicket(context, item, isDark),
        );
      },
    );
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
                          Text(item['category'].toUpperCase(), style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          _buildStatusBadge(status, isDark),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      const SizedBox(height: 4),
                      Text("${item['date']} • ${item['time']}", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 🟢 Reactive Step Progress Tracker
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
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      bool confirm = await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: isDark ? const Color(0xFF1E242B) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: Text("Cancel Booking?", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                          content: Text("Are you sure you want to cancel this booking?", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No, Keep it", style: TextStyle(color: Colors.grey))),
                            Container(decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes, Cancel", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)))),
                          ],
                        ),
                      ) ?? false;

                      if (!confirm) return;

                      await Supabase.instance.client.from('bookings').update({'status': 'cancelled'}).eq('id', item["db_id"]);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                      child: Center(child: Text(loc?.cancelBtn ?? "Cancel", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                      child: Center(child: Text(loc?.viewTicketBtn ?? "View Ticket", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
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
        label = 'Pending';
        icon = HugeIcons.strokeRoundedTime02;
        break;
      case 'preparing':
      case 'in_progress':
        color = const Color(0xFF8B5CF6);
        label = 'Diproses';
        icon = HugeIcons.strokeRoundedHourglass;
        break;
      case 'ready':
        color = const Color(0xFF10B981);
        label = 'Sedia';
        icon = HugeIcons.strokeRoundedShoppingBag01;
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
                      ? const Icon(Icons.check, size: 9, color: Colors.white)
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
                  Text(item['category'].toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
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

// 🟢 Alias for backwards compatibility
typedef MyRezrvView = MyBookingsView;
