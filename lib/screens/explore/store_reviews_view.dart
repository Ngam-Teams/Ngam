import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:ngam/widgets/glass_box.dart';
import '../../widgets/glass_toast.dart';

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
        'item': 'Premium Haircut',
        'comment': 'Best experience ever at $shopName! Clean place, very professional staff and on time.',
        'helpful': 14,
        'isHelpful': false,
      },
      {
        'id': '2',
        'name': 'Nurul Ain',
        'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=150',
        'rating': 5,
        'date': '5 days ago',
        'item': 'Facial Treatment',
        'comment': 'Super relaxing treatment! Really recommended if you need self-care. Staff was welcoming.',
        'helpful': 9,
        'isHelpful': false,
      },
      {
        'id': '3',
        'name': 'Daniel Tan',
        'avatar': 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?q=80&w=150',
        'rating': 4,
        'date': '1 week ago',
        'item': 'Classic Shave',
        'comment': 'Good precision and gentle service. Slightly crowded on weekends so book ahead.',
        'helpful': 5,
        'isHelpful': false,
      },
      {
        'id': '4',
        'name': 'Siti Sarah',
        'avatar': 'https://images.unsplash.com/photo-1580489944761-15a19d654956?q=80&w=150',
        'rating': 5,
        'date': '2 weeks ago',
        'item': 'Hair Coloring',
        'comment': 'The color result is super vibrant and looks exactly like my reference picture!',
        'helpful': 8,
        'isHelpful': false,
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

  void _openWriteReviewModal() {
    int rating = 5;
    final commentCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                'Rate & Review',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Share your experience at ${widget.shop['name'] ?? 'this store'}',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              // Star Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (idx) {
                  final starVal = idx + 1;
                  return IconButton(
                    iconSize: 34,
                    icon: Icon(
                      starVal <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber,
                    ),
                    onPressed: () => setModalState(() => rating = starVal),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentCtrl,
                maxLines: 4,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'What did you like or dislike? Write your review here...',
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
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
                      showGlassToast(context, 'Please enter a comment', isError: true);
                      return;
                    }
                    setState(() {
                      _reviews.insert(0, {
                        'id': DateTime.now().toString(),
                        'name': 'You',
                        'avatar': '',
                        'rating': rating,
                        'date': 'Just now',
                        'item': 'Verified Visit',
                        'comment': text,
                        'helpful': 0,
                        'isHelpful': false,
                      });
                    });
                    Navigator.pop(ctx);
                    showGlassToast(context, 'Thank you! Review submitted.');
                  },
                  child: const Text('Submit Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: _liquidGlassBox(
                      isDark: isDark,
                      radius: 100,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedArrowLeft01,
                            color: textPrimary,
                            size: 22,
                            strokeWidth: 2.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reviews & Ratings',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          shopName,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _openWriteReviewModal,
                    child: _liquidGlassBox(
                      isDark: isDark,
                      radius: 100,
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Icon(Icons.rate_review_outlined, color: Colors.blue, size: 20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable list
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                                (i) => Icon(Icons.star_rounded, color: Colors.amber, size: 18),
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
                                        ? const Icon(Icons.person, color: Colors.blue, size: 20)
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
                                                (i) => const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
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
                                        Icon(
                                          rev['isHelpful'] ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
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
