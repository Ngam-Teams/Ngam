import 'package:flutter/material.dart';

// ==================================================================
// LocalNotificationService - Stub untuk Ngam Super App
// Notification dihantar melalui Firebase Cloud Messaging (FCM)
// yang sudah tersedia dalam Ngam. Fail ini hanya menyediakan
// interface yang sama untuk keserasian dengan bookings_view.
// ==================================================================
class LocalNotificationService {

  static Future<void> initialize() async {
    // FCM already initialized via PushService in main.dart
    debugPrint('LocalNotificationService initialized (stub)');
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
  }) async {
    // In production, this would trigger a local notification.
    // For now we log it - FCM handles push notifications.
    debugPrint('Booking Confirmed: $shopName | $date $time | $totalPrice | ID: $bookingId');
  }

  static Future<void> showBookingConfirmation({
    required String shopName,
    required String date,
    required String time,
  }) async {
    debugPrint('Booking Confirmation: $shopName - $date at $time');
  }

  static Future<void> showBookingReminder({
    required String shopName,
    required String time,
  }) async {
    debugPrint('Booking Reminder: $shopName at $time');
  }

  static void cancelAll() {
    debugPrint('All local notifications cancelled');
  }
}