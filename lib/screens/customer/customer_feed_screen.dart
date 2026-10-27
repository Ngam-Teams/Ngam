import 'package:ngam/l10n/generated/app_localizations.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../widgets/glass_toast.dart';
import '../../widgets/customer_desktop_sidebar.dart';
import '../explore/business_store_view.dart';

// ---------------------------------------------------------------------------
// Reusable Feed Avatar with Initial / Abjad Fallback
// ---------------------------------------------------------------------------
Widget _buildFeedAvatar({
  required String name,
  required double size,
  String? imageUrl,
  Color? borderColor,
  double borderWidth = 1.5,
  List<BoxShadow>? boxShadow,
  double? fontSize,
}) {
  final cleanName = name.trim();
  final String initial = cleanName.isNotEmpty ? cleanName[0].toUpperCase() : 'N';
  final String cleanUrl = imageUrl?.trim() ?? '';
  final bool isDefaultOrEmpty = cleanUrl.isEmpty ||
      cleanUrl.contains('photo-1535713875002-d1d0cf377fde') ||
      cleanUrl.contains('default') ||
      cleanUrl.contains('placeholder');

  Widget avatarContent;
  if (!isDefaultOrEmpty) {
    avatarContent = ClipOval(
      child: CachedNetworkImage(
        imageUrl: cleanUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _buildFeedAlphabetCircle(initial, size, fontSize),
        placeholder: (_, __) => _buildFeedAlphabetCircle(initial, size, fontSize),
      ),
    );
  } else {
    avatarContent = _buildFeedAlphabetCircle(initial, size, fontSize);
  }

  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: borderColor != null
          ? Border.all(color: borderColor, width: borderWidth)
          : null,
      boxShadow: boxShadow,
    ),
    child: avatarContent,
  );
}

Widget _buildFeedAlphabetCircle(String initial, double size, [double? fontSize]) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF2A2B3D),
          Color(0xFF161622),
        ],
      ),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.16),
        width: 1.2,
      ),
    ),
    alignment: Alignment.center,
    child: Text(
      initial,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: fontSize ?? (size * 0.44),
        letterSpacing: -0.5,
      ),
    ),
  );
}

// =============================================================================
// CustomerFeedScreen — Ruangan "Ngam Feed" Gaya TikTok / Reels Penuh
// Pengalaman Skrin Penuh (Immersive Snap), Butang Tindakan Kanan,
// Interaksi Double-Tap Like & Butang Pintas Tempahan/Giliran Eksklusif
// =============================================================================

class CustomerFeedScreen extends StatefulWidget {
  final void Function(int index)? onSwitchTab;
  final bool isTabActive;

  const CustomerFeedScreen({
    super.key,
    this.onSwitchTab,
    this.isTabActive = true,
  });

  @override
  State<CustomerFeedScreen> createState() => _CustomerFeedScreenState();
}

