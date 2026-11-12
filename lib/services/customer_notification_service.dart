import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/notification_data.dart';
import '../widgets/glass_notification_banner.dart';
import '../screens/explore/order_status_tracker_screen.dart';
import '../screens/explore/my_bookings_view.dart';
import '../screens/shared/chat_screen.dart';
import 'notification_bridge.dart';
import 'push_service.dart';

// =============================================================================
// CustomerNotificationService
// Unified real-time notification manager for Ngam Super App (Mobile & Web PWA).
// Handles order milestones, booking appointments, promotional drops & chat alerts.
// =============================================================================

class CustomerNotificationService {
  static final CustomerNotificationService instance =
      CustomerNotificationService._internal();

  CustomerNotificationService._internal();

  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _bookingsChannel;
  RealtimeChannel? _vouchersChannel;
  RealtimeChannel? _messagesChannel;

  String? _activeUserId;
  final Set<String> _notifiedOrderStatuses = {};
  final Set<String> _knownVoucherIds = {};
  final Set<String> _knownMessageIds = {};

  bool _isInitialized = false;

  /// Check whether browser / push notifications are supported on this platform
  Future<bool> isSupported() async {
    return await isWebNotificationSupported();
  }

  /// Request browser notification permission on Web/PWA
  Future<String> requestPermission() async {
    return await requestWebNotificationPermission();
  }

  /// Current permission status ('granted', 'denied', 'default', 'unsupported')
  Future<String> getPermissionStatus() async {
    return await getWebNotificationPermission();
  }

  /// Initialize real-time notification engine for current user
  Future<void> initialize() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    if (_isInitialized && _activeUserId == currentUserId) return;
    _activeUserId = currentUserId;

    // 1. Ensure local notification disk cache is loaded
    await NotificationData.loadNotifications();

    // 2. Request web notification permission if default/prompt
    try {
      final status = await getPermissionStatus();
      if (status == 'default') {
        await requestPermission();
      }
    } catch (_) {}

    // 3. Register FCM Token on native platforms
    try {
      await PushService.saveTokenToSupabase(currentUserId);
    } catch (_) {}

    // 4. Listen to Orders table for current user
    _setupOrdersListener(currentUserId);

    // 5. Listen to Bookings table for current user
    _setupBookingsListener(currentUserId);

    // 6. Listen to Vouchers / Promotions
    _setupVouchersListener();

    // 7. Listen to Direct Messages
    _setupMessagesListener(currentUserId);

