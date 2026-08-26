import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'booking_ticket_screen.dart';

class MyRezrvView extends StatefulWidget {
  const MyRezrvView({super.key});

  @override
  State<MyRezrvView> createState() => _MyRezrvViewState();
}

class _MyRezrvViewState extends State<MyRezrvView> {
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
    final myUid = Supabase.instance.client.auth.currentUser?.id;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
                "My Bookings",
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
                  _buildTabButton("Upcoming", 0, isDark),
                  _buildTabButton("History", 1, isDark),
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
                    return meta?['customer_auth_id'] == myUid && b['status'] != 'holding';
                  }).toList();

                  // Map Database Format back to UI Format so your tickets look perfect
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
                      'shopId': dbItem['business_id'] ?? '', // 🟢 ADD THIS LINE!
                      'id': meta['booking_id'] ?? meta['short_ref'] ?? 'RZRV-0000',
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
                  final upcomingList = formattedBookings.where((b) => b['status'] == 'pending' || b['status'] == 'confirmed').toList();
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
      return Center(
        child: Text(
          isHistory ? "No past or cancelled reservations." : "No upcoming reservations yet.\nBook a service to see it here!",
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
                      Text(item['category'].toUpperCase(), style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(item['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      const SizedBox(height: 4),
                      Text("${item['date']} • ${item['time']}", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const HugeIcon(icon: HugeIcons.strokeRoundedQrCode01, color: Colors.blue, size: 24),
                )
              ],
            ),
          ),
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
                          content: Text("Are you sure you want to cancel this reservation?", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
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
                      child: const Center(child: Text("Cancel", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14))),
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
                            shopId: item['shopId'], // 🟢 ADD THIS LINE!
                            shopName: item['title'],
                            category: item['category'],
                            shopImage: item['img'],
                            providerName: item['providerName'],
                            date: item['date'],
                            time: item['time'],
                            totalPrice: item['totalPrice'],
                            bookingId: item['id'],
                          ),
                        ),
                      );
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]),
                      child: const Center(child: Text("View Ticket", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
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

  Widget _buildHistoryTicket(BuildContext context, Map<String, dynamic> item, bool isDark) {
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
              isCancelled: isCancelled, // 🟢 ADD THIS SO IT KNOWS TO HIDE THE TIMER!
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
                child: Text(isCancelled ? "Cancelled" : "Done", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isCancelled ? Colors.redAccent : (isDark ? Colors.white54 : Colors.black54))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}