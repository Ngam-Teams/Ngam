import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:ngam/widgets/glass_box.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../utils/glass_toast.dart';

// ============================================================
// Ngam App — Skrin About
// Teks perundangan & Rate App
// ============================================================

LiquidGlassSettings _glassSettings(bool isDark) => LiquidGlassSettings(
  thickness: 0.1, blur: 15, refractiveIndex: 1.0, glassColor: Colors.transparent,
  lightAngle: 45.0, lightIntensity: isDark ? 0.1 : 0.2, ambientStrength: 1.0,
  saturation: 1.0, chromaticAberration: 0.0,
);

// ─── Wrapper Animasi Tekan-tekan ────────────────────────────
class _AnimatedPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _AnimatedPressable({required this.child, required this.onTap});

  @override
  State<_AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<_AnimatedPressable> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _s = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _c.forward(),
    onTapUp: (_) { _c.reverse(); widget.onTap(); },
    onTapCancel: () => _c.reverse(),
    child: ScaleTransition(scale: _s, child: widget.child),
  );
}

// ─── Skrin Legal Teks ───────────────────────────────────────
class LegalTextScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalTextScreen({super.key, required this.title, required this.content});

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
        title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
        leading: IconButton(
          icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: isDark ? Colors.white70 : Colors.black54, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassContainer(
            useOwnLayer: true, quality: GlassQuality.standard, shape: LiquidRoundedSuperellipse(borderRadius: 24.0), settings: _glassSettings(isDark),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.6))),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(content, style: TextStyle(fontSize: 14, height: 1.6, color: isDark ? Colors.white70 : Colors.black87)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Skrin Rate App Kita ────────────────────────────────────
class RateAppScreen extends StatefulWidget {
  const RateAppScreen({super.key});

  @override
  State<RateAppScreen> createState() => _RateAppScreenState();
}

class _RateAppScreenState extends State<RateAppScreen> {
  int _rating = 0;
  final TextEditingController _feedbackController = TextEditingController();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _submitFeedback() {
    FocusScope.of(context).unfocus();
    showGlassToast(context, "about.thank_you".tr());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: isDark ? Colors.white70 : Colors.black54, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const HugeIcon(icon: HugeIcons.strokeRoundedStar, color: Colors.orangeAccent, size: 64),
                const SizedBox(height: 24),
                Text("about.like_ngam".tr(), style: GoogleFonts.outfit(fontSize: 30, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 8),
                Text("about.rate_subtitle".tr(), style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54)),
                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () => setState(() => _rating = index + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: index < _rating ? Colors.orangeAccent : Colors.grey.withValues(alpha: 0.4),
                          size: 44,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),

                AnimatedOpacity(
                  opacity: _rating > 0 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: GlassContainer(
                    useOwnLayer: true, quality: GlassQuality.standard, shape: LiquidRoundedSuperellipse(borderRadius: 20.0), settings: _glassSettings(isDark),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.6))),
                      child: TextField(
                        controller: _feedbackController,
                        maxLines: 4,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                        decoration: InputDecoration(
                          filled: false,
                          hintText: "about.feedback_hint".tr(),
                          hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                AnimatedOpacity(
                  opacity: _rating > 0 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: _AnimatedPressable(
                    onTap: _rating > 0 ? _submitFeedback : () {},
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF8C00), Color(0xFFE07B00)]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: const Color(0xFFFF8C00).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: Center(child: Text("about.submit_feedback".tr(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
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
}

// ─── Teks Panjang untuk Legal ───────────────────────────────
const String ngamTermsText = """
Dikemas kini: Jun 2026

Selamat datang ke Ngam. Dengan mengakses atau menggunakan aplikasi kami, anda bersetuju untuk terikat dengan Terma Perkhidmatan ini.

1. Pendaftaran Akaun
Anda mesti mewujudkan akaun untuk menggunakan Ngam. Anda bertanggungjawab untuk menjaga kerahsiaan kelayakan akaun anda dan semua aktiviti di bawah akaun anda.

2. Task & Runner
customer bertanggungjawab untuk menyediakan maklumat task yang tepat. Runner bertanggungjawab untuk melaksanakan task dengan jujur dan profesional.

3. Pembayaran
Harga yang ditunjukkan adalah dalam Ringgit Malaysia (MYR). Pembayaran dibuat terus antara customer dan Runner. Ngam tidak bertanggungjawab atas sebarang pertikaian pembayaran.

4. Kelakuan Pengguna
Pengguna dilarang menggunakan Ngam untuk aktiviti haram, menipu, atau berbahaya. Akaun yang melanggar peraturan ini akan digantung.
""";

const String ngamPrivacyText = """
Dikemas kini: Jun 2026

Privasi anda penting bagi Ngam. Dasar ini menerangkan cara kami mengumpul dan menggunakan data anda.

1. Maklumat Yang Kami Kumpul
Kami mengumpul maklumat yang anda berikan secara langsung, seperti nama, e-mel, nombor telefon, dan lokasi.

2. Perkhidmatan Lokasi
Dengan kebenaran anda, kami mengumpul lokasi peranti anda untuk menunjukkan task dan runner berhampiran. Anda boleh melumpuhkan perkhidmatan lokasi pada bila-bila masa.

3. Cara Kami Menggunakan Data Anda
Kami menggunakan data anda untuk memproses task, memudahkan komunikasi antara pengguna, dan meningkatkan pengalaman aplikasi.

4. Perkongsian Maklumat
Kami berkongsi nama dan butiran task anda dengan Runner yang anda pilih. Kami tidak menjual data peribadi anda kepada pihak ketiga.
""";
