import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/glass_toast.dart';
import '../explore/business_store_view.dart';

// =============================================================================
// CustomerFeedScreen — Ruangan "Feed" Interaktif, Visual & Ultra-Modern
// Perkongsian gaya rambut, transformasi cucian kereta, port kopi & reviu peniaga
// =============================================================================

class CustomerFeedScreen extends StatefulWidget {
  final void Function(int index)? onSwitchTab;

  const CustomerFeedScreen({super.key, this.onSwitchTab});

  @override
  State<CustomerFeedScreen> createState() => _CustomerFeedScreenState();
}

class _CustomerFeedScreenState extends State<CustomerFeedScreen> {
  int _selectedFilterIndex = 0;

  final List<String> _filters = [
    'Semua',
    '✂️ Barber',
    '🚗 Detailing',
    '☕ Kafe & Port',
    '🔥 Viral',
    '💆 Spa',
  ];

  // Feed posts dataset
  final List<Map<String, dynamic>> _posts = [
    {
      'id': '1',
      'shopName': 'Barber Danial',
      'shopAvatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=200',
      'category': 'barber',
      'timeAgo': '35 min lepas',
      'location': 'Bangi Sentral',
      'image': 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=600',
      'title': 'Low Taper Fade + Beard Sculpting 🔥',
      'caption': 'Hasil sentuhan kemas petang ini untuk regular bro Hazim. Slot walk-in dan giliran petang ni masih dibuka sampai jam 10 malam!',
      'serviceTag': 'Potong + Cuci • RM35',
      'likes': 142,
      'isLiked': false,
      'comments': 19,
      'queueStatus': 'Line Clear (1 Giliran)',
      'shopData': {
        'name': 'Barber Danial',
        'category': 'barber',
        'rating': 4.9,
        'reviews': 88,
        'image': 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=400',
      },
    },
    {
      'id': '2',
      'shopName': 'SpeedWash Detailing Autocare',
      'shopAvatar': 'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?q=80&w=200',
      'category': 'carwash',
      'timeAgo': '1 jam lepas',
      'location': 'Seksyen 9, Bangi',
      'image': 'https://images.unsplash.com/photo-1520340356584-f9917d1eea6f?q=80&w=600',
      'title': 'Cermin Kereta Bersinar Bak Kristal ✨',
      'caption': 'Pakej Nano Wax Coating + Interior Steam Wash promosi khas pertengahan bulan. Hilangkan watermark dan bau hapak kereta anda!',
      'serviceTag': 'Pakej Jimat • RM45',
      'likes': 89,
      'isLiked': true,
      'comments': 8,
      'queueStatus': '0 Menunggu (Masuk Terus)',
      'shopData': {
        'name': 'SpeedWash Detailing Autocare',
        'category': 'carwash',
        'rating': 4.8,
        'reviews': 120,
        'image': 'https://images.unsplash.com/photo-1520340356584-f9917d1eea6f?q=80&w=400',
      },
    },
    {
      'id': '3',
      'shopName': 'Kopi & Roti Artisan Corner',
      'shopAvatar': 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?q=80&w=200',
      'category': 'cafe',
      'timeAgo': '3 jam lepas',
      'location': 'Bandar Baru Bangi',
      'image': 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?q=80&w=600',
      'title': 'Iced Salted Caramel Butter Pecan Latte ☕',
      'caption': 'Port santai untuk buat kerja atau lepak sambil tunggu kereta siap dicuci. Ada high-speed WiFi dan plug di setiap meja.',
      'serviceTag': 'Menu Baru • RM14',
      'likes': 234,
      'isLiked': false,
      'comments': 42,
      'queueStatus': 'Port Tenang (Meja Tersedia)',
      'shopData': {
        'name': 'Kopi & Roti Artisan Corner',
        'category': 'cafe',
        'rating': 4.9,
        'reviews': 210,
        'image': 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?q=80&w=400',
      },
    },
    {
      'id': '4',
      'shopName': 'Changkat Jering Auto Garage',
      'shopAvatar': 'https://images.unsplash.com/photo-1486006920555-c77dce18193b?q=80&w=200',
      'category': 'workshop',
      'timeAgo': '5 jam lepas',
      'location': 'Changkat Jering',
      'image': 'https://images.unsplash.com/photo-1486006920555-c77dce18193b?q=80&w=600',
      'title': 'Servis Minyak Hitam & Brek Siap Dalam 25 Minit 🔧',
      'caption': 'Servis pantas tanpa perlu tinggal kereta seharian. Setiap pakej percuma pemeriksaan 21 poin keselamatan kenderaan.',
      'serviceTag': 'Servis Pakej • Dari RM85',
      'likes': 76,
      'isLiked': false,
      'comments': 12,
      'queueStatus': '2 Bay Sedang Servis',
      'shopData': {
        'name': 'Changkat Jering Auto Garage',
        'category': 'workshop',
        'rating': 4.7,
        'reviews': 95,
        'image': 'https://images.unsplash.com/photo-1486006920555-c77dce18193b?q=80&w=400',
      },
    },
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgGradStart = isDark ? const Color(0xFF0F1318) : const Color(0xFFF3F6FA);
    final Color bgGradEnd = isDark ? const Color(0xFF161B22) : const Color(0xFFE9EEF4);

    return Scaffold(
      backgroundColor: bgGradStart,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgGradStart, bgGradEnd],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Top Bar Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Ngam Feed',
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF00E5FF), Color(0xFF3B82F6)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Gaya, Hasil Servis & Port Viral Komuniti',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      // Create / Post button or Search
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.6),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedSparkles,
                            color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0284C7),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Filter Chips Row
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final isSelected = _selectedFilterIndex == index;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedFilterIndex = index;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.8)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.white.withValues(alpha: isDark ? 0.12 : 0.5),
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              _filters[index],
                              style: TextStyle(
                                color: isSelected
                                    ? (isDark ? Colors.black : Colors.white)
                                    : (isDark ? Colors.white70 : Colors.black87),
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              // Feed Posts List
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = _posts[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: _buildFeedCard(post, isDark),
                    );
                  },
                  childCount: _posts.length,
                ),
              ),

              // Bottom Spacer
              const SliverToBoxAdapter(child: SizedBox(height: 130)),
            ],
          ),
        ),
      ),
    );
  }

  // --- FEED POST CARD ---
  Widget _buildFeedCard(Map<String, dynamic> post, bool isDark) {
    final bool isLiked = post['isLiked'] ?? false;
    final int likesCount = post['likes'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161C24) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Post Header: Avatar + Shop Name + Category & Time
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF00E5FF),
                        width: 1.5,
                      ),
                      image: DecorationImage(
                        image: NetworkImage(post['shopAvatar']),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                post['shopName'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              color: Color(0xFF00E5FF),
                              size: 15,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${post['location']} • ${post['timeAgo']}',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Shop details button
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BusinessStoreView(shop: post['shopData'] ?? {}),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Lihat Kedai',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0284C7),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Post Hero Image with Service Tag & Queue Tag
            Stack(
              children: [
                SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: post['image'],
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: isDark ? Colors.grey.shade900 : Colors.grey.shade300,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: isDark ? Colors.grey.shade900 : Colors.grey.shade300,
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
                ),
                // Gradient overlay bottom
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 90,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                  ),
                ),
                // Service Price Tag (Bottom Left)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedSparkles,
                          color: Color(0xFF00E5FF),
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          post['serviceTag'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Live Queue Status Pill (Top Right)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          size: 13,
                          color: Color(0xFF003852),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          post['queueStatus'],
                          style: const TextStyle(
                            color: Color(0xFF003852),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // 3. Post Body: Title & Caption
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post['title'],
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    post['caption'],
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // 4. Action Bar (Likes, Comments, Direct Queue CTA Button)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Row(
                children: [
                  // Like button
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        post['isLiked'] = !isLiked;
                        post['likes'] = isLiked ? (likesCount - 1) : (likesCount + 1);
                      });
                    },
                    child: Row(
                      children: [
                        Icon(
                          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isLiked ? const Color(0xFFFF3366) : (isDark ? Colors.white70 : Colors.black54),
                          size: 22,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${post['likes']}',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 18),

                  // Comment button
                  GestureDetector(
                    onTap: () {
                      showGlassToast(
                        context,
                        'Komen akan dibuka sebentar lagi!',
                        icon: HugeIcons.strokeRoundedComment01,
                      );
                    },
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedComment01,
                          color: isDark ? Colors.white70 : Colors.black54,
                          size: 20,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${post['comments']}',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Direct CTA Button: "Ambil Giliran / Tempah"
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BusinessStoreView(shop: post['shopData'] ?? {}),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E5FF), Color(0xFF0284C7)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Text(
                            'Ambil Giliran',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