class _CustomerFeedScreenState extends State<CustomerFeedScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static int _persistedPageIndex = 0;
  static bool _persistedIsMuted = false;

  late PageController _pageController;
  late AnimationController _discAnimController;

  int _activeTopTab = 1; // 0: 'Berhampiran', 1: 'Untuk Anda'
  int _currentPage = 0;
  bool _isMuted = _persistedIsMuted; // Unmuted by default so videos play with full sound!
  bool _isModalOrRouteOpen = false;
  bool _isVideoPlaying = true;
  Map<String, dynamic>? _desktopCommentsPost; // TikTok/IG desktop right-side comments panel

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
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      'mediaType': 'video',
      'aspectRatio': 16 / 9,
      'title': 'Low Taper Fade + Beard Sculpting',
      'caption':
          'Hasil sentuhan kemas petang ini untuk regular bro Hazim. Slot walk-in dan giliran petang ni masih dibuka sampai jam 10 malam! #barber #taperfade #ngam',
      'serviceTag': 'Potong + Cuci • RM35 · Buka Hingga 10:00 PM',
      'ctaText': 'AMBIL GILIRAN (1 MENUNGGU)',
      'likes': 142,
      'isLiked': false,
      'isSaved': false,
      'isFollowed': false,
      'comments': 19,
      'commentList': [
        {
          'user': 'Hazim Azlan',
          'avatar': '',
          'text': 'Memang kemas bro! Balik rumah bini terus puji haha',
          'time': '20m lepas',
          'likes': 4,
        },
        {
          'user': 'Farhan Barber',
          'avatar': 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?q=80&w=150',
          'text': 'Fade paling licin minggu ni! Mantap Danial!',
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
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4',
      'mediaType': 'video',
      'aspectRatio': 16 / 9,
      'title': 'Cermin Kereta Bersinar Bak Kristal',
      'caption':
          'Pakej Nano Wax Coating + Interior Steam Wash promosi khas pertengahan bulan. Hilangkan watermark dan bau hapak kereta anda sekarang! #detailing #carwash #ngam',
      'serviceTag': 'Nano Coating • RM45 · 3 Bay Cucian Aktif',
      'ctaText': 'MASUK TERUS (0 MENUNGGU)',
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
      'title': 'Iced Salted Caramel Butter Pecan Latte',
      'caption':
          'Port santai untuk buat kerja atau lepak sambil tunggu kereta siap dicuci. Ada high-speed WiFi dan plug di setiap meja santai. #ngamcafe #kopiroti #viral',
      'serviceTag': 'Menu Baru Musim Ini • RM14 · Meja Santai Tersedia',
      'ctaText': 'PESAN QR / TEMPAH MEJA',
      'likes': 234,
      'isLiked': false,
      'isSaved': false,
      'isFollowed': false,
      'comments': 42,
      'commentList': [
        {
          'user': 'Sarah Nadia',
          'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=150',
          'text': 'Butter Pecan dia memang sedap gila, tak manis sangat',
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
      'title': 'Servis Minyak Hitam & Brek Siap Dalam 25 Minit',
      'caption':
          'Servis pantas tanpa perlu tinggal kereta seharian. Percuma pemeriksaan 21 poin keselamatan kenderaan untuk setiap pelanggan Ngam. #bengkel #serviskereta',
      'serviceTag': 'Pakej Servis • Dari RM85 · 2 Bay Sedang Servis',
      'ctaText': 'AMBIL TIKET SERVIS',
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
    WidgetsBinding.instance.addObserver(this);
    _posts = [];
    _isLoading = true;
    _currentPage = _persistedPageIndex;
    _pageController = PageController(initialPage: _persistedPageIndex);
    _discAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _fetchLivePosts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _discAnimController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      if (mounted) setState(() => _isModalOrRouteOpen = true);
    } else {
      if (mounted) setState(() => _isModalOrRouteOpen = false);
    }
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
              business_cover_url,
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
              : '';

          final locParts = [biz['business_city'], biz['state']]
              .where((s) => s != null && s.toString().trim().isNotEmpty)
              .map((s) => s.toString().trim())
              .toList();
          final location =
              locParts.isNotEmpty ? locParts.join(', ') : 'Malaysia';

          // Format masa
          final rawDate = row['created_at']?.toString() ?? '';
          DateTime createdAt;
          if (!rawDate.endsWith('Z') && !rawDate.contains('+') && rawDate.contains('T')) {
            createdAt = DateTime.tryParse('${rawDate}Z')?.toLocal() ?? DateTime.now();
          } else if (!rawDate.endsWith('Z') && !rawDate.contains('+') && !rawDate.contains('T')) {
            createdAt = DateTime.tryParse('${rawDate.replaceAll(' ', 'T')}Z')?.toLocal() ?? DateTime.now();
          } else {
            createdAt = DateTime.tryParse(rawDate)?.toLocal() ?? DateTime.now();
          }
          final diff = DateTime.now().difference(createdAt);
          String timeAgo;
          if (diff.isNegative || diff.inSeconds < 60) {
            timeAgo = 'Baru saja';
          } else if (diff.inMinutes < 60) {
            final m = diff.inMinutes;
            timeAgo = '$m min lepas';
          } else if (diff.inHours < 24) {
            timeAgo = '${diff.inHours} jam lepas';
          } else if (diff.inDays < 7) {
            timeAgo = '${diff.inDays} hari lepas';
          } else {
            timeAgo = '${createdAt.day}/${createdAt.month}/${createdAt.year}';
          }

          String mediaUrl = row['media_url']?.toString() ?? '';
          if (mediaUrl.contains('mixkit.co')) {
            mediaUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
          }
          final cleanMedia = mediaUrl.trim().toLowerCase();
          final isVideo = (row['media_type']?.toString().toLowerCase() == 'video') ||
              cleanMedia.endsWith('.mp4') ||
              cleanMedia.endsWith('.mov') ||
              cleanMedia.endsWith('.webm') ||
              cleanMedia.contains('/video/') ||
              cleanMedia.contains('.mp4?');
          final ctaType = row['cta_type']?.toString() ?? 'queue';
          final ctaText = row['cta_text']?.toString() ?? 'AMBIL GILIRAN';
          final serviceTag =
              row['service_tag']?.toString() ?? 'Servis Pantas Ngam';

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
            'mediaType': isVideo ? 'video' : (row['media_type'] ?? 'image'),
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
              'business_logo_url': shopAvatar,
              'cover': (biz['business_cover_url'] as String?)?.trim() ?? '',
              'business_cover_url': (biz['business_cover_url'] as String?)?.trim() ?? '',
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
            if (_currentPage >= loaded.length) {
              _currentPage = 0;
            }
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
    _persistedPageIndex = index;
    setState(() {
      _currentPage = index;
      _isVideoPlaying = true;
      if (_desktopCommentsPost != null && index >= 0 && index < _posts.length) {
        _desktopCommentsPost = _posts[index];
      }
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
      _persistedIsMuted = _isMuted;
    });
    showGlassToast(
      context,
      _isMuted ? 'Audio Dimatikan' : 'Audio Dihidupkan',
      icon: _isMuted
          ? HugeIcons.strokeRoundedVolumeOff
          : HugeIcons.strokeRoundedVolumeHigh,
    );
  }

  void _handleCtaAction(Map<String, dynamic> post) {
    final ctaType = post['ctaType']?.toString() ?? 'queue';
    if (ctaType == 'queue') {
      _openStore(post);
      showGlassToast(
        context,
        'Membuka giliran untuk ${post['shopName']}',
        icon: HugeIcons.strokeRoundedFlash,
      );
    } else if (ctaType == 'booking') {
      _openStore(post);
      showGlassToast(
        context,
        'Membuka tempahan untuk ${post['shopName']}',
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
          ? 'Mengikuti ${post['shopName']}'
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
          ? 'Disimpan ke koleksi simpanan anda'
          : 'Dikeluarkan dari simpanan',
      icon: HugeIcons.strokeRoundedBookmark02,
    );
  }

  void _sharePost(Map<String, dynamic> post) {
    showGlassToast(
      context,
      'Pautan ${post['shopName']} disalin ke papan klip!',
      icon: HugeIcons.strokeRoundedShare01,
    );
  }

  Future<void> _openStore(Map<String, dynamic> post) async {
    setState(() => _isModalOrRouteOpen = true);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessStoreView(shop: post['shopData'] ?? {}),
      ),
    );
    if (mounted) {
      setState(() => _isModalOrRouteOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double safeBottom = MediaQuery.paddingOf(context).bottom;
    final double safeTop = MediaQuery.paddingOf(context).top;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isDesktopLandscape = screenWidth > 700;
    final themeProvider = context.watch<ThemeProvider?>();
    final bool isDark = themeProvider?.isDarkMode ?? (Theme.of(context).brightness == Brightness.dark);
    final Color scaffoldBg = isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC);
    
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
      child: ValueListenableBuilder<bool>(
        valueListenable: CustomerDesktopSidebar.isExpandedNotifier,
        builder: (context, isSidebarExpanded, _) {
          final double sidebarOccupiedWidth = isDesktopLandscape
              ? (16.0 + (isSidebarExpanded ? 260.0 : 72.0))
              : 0.0;
          final double leftContentOffset = sidebarOccupiedWidth;
          final double commentsPanelWidth = (screenWidth * 0.32).clamp(380.0, 460.0);
          final double rightContentOffset = (isDesktopLandscape && _desktopCommentsPost != null)
              ? commentsPanelWidth
              : 0.0;

          return Scaffold(
        backgroundColor: scaffoldBg,
        body: Stack(
        children: [
          // 0. Continuous Unified Ambient Mesh/Radial Gradient for Desktop
          if (isDesktopLandscape)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.35,
                    colors: isDark
                        ? [
                            const Color(0xFF1E293B), // Deep slate blue glow in center
                            const Color(0xFF0F172A), // Dark slate
                            const Color(0xFF0B0F17), // Edge
                          ]
                        : [
                            const Color(0xFFE2E8F0), // Soft slate center
                            const Color(0xFFF1F5F9), // Light studio slate
                            const Color(0xFFF8FAFC), // Crisp light white
                          ],
                  ),
                ),
              ),
            ),

          // 1. VERTICAL FULL SCREEN PAGEVIEW (TIKTOK STYLE)
          RefreshIndicator(
            color: const Color(0xFF00E5FF),
            backgroundColor: isDark ? const Color(0xFF141920) : Colors.white,
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
                                Text(
                                  'Memuatkan suapan Ngam...',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ] else ...[
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedVideo01,
                                  size: 48,
                                  color: isDark ? Colors.white24 : Colors.black26,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Tiada pos suapan ditemui.',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: _fetchLivePosts,
                                  icon: const HugeIcon(
                                      icon: HugeIcons.strokeRoundedRefresh,
                                      color: Color(0xFF00E5FF),
                                      size: 18),
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
                    physics: const PageScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    onPageChanged: _onPageChanged,
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      return _buildFeedItem(
                        post,
                        bottomOffset,
                        index,
                        leftContentOffset: leftContentOffset,
                        rightContentOffset: rightContentOffset,
                      );
                    },
                  ),
          ),

          // 2. DOUBLE-TAP POPPING HEARTS OVERLAY
          ..._hearts,

          // 3. TOP NAVIGATION OVERLAY (Header + FYP & Nearby Tabs)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            top: safeTop > 0 ? safeTop + 6 : 14,
            left: isDesktopLandscape ? leftContentOffset : 0,
            right: isDesktopLandscape ? rightContentOffset : 0,
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
                            'Memuat semula suapan Ngam...',
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
                            Text(
                              'FEED',
                              style: TextStyle(
                                color: (isDesktopLandscape && !isDark)
                                    ? const Color(0xFF0F172A)
                                    : Colors.white,
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
                          color: (isDesktopLandscape && !isDark)
                              ? Colors.black.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: (isDesktopLandscape && !isDark)
                              ? Border.all(color: Colors.black12, width: 0.8)
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _activeTopTab = 0;
                                  _desktopCommentsPost = null;
                                });
                                showGlassToast(
                                  context,
                                  'Menapis pos dalam radius 10KM',
                                  icon: HugeIcons.strokeRoundedLocation01,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                child: Text(
                                  AppLocalizations.of(context)?.nearby ?? 'Berhampiran',
                                  style: TextStyle(
                                    color: (isDesktopLandscape && !isDark)
                                        ? (_activeTopTab == 0
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFF64748B))
                                        : (_activeTopTab == 0
                                            ? Colors.white
                                            : Colors.white54),
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
                              decoration: BoxDecoration(
                                color: (isDesktopLandscape && !isDark)
                                    ? Colors.black26
                                    : Colors.white30,
                                shape: BoxShape.circle,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _activeTopTab = 1;
                                  _desktopCommentsPost = null;
                                });
                                showGlassToast(
                                  context,
                                  'Memaparkan pos paling trending',
                                  icon: HugeIcons.strokeRoundedFire,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                child: Text(
                                  AppLocalizations.of(context)?.feedForYou ?? 'Untuk Anda',
                                  style: TextStyle(
                                    color: (isDesktopLandscape && !isDark)
                                        ? (_activeTopTab == 1
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFF64748B))
                                        : (_activeTopTab == 1
                                            ? Colors.white
                                            : Colors.white54),
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
                            color: (isDesktopLandscape && !isDark)
                                ? Colors.black.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (isDesktopLandscape && !isDark)
                                  ? Colors.black12
                                  : Colors.white12,
                            ),
                          ),
                          child: Center(
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedSearch01,
                              color: (isDesktopLandscape && !isDark)
                                  ? const Color(0xFF0F172A)
                                  : Colors.white,
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
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              right: rightContentOffset + 24,
              top: 0,
              bottom: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDesktopNavArrow(
                      icon: HugeIcons.strokeRoundedArrowUp01,
                      tooltip: 'Pos Sebelumnya (↑)',
                      enabled: _currentPage > 0,
                      isDark: isDark,
                      onTap: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildDesktopNavArrow(
                      icon: HugeIcons.strokeRoundedArrowDown01,
                      tooltip: 'Pos Seterusnya (↓)',
                      enabled: _currentPage < _posts.length - 1,
                      isDark: isDark,
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

          // 5. DESKTOP RIGHT-SIDE SLIDING COMMENTS PANEL (TIKTOK & INSTAGRAM REELS STYLE)
          if (isDesktopLandscape)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              top: 0,
              bottom: 0,
              right: _desktopCommentsPost != null
                  ? 0
                  : -((screenWidth * 0.32).clamp(380.0, 460.0) + 30),
              width: (screenWidth * 0.32).clamp(380.0, 460.0),
              child: _desktopCommentsPost != null
                  ? Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF10141B) : Colors.white,
                        border: Border(
                          left: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.08),
                            width: 1.2,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.5)
                                : Colors.black.withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(-8, 0),
                          ),
                        ],
                      ),
                      child: _FeedCommentsView(
                        key: ValueKey('desktop_comments_${_desktopCommentsPost!['id']}'),
                        post: _desktopCommentsPost!,
                        isDesktop: true,
                        onClose: () => setState(() => _desktopCommentsPost = null),
                        onCommentCountChanged: (count) {
                          if (mounted) {
                            setState(() {
                              _desktopCommentsPost!['comments'] = count;
                            });
                          }
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
              ),
            );
          },
        ),
      );
    }

  // --- SINGLE FEED POST ITEM (RESPONSIVE TIKTOK DESKTOP / MOBILE ADAPTIVE) ---
  Widget _buildFeedItem(
    Map<String, dynamic> post,
    double bottomOffset,
    int index, {
    double leftContentOffset = 0.0,
    double rightContentOffset = 0.0,
  }) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final bool isDesktopLandscape = screenWidth > 700;
    final bool isShortPhone = screenHeight < 720;
    final themeProvider = context.watch<ThemeProvider?>();
    final bool isDark = themeProvider?.isDarkMode ?? (Theme.of(context).brightness == Brightness.dark);

    final String rawMedia = post['image']?.toString() ?? '';
    final String cleanRawMedia = rawMedia.trim().toLowerCase();
    final bool isVideoMedia = (post['mediaType'] == 'video' ||
        cleanRawMedia.endsWith('.mp4') ||
        cleanRawMedia.endsWith('.mov') ||
        cleanRawMedia.endsWith('.webm') ||
        cleanRawMedia.contains('/video/') ||
        cleanRawMedia.contains('.mp4?')) && rawMedia.isNotEmpty;

    if (isDesktopLandscape) {
      // -------------------------------------------------------------
      // TIKTOK DESKTOP / LANDSCAPE MODE
      // Full viewport height below top navigation header (TikTok Desktop standard)
      // Minimizes gap between stacked/scrolled video cards to ~68px
      // -------------------------------------------------------------
      final double topNavOffset = 58.0;
      final double cardBottomOffset = 10.0;
      final double availableHeight = (screenHeight - topNavOffset - cardBottomOffset).clamp(320.0, 1400.0);
      final double openWidth = (screenWidth - leftContentOffset - rightContentOffset).clamp(320.0, 2400.0);

      // Orientation & aspect ratio detection
      final double postAspect = (post['aspectRatio'] as num?)?.toDouble() ?? (9 / 16);
      final bool isLandscapePost = postAspect > 1.05;

      final double maxCardWidth = (openWidth - 84.0).clamp(280.0, 1300.0);
      final double maxCardHeight = availableHeight.clamp(480.0, 1150.0);

      double cardWidth;
      double cardHeight;

      if (isLandscapePost) {
        // Landscape video: expand gracefully horizontally to make full use of widescreen!
        final double targetAspect = postAspect > 0.1 ? postAspect : (16 / 9);
        double calcWidth = maxCardHeight * targetAspect;
        double calcHeight = maxCardHeight;

        if (calcWidth > maxCardWidth) {
          calcWidth = maxCardWidth;
          calcHeight = calcWidth / targetAspect;
        }

        // Clamp to sensible aesthetic proportions
        cardWidth = calcWidth.clamp(480.0, maxCardWidth);
        cardHeight = calcHeight.clamp(300.0, maxCardHeight);
      } else {
        // Portrait 9:16 standard feed item
        cardHeight = maxCardHeight;
        cardWidth = (cardHeight * (9 / 16)).clamp(280.0, (openWidth - 84.0) * 0.75);
      }

      final String backdropImageUrl = isVideoMedia
          ? (post['shopAvatar']?.toString() ?? '')
          : (rawMedia.isNotEmpty ? rawMedia : (post['shopAvatar']?.toString() ?? ''));

      return Stack(
        fit: StackFit.expand,
        children: [
          // 1. Cinematic Ambient Blurred Glow from Store Avatar/Photo (Tap outside to close comments panel)
          if (backdropImageUrl.isNotEmpty)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _desktopCommentsPost != null
                    ? () => setState(() => _desktopCommentsPost = null)
                    : null,
                child: Opacity(
                  opacity: isDark ? 0.38 : 0.22,
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 65, sigmaY: 65),
                    child: CachedNetworkImage(
                      imageUrl: backdropImageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),

          // 2. Centered Video Card + Action Bar Right Beside It
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            top: topNavOffset,
            bottom: cardBottomOffset,
            left: leftContentOffset,
            right: rightContentOffset,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Centered Video Canvas with Animated Resize
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      width: cardWidth,
                      height: cardHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0F15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.7)
                                : Colors.black.withValues(alpha: 0.12),
                            blurRadius: isDark ? 36 : 24,
                            spreadRadius: isDark ? 8 : 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: GestureDetector(
                        onDoubleTapDown: (post['mediaType'] == 'video')
                            ? null
                            : (details) {
                                _handleDoubleTap(details.globalPosition, post);
                              },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildMediaContent(post, index, bottomOffset: 16, isDesktop: true),

                            // Top shadow gradient
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 100,
                              child: IgnorePointer(
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
                            ),

                            // Bottom shadow gradient
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: 280,
                              child: IgnorePointer(
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
        // 1. FULL SCREEN MEDIA / IMAGE (Interactive Double Tap for photo, handled by video player for video)
        GestureDetector(
          onDoubleTapDown: isVideoMedia
              ? null
              : (details) {
                  _handleDoubleTap(details.globalPosition, post);
                },
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildMediaContent(post, index, bottomOffset: bottomOffset, isDesktop: false),

              // Top dark shadow gradient
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 140,
                child: IgnorePointer(
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
              ),

              // Bottom heavy shadow gradient
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 380,
                child: IgnorePointer(
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
  Widget _buildMediaContent(
    Map<String, dynamic> post,
    int index, {
    required double bottomOffset,
    bool isDesktop = false,
  }) {
    final String mediaUrl = post['image']?.toString() ?? '';
    final String cleanMedia = mediaUrl.trim().toLowerCase();
    final bool isVideo = (post['mediaType'] == 'video' ||
        cleanMedia.endsWith('.mp4') ||
        cleanMedia.endsWith('.mov') ||
        cleanMedia.endsWith('.webm') ||
        cleanMedia.contains('/video/') ||
        cleanMedia.contains('.mp4?')) && mediaUrl.isNotEmpty;

    if (isVideo) {
      return _FeedVideoPlayerItem(
        key: ValueKey('feed_vid_${post['id']}_$mediaUrl'),
        videoUrl: post['image'],
        isCurrentPage: index == _currentPage,
        isPausedExternally: !widget.isTabActive || _isModalOrRouteOpen,
        isMuted: _isMuted,
        bottomOffset: bottomOffset,
        isDesktop: isDesktop,
        onToggleMute: _toggleMute,
        onDoubleTap: (pos) => _handleDoubleTap(pos, post),
        onAspectRatioDetermined: (aspect) {
          if (post['aspectRatio'] != aspect) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  post['aspectRatio'] = aspect;
                });
              }
            });
          }
        },
        onPlayStateChanged: (playing) {
          if (mounted && index == _currentPage && _isVideoPlaying != playing) {
            setState(() => _isVideoPlaying = playing);
          }
        },
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
          child: HugeIcon(icon: HugeIcons.strokeRoundedImage01, color: Colors.white38, size: 28),
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
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedFlash,
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
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
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
              const HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkBadge01,
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
      ],
    );
  }

  // --- FLOATING ACTION BAR (AVATAR, LIKE, COMMENT, SAVE, SHARE, MUTE, VINYL) ---
  Widget _buildActionBar(
    Map<String, dynamic> post, {
    required bool isShortPhone,
    required bool isDesktop,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isLiked = post['isLiked'] ?? false;
    final bool isSaved = post['isSaved'] ?? false;
    final bool isFollowed = post['isFollowed'] ?? false;
    final int likes = post['likes'] ?? 0;
    final int comments = post['comments'] ?? 0;
    final double actionSpacing = isShortPhone ? 10 : (isDesktop ? 16 : 14);
    final bool isCommentsActive = isDesktop &&
        _desktopCommentsPost != null &&
        _desktopCommentsPost!['id'] == post['id'];

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
              _buildFeedAvatar(
                name: post['shopName']?.toString() ?? post['shopHandle']?.toString() ?? 'Ngam',
                size: isShortPhone ? 42 : 48,
                imageUrl: post['shopAvatar']?.toString(),
                borderColor: Colors.white.withValues(alpha: 0.35),
                borderWidth: 1.8,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 10,
                  ),
                ],
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
                          : const Color(0xFF2196F3),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isFollowed
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF2196F3))
                              .withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: HugeIcon(
                      icon: isFollowed ? HugeIcons.strokeRoundedTick01 : HugeIcons.strokeRoundedAdd01,
                      size: isShortPhone ? 12 : 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: isShortPhone ? 12 : (isDesktop ? 18 : 16)),

        // Like (Hati) Action (TikTok Style: Solid #FE2C55 heart with bounce when liked)
        _buildRightActionButton(
          hugeIcon: isLiked ? Icons.favorite : HugeIcons.strokeRoundedFavourite,
          iconColor: isLiked ? const Color(0xFFFE2C55) : Colors.white,
          label: '$likes',
          isCompact: isShortPhone,
          isDesktop: isDesktop,
          isDark: isDark,
          isLikedBounce: isLiked,
          onTap: () => _toggleLike(post),
        ),

        SizedBox(height: actionSpacing),

        // Comment Action (TikTok & IG Style: Right docked panel on desktop, bottom sheet on mobile)
        _buildRightActionButton(
          hugeIcon: HugeIcons.strokeRoundedComment01,
          iconColor: isCommentsActive ? const Color(0xFF00E5FF) : Colors.white,
          label: '$comments',
          isCompact: isShortPhone,
          isDesktop: isDesktop,
          isDark: isDark,
          onTap: () => _toggleComments(post),
        ),

        SizedBox(height: actionSpacing),

        // Save / Bookmark Action
        _buildRightActionButton(
          hugeIcon: isSaved ? Icons.bookmark_rounded : HugeIcons.strokeRoundedBookmark02,
          iconColor: isSaved ? const Color(0xFFFBBF24) : Colors.white,
          label: 'Simpan',
          isCompact: isShortPhone,
          isDesktop: isDesktop,
          isDark: isDark,
          onTap: () => _toggleSave(post),
        ),

        SizedBox(height: actionSpacing),

        // Share Action
        _buildRightActionButton(
          hugeIcon: HugeIcons.strokeRoundedShare01,
          label: 'Kongsi',
          isCompact: isShortPhone,
          isDesktop: isDesktop,
          isDark: isDark,
          onTap: () => _sharePost(post),
        ),

        SizedBox(height: actionSpacing),

        // Audio Mute/Unmute Action for Video
        if (post['mediaType'] == 'video' || (post['image']?.toString() ?? '').toLowerCase().contains('.mp4')) ...[
          _buildRightActionButton(
            hugeIcon: _isMuted
                ? HugeIcons.strokeRoundedVolumeOff
                : HugeIcons.strokeRoundedVolumeHigh,
            iconColor: _isMuted ? Colors.white54 : const Color(0xFF00E5FF),
            label: _isMuted ? 'Bisu' : 'Audio',
            isCompact: isShortPhone,
            isDesktop: isDesktop,
            isDark: isDark,
            onTap: _toggleMute,
          ),
        ],
      ],
    );
  }

  // --- DESKTOP NAVIGATION ARROW BUTTON ---
  Widget _buildDesktopNavArrow({
    required List<List<dynamic>> icon,
    required String tooltip,
    required bool enabled,
    required bool isDark,
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
              color: isDark
                  ? (enabled
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.04))
                  : (enabled
                      ? Colors.black.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.02)),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? (enabled ? Colors.white24 : Colors.white10)
                    : (enabled ? Colors.black12 : Colors.black.withValues(alpha: 0.04)),
                width: 1.2,
              ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: HugeIcon(
                icon: icon,
                color: isDark
                    ? (enabled ? Colors.white : Colors.white24)
                    : (enabled ? const Color(0xFF0F172A) : Colors.black26),
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- RIGHT FLOATING ACTION BUTTON BUILDER ---
  Widget _buildRightActionButton({
    dynamic hugeIcon,
    Color iconColor = Colors.white,
    required String label,
    bool isCompact = false,
    bool isDesktop = false,
    bool isDark = true,
    bool isLikedBounce = false,
    required VoidCallback onTap,
  }) {
    final double buttonSize = isCompact ? 38 : 44;
    final bool useLightDesktop = isDesktop && !isDark;
    final Color effectiveIconColor = (useLightDesktop && iconColor == Colors.white)
        ? const Color(0xFF1E293B)
        : iconColor;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: isLikedBounce ? 0.75 : 1.0, end: 1.0),
            duration: const Duration(milliseconds: 280),
            curve: Curves.elasticOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    color: useLightDesktop
                        ? Colors.white
                        : Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: useLightDesktop
                          ? Colors.black.withValues(alpha: 0.08)
                          : Colors.white12,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: useLightDesktop
                            ? Colors.black.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: hugeIcon is IconData
                        ? Icon(hugeIcon, color: effectiveIconColor, size: isCompact ? 22 : 26)
                        : HugeIcon(icon: hugeIcon, color: effectiveIconColor, size: isCompact ? 19 : 22),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: useLightDesktop ? const Color(0xFF334155) : Colors.white,
              fontSize: isCompact ? 10 : 11,
              fontWeight: FontWeight.w700,
              shadows: useLightDesktop
                  ? null
                  : const [
                      Shadow(color: Colors.black, blurRadius: 6),
                    ],
            ),
          ),
        ],
      ),
    );
  }

  // --- COMMENTS MANAGEMENT (TIKTOK & INSTAGRAM REELS DOCKED RIGHT PANEL ON DESKTOP / BOTTOM SHEET ON MOBILE) ---
  void _toggleComments(Map<String, dynamic> post) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isDesktop = screenWidth > 700;
    if (isDesktop) {
      setState(() {
        if (_desktopCommentsPost != null && _desktopCommentsPost!['id'] == post['id']) {
          _desktopCommentsPost = null; // Tutup panel jika klik pos yang sama
        } else {
          _desktopCommentsPost = post; // Buka panel di sebelah kanan ikut TikTok/IG Reels
        }
      });
    } else {
      _showCommentsBottomSheet(context, post);
    }
  }

  Future<void> _showCommentsBottomSheet(BuildContext context, Map<String, dynamic> post) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF10141B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: _FeedCommentsView(
            post: post,
            isDesktop: false,
            onClose: () => Navigator.pop(ctx),
            onCommentCountChanged: (count) {
              if (mounted) {
                setState(() => post['comments'] = count);
              }
            },
          ),
        );
      },
    );
  }
}

