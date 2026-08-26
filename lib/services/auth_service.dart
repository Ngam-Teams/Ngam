import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart' as g_sign_in;
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'supabase_service.dart';

// ============================================================
// Ngam App — Servis Auth
// Handle pendaftaran, login, logout dengan info profil
// ============================================================

class AuthService {
  static final _client = SupabaseService.client;

  static String _generateRandomString(int length) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Sign up a new user with email/password and insert profile into users table
  static Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
  }) async {
    // 1. Buat akaun kat Supabase Auth dulu
    final authResponse = await _client.auth.signUp(
      email: email,
      password: password,
    );

    if (authResponse.user == null) {
      throw Exception('Registration failed. Please try again.');
    }

    final userId = authResponse.user!.id;

    // 2. Lepas tu sumbat profil dia masuk table 'users'
    final userData = {
      'id': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'created_at': DateTime.now().toIso8601String(),
    };

    await _client.from(DbTable.users).insert(userData);

    return UserModel.fromJson(userData);
  }

  /// Sign in with email and password
  static Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final authResponse = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (authResponse.user == null) {
      throw Exception('Login failed. Invalid credentials.');
    }

    // Tarik info profil dari table 'users'
    final userId = authResponse.user!.id;
    final response = await _client
        .from(DbTable.users)
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) {
      // User wujud kat auth.users tapi takde profile di public.users
      final newProfile = {
        'id': userId,
        'email': email,
        'name': email.split('@').first,
        'phone': 'N/A',
        'role': 'customer',
        'balance': 0,
        'rating': 5.0,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      await _client.from(DbTable.users).insert(newProfile);
      return UserModel.fromJson(newProfile);
    }

    return UserModel.fromJson(response);
  }

  /// Sign in with Google
  static Future<UserModel> signInWithGoogle() async {
    final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';
    final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '';

    // Setup benda-benda nak Google Sign In
    await g_sign_in.GoogleSignIn.instance.initialize(
      serverClientId: webClientId.isNotEmpty ? webClientId : null,
      clientId: iosClientId.isNotEmpty ? iosClientId : null,
    );

    final googleUser = await g_sign_in.GoogleSignIn.instance.authenticate();

    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw Exception('No ID Token found.');
    }

    final authResponse = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );

    if (authResponse.user == null) {
      throw Exception('Login failed. Could not authenticate with Google.');
    }

    final userId = authResponse.user!.id;
    
    // Check tengok user ni dah wujud tak kat table 'users'
    final response = await _client
        .from(DbTable.users)
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) {
      // User baru! Kita masukkan dia dalam public.users
      final userData = {
        'id': userId,
        'name': authResponse.user!.userMetadata?['full_name'] ?? 'Google User',
        'email': authResponse.user!.email,
        'phone': '',
        'role': 'customer', // Bagi role default untuk OAuth (social login)
          'created_at': DateTime.now().toIso8601String(),
        'avatar_url': authResponse.user!.userMetadata?['avatar_url'],
      };
      await _client.from(DbTable.users).insert(userData);
      return UserModel.fromJson(userData);
    }

    return UserModel.fromJson(response);
  }

  /// Sign out current user
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Get current logged-in user profile
  static Future<UserModel?> getCurrentUser() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;

    final userId = session.user.id;
    try {
      final response = await _client
          .from(DbTable.users)
          .select()
          .eq('id', userId)
          .single();
      return UserModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Update user role (for role switching)
  static Future<void> updateRole(String userId, String newRole) async {
    await _client
        .from(DbTable.users)
        .update({'role': newRole})
        .eq('id', userId);
  }


  /// Check if user is currently logged in
  static bool get isLoggedIn => _client.auth.currentSession != null;

  /// Sign in with Apple
  static Future<UserModel> signInWithApple() async {
    final rawNonce = _generateRandomString(32);
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = appleCredential.identityToken;
    if (idToken == null) {
      throw Exception('Could not find ID Token from Apple Sign In.');
    }

    final authResponse = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    if (authResponse.user == null) {
      throw Exception('Login failed. Could not authenticate with Apple.');
    }

    final userId = authResponse.user!.id;

    // Semak kalau user dah ada dalam table 'users'
    final existingUserRes = await _client
        .from(DbTable.users)
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (existingUserRes != null) {
      return UserModel.fromJson(existingUserRes);
    } else {
      // User baru (first time login guna Apple)
      String defaultName = appleCredential.givenName != null 
          ? ' '.trim()
          : 'Apple User';
      if (defaultName.isEmpty) defaultName = 'Apple User';

      final newProfile = {
        'id': userId,
        'email': authResponse.user!.email ?? '',
        'name': defaultName,
        'phone': 'N/A',
        'role': 'customer',
        'balance': 0,
        'rating': 5.0,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _client.from(DbTable.users).insert(newProfile);

      final createdUserRes = await _client
          .from(DbTable.users)
          .select()
          .eq('id', userId)
          .single();

      return UserModel.fromJson(createdUserRes);
    }
  }
}
