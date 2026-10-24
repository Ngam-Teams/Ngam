import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../widgets/glass_toast.dart';
import '../explore/business_store_view.dart';

// =============================================================================
// CustomerFeedScreen — Ruangan "Ngam Feed" Gaya TikTok / Reels Penuh
// Pengalaman Skrin Penuh (Immersive Snap), Butang Tindakan Kanan,
// Interaksi Double-Tap Like & Butang Pintas Tempahan/Giliran Eksklusif
// =============================================================================

class CustomerFeedScreen extends StatefulWidget {
  final void Function(int index)? onSwitchTab;

  const CustomerFeedScreen({super.key, this.onSwitchTab});

  @override
  State<CustomerFeedScreen> createState() => _CustomerFeedScreenState();
}

class _CustomerFeedScreenState extends State<CustomerFeedScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _discAnimController;

  int _activeTopTab = 1; // 0: 'Berhampiran', 1: 'Untuk Anda'
  int _currentPage = 0;
  bool _isMuted = false;

  // Double-tap heart animation items
  final List<_FloatingHeart> _hearts = [];

  // Feed posts dataset fallback (Demo)
  static final List<Map<String, dynamic>> _demoPosts = [
    {
      'id': '1',
      'shopName': 'Barber Danial',
      'shopHandle': '@barberdanial',
      'shopAvatar':
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=200',
      'category': 'barber',
      'timeAgo': '35 min lepas',
      'location': 'Bangi Sentral',
      'image':
          'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=800',
      'title': 'Low Taper Fade + Beard Sculpting 🔥',
      'caption':
          'Hasil sentuhan kemas petang ini untuk regular bro Hazim. Slot walk-in dan giliran petang ni masih dibuka sampai jam 10 malam! #barber #taperfade #ngam',
      'serviceTag': '✂️ Potong + Cuci • RM35 · Buka Hingga 10:00 PM',
      'ctaText': '⚡ AMBIL GILIRAN (1 MENUNGGU)',
      'likes': 142,
      'isLiked': false,
      'isSaved': false,
      'isFollowed': false,
      'comments': 19,
      'commentList': [
        {
          'user': 'Hazim Azlan',
          'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=150',
          'text': 'Memang kemas bro! Balik rumah bini terus puji haha 👍',
          'time': '20m lepas',
          'likes': 4,
        },
        {
          'user': 'Farhan Barber',
          'avatar': 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?q=80&w=150',
          'text': 'Fade paling licin minggu ni 🔥 Mantap Danial!',
          'time': '15m lepas',
          'likes': 2,
        },
        {
          'user': 'Syed Amir',
          'avatar': 'https://images.unsplash.com/photo-1527980965255-d3b416303d12?q=80&w=150',
          'text': 'Kena book awal ke bro atau boleh walk-in petang ni?',
          'time': '5m lepas',
          'likes': 1,
        },
      ],
      'shopData': {
        'name': 'Barber Danial',
        'category': 'barber',
        'rating': 4.9,
        'reviews': 88,
        'image':
            'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=400',
      },
    },
    {
      'id': '2',
      'shopName': 'SpeedWash Detailing Autocare',
      'shopHandle': '@speedwash_detailing',
      'shopAvatar':
          'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?q=80&w=200',
      'category': 'carwash',
      'timeAgo': '1 jam lepas',
      'location': 'Seksyen 9, Bangi',
      'image':
          'https://images.unsplash.com/photo-1520340356584-f9917d1eea6f?q=80&w=800',
      'title': 'Cermin Kereta Bersinar Bak Kristal ✨',
      'caption':
          'Pakej Nano Wax Coating + Interior Steam Wash promosi khas pertengahan bulan. Hilangkan watermark dan bau hapak kereta anda sekarang! #detailing #carwash #ngam',
      'serviceTag': '🚗 Nano Coating • RM45 · 3 Bay Cucian Aktif',
      'ctaText': '🚗 MASUK TERUS (0 MENUNGGU)',
      'likes': 89,
      'isLiked': true,
      'isSaved': true,
      'isFollowed': true,
      'comments': 8,
      'commentList': [
        {
          'user': 'Afiq Honda',
          'avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=150',
          'text': 'Watermark kat cermin depan betul-betul hilang. Servis tiptop!',
          'time': '45m lepas',
          'likes': 5,
        },
      ],
      'shopData': {
        'name': 'SpeedWash Detailing Autocare',
        'category': 'carwash',
        'rating': 4.8,
        'reviews': 120,
        'image':
            'https://images.unsplash.com/photo-1520340356584-f9917d1eea6f?q=80&w=400',
      },
    },
    {
      'id': '3',
      'shopName': 'Kopi & Roti Artisan Corner',
      'shopHandle': '@kopiroti_artisan',
      'shopAvatar':
          'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?q=80&w=200',
      'category': 'cafe',
      'timeAgo': '3 jam lepas',
      'location': 'Bandar Baru Bangi',
      'image':
          'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?q=80&w=800',
      'title': 'Iced Salted Caramel Butter Pecan Latte ☕',
      'caption':
          'Port santai untuk buat kerja atau lepak sambil tunggu kereta siap dicuci. Ada high-speed WiFi dan plug di setiap meja santai. #ngamcafe #kopiroti #viral',
      'serviceTag': '☕ Menu Baru Musim Ini • RM14 · Meja Santai Tersedia',
      'ctaText': '☕ PESAN QR / TEMPAH MEJA',
      'likes': 234,
      'isLiked': false,
      'isSaved': false,
      'isFollowed': false,
      'comments': 42,
      'commentList': [
        {
          'user': 'Sarah Nadia',
          'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=150',
          'text': 'Butter Pecan dia memang sedap gila, tak manis sangat ☕🤍',
          'time': '2j lepas',
          'likes': 12,
        },
      ],
      'shopData': {
        'name': 'Kopi & Roti Artisan Corner',
        'category': 'cafe',
        'rating': 4.9,
        'reviews': 210,
        'image':
            'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?q=80&w=400',
      },
    },
    {
      'id': '4',
      'shopName': 'Changkat Jering Auto Garage',
      'shopHandle': '@changkat_autogarage',
      'shopAvatar':
          'https://images.unsplash.com/photo-1486006920555-c77dce18193b?q=80&w=200',
      'category': 'workshop',
      'timeAgo': '5 jam lepas',
      'location': 'Changkat Jering',
      'image':
          'https://images.unsplash.com/photo-1486006920555-c77dce18193b?q=80&w=800',
      'title': 'Servis Minyak Hitam & Brek Siap Dalam 25 Minit 🔧',
      'caption':
          'Servis pantas tanpa perlu tinggal kereta seharian. Percuma pemeriksaan 21 poin keselamatan kenderaan untuk setiap pelanggan Ngam. #bengkel #serviskereta',
      'serviceTag': '🔧 Pakej Servis • Dari RM85 · 2 Bay Sedang Servis',
      'ctaText': '⚡ AMBIL TIKET SERVIS',
      'likes': 76,
      'isLiked': false,
      'isSaved': false,
      'isFollowed': false,
      'comments': 12,
      'commentList': [],
      'shopData': {
        'name': 'Changkat Jering Auto Garage',
        'category': 'workshop',
        'rating': 4.7,
        'reviews': 95,
        'image':
            'https://images.unsplash.com/photo-1486006920555-c77dce18193b?q=80&w=400',
      },
    },
  ];

  // Active Feed Posts (Live from Supabase or fallback)
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _posts = List.from(_demoPosts);
    _pageController = PageController();
    _discAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _fetchLivePosts();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _discAnimController.dispose();
    super.dispose();
  }

  /// Tarik pos suapan langsung dari jadual 'feed_posts' (bersama maklumat kedai)
  Future<void> _fetchLivePosts() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('feed_posts')
          .select('''
            id,
            business_id,
            title,
            caption,
            media_url,
            media_type,
            category,
            service_tag,
            cta_type,
            cta_text,
            status,
            is_pinned,
            likes_count,
            comments_count,
            shares_count,
            views_count,
            created_at,
            businesses (
              id,
              business_name,
              business_handle,
              business_logo_url,
              business_industry,
              business_city,
              state
            )
          ''')
          .eq('status', 'published')
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false);

      if (res.isNotEmpty) {
        final List<Map<String, dynamic>> loaded = [];
        for (final item in res) {
          final row = Map<String, dynamic>.from(item as Map);
          final biz = row['businesses'] != null
              ? Map<String, dynamic>.from(row['businesses'] as Map)
              : <String, dynamic>{};

          final shopName = biz['business_name']?.toString() ?? 'Kedai Ngam';
          final handleRaw = biz['business_handle']?.toString();
          final shopHandle = (handleRaw != null && handleRaw.trim().isNotEmpty)
              ? (handleRaw.trim().startsWith('@')
                  ? handleRaw.trim()
                  : '@${handleRaw.trim()}')
              : '@${shopName.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';

          final logoUrl = biz['business_logo_url']?.toString() ??
              biz['logo_url']?.toString();
          final shopAvatar = (logoUrl != null && logoUrl.trim().isNotEmpty)
              ? logoUrl.trim()
              : 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200';

          final locParts = [biz['business_city'], biz['state']]
              .where((s) => s != null && s.toString().trim().isNotEmpty)
              .map((s) => s.toString().trim())
              .toList();
          final location =
              locParts.isNotEmpty ? locParts.join(', ') : 'Malaysia';

          // Format masa
          final createdAt =
              DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                  DateTime.now();
          final diff = DateTime.now().difference(createdAt);
          String timeAgo;
          if (diff.inMinutes < 60) {
            final m = diff.inMinutes;
            timeAgo = '${m > 0 ? m : 1} min lepas';
          } else if (diff.inHours < 24) {
            timeAgo = '${diff.inHours} jam lepas';
          } else if (diff.inDays < 7) {
            timeAgo = '${diff.inDays} hari lepas';
          } else {
            timeAgo = '${createdAt.day}/${createdAt.month}/${createdAt.year}';
          }

          final mediaUrl = row['media_url']?.toString() ?? '';
          final ctaType = row['cta_type']?.toString() ?? 'queue';
          final ctaText = row['cta_text']?.toString() ?? '⚡ AMBIL GILIRAN';
          final serviceTag =
              row['service_tag']?.toString() ?? '⚡ Servis Pantas Ngam';

          loaded.add({
            'id': row['id'].toString(),
            'businessId': row['business_id']?.toString(),
            'shopName': shopName,
            'shopHandle': shopHandle,
            'shopAvatar': shopAvatar,
            'category': row['category'] ?? biz['business_industry'] ?? 'general',
            'timeAgo': timeAgo,
            'location': location,
            'image': mediaUrl.isNotEmpty
                ? mediaUrl
                : 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=800',
            'mediaType': row['media_type'] ?? 'image',
            'title': row['title'] ?? '',
            'caption': row['caption'] ?? '',
            'serviceTag': serviceTag,
            'ctaType': ctaType,
            'ctaText': ctaText,
            'likes': (row['likes_count'] as num?)?.toInt() ?? 0,
            'isLiked': false,
            'isSaved': false,
            'isFollowed': false,
            'comments': (row['comments_count'] as num?)?.toInt() ?? 0,
            'commentList': <Map<String, dynamic>>[],
            'shopData': {
              'id': biz['id'] ?? row['business_id'],
              'name': shopName,
              'business_name': shopName,
              'business_handle': shopHandle,
              'logo_url': shopAvatar,
              'image': shopAvatar,
              'category':
                  biz['business_industry'] ?? row['category'] ?? 'general',
              'rating': 4.9,
              'reviews': 50,
            },
          });
        }

        if (mounted) {
          setState(() {
            _posts = loaded;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('[CustomerFeedScreen] Live posts fetch fallback to demo: $e');
    }

    if (mounted) {
      setState(() {
        if (_posts.isEmpty) {
          _posts = List.from(_demoPosts);
        }
        _isLoading = false;
      });
    }
  }

  // Double-tap handler for heart animation
  void _handleDoubleTap(Offset position, Map<String, dynamic> post) {
    final bool wasLiked = post['isLiked'] == true;
    setState(() {
      if (!wasLiked) {
        post['isLiked'] = true;
        post['likes'] = (post['likes'] as int) + 1;
      }
      _hearts.add(_FloatingHeart(
        key: UniqueKey(),
        position: position,
        onComplete: (key) {
          if (mounted) {
            setState(() {
              _hearts.removeWhere((h) => h.key == key);
            });
          }
        },
      ));
    });

    if (!wasLiked) {
      final postId = post['id']?.toString();
      if (postId != null && postId.length > 20) {
        Supabase.instance.client.rpc('toggle_feed_post_like', params: {
          'p_post_id': postId,
          'p_increment': true,
        }).catchError((e) {
          debugPrint('[CustomerFeedScreen] Double-tap like RPC failed: $e');
        });
      }
    }
  }

  void _toggleLike(Map<String, dynamic> post) {
    setState(() {
      final isLiked = post['isLiked'] as bool;
      post['isLiked'] = !isLiked;
      post['likes'] = (post['likes'] as int) + (isLiked ? -1 : 1);
    });

    final postId = post['id']?.toString();
    if (postId != null && postId.length > 20) {
      Supabase.instance.client.rpc('toggle_feed_post_like', params: {
        'p_post_id': postId,
        'p_increment': post['isLiked'] == true,
      }).catchError((e) {
        debugPrint('[CustomerFeedScreen] Like RPC failed: $e');
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    if (index >= 0 && index < _posts.length) {
      final post = _posts[index];
      final postId = post['id']?.toString();
      if (postId != null && postId.length > 20) {
        Supabase.instance.client.rpc('increment_feed_post_views', params: {
          'p_post_id': postId,
        }).catchError((e) {
          debugPrint('[CustomerFeedScreen] View count RPC failed: $e');
        });
      }
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    showGlassToast(
      context,
      _isMuted ? 'Audio Dimatikan 🔇' : 'Audio Dihidupkan 🔊',
      icon: _isMuted
          ? Icons.volume_off_rounded
          : Icons.volume_up_rounded,
    );
  }

  void _handleCtaAction(Map<String, dynamic> post) {
    final ctaType = post['ctaType']?.toString() ?? 'queue';
    if (ctaType == 'queue') {
      _openStore(post);
      showGlassToast(
        context,
        'Membuka giliran untuk ${post['shopName']} ⚡',
        icon: HugeIcons.strokeRoundedFlash,
      );
    } else if (ctaType == 'booking') {
      _openStore(post);
      showGlassToast(
        context,
        'Membuka tempahan untuk ${post['shopName']} 📅',
        icon: HugeIcons.strokeRoundedCalendar03,
      );
    } else {
      _openStore(post);
    }
  }

  void _toggleFollow(Map<String, dynamic> post) {
    setState(() {
      final isFollowed = post['isFollowed'] as bool;
      post['isFollowed'] = !isFollowed;
    });
    showGlassToast(
      context,
      post['isFollowed']
          ? 'Mengikuti ${post['shopName']} ✓'
          : 'Batal ikuti ${post['shopName']}',
      icon: post['isFollowed']
          ? HugeIcons.strokeRoundedCheckmarkCircle02
          : HugeIcons.strokeRoundedUserRemove01,
    );
  }

  void _toggleSave(Map<String, dynamic> post) {
    setState(() {
      final isSaved = post['isSaved'] as bool;
      post['isSaved'] = !isSaved;
    });
    showGlassToast(
      context,
      post['isSaved']
          ? 'Disimpan ke koleksi simpanan anda 🔖'
          : 'Dikeluarkan dari simpanan',
      icon: HugeIcons.strokeRoundedBookmark02,
    );
  }

  void _sharePost(Map<String, dynamic> post) {
    showGlassToast(
      context,
      'Pautan ${post['shopName']} disalin ke papan klip! 📋',
      icon: HugeIcons.strokeRoundedShare01,
    );
  }

  void _openStore(Map<String, dynamic> post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessStoreView(shop: post['shopData'] ?? {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double safeBottom = MediaQuery.paddingOf(context).bottom;
    final double safeTop = MediaQuery.paddingOf(context).top;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isDesktopLandscape = screenWidth > 700;
    
    // Bottom padding to position feed content nicely above the floating navbar
    final double bottomOffset = (safeBottom > 0 ? safeBottom : 16) + 78;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
              event.logicalKey == LogicalKeyboardKey.pageDown) {
            if (_currentPage < _posts.length - 1) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
              );
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
              event.logicalKey == LogicalKeyboardKey.pageUp) {
            if (_currentPage > 0) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
              );
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
            _toggleMute();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
        children: [
          // 1. VERTICAL FULL SCREEN PAGEVIEW (TIKTOK STYLE)
          RefreshIndicator(
            color: const Color(0xFF00E5FF),
            backgroundColor: const Color(0xFF141920),
            onRefresh: _fetchLivePosts,
            child: _posts.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isLoading) ...[
                                const CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF00E5FF),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Memuatkan suapan Ngam...',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ] else ...[
                                const Icon(
                                  Icons.movie_filter_rounded,
                                  size: 48,
                                  color: Colors.white24,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Tiada pos suapan ditemui.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: _fetchLivePosts,
                                  icon: const Icon(Icons.refresh_rounded,
                                      color: Color(0xFF00E5FF)),
                                  label: const Text(
                                    'Muat Semula',
                                    style: TextStyle(color: Color(0xFF00E5FF)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    onPageChanged: _onPageChanged,
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      return _buildFeedItem(post, bottomOffset, index);
                    },
                  ),
          ),

          // 2. DOUBLE-TAP POPPING HEARTS OVERLAY
          ..._hearts,

          // 3. TOP NAVIGATION OVERLAY (Header + FYP & Nearby Tabs)
          Positioned(
            top: safeTop > 0 ? safeTop + 6 : 14,
            left: 0,
            right: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktopLandscape ? 720 : double.infinity,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Logo Badge (Tap to refresh feed)
                      GestureDetector(
                        onTap: () {
                          _fetchLivePosts();
                          showGlassToast(
                            context,
                            'Memuat semula suapan Ngam... 🔄',
                            icon: HugeIcons.strokeRoundedRefresh,
                          );
                        },
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF00E5FF), Color(0xFF0284C7)],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'NGAM',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'FEED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Center Feed Switcher: 'Berhampiran' vs 'Untuk Anda'
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() => _activeTopTab = 0);
                                showGlassToast(
                                  context,
                                  'Menapis pos dalam radius 10KM 📍',
                                  icon: HugeIcons.strokeRoundedLocation01,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                child: Text(
                                  'Berhampiran',
                                  style: TextStyle(
                                    color: _activeTopTab == 0
                                        ? Colors.white
                                        : Colors.white54,
                                    fontSize: 13,
                                    fontWeight: _activeTopTab == 0
                                        ? FontWeight.w900
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                color: Colors.white30,
                                shape: BoxShape.circle,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() => _activeTopTab = 1);
                                showGlassToast(
                                  context,
                                  'Memaparkan pos paling trending 🔥',
                                  icon: HugeIcons.strokeRoundedFire,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                child: Text(
                                  'Untuk Anda',
                                  style: TextStyle(
                                    color: _activeTopTab == 1
                                        ? Colors.white
                                        : Colors.white54,
                                    fontSize: 13,
                                    fontWeight: _activeTopTab == 1
                                        ? FontWeight.w900
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Search / Discover shortcut
                      GestureDetector(
                        onTap: () {
                          if (widget.onSwitchTab != null) {
                            widget.onSwitchTab!(1); // Go to Discover Tab
                          }
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Center(
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedSearch01,
                              color: Colors.white,
                              size: 17,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 4. DESKTOP NAVIGATION ARROWS (TIKTOK STYLE)
          if (isDesktopLandscape && _posts.length > 1)
            Positioned(
              right: 28,
              top: 0,
              bottom: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDesktopNavArrow(
                      icon: Icons.keyboard_arrow_up_rounded,
                      tooltip: 'Pos Sebelumnya (↑)',
                      enabled: _currentPage > 0,
                      onTap: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildDesktopNavArrow(
                      icon: Icons.keyboard_arrow_down_rounded,
                      tooltip: 'Pos Seterusnya (↓)',
                      enabled: _currentPage < _posts.length - 1,
                      onTap: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        );
                      },
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

  // --- SINGLE FEED POST ITEM (RESPONSIVE TIKTOK DESKTOP / MOBILE ADAPTIVE) ---
  Widget _buildFeedItem(
      Map<String, dynamic> post, double bottomOffset, int index) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final bool isDesktopLandscape = screenWidth > 700;
    final bool isShortPhone = screenHeight < 720;

    if (isDesktopLandscape) {
      // -------------------------------------------------------------
      // TIKTOK DESKTOP / LANDSCAPE MODE
      // Centered 9:16 vertical video card, ambient blurred backdrop,
      // action bar resting right beside the card (no 1920px stretching!)
      // -------------------------------------------------------------
      final double cardHeight = (screenHeight - 110).clamp(460.0, 780.0);
      final double cardWidth = (cardHeight * (9 / 16)).clamp(300.0, 460.0);

      return Stack(
        fit: StackFit.expand,
        children: [
          // 1. Cinematic Ambient Blurred Backdrop (Signature TikTok Desktop glow)
          if (post['image'] != null && (post['image'] as String).isNotEmpty)
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                    child: CachedNetworkImage(
                      imageUrl: post['image'],
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  Container(
                    color: Colors.black.withValues(alpha: 0.82),
                  ),
                ],
              ),
            ),

          // 2. Centered Video Card + Action Bar Right Beside It
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Centered 9:16 Video Canvas
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: cardWidth,
                      height: cardHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0F15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.7),
                            blurRadius: 36,
                            spreadRadius: 8,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: GestureDetector(
                        onDoubleTapDown: (details) {
                          _handleDoubleTap(details.globalPosition, post);
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildMediaContent(post, index),

                            // Top shadow gradient
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 100,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.6),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Bottom shadow gradient
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: 280,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.5),
                                      Colors.black.withValues(alpha: 0.88),
                                      Colors.black,
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Caption & CTA overlay inside card
                            Positioned(
                              left: 14,
                              right: 14,
                              bottom: 16,
                              child: _buildBottomContent(post),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Action Bar (Placed gracefully next to the card)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildActionBar(
                      post,
                      isShortPhone: false,
                      isDesktop: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // -------------------------------------------------------------
    // MOBILE / VERTICAL PHONE MODE
    // Full screen edge-to-edge immersive experience
    // -------------------------------------------------------------
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. FULL SCREEN MEDIA / IMAGE (Interactive Double Tap)
        GestureDetector(
          onDoubleTapDown: (details) {
            _handleDoubleTap(details.globalPosition, post);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildMediaContent(post, index),

              // Top dark shadow gradient
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 140,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom heavy shadow gradient
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 380,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                        Colors.black.withValues(alpha: 0.88),
                        Colors.black,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. RIGHT-SIDE FLOATING ACTION BAR (Mobile)
        Positioned(
          right: 12,
          bottom: bottomOffset + 6,
          child: _buildActionBar(
            post,
            isShortPhone: isShortPhone,
            isDesktop: false,
          ),
        ),

        // 3. BOTTOM CONTENT OVERLAY (Mobile)
        Positioned(
          left: 16,
          right: 76,
          bottom: bottomOffset,
          child: _buildBottomContent(post),
        ),
      ],
    );
  }

  // --- MEDIA CONTENT BUILDER (VIDEO PLAYER OR IMAGE) ---
  Widget _buildMediaContent(Map<String, dynamic> post, int index) {
    final bool isVideo = post['mediaType'] == 'video' &&
        post['image'] != null &&
        (post['image'] as String).isNotEmpty;

    if (isVideo) {
      return _FeedVideoPlayerItem(
        videoUrl: post['image'],
        isCurrentPage: index == _currentPage,
        isMuted: _isMuted,
        onToggleMute: _toggleMute,
      );
    }

    return CachedNetworkImage(
      imageUrl: post['image'] ?? '',
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: const Color(0xFF11171E),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF00E5FF),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        color: const Color(0xFF11171E),
        child: const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.white38),
        ),
      ),
    );
  }

  // --- BOTTOM CONTENT (CTA, SHOP HANDLE, CAPTION, MUSIC TICKER) ---
  Widget _buildBottomContent(Map<String, dynamic> post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // EXCLUSIVE NGAM DIRECT CTA BUTTON
        GestureDetector(
          onTap: () => _handleCtaAction(post),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFF0284C7)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  color: Colors.black,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    post['ctaText'] ?? 'AMBIL GILIRAN',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.black,
                  size: 11,
                ),
              ],
            ),
          ),
        ),

        // Shop Handle & Verified Badge
        GestureDetector(
          onTap: () => _openStore(post),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  post['shopHandle'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 6),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.verified_rounded,
                color: Color(0xFF00E5FF),
                size: 16,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '· ${post['location']}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Post Caption & Hashtags
        Text(
          post['caption'],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            height: 1.35,
            fontWeight: FontWeight.w500,
            shadows: [
              Shadow(color: Colors.black87, blurRadius: 6),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 8),

        // Rolling Music / Service Price Ticker
        Row(
          children: [
            const Icon(
              Icons.music_note_rounded,
              color: Color(0xFF00E5FF),
              size: 14,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                post['serviceTag'],
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 4),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- FLOATING ACTION BAR (AVATAR, LIKE, COMMENT, SAVE, SHARE, MUTE, VINYL) ---
  Widget _buildActionBar(
    Map<String, dynamic> post, {
    required bool isShortPhone,
    required bool isDesktop,
  }) {
    final bool isLiked = post['isLiked'] ?? false;
    final bool isSaved = post['isSaved'] ?? false;
    final bool isFollowed = post['isFollowed'] ?? false;
    final int likes = post['likes'] ?? 0;
    final int comments = post['comments'] ?? 0;
    final double actionSpacing = isShortPhone ? 10 : (isDesktop ? 16 : 14);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar with Follow Plus / Check Badge
        GestureDetector(
          onTap: () => _openStore(post),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: isShortPhone ? 42 : 48,
                height: isShortPhone ? 42 : 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00E5FF),
                    width: 2,
                  ),
                  image: DecorationImage(
                    image: NetworkImage(post['shopAvatar']),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: -7,
                child: GestureDetector(
                  onTap: () => _toggleFollow(post),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isShortPhone ? 18 : 20,
                    height: isShortPhone ? 18 : 20,
                    decoration: BoxDecoration(
                      color: isFollowed
                          ? const Color(0xFF10B981)
                          : const Color(0xFF00E5FF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isFollowed
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF00E5FF))
                              .withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Icon(
                      isFollowed ? Icons.check_rounded : Icons.add_rounded,
                      size: isShortPhone ? 12 : 14,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: isShortPhone ? 12 : (isDesktop ? 18 : 16)),

        // Like (Hati) Action
        _buildRightActionButton(
          icon: isLiked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          iconColor: isLiked ? const Color(0xFFFF2B54) : Colors.white,
          label: '$likes',
          isCompact: isShortPhone,
          onTap: () => _toggleLike(post),
        ),

        SizedBox(height: actionSpacing),

        // Comment Action
        _buildRightActionButton(
          hugeIcon: HugeIcons.strokeRoundedComment01,
          label: '$comments',
          isCompact: isShortPhone,
          onTap: () => _showCommentsModal(context, post),
        ),

        SizedBox(height: actionSpacing),

        // Save / Bookmark Action
        _buildRightActionButton(
          icon: isSaved
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          iconColor: isSaved ? const Color(0xFFFBBF24) : Colors.white,
          label: 'Simpan',
          isCompact: isShortPhone,
          onTap: () => _toggleSave(post),
        ),

        SizedBox(height: actionSpacing),

        // Share Action
        _buildRightActionButton(
          hugeIcon: HugeIcons.strokeRoundedShare01,
          label: 'Kongsi',
          isCompact: isShortPhone,
          onTap: () => _sharePost(post),
        ),

        SizedBox(height: actionSpacing),

        // Audio Mute/Unmute Action for Video
        if (post['mediaType'] == 'video') ...[
          _buildRightActionButton(
            icon: _isMuted
                ? Icons.volume_off_rounded
                : Icons.volume_up_rounded,
            iconColor: _isMuted ? Colors.white54 : const Color(0xFF00E5FF),
            label: _isMuted ? 'Bisu' : 'Audio',
            isCompact: isShortPhone,
            onTap: _toggleMute,
          ),
          SizedBox(height: actionSpacing),
        ],

        // Rotating Merchant Vinyl Disc
        GestureDetector(
          onTap: () => _openStore(post),
          child: RotationTransition(
            turns: _discAnimController,
            child: Container(
              width: isShortPhone ? 34 : 40,
              height: isShortPhone ? 34 : 40,
              padding: EdgeInsets.all(isShortPhone ? 6 : 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF222831), Color(0xFF0F141A)],
                ),
                border: Border.all(color: Colors.white24, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage(post['shopAvatar']),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- DESKTOP NAVIGATION ARROW BUTTON ---
  Widget _buildDesktopNavArrow({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: enabled
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.04),
              shape: BoxShape.circle,
              border: Border.all(
                color: enabled ? Colors.white24 : Colors.white10,
                width: 1.2,
              ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                icon,
                color: enabled ? Colors.white : Colors.white24,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- RIGHT FLOATING ACTION BUTTON BUILDER ---
  Widget _buildRightActionButton({
    IconData? icon,
    dynamic hugeIcon,
    Color iconColor = Colors.white,
    required String label,
    bool isCompact = false,
    required VoidCallback onTap,
  }) {
    final double buttonSize = isCompact ? 38 : 44;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: icon != null
                  ? Icon(icon, color: iconColor, size: isCompact ? 22 : 26)
                  : HugeIcon(icon: hugeIcon, color: iconColor, size: isCompact ? 19 : 22),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 10 : 11,
              fontWeight: FontWeight.w700,
              shadows: const [
                Shadow(color: Colors.black, blurRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- COMMENTS MODAL SHEET ---
  void _showCommentsModal(BuildContext context, Map<String, dynamic> post) {
    final List comments = post['commentList'] ?? [];
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.65,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141920),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border.all(color: Colors.white10),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 20,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                children: [
                  // Handle Bar
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Komen (${comments.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white60, size: 20),
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white10, height: 1),

                  // Comment List
                  Expanded(
                    child: comments.isEmpty
                        ? const Center(
                            child: Text(
                              'Belum ada komen lagi.\nJadilah yang pertama!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            itemCount: comments.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 16),
                            itemBuilder: (_, idx) {
                              final c = comments[idx];
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 17,
                                    backgroundImage:
                                        NetworkImage(c['avatar']),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              c['user'],
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              c['time'],
                                              style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          c['text'],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    children: [
                                      const Icon(
                                        Icons.favorite_border_rounded,
                                        size: 16,
                                        color: Colors.white38,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${c['likes'] ?? 0}',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                  ),

                  // Comment Input Field at Bottom
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      10,
                      14,
                      MediaQuery.of(context).viewInsets.bottom + 12,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F1318),
                      border: Border(top: BorderSide(color: Colors.white10)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: TextField(
                              controller: commentController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Tulis komen anda...',
                                hintStyle: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            if (commentController.text.trim().isNotEmpty) {
                              setModalState(() {
                                comments.add({
                                  'user': 'Anda',
                                  'avatar':
                                      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=150',
                                  'text': commentController.text.trim(),
                                  'time': 'Sekarang',
                                  'likes': 0,
                                });
                                post['comments'] = comments.length;
                              });
                              commentController.clear();
                              setState(() {});
                            }
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF00E5FF), Color(0xFF0284C7)],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.arrow_upward_rounded,
                                color: Colors.black,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  },
);
  }
}

// =============================================================================
// Helper: Double-Tap Floating Heart Widget with Pop & Fade Animation
// =============================================================================
class _FloatingHeart extends StatefulWidget {
  final Offset position;
  final void Function(Key key) onComplete;

  const _FloatingHeart({
    required super.key,
    required this.position,
    required this.onComplete,
  });

  @override
  State<_FloatingHeart> createState() => _FloatingHeartState();
}

class _FloatingHeartState extends State<_FloatingHeart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late double _rotationAngle;

  @override
  void initState() {
    super.initState();
    // Slight random rotation for natural TikTok feel
    _rotationAngle = (math.Random().nextDouble() - 0.5) * 0.4;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.2, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 40),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward().then((_) {
      widget.onComplete(widget.key!);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 45,
      top: widget.position.dy - 45,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.rotate(
              angle: _rotationAngle,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            ),
          );
        },
        child: const Icon(
          Icons.favorite_rounded,
          color: Color(0xFFFF2B54),
          size: 90,
          shadows: [
            Shadow(color: Colors.black54, blurRadius: 18),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Helper: Pemain Video Skrin Penuh Gaya TikTok / Reels (Auto-loop & Vertical Fit)
// =============================================================================
class _FeedVideoPlayerItem extends StatefulWidget {
  final String videoUrl;
  final bool isCurrentPage;
  final bool isMuted;
  final VoidCallback onToggleMute;

  const _FeedVideoPlayerItem({
    required this.videoUrl,
    required this.isCurrentPage,
    required this.isMuted,
    required this.onToggleMute,
  });

  @override
  State<_FeedVideoPlayerItem> createState() => _FeedVideoPlayerItemState();
}

class _FeedVideoPlayerItemState extends State<_FeedVideoPlayerItem> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isUserPaused = false;
  bool _showPlayStateIndicator = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          _controller.setLooping(true);
          _controller.setVolume(widget.isMuted ? 0.0 : 1.0);
          if (widget.isCurrentPage && !_isUserPaused) {
            _controller.play();
          }
        }
      }).catchError((e) {
        debugPrint('[FeedVideoPlayer] Error loading video: $e');
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      });
  }

  @override
  void didUpdateWidget(covariant _FeedVideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isInitialized) {
      if (widget.isCurrentPage != oldWidget.isCurrentPage) {
        if (widget.isCurrentPage && !_isUserPaused) {
          _controller.play();
        } else {
          _controller.pause();
        }
      }
      if (widget.isMuted != oldWidget.isMuted) {
        _controller.setVolume(widget.isMuted ? 0.0 : 1.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_isInitialized) return;
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _isUserPaused = true;
      } else {
        _controller.play();
        _isUserPaused = false;
      }
      _showPlayStateIndicator = true;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _showPlayStateIndicator = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: const Color(0xFF11171E),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 42),
              SizedBox(height: 8),
              Text(
                'Gagal memuatkan video',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        color: const Color(0xFF11171E),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF00E5FF),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full Screen Cover Video (TikTok Style Vertical Fit)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _controller.value.size.width > 0
                  ? _controller.value.size.width
                  : 720,
              height: _controller.value.size.height > 0
                  ? _controller.value.size.height
                  : 1280,
              child: VideoPlayer(_controller),
            ),
          ),

          // Temporary Animated Play / Pause Icon Feedback
          if (_showPlayStateIndicator || !_controller.value.isPlaying)
            Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _showPlayStateIndicator || !_controller.value.isPlaying
                    ? 0.85
                    : 0.0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _controller.value.isPlaying
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
