import 'package:flutter/material.dart';

class BookingData {
  // 🟢 Stored data for bookings
  static final ValueNotifier<List<Map<String, dynamic>>> upcomingBookings = ValueNotifier([]);
  static final ValueNotifier<List<Map<String, dynamic>>> historyBookings = ValueNotifier([]);

  // Backward-compatibility aliases
  static ValueNotifier<List<Map<String, dynamic>>> get upcomingReservations => upcomingBookings;
  static ValueNotifier<List<Map<String, dynamic>>> get historyReservations => historyBookings;

  static void addBooking({
    required String title,
    required String category,
    required String date,
    required String img,
    required String time,
    required String providerName,
    required String totalPrice,
    required String bookingId,
  }) {
    final newBooking = {
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

    upcomingBookings.value = [...upcomingBookings.value, newBooking];
  }

  // Alias
  static void addReservation({
    required String title,
    required String category,
    required String date,
    required String img,
    required String time,
    required String providerName,
    required String totalPrice,
    required String bookingId,
  }) => addBooking(
    title: title,
    category: category,
    date: date,
    img: img,
    time: time,
    providerName: providerName,
    totalPrice: totalPrice,
    bookingId: bookingId,
  );

  static void cancelBooking(String bookingId) {
    // 1. Find the booking in the upcoming list
    final int itemIndex = upcomingBookings.value.indexWhere((item) => item['id'] == bookingId);

    if (itemIndex != -1) {
      // 2. Make a copy of the item so we can edit it
      final Map<String, dynamic> cancelledItem = Map<String, dynamic>.from(upcomingBookings.value[itemIndex]);

      // 3. Remove it from the Upcoming list
      final updatedUpcoming = List<Map<String, dynamic>>.from(upcomingBookings.value)..removeAt(itemIndex);
      upcomingBookings.value = updatedUpcoming;

      // 4. Mark its status as 'cancelled' and insert it at the top of the History list!
      cancelledItem['status'] = 'cancelled';
      final updatedHistory = List<Map<String, dynamic>>.from(historyBookings.value)..insert(0, cancelledItem);
      historyBookings.value = updatedHistory;
    }
  }

  // Alias
  static void cancelReservation(String bookingId) => cancelBooking(bookingId);
}

typedef RezrvData = BookingData;
