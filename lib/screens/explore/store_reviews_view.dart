import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:ngam/widgets/glass_box.dart';
import '../../widgets/glass_toast.dart';
import '../../widgets/glass_nav_button.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/review_video_dialog.dart';

// ============================================================
// StoreReviewsView — Store Reviews, Ratings Breakdown & Feedback
// ============================================================
class StoreReviewsView extends StatefulWidget {
  final Map<String, dynamic> shop;

  const StoreReviewsView({super.key, required this.shop});

  @override
  State<StoreReviewsView> createState() => _StoreReviewsViewState();
}

class _StoreReviewsViewState extends State<StoreReviewsView> {
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['All', 'With Photos', '5 Stars', '4 Stars'];

  // Sample verified reviews
  late List<Map<String, dynamic>> _reviews;

  @override
  void initState() {
    super.initState();
    final shopName = widget.shop['name'] ?? 'this store';
    _reviews = [
      {
        'id': '1',
        'name': 'Farhan Akmal',
        'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=150',
        'rating': 5,
        'date': '2 days ago',
        'item': 'Verified Visit',
        'comment': 'Best experience ever at $shopName! Clean place, very professional staff and on time. Highly recommended!',
        'helpful': 14,
        'isHelpful': false,
        'images': [
          'https://images.unsplash.com/photo-1541544741938-0af808871cc0?q=80&w=400',
          'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=400',
        ],
        'hasVideo': false,
      },
      {
        'id': '2',
        'name': 'Nurul Ain',
        'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=150',
        'rating': 5,
        'date': '5 days ago',
        'item': 'Verified Customer',
        'comment': 'Super satisfying experience! Really recommended if you visit. Staff was very welcoming. Check out the video!',
        'helpful': 9,
        'isHelpful': false,
        'images': <String>[],
        'hasVideo': true,
        'videoDuration': '0:22',
        'videoThumbnail': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?q=80&w=400',
        'videoUrl': 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      },
      {
        'id': '3',
        'name': 'Daniel Tan',
        'avatar': 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?q=80&w=150',
        'rating': 4,
        'date': '1 week ago',
        'item': 'Regular Customer',
        'comment': 'Good precision and gentle service. Slightly crowded on weekends so book ahead with Ngam app.',
        'helpful': 5,
        'isHelpful': false,
        'images': [
          'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?q=80&w=400',
        ],
        'hasVideo': false,
      },
      {
        'id': '4',
        'name': 'Siti Sarah',
        'avatar': 'https://images.unsplash.com/photo-1580489944761-15a19d654956?q=80&w=150',
        'rating': 5,
        'date': '2 weeks ago',
        'item': 'Community Review',
        'comment': 'The result is super vibrant and looks exactly like my reference picture! 10/10.',
        'helpful': 8,
        'isHelpful': false,
        'images': <String>[],
        'hasVideo': false,
      },
    ];
  }

  LiquidGlassSettings _glassSettings(bool isDark, {double blur = 2.0}) {
    return LiquidGlassSettings(
      thickness: 0.1,
      blur: blur,
      refractiveIndex: 1.0,
      glassColor: Colors.transparent,
      lightAngle: 45.0,
      lightIntensity: isDark ? 0.1 : 0.2,
      ambientStrength: 1.0,
      saturation: 1.0,
      chromaticAberration: 0.0,
    );
  }

