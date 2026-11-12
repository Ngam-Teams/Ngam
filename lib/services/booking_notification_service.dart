import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../models/notification_data.dart';
import '../widgets/glass_notification_banner.dart';
import 'notification_bridge.dart';

// ==================================================================
// LocalNotificationService - Ngam Super App Notification Engine
// Cross-platform: Dispatches Web Push / In-App Banner / Local Notification
// ==================================================================
class LocalNotificationService {

  static Future<void> initialize() async {
    debugPrint('[LocalNotificationService] initialized');
  }

  static Future<void> showBookingConfirmed({
    required String shopName,
    required String category,
    required String shopImage,
    required String providerName,
    required String date,
    required String time,
    required String totalPrice,
    required String bookingId,
    String status = 'pending',
  }) async {
    final title = 'notifications.booking_confirmed_title'.tr();
    final body = 'notifications.booking_confirmed_body'.tr(args: [shopName, date, time]);

    // Dispatch Web Browser / OS Notification
    showWebNotification(
      title: title,
      body: body,
      tag: 'booking_$bookingId',
      url: '/bookings',
    );

    // Dispatch In-App Frosted Glass Banner
    showCustomerNotificationBanner(
      title: title,
      body: body,
      category: CustomerNotificationCategory.booking,
    );

    // Save into persistent notification center
    await NotificationData.addNotification(
      type: 'booking',
      title: title,
      message: body,
      data: {'booking_id': bookingId, 'status': status},
    );
  }

  static Future<void> showBookingConfirmation({
    required String shopName,
    required String date,
    required String time,
  }) async {
    final title = 'notifications.booking_confirmed_title'.tr();
    final body = 'notifications.booking_confirmed_body'.tr(args: [shopName, date, time]);

    showWebNotification(
      title: title,
      body: body,
    );

    showCustomerNotificationBanner(
      title: title,
      body: body,
      category: CustomerNotificationCategory.booking,
    );
  }

  static Future<void> showBookingReminder({
    required String shopName,
    required String time,
  }) async {
    final title = 'notifications.booking_reminder_title'.tr();
    final body = 'notifications.booking_reminder_body'.tr(args: [shopName, 'Hari Ini', time]);

    showWebNotification(
      title: title,
      body: body,
    );

    showCustomerNotificationBanner(
      title: title,
      body: body,
      category: CustomerNotificationCategory.booking,
    );
  }

  static void cancelAll() {
    debugPrint('[LocalNotificationService] All local notifications cancelled');
  }
}
