import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/push_service.dart';
import '../services/chat_service.dart';

// ============================================================
// Ngam App — Auth Provider
// Untuk control state auth dengan tukar role (customer/runner)
// ============================================================

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  String get userRole => _user?.role ?? 'customer';
  bool get isCustomer => userRole == 'customer';
  bool get isRunner => userRole == 'runner';

  /// Try to restore session on app start
  Future<void> initialize() async {
    _isInitializing = true;
    notifyListeners();

    try {
      _user = await AuthService.getCurrentUser();
      if (_user != null) {
        await PushService.saveTokenToSupabase(_user!.id);
        ChatService.prefetchChats(_user!.id); // Auto-fetch chats background
      }
    } catch (e) {
      _user = null;
    }

    _isInitializing = false;
    notifyListeners();
  }

  /// Sign up a new user
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await AuthService.signUp(
        email: email,
        password: password,
        name: name,
        phone: phone,
        role: role,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      String errorMessage = e.toString().replaceAll('Exception: ', '');
      if (errorMessage.toLowerCase().contains('already registered') || errorMessage.toLowerCase().contains('already exists')) {
        if (role == 'runner') {
          errorMessage = 'Emel ini telah didaftarkan. Sila log masuk dan pergi ke Profil > Runner untuk memohon.';
        } else {
          errorMessage = 'Emel ini telah didaftarkan. Sila log masuk ke akaun anda.';
        }
      }
      _error = errorMessage;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with email/password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await AuthService.signIn(
        email: email,
        password: password,
      );
      if (_user != null) {
        await PushService.saveTokenToSupabase(_user!.id);
        ChatService.prefetchChats(_user!.id); // Auto-fetch chats background
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await AuthService.signInWithGoogle();
      if (_user != null) {
        await PushService.saveTokenToSupabase(_user!.id);
        ChatService.prefetchChats(_user!.id); // Auto-fetch chats background
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('GoogleSignInExceptionCode.canceled') || errorMsg.contains('Account reauth failed')) {
        _error = 'Google Sign-In canceled or failed to authenticate.';
      } else {
        _error = errorMsg.replaceAll('Exception: ', '');
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    if (_user != null) {
      await PushService.clearTokenFromSupabase(_user!.id);
    }
    await AuthService.signOut();
    _user = null;
    _error = null;
    notifyListeners();
  }

  /// Switch user role between customer and runner
  Future<void> switchRole() async {
    if (_user == null) return;

    final newRole = _user!.role == 'customer' ? 'runner' : 'customer';

    try {
      await AuthService.updateRole(_user!.id, newRole);
      _user = _user!.copyWith(role: newRole);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to switch role';
      notifyListeners();
    }
  }

  /// Set role directly
  Future<void> setRole(String role) async {
    if (_user == null) return;

    try {
      await AuthService.updateRole(_user!.id, role);
      _user = _user!.copyWith(role: role);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update role';
      notifyListeners();
    }
  }

  /// Update profile details
  Future<String?> updateProfile({
    required String name,
    required String phone,
    String? bio,
    String? gender,
    DateTime? birthDate,
    String? address,
  }) async {
    if (_user == null) return 'User not logged in';
    try {
      final error = await SupabaseService.updateProfile(
        userId: _user!.id,
        name: name,
        phone: phone,
        bio: bio,
        gender: gender,
        birthDate: birthDate,
        address: address,
      );
      if (error == null) {
        _user = _user!.copyWith(
          name: name, 
          phone: phone,
          bio: bio,
          gender: gender,
          birthDate: birthDate,
          address: address,
        );
        notifyListeners();
      }
      return error;
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  /// Upload user avatar
  Future<String?> uploadAvatar(File imageFile) async {
    if (_user == null) return 'User not logged in';
    try {
      final String path = '${_user!.id}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage
          .from('avatars')
          .upload(path, imageFile, fileOptions: const FileOptions(cacheControl: '3600', upsert: true));

      final String publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(path);

      final error = await SupabaseService.updateProfile(
        userId: _user!.id,
        avatarUrl: publicUrl,
      );

      if (error == null) {
        _user = _user!.copyWith(avatarUrl: publicUrl);
        notifyListeners();
      }
      return error;
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  /// Upload runner QR Code
  Future<String?> uploadQrCode(File imageFile) async {
    if (_user == null) return 'User not logged in';
    try {
      final String path = '${_user!.id}/qrcode_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage
          .from('avatars') // Or create a new bucket 'qrcodes' if preferred, using 'avatars' for simplicity
          .upload(path, imageFile, fileOptions: const FileOptions(cacheControl: '3600', upsert: true));

      final String publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(path);

      final error = await SupabaseService.updateProfile(
        userId: _user!.id,
        qrCodeUrl: publicUrl,
      );

      if (error == null) {
        _user = _user!.copyWith(qrCodeUrl: publicUrl);
        notifyListeners();
      }
      return error;
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  /// Refresh user balance
  Future<void> refreshBalance() async {
    if (_user == null) return;
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('balance')
          .eq('id', _user!.id)
          .single();
      final newBalance = (response['balance'] as num?)?.toDouble() ?? 0.0;
      _user = _user!.copyWith(balance: newBalance);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh balance: $e');
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