  Widget _liquidGlassBox({
    required bool isDark,
    required Widget child,
    double radius = 20,
    EdgeInsetsGeometry? padding,
  }) {
    return GlassContainer(
      useOwnLayer: true,
      quality: GlassQuality.standard,
      shape: LiquidRoundedSuperellipse(borderRadius: radius),
      settings: _glassSettings(isDark),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.4),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.5),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }


  void _openImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.92),
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 54),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openVideoDialog(BuildContext context, String videoUrl, String reviewerName) {
    ReviewVideoDialog.show(
      context,
      videoUrl: videoUrl,
      title: 'Video: $reviewerName',
    );
  }

  void _openWriteReviewModal() {
    int rating = 5;
    final commentCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ImagePicker picker = ImagePicker();
    final List<XFile> attachedImages = [];
    XFile? attachedVideo;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2228) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Beri Penilaian & Ulasan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kongsi pengalaman anda di ${widget.shop['name'] ?? 'kedai ini'}',
                  style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 18),
                // Star Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (idx) {
                    final starVal = idx + 1;
                    return IconButton(
                      iconSize: 34,
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedStar,
                        color: starVal <= rating ? Colors.amber : Colors.grey,
                        size: 34,
                      ),
                      onPressed: () => setModalState(() => rating = starVal),
                    );
                  }),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: commentCtrl,
                  maxLines: 4,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Apa yang anda suka atau cadangan anda? Tulis ulasan di sini...',
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13.5),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),

                // Butang Tambah Foto & Video
                Row(
                  children: [
                    // Tambah Foto
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: BorderSide(color: Colors.blue.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const HugeIcon(icon: HugeIcons.strokeRoundedImage01, color: Colors.blue, size: 18),
                        label: const Text('Tambah Foto', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          try {
                            final List<XFile> picked = await picker.pickMultiImage();
                            if (picked.isNotEmpty) {
                              setModalState(() {
                                attachedImages.addAll(picked);
                              });
                            }
                          } catch (e) {
                            debugPrint('[WriteReview] Pick image error: $e');
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Tambah Video
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purpleAccent,
                          side: BorderSide(color: Colors.purpleAccent.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const HugeIcon(icon: HugeIcons.strokeRoundedVideo01, color: Colors.purpleAccent, size: 18),
                        label: const Text('Tambah Video', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          try {
                            final XFile? vid = await picker.pickVideo(source: ImageSource.gallery);
                            if (vid != null) {
                              setModalState(() {
                                attachedVideo = vid;
                              });
                            }
                          } catch (e) {
                            debugPrint('[WriteReview] Pick video error: $e');
                          }
                        },
                      ),
                    ),
                  ],
                ),

                // Pratonton Lampiran Media Terpilih
                if (attachedImages.isNotEmpty || attachedVideo != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...attachedImages.map((img) => Chip(
                            avatar: const Icon(Icons.image, size: 16, color: Colors.blue),
                            label: Text(img.name, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () => setModalState(() => attachedImages.remove(img)),
                          )),
                      if (attachedVideo != null)
                        Chip(
                          avatar: const Icon(Icons.videocam, size: 16, color: Colors.purpleAccent),
                          label: Text(attachedVideo!.name, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => setModalState(() => attachedVideo = null),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      final text = commentCtrl.text.trim();
                      if (text.isEmpty) {
                        showGlassToast(context, 'Sila masukkan ulasan anda', isError: true);
                        return;
                      }

                      // Kumpulkan URL gambar (atau fallback sample jika fail lokal)
                      final List<String> reviewImages = attachedImages.isNotEmpty
                          ? [
                              'https://images.unsplash.com/photo-1541544741938-0af808871cc0?q=80&w=400',
                              if (attachedImages.length > 1) 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=400',
                            ]
                          : <String>[];

                      setState(() {
                        _reviews.insert(0, {
                          'id': DateTime.now().toString(),
                          'name': 'Anda',
                          'avatar': '',
                          'rating': rating,
                          'date': 'Baru sahaja',
                          'item': 'Lawatan Disahkan',
                          'comment': text,
                          'helpful': 0,
                          'isHelpful': false,
                          'images': reviewImages,
                          'hasVideo': attachedVideo != null,
                          'videoDuration': '0:20',
                          'videoThumbnail': attachedVideo != null ? 'https://images.unsplash.com/photo-1509440159596-0249088772ff?q=80&w=400' : null,
                          'videoUrl': attachedVideo != null ? 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4' : null,
                        });
                      });
                      Navigator.pop(ctx);
                      showGlassToast(context, 'Terima kasih! Ulasan anda berjaya dihantar.');
                    },
                    child: const Text('Hantar Ulasan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textPrimary = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final Color textSecondary = isDark ? Colors.white60 : const Color(0xFF3A3A3C).withValues(alpha: 0.7);

    final String shopName = widget.shop['name'] ?? 'Store';
    final double ratingVal = (widget.shop['rating'] is num)
        ? (widget.shop['rating'] as num).toDouble()
        : 4.8;
    final int reviewCount = (widget.shop['reviews'] is num)
        ? (widget.shop['reviews'] as num).toInt()
        : 128;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Scrollable list
            ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 68, 20, 12),
                children: [
                  // Overall Rating Box
                  _liquidGlassBox(
                    isDark: isDark,
                    radius: 24,
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        // Left Score
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ratingVal.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                color: textPrimary,
                                letterSpacing: -1.0,
                              ),
                            ),
                            Row(
                              children: List.generate(
                                5,
                                (i) => const HugeIcon(icon: HugeIcons.strokeRoundedStar, color: Colors.amber, size: 18),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Based on $reviewCount reviews',
                              style: TextStyle(color: textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        // Right Rating Bars
                        Expanded(
                          child: Column(
                            children: [
                              _ratingBar(5, 0.85, textSecondary),
                              _ratingBar(4, 0.10, textSecondary),
                              _ratingBar(3, 0.03, textSecondary),
                              _ratingBar(2, 0.01, textSecondary),
                              _ratingBar(1, 0.01, textSecondary),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Filters
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filters.length,
                      itemBuilder: (context, idx) {
                        final isSelected = _selectedFilterIndex == idx;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedFilterIndex = idx),
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blue
                                  : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                _filters[idx],
                                style: TextStyle(
                                  color: isSelected ? Colors.white : textSecondary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Reviews List
                  ..._reviews.map((rev) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _liquidGlassBox(
                          isDark: isDark,
                          radius: 20,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.blue.withValues(alpha: 0.15),
                                    backgroundImage: rev['avatar'].toString().isNotEmpty
                                        ? NetworkImage(rev['avatar'])
                                        : null,
                                    child: rev['avatar'].toString().isEmpty
                                        ? const HugeIcon(icon: HugeIcons.strokeRoundedUser, color: Colors.blue, size: 20)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          rev['name'],
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Row(
                                              children: List.generate(
                                                rev['rating'] as int,
                                                (i) => const HugeIcon(icon: HugeIcons.strokeRoundedStar, color: Colors.amber, size: 14),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              rev['date'],
                                              style: TextStyle(color: textSecondary, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('Verified', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (rev['item'] != null && rev['item'].toString().isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Purchased: ${rev['item']}',
                                    style: TextStyle(color: textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Text(
                                rev['comment'],
                                style: TextStyle(color: textPrimary, fontSize: 13, height: 1.4),
                              ),
                              // Foto Ulasan Pelanggan
                              if (rev['images'] != null && (rev['images'] as List).isNotEmpty) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 72,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: (rev['images'] as List).length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                                    itemBuilder: (context, imgIdx) {
                                      final imgUrl = (rev['images'] as List)[imgIdx].toString();
                                      return GestureDetector(
                                        onTap: () => _openImagePreview(context, imgUrl),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Stack(
                                            children: [
                                              Image.network(
                                                imgUrl,
                                                width: 72,
                                                height: 72,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  width: 72,
                                                  height: 72,
                                                  color: Colors.white12,
                                                  child: const Icon(Icons.broken_image_rounded, color: Colors.white38, size: 22),
                                                ),
                                              ),
                                              Positioned(
                                                bottom: 4,
                                                right: 4,
                                                child: Container(
                                                  padding: const EdgeInsets.all(3),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.60),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 12),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                              // Video Ulasan Pelanggan
                              if (rev['hasVideo'] == true && rev['videoUrl'] != null) ...[
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTap: () => _openVideoDialog(context, rev['videoUrl'].toString(), rev['name'].toString()),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 145,
                                      height: 86,
                                      color: Colors.black,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (rev['videoThumbnail'] != null && rev['videoThumbnail'].toString().isNotEmpty)
                                            Image.network(
                                              rev['videoThumbnail'].toString(),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF161622)),
                                            )
                                          else
                                            Container(color: const Color(0xFF161622)),
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.black.withValues(alpha: 0.65),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Center(
                                            child: Container(
                                              padding: const EdgeInsets.all(7),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.black.withValues(alpha: 0.55),
                                                border: Border.all(color: Colors.white.withValues(alpha: 0.40)),
                                              ),
                                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 6,
                                            right: 6,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.75),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.videocam_rounded, color: Colors.white70, size: 10),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    rev['videoDuration']?.toString() ?? '0:20',
                                                    style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        rev['isHelpful'] = !(rev['isHelpful'] as bool);
                                        rev['helpful'] = (rev['helpful'] as int) + (rev['isHelpful'] ? 1 : -1);
                                      });
                                    },
                                    child: Row(
                                      children: [
                                        HugeIcon(
                                          icon: HugeIcons.strokeRoundedThumbsUp,
                                          size: 15,
                                          color: rev['isHelpful'] ? Colors.blue : textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Helpful (${rev['helpful']})',
                                          style: TextStyle(
                                            color: rev['isHelpful'] ? Colors.blue : textSecondary,
                                            fontSize: 12,
                                            fontWeight: rev['isHelpful'] ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )),

                  const SizedBox(height: 30),
                ],
              ),
            FloatingTopBar(
              isDark: isDark,
              title: 'Reviews & Ratings',
              subtitle: shopName,
              actions: [
                GlassNavButton(
                  icon: HugeIcons.strokeRoundedEdit02,
                  iconColor: Colors.blue,
                  isDark: isDark,
                  size: 42,
                  iconSize: 20,
                  onTap: _openWriteReviewModal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratingBar(int star, double fraction, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$star', style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
