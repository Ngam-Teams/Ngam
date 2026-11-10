import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:ngam/widgets/glass_box.dart';
import '../../widgets/glass_nav_button.dart';
import '../../utils/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

// ============================================================
// Ngam App — Skrin Support & Pusat Bantuan
// Redesigned with smooth scroll-driven collapsing search bar,
// audited relevant FAQs, brand theme color, and Contact Us integration.
// ============================================================

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

class _FaqItem {
  final String question;
  final String answer;
  final String category;
  final dynamic icon;

  const _FaqItem({
    required this.question,
    required this.answer,
    required this.category,
    required this.icon,
  });
}

// ─── Pusat Bantuan (Help Center) ──────────────────────────────
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  late final ScrollController _scrollController;
  late final FocusNode _searchFocusNode;
  final TextEditingController _searchController = TextEditingController();

  double _scrollOffset = 0.0;
  String _searchQuery = '';
  String _selectedCategory = 'Semua';
  int? _expandedIndex;

  final List<String> _categories = [
    'Semua',
    'Pesanan',
    'Servis',
    'Baucar',
    'Bayaran',
    'Peniaga',
  ];

  List<_FaqItem> get _faqs => [
    _FaqItem(
      question: "support.faq_1_q".tr(),
      answer: "support.faq_1_a".tr(),
      category: 'Pesanan',
      icon: HugeIcons.strokeRoundedQrCode01,
    ),
    _FaqItem(
      question: "support.faq_2_q".tr(),
      answer: "support.faq_2_a".tr(),
      category: 'Servis',
      icon: HugeIcons.strokeRoundedScissor,
    ),
    _FaqItem(
      question: "support.faq_3_q".tr(),
      answer: "support.faq_3_a".tr(),
      category: 'Baucar',
      icon: HugeIcons.strokeRoundedTicket02,
    ),
    _FaqItem(
      question: "support.faq_4_q".tr(),
      answer: "support.faq_4_a".tr(),
      category: 'Bayaran',
      icon: HugeIcons.strokeRoundedCreditCard,
    ),
    _FaqItem(
      question: "support.faq_5_q".tr(),
      answer: "support.faq_5_a".tr(),
      category: 'Pesanan',
      icon: HugeIcons.strokeRoundedClock01,
    ),
    _FaqItem(
      question: "support.faq_6_q".tr(),
      answer: "support.faq_6_a".tr(),
      category: 'Servis',
      icon: HugeIcons.strokeRoundedCalendar03,
    ),
    _FaqItem(
      question: "support.faq_7_q".tr(),
      answer: "support.faq_7_a".tr(),
      category: 'Baucar',
      icon: HugeIcons.strokeRoundedGift,
    ),
    _FaqItem(
      question: "support.faq_8_q".tr(),
      answer: "support.faq_8_a".tr(),
      category: 'Pesanan',
      icon: HugeIcons.strokeRoundedHelpCircle,
    ),
    _FaqItem(
      question: "support.faq_9_q".tr(),
      answer: "support.faq_9_a".tr(),
      category: 'Bayaran',
      icon: HugeIcons.strokeRoundedShield01,
    ),
    _FaqItem(
      question: "support.faq_10_q".tr(),
      answer: "support.faq_10_a".tr(),
      category: 'Peniaga',
      icon: HugeIcons.strokeRoundedStore01,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!mounted) return;
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _launchWhatsApp() async {
    const phone = '601115892468';
    final text = Uri.encodeComponent('Hai Ngam Support, saya perlukan bantuan berkenaan aplikasi Ngam.');
    final url = 'https://wa.me/$phone?text=$text';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;

    const horizontalMargin = 16.0;
    final fullWidth = screenWidth - (horizontalMargin * 2);
    const searchHeight = 44.0;
    const endTop = 12.0;
    const startTop = 152.0;

    // Movement: The search bar moves up first with the scroll
    final currentTop = math.max(endTop, startTop - _scrollOffset);

    // Shrink: Only shrinks into a circle as it approaches the top bar (offset 80 -> 140)
    final shrinkT = ((_scrollOffset - 80.0) / 60.0).clamp(0.0, 1.0);
    final widthCurve = Curves.easeOutCubic.transform(shrinkT);
    final currentWidth = fullWidth - (fullWidth - searchHeight) * widthCurve;
    final isCircle = widthCurve >= 0.85;

    // Filter FAQs by Category and Search Query
    final filteredFaqs = _faqs.where((faq) {
      final matchesCategory = _selectedCategory == 'Semua' || faq.category == _selectedCategory;
      if (!matchesCategory) return false;
      if (_searchQuery.isEmpty) return true;
      return faq.question.toLowerCase().contains(_searchQuery) ||
          faq.answer.toLowerCase().contains(_searchQuery);
    }).toList();

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
            // Layer 1: Scrollable Body
            SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 72, 16, 36),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting Title
                  Text(
                    "support.greeting".tr(),
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Bar Placeholder (reserve exact 44px height so content doesn't jump)
                  const SizedBox(height: searchHeight),
                  const SizedBox(height: 16),

                  // Category Filter Chips
                  _buildCategoryChips(isDark),
                  const SizedBox(height: 24),

                  // FAQ Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "support.faq_title".tr(),
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        '${filteredFaqs.length} soalan',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // FAQ List
                  if (filteredFaqs.isEmpty)
                    _buildEmptySearchState(isDark)
                  else
                    ...List.generate(filteredFaqs.length, (index) {
                      final item = filteredFaqs[index];
                      final isExpanded = _expandedIndex == index;
                      return _buildFaqCard(item, index, isExpanded, isDark);
                    }),

                  const SizedBox(height: 32),

                  // Contact Us Card
                  _buildContactUsCard(isDark),
                ],
              ),
            ),

            // Layer 2: Floating Animated Search Bar
            Positioned(
              top: currentTop,
              right: horizontalMargin,
              width: currentWidth,
              height: searchHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isCircle
                    ? () {
                        _scrollController.animateTo(
                          0.0,
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeOutCubic,
                        ).then((_) {
                          _searchFocusNode.requestFocus();
                        });
                      }
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(searchHeight / 2),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      height: searchHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(searchHeight / 2),
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.85),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          // 1. Text input area (takes full width minus 44px for the search icon)
                          if (widthCurve < 0.95)
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              right: searchHeight,
                              child: Opacity(
                                opacity: (1.0 - widthCurve * 1.5).clamp(0.0, 1.0),
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 16),
                                  child: Center(
                                    child: TextField(
                                      controller: _searchController,
                                      focusNode: _searchFocusNode,
                                      onChanged: (val) {
                                        setState(() {
                                          _searchQuery = val.trim().toLowerCase();
                                          _expandedIndex = null;
                                        });
                                      },
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        filled: false,
                                        fillColor: Colors.transparent,
                                        contentPadding: EdgeInsets.zero,
                                        hintText: "support.search_hint".tr(),
                                        hintStyle: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? Colors.white30 : Colors.black26,
                                          fontWeight: FontWeight.normal,
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // 2. Clear query button (positioned just to the left of the search icon)
                          if (_searchQuery.isNotEmpty && widthCurve < 0.4)
                            Positioned(
                              right: searchHeight - 4,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _expandedIndex = null;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // 3. Search Icon (STRICTLY PINNED AT THE FAR RIGHT EDGE, 44x44)
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            width: searchHeight,
                            child: Center(
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedSearch01,
                                size: 19,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.90)
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Layer 3: Floating Top Bar (Back Button + Centered Title Pill + 44px Placeholder for Docking Search)
            FloatingTopBar(
              isDark: isDark,
              title: "support.help_center".tr(),
              fallbackRoute: '/tab/profile',
              actions: const [
                SizedBox(width: 44, height: 44),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  // ─── Category Filter Chips ──────────────────────────────────
  Widget _buildCategoryChips(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = cat;
                  _expandedIndex = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isSelected
                      ? AppTheme.primary
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04)),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primary
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06)),
                    width: 1,
                  ),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : const Color(0xFF334155)),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── FAQ Card Item ──────────────────────────────────────────
  Widget _buildFaqCard(_FaqItem item, int index, bool isExpanded, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _expandedIndex = isExpanded ? null : index;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? (isExpanded
                    ? AppTheme.primary.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.035))
                : (isExpanded
                    ? AppTheme.primary.withValues(alpha: 0.05)
                    : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isExpanded
                  ? AppTheme.primary.withValues(alpha: 0.5)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06)),
              width: 1.2,
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isExpanded
                          ? AppTheme.primary.withValues(alpha: 0.15)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.03)),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: item.icon,
                        color: isExpanded
                            ? AppTheme.primary
                            : (isDark ? Colors.white60 : Colors.black54),
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.question,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowDown01,
                      color: isExpanded
                          ? AppTheme.primary
                          : (isDark ? Colors.white38 : Colors.black38),
                      size: 18,
                    ),
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 44),
                  child: Text(
                    item.answer,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white.withValues(alpha: 0.75) : const Color(0xFF475569),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Empty Search State ─────────────────────────────────────
  Widget _buildEmptySearchState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedHelpCircle,
                  color: AppTheme.primary,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tiada soalan dijumpai',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cuba kata kunci lain atau hubungi kami langsung.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Contact Us Card ────────────────────────────────────────
  Widget _buildContactUsCard(bool isDark) {
    return GlassContainer(
      useOwnLayer: true,
      quality: GlassQuality.standard,
      shape: LiquidRoundedSuperellipse(borderRadius: 20.0),
      settings: _glassSettings(isDark),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.60),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedCustomerSupport,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Masih perlukan bantuan?',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pasukan bantuan Ngam sentiasa sedia membantu.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Action Buttons
            Row(
              children: [
                // WhatsApp Button
                Expanded(
                  child: GestureDetector(
                    onTap: _launchWhatsApp,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF25D366).withValues(alpha: 0.4),
                          width: 1.0,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedBubbleChat,
                            color: Color(0xFF25D366),
                            size: 17,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'WhatsApp',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF25D366),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Saluran Bantuan Lain (ContactUsScreen)
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ContactUsScreen()),
                      );
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.10),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedMail01,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                            size: 17,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Saluran Lain',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hubungi Kami (Contact Us Screen) ─────────────────────────
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 72, 20, 28),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "support.contact_us".tr(),
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "support.contact_subtitle".tr(),
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 28),

                  _contactCard(
                    isDark: isDark,
                    icon: HugeIcons.strokeRoundedBubbleChat,
                    title: "support.chat_support".tr(),
                    subtitle: "support.chat_subtitle".tr(),
                    action: "support.start_chat".tr(),
                    onTap: () {
                      _launchUrl('https://wa.me/601115892468?text=Hai%20Ngam%20Support');
                    },
                  ),
                  const SizedBox(height: 14),
                  _contactCard(
                    isDark: isDark,
                    icon: HugeIcons.strokeRoundedMail01,
                    title: "support.email_us".tr(),
                    subtitle: "support.email_subtitle".tr(),
                    action: 'support@ngam.dev',
                    onTap: () {
                      _launchUrl('mailto:support@ngam.dev?subject=Pertanyaan%20Bantuan%20Ngam');
                    },
                  ),
                  const SizedBox(height: 14),
                  _contactCard(
                    isDark: isDark,
                    icon: HugeIcons.strokeRoundedCall02,
                    title: "support.call_us".tr(),
                    subtitle: "support.call_subtitle".tr(),
                    action: '+60 11-1589 2468',
                    onTap: () {
                      _launchUrl('tel:+601115892468');
                    },
                  ),
                  const SizedBox(height: 32),

                  Text(
                    "support.follow_us".tr(),
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _socialButton('Instagram', const Color(0xFFE91E63), 'https://instagram.com/ngam.dev'),
                      const SizedBox(width: 10),
                      _socialButton('Facebook', const Color(0xFF1976D2), 'https://facebook.com/ngam.dev'),
                      const SizedBox(width: 10),
                      _socialButton('TikTok', isDark ? Colors.white : Colors.black, 'https://tiktok.com/@ngam.dev'),
                    ],
                  ),
                ],
              ),
            ),
            FloatingTopBar(
              isDark: isDark,
              title: "support.contact_us".tr(),
              fallbackRoute: '/tab/profile',
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _contactCard({
    required bool isDark,
    required dynamic icon,
    required String title,
    required String subtitle,
    required String action,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: GlassContainer(
        useOwnLayer: true,
        quality: GlassQuality.standard,
        shape: LiquidRoundedSuperellipse(borderRadius: 18.0),
        settings: _glassSettings(isDark),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.6),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: HugeIcon(icon: icon, color: AppTheme.primary, size: 22),
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
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      action,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialButton(String label, Color color, String url) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _launchUrl(url),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
