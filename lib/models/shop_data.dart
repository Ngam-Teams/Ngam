import 'package:flutter/material.dart';

class ShopData {
  // ValueNotifier broadcasts changes instantly to any listening screen
  static ValueNotifier<Set<String>> savedShopNames = ValueNotifier<Set<String>>({});

  // Real data is loaded dynamically from Supabase database and cached locally.
  static final List<Map<String, dynamic>> shops = [];
}