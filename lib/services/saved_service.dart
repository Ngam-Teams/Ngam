import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedService {
  static const String _shopsKey = 'ngam_saved_shops';
  static const String _postsKey = 'ngam_saved_posts';

  static final ValueNotifier<List<Map<String, dynamic>>> savedShopsNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);
  static final ValueNotifier<List<Map<String, dynamic>>> savedPostsNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  static bool _initialized = false;

  /// Inisialisasi data simpanan dari cache tempatan (SharedPreferences)
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      final shopsRaw = prefs.getString(_shopsKey);
      if (shopsRaw != null && shopsRaw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(shopsRaw);
        savedShopsNotifier.value =
            decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      final postsRaw = prefs.getString(_postsKey);
      if (postsRaw != null && postsRaw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(postsRaw);
        savedPostsNotifier.value =
            decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      _initialized = true;
    } catch (e) {
      debugPrint('[SavedService] Gagal memuat data simpanan: $e');
    }
  }

  // ─── KEDAI DISIMPAN ──────────────────────────────────────────

  static bool isShopSaved(String? shopId) {
    if (shopId == null || shopId.isEmpty) return false;
    return savedShopsNotifier.value.any(
      (s) => s['id']?.toString() == shopId || s['shopId']?.toString() == shopId,
    );
  }

  static Future<bool> toggleSaveShop(Map<String, dynamic> shop) async {
    await init();
    final shopId = (shop['id'] ?? shop['shopId'] ?? '').toString();
    if (shopId.isEmpty) return false;

    final current = List<Map<String, dynamic>>.from(savedShopsNotifier.value);
    final existingIndex = current.indexWhere(
      (s) => s['id']?.toString() == shopId || s['shopId']?.toString() == shopId,
    );

    bool nowSaved;
    if (existingIndex >= 0) {
      current.removeAt(existingIndex);
      nowSaved = false;
    } else {
      current.insert(0, {
        'id': shopId,
        'shopId': shopId,
        'name': shop['name'] ?? shop['shopName'] ?? shop['business_name'] ?? 'Kedai',
        'category': shop['category'] ?? shop['business_industry'] ?? 'Servis',
        'image': shop['image'] ?? shop['shopImage'] ?? shop['logo_url'] ?? '',
        'rating': shop['rating'] ?? 5.0,
        'location': shop['location'] ?? shop['address'] ?? '',
        'savedAt': DateTime.now().toIso8601String(),
      });
      nowSaved = true;
    }

    savedShopsNotifier.value = current;
    await _persistShops(current);
    return nowSaved;
  }

  static Future<void> removeSavedShop(String shopId) async {
    await init();
    final current = List<Map<String, dynamic>>.from(savedShopsNotifier.value);
    current.removeWhere(
      (s) => s['id']?.toString() == shopId || s['shopId']?.toString() == shopId,
    );
    savedShopsNotifier.value = current;
    await _persistShops(current);
  }

  static Future<void> _persistShops(List<Map<String, dynamic>> shops) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_shopsKey, jsonEncode(shops));
    } catch (e) {
      debugPrint('[SavedService] Gagal menyimpan senarai kedai: $e');
    }
  }

  // ─── HANTARAN DISIMPAN ─────────────────────────────────────────

  static bool isPostSaved(String? postId) {
    if (postId == null || postId.isEmpty) return false;
    return savedPostsNotifier.value.any(
      (p) => p['id']?.toString() == postId,
    );
  }

  static Future<bool> toggleSavePost(Map<String, dynamic> post) async {
    await init();
    final postId = (post['id'] ?? '').toString();
    if (postId.isEmpty) return false;

    final current = List<Map<String, dynamic>>.from(savedPostsNotifier.value);
    final existingIndex = current.indexWhere(
      (p) => p['id']?.toString() == postId,
    );

    bool nowSaved;
    if (existingIndex >= 0) {
      current.removeAt(existingIndex);
      nowSaved = false;
    } else {
      final String coverCandidate = (post['cover'] ??
              post['thumbnail'] ??
              post['coverUrl'] ??
              post['shopCover'] ??
              post['shopData']?['cover'] ??
              post['shopData']?['business_cover_url'] ??
              post['business_cover_url'] ??
              '')
          .toString();

      final String mediaUrl = (post['image'] ?? post['mediaUrl'] ?? '').toString();
      final bool isVideo = (post['mediaType'] == 'video') ||
          mediaUrl.toLowerCase().endsWith('.mp4') ||
          mediaUrl.toLowerCase().endsWith('.mov') ||
          mediaUrl.toLowerCase().endsWith('.webm');

      current.insert(0, {
        'id': postId,
        'businessId': post['businessId']?.toString() ?? '',
        'shopName': post['shopName'] ?? 'Kedai',
        'shopHandle': post['shopHandle'] ?? '',
        'shopAvatar': post['shopAvatar'] ?? post['shopData']?['logo_url'] ?? '',
        'category': post['category'] ?? 'Umum',
        'title': post['title'] ?? '',
        'caption': post['caption'] ?? '',
        'image': mediaUrl,
        'cover': coverCandidate,
        'thumbnail': coverCandidate,
        'mediaType': isVideo ? 'video' : (post['mediaType'] ?? 'image'),
        'likes': post['likes'] ?? 0,
        'comments': post['comments'] ?? 0,
        'ctaText': post['ctaText'] ?? 'AMBIL GILIRAN',
        'savedAt': DateTime.now().toIso8601String(),
      });
      nowSaved = true;
    }

    savedPostsNotifier.value = current;
    await _persistPosts(current);
    return nowSaved;
  }

  static Future<void> removeSavedPost(String postId) async {
    await init();
    final current = List<Map<String, dynamic>>.from(savedPostsNotifier.value);
    current.removeWhere((p) => p['id']?.toString() == postId);
    savedPostsNotifier.value = current;
    await _persistPosts(current);
  }

  static Future<void> updateSavedPosts(List<Map<String, dynamic>> posts) async {
    savedPostsNotifier.value = posts;
    await _persistPosts(posts);
  }

  static Future<void> _persistPosts(List<Map<String, dynamic>> posts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_postsKey, jsonEncode(posts));
    } catch (e) {
      debugPrint('[SavedService] Gagal menyimpan senarai hantaran: $e');
    }
  }
}
