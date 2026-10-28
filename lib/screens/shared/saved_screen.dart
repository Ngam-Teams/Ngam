import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../services/saved_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/glass_toast.dart';
import '../explore/business_store_view.dart';

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
    SavedService.init();
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

        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.72,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return _buildPostCard(post, isDark);
          },
        );
      },
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, bool isDark) {
    final String postId = (post['id'] ?? '').toString();
    final String shopName = post['shopName'] ?? 'Kedai';
    final String title = post['title'] ?? post['caption'] ?? '';
    final String image = post['image'] ?? '';
    final String mediaType = post['mediaType'] ?? 'image';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141923) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Media Background
            Positioned.fill(
              child: image.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: Colors.grey.shade900),
                    )
                  : Container(color: Colors.grey.shade900),
            ),

            // Top gradient & video badge
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(
                      icon: mediaType == 'video'
                          ? HugeIcons.strokeRoundedVideo01
                          : HugeIcons.strokeRoundedImage01,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      mediaType.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            // Unsave Bookmark Button
            Positioned(
              top: 8,
              right: 8,
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
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bookmark_rounded,
                    color: Color(0xFFFBBF24),
                    size: 16,
                  ),
                ),
              ),
            ),

            // Bottom Gradient Overlay + Text
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      shopName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title.isNotEmpty ? title : 'Promosi Istimewa',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

  // ─── EMPTY STATE WIDGET ────────────────────────────────────────
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
