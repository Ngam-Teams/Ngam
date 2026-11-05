import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../models/notification_data.dart';
import '../explore/order_status_tracker_screen.dart';
import '../explore/my_bookings_view.dart';
import '../shared/chat_screen.dart';

class CustomerNotificationCenterSheet extends StatefulWidget {
  const CustomerNotificationCenterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => const CustomerNotificationCenterSheet(),
    );
  }

  @override
  State<CustomerNotificationCenterSheet> createState() =>
      _CustomerNotificationCenterSheetState();
}

class _CustomerNotificationCenterSheetState
    extends State<CustomerNotificationCenterSheet> {
  String _selectedFilter = 'all'; // 'all', 'order', 'booking', 'promo'

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.85,
        maxWidth: 580,
      ),
      margin: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        bottomInset > 0 ? bottomInset + 12 : 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 36,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull Bar Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedNotification01,
                          color: Color(0xFF38BDF8),
                          size: 20,
                        ),
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
                                'notifications.title'.tr(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ValueListenableBuilder<int>(
                                valueListenable: NotificationData.unreadCount,
                                builder: (context, count, _) {
                                  if (count == 0) return const SizedBox.shrink();
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF4757),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      count.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          Text(
                            'Kemas kini langsung aktiviti anda',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Mark all as read button
                    IconButton(
                      tooltip: 'notifications.mark_all_read'.tr(),
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedCheckmarkBadge01,
                        color: Color(0xFF38BDF8),
                        size: 20,
                      ),
                      onPressed: () {
                        NotificationData.markAllAsRead();
                      },
                    ),

                    // Clear All button
                    IconButton(
                      tooltip: 'notifications.clear_all'.tr(),
                      icon: Icon(
                        Icons.delete_sweep_rounded,
                        color: Colors.white.withValues(alpha: 0.55),
                        size: 22,
                      ),
                      onPressed: () {
                        NotificationData.clearAll();
                      },
                    ),
                  ],
                ),
              ),

              // Category Filter Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'notifications.tab_all'.tr()),
                      _buildFilterChip('order', 'notifications.tab_orders'.tr()),
                      _buildFilterChip('booking', 'notifications.tab_bookings'.tr()),
                      _buildFilterChip('promo', 'notifications.tab_promos'.tr()),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Divider(
                color: Colors.white.withValues(alpha: 0.08),
                height: 1,
              ),

              // Notification List
              Expanded(
                child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: NotificationData.notifications,
                  builder: (context, list, _) {
                    final filtered = list.where((n) {
                      if (_selectedFilter == 'all') return true;
                      return n['type'] == _selectedFilter;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedNotification03,
                                    color: Colors.white.withValues(alpha: 0.35),
                                    size: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'notifications.empty'.tr(),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _buildNotificationItem(context, item, isDark);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = key;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF38BDF8).withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF38BDF8).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF38BDF8) : Colors.white70,
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    Map<String, dynamic> item,
    bool isDark,
  ) {
    final String id = item['id']?.toString() ?? '';
    final String type = item['type']?.toString() ?? 'system';
    final String title = item['title']?.toString() ?? '';
    final String message = item['message']?.toString() ?? '';
    final bool isUnread = item['isUnread'] == true;
    final Map<String, dynamic>? data = item['data'] as Map<String, dynamic>?;

    Color catColor = const Color(0xFF38BDF8);
    dynamic iconData = HugeIcons.strokeRoundedNotification01;

    switch (type) {
      case 'order':
        catColor = const Color(0xFF38BDF8);
        iconData = HugeIcons.strokeRoundedDeliveryTruck01;
        break;
      case 'booking':
        catColor = const Color(0xFF818CF8);
        iconData = HugeIcons.strokeRoundedCalendar03;
        break;
      case 'promo':
        catColor = const Color(0xFFF472B6);
        iconData = HugeIcons.strokeRoundedTicket01;
        break;
      case 'message':
        catColor = const Color(0xFF34D399);
        iconData = HugeIcons.strokeRoundedChatting01;
        break;
    }

    return Dismissible(
      key: Key('notif_item_$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      onDismissed: (_) {
        NotificationData.removeNotification(id);
      },
      child: GestureDetector(
        onTap: () {
          NotificationData.markAsRead(id);
          Navigator.pop(context);

          // Handle action routing
          if (type == 'order' && data?['order_id'] != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderStatusTrackerScreen(
                  orderId: data!['order_id'].toString(),
                ),
              ),
            );
          } else if (type == 'booking') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyBookingsView()),
            );
          } else if (type == 'message') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isUnread
                ? catColor.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isUnread
                  ? catColor.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Circle
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: catColor.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: iconData,
                    color: catColor,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title, Message, Unread dot
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: catColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: catColor.withValues(alpha: 0.8),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
