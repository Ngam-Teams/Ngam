import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/constants.dart';

// ============================================================
// Ngam App — Servis Supabase
// Pusat kawalan utama untuk panggil Supabase
// ============================================================

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  /// Setup Supabase — panggil benda ni kat main.dart sebelum runApp
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }

  /// Update password user yang tengah login sekarang
  /// Return error text kalau fail, return null kalau berjaya
  static Future<String?> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // Log masuk balik kejap (Supabase perlukan session on-the-spot baru jalan)
      await client.auth.updateUser(UserAttributes(password: newPassword));
      return null;
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  /// Update nama display dengan nombor fon kat table profiles
  static Future<String?> updateProfile({
    required String userId,
    String? name,
    String? phone,
    String? avatarUrl,
    String? bio,
    String? gender,
    DateTime? birthDate,
    String? address,
    double? addressLat,
    double? addressLng,
    String? fcmToken,
    String? qrCodeUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['user_name'] = name;
      if (phone != null) updates['user_phone'] = phone;
      if (avatarUrl != null) updates['user_avatar_url'] = avatarUrl;
      if (bio != null) updates['user_bio'] = bio;
      if (gender != null) updates['user_gender'] = gender;
      if (birthDate != null) updates['user_birth_date'] = "${birthDate.year}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}";
      if (address != null) updates['user_address'] = address;
      if (addressLat != null) updates['user_address_lat'] = addressLat;
      if (addressLng != null) updates['user_address_lng'] = addressLng;
      if (fcmToken != null) updates['user_fcm_token'] = fcmToken;
      if (qrCodeUrl != null) updates['user_qr_code_url'] = qrCodeUrl;
      if (updates.isEmpty) return null;

      await client.from('users').update(updates).eq('id', userId);
      return null;
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }
}
