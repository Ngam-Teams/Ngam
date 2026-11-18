import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ngam/widgets/glass_box.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_data.dart';
import '../../services/app_update_service.dart';
import '../../services/support_ticket_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/glass_toast.dart';
import '../../widgets/glass_nav_button.dart';

class ReportIssueScreen extends StatefulWidget {
  final int initialTab; // 0 = Submit, 1 = My Reports
  final String? initialCategory;

  const ReportIssueScreen({
    super.key,
    this.initialTab = 0,
    this.initialCategory,
  });

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final SupportTicketService _ticketService = SupportTicketService();
  final _formKey = GlobalKey<FormState>();

  late int _activeTab;
  late String _selectedCategory;
  String _selectedPriority = 'normal';

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _subjectCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  final List<XFile> _pickedFiles = [];
  final Map<String, Uint8List> _previewBytes = {};

  bool _submitting = false;
  String? _submittedCode;

  static const List<({String id, String key, dynamic icon, Color color})> _categories = [
    (id: 'bug', key: 'support_ticket.cat_bug', icon: HugeIcons.strokeRoundedAlert02, color: Color(0xFFEF4444)),
    (id: 'feature', key: 'support_ticket.cat_feature', icon: HugeIcons.strokeRoundedIdea01, color: Color(0xFF8B5CF6)),
    (id: 'order_issue', key: 'support_ticket.cat_order_issue', icon: HugeIcons.strokeRoundedShoppingCart02, color: Color(0xFFF59E0B)),
    (id: 'payment', key: 'support_ticket.cat_payment', icon: HugeIcons.strokeRoundedCreditCard, color: Color(0xFF10B981)),
    (id: 'account', key: 'support_ticket.cat_account', icon: HugeIcons.strokeRoundedUser, color: Color(0xFF42A5F5)),
    (id: 'other', key: 'support_ticket.cat_other', icon: HugeIcons.strokeRoundedHelpCircle, color: Color(0xFF94A3B8)),
  ];

  static const List<({String id, String key, Color color})> _priorities = [
    (id: 'low', key: 'support_ticket.priority_low', color: Color(0xFF64748B)),
    (id: 'normal', key: 'support_ticket.priority_normal', color: Color(0xFF42A5F5)),
    (id: 'high', key: 'support_ticket.priority_high', color: Color(0xFFF59E0B)),
    (id: 'urgent', key: 'support_ticket.priority_urgent', color: Color(0xFFEF4444)),
  ];

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab.clamp(0, 1);
    _selectedCategory = widget.initialCategory ?? 'bug';

    final user = Supabase.instance.client.auth.currentUser;
    _nameCtrl.text = UserData.userName.value.trim().isNotEmpty
        ? UserData.userName.value.trim()
        : (user?.userMetadata?['user_name']?.toString() ?? '');
    _emailCtrl.text = UserData.userEmail.value.trim().isNotEmpty
        ? UserData.userEmail.value.trim()
        : (user?.email ?? '');
    _phoneCtrl.text = UserData.userPhone.value.trim();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  LiquidGlassSettings _glassSettings(bool isDark) => LiquidGlassSettings(
    thickness: 0.1,
    blur: 15,
    refractiveIndex: 1.0,
    glassColor: Colors.transparent,
    lightAngle: 45.0,
    lightIntensity: isDark ? 0.1 : 0.2,
    ambientStrength: 1.0,
    saturation: 1.0,
    chromaticAberration: 0.0,
  );

