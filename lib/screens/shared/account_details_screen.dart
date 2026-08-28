import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/glass_toast.dart';

class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({super.key});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _dobController;
  late TextEditingController _addressController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;

  DateTime? _selectedDob;
  bool _isLoading = false;
  bool _obscureCurrentPass = true;
  bool _obscureNewPass = true;
  bool _isUploadingAvatar = false;
  bool _isUploadingQrCode = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.userName ?? '');
    _emailController = TextEditingController(text: user?.userEmail ?? '');
    _phoneController = TextEditingController(text: user?.userPhone ?? '');
    _selectedDob = user?.userBirthDate;
    _dobController = TextEditingController(
      text: _selectedDob != null ? DateFormat('dd MMM yyyy').format(_selectedDob!) : '',
    );
    _addressController = TextEditingController(text: user?.userAddress ?? '');
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: isDark
            ? ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFF42A5F5),
                  onPrimary: Colors.white,
                  surface: Color(0xFF1E1E2C),
                  onSurface: Colors.white,
                ),
              )
            : ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF2196F3),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black,
                ),
              ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = DateFormat('dd MMM yyyy').format(picked);
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final profileError = await context.read<AuthProvider>().updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        birthDate: _selectedDob,
        address: _addressController.text.trim(),
      );

      if (profileError != null && mounted) {
        setState(() => _isLoading = false);
        showGlassToast(context, profileError, isError: true);
        return;
      }

      final currentPass = _currentPasswordController.text.trim();
      final newPass = _newPasswordController.text.trim();

      if (newPass.isNotEmpty && currentPass.isNotEmpty) {
        final passError = await SupabaseService.updatePassword(
          currentPassword: currentPass,
          newPassword: newPass,
        );

        if (passError != null && mounted) {
          setState(() => _isLoading = false);
          showGlassToast(context, passError, isError: true);
          return;
        }
      }

      setState(() => _isLoading = false);

      if (mounted) {
        showGlassToast(context, "Account updated successfully!");
        Navigator.pop(context);
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (pickedFile != null && mounted) {
      setState(() => _isUploadingAvatar = true);
      final error = await context.read<AuthProvider>().uploadAvatar(File(pickedFile.path));
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        if (error != null) {
          showGlassToast(context, error, isError: true);
        } else {
          showGlassToast(context, "Profile picture updated!");
        }
      }
    }
  }

  Future<void> _pickAndUploadQrCode() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );

    if (pickedFile != null && mounted) {
      setState(() => _isUploadingQrCode = true);
      final error = await context.read<AuthProvider>().uploadQrCode(File(pickedFile.path));
      if (mounted) {
        setState(() => _isUploadingQrCode = false);
        if (error != null) {
          showGlassToast(context, error, isError: true);
        } else {
          showGlassToast(context, "QR Code updated!");
        }
      }
    }
  }

  String? _validateCurrentPassword(String? value) {
    if (_newPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
      return "Required to change password";
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (_currentPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
      return "Required to change password";
    }
    if (value == null || value.isEmpty) return null;
    final regex = RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*[\d\W]).{8,}$');
    if (!regex.hasMatch(value)) return "8+ chars, upper, lower & number/symbol";
    return null;
  }

  LiquidGlassSettings _getGlassSettings(bool isDark) {
    return LiquidGlassSettings(
      thickness: 0.1, blur: 15.0, refractiveIndex: 1.0, glassColor: Colors.transparent,
      lightAngle: 45.0, lightIntensity: isDark ? 0.1 : 0.2, ambientStrength: 1.0,
      saturation: 1.0, chromaticAberration: 0.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text("account.title".tr(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
        leading: IconButton(icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: isDark ? Colors.white70 : Colors.black54, size: 24), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          Positioned(top: -100, right: -50, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent.withValues(alpha: isDark ? 0.05 : 0.1)))),
          Positioned(bottom: 100, left: -50, child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purpleAccent.withValues(alpha: isDark ? 0.05 : 0.1)))),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Upload Gambar Profil ───
                    Center(
                      child: GestureDetector(
                        onTap: _isUploadingAvatar ? null : _pickAndUploadImage,
                        child: Stack(
                          children: [
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: isDark ? 0.2 : 0.6),
                                  width: 2,
                                ),
                                image: context.watch<AuthProvider>().user?.userAvatarUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(context.watch<AuthProvider>().user!.userAvatarUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: context.watch<AuthProvider>().user?.userAvatarUrl == null
                                  ? HugeIcon(
                                      icon: HugeIcons.strokeRoundedUser,
                                      color: isDark ? Colors.white54 : Colors.black54,
                                      size: 40,
                                    )
                                  : null,
                            ),
                            if (_isUploadingAvatar)
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black54,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(color: Colors.white),
                                  ),
                                ),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                                ),
                                child: const HugeIcon(
                                  icon: HugeIcons.strokeRoundedCamera01,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    Text("account.public_profile".tr(), style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const SizedBox(height: 12),

                    GlassContainer(
                      useOwnLayer: true, quality: GlassQuality.standard, shape: LiquidRoundedSuperellipse(borderRadius: 24.0), settings: _getGlassSettings(isDark),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(24.0), border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.6), width: 1.0)),
                        child: Column(
                          children: [
                            _buildPremiumInput(isDark: isDark, label: "account.full_name".tr(), controller: _nameController, icon: HugeIcons.strokeRoundedUser),
                            const SizedBox(height: 16),
                            _buildPremiumInput(isDark: isDark, label: "account.email_readonly".tr(), controller: _emailController, icon: HugeIcons.strokeRoundedMail01, keyboardType: TextInputType.emailAddress, readOnly: true),
                            const SizedBox(height: 16),
                            _buildPremiumInput(isDark: isDark, label: "account.phone".tr(), controller: _phoneController, icon: HugeIcons.strokeRoundedCall02, keyboardType: TextInputType.phone),
                            const SizedBox(height: 16),
                            _buildPremiumInput(isDark: isDark, label: "account.dob".tr(), controller: _dobController, icon: HugeIcons.strokeRoundedCalendar01, readOnly: true, onTap: _pickDate),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    Text("account.shipping_details".tr(), style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const SizedBox(height: 12),

                    GlassContainer(
                      useOwnLayer: true, quality: GlassQuality.standard, shape: LiquidRoundedSuperellipse(borderRadius: 24.0), settings: _getGlassSettings(isDark),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(24.0), border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.6), width: 1.0)),
                        child: Column(
                          children: [
                            _buildPremiumInput(isDark: isDark, label: "account.address".tr(), controller: _addressController, icon: HugeIcons.strokeRoundedLocation01, keyboardType: TextInputType.streetAddress),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    if (context.watch<AuthProvider>().isRunner) ...[
                      Text("RUNNER QR CODE", style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      GlassContainer(
                        useOwnLayer: true, quality: GlassQuality.standard, shape: LiquidRoundedSuperellipse(borderRadius: 24.0), settings: _getGlassSettings(isDark),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(24.0), border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.6), width: 1.0)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Upload your DuitNow / Bank QR Code so customers can pay you directly.", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13)),
                              const SizedBox(height: 16),
                              Center(
                                child: GestureDetector(
                                  onTap: _isUploadingQrCode ? null : _pickAndUploadQrCode,
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 140,
                                        height: 140,
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: isDark ? 0.2 : 0.6),
                                            width: 2,
                                          ),
                                          image: context.watch<AuthProvider>().user?.userQrCodeUrl != null
                                              ? DecorationImage(
                                                  image: NetworkImage(context.watch<AuthProvider>().user!.userQrCodeUrl!),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: context.watch<AuthProvider>().user?.userQrCodeUrl == null
                                            ? HugeIcon(
                                                icon: HugeIcons.strokeRoundedQrCode01,
                                                color: isDark ? Colors.white54 : Colors.black54,
                                                size: 50,
                                              )
                                            : null,
                                      ),
                                      if (_isUploadingQrCode)
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(16),
                                              color: Colors.black54,
                                            ),
                                            child: const Center(
                                              child: CircularProgressIndicator(color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).primaryColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                                          ),
                                          child: const HugeIcon(
                                            icon: HugeIcons.strokeRoundedCamera01,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    Text("account.security".tr(), style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const SizedBox(height: 12),

                    GlassContainer(
                      useOwnLayer: true, quality: GlassQuality.standard, shape: LiquidRoundedSuperellipse(borderRadius: 24.0), settings: _getGlassSettings(isDark),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(24.0), border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.6), width: 1.0)),
                        child: Column(
                          children: [
                            _buildPremiumInput(
                              isDark: isDark, label: "account.current_password".tr(), controller: _currentPasswordController, icon: HugeIcons.strokeRoundedLockPassword,
                              isPassword: true, obscureText: _obscureCurrentPass, onToggleObscure: () => setState(() => _obscureCurrentPass = !_obscureCurrentPass),
                              validator: _validateCurrentPassword,
                            ),
                            const SizedBox(height: 16),
                            _buildPremiumInput(
                              isDark: isDark, label: "account.new_password".tr(), controller: _newPasswordController, icon: HugeIcons.strokeRoundedLockKey,
                              isPassword: true, obscureText: _obscureNewPass, onToggleObscure: () => setState(() => _obscureNewPass = !_obscureNewPass),
                              validator: _validateNewPassword,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    GestureDetector(
                      onTap: _isLoading ? null : _saveChanges,
                      child: Container(
                        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1976D2)]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))]),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text("account.save_changes".tr(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumInput({required bool isDark, required String label, required TextEditingController controller, required dynamic icon, TextInputType keyboardType = TextInputType.text, bool isPassword = false, bool obscureText = false, VoidCallback? onToggleObscure, String? Function(String?)? validator, bool readOnly = false, VoidCallback? onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(14)),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            readOnly: readOnly,
            onTap: onTap,
            style: TextStyle(color: isDark ? (readOnly ? Colors.white54 : Colors.white) : (readOnly ? Colors.black54 : Colors.black87), fontWeight: FontWeight.w600, fontSize: 14),
            validator: validator ?? (value) => value == null || value.isEmpty && !readOnly ? "Required" : null,
            decoration: InputDecoration(
              prefixIcon: Padding(padding: const EdgeInsets.only(right: 14.0), child: HugeIcon(icon: icon, color: Colors.grey, size: 20)),
              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              border: InputBorder.none,
              errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
              suffixIcon: isPassword ? IconButton(
                icon: HugeIcon(icon: obscureText ? HugeIcons.strokeRoundedViewOff : HugeIcons.strokeRoundedView, color: Colors.grey, size: 20),
                onPressed: onToggleObscure,
              ) : null,
            ),
          ),
        ),
      ],
    );
  }
}
