import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../services/saved_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/glass_toast.dart';
import '../explore/business_store_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  int _selectedTab = 0; // 0: Kedai, 1: Hantaran

  @override
  void initState() {
    super.initState();
    SavedService.init().then((_) {
      if (mounted) {
        _hydratePostCovers();
      }
    });
  }

  Future<void> _hydratePostCovers() async {
    final posts = SavedService.savedPostsNotifier.value;
    final missingCovers = posts.where((p) {
      final cover = (p['cover'] ?? p['thumbnail'] ?? '').toString();
      final bId = (p['businessId'] ?? '').toString();
      return (cover.isEmpty || cover.endsWith('.mp4')) && bId.isNotEmpty;
    }).toList();

    if (missingCovers.isEmpty) return;

    final bizIds = missingCovers.map((p) => p['businessId'].toString()).toSet().toList();
    try {
      final res = await Supabase.instance.client
          .from('businesses')
          .select('id, business_cover_url, business_logo_url')
          .inFilter('id', bizIds);

      if (res.isNotEmpty) {
        final Map<String, dynamic> bizMap = {};
        for (final b in res) {
          bizMap[b['id'].toString()] = b;
        }

        bool updated = false;
        final updatedPosts = posts.map((p) {
          final bId = p['businessId']?.toString();
          if (bId != null && bizMap.containsKey(bId)) {
            final b = bizMap[bId];
            final cover = b['business_cover_url']?.toString();
            final logo = b['business_logo_url']?.toString();
            final currentCover = (p['cover'] ?? p['thumbnail'] ?? '').toString();
            if (cover != null && cover.isNotEmpty && (currentCover.isEmpty || currentCover.endsWith('.mp4'))) {
              p['cover'] = cover;
              p['thumbnail'] = cover;
              updated = true;
            }
            if (logo != null && logo.isNotEmpty && (p['shopAvatar'] == null || p['shopAvatar'].toString().isEmpty)) {
              p['shopAvatar'] = logo;
              updated = true;
            }
          }
          return p;
        }).toList();

        if (updated && mounted) {
          await SavedService.updateSavedPosts(updatedPosts);
        }
      }
    } catch (e) {
      debugPrint('[SavedScreen] Hydrate post covers error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A14), Color(0xFF141424)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
          );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ─── APP BAR ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    _buildGlassIconButton(
                      icon: HugeIcons.strokeRoundedArrowLeft01,
                      isDark: isDark,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'profile.saved'.tr(),
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'Koleksi rujukan & kedai pilihan anda',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ─── 2 PILL TABS (KEDAI vs HANTARAN) ──────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: SavedService.savedShopsNotifier,
                  builder: (context, savedShops, _) {
                    return ValueListenableBuilder<List<Map<String, dynamic>>>(
                      valueListenable: SavedService.savedPostsNotifier,
                      builder: (context, savedPosts, _) {
                        return Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildPillTab(
                                index: 0,
                                label: 'profile.saved_shops'.tr(),
                                icon: HugeIcons.strokeRoundedStore01,
                                count: savedShops.length,
                                isDark: isDark,
                              ),
                              _buildPillTab(
                                index: 1,
                                label: 'profile.saved_posts'.tr(),
                                icon: HugeIcons.strokeRoundedBookmark02,
                                count: savedPosts.length,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // ─── TAB CONTENT ──────────────────────────────────
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _selectedTab == 0
                      ? _buildShopsTab(isDark)
                      : _buildPostsTab(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── WIDGET: PILL TAB ITEM ─────────────────────────────────────
  Widget _buildPillTab({
    required int index,
    required String label,
    required dynamic icon,
    required int count,
    required bool isDark,
  }) {
    final bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2563EB) : const Color(0xFF3B82F6))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: icon,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white60 : Colors.black54),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
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

  // ─── TAB 1: KEDAI DISIMPAN ─────────────────────────────────────
  Widget _buildShopsTab(bool isDark) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: SavedService.savedShopsNotifier,
      builder: (context, shops, _) {
        if (shops.isEmpty) {
          return _buildEmptyState(
            icon: HugeIcons.strokeRoundedStore01,
            title: 'profile.no_saved_shops'.tr(),
            description: 'profile.no_saved_shops_desc'.tr(),
            isDark: isDark,
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: shops.length,
          itemBuilder: (context, index) {
            final shop = shops[index];
            return _buildShopCard(shop, isDark);
          },
        );
      },
    );
  }

  Widget _buildShopCard(Map<String, dynamic> shop, bool isDark) {
    final String shopId = (shop['id'] ?? shop['shopId'] ?? '').toString();
    final String name = shop['name'] ?? 'Kedai';
    final String category = shop['category'] ?? 'Servis';
    final String image = shop['image'] ?? '';
    final String location = shop['location'] ?? 'Kawasan Berhampiran';
    final double rating = (shop['rating'] as num?)?.toDouble() ?? 5.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141923) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gambar Kedai
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: image.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: image,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _buildShopPlaceholder(isDark),
                  )
                : _buildShopPlaceholder(isDark),
          ),
          const SizedBox(width: 14),

          // Info Kedai
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.blueAccent : Colors.blue.shade700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Butang Buang dari Simpanan
                    GestureDetector(
                      onTap: () async {
                        await SavedService.removeSavedShop(shopId);
                        if (mounted) {
                          showGlassToast(
                            context,
                            'Kedai dikeluarkan dari simpanan',
                            icon: HugeIcons.strokeRoundedBookmark02,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bookmark_rounded,
                          color: Color(0xFFFBBF24),
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const HugeIcon(icon: HugeIcons.strokeRoundedStar, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('•', style: TextStyle(color: isDark ? Colors.white24 : Colors.black26)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        location,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BusinessStoreView(
                            shop: {
                              'id': shopId,
                              'business_id': shopId,
                              'name': name,
                              'business_name': name,
                              'category': category,
                              'business_industry': category,
                              'image': image,
                              'rating': rating,
                              'location': location,
                              'address': location,
                            },
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      elevation: 0,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Lihat Kedai', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        SizedBox(width: 4),
                        HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: Colors.white, size: 13),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopPlaceholder(bool isDark) {
    return Container(
      width: 76,
      height: 76,
      color: isDark ? Colors.white10 : Colors.black12,
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedStore01,
          color: isDark ? Colors.white38 : Colors.black26,
          size: 28,
        ),
      ),
    );
  }

  // ─── TAB 2: HANTARAN DISIMPAN ──────────────────────────────────
  Widget _buildPostsTab(bool isDark) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: SavedService.savedPostsNotifier,
      builder: (context, posts, _) {
        if (posts.isEmpty) {
          return _buildEmptyState(
            icon: HugeIcons.strokeRoundedBookmark02,
            title: 'profile.no_saved_posts'.tr(),
            description: 'profile.no_saved_posts_desc'.tr(),
            isDark: isDark,
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            // Di telefon bimbit (< 480px): susun 3 lajur ikut standard TikTok / Reels
            // Di skrin lebar / desktop: susun selagi muat (responsif 4 hingga 8 lajur mengikut kelebaran skrin)
            final int crossAxisCount = width < 480
                ? 3
                : (width / 135).floor().clamp(3, 8);

            final double spacing = width < 480 ? 6.0 : 10.0;

            return GridView.builder(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: width < 480 ? 10 : 20,
                vertical: 8,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: 0.68, // Nisbah menegak TikTok / Reels yang ideal
              ),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return _buildPostCard(post, isDark, compact: width < 480);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, bool isDark, {bool compact = false}) {
    final String postId = (post['id'] ?? '').toString();
    final String shopName = post['shopName'] ?? 'Kedai';
    final String title = post['title'] ?? post['caption'] ?? '';
    final String image = post['image'] ?? '';
    final String cover = (post['cover'] ?? post['thumbnail'] ?? '').toString();
    final String mediaType = post['mediaType'] ?? 'image';
    final String category = post['category'] ?? 'Umum';
    final bool isVideo = mediaType == 'video' ||
        image.toLowerCase().endsWith('.mp4') ||
        image.toLowerCase().endsWith('.mov') ||
        image.toLowerCase().endsWith('.webm');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openPostViewer(post, isDark),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141923) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Media Thumbnail (Auto video frame, static cover, or curated aesthetic fallback)
                _SavedPostThumbnail(
                  mediaUrl: image,
                  coverUrl: cover,
                  category: category,
                  isVideo: isVideo,
                  isDark: isDark,
                ),

                // Top Vignette Overlay
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.60),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Top-Left Badge (Video / Photo Indicator)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: isVideo
                              ? HugeIcons.strokeRoundedVideo01
                              : HugeIcons.strokeRoundedImage01,
                          color: Colors.white,
                          size: 10,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isVideo ? 'VIDEO' : 'FOTO',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Top-Right Unsave Bookmark Button
                Positioned(
                  top: 5,
                  right: 5,
                  child: GestureDetector(
                    onTap: () async {
                      await SavedService.removeSavedPost(postId);
                      if (mounted) {
                        showGlassToast(
                          context,
                          'Hantaran dikeluarkan dari simpanan',
                          icon: HugeIcons.strokeRoundedBookmark02,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 0.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.bookmark_rounded,
                        color: Color(0xFFFBBF24),
                        size: 13,
                      ),
                    ),
                  ),
                ),

                // Bottom Gradient Overlay + Info
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 7 : 9,
                      vertical: compact ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.40),
                          Colors.black.withValues(alpha: 0.88),
                        ],
                        stops: const [0.0, 0.3, 1.0],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          shopName,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: compact ? 9.5 : 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          title.isNotEmpty ? title : 'Promosi Istimewa',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 10.5 : 11.5,
                            fontWeight: FontWeight.bold,
                            height: 1.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    );
  }

  void _openPostViewer(Map<String, dynamic> post, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SavedPostViewerModal(post: post, isDark: isDark),
    );
  }

  // ─── EMPTY STATE WIDGET ────────────────────────────────────────  // ─── EMPTY STATE WIDGET ────────────────────────────────────────
  Widget _buildEmptyState({
    required dynamic icon,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: HugeIcon(
                icon: icon,
                color: isDark ? Colors.white38 : Colors.black26,
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black54,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassIconButton({
    required dynamic icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: HugeIcon(
          icon: icon,
          color: isDark ? Colors.white : Colors.black87,
          size: 20,
        ),
      ),
    );
  }
}


// ─── WIDGET: SMART VIDEO THUMBNAIL (FIRST FRAME / STATIC COVER / AESTHETIC FALLBACK) ────
class _SavedPostThumbnail extends StatefulWidget {
  final String mediaUrl;
  final String coverUrl;
  final String category;
  final bool isVideo;
  final bool isDark;

  const _SavedPostThumbnail({
    required this.mediaUrl,
    required this.coverUrl,
    required this.category,
    required this.isVideo,
    required this.isDark,
  });

  @override
  State<_SavedPostThumbnail> createState() => _SavedPostThumbnailState();
}

class _SavedPostThumbnailState extends State<_SavedPostThumbnail> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initThumbnail();
  }

  @override
  void didUpdateWidget(covariant _SavedPostThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl || oldWidget.coverUrl != widget.coverUrl) {
      _disposeController();
      _initThumbnail();
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _initThumbnail() {
    final cleanCover = widget.coverUrl.trim();
    final bool hasValidCover = cleanCover.isNotEmpty &&
        !cleanCover.toLowerCase().endsWith('.mp4') &&
        !cleanCover.toLowerCase().endsWith('.mov') &&
        !cleanCover.toLowerCase().endsWith('.webm');

    // Jika sudah ada cover statik sah, gunakan terus
    if (hasValidCover) return;

    // Jika video, inisialisasi VideoPlayerController untuk paparkan frame pertama (paused)
    final cleanMedia = widget.mediaUrl.trim();
    if (widget.isVideo && cleanMedia.isNotEmpty) {
      try {
        final uri = Uri.tryParse(cleanMedia);
        if (uri != null) {
          _controller = VideoPlayerController.networkUrl(
            uri,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
          _controller!.setVolume(0.0).catchError((_) {});
          _controller!.initialize().then((_) {
            if (mounted) {
              setState(() {
                _isInitialized = true;
              });
            }
          }).catchError((_) {
            // Jika ralat muat video, ia automatik gunakan curated aesthetic fallback
          });
        }
      } catch (_) {}
    }
  }

  String _getCategoryFallbackImage(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('barber') || lower.contains('rambut') || lower.contains('gunting')) {
      return 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=600';
    } else if (lower.contains('carwash') || lower.contains('cuci') || lower.contains('detailing')) {
      return 'https://images.unsplash.com/photo-1520340356584-f9917d1eea6f?q=80&w=600';
    } else if (lower.contains('cafe') || lower.contains('kafe') || lower.contains('kopi') || lower.contains('chill')) {
      return 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?q=80&w=600';
    } else if (lower.contains('restoran') || lower.contains('estetik') || lower.contains('makan') || lower.contains('dining') || lower.contains('fnb')) {
      return 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=600';
    } else if (lower.contains('pickle') || lower.contains('ball') || lower.contains('sport') || lower.contains('sukan')) {
      return 'https://images.unsplash.com/photo-1622163642998-1ea32b0bbc67?q=80&w=600';
    } else if (lower.contains('workshop') || lower.contains('bengkel') || lower.contains('servis')) {
      return 'https://images.unsplash.com/photo-1486006920555-c77dce18193b?q=80&w=600';
    } else if (lower.contains('salon') || lower.contains('salun') || lower.contains('spa')) {
      return 'https://images.unsplash.com/photo-1560066984-138dadb4c035?q=80&w=600';
    } else if (lower.contains('klinik') || lower.contains('kesihatan') || lower.contains('health')) {
      return 'https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?q=80&w=600';
    }
    return 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=600';
  }

  @override
  Widget build(BuildContext context) {
    final cleanCover = widget.coverUrl.trim();
    final bool hasValidCover = cleanCover.isNotEmpty &&
        !cleanCover.toLowerCase().endsWith('.mp4') &&
        !cleanCover.toLowerCase().endsWith('.mov') &&
        !cleanCover.toLowerCase().endsWith('.webm');

    // 1. Gambar cover statik
    if (hasValidCover) {
      return CachedNetworkImage(
        imageUrl: cleanCover,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _buildFallbackImage(),
      );
    }

    // 2. Frame video sebenar (paused pada frame 0)
    if (widget.isVideo && _isInitialized && _controller != null) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 300,
          height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 400,
          child: VideoPlayer(_controller!),
        ),
      );
    }

    // 3. Fallback estetik bertema kategori kedai
    return _buildFallbackImage();
  }

  Widget _buildFallbackImage() {
    final fallbackUrl = _getCategoryFallbackImage(widget.category);
    return CachedNetworkImage(
      imageUrl: fallbackUrl,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => Container(
        color: widget.isDark ? const Color(0xFF1E2430) : const Color(0xFFE2E8F0),
        child: Center(
          child: HugeIcon(
            icon: widget.isVideo ? HugeIcons.strokeRoundedVideo01 : HugeIcons.strokeRoundedImage01,
            color: widget.isDark ? Colors.white30 : Colors.black26,
            size: 24,
          ),
        ),
      ),
    );
  }
}

// ─── WIDGET: INTERACTIVE MODAL VIDEO PLAYER (WATCH SAVED VIDEO) ─────────
class _SavedPostViewerModal extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isDark;

  const _SavedPostViewerModal({required this.post, required this.isDark});

  @override
  State<_SavedPostViewerModal> createState() => _SavedPostViewerModalState();
}

