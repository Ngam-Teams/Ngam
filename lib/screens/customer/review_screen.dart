import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/review_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/glass_toast.dart';

// ============================================================
// Ngam App — Skrin Review Kedai & Perkhidmatan
// Pelanggan beri penarafan & ulasan selepas urusan/tempahan siap
// ============================================================

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 5;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  Map<String, dynamic>? _targetData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _targetData = args;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sila pilih penarafan bintang')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final userId = context.read<AuthProvider>().user?.id ?? 'guest_user';
    final businessId = _targetData?['business_id'] ??
        _targetData?['shop_id'] ??
        _targetData?['id']?.toString();
    final serviceName = _targetData?['service_name'] ??
        _targetData?['service'] ??
        _targetData?['category'];

    try {
      await ReviewService.submitReview(
        businessId: businessId?.toString(),
        serviceName: serviceName?.toString(),
        reviewerId: userId,
        rating: _rating,
        comment: _commentController.text.trim(),
      );

      if (mounted) {
        showGlassToast(
          context,
          'Terima kasih atas ulasan anda!',
          customIcon: Icons.check_circle_rounded,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        showGlassToast(
          context,
          'Gagal menghantar ulasan. Sila cuba lagi.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final storeName = _targetData?['name'] ??
        _targetData?['shop_name'] ??
        _targetData?['business_name'] ??
        'Kedai & Perkhidmatan';
    final serviceName = _targetData?['service_name'] ??
        _targetData?['service'] ??
        _targetData?['category'] ??
        'Tempahan Selesai';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ulasan & Penarafan',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // ─── Store / Service Header Card ───────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedStore01,
                        color: AppTheme.primary,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName,
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          serviceName,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Text(
              'Bagaimana pengalaman anda?',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Maklum balas anda membantu perniagaan ini meningkatkan mutu perkhidmatan.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // ─── Rating Bintang ──────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                return GestureDetector(
                  onTap: () {
                    setState(() => _rating = starValue);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      starValue <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 46,
                      color: starValue <= _rating
                          ? Colors.amber.shade600
                          : Colors.grey.shade300,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            Text(
              _rating == 0
                  ? 'Tekan bintang untuk pilih'
                  : _rating <= 2
                      ? 'Kurang Memuaskan 🙁'
                      : _rating <= 3
                          ? 'Sederhana Baik 🙂'
                          : _rating <= 4
                              ? 'Sangat Memuaskan! 👍'
                              : 'Terbaik & Cemerlang! 🎉',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _rating > 0
                    ? Colors.amber.shade700
                    : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 32),

            // ─── Ruangan Komen ───────────────────────
            TextFormField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Tulis maklum balas (Pilihan)',
                hintText:
                    'Kongsikan kualiti layanan, ketepatan masa atau suasana kedai...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ─── Butang Submit ───────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: _isSubmitting ? null : _handleSubmit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Hantar Ulasan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
