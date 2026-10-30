import '../../widgets/glass_nav_button.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  late TextEditingController _displayNameController;
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
    final authUser = Supabase.instance.client.auth.currentUser;
    final initialDisplayName = authUser?.userMetadata?['display_name'] ??
        authUser?.userMetadata?['nickname'] ??
        (user?.userName != null && user!.userName!.contains(' ')
            ? user.userName!.split(' ').first
            : (user?.userName ?? ''));

    _nameController = TextEditingController(text: user?.userName ?? '');
    _displayNameController =
        TextEditingController(text: initialDisplayName.toString());
    _emailController = TextEditingController(text: user?.userEmail ?? '');
    _phoneController = TextEditingController(text: user?.userPhone ?? '');
    _selectedDob = user?.userBirthDate;
    _dobController = TextEditingController(
      text: _selectedDob != null
          ? DateFormat('dd MMM yyyy').format(_selectedDob!)
          : '',
    );
    _addressController = TextEditingController(text: user?.userAddress ?? '');
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayNameController.dispose();
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

      // Simpan display name / nama panggilan ke metadata Supabase
      final customDisplayName = _displayNameController.text.trim();
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'display_name': customDisplayName}),
        );
      } catch (_) {}

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
        showGlassToast(context, "Maklumat akaun berjaya dikemas kini!");
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
      final error = await context
          .read<AuthProvider>()
          .uploadAvatar(File(pickedFile.path));
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        if (error != null) {
          showGlassToast(context, error, isError: true);
        } else {
          showGlassToast(context, "Gambar profil berjaya dikemas kini!");
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
      imageQuality: 85,
    );

    if (pickedFile != null && mounted) {
      setState(() => _isUploadingQrCode = true);
      final error = await context
          .read<AuthProvider>()
          .uploadQrCode(File(pickedFile.path));
      if (mounted) {
        setState(() => _isUploadingQrCode = false);
        if (error != null) {
          showGlassToast(context, error, isError: true);
        } else {
          showGlassToast(context, "Kod QR DuitNow berjaya dikemas kini!");
        }
      }
    }
  }

  String? _validateCurrentPassword(String? value) {
    if (_newPasswordController.text.isNotEmpty &&
        (value == null || value.isEmpty)) {
      return "Diperlukan untuk menukar kata laluan";
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (_currentPasswordController.text.isNotEmpty &&
        (value == null || value.isEmpty)) {
      return "Diperlukan untuk menukar kata laluan";
    }
    if (value == null || value.isEmpty) return null;
    final regex = RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*[\d\W]).{8,}$');
    if (!regex.hasMatch(value)) {
      return "Min. 8 aksara, huruf besar, kecil & nombor/simbol";
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authUser = context.watch<AuthProvider>().user;
    final isRunner = context.watch<AuthProvider>().isRunner;

    final bgColor = isDark ? const Color(0xFF0C0E17) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
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
        title: Text(
          "account.title".tr().isNotEmpty ? "account.title".tr() : "Butiran Akaun",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: -0.2,
            color: textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              onPressed: _isLoading ? null : _saveChanges,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                foregroundColor: const Color(0xFF38BDF8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF38BDF8),
                      ),
                    )
                  : const HugeIcon(
                      icon: HugeIcons.strokeRoundedCheckmarkBadge01,
                      color: Color(0xFF38BDF8),
                      size: 16,
                    ),
              label: Text(
                _isLoading ? "Menyimpan..." : "Simpan",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF38BDF8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          final heroCard = _buildProfileHeroCard(
            isDark: isDark,
            user: authUser,
            isRunner: isRunner,
          );

          final formSections = Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Maklumat Peribadi
                _buildPanel(
                  isDark: isDark,
                  title: "Maklumat Peribadi",
                  subtitle: "Nama penuh, paparan nama dan tarikh lahir akaun anda",
                  icon: HugeIcons.strokeRoundedUser,
                  child: Column(
                    children: [
                      _buildTextField(
                        isDark: isDark,
                        label: "Nama Penuh (Seperti Dalam IC) *",
                        hint: "cth. Muhammad Danial bin Razak",
                        controller: _nameController,
                        icon: HugeIcons.strokeRoundedUser,
                        validator: (val) => val == null || val.trim().isEmpty
                            ? "Nama penuh diperlukan"
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        isDark: isDark,
                        label: "Nama Panggilan / Display Name",
                        hint: "cth. Danial, Danny",
                        controller: _displayNameController,
                        icon: HugeIcons.strokeRoundedSmile,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        isDark: isDark,
                        label: "Alamat E-mel",
                        controller: _emailController,
                        icon: HugeIcons.strokeRoundedMail01,
                        keyboardType: TextInputType.emailAddress,
                        readOnly: true,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        isDark: isDark,
                        label: "Nombor Telefon",
                        hint: "cth. +60123456789",
                        controller: _phoneController,
                        icon: HugeIcons.strokeRoundedCall02,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        isDark: isDark,
                        label: "Tarikh Lahir",
                        hint: "Pilih tarikh lahir anda",
                        controller: _dobController,
                        icon: HugeIcons.strokeRoundedCalendar01,
                        readOnly: true,
                        onTap: _pickDate,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 2. Alamat & Lokasi
                _buildPanel(
                  isDark: isDark,
                  title: "Alamat Penghantaran",
                  subtitle: "Alamat utama untuk menerima pesanan dan barangan",
                  icon: HugeIcons.strokeRoundedLocation01,
                  child: Column(
                    children: [
                      _buildTextField(
                        isDark: isDark,
                        label: "Alamat Premis / Rumah",
                        hint: "cth. No 12, Jalan Indah 3, Taman Maju",
                        controller: _addressController,
                        icon: HugeIcons.strokeRoundedLocation01,
                        keyboardType: TextInputType.streetAddress,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),

                if (isRunner) ...[
                  const SizedBox(height: 24),
                  // 3. Kod QR DuitNow Runner
                  _buildPanel(
                    isDark: isDark,
                    title: "Kod QR DuitNow Runner",
                    subtitle:
                        "Pelanggan boleh membuat bayaran terus ke akaun bank anda",
                    icon: HugeIcons.strokeRoundedQrCode,
                    child: _buildRunnerQrSection(isDark, authUser),
                  ),
                ],

                const SizedBox(height: 24),

                // 4. Keselamatan & Kata Laluan
                _buildPanel(
                  isDark: isDark,
                  title: "Keselamatan & Kata Laluan",
                  subtitle:
                        "Tukar kata laluan akaun anda (biarkan kosong jika tidak mahu ubah)",
                  icon: HugeIcons.strokeRoundedShield01,
                  child: Column(
                    children: [
                      _buildTextField(
                        isDark: isDark,
                        label: "Kata Laluan Semasa",
                        hint: "Masukkan kata laluan semasa anda",
                        controller: _currentPasswordController,
                        icon: HugeIcons.strokeRoundedLockPassword,
                        isPassword: true,
                        obscureText: _obscureCurrentPass,
                        onToggleObscure: () => setState(
                            () => _obscureCurrentPass = !_obscureCurrentPass),
                        validator: _validateCurrentPassword,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        isDark: isDark,
                        label: "Kata Laluan Baharu",
                        hint: "Min. 8 aksara (huruf besar, kecil & simbol)",
                        controller: _newPasswordController,
                        icon: HugeIcons.strokeRoundedLockKey,
                        isPassword: true,
                        obscureText: _obscureNewPass,
                        onToggleObscure: () => setState(
                            () => _obscureNewPass = !_obscureNewPass),
                        validator: _validateNewPassword,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // Butang Simpan Besar (Mobile)
                Container(
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF0284C7)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.2,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedFloppyDisk,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Simpan Semua Perubahan",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );

          if (isWide) {
            // Dual Column Responsive Tablet / Desktop View
            final leftWidth = (constraints.maxWidth * 0.35).clamp(320.0, 420.0);
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: leftWidth,
                    child: heroCard,
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: formSections,
                  ),
                ],
              ),
            );
          }

          // Mobile View
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heroCard,
                const SizedBox(height: 24),
                formSections,
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Hero Profile Card (Twitter/Ngam Business Overlapping Style) ───
  Widget _buildProfileHeroCard({
    required bool isDark,
    required dynamic user,
    required bool isRunner,
  }) {
    final avatarUrl = user?.userAvatarUrl as String?;
    final userName = user?.userName ?? 'Pengguna Ngam';
    final userEmail = user?.userEmail ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131522) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top Cover Banner Stack
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  height: 110,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 42),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF1E293B),
                        Color(0xFF0F172A),
                        Color(0xFF0369A1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.25),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.5),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HugeIcon(
                                icon: isRunner
                                    ? HugeIcons.strokeRoundedDeliveryBox01
                                    : HugeIcons.strokeRoundedUser,
                                color: isRunner
                                    ? const Color(0xFF38BDF8)
                                    : const Color(0xFF34D399),
                                size: 12,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isRunner ? "Runner Sah" : "Pelanggan",
                                style: TextStyle(
                                  color: isRunner
                                      ? const Color(0xFF38BDF8)
                                      : const Color(0xFF34D399),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Overlapping Avatar with Edit Badge
                Positioned(
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _isUploadingAvatar ? null : _pickAndUploadImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? const Color(0xFF131522)
                                : Colors.white,
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF131522)
                                  : Colors.white,
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFE2E8F0),
                              border: Border.all(
                                color: const Color(0xFF38BDF8)
                                    .withValues(alpha: 0.7),
                                width: 2,
                              ),
                              image: (avatarUrl != null && avatarUrl.isNotEmpty)
                                  ? DecorationImage(
                                      image: NetworkImage(avatarUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: (avatarUrl == null || avatarUrl.isEmpty)
                                ? const Center(
                                    child: HugeIcon(
                                      icon: HugeIcons.strokeRoundedUser,
                                      color: Color(0xFF38BDF8),
                                      size: 36,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        if (_isUploadingAvatar)
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black54,
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        else
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF131522)
                                      : Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const HugeIcon(
                                icon: HugeIcons.strokeRoundedCamera01,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Profile Names & User Info
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                children: [
                  Text(
                    userName,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (userEmail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      userEmail,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        fontSize: 12.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Reusable Panel Container (Ngam Business Design) ───
  Widget _buildPanel({
    required bool isDark,
    required String title,
    required String subtitle,
    required dynamic icon,
    required Widget child,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF131522).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.28),
                      ),
                    ),
                    child: HugeIcon(
                      icon: icon,
                      color: const Color(0xFF38BDF8),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : const Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              child,
            ],
          ),
        ),
      ),
    );
  }

  // ─── Modern Input Field (Ngam Business Design) ───
  Widget _buildTextField({
    required bool isDark,
    required String label,
    required TextEditingController controller,
    required dynamic icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    String? Function(String?)? validator,
    VoidCallback? onTap,
    int maxLines = 1,
  }) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? Colors.white54 : const Color(0xFF64748B);
    final inputBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);
    final inputBorder = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (readOnly) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Kekal / Tidak Boleh Ubah',
                  style: TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          obscureText: obscureText,
          onTap: onTap,
          maxLines: maxLines,
          style: TextStyle(
            color: readOnly ? textSecondary : textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.white24 : Colors.black26,
              fontSize: 13,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: HugeIcon(
                icon: icon,
                color: const Color(0xFF38BDF8),
                size: 19,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 46),
            suffixIcon: isPassword
                ? IconButton(
                    icon: HugeIcon(
                      icon: obscureText
                          ? HugeIcons.strokeRoundedViewOff
                          : HugeIcons.strokeRoundedView,
                      color: textSecondary,
                      size: 19,
                    ),
                    onPressed: onToggleObscure,
                  )
                : null,
            filled: true,
            fillColor: inputBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Runner QR Code Upload Box ───
  Widget _buildRunnerQrSection(bool isDark, dynamic user) {
    final qrUrl = user?.userQrCodeUrl as String?;

    return Center(
      child: GestureDetector(
        onTap: _isUploadingQrCode ? null : _pickAndUploadQrCode,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(14),
                      image: (qrUrl != null && qrUrl.isNotEmpty)
                          ? DecorationImage(
                              image: NetworkImage(qrUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (qrUrl == null || qrUrl.isEmpty)
                        ? const Center(
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedQrCode01,
                              color: Color(0xFF38BDF8),
                              size: 48,
                            ),
                          )
                        : null,
                  ),
                  if (_isUploadingQrCode)
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedCamera01,
                    color: Color(0xFF38BDF8),
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    qrUrl != null && qrUrl.isNotEmpty
                        ? "Tukar Kod QR"
                        : "Muat Naik Kod QR",
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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
}