class _SavedPostViewerModalState extends State<_SavedPostViewerModal> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = true;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    final String mediaUrl = (widget.post['image'] ?? '').toString().trim();
    final bool isVideo = widget.post['mediaType'] == 'video' ||
        mediaUrl.toLowerCase().endsWith('.mp4') ||
        mediaUrl.toLowerCase().endsWith('.mov') ||
        mediaUrl.toLowerCase().endsWith('.webm');

    if (isVideo && mediaUrl.isNotEmpty) {
      final uri = Uri.tryParse(mediaUrl);
      if (uri != null) {
        _controller = VideoPlayerController.networkUrl(uri);
        _controller!.initialize().then((_) {
          if (mounted) {
            setState(() => _isInitialized = true);
            _controller!.setLooping(true);
            _controller!.play();
          }
        }).catchError((_) {});
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
  }

  void _toggleMute() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final String shopName = widget.post['shopName'] ?? 'Kedai';
    final String shopAvatar = widget.post['shopAvatar'] ?? '';
    final String category = widget.post['category'] ?? 'Umum';
    final String title = widget.post['title'] ?? widget.post['caption'] ?? '';
    final String caption = widget.post['caption'] ?? '';
    final String shopId = widget.post['businessId']?.toString() ?? '';
    final isVideo = _controller != null;

    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth > 600;

    return Center(
      child: Container(
        width: isWide ? 460 : screenWidth,
        height: isWide ? (screenHeight * 0.85).clamp(500, 750) : screenHeight * 0.90,
        margin: isWide ? const EdgeInsets.all(24) : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: const Color(0xFF0F131C),
          borderRadius: BorderRadius.circular(isWide ? 28 : 24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isWide ? 28 : 24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Media Player or Image
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  color: Colors.black,
                  child: isVideo && _isInitialized
                      ? Center(
                          child: AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio > 0
                                ? _controller!.value.aspectRatio
                                : 9 / 16,
                            child: VideoPlayer(_controller!),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: (widget.post['cover'] ?? widget.post['image'] ?? '').toString(),
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const Center(
                            child: CircularProgressIndicator(color: Colors.blueAccent),
                          ),
                        ),
                ),
              ),

              // Play/Pause indicator icon when paused
              if (isVideo && _isInitialized && !_isPlaying)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
                  ),
                ),

              // Top Bar: Close Button & Sound Toggle
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    if (isVideo && _isInitialized)
                      GestureDetector(
                        onTap: _toggleMute,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Bottom Overlay: Shop Info, Caption, and View Store Button
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75),
                        Colors.black.withValues(alpha: 0.95),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: shopAvatar.isNotEmpty
                                ? CachedNetworkImageProvider(shopAvatar)
                                : null,
                            backgroundColor: Colors.white24,
                            child: shopAvatar.isEmpty
                                ? const HugeIcon(icon: HugeIcons.strokeRoundedStore01, color: Colors.white, size: 18)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shopName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  category.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (shopId.isNotEmpty)
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BusinessStoreView(
                                      shop: {
                                        'id': shopId,
                                        'business_id': shopId,
                                        'name': shopName,
                                        'business_name': shopName,
                                        'category': category,
                                      },
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text('Lihat Kedai', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      if (title.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (caption.isNotEmpty && caption != title) ...[
                        const SizedBox(height: 4),
                        Text(
                          caption,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
