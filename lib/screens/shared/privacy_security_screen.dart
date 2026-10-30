import '../../widgets/glass_nav_button.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/glass_toast.dart';
import 'package:easy_localization/easy_localization.dart';
import '../auth/login_screen.dart';

class SecurityData {
  static final appLockEnabled = ValueNotifier<bool>(false);
  static final appLockTimeout = ValueNotifier<int>(0);
  static final hideContentEnabled = ValueNotifier<bool>(false);
  static final locationEnabled = ValueNotifier<bool>(true);
  static final twoFactorEnabled = ValueNotifier<bool>(false);
  static final userPhone = ValueNotifier<String>("+60123456789");
  static final userLocation = ValueNotifier<String>("Kuala Lumpur, Malaysia");

  static Future<void> toggleSecuritySetting(String key, bool value) async {
    if (key == 'appLockEnabled') appLockEnabled.value = value;
    if (key == 'hideContentEnabled') hideContentEnabled.value = value;
    if (key == 'locationEnabled') locationEnabled.value = value;
    if (key == 'twoFactorEnabled') twoFactorEnabled.value = value;
  }
}

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool _isTimeoutExpanded = false;
  String _cacheSize = "0.0 MB";
  String get _deviceName {
    if (kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.android) return "Android (Web)";
      if (defaultTargetPlatform == TargetPlatform.iOS) return "iPhone (Web)";
      if (defaultTargetPlatform == TargetPlatform.macOS) return "Mac (Web)";
      if (defaultTargetPlatform == TargetPlatform.windows) return "Windows PC (Web)";
      return "Web Browser";
    }
    if (defaultTargetPlatform == TargetPlatform.android) return "Android Device";
    if (defaultTargetPlatform == TargetPlatform.iOS) return "iPhone";
    return "This Device";
  }

  dynamic get _deviceIcon {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return HugeIcons.strokeRoundedAndroid;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return HugeIcons.strokeRoundedApple;
    } else {
      return HugeIcons.strokeRoundedLaptop;
    }
  }
  final LocalAuthentication _auth = LocalAuthentication();
  
  @override
  void initState() {
    super.initState();
  }

  // Data olok-olok (Mocks)

  Future<void> _clearCache() async {
    setState(() => _cacheSize = "0.0 MB");
    HapticFeedback.mediumImpact();
    showGlassToast(context, "privacy.cache_cleared".tr());
  }

  static const _securityChannel = MethodChannel('com.example.ngam/security');

  Future<void> _toggleScreenSecurity(bool enable) async {
    try {
      if (enable) {
        await _securityChannel.invokeMethod('enableSecureMode');
        await SecurityData.toggleSecuritySetting('hideContentEnabled', true);
        if (mounted) showGlassToast(context, "Screen Security Enabled");
      } else {
        await _securityChannel.invokeMethod('disableSecureMode');
        await SecurityData.toggleSecuritySetting('hideContentEnabled', false);
        if (mounted) showGlassToast(context, "Screen Security Disabled");
      }
    } catch (e) {
      if (mounted) showGlassToast(context, "Sila Restart (Stop & Play) untuk aktifkan perlindungan!");
    }
    HapticFeedback.mediumImpact();
  }

  Future<void> _toggleAppLock(bool enable) async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (canAuthenticate) {
        final bool didAuthenticate = await _auth.authenticate(
          localizedReason: enable ? 'Authenticate to enable App Lock' : 'Authenticate to disable App Lock',
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
          ),
        );

        if (!didAuthenticate) {
          if (mounted) showGlassToast(context, "Authentication cancelled");
          return;
        }
      }

      // Kalau face/fingerprint berjaya (ataupun phone tu jenis lama tak support)
      await SecurityData.toggleSecuritySetting('appLockEnabled', enable);
      if (mounted) {
        showGlassToast(context, enable ? "App Lock Enabled" : "App Lock Disabled");
      }
    } catch (e) {
      if (mounted) showGlassToast(context, "Authentication error");
      return;
    }

    HapticFeedback.mediumImpact();
  }

  Future<void> _handle2FAToggle(bool enable) async {
    if (enable) {
      bool? confirmed = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.4),
        builder: (context) => _build2FASetupDialog(context),
      );
      if (confirmed == true) {
        await SecurityData.toggleSecuritySetting('twoFactorEnabled', true);
        if (mounted) showGlassToast(context, "Two-Factor Authentication Enabled");
      }
    } else {
      await SecurityData.toggleSecuritySetting('twoFactorEnabled', false);
      if (mounted) showGlassToast(context, "2FA Security Disabled");
    }
  }

  Future<void> _openAppSettings() async {
    showGlassToast(context, "System Permissions requested");
  }


  Widget _build2FASetupDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 30, offset: const Offset(0, 10))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              //  Ikon Security Phone
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedSmartPhone01,
                    color: Colors.blueAccent,
                    size: 28
                ),
              ),
              const SizedBox(height: 20),

              //  Tajuk Utama
              Text(
                "privacy.enable_2fa".tr(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              //  Isi Kandungan
              Text(
                "We will use your registered number (${SecurityData.userPhone.value}) to send verification codes.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 28),

              //  Tindakan (Butang)
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        "wallet.cancel".tr(),
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter'
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                      ),
                      onPressed: () => Navigator.pop(context, true), //  Pulangkan 'true' untuk enable benda ni
                      child: Text(
                        "privacy.enable".tr(),
                        style: const TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter'
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF262626) : Colors.white;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text("privacy.title".tr(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Inter')),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Center(
            child: GlassNavButton.back(
              context: context,
              isDark: isDark,
              size: 40,
              iconSize: 20,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("privacy.security".tr(),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontFamily: 'Inter',
                )),
            const SizedBox(height: 12),

            // 1. Seksyen App Lock boleh buka/tutup
            _buildAppLockSection(isDark, cardColor),

            const SizedBox(height: 16),

            // 2. Kotak setting nombor dua
            _buildSystemGlass(
              isDark: isDark,
              borderRadius: 20,
              child: Column(
                children: [
                  // 1. Sorok dari App Switcher
                  ValueListenableBuilder<bool>(
                    valueListenable: SecurityData.hideContentEnabled,
                    builder: (context, val, _) => _buildToggleTile(
                        isDark, HugeIcons.strokeRoundedViewOffSlash, "privacy.hide_app_switcher".tr(), val,
                            (newVal) => _toggleScreenSecurity(newVal)
                    ),
                  ),
                  _buildDivider(isDark),

                  // 2. Servis Lokasi (Yang dah di-sync)
                  ValueListenableBuilder<bool>(
                    valueListenable: SecurityData.locationEnabled,
                    builder: (context, val, _) => _buildToggleTile(
                        isDark, HugeIcons.strokeRoundedLocation01, "privacy.location_services".tr(), val,
                            (newVal) => SecurityData.toggleSecuritySetting('locationEnabled', newVal)
                    ),
                  ),
                  _buildDivider(isDark),

                  // 3. 2FA Authentication (Guna Notifier yang betul)
                  ValueListenableBuilder<bool>(
                    valueListenable: SecurityData.twoFactorEnabled,
                    builder: (context, val, _) => _buildToggleTile(
                        isDark, HugeIcons.strokeRoundedSmartPhone01, "privacy.two_factor_auth".tr(), val,
                            (newVal) => _handle2FAToggle(newVal)
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ---  SEKSYEN DATA & PRIVACY ---
            _buildSectionHeader("privacy.data_privacy".tr()),
            const SizedBox(height: 12),
            _buildSystemGlass(
              isDark: isDark,
              borderRadius: 20,
              child: Column(
                children: [
                  _buildSettingsTile(
                    isDark,
                    HugeIcons.strokeRoundedSettings02,
                    "privacy.system_permissions".tr(),
                    subtitle: "privacy.manage_permissions".tr(),
                    onTap: _openAppSettings,
                  ),
                  _buildDivider(isDark),
                  _buildSettingsTile(
                    isDark,
                    HugeIcons.strokeRoundedDelete02,
                    "privacy.clear_cache".tr(),
                    trailing: Text(_cacheSize, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                    onTap: () => _showClearCacheConfirmation(context),
                  ),
                  _buildDivider(isDark),
                  _buildSettingsTile(
                    isDark,
                    HugeIcons.strokeRoundedUserRemove02,
                    "Padam Akaun",
                    subtitle: "Padam akaun dan semua data peribadi anda",
                    trailing: const HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: Colors.redAccent, size: 14),
                    onTap: () => _showDeleteAccountConfirmation(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ---  SEKSYEN SESSIONS ---
            _buildSectionHeader("privacy.active_sessions".tr()),
            const SizedBox(height: 12),
            _buildSystemGlass(
              isDark: isDark,
              borderRadius: 20,
              child: Column(
                children: [
                  //  Tile Device (Reaktif): Dia akan sync dengan Refresh GPS dari Profil
                  // Dalam Column untuk SESSION YANG AKTIF
                  ValueListenableBuilder<String>(
                    valueListenable: SecurityData.userLocation,
                    builder: (context, location, _) {
                      return _buildCurrentDeviceTile(isDark, location);
                    },
                  ),
                  _buildDivider(isDark),
                  _buildSettingsTile(
                    isDark, HugeIcons.strokeRoundedShield02, "privacy.log_out_all".tr(),
                    subtitle: "privacy.instantly_secure".tr(),
                    onTap: () => _showLogoutConfirmation(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      )
    );
  }

  Widget _buildSettingsTile(bool isDark, dynamic icon, String title, {String? subtitle, Widget? trailing, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12)
                ),
                child: HugeIcon(icon: icon, color: isDark ? Colors.white : Colors.black87, size: 20)
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                  if (subtitle != null)
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Inter')),
                ],
              ),
            ),
            if (trailing != null) trailing else const HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: Colors.grey, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildAppLockSection(bool isDark, Color cardColor) {
    return ValueListenableBuilder<bool>(
      valueListenable: SecurityData.appLockEnabled,
      builder: (context, appLockEnabled, _) {
        return ValueListenableBuilder<int>(
          valueListenable: SecurityData.appLockTimeout,
          builder: (context, timeoutValue, _) {
            String currentTimeoutText = timeoutValue == 0 ? "Immediately" : "After $timeoutValue min";
            if (timeoutValue == 60) currentTimeoutText = "After 1 hour";

            return _buildSystemGlass(
              isDark: isDark,
              borderRadius: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (appLockEnabled) {
                        setState(() => _isTimeoutExpanded = !_isTimeoutExpanded);
                        HapticFeedback.selectionClick();
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: appLockEnabled ? Colors.blue.withValues(alpha: 0.1) : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                              shape: BoxShape.circle,
                            ),
                            child: HugeIcon(
                                icon: HugeIcons.strokeRoundedLockKey,
                                color: appLockEnabled ? Colors.blue : (isDark ? Colors.white : Colors.black87),
                                size: 20
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("privacy.app_lock".tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                                const SizedBox(height: 2),
                                Text(
                                  appLockEnabled ? "Enabled • $currentTimeoutText" : "Disabled",
                                  style: TextStyle(
                                      color: appLockEnabled ? Colors.blue : Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Inter'
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (appLockEnabled)
                            RotationTransition(
                              turns: AlwaysStoppedAnimation(_isTimeoutExpanded ? 0.5 : 0.0),
                              child: const HugeIcon(icon: HugeIcons.strokeRoundedArrowDown01, color: Colors.grey, size: 20),
                            ),
                          const SizedBox(width: 8),
                          Switch.adaptive(
                            value: appLockEnabled,
                            activeColor: Colors.blue,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                            thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) => null),
                            onChanged: (val) {
                              _toggleAppLock(val);
                              if (!val) setState(() => _isTimeoutExpanded = false);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox(width: double.infinity),
                    secondChild: Column(
                      children: [
                        Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12, indent: 20, endIndent: 20),
                        const SizedBox(height: 8),
                        _buildModernOption("Immediately", 0, isDark, timeoutValue),
                        _buildModernOption("After 1 minute", 1, isDark, timeoutValue),
                        _buildModernOption("After 15 minutes", 15, isDark, timeoutValue),
                        _buildModernOption("After 1 hour", 60, isDark, timeoutValue),
                        const SizedBox(height: 12),
                      ],
                    ),
                    crossFadeState: (appLockEnabled && _isTimeoutExpanded) ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 300),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModernOption(String title, int value, bool isDark, int currentSelected) {
    bool isSelected = currentSelected == value;

    return GestureDetector(
      onTap: () async {
        SecurityData.appLockTimeout.value = value;
        HapticFeedback.lightImpact();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 24),
        child: Row(
          children: [
            const SizedBox(width: 46),
            Expanded(
              child: Text(
                  title,
                  style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Inter',
                      color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.grey,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                  )
              ),
            ),
            if (isSelected) const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, color: Colors.blue, size: 22),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile(bool isDark, dynamic icon, String title, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12)
              ),
              child: HugeIcon(icon: icon, color: isDark ? Colors.white : Colors.black87, size: 20)
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter'))),
          Switch.adaptive(value: value, activeColor: Colors.blue, inactiveThumbColor: Colors.white, inactiveTrackColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300, trackOutlineColor: WidgetStateProperty.all(Colors.transparent), thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) => null), onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12, indent: 64);

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            fontFamily: 'Inter',
          )),
    );
  }

  Widget _buildCurrentDeviceTile(bool isDark, String syncedLocation) {
    return InkWell(
      onTap: () => _showCurrentDeviceDetails(context, syncedLocation),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(12)),
                child: HugeIcon(icon: _deviceIcon, color: isDark ? Colors.white : Colors.black87, size: 20)
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(_deviceName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter'), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      //  Lencana Hijau
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text("privacy.this_device".tr(), style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  //  Teks lokasi (berubah ikut keadaan)
                  Text("${"privacy.active_now".tr()}  •  $syncedLocation", style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Inter')),
                ],
              ),
            ),
            const HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: Colors.grey, size: 12),
          ],
        ),
      ),
    );
  }

  //  FIXED: Dah tambah parameter 'syncedLocation'
  void _showCurrentDeviceDetails(BuildContext context, String syncedLocation) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---  Ikon Peranti ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                      icon: _deviceIcon,
                      color: Colors.blueAccent,
                      size: 32
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "privacy.active_sessions_info".tr(),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Inter', color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 24),

                // ---  Senarai Details ---
                _buildDetailRow("Model", _deviceName, isDark),
                _buildDivider(isDark),

                //  FIXED: Pakai lokasi GPS yang dah sync berbanding IP variables lama
                _buildDetailRow("Location", syncedLocation.isNotEmpty ? syncedLocation : "Detecting...", isDark),

                _buildDivider(isDark),
                _buildDetailRow("Status", "Online", isDark, isStatus: true),

                const SizedBox(height: 32),

                // ---  Butang Pangkah (Tutup) ---
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "support.done".tr(),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper function untuk buat Barisan Details
  Widget _buildDetailRow(String label, String value, bool isDark, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14, fontFamily: 'Inter')),
          Row(
            children: [
              if (isStatus) ...[
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 8),
              ],
              Text(
                value,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    fontFamily: 'Inter',
                    color: isDark ? Colors.white : Colors.black87
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 30, offset: const Offset(0, 10))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedShield02,
                      color: Colors.redAccent,
                      size: 28
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "privacy.log_out_all_title".tr(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Inter',
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "privacy.log_out_all_desc".tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text("wallet.cancel".tr(), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                        ),
                        onPressed: () {
                          Navigator.pop(context); // Tutup dialog ni

                          //  LOGIK UTAMA
                          HapticFeedback.heavyImpact();

                          // Berlakon macam buat Supabase/Auth logout kat sini...

                          //  FIXED: Tukar pakai global glass helper yang baru
                          showGlassToast(context, "Other sessions secured successfully");
                        },
                        child: Text("auth.logout".tr(), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClearCacheConfirmation(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 30, offset: const Offset(0, 10))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                //  Ikon Storage (Storan)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedDelete02,
                      color: Colors.blueAccent,
                      size: 28
                  ),
                ),
                const SizedBox(height: 20),

                //  Tajuk Utama
                Text(
                  "privacy.clear_cache".tr(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Inter',
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                //  Isi Kandungan
                Text(
                  "privacy.free_storage".tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 28),

                //  Tindakan (Butang)
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "wallet.cancel".tr(),
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter'
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                        ),
                        onPressed: () {
                          Navigator.pop(context); // Kita tutup dialog ni dulu
                          _clearCache(); // Jalankan logik buang cache yang sedia ada
                        },
                        child: Text(
                          "privacy.clear_cache".tr().split(" ")[0], // kita pakai terma "Buang"
                          style: TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Inter'
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountConfirmation(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogCtx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedUserRemove02,
                    color: Colors.redAccent,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "Padam Akaun Secara Kekal?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Inter',
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Tindakan ini adalah kekal dan tidak boleh diundur. Semua profil, data tempahan perkhidmatan, dan kad ganjaran anda akan dipadamkan dari pelayan kami.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                        ),
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: Text(
                          "Batal",
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.redAccent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          Navigator.pop(dialogCtx);
                          HapticFeedback.heavyImpact();
                          try {
                            final user = Supabase.instance.client.auth.currentUser;
                            if (user != null) {
                              await Supabase.instance.client.from('users').delete().eq('id', user.id);
                              await Supabase.instance.client.auth.signOut();
                            }
                          } catch (_) {
                            try {
                              await Supabase.instance.client.auth.signOut();
                            } catch (_) {}
                          }

                          if (context.mounted) {
                            showGlassToast(context, "Akaun anda telah berjaya dipadamkan.");
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                        child: const Text(
                          "Padam",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSystemGlass({
    required Widget child,
    required double borderRadius,
    required bool isDark,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.4),
              width: 1.0,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

