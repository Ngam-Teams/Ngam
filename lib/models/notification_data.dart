import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationData {
  // Global listener for the UI
  static ValueNotifier<List<Map<String, dynamic>>> notifications = ValueNotifier([]);
  static ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  // Load from disk when app starts
  static Future<void> loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString('saved_notifications');
    if (saved != null) {
      List<dynamic> decoded = json.decode(saved);
      notifications.value = decoded.cast<Map<String, dynamic>>();

      // 🟢 2. ADD: Calculate the initial unread count
      unreadCount.value = notifications.value.where((n) => n["isUnread"] == true).length;
    }
  }

  // Save to disk
  static Future<void> _saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_notifications', json.encode(notifications.value));
  }

  // Add a new notification
  static Future<void> addNotification({required String type, required String title, required String message}) async {
    final newNotif = {
      "id": DateTime.now().millisecondsSinceEpoch.toString(),
      "type": type,
      "title": title,
      "message": message,
      "time": "Just now",
      "isUnread": true,
    };

    notifications.value = [newNotif, ...notifications.value];

    // 🟢 3. ADD: Increment unread count
    unreadCount.value++;

    await _saveToDisk();
  }

  static Future<void> markAllAsRead() async {
    final updatedList = notifications.value.map((n) {
      n["isUnread"] = false;
      return n;
    }).toList();

    notifications.value = updatedList;

    // 🟢 4. ADD: Reset the count
    unreadCount.value = 0;

    await _saveToDisk();
  }

  static Future<void> removeNotification(String id) async {
    // 🟢 5. ADD: If we are removing an unread item, lower the count
    final bool wasUnread = notifications.value.any((n) => n["id"] == id && n["isUnread"] == true);

    final updatedList = List<Map<String, dynamic>>.from(notifications.value);
    updatedList.removeWhere((n) => n["id"] == id);
    notifications.value = updatedList;

    if (wasUnread && unreadCount.value > 0) {
      unreadCount.value--;
    }

    await _saveToDisk();
  }
}