import 'package:flutter/material.dart';

class RezrvData {
  // 🟢 We must declare the lists here so the app can store the data!
  static final ValueNotifier<List<Map<String, dynamic>>> upcomingReservations = ValueNotifier([]);
  static final ValueNotifier<List<Map<String, dynamic>>> historyReservations = ValueNotifier([]);

  static void addReservation({
    required String title,
    required String category,
    required String date,
    required String img,
    required String time,
    required String providerName,
    required String totalPrice,
    required String bookingId,
  }) {
    final newReservation = {
      "id": bookingId,
      "title": title,
      "category": category,
      "date": date,
      "time": time,
      "img": img,
      "providerName": providerName,
      "totalPrice": totalPrice,
      "status": "upcoming",
    };

    upcomingReservations.value = [...upcomingReservations.value, newReservation];
  }

  static void cancelReservation(String bookingId) {
    // 1. Find the booking in the upcoming list
    final int itemIndex = upcomingReservations.value.indexWhere((item) => item['id'] == bookingId);

    if (itemIndex != -1) {
      // 2. Make a copy of the item so we can edit it
      final Map<String, dynamic> cancelledItem = Map<String, dynamic>.from(upcomingReservations.value[itemIndex]);

      // 3. Remove it from the Upcoming list
      final updatedUpcoming = List<Map<String, dynamic>>.from(upcomingReservations.value)..removeAt(itemIndex);
      upcomingReservations.value = updatedUpcoming;

      // 4. Mark its status as 'cancelled' and insert it at the top of the History list!
      cancelledItem['status'] = 'cancelled';
      final updatedHistory = List<Map<String, dynamic>>.from(historyReservations.value)..insert(0, cancelledItem);
      historyReservations.value = updatedHistory;
    }
  }
}