    _isInitialized = true;
    debugPrint('[CustomerNotif] Engine active for user: $currentUserId');
  }

  void _setupOrdersListener(String userId) {
    try {
      _ordersChannel?.unsubscribe();
      _ordersChannel = Supabase.instance.client
          .channel('public:customer_orders:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'orders',
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                final orderUserId = newRecord['owner_user_id']?.toString() ??
                    newRecord['user_id']?.toString() ??
                    newRecord['customer_id']?.toString();
                if (orderUserId == userId) {
                  _onOrderStatusChanged(newRecord);
                }
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[CustomerNotif] Orders channel error: $e');
    }
  }

  void _onOrderStatusChanged(Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '';
    final status = order['status']?.toString().toLowerCase() ?? '';
    final orderNum = order['order_number']?.toString() ??
        (orderId.length > 6 ? orderId.substring(0, 6) : orderId);

    if (orderId.isEmpty || status.isEmpty) return;

    final key = '$orderId:$status';
    if (_notifiedOrderStatuses.contains(key)) return;
    _notifiedOrderStatuses.add(key);

    String? title;
    String? body;

    switch (status) {
      case 'confirmed':
        title = 'notifications.order_confirmed_title'.tr();
        body = 'notifications.order_confirmed_body'.tr(args: [orderNum]);
        break;
      case 'preparing':
        title = 'notifications.order_preparing_title'.tr();
        body = 'notifications.order_preparing_body'.tr(args: [orderNum]);
        break;
      case 'ready':
      case 'ready_for_pickup':
        title = 'notifications.order_ready_title'.tr();
        body = 'notifications.order_ready_body'.tr(args: [orderNum]);
        break;
      case 'completed':
        title = 'notifications.order_completed_title'.tr();
        body = 'notifications.order_completed_body'.tr(args: [orderNum]);
        break;
      case 'cancelled':
        title = 'notifications.order_cancelled_title'.tr();
        body = 'notifications.order_cancelled_body'.tr(args: [orderNum]);
        break;
      default:
        return;
    }

    // 1. Dispatch Web/PWA or native browser push notification
    showWebNotification(
      title: title,
      body: body,
      tag: 'order_$orderId',
      url: '/orders',
    );

    // 2. Dispatch in-app liquid frosted glass banner
    showCustomerNotificationBanner(
      title: title,
      body: body,
      category: CustomerNotificationCategory.order,
      onTap: () {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => OrderStatusTrackerScreen(orderId: orderId),
            ),
          );
        }
      },
    );

    // 3. Save to local NotificationData persistence
    NotificationData.addNotification(
      type: 'order',
      title: title,
      message: body,
      data: {'order_id': orderId, 'status': status},
    );
  }

  void _setupBookingsListener(String userId) {
    try {
      _bookingsChannel?.unsubscribe();
      _bookingsChannel = Supabase.instance.client
          .channel('public:customer_bookings:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'bookings',
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                final meta = newRecord['booking_metadata'] is Map
                    ? newRecord['booking_metadata'] as Map
                    : const {};
                final bUserId = newRecord['customer_id']?.toString() ??
                    meta['customer_auth_id']?.toString() ??
                    newRecord['user_id']?.toString();
                if (bUserId == userId) {
                  _onBookingStatusChanged(newRecord);
                }
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[CustomerNotif] Bookings channel error: $e');
    }
  }

  void _onBookingStatusChanged(Map<String, dynamic> booking) {
    final bookingId = booking['id']?.toString() ?? '';
    final status = booking['status']?.toString().toLowerCase() ?? '';
    final meta = booking['booking_metadata'] is Map
        ? booking['booking_metadata'] as Map
        : const {};
    final shopName = (meta['shop_name'] ??
            booking['shop_name'] ??
            booking['business_name'] ??
            'Kedai')
        .toString();
    final date = (booking['booking_date'] ?? booking['date'] ?? '').toString();
    final time = (booking['booking_time'] ?? booking['time'] ?? '').toString();

    if (bookingId.isEmpty || status.isEmpty) return;

    final key = 'booking:$bookingId:$status';
    if (_notifiedOrderStatuses.contains(key)) return;
    _notifiedOrderStatuses.add(key);

    String? title;
    String? body;

    if (status == 'confirmed') {
      title = 'notifications.booking_confirmed_title'.tr();
      body = 'notifications.booking_confirmed_body'.tr(args: [shopName, date, time]);
    } else if (status == 'cancelled') {
      title = 'notifications.booking_cancelled_title'.tr();
      body = 'notifications.booking_cancelled_body'.tr(args: [shopName]);
    } else {
      return;
    }

    showWebNotification(
      title: title,
      body: body,
      tag: 'booking_$bookingId',
      url: '/bookings',
    );

    showCustomerNotificationBanner(
      title: title,
      body: body,
      category: CustomerNotificationCategory.booking,
      onTap: () {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => const MyBookingsView()),
          );
        }
      },
    );

    NotificationData.addNotification(
      type: 'booking',
      title: title,
      message: body,
      data: {'booking_id': bookingId, 'status': status},
    );
  }

  void _setupVouchersListener() {
    try {
      _vouchersChannel?.unsubscribe();
      _vouchersChannel = Supabase.instance.client
          .channel('public:customer_vouchers')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'vouchers',
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                final id = newRecord['id']?.toString() ?? '';
                if (id.isNotEmpty && !_knownVoucherIds.contains(id)) {
                  _knownVoucherIds.add(id);

                  final title = 'notifications.promo_title'.tr();
                  final body = 'notifications.promo_body'.tr();

                  showWebNotification(
                    title: title,
                    body: body,
                    tag: 'voucher_$id',
                  );

                  showCustomerNotificationBanner(
                    title: title,
                    body: body,
                    category: CustomerNotificationCategory.promo,
                  );

                  NotificationData.addNotification(
                    type: 'promo',
                    title: title,
                    message: body,
                    data: {'voucher_id': id},
                  );
                }
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[CustomerNotif] Vouchers channel error: $e');
    }
  }

  void _setupMessagesListener(String userId) {
    try {
      _messagesChannel?.unsubscribe();
      _messagesChannel = Supabase.instance.client
          .channel('public:customer_chat_messages:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                final senderId = newRecord['sender_id']?.toString();
                final id = newRecord['id']?.toString() ?? '';
                if (senderId != userId && id.isNotEmpty && !_knownMessageIds.contains(id)) {
                  _knownMessageIds.add(id);

                  final senderName =
                      newRecord['sender_name']?.toString() ?? 'Peniaga';
                  final content =
                      newRecord['content']?.toString() ?? 'Mesej baharu';

                  final title = 'notifications.chat_title'.tr(args: [senderName]);

                  showWebNotification(
                    title: title,
                    body: content,
                    tag: 'msg_$id',
                  );

                  showCustomerNotificationBanner(
                    title: title,
                    body: content,
                    category: CustomerNotificationCategory.message,
                    onTap: () {
                      final ctx = navigatorKey.currentContext;
                      if (ctx != null) {
                        Navigator.push(
                          ctx,
                          MaterialPageRoute(builder: (_) => const ChatScreen()),
                        );
                      }
                    },
                  );

                  NotificationData.addNotification(
                    type: 'message',
                    title: title,
                    message: content,
                    data: {'message_id': id},
                  );
                }
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[CustomerNotif] Messages channel error: $e');
    }
  }

  void dispose() {
    _ordersChannel?.unsubscribe();
    _bookingsChannel?.unsubscribe();
    _vouchersChannel?.unsubscribe();
    _messagesChannel?.unsubscribe();
    _isInitialized = false;
  }
}
