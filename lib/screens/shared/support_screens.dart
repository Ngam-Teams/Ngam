import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:ngam/widgets/glass_box.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';

// ============================================================
// Ngam App — Skrin Support (Bantuan)
// Help Center dengan ruang Hubungi Kami
// ============================================================

LiquidGlassSettings _glassSettings(bool isDark) => LiquidGlassSettings(
  thickness: 0.1, blur: 15, refractiveIndex: 1.0, glassColor: Colors.transparent,
  lightAngle: 45.0, lightIntensity: isDark ? 0.1 : 0.2, ambientStrength: 1.0,
  saturation: 1.0, chromaticAberration: 0.0,
);

// ─── Pusat Bantuan ───────────────────────────────────────────
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  List<Map<String, String>> get _faqs => [
    {'q': "support.faq_1_q".tr(), 'a': "support.faq_1_a".tr()},
    {'q': "support.faq_2_q".tr(), 'a': "support.faq_2_a".tr()},
    {'q': "support.faq_3_q".tr(), 'a': "support.faq_3_a".tr()},
    {'q': "support.faq_4_q".tr(), 'a': "support.faq_4_a".tr()},
    {'q': "support.faq_5_q".tr(), 'a': "support.faq_5_a".tr()},
    {'q': "support.faq_6_q".tr(), 'a': "support.faq_6_a".tr()},
    {'q': "support.faq_7_q".tr(), 'a': "support.faq_7_a".tr()},
    {'q': "support.faq_8_q".tr(), 'a': "support.faq_8_a".tr()},
    {'q': "support.faq_9_q".tr(), 'a': "support.faq_9_a".tr()},
    {'q': "support.faq_10_q".tr(), 'a': "support.faq_10_a".tr()},
    {'q': "support.faq_11_q".tr(), 'a': "support.faq_11_a".tr()},
    {'q': "support.faq_12_q".tr(), 'a': "support.faq_12_a".tr()},
    {'q': "support.faq_13_q".tr(), 'a': "support.faq_13_a".tr()},
    {'q': "support.faq_14_q".tr(), 'a': "support.faq_14_a".tr()},
    {'q': "support.faq_15_q".tr(), 'a': "support.faq_15_a".tr()},
  ];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _expandedIndex;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        title: Text("support.help_center".tr(), style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
        leading: IconButton(
          icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: isDark ? Colors.white70 : Colors.black54, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("support.greeting".tr(), style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, height: 1.2)),
              const SizedBox(height: 24),

              // Kotak Cari
              GlassContainer(
                useOwnLayer: true, quality: GlassQuality.standard, shape: LiquidRoundedSuperellipse(borderRadius: 16.0), settings: _glassSettings(isDark),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.6))),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      filled: false,
                      hintText: "support.search_hint".tr(), hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                      icon: const HugeIcon(icon: HugeIcons.strokeRoundedSearch01, color: Colors.grey, size: 20),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Text("support.faq_title".tr(), style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 12),

              ...(() {
                final filteredFaqs = _searchQuery.isEmpty
                    ? _faqs
                    : _faqs.where((faq) => faq['q']!.toLowerCase().contains(_searchQuery) || faq['a']!.toLowerCase().contains(_searchQuery)).toList();

                if (filteredFaqs.isEmpty) {
                  return [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'Tiada soalan dijumpai untuk "$_searchQuery"',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    ),
                  ];
                }

                return List.generate(filteredFaqs.length, (index) {
                  final isExpanded = _expandedIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _expandedIndex = isExpanded ? null : index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: isExpanded ? 0.08 : 0.03) : Colors.white.withValues(alpha: isExpanded ? 0.7 : 0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isExpanded ? const Color(0xFFFF8C00).withValues(alpha: 0.6) : Colors.white.withValues(alpha: isDark ? 0.05 : 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(filteredFaqs[index]['q']!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87))),
                              Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                            ],
                          ),
                          if (isExpanded) ...[
                            const SizedBox(height: 12),
                            Text(filteredFaqs[index]['a']!, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54, height: 1.5)),
                          ]
                        ],
                      ),
                    ),
                  );
                });
              })(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Hubungi Kami ────────────────────────────────────────────
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

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
        title: Text("support.contact_us".tr(), style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
        leading: IconButton(
          icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: isDark ? Colors.white70 : Colors.black54, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("support.contact_us".tr(), style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              Text("support.contact_subtitle".tr(), style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54)),
              const SizedBox(height: 32),

              _contactCard(isDark, HugeIcons.strokeRoundedBubbleChat, "support.chat_support".tr(), "support.chat_subtitle".tr(), "support.start_chat".tr()),
              const SizedBox(height: 16),
              _contactCard(isDark, HugeIcons.strokeRoundedMail01, "support.email_us".tr(), "support.email_subtitle".tr(), 'support@ngam.my'),
              const SizedBox(height: 16),
              _contactCard(isDark, HugeIcons.strokeRoundedCall02, "support.call_us".tr(), "support.call_subtitle".tr(), '+60 12-345 6789'),
              const SizedBox(height: 32),

              Text("support.follow_us".tr(), style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _socialButton(isDark, 'Instagram', const Color(0xFFE91E63)),
                  const SizedBox(width: 12),
                  _socialButton(isDark, 'Facebook', const Color(0xFF1976D2)),
                  const SizedBox(width: 12),
                  _socialButton(isDark, 'Twitter/X', Colors.black),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactCard(bool isDark, dynamic icon, String title, String subtitle, String action) {
    return GlassContainer(
      useOwnLayer: true, quality: GlassQuality.standard, shape: LiquidRoundedSuperellipse(borderRadius: 20.0), settings: _glassSettings(isDark),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.6))),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFF8C00).withValues(alpha: 0.1), shape: BoxShape.circle),
              child: HugeIcon(icon: icon, color: const Color(0xFFFF8C00), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                  const SizedBox(height: 6),
                  Text(action, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFFF8C00))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialButton(bool isDark, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Center(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))),
      ),
    );
  }
}
