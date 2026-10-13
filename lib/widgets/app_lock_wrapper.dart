import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:local_auth/local_auth.dart';
import '../screens/shared/privacy_security_screen.dart';
import '../services/push_service.dart';

class AppLockWrapper extends StatefulWidget {
  final Widget child;

  const AppLockWrapper({super.key, required this.child});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper> with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _isAuthenticating = false;
  DateTime? _pausedTime;
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!SecurityData.appLockEnabled.value) return;
    if (_isAuthenticating) return;
    // Bypass app lock bila user sedang reply dari notification
    if (isReplyingFromNotification.value) return;

    if (state == AppLifecycleState.paused) {
      _pausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedTime != null) {
        final timeoutMinutes = SecurityData.appLockTimeout.value;
        final elapsed = DateTime.now().difference(_pausedTime!).inMinutes;

        _pausedTime = null; // Clear cepat-cepat supaya dia tak loop berkali-kali

        if (elapsed >= timeoutMinutes) {
          setState(() {
            _isLocked = true;
          });
          _authenticate();
        }
      }
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    
    try {
      _isAuthenticating = true;
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (canAuthenticate) {
        final bool didAuthenticate = await _auth.authenticate(
          localizedReason: 'Please authenticate to unlock Ngam',
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
          ),
        );

        if (didAuthenticate) {
          setState(() {
            _isLocked = false;
          });
        }
      } else {
        // Kalau phone tu takde fingerprint/face id, kita lepaskan je buat masa ni.
        setState(() {
          _isLocked = false;
        });
      }
    } catch (e) {
      debugPrint("Auth error: $e");
    } finally {
      _isAuthenticating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (_isLocked)
          Positioned.fill(
            child: _buildLockScreen(),
          ),
      ],
    );
  }

  Widget _buildLockScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Material(
      color: isDark ? const Color(0xFF13131A) : Colors.white,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: isDark ? Colors.black.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedLockKey,
                  color: Colors.blue,
                  size: 64,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "App Locked",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Verify your identity to continue using Ngam",
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: _authenticate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.fingerprint),
                label: const Text("Unlock"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