// =============================================================================
// REUSABLE FEED COMMENTS VIEW (TIKTOK & INSTAGRAM REELS ADAPTIVE)
// Used in right side sliding panel on Desktop, and bottom sheet on Mobile.
// =============================================================================
class _FeedCommentsView extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isDesktop;
  final VoidCallback onClose;
  final void Function(int newCount)? onCommentCountChanged;

  const _FeedCommentsView({
    super.key,
    required this.post,
    required this.isDesktop,
    required this.onClose,
    this.onCommentCountChanged,
  });

  @override
  State<_FeedCommentsView> createState() => _FeedCommentsViewState();
}

class _FeedCommentsViewState extends State<_FeedCommentsView> {
  late TextEditingController _commentController;
  final List<Map<String, dynamic>> _comments = [];
  bool _isLoading = false;
  String? _loadedPostId;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _initAndFetchComments();
  }

  @override
  void didUpdateWidget(covariant _FeedCommentsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post['id'] != oldWidget.post['id']) {
      _initAndFetchComments();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _initAndFetchComments() {
    final String postId = widget.post['id']?.toString() ?? '';
    _loadedPostId = postId;
    _comments.clear();
    final rawList = widget.post['commentList'] as List?;
    if (rawList != null && rawList.isNotEmpty) {
      _comments.addAll(rawList.map((e) => Map<String, dynamic>.from(e as Map)));
    }

    if (postId.length > 20 && _comments.isEmpty) {
      _fetchLiveComments(postId);
    }
  }

  Future<void> _fetchLiveComments(String postId) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final dbRes = await Supabase.instance.client
          .from('feed_comments')
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: false)
          .limit(60);

      if (!mounted || _loadedPostId != postId) return;

      if (dbRes.isNotEmpty) {
        final List<Map<String, dynamic>> loadedDb = [];
        for (final row in dbRes) {
          final rawDate = row['created_at']?.toString() ?? '';
          DateTime dt;
          if (!rawDate.endsWith('Z') && !rawDate.contains('+') && rawDate.contains('T')) {
            dt = DateTime.tryParse('${rawDate}Z')?.toLocal() ?? DateTime.now();
          } else {
            dt = DateTime.tryParse(rawDate)?.toLocal() ?? DateTime.now();
          }
          final diff = DateTime.now().difference(dt);
          String timeAgo;
          if (diff.inSeconds < 60) {
            timeAgo = 'Baru saja';
          } else if (diff.inMinutes < 60) {
            timeAgo = '${diff.inMinutes}m lepas';
          } else if (diff.inHours < 24) {
            timeAgo = '${diff.inHours}j lepas';
          } else {
            timeAgo = '${dt.day}/${dt.month}';
          }

          loadedDb.add({
            'id': row['id']?.toString(),
            'user': row['user_name'] ?? 'Pelanggan Ngam',
            'avatar': row['user_avatar']?.toString() ?? '',
            'text': row['comment_text'] ?? '',
            'time': timeAgo,
            'likes': (row['likes_count'] as num?)?.toInt() ?? 0,
            'isLiked': false,
          });
        }
        setState(() {
          _comments.clear();
          _comments.addAll(loadedDb);
          _isLoading = false;
        });
        widget.post['commentList'] = _comments;
        widget.post['comments'] = _comments.length;
        widget.onCommentCountChanged?.call(_comments.length);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[FeedCommentsView] Fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleSendComment() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      if (mounted) {
        showGlassToast(
          context,
          'Sila log masuk untuk menulis komen',
          icon: HugeIcons.strokeRoundedLock,
        );
        Navigator.pushNamed(context, '/login');
      }
      return;
    }

    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    final userName = (currentUser.userMetadata?['full_name'] as String?) ??
        (currentUser.userMetadata?['name'] as String?) ??
        (currentUser.email?.split('@').first) ??
        'Pelanggan Ngam';
    final userAvatar = (currentUser.userMetadata?['avatar_url'] as String?) ?? '';

    final newEntry = {
      'user': userName,
      'avatar': userAvatar,
      'text': text,
      'time': 'Baru saja',
      'likes': 0,
      'isLiked': false,
    };

    setState(() {
      _comments.insert(0, newEntry);
    });
    widget.post['commentList'] = _comments;
    widget.post['comments'] = _comments.length;
    widget.onCommentCountChanged?.call(_comments.length);

    _commentController.clear();

    final String postId = widget.post['id']?.toString() ?? '';
    if (postId.length > 20) {
      try {
        await Supabase.instance.client.from('feed_comments').insert({
          'post_id': postId,
          'user_id': currentUser?.id,
          'user_name': userName,
          'user_avatar': userAvatar,
          'comment_text': text,
        });
      } catch (err) {
        debugPrint('[FeedCommentsView] DB insert note: $err');
      }
    }

    if (mounted) {
      showGlassToast(
        context,
        'Komen berjaya dihantar!',
        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final shopName = widget.post['shopName']?.toString() ?? 'Ngam Feed';
    final shopHandle = widget.post['shopHandle']?.toString() ?? '';
    final shopAvatar = widget.post['shopAvatar']?.toString() ?? '';
    final caption = widget.post['caption']?.toString() ?? widget.post['title']?.toString() ?? '';

    return Column(
      children: [
        // 1. Mobile Drag Handle (Only on bottom sheet)
        if (!widget.isDesktop)
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

        // 2. Creator Info Snippet (Desktop signature header - TikTok/IG style)
        if (widget.isDesktop)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              children: [
                _buildFeedAvatar(
                  name: shopName,
                  size: 40,
                  imageUrl: shopAvatar,
                  borderColor: Colors.white.withValues(alpha: 0.22),
                  borderWidth: 1.5,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              shopName,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF00E5FF)),
                        ],
                      ),
                      if (shopHandle.isNotEmpty)
                        Text(
                          shopHandle,
                          style: TextStyle(
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Close button
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCancel01,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Post Caption Preview (if on desktop)
        if (widget.isDesktop && caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                caption,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ),
          ),

        // Divider
        Divider(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
          height: 1,
        ),

        // 3. Comments Title Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Komen',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_comments.length}',
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (!widget.isDesktop)
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),

        Divider(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
          height: 1,
        ),

        // 4. Comments List
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00E5FF),
                  ),
                )
              : _comments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.04),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedComment01,
                                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Belum ada komen lagi.',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Jadilah yang pertama berkongsi pandangan!',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: _comments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (_, idx) {
                        final c = _comments[idx];
                        final bool isCommentLiked = c['isLiked'] == true;
                        final int commentLikes = (c['likes'] as num?)?.toInt() ?? 0;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFeedAvatar(
                              name: c['user']?.toString() ?? 'Pelanggan',
                              size: 34,
                              imageUrl: c['avatar']?.toString(),
                              borderColor: Colors.white12,
                              borderWidth: 1.0,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        c['user']?.toString() ?? 'Pelanggan',
                                        style: TextStyle(
                                          color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        c['time']?.toString() ?? '',
                                        style: TextStyle(
                                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    c['text']?.toString() ?? '',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  c['isLiked'] = !isCommentLiked;
                                  c['likes'] = commentLikes + (isCommentLiked ? -1 : 1);
                                });
                              },
                              child: Column(
                                children: [
                                  Icon(
                                    isCommentLiked ? Icons.favorite : Icons.favorite_border_rounded,
                                    size: 16,
                                    color: isCommentLiked
                                        ? const Color(0xFFFE2C55)
                                        : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${c['likes'] ?? 0}',
                                    style: TextStyle(
                                      color: isCommentLiked
                                          ? const Color(0xFFFE2C55)
                                          : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
        ),

        // 5. Sticky Bottom Input Field
        Container(
          padding: EdgeInsets.fromLTRB(
            14,
            10,
            14,
            widget.isDesktop ? 16 : (MediaQuery.of(context).viewInsets.bottom + 12),
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1318) : const Color(0xFFF8FAFC),
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _commentController,
                    onSubmitted: (_) => _handleSendComment(),
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tulis komen anda...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _handleSendComment,
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
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowUp01,
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
        child: Icon(
          Icons.favorite,
          color: const Color(0xFFFE2C55),
          size: 96,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Helper: Pemain Video Skrin Penuh Gaya TikTok / Reels
// Autoplay, Pause on tap, Timeline Dragging, Hold 2x Speed & Landscape Support
// =============================================================================
class _FeedVideoPlayerItem extends StatefulWidget {
  final String videoUrl;
  final bool isCurrentPage;
  final bool isPausedExternally;
  final bool isMuted;
  final double bottomOffset;
  final bool isDesktop;
  final VoidCallback onToggleMute;
  final void Function(Offset position)? onDoubleTap;
  final void Function(double aspectRatio)? onAspectRatioDetermined;
  final void Function(bool isPlaying)? onPlayStateChanged;

  const _FeedVideoPlayerItem({
    super.key,
    required this.videoUrl,
    required this.isCurrentPage,
    required this.isPausedExternally,
    required this.isMuted,
    required this.bottomOffset,
    required this.isDesktop,
    required this.onToggleMute,
    this.onDoubleTap,
    this.onAspectRatioDetermined,
    this.onPlayStateChanged,
  });

  @override
  State<_FeedVideoPlayerItem> createState() => _FeedVideoPlayerItemState();
}

class _FeedVideoPlayerItemState extends State<_FeedVideoPlayerItem> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  int _retryCount = 0;
  bool _isUserPaused = false;
  bool _is2xSpeed = false;
  bool _isScrubbing = false;
  double _scrubRatio = 0.0;
  bool _showPlayIndicator = false;
  Timer? _playIndicatorTimer;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    final String cleanUrl = widget.videoUrl.trim();
    if (cleanUrl.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(cleanUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    _controller.initialize().then((_) {
      if (!mounted) return;
      final double aspect = _controller.value.aspectRatio;
      if (aspect > 0) {
        widget.onAspectRatioDetermined?.call(aspect);
      }
      setState(() {
        _isInitialized = true;
        _hasError = false;
      });
      _controller.addListener(_videoListener);
      _controller.setLooping(true);

      // Initial volume: 0.0 if muted, otherwise 1.0 (unmuted)
      final double initialVolume = widget.isMuted ? 0.0 : 1.0;
      _controller.setVolume(initialVolume).catchError((_) {});

      if (widget.isCurrentPage && !widget.isPausedExternally && !_isUserPaused) {
        _controller.play().then((_) {
          if (mounted) {
            widget.onPlayStateChanged?.call(true);
          }
        }).catchError((playErr) {
          debugPrint('[FeedVideoPlayer] Unmuted autoplay blocked by browser policy, falling back to muted: $playErr');
          _controller.setVolume(0.0).then((_) {
            return _controller.play().then((_) {
              if (mounted) widget.onPlayStateChanged?.call(true);
            });
          }).catchError((_) {});
        });
      } else {
        _controller.pause();
        widget.onPlayStateChanged?.call(false);
      }
    }).catchError((e) {
      debugPrint('[FeedVideoPlayer] Error loading video: $e (attempt $_retryCount)');
      if (_retryCount < 2 && mounted) {
        _retryCount++;
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _initializeController();
        });
        return;
      }
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    });
  }

  void _videoListener() {
    if (mounted && !_isScrubbing) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant _FeedVideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videoUrl != oldWidget.videoUrl) {
      _controller.removeListener(_videoListener);
      _controller.pause();
      _controller.dispose();
      _isInitialized = false;
      _hasError = false;
      _retryCount = 0;
      _initializeController();
      return;
    }

    if (oldWidget.isCurrentPage != widget.isCurrentPage && !widget.isCurrentPage) {
      _playIndicatorTimer?.cancel();
      _showPlayIndicator = false;
    }
    if (_isInitialized) {
      final shouldPlay = widget.isCurrentPage && !widget.isPausedExternally && !_isUserPaused;

      if (!shouldPlay) {
        if (_controller.value.isPlaying) {
          _controller.pause();
          widget.onPlayStateChanged?.call(false);
        }
      } else {
        if (!_controller.value.isPlaying) {
          if (!widget.isMuted && _controller.value.volume == 0.0) {
            _controller.setVolume(1.0).catchError((_) {});
          }
          _controller.play().catchError((playErr) {
            _controller.setVolume(0.0).then((_) => _controller.play()).catchError((_) {});
          });
          widget.onPlayStateChanged?.call(true);
        }
      }

      if (widget.isMuted != oldWidget.isMuted) {
        _controller.setVolume(widget.isMuted ? 0.0 : 1.0).catchError((_) {});
      }
    }
  }

  @override
  void dispose() {
    _playIndicatorTimer?.cancel();
    _controller.removeListener(_videoListener);
    _controller.pause();
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() async {
    if (!_isInitialized) return;
    HapticFeedback.lightImpact();
    try {
      if (_controller.value.isPlaying) {
        await _controller.pause();
        if (mounted) {
          setState(() {
            _isUserPaused = true;
            _showPlayIndicator = true;
          });
          widget.onPlayStateChanged?.call(false);
          _playIndicatorTimer?.cancel();
          _playIndicatorTimer = Timer(const Duration(milliseconds: 1800), () {
            if (mounted) {
              setState(() => _showPlayIndicator = false);
            }
          });
        }
      } else {
        if (!widget.isMuted && _controller.value.volume == 0.0) {
          await _controller.setVolume(1.0).catchError((_) {});
        }
        await _controller.play();
        if (mounted) {
          setState(() {
            _isUserPaused = false;
            _showPlayIndicator = true;
          });
          widget.onPlayStateChanged?.call(true);
          _playIndicatorTimer?.cancel();
          _playIndicatorTimer = Timer(const Duration(milliseconds: 600), () {
            if (mounted) {
              setState(() => _showPlayIndicator = false);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[FeedVideoPlayer] togglePlayPause error: $e');
    }
  }

  void _setSpeed(double speed) {
    if (!_isInitialized) return;
    _controller.setPlaybackSpeed(speed);
    if (speed > 1.0) {
      HapticFeedback.lightImpact();
      if (!_controller.value.isPlaying && !_isUserPaused) {
        _controller.play();
      }
    }
    setState(() => _is2xSpeed = speed > 1.0);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _openLandscapeFullscreen(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      useSafeArea: false,
      builder: (ctx) => _LandscapeVideoFullscreenDialog(
        controller: _controller,
        isMuted: widget.isMuted,
        onToggleMute: widget.onToggleMute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: const Color(0xFF11171E),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HugeIcon(icon: HugeIcons.strokeRoundedVideoOff, color: Colors.white38, size: 42),
              const SizedBox(height: 8),
              const Text(
                'Gagal memuatkan video',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _hasError = false;
                    _isInitialized = false;
                    _retryCount = 0;
                  });
                  _initializeController();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HugeIcon(icon: HugeIcons.strokeRoundedRefresh, color: Color(0xFF00E5FF), size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Cuba Semula',
                        style: TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
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

    final duration = _controller.value.duration;
    final position = _controller.value.position;
    final double currentRatio = duration.inMilliseconds > 0
        ? (_isScrubbing ? _scrubRatio : (position.inMilliseconds / duration.inMilliseconds)).clamp(0.0, 1.0)
        : 0.0;
    final scrubTime = duration * currentRatio;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Detect if this is a horizontal landscape video (aspectRatio > 1.05)
        final double videoAspect = _controller.value.aspectRatio;
        final bool isLandscape = videoAspect > 1.05;

        // Calculate landscape video frame geometry:
        // Video height when fitWidth is used = maxWidth / videoAspect
        final double safeAspect = videoAspect > 0.1 ? videoAspect : (16 / 9);
        final double videoHeight = constraints.maxWidth / safeAspect;
        // Distance from bottom of screen to the bottom edge of the vertically centered video frame
        final double videoBottomDistance = (constraints.maxHeight - videoHeight) / 2;
        // Position the "Lihat Melintang" pill in the open space below the video,
        // strictly higher than the bottom CTA and caption overlay zone
        final double minSafeBottom = widget.bottomOffset + 120;
        final double targetBottom = videoBottomDistance - 48;
        final double pillBottom = targetBottom > minSafeBottom ? targetBottom : minSafeBottom;

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Base Video Surface (IgnorePointer ensures HTML5 video element on Web doesn't swallow click events)
            IgnorePointer(
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: FittedBox(
                  // On desktop widescreen, contain ensures landscape video expands fully with zero distortion
                  // On mobile portrait, cover fills vertical immersive
                  fit: widget.isDesktop
                      ? (isLandscape ? BoxFit.contain : BoxFit.cover)
                      : (isLandscape ? BoxFit.fitWidth : BoxFit.cover),
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _controller.value.size.width > 0 ? _controller.value.size.width : 720,
                    height: _controller.value.size.height > 0 ? _controller.value.size.height : 1280,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
            ),

            // 2. Full-Screen Interactive Gesture Overlay (Tap to Play/Pause, Double-Tap Like & Long-Press 2x)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!widget.isMuted && _controller.value.volume == 0.0) {
                    _controller.setVolume(1.0).catchError((_) {});
                  }
                  _togglePlayPause();
                },
                onDoubleTapDown: (details) {
                  if (!widget.isMuted && _controller.value.volume == 0.0) {
                    _controller.setVolume(1.0).catchError((_) {});
                  }
                  widget.onDoubleTap?.call(details.globalPosition);
                },
                onLongPressStart: (_) => _setSpeed(2.0),
                onLongPressEnd: (_) => _setSpeed(1.0),
                onLongPressCancel: () => _setSpeed(1.0),
              ),
            ),

            // 2. TikTok-style "Lihat Melintang" Pill for Landscape Videos on Mobile/Portrait
            // Prominently placed in the clear space below the video frame, never obscured by CTA/caption
            if (isLandscape && !widget.isDesktop)
              Positioned(
                bottom: pillBottom,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => _openLandscapeFullscreen(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.7),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(icon: HugeIcons.strokeRoundedCrop, color: Color(0xFF00E5FF), size: 16),
                          SizedBox(width: 7),
                          Text(
                            'Lihat Melintang',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

        // 3. 2X Speed Floating Indicator
        if (_is2xSpeed)
          Positioned(
            top: widget.isDesktop ? 18 : 64,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedFlash, color: Color(0xFF00E5FF), size: 18),
                    SizedBox(width: 6),
                    Text(
                      '2X KELAJUAN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 4. Center Play/Pause Indicator (TikTok Signature: Pops on tap, auto-fades out smoothly)
        IgnorePointer(
          child: Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              scale: _showPlayIndicator ? 1.0 : 1.35,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 240),
                opacity: _showPlayIndicator ? 0.92 : 0.0,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: (!_controller.value.isPlaying) ? 4.0 : 0.0,
                      ),
                      child: Icon(
                        _controller.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 52,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 5. Floating Scrub Timestamp Bubble when Dragging Timeline
        if (_isScrubbing)
          Positioned(
            bottom: widget.isDesktop ? 32 : (widget.bottomOffset + 24),
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 10),
                  ],
                ),
                child: Text(
                  '${_formatDuration(scrubTime)} / ${_formatDuration(duration)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),

        // 6. Interactive Video Timeline Scrubber (TikTok Style Progress Bar)
        Positioned(
          left: 0,
          right: 0,
          bottom: widget.isDesktop ? 2 : (widget.bottomOffset - 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (details) {
                  setState(() {
                    _isScrubbing = true;
                    _scrubRatio = (details.localPosition.dx / barWidth).clamp(0.0, 1.0);
                  });
                },
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _scrubRatio = (details.localPosition.dx / barWidth).clamp(0.0, 1.0);
                  });
                },
                onHorizontalDragEnd: (details) {
                  final targetMs = (duration.inMilliseconds * _scrubRatio).toInt();
                  _controller.seekTo(Duration(milliseconds: targetMs));
                  setState(() => _isScrubbing = false);
                },
                onTapDown: (details) {
                  final ratio = (details.localPosition.dx / barWidth).clamp(0.0, 1.0);
                  final targetMs = (duration.inMilliseconds * ratio).toInt();
                  _controller.seekTo(Duration(milliseconds: targetMs));
                },
                child: Container(
                  height: 24, // Touch target
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Base track
                      Container(
                        height: _isScrubbing ? 5.5 : 2.5,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      // Progress track
                      FractionallySizedBox(
                        widthFactor: currentRatio,
                        child: Container(
                          height: _isScrubbing ? 5.5 : 2.5,
                          decoration: BoxDecoration(
                            color: _isScrubbing ? const Color(0xFF00E5FF) : Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(3),
                          ),
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
        );
      },
    );
  }
}

// =============================================================================
// Dialog: Skrin Penuh Video Melintang (TikTok Landscape Fullscreen Mode)
// =============================================================================
class _LandscapeVideoFullscreenDialog extends StatefulWidget {
  final VideoPlayerController controller;
  final bool isMuted;
  final VoidCallback onToggleMute;

  const _LandscapeVideoFullscreenDialog({
    required this.controller,
    required this.isMuted,
    required this.onToggleMute,
  });

  @override
  State<_LandscapeVideoFullscreenDialog> createState() =>
      _LandscapeVideoFullscreenDialogState();
}

class _LandscapeVideoFullscreenDialogState
    extends State<_LandscapeVideoFullscreenDialog> {
  bool _showControls = true;
  bool _isScrubbing = false;
  double _scrubRatio = 0.0;
  bool _is2x = false;
  Timer? _hideControlsTimer;
  double _buttonScale = 1.0;
  late bool _isMuted;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.isMuted || widget.controller.value.volume == 0.0;
    widget.controller.addListener(_listener);
    // Auto-hide controls after 2.5 seconds upon entering landscape
    _startHideControlsTimer(milliseconds: 2500);
  }

  void _listener() {
    if (mounted && !_isScrubbing) {
      setState(() {});
    }
  }

  void _startHideControlsTimer({int milliseconds = 2500}) {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(Duration(milliseconds: milliseconds), () {
      if (mounted && !_isScrubbing) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _startHideControlsTimer();
      } else {
        _hideControlsTimer?.cancel();
      }
    });
  }

  void _togglePlayPause() {
    HapticFeedback.lightImpact();
    setState(() {
      _buttonScale = 1.25;
      if (widget.controller.value.isPlaying) {
        widget.controller.pause();
      } else {
        if (!_isMuted && widget.controller.value.volume == 0.0) {
          widget.controller.setVolume(1.0).catchError((_) {});
        }
        widget.controller.play();
      }
    });

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() => _buttonScale = 1.0);
      }
    });

    // Auto-hide controls after 1.8s whether paused or playing ("pause ke play ke still butang tu hilang lepas tu")
    _startHideControlsTimer(milliseconds: 1800);
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    widget.controller.removeListener(_listener);
    if (_is2x) {
      widget.controller.setPlaybackSpeed(1.0);
    }
    super.dispose();
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _toggleSpeed() {
    setState(() {
      _is2x = !_is2x;
      widget.controller.setPlaybackSpeed(_is2x ? 2.0 : 1.0);
    });
    _startHideControlsTimer();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bool isPortraitScreen = size.width < size.height;

    final duration = widget.controller.value.duration;
    final position = widget.controller.value.position;
    final double currentRatio = duration.inMilliseconds > 0
        ? (_isScrubbing ? _scrubRatio : (position.inMilliseconds / duration.inMilliseconds)).clamp(0.0, 1.0)
        : 0.0;
    final scrubTime = duration * currentRatio;

    Widget content = Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Centered Landscape Video Player
          Center(
            child: AspectRatio(
              aspectRatio: widget.controller.value.aspectRatio > 0
                  ? widget.controller.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(widget.controller),
            ),
          ),

          // Tap gesture over entire screen to toggle controls visibility
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
            ),
          ),

          // Controls Overlay with Smooth Fade Animation
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOut,
            child: IgnorePointer(
              ignoring: !_showControls,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Top Gradient Shadow
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 90,
                    child: IgnorePointer(
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
                  ),

                  // Bottom Gradient Shadow
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 100,
                    child: IgnorePointer(
                      child: Container(
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
                      ),
                    ),
                  ),

                  // Top Bar: Close (X), Speed, Mute
                  Positioned(
                    top: 14,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            color: Colors.white,
                            size: 24,
                          ),
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Tutup Skrin Penuh',
                        ),
                        const Spacer(),
                        // 2X Speed Toggle Button
                        GestureDetector(
                          onTap: _toggleSpeed,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _is2x ? const Color(0xFF00E5FF) : Colors.black54,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              _is2x ? '2X' : '1X',
                              style: TextStyle(
                                color: _is2x ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: HugeIcon(
                            icon: _isMuted
                                ? HugeIcons.strokeRoundedVolumeOff
                                : HugeIcons.strokeRoundedVolumeHigh,
                            color: Colors.white,
                            size: 22,
                          ),
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          onPressed: () {
                            setState(() {
                              _isMuted = !_isMuted;
                              widget.controller.setVolume(_isMuted ? 0.0 : 1.0).catchError((_) {});
                            });
                            widget.onToggleMute();
                            _startHideControlsTimer();
                          },
                          tooltip: _isMuted ? 'Buka Suara' : 'Senyap',
                        ),
                      ],
                    ),
                  ),

                  // Center Big Play/Pause Button
                  Center(
                    child: GestureDetector(
                      onTap: _togglePlayPause,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOutBack,
                        scale: _buttonScale,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: HugeIcon(
                            icon: widget.controller.value.isPlaying
                                ? HugeIcons.strokeRoundedPauseCircle
                                : HugeIcons.strokeRoundedPlay,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Bar: Scrubber + Timestamps
                  Positioned(
                    bottom: 16,
                    left: 18,
                    right: 18,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isScrubbing)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              '${_format(scrubTime)} / ${_format(duration)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            Text(
                              _format(position),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final barW = constraints.maxWidth;
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onHorizontalDragStart: (details) {
                                      _hideControlsTimer?.cancel();
                                      setState(() {
                                        _isScrubbing = true;
                                        _scrubRatio = (details.localPosition.dx / barW).clamp(0.0, 1.0);
                                      });
                                    },
                                    onHorizontalDragUpdate: (details) {
                                      setState(() {
                                        _scrubRatio = (details.localPosition.dx / barW).clamp(0.0, 1.0);
                                      });
                                    },
                                    onHorizontalDragEnd: (details) {
                                      final ms = (duration.inMilliseconds * _scrubRatio).toInt();
                                      widget.controller.seekTo(Duration(milliseconds: ms));
                                      setState(() => _isScrubbing = false);
                                      _startHideControlsTimer();
                                    },
                                    child: Container(
                                      height: 24,
                                      alignment: Alignment.center,
                                      child: Stack(
                                        alignment: Alignment.centerLeft,
                                        children: [
                                          Container(
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Colors.white24,
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          FractionallySizedBox(
                                            widthFactor: currentRatio,
                                            child: Container(
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF00E5FF),
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _format(duration),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // If screen is portrait (phone held vertically), rotate 90 degrees to landscape!
    if (isPortraitScreen) {
      return RotatedBox(
        quarterTurns: 1,
        child: SizedBox(
          width: size.height,
          height: size.width,
          child: content,
        ),
      );
    }

    return content;
  }
}