  Future<void> _pickScreenshot() async {
    if (_pickedFiles.length >= 3) {
      showGlassToast(context, 'support_ticket.max_attachments'.tr(), isError: true);
      return;
    }
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedFiles.add(picked);
        _previewBytes[picked.path] = bytes;
      });
    } catch (_) {
      if (mounted) {
        showGlassToast(context, 'support_ticket.pick_image_error'.tr(), isError: true);
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      final code = await _ticketService.submitTicket(
        category: _selectedCategory,
        priority: _selectedPriority,
        subject: _subjectCtrl.text,
        description: _descCtrl.text,
        reporterName: _nameCtrl.text,
        reporterEmail: _emailCtrl.text,
        reporterPhone: _phoneCtrl.text,
        attachments: _pickedFiles,
      );
      if (!mounted) return;
      setState(() {
        _submittedCode = code;
        _subjectCtrl.clear();
        _descCtrl.clear();
        _pickedFiles.clear();
        _previewBytes.clear();
      });
      showGlassToast(context, 'support_ticket.submit_success'.tr(args: [code]));
    } catch (e) {
      if (mounted) {
        showGlassToast(context, 'support_ticket.submit_error'.tr(), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _openImageViewer(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 24,
                right: 20,
                child: IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                ),
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
    final currentUser = Supabase.instance.client.auth.currentUser;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        GlassNavButton.safeNavBack(context, fallbackRoute: '/tab/profile');
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      const SizedBox(height: 68),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildSegmentedSwitch(isDark),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _activeTab == 0
                            ? _buildSubmitTab(isDark)
                            : _buildMyTicketsTab(isDark, currentUser != null),
                      ),
                    ],
                  ),
                ),
              ),
              FloatingTopBar(
                isDark: isDark,
                title: 'support_ticket.page_title'.tr(),
                fallbackRoute: '/tab/profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedSwitch(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          _segmentButton(0, 'support_ticket.tab_submit'.tr(), HugeIcons.strokeRoundedEdit02, isDark),
          _segmentButton(1, 'support_ticket.tab_my_tickets'.tr(), HugeIcons.strokeRoundedTicket02, isDark),
        ],
      ),
    );
  }

  Widget _segmentButton(int index, String label, dynamic icon, bool isDark) {
    final selected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: icon,
                size: 16,
                color: selected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitTab(bool isDark) {
    final bool isGuest = Supabase.instance.client.auth.currentUser == null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
      physics: const BouncingScrollPhysics(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_submittedCode != null) ...[
              _buildSuccessBanner(isDark, _submittedCode!),
              const SizedBox(height: 16),
            ],

            Text(
              'support_ticket.hero_title'.tr(),
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'support_ticket.hero_subtitle'.tr(),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 18),

            // Category Selection
            _buildSectionLabel('support_ticket.category_label'.tr(), isDark),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cat.color.withValues(alpha: isDark ? 0.22 : 0.14)
                          : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? cat.color
                            : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
                        width: isSelected ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: cat.icon,
                          size: 16,
                          color: isSelected ? cat.color : (isDark ? Colors.white60 : Colors.black54),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cat.key.tr(),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? (isDark ? Colors.white : cat.color)
                                : (isDark ? Colors.white70 : const Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Priority Selection
            _buildSectionLabel('support_ticket.priority_label'.tr(), isDark),
            const SizedBox(height: 10),
            Row(
              children: _priorities.map((p) {
                final isSelected = _selectedPriority == p.id;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: p.id == 'urgent' ? 0 : 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPriority = p.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? p.color.withValues(alpha: isDark ? 0.24 : 0.14)
                              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? p.color
                                : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            p.key.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? (isDark ? Colors.white : p.color)
                                  : (isDark ? Colors.white70 : const Color(0xFF475569)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Form Card
            GlassContainer(
              useOwnLayer: true,
              quality: GlassQuality.standard,
              shape: LiquidRoundedSuperellipse(borderRadius: 20.0),
              settings: _glassSettings(isDark),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      controller: _subjectCtrl,
                      label: 'support_ticket.subject_label'.tr(),
                      hint: 'support_ticket.subject_hint'.tr(),
                      isDark: isDark,
                      validator: (v) => (v == null || v.trim().length < 4)
                          ? 'support_ticket.subject_required'.tr()
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _descCtrl,
                      label: 'support_ticket.desc_label'.tr(),
                      hint: 'support_ticket.desc_hint'.tr(),
                      isDark: isDark,
                      maxLines: 5,
                      validator: (v) => (v == null || v.trim().length < 10)
                          ? 'support_ticket.desc_required'.tr()
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Contact Info (editable, pre-filled for logged-in users)
                    _buildSectionLabel('support_ticket.contact_info_label'.tr(), isDark),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _nameCtrl,
                            label: 'support_ticket.name_label'.tr(),
                            hint: 'support_ticket.name_hint'.tr(),
                            isDark: isDark,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'support_ticket.name_required'.tr()
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            controller: _phoneCtrl,
                            label: 'support_ticket.phone_label'.tr(),
                            hint: 'support_ticket.phone_hint'.tr(),
                            isDark: isDark,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _emailCtrl,
                      label: 'support_ticket.email_label'.tr(),
                      hint: 'support_ticket.email_hint'.tr(),
                      isDark: isDark,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        final val = (v ?? '').trim();
                        if (isGuest && val.isEmpty) {
                          return 'support_ticket.email_required'.tr();
                        }
                        if (val.isNotEmpty && !val.contains('@')) {
                          return 'support_ticket.email_invalid'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Screenshots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionLabel('support_ticket.attachments_label'.tr(), isDark),
                        Text(
                          '${_pickedFiles.length}/3',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ..._pickedFiles.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final file = entry.value;
                          final bytes = _previewBytes[file.path];
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? Colors.white24 : Colors.black12,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: bytes != null
                                      ? Image.memory(bytes, fit: BoxFit.cover)
                                      : const Icon(Icons.image_outlined),
                                ),
                              ),
                              Positioned(
                                top: -6,
                                right: -6,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _previewBytes.remove(file.path);
                                      _pickedFiles.removeAt(idx);
                                    });
                                  },
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        if (_pickedFiles.length < 3)
                          GestureDetector(
                            onTap: _pickScreenshot,
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.primary.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const HugeIcon(
                                    icon: HugeIcons.strokeRoundedImage01,
                                    color: AppTheme.primary,
                                    size: 22,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'support_ticket.add_photo'.tr(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Auto Diagnostic Info Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedInformationCircle,
                            color: AppTheme.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'support_ticket.auto_diag_note'.tr(args: [
                                'v${AppUpdateService.currentVersion}',
                                SupportTicketService.detectedPlatform.toUpperCase(),
                              ]),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white70 : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const HugeIcon(
                                icon: HugeIcons.strokeRoundedSent02,
                                color: Colors.white,
                                size: 18,
                              ),
                        label: Text(
                          _submitting
                              ? 'support_ticket.submitting'.tr()
                              : 'support_ticket.submit_btn'.tr(),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
    );
  }

  Widget _buildSuccessBanner(bool isDark, String code) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            color: Color(0xFF10B981),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'support_ticket.ticket_created_title'.tr(args: [code]),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF065F46),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'support_ticket.ticket_created_desc'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : const Color(0xFF047857),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _activeTab = 1),
            child: Text(
              'support_ticket.view_status'.tr(),
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyTicketsTab(bool isDark, bool isLoggedIn) {
    if (!isLoggedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedTicket02,
                color: AppTheme.primary,
                size: 46,
              ),
              const SizedBox(height: 14),
              Text(
                'support_ticket.login_to_track_title'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'support_ticket.login_to_track_desc'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('profile.login_register'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<SupportTicketModel>>(
      stream: _ticketService.watchMyTickets(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final tickets = snapshot.data ?? const [];
        if (tickets.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedTicket02,
                        color: AppTheme.primary,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'support_ticket.no_tickets_title'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'support_ticket.no_tickets_desc'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _activeTab = 0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text('support_ticket.tab_submit'.tr()),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
          physics: const BouncingScrollPhysics(),
          itemCount: tickets.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _buildTicketCard(tickets[index], isDark),
        );
      },
    );
  }

  Widget _buildTicketCard(SupportTicketModel ticket, bool isDark) {
    final statusColor = switch (ticket.status) {
      'in_progress' => const Color(0xFFF59E0B),
      'resolved' => const Color(0xFF10B981),
      'closed' => const Color(0xFF64748B),
      _ => const Color(0xFF42A5F5),
    };
    final statusLabel = 'support_ticket.status_${ticket.status}'.tr();
    final catLabel = 'support_ticket.cat_${ticket.category}'.tr();
    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(ticket.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ticket.adminReply != null && ticket.adminReply!.trim().isNotEmpty
              ? const Color(0xFF10B981).withValues(alpha: 0.35)
              : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.07)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ticket.ticketCode,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  catLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ticket.subject,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ticket.description,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          if (ticket.attachmentUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ticket.attachmentUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final url = ticket.attachmentUrls[idx];
                  return GestureDetector(
                    onTap: () => _openImageViewer(url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        url,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (ticket.adminReply != null && ticket.adminReply!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedCustomerSupport,
                        color: Color(0xFF10B981),
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'support_ticket.admin_reply_label'.tr(),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    ticket.adminReply!.trim(),
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            dateStr,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: isDark ? Colors.white60 : const Color(0xFF475569),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontSize: 13.5,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          fontSize: 12.5,
          color: isDark ? Colors.white60 : const Color(0xFF64748B),
        ),
        hintStyle: TextStyle(
          fontSize: 12.5,
          color: isDark ? Colors.white30 : Colors.black26,
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.4),
        ),
      ),
    );
  }
}
