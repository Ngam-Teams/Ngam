import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/user_data.dart';
import 'package:ngam/l10n/generated/app_localizations.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../services/r2_storage_service.dart';
import '../../widgets/glass_toast.dart';
import '../../widgets/glass_box.dart';
import '../../widgets/glass_nav_button.dart';
import '../../widgets/customer_desktop_sidebar.dart';
import '../../services/saved_service.dart';
import '../../widgets/glass_share_sheet.dart';
import '../explore/business_store_view.dart';
import 'home_search_screen.dart';

// ---------------------------------------------------------------------------
// FeedVideoPreloadManager — Pengurus Pemuatan Awal Video (TikTok-Style Preloading)
// Mengelakkan kelewatan (buffering) semasa klik tab & leret (scroll) video seterusnya
// ---------------------------------------------------------------------------
class FeedVideoPreloadManager {
  static final Map<String, VideoPlayerController> _cache = {};
  static final Map<String, Future<void>> _initFutures = {};

  static VideoPlayerController? getController(String url) {
    return _cache[url.trim()];
  }

  static Future<void>? getInitFuture(String url) {
    return _initFutures[url.trim()];
  }

  static Future<VideoPlayerController?> preload(String url) async {
    final clean = url.trim();
    if (clean.isEmpty) return null;
    if (_cache.containsKey(clean)) {
      final ctrl = _cache[clean]!;
      if (!ctrl.value.isInitialized && _initFutures.containsKey(clean)) {
        await _initFutures[clean];
      }
      return ctrl;
    }

    try {
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(clean),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _cache[clean] = ctrl;
      final future = ctrl.initialize().then((_) {
        ctrl.setLooping(true);
        ctrl.setVolume(0.0).catchError((_) {});
      }).catchError((e) {
        debugPrint('[FeedVideoPreloadManager] Preload error: $e');
        _cache.remove(clean);
      });
      _initFutures[clean] = future;
      await future;
      return ctrl;
    } catch (e) {
      debugPrint('[FeedVideoPreloadManager] Init error: $e');
      _cache.remove(clean);
      return null;
    }
  }

  static void pruneExcept(Set<String> keepUrls) {
    final toRemove = <String>[];
    for (final url in _cache.keys) {
      if (!keepUrls.contains(url)) {
        toRemove.add(url);
      }
    }
    for (final url in toRemove) {
      final ctrl = _cache.remove(url);
      _initFutures.remove(url);
      try {
        ctrl?.pause();
        ctrl?.dispose();
      } catch (_) {}
    }
  }

  static void disposeAll() {
    for (final ctrl in _cache.values) {
      try {
        ctrl.pause();
        ctrl.dispose();
      } catch (_) {}
    }
    _cache.clear();
    _initFutures.clear();
  }
}

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

  // Expanded caption post IDs (TikTok style "... lagi" / "Ringkaskan")
  final Set<String> _expandedCaptionPosts = {};

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
      'cover': '',
      'thumbnail': '',
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
          'id': 'demo_cm_3',
          'user': 'Syed Amir',
          'avatar': 'https://images.unsplash.com/photo-1527980965255-d3b416303d12?q=80&w=150',
          'text': 'Kena book awal ke bro atau boleh walk-in petang ni?',
          'time': '5m lepas',
          'likes': 1,
          'replies': [
            {
              'id': 'demo_rp_1',
              'parentId': 'demo_cm_3',
              'user': 'Barber Danial',
              'replyToUser': 'Syed Amir',
              'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=200',
              'text': 'Boleh walk-in terus bro, petang ni ada 3 barber standby! 🔥',
              'time': '2m lepas',
              'likes': 3,
              'isLiked': false,
              'isCreator': true,
            },
          ],
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
      'cover': '',
      'thumbnail': '',
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
      final prefs = await SharedPreferences.getInstance();
      final Set<String> likedPostIds =
          (prefs.getStringList('ngam_liked_feed_posts') ?? const <String>[]).toSet();

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
              owner_user_id,
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
          final ownerUserId = biz['owner_user_id']?.toString() ?? '';
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
            timeAgo = 'feed_comments.just_now'.tr();
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
          final List<Map<String, String>> mediaItems = _parseFeedMediaItems(
            mediaUrl,
            row['media_type']?.toString() ?? 'image',
          );
          final String primaryUrl = mediaItems.isNotEmpty
              ? mediaItems.first['url']!
              : 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=800';
          final String primaryType = mediaItems.isNotEmpty
              ? mediaItems.first['type']!
              : (row['media_type']?.toString() ?? 'image');
          final bool isVideo = primaryType == 'video';
          final ctaType = row['cta_type']?.toString() ?? 'queue';
          final ctaText = row['cta_text']?.toString() ?? 'AMBIL GILIRAN';
          final serviceTag =
              row['service_tag']?.toString() ?? 'Servis Pantas Ngam';
          final postIdStr = row['id'].toString();
          final isPostLiked = likedPostIds.contains(postIdStr);
          final dbLikes = (row['likes_count'] as num?)?.toInt() ?? 0;

          loaded.add({
            'id': postIdStr,
            'businessId': row['business_id']?.toString(),
            'ownerUserId': ownerUserId,
            'shopName': shopName,
            'shopHandle': shopHandle,
            'shopAvatar': shopAvatar,
            'category': row['category'] ?? biz['business_industry'] ?? 'general',
            'timeAgo': timeAgo,
            'location': location,
            'image': primaryUrl,
            'mediaItems': mediaItems,
            'cover': isVideo
                ? (row['thumbnail_url'] ?? row['cover_url'] ?? '').toString().trim()
                : primaryUrl,
            'thumbnail': isVideo
                ? (row['thumbnail_url'] ?? row['cover_url'] ?? '').toString().trim()
                : primaryUrl,
            'mediaType': primaryType,
            'title': row['title'] ?? '',
            'caption': row['caption'] ?? '',
            'serviceTag': serviceTag,
            'ctaType': ctaType,
            'ctaText': ctaText,
            'views': (row['views_count'] as num?)?.toInt() ?? 0,
            'likes': isPostLiked && dbLikes == 0 ? 1 : dbLikes,
            'isLiked': isPostLiked,
            'isSaved': SavedService.isPostSaved(postIdStr),
            'isFollowed': false,
            'comments': (row['comments_count'] as num?)?.toInt() ?? 0,
            'commentList': <Map<String, dynamic>>[],
            'shopData': {
              'id': biz['id'] ?? row['business_id'],
              'owner_user_id': ownerUserId,
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

        await _hydrateSavedCommentCounts(loaded);

        if (mounted) {
          setState(() {
            _posts = loaded;
            _isLoading = false;
            if (_currentPage >= loaded.length) {
              _currentPage = 0;
            }
          });
          _preloadNearbyVideos(_currentPage);
          _recordPostView(_currentPage);
        }
        return;
      }
    } catch (e) {
      debugPrint('[CustomerFeedScreen] Live posts fetch fallback to demo: $e');
    }

    final demoCopy = _demoPosts.map((p) => Map<String, dynamic>.from(p)).toList();
    await _hydrateSavedCommentCounts(demoCopy);

    if (mounted) {
      setState(() {
        if (_posts.isEmpty) {
          _posts = demoCopy;
        }
        _isLoading = false;
      });
      _preloadNearbyVideos(_currentPage);
    }
  }

  static final Set<String> _viewedPostIdsInSession = {};

  void _recordPostView(int index) {
    if (index < 0 || index >= _posts.length) return;
    final post = _posts[index];
    final postId = post['id']?.toString() ?? '';
    if (postId.length > 20 && !_viewedPostIdsInSession.contains(postId)) {
      _viewedPostIdsInSession.add(postId);
      post['views'] = ((post['views'] as num?)?.toInt() ?? 0) + 1;
      Supabase.instance.client.rpc('increment_feed_post_views', params: {
        'p_post_id': postId,
      }).catchError((e) {
        debugPrint('[CustomerFeedScreen] View count RPC failed: $e');
      });
    }
  }

  static bool _isVideoMediaUrl(String url) {
    final clean = url.trim().toLowerCase();
    return clean.endsWith('.mp4') ||
        clean.endsWith('.mov') ||
        clean.endsWith('.webm') ||
        clean.contains('/video/') ||
        clean.contains('.mp4?');
  }

  static List<Map<String, String>> _parseFeedMediaItems(String rawMediaUrl, String fallbackMediaType) {
    final trimmed = rawMediaUrl.trim();
    if (trimmed.isEmpty) return const [];
    if (trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          final items = <Map<String, String>>[];
          for (final entry in decoded) {
            if (entry is Map) {
              final u = entry['url']?.toString().trim() ?? '';
              final t = entry['type']?.toString().trim().toLowerCase();
              if (u.isNotEmpty) {
                items.add({
                  'url': u,
                  'type': (t == 'video' || _isVideoMediaUrl(u)) ? 'video' : 'image',
                });
              }
            } else if (entry is String && entry.trim().isNotEmpty) {
              final u = entry.trim();
              items.add({'url': u, 'type': _isVideoMediaUrl(u) ? 'video' : 'image'});
            }
          }
          if (items.isNotEmpty) return items;
        }
      } catch (_) {}
    }
    final isVid = fallbackMediaType.toLowerCase() == 'video' || _isVideoMediaUrl(trimmed);
    return [
      {'url': trimmed, 'type': isVid ? 'video' : 'image'}
    ];
  }

  /// Pemuatan awal video berdekatan secara pintar (gaya TikTok)
  void _preloadNearbyVideos(int currentIndex) {
    if (_posts.isEmpty) return;
    final keepUrls = <String>{};
    final int start = math.max(0, currentIndex - 1);
    final int end = math.min(_posts.length - 1, currentIndex + 2);

    for (int i = start; i <= end; i++) {
      final p = _posts[i];
      final rawItems = p['mediaItems'];
      if (rawItems is List && rawItems.isNotEmpty) {
        for (final item in rawItems) {
          if (item is Map && item['type'] == 'video') {
            final u = (item['url'] ?? '').toString().trim();
            if (u.isNotEmpty) {
              keepUrls.add(u);
              FeedVideoPreloadManager.preload(u);
            }
          }
        }
      } else {
        final mediaUrl = (p['image'] ?? '').toString().trim();
        final bool isVid = (p['mediaType'] == 'video') || _isVideoMediaUrl(mediaUrl);
        if (isVid && mediaUrl.isNotEmpty) {
          keepUrls.add(mediaUrl);
          FeedVideoPreloadManager.preload(mediaUrl);
        }
      }
    }
    FeedVideoPreloadManager.pruneExcept(keepUrls);
  }

  /// Kira jumlah semua komen utama + balasan (replies) di bawah setiap komen
  static int countAllCommentsAndReplies(List<dynamic>? rawList) {
    if (rawList == null || rawList.isEmpty) return 0;
    int total = 0;
    for (final item in rawList) {
      if (item is Map) {
        total += 1;
        final replies = item['replies'];
        if (replies is List) {
          total += replies.length;
        }
      }
    }
    return total;
  }

  /// Selaraskan bilangan komen daripada SharedPreferences & jadual feed_comments supaya nombor komen di Feed sentiasa tepat
  Future<void> _hydrateSavedCommentCounts(List<Map<String, dynamic>> postsList) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Cuba tarik kiraan sebenar dari jadual feed_comments jika ada pos Supabase
      final Map<String, int> dbCommentCounts = {};
      final livePostIds = postsList
          .map((p) => p['id']?.toString() ?? '')
          .where((id) => id.length > 20)
          .toList();

      bool fetchedDbCounts = false;
      if (livePostIds.isNotEmpty) {
        try {
          final rows = await Supabase.instance.client
              .from('feed_comments')
              .select('id, post_id')
              .inFilter('post_id', livePostIds);
          fetchedDbCounts = true;
          for (final r in rows) {
            final pid = r['post_id']?.toString() ?? '';
            if (pid.isNotEmpty) {
              dbCommentCounts[pid] = (dbCommentCounts[pid] ?? 0) + 1;
            }
          }
        } catch (_) {}
      }

      for (final post in postsList) {
        final String postId = post['id']?.toString() ?? '';
        if (postId.isEmpty) continue;

        if (postId.length > 20 && fetchedDbCounts) {
          final int liveDbRowsCount = dbCommentCounts[postId] ?? 0;
          post['comments'] = liveDbRowsCount;
          await prefs.setInt('ngam_feed_comments_base_$postId', 0);
          await prefs.setInt('ngam_feed_comments_total_$postId', liveDbRowsCount);
          continue;
        }

        final int initialMetaCount = (post['comments'] as num?)?.toInt() ?? 0;
        final int liveDbRowsCount = dbCommentCounts[postId] ?? 0;
        final List? seedList = post['commentList'] as List?;
        final int seedListCount = countAllCommentsAndReplies(seedList);

        // Semak jika ada komen tersimpan secara tempatan
        List<Map<String, dynamic>>? cachedComments;
        int cachedCount = 0;
        final String? cachedJson = prefs.getString('ngam_feed_comments_$postId');
        if (cachedJson != null && cachedJson.isNotEmpty) {
          try {
            final List decoded = jsonDecode(cachedJson);
            cachedComments =
                decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            cachedCount = countAllCommentsAndReplies(cachedComments);
          } catch (_) {}
        }

        // Simpan atau dapatkan base offset supaya setiap komen/balasan baharu sentiasa +1
        int? baseOffset = prefs.getInt('ngam_feed_comments_base_$postId');
        if (baseOffset == null) {
          final int actualKnownCount =
              math.max(seedListCount, math.max(cachedCount, liveDbRowsCount));
          baseOffset = math.max(0, initialMetaCount - actualKnownCount);
          await prefs.setInt('ngam_feed_comments_base_$postId', baseOffset);
        }

        if (cachedComments != null) {
          post['commentList'] = cachedComments;
          final int computedTotal = baseOffset + cachedCount;
          post['comments'] = math.max(computedTotal, liveDbRowsCount);
          await prefs.setInt('ngam_feed_comments_total_$postId', post['comments'] as int);
          continue;
        }

        final int effectiveCount = math.max(
          initialMetaCount,
          math.max(liveDbRowsCount, baseOffset + seedListCount),
        );
        post['comments'] = effectiveCount;
      }
    } catch (e) {
      debugPrint('[CustomerFeedScreen] Error hydrating comment counts: $e');
    }
  }

  void _syncPostCommentCount(
    String postId,
    int newCount,
    List<Map<String, dynamic>> updatedComments,
  ) {
    if (!mounted) return;
    setState(() {
      for (final p in _posts) {
        if (p['id']?.toString() == postId) {
          p['comments'] = newCount;
          p['commentList'] = List<Map<String, dynamic>>.from(updatedComments);
        }
      }
      if (_desktopCommentsPost != null &&
          _desktopCommentsPost!['id']?.toString() == postId) {
        _desktopCommentsPost!['comments'] = newCount;
        _desktopCommentsPost!['commentList'] =
            List<Map<String, dynamic>>.from(updatedComments);
      }
    });
  }

  Future<void> _persistPostLikeState(String postId, bool isLiked) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = (prefs.getStringList('ngam_liked_feed_posts') ?? <String>[]).toSet();
      if (isLiked) {
        list.add(postId);
      } else {
        list.remove(postId);
      }
      await prefs.setStringList('ngam_liked_feed_posts', list.toList());
    } catch (_) {}
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
      if (postId != null && postId.isNotEmpty) {
        _persistPostLikeState(postId, true);
        if (postId.length > 20) {
          Supabase.instance.client.rpc('toggle_feed_post_like', params: {
            'p_post_id': postId,
            'p_increment': true,
          }).catchError((e) {
            debugPrint('[CustomerFeedScreen] Double-tap like RPC failed: $e');
          });
        }
      }
    }
  }

  void _toggleLike(Map<String, dynamic> post) {
    final bool wasLiked = post['isLiked'] == true;
    final bool nowLiked = !wasLiked;
    setState(() {
      post['isLiked'] = nowLiked;
      post['likes'] = math.max(0, (post['likes'] as int) + (nowLiked ? 1 : -1));
    });

    final postId = post['id']?.toString();
    if (postId != null && postId.isNotEmpty) {
      _persistPostLikeState(postId, nowLiked);
      if (postId.length > 20) {
        Supabase.instance.client.rpc('toggle_feed_post_like', params: {
          'p_post_id': postId,
          'p_increment': nowLiked,
        }).catchError((e) {
          debugPrint('[CustomerFeedScreen] Like RPC failed: $e');
        });
      }
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
    _preloadNearbyVideos(index);
    _recordPostView(index);
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _persistedIsMuted = _isMuted;
    });
    showGlassToast(
      context,
      _isMuted ? 'feed_comments.audio_muted'.tr() : 'feed_comments.audio_unmuted'.tr(),
      icon: _isMuted
          ? HugeIcons.strokeRoundedVolumeOff
          : HugeIcons.strokeRoundedVolumeHigh,
    );
  }

  List<Map<String, String>> _parseCtaItems(Map<String, dynamic> post) {
    final rawText = (post['ctaText'] ?? '').toString().trim();
    final fallbackType = (post['ctaType'] ?? 'queue').toString().trim();
    if (rawText.isEmpty) return const [];
    if (rawText.startsWith('[')) {
      try {
        final decoded = jsonDecode(rawText);
        if (decoded is List) {
          final items = <Map<String, String>>[];
          for (final entry in decoded) {
            if (entry is Map) {
              final text = entry['text']?.toString().trim() ?? '';
              final type = entry['type']?.toString().trim() ?? fallbackType;
              if (text.isNotEmpty) {
                items.add({'type': type, 'text': text});
              }
            }
            if (items.length >= 3) break;
          }
          return items;
        }
      } catch (_) {}
    }
    return [
      {
        'type': fallbackType.isEmpty ? 'queue' : fallbackType,
        'text': rawText,
      }
    ];
  }

  void _handleCtaAction(Map<String, dynamic> post, {String? overrideCtaType}) {
    final ctaType = overrideCtaType ?? post['ctaType']?.toString() ?? 'queue';
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
    final String postId = (post['id'] ?? '').toString();
    final bool willBeSaved = !SavedService.isPostSaved(postId);

    HapticFeedback.lightImpact();
    setState(() {
      post['isSaved'] = willBeSaved;
    });

    showGlassToast(
      context,
      willBeSaved
          ? 'Hantaran disimpan ke koleksi anda'
          : 'Hantaran dikeluarkan dari simpanan',
      icon: HugeIcons.strokeRoundedBookmark02,
    );

    SavedService.toggleSavePost(post);
  }

  void _sharePost(Map<String, dynamic> post) {
    HapticFeedback.lightImpact();
    showGlassShareSheet(
      context,
      post: post,
      onPostHidden: () {
        setState(() {
          _posts.removeWhere((p) => p['id']?.toString() == post['id']?.toString());
        });
      },
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
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final bool isLandscape = screenWidth > screenHeight;
    final bool isDesktopLandscape = screenWidth >= 768 || (isLandscape && screenWidth >= 500);
    final themeProvider = context.watch<ThemeProvider?>();
    final bool isDark = themeProvider?.isDarkMode ?? (Theme.of(context).brightness == Brightness.dark);
    final Color scaffoldBg = isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC);
    
    // Bottom padding to position feed content comfortably and cleanly above the floating navbar
    final double adjustedSafeBottom = safeBottom > 0 ? (safeBottom * 0.5) : 10.0;
    final double bottomOffset = adjustedSafeBottom + 88.0;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Abaikan semua pintasan papan kekunci jika pengguna sedang menaip (TextField / EditableText)
          final primaryFocus = FocusManager.instance.primaryFocus;
          if (primaryFocus != null && primaryFocus.context != null) {
            final isEditable = primaryFocus.context!.findAncestorWidgetOfExactType<EditableText>() != null;
            if (isEditable) {
              return KeyEventResult.ignored;
            }
          }
          // Jika modal ulasan atau panel komen dibuka, abaikan kekunci huruf seperti 'M'
          if (_isModalOrRouteOpen || _desktopCommentsPost != null) {
            if (event.logicalKey == LogicalKeyboardKey.keyM) {
              return KeyEventResult.ignored;
            }
          }

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
              ? CustomerDesktopSidebar.getSidebarTotalWidth(context, isSidebarExpanded)
              : 0.0;
          final double leftContentOffset = sidebarOccupiedWidth;
          final double commentsPanelWidth = (screenWidth * 0.32).clamp(380.0, 460.0);
          final double rightContentOffset = (isDesktopLandscape && _desktopCommentsPost != null)
              ? commentsPanelWidth
              : 0.0;

          return Scaffold(
        backgroundColor: scaffoldBg,
        body: Stack(
        fit: StackFit.expand,
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

          // 1. VERTICAL FULL SCREEN PAGEVIEW (TIKTOK STYLE - EDGE TO EDGE FULL BLEED)
          Positioned.fill(
            child: RefreshIndicator(
              color: const Color(0xFF00E5FF),
              backgroundColor: isDark ? const Color(0xFF141920) : Colors.white,
              onRefresh: _fetchLivePosts,
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeBottom: true,
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
                                  'customer.feed_loading'.tr(),
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
                                  'customer.feed_empty'.tr(),
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
                                  label: Text(
                                    'customer.reload'.tr(),
                                    style: const TextStyle(color: Color(0xFF00E5FF)),
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
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Center Feed Switcher: 'Berhampiran' vs 'Untuk Anda' (TikTok Signature Style)
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

                      // TikTok-style Video Search shortcut on the far right
                      Align(
                        alignment: Alignment.centerRight,
                        child: GlassNavButton(
                          icon: HugeIcons.strokeRoundedSearch01,
                          tooltip: 'search.tab_videos'.tr(),
                          isDark: !(isDesktopLandscape && !isDark),
                          size: 38,
                          iconSize: 18,
                          onTap: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder<void>(
                                transitionDuration: const Duration(milliseconds: 220),
                                reverseTransitionDuration: const Duration(milliseconds: 180),
                                pageBuilder: (_, __, ___) => HomeSearchScreen(
                                  initialFeedPosts: _posts,
                                  initialResultTab: 3,
                                  isVideoFocused: true,
                                ),
                                transitionsBuilder: (_, animation, __, child) {
                                  return FadeTransition(opacity: animation, child: child);
                                },
                              ),
                            );
                          },
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
                        onCommentCountChanged: (count, updatedList) {
                          _syncPostCommentCount(
                            _desktopCommentsPost!['id']?.toString() ?? '',
                            count,
                            updatedList,
                          );
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
    final bool isLandscape = screenWidth > screenHeight;
    final bool isDesktopLandscape = screenWidth >= 768 || (isLandscape && screenWidth >= 500);
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
                            _buildMediaContent(
                              post,
                              index,
                              bottomOffset: 16,
                              isDesktop: true,
                              bottomContent: _buildBottomContent(post),
                            ),

                            // For photo media only: subtle ambient gradients behind caption
                            if (!isVideoMedia) ...[
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: 80,
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.35),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                height: 180,
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.25),
                                          Colors.black.withValues(alpha: 0.65),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            // Caption & CTA overlay inside card (for images only; video handles it inside _FeedVideoPlayerItem)
                            if (!isVideoMedia)
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
              _buildMediaContent(
                post,
                index,
                bottomOffset: bottomOffset,
                isDesktop: false,
                bottomContent: _buildBottomContent(post),
              ),

              // For photo media only: subtle ambient gradients strictly behind caption
              if (!isVideoMedia) ...[
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
                            Colors.black.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 200,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.25),
                            Colors.black.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // 2. RIGHT-SIDE FLOATING ACTION BAR (Mobile)
        Positioned(
          right: 12,
          bottom: bottomOffset + 8,
          child: _buildActionBar(
            post,
            isShortPhone: isShortPhone,
            isDesktop: false,
          ),
        ),

        // 3. BOTTOM CONTENT OVERLAY (Mobile - for images & carousels; single video handles it inside _FeedVideoPlayerItem)
        if (!isVideoMedia || (post['mediaItems'] is List && (post['mediaItems'] as List).length > 1))
          Positioned(
            left: 16,
            right: 76,
            bottom: bottomOffset + 6,
            child: _buildBottomContent(post),
          ),
      ],
    );
  }

  // --- MEDIA CONTENT BUILDER (CAROUSEL, VIDEO PLAYER, OR IMAGE) ---
  Widget _buildMediaContent(
    Map<String, dynamic> post,
    int index, {
    required double bottomOffset,
    bool isDesktop = false,
    Widget? bottomContent,
  }) {
    final rawItems = post['mediaItems'];
    final List<Map<String, String>> mediaItems = [];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          final u = (item['url'] ?? '').toString().trim();
          final t = (item['type'] ?? 'image').toString().trim();
          if (u.isNotEmpty) {
            mediaItems.add({'url': u, 'type': t});
          }
        }
      }
    }

    if (mediaItems.length > 1) {
      return _FeedCarouselMediaView(
        key: ValueKey('feed_carousel_${post['id']}'),
        postId: post['id']?.toString() ?? '',
        items: mediaItems,
        isCurrentPage: index == _currentPage,
        isPausedExternally: !widget.isTabActive || _isModalOrRouteOpen,
        isMuted: _isMuted,
        bottomOffset: bottomOffset,
        isDesktop: isDesktop,
        onToggleMute: _toggleMute,
        onDoubleTap: (pos) => _handleDoubleTap(pos, post),
        onPlayStateChanged: (playing) {
          if (mounted && index == _currentPage && _isVideoPlaying != playing) {
            setState(() => _isVideoPlaying = playing);
          }
        },
      );
    }

    final String mediaUrl = mediaItems.isNotEmpty
        ? mediaItems.first['url']!
        : (post['image']?.toString() ?? '');
    final String cleanMedia = mediaUrl.trim().toLowerCase();
    final bool isVideo = (mediaItems.isNotEmpty
            ? mediaItems.first['type'] == 'video'
            : (post['mediaType'] == 'video' || _isVideoMediaUrl(cleanMedia))) &&
        mediaUrl.isNotEmpty;

    if (isVideo) {
      return _FeedVideoPlayerItem(
        key: ValueKey('feed_vid_${post['id']}_$mediaUrl'),
        videoUrl: mediaUrl,
        isCurrentPage: index == _currentPage,
        isPausedExternally: !widget.isTabActive || _isModalOrRouteOpen,
        isMuted: _isMuted,
        bottomOffset: bottomOffset,
        isDesktop: isDesktop,
        bottomContent: bottomContent,
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

    return Container(
      color: Colors.black,
      child: SizedBox.expand(
        child: CachedNetworkImage(
          imageUrl: mediaUrl,
          fit: BoxFit.contain,
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
        ),
      ),
    );
  }

  // --- BOTTOM CONTENT (CTA, SHOP HANDLE, CAPTION, MUSIC TICKER) ---
  Widget _buildBottomContent(Map<String, dynamic> post) {
    final ctaItems = _parseCtaItems(post);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // EXCLUSIVE NGAM DIRECT CTA BUTTON(S) — 0 to 3
        if (ctaItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: ctaItems.asMap().entries.map((entry) {
                final idx = entry.key;
                final cta = entry.value;
                final isPrimary = idx == 0;
                return GestureDetector(
                  onTap: () => _handleCtaAction(post, overrideCtaType: cta['type']),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isPrimary ? 14 : 11,
                      vertical: isPrimary ? 8 : 7,
                    ),
                    decoration: BoxDecoration(
                      gradient: isPrimary
                          ? const LinearGradient(
                              colors: [Color(0xFF00E5FF), Color(0xFF0284C7)],
                            )
                          : null,
                      color: isPrimary ? null : Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(16),
                      border: isPrimary
                          ? null
                          : Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.6)),
                      boxShadow: isPrimary
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPrimary) ...[
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedFlash,
                            color: Colors.black,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            cta['text'] ?? '',
                            style: TextStyle(
                              color: isPrimary ? Colors.black : Colors.white,
                              fontSize: isPrimary ? 12 : 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowRight01,
                          color: isPrimary ? Colors.black : const Color(0xFF00E5FF),
                          size: 11,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
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

        // Post Caption & Hashtags (TikTok-Style Expandable Caption with "... lagi" / "Ringkaskan")
        Builder(
          builder: (context) {
            final String postId = (post['id'] ?? '').toString();
            final String rawCaption = (post['caption'] ?? '').toString();
            final bool isExpanded = _expandedCaptionPosts.contains(postId);
            final bool isLong = rawCaption.length > 70 || rawCaption.contains('\n');

            if (!isLong) {
              return Text(
                rawCaption,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  shadows: [
                    Shadow(color: Colors.black87, blurRadius: 6),
                  ],
                ),
              );
            }

            if (!isExpanded) {
              final int cutIndex = rawCaption.length > 68 ? 68 : rawCaption.length;
              final String truncated = rawCaption.substring(0, cutIndex).trimRight();

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _expandedCaptionPosts.add(postId);
                  });
                },
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 6),
                      ],
                    ),
                    children: [
                      TextSpan(text: '$truncated... '),
                      const TextSpan(
                        text: 'lagi',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      rawCaption,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _expandedCaptionPosts.remove(postId);
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: const Text(
                      'Ringkaskan',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
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

        // Save / Bookmark Action (Reactive to SavedService)
        ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: SavedService.savedPostsNotifier,
          builder: (context, _, __) {
            final String postId = (post['id'] ?? '').toString();
            final bool isItemSaved = SavedService.isPostSaved(postId);
            return _buildRightActionButton(
              hugeIcon: isItemSaved ? Icons.bookmark_rounded : HugeIcons.strokeRoundedBookmark02,
              iconColor: isItemSaved ? const Color(0xFFFBBF24) : Colors.white,
              label: 'Simpan',
              isCompact: isShortPhone,
              isDesktop: isDesktop,
              isDark: isDark,
              onTap: () => _toggleSave(post),
            );
          },
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
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final bool isLandscape = screenWidth > screenHeight;
    final bool isDesktop = screenWidth >= 768 || (isLandscape && screenWidth >= 500);
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
    setState(() => _isModalOrRouteOpen = true);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final size = MediaQuery.of(ctx).size;
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        final topPad = MediaQuery.of(ctx).padding.top;
        final bool keyboardOpen = bottomInset > 80;
        final double maxAvail = math.max(180.0, size.height - bottomInset - topPad - 24);
        final double sheetHeight = keyboardOpen
            ? math.min(maxAvail, size.height * 0.76)
            : math.min(maxAvail, (size.height * 0.70).clamp(360.0, 700.0));

        return Column(
          children: [
            // 1. Mini Video / Media Preview Stage at Top (TikTok style)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(ctx),
                child: SafeArea(
                  bottom: false,
                  child: _MiniCommentPostStage(
                    post: post,
                    onClose: () => Navigator.pop(ctx),
                  ),
                ),
              ),
            ),

            // 2. Solid TikTok Comments Sheet at Bottom
            Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                height: sheetHeight,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16161B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.14),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _FeedCommentsView(
                  post: post,
                  isDesktop: false,
                  onClose: () => Navigator.pop(ctx),
                  onCommentCountChanged: (count, updatedList) {
                    post['comments'] = count;
                    post['commentList'] = updatedList;
                    _syncPostCommentCount(
                      post['id']?.toString() ?? '',
                      count,
                      updatedList,
                    );
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
    if (mounted) {
      setState(() => _isModalOrRouteOpen = false);
    }
  }
}

class _MiniCommentPostStage extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onClose;

  const _MiniCommentPostStage({
    required this.post,
    required this.onClose,
  });

  @override
  State<_MiniCommentPostStage> createState() => _MiniCommentPostStageState();
}

class _MiniCommentPostStageState extends State<_MiniCommentPostStage> {
  VideoPlayerController? _vc;
  bool _initialized = false;

  String get _mediaUrl {
    final items = widget.post['mediaItems'];
    if (items is List && items.isNotEmpty && items.first is Map) {
      final u = items.first['url']?.toString().trim() ?? '';
      if (u.isNotEmpty) return u;
    }
    return widget.post['image']?.toString().trim() ?? '';
  }

  bool get _isVideo {
    final items = widget.post['mediaItems'];
    if (items is List && items.isNotEmpty && items.first is Map) {
      if (items.first['type']?.toString() == 'video') return true;
    }
    return widget.post['mediaType'] == 'video' ||
        _CustomerFeedScreenState._isVideoMediaUrl(_mediaUrl);
  }

  @override
  void initState() {
    super.initState();
    if (_isVideo && _mediaUrl.isNotEmpty) {
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(_mediaUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _vc = ctrl;
      ctrl.initialize().then((_) {
        if (!mounted) return;
        ctrl.setLooping(true);
        ctrl.setVolume(0.0);
        ctrl.play();
        setState(() => _initialized = true);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _vc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String thumbUrl =
        (widget.post['cover']?.toString().trim().isNotEmpty == true)
            ? widget.post['cover'].toString().trim()
            : _mediaUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: AspectRatio(
          aspectRatio: 9 / 14,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 16,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _isVideo && _initialized && _vc != null
                ? FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: _vc!.value.size.width > 0 ? _vc!.value.size.width : 9,
                      height: _vc!.value.size.height > 0 ? _vc!.value.size.height : 16,
                      child: VideoPlayer(_vc!),
                    ),
                  )
                : (thumbUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumbUrl,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(Icons.play_circle_outline_rounded, color: Colors.white54, size: 32),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.play_circle_outline_rounded, color: Colors.white54, size: 32),
                      )),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// REUSABLE FEED COMMENTS VIEW (TIKTOK & INSTAGRAM REELS ADAPTIVE)
// Used in right side sliding panel on Desktop, and bottom sheet on Mobile.
// Supports TikTok/Reels threaded replies directly underneath each comment!
// =============================================================================
class _FeedCommentsView extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isDesktop;
  final VoidCallback onClose;
  final void Function(int newCount, List<Map<String, dynamic>> updatedComments)?
      onCommentCountChanged;

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
  late final TextEditingController _commentController;
  late final FocusNode _commentFocusNode;
  late final ScrollController _scrollController;
  final List<Map<String, dynamic>> _comments = [];
  final Set<String> _expandedCommentIds = {};
  final Set<String> _likedCommentIds = {};

  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isUploadingImage = false;
  bool _sortByTop = false;
  bool _showEmojiStrip = false;
  String? _loadedPostId;
  String? _activeFetchPostId;
  int _baseCommentOffset = 0;
  Timer? _livePollTimer;

  // Photo attachment state for TikTok-style photo comments
  Uint8List? _pendingImageBytes;
  String? _pendingImageName;
  final ImagePicker _commentImagePicker = ImagePicker();

  // Reply state (TikTok / Instagram Reels nested thread target)
  String? _replyingToCommentId;
  String? _replyingToUser;
  bool _hasInputText = false;

  // Cached current user Ngam App profile from public.users (never raw Google OAuth fallback if Ngam profile exists)
  String _resolvedAppUserName = '';
  String _resolvedAppUserAvatar = '';

  static const List<String> _quickEmojis = [
    '🔥',
    '😍',
    '👏',
    '❤️',
    '😂',
    '👍',
    '✨',
    '🙌',
  ];

  int get _totalCommentCount =>
      _baseCommentOffset +
      _CustomerFeedScreenState.countAllCommentsAndReplies(_comments);

  bool get _isCurrentUserStoreOwner {
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    final ownerUid = widget.post['ownerUserId']?.toString() ??
        (widget.post['shopData'] is Map
            ? widget.post['shopData']['owner_user_id']?.toString()
            : null) ??
        '';
    if (myUid != null && myUid.isNotEmpty && ownerUid.isNotEmpty && myUid == ownerUid) {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _commentFocusNode = FocusNode();
    _scrollController = ScrollController();

    _commentController.addListener(() {
      final hasText = _commentController.text.trim().isNotEmpty;
      if (hasText != _hasInputText) {
        setState(() => _hasInputText = hasText);
      }
    });

    final rawList = widget.post['commentList'] as List?;
    if (rawList != null && rawList.isNotEmpty) {
      _comments.addAll(_normalizeCommentsList(rawList));
    }
    final String postId = widget.post['id']?.toString() ?? '';
    final int currentListItems =
        _CustomerFeedScreenState.countAllCommentsAndReplies(_comments);
    final int postMetaComments = (widget.post['comments'] as num?)?.toInt() ?? 0;
    _baseCommentOffset = postId.length > 20
        ? 0
        : math.max(0, postMetaComments - currentListItems);

    _hydrateCurrentUserAppProfile();
    _initAndFetchComments();

    // Poll live comments every 8 seconds while sheet is open so comments/replies from other devices appear live
    _livePollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      final pid = _loadedPostId;
      if (mounted && pid != null && pid.length > 20 && !_isSubmitting) {
        _fetchLiveComments(pid, silent: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _FeedCommentsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post['id'] != oldWidget.post['id']) {
      _replyingToCommentId = null;
      _replyingToUser = null;
      _pendingImageBytes = null;
      _pendingImageName = null;
      _showEmojiStrip = false;
      _commentController.clear();
      _hydrateCurrentUserAppProfile();
      _initAndFetchComments();
    }
  }

  @override
  void dispose() {
    _livePollTimer?.cancel();
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Pastikan profil komen sentiasa menggunakan profil sebenar Ngam App (`public.users`),
  /// BUKAN nama/gambar Google OAuth mentah.
  Future<void> _hydrateCurrentUserAppProfile() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final appUser = authProvider.user;
      if (appUser != null) {
        final appUserName = (appUser.userName ?? '').trim();
        if (appUserName.isNotEmpty) {
          _resolvedAppUserName = appUserName;
          UserData.userName.value = _resolvedAppUserName;
        }
        if ((appUser.userAvatarUrl ?? '').trim().isNotEmpty) {
          _resolvedAppUserAvatar = appUser.userAvatarUrl!.trim();
          UserData.userProfilePic.value = _resolvedAppUserAvatar;
        }
      }
    } catch (_) {}

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      try {
        final row = await Supabase.instance.client
            .from('users')
            .select('user_name, user_avatar_url')
            .eq('id', currentUser.id)
            .maybeSingle();
        if (row != null && mounted) {
          final dbName = row['user_name']?.toString().trim() ?? '';
          final dbAvatar = row['user_avatar_url']?.toString().trim() ?? '';
          setState(() {
            if (dbName.isNotEmpty) {
              _resolvedAppUserName = dbName;
              UserData.userName.value = dbName;
            }
            // Gunakan user_avatar_url dari jadual public.users (walaupun kosong jika pengguna tiada gambar profil Ngam)
            _resolvedAppUserAvatar = dbAvatar;
            UserData.userProfilePic.value = dbAvatar;
          });
        }
      } catch (_) {}
    }
  }

  ({String name, String avatar, bool isOwner}) _getActiveCommenterIdentity() {
    final String shopName = widget.post['shopName']?.toString() ?? '';
    final String shopAvatar = widget.post['shopAvatar']?.toString() ?? '';
    final bool isOwner = _isCurrentUserStoreOwner;

    String name = _resolvedAppUserName.trim();
    if (name.isEmpty) {
      try {
        final authUser = context.read<AuthProvider>().user;
        final authUserName = (authUser?.userName ?? '').trim();
        if (authUserName.isNotEmpty) {
          name = authUserName;
        }
      } catch (_) {}
    }
    if (name.isEmpty && UserData.userName.value.trim().isNotEmpty) {
      name = UserData.userName.value.trim();
    }
    if (name.isEmpty) {
      final currentUser = Supabase.instance.client.auth.currentUser;
      name = (currentUser?.userMetadata?['display_name'] as String?)?.trim() ??
          (currentUser?.userMetadata?['user_name'] as String?)?.trim() ??
          (currentUser?.email?.split('@').first) ??
          'feed_comments.default_customer'.tr();
    }

    String avatar = _resolvedAppUserAvatar.trim();
    if (avatar.isEmpty) {
      try {
        final authUser = context.read<AuthProvider>().user;
        if (authUser != null && (authUser.userAvatarUrl ?? '').trim().isNotEmpty) {
          avatar = authUser.userAvatarUrl!.trim();
        }
      } catch (_) {}
    }
    if (avatar.isEmpty && UserData.userProfilePic.value.trim().isNotEmpty) {
      avatar = UserData.userProfilePic.value.trim();
    }

    // Jika pemilik kedai membalas dan tiada avatar peribadi, gunakan logo kedai
    if (isOwner && avatar.isEmpty && shopAvatar.isNotEmpty) {
      avatar = shopAvatar;
    }

    final bool matchesShop = shopName.isNotEmpty &&
        name.toLowerCase().trim() == shopName.toLowerCase().trim();

    return (
      name: name,
      avatar: avatar,
      isOwner: isOwner || matchesShop,
    );
  }

  String _storageKey(String postId) => 'ngam_feed_comments_$postId';
  String _baseKey(String postId) => 'ngam_feed_comments_base_$postId';
  String _totalKey(String postId) => 'ngam_feed_comments_total_$postId';

  ({String text, String imageUrl}) _extractCommentTextAndImage(String raw) {
    final imgRegex = RegExp(r'\[\[IMG:([^\]]+)\]\]', caseSensitive: false);
    String imageUrl = '';
    final match = imgRegex.firstMatch(raw);
    if (match != null) {
      imageUrl = (match.group(1) ?? '').trim();
    }
    final cleanText = raw.replaceAll(imgRegex, '').trim();
    return (text: cleanText, imageUrl: imageUrl);
  }

  String _encodeCommentTextWithImage(String text, String? imageUrl) {
    final cleanText = text.trim();
    final cleanImg = (imageUrl ?? '').trim();
    if (cleanImg.isEmpty) return cleanText;
    if (cleanText.isEmpty) return '[[IMG:$cleanImg]]';
    return '$cleanText\n[[IMG:$cleanImg]]';
  }

  List<Map<String, dynamic>> _normalizeCommentsList(List<dynamic> raw) {
    final List<Map<String, dynamic>> result = [];
    for (int i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final String cid = (map['id']?.toString() ?? '').trim().isNotEmpty
          ? map['id'].toString()
          : 'cm_seed_${i}_${map['user'] ?? 'u'}';
      map['id'] = cid;

      final parsed = _extractCommentTextAndImage(map['text']?.toString() ?? '');
      map['text'] = parsed.text;
      if ((map['imageUrl']?.toString().trim() ?? '').isEmpty && parsed.imageUrl.isNotEmpty) {
        map['imageUrl'] = parsed.imageUrl;
      }

      final List<Map<String, dynamic>> normalizedReplies = [];
      final rawReplies = map['replies'];
      if (rawReplies is List) {
        for (int j = 0; j < rawReplies.length; j++) {
          final r = rawReplies[j];
          if (r is Map) {
            final rMap = Map<String, dynamic>.from(r);
            rMap['id'] = (rMap['id']?.toString() ?? '').trim().isNotEmpty
                ? rMap['id'].toString()
                : 'rp_seed_${i}_$j';
            rMap['parentId'] = cid;
            final rParsed = _extractCommentTextAndImage(rMap['text']?.toString() ?? '');
            rMap['text'] = rParsed.text;
            if ((rMap['imageUrl']?.toString().trim() ?? '').isEmpty && rParsed.imageUrl.isNotEmpty) {
              rMap['imageUrl'] = rParsed.imageUrl;
            }
            normalizedReplies.add(rMap);
          }
        }
      }
      map['replies'] = normalizedReplies;
      if (normalizedReplies.isNotEmpty) {
        _expandedCommentIds.add(cid);
      }
      result.add(map);
    }
    return result;
  }

  Future<void> _persistAndNotifyCount(String postId) async {
    final int newTotal = _totalCommentCount;
    widget.post['commentList'] = _comments;
    widget.post['comments'] = newTotal;
    widget.onCommentCountChanged?.call(newTotal, _comments);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey(postId), jsonEncode(_comments));
      await prefs.setInt(_baseKey(postId), _baseCommentOffset);
      await prefs.setInt(_totalKey(postId), newTotal);
    } catch (e) {
      debugPrint('[FeedComments] Error saving local comments: $e');
    }
  }

  void _initAndFetchComments() async {
    final String postId = widget.post['id']?.toString() ?? '';
    _loadedPostId = postId;
    _comments.clear();
    _expandedCommentIds.clear();

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final savedLikes = prefs.getStringList('ngam_liked_feed_comments') ?? const <String>[];
      _likedCommentIds
        ..clear()
        ..addAll(savedLikes);
    } catch (_) {}

    // 1. Load cached comments from SharedPreferences if present
    bool loadedFromCache = false;
    if (prefs != null) {
      final cachedJson = prefs.getString(_storageKey(postId));
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final List list = jsonDecode(cachedJson);
          _comments.addAll(_normalizeCommentsList(list));
          loadedFromCache = true;
        } catch (e) {
          debugPrint('[FeedComments] Error decoding cached comments: $e');
        }
      }
    }

    // 2. If no local cache, check initial commentList from post payload
    if (!loadedFromCache) {
      final rawList = widget.post['commentList'] as List?;
      if (rawList != null && rawList.isNotEmpty) {
        _comments.addAll(_normalizeCommentsList(rawList));
      }
    }

    // 3. For live Supabase posts, base offset is 0 so count matches DB 1:1
    if (postId.length > 20) {
      _baseCommentOffset = 0;
    } else {
      final int currentListItems =
          _CustomerFeedScreenState.countAllCommentsAndReplies(_comments);
      final int postMetaComments = (widget.post['comments'] as num?)?.toInt() ?? 0;
      if (prefs != null && prefs.containsKey(_baseKey(postId))) {
        _baseCommentOffset = prefs.getInt(_baseKey(postId)) ?? 0;
      } else {
        _baseCommentOffset = math.max(0, postMetaComments - currentListItems);
        prefs?.setInt(_baseKey(postId), _baseCommentOffset);
      }
    }

    if (mounted) {
      setState(() {});
      widget.post['comments'] = _totalCommentCount;
      widget.onCommentCountChanged?.call(_totalCommentCount, _comments);
    }

    // 4. For real backend posts (UUID > 20 chars), sync live from Supabase
    if (postId.length > 20) {
      _fetchLiveComments(postId);
    }
  }

  String _formatTimeAgo(String rawDate) {
    if (rawDate.isEmpty) return 'feed_comments.just_now'.tr();
    DateTime dt;
    if (!rawDate.endsWith('Z') && !rawDate.contains('+') && rawDate.contains('T')) {
      dt = DateTime.tryParse('${rawDate}Z')?.toLocal() ?? DateTime.now();
    } else {
      dt = DateTime.tryParse(rawDate)?.toLocal() ?? DateTime.now();
    }
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative || diff.inSeconds < 60) {
      return 'feed_comments.just_now'.tr();
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}j';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}h';
    } else {
      return '${dt.day}/${dt.month}';
    }
  }

  void _applySortOrder(List<Map<String, dynamic>> list) {
    if (_sortByTop) {
      list.sort((a, b) {
        final int likesB = (b['likes'] as num?)?.toInt() ?? 0;
        final int likesA = (a['likes'] as num?)?.toInt() ?? 0;
        if (likesB != likesA) return likesB.compareTo(likesA);
        final ca = a['createdAt']?.toString() ?? '';
        final cb = b['createdAt']?.toString() ?? '';
        return cb.compareTo(ca);
      });
    } else {
      list.sort((a, b) {
        final ca = a['createdAt']?.toString() ?? '';
        final cb = b['createdAt']?.toString() ?? '';
        return cb.compareTo(ca);
      });
    }
  }

  void _toggleSort() {
    HapticFeedback.selectionClick();
    setState(() {
      _sortByTop = !_sortByTop;
      _applySortOrder(_comments);
    });
  }

  Future<void> _fetchLiveComments(String postId, {bool silent = false}) async {
    if (_activeFetchPostId == postId && !silent) return;
    _activeFetchPostId = postId;
    if (_comments.isEmpty && !silent && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final dbRes = await Supabase.instance.client
          .from('feed_comments')
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: true)
          .limit(200);

      if (!mounted || _loadedPostId != postId) return;
      // Jangan timpa senarai jika pengguna sedang menghantar komen secara optimistik
      if (silent && _isSubmitting) return;

      final myUid = Supabase.instance.client.auth.currentUser?.id;
      final String shopName = widget.post['shopName']?.toString() ?? '';
      final String shopAvatar = widget.post['shopAvatar']?.toString() ?? '';
      final String ownerUserId = widget.post['ownerUserId']?.toString() ??
          (widget.post['shopData'] is Map
              ? widget.post['shopData']['owner_user_id']?.toString()
              : null) ??
          '';

      // Batch-fetch profil sebenar Ngam (`public.users`) untuk semua user_id komen
      // supaya semua peranti melihat nama & gambar profil Ngam terkini (bukan Google profile).
      final Set<String> userIds = {};
      for (final row in dbRes) {
        final uid = row['user_id']?.toString() ?? '';
        if (uid.length > 20) {
          userIds.add(uid);
        }
      }

      final Map<String, Map<String, String>> appProfilesByUid = {};
      if (userIds.isNotEmpty) {
        try {
          final usersRows = await Supabase.instance.client
              .from('users')
              .select('id, user_name, user_avatar_url')
              .inFilter('id', userIds.toList());
          for (final u in usersRows) {
            final uid = u['id']?.toString() ?? '';
            if (uid.isNotEmpty) {
              appProfilesByUid[uid] = {
                'name': u['user_name']?.toString().trim() ?? '',
                'avatar': u['user_avatar_url']?.toString().trim() ?? '',
              };
            }
          }
        } catch (e) {
          debugPrint('[FeedCommentsView] Users profile hydration note: $e');
        }
      }

      if (!mounted || _loadedPostId != postId) return;
      if (silent && _isSubmitting) return;

      final List<Map<String, dynamic>> topLevelDb = [];
      final Map<String, List<Map<String, dynamic>>> repliesByParent = {};

      // Regex menyokong [[REPLY:parentId|replyToUser]] dan [[REPLY:parentId|replyToUser|OWNER]] serta [[OWNER]]
      final replyRegex = RegExp(
        r'^\[\[REPLY:([^|\]]+)\|([^|\]]*)(?:\|([^\]]*))?\]\]\s*(.*)$',
        dotAll: true,
      );

      for (final row in dbRes) {
        final String rowId =
            row['id']?.toString() ?? 'db_${DateTime.now().microsecondsSinceEpoch}';
        final String rowUserId = row['user_id']?.toString() ?? '';
        final String createdAtRaw = row['created_at']?.toString() ?? '';
        String rawText = row['comment_text']?.toString() ?? '';

        bool hasOwnerTagInText = false;
        if (rawText.startsWith('[[OWNER]]')) {
          hasOwnerTagInText = true;
          rawText = rawText.replaceFirst(RegExp(r'^\[\[OWNER\]\]\s*'), '');
        }

        final match = replyRegex.firstMatch(rawText);
        if (match != null && (match.group(3)?.toUpperCase().contains('OWNER') ?? false)) {
          hasOwnerTagInText = true;
        }

        String userName = row['user_name']?.toString().trim() ?? '';
        String userAvatar = row['user_avatar']?.toString().trim() ?? '';

        final bool isRowByOwnerId =
            ownerUserId.isNotEmpty && rowUserId.isNotEmpty && rowUserId == ownerUserId;
        final bool isRowMatchingShopName = shopName.isNotEmpty &&
            userName.toLowerCase().trim() == shopName.toLowerCase().trim();
        final bool isCreator =
            hasOwnerTagInText || isRowByOwnerId || isRowMatchingShopName;
        final bool isOfficialBrandReply = hasOwnerTagInText || isRowMatchingShopName;

        // Jika bukan balasan rasmi jenama kedai, gunakan profil Ngam dari public.users
        if (!isOfficialBrandReply &&
            rowUserId.isNotEmpty &&
            appProfilesByUid.containsKey(rowUserId)) {
          final appProf = appProfilesByUid[rowUserId]!;
          if ((appProf['name'] ?? '').isNotEmpty) {
            userName = appProf['name']!;
          }
          userAvatar = appProf['avatar'] ?? '';
        }

        if (userName.isEmpty) {
          userName = isOfficialBrandReply && shopName.isNotEmpty
              ? shopName
              : 'feed_comments.default_customer'.tr();
        }
        if (isCreator && userAvatar.isEmpty && shopAvatar.isNotEmpty) {
          userAvatar = shopAvatar;
        }

        final String timeAgo = _formatTimeAgo(createdAtRaw);
        final int likes = (row['likes_count'] as num?)?.toInt() ?? 0;
        final bool isMine = myUid != null && rowUserId == myUid;
        final bool isLikedByMe = _likedCommentIds.contains(rowId);
        final bool likedByOwner = row['liked_by_owner'] == true;

        if (match != null) {
          final String parentId = match.group(1)!.trim();
          final String replyToUser = match.group(2)!.trim();
          String cleanText = match.group(4)!.trim();
          if (cleanText.startsWith('[[OWNER]]')) {
            cleanText = cleanText.replaceFirst(RegExp(r'^\[\[OWNER\]\]\s*'), '');
          }
          final parsed = _extractCommentTextAndImage(cleanText);
          repliesByParent.putIfAbsent(parentId, () => []).add({
            'id': rowId,
            'parentId': parentId,
            'userId': rowUserId,
            'user': userName,
            'replyToUser': replyToUser,
            'avatar': userAvatar,
            'text': parsed.text,
            'imageUrl': parsed.imageUrl,
            'time': timeAgo,
            'createdAt': createdAtRaw,
            'likes': isLikedByMe && likes == 0 ? 1 : likes,
            'isLiked': isLikedByMe,
            'isMyComment': isMine,
            'isCreator': isCreator,
            'likedByOwner': likedByOwner,
          });
        } else {
          final parsed = _extractCommentTextAndImage(rawText);
          topLevelDb.add({
            'id': rowId,
            'userId': rowUserId,
            'user': userName,
            'avatar': userAvatar,
            'text': parsed.text,
            'imageUrl': parsed.imageUrl,
            'time': timeAgo,
            'createdAt': createdAtRaw,
            'likes': isLikedByMe && likes == 0 ? 1 : likes,
            'isLiked': isLikedByMe,
            'isMyComment': isMine,
            'isCreator': isCreator,
            'likedByOwner': likedByOwner,
            'replies': <Map<String, dynamic>>[],
          });
        }
      }

      // Attach DB replies to their parent comments
      for (final c in topLevelDb) {
        final cid = c['id'].toString();
        if (repliesByParent.containsKey(cid)) {
          final rList = repliesByParent[cid]!;
          c['replies'] = rList;
          _expandedCommentIds.add(cid);
        }
      }

      // Handle any orphan replies whose parentId wasn't matched so no comment is ever invisible
      final matchedParentIds = topLevelDb.map((c) => c['id'].toString()).toSet();
      for (final entry in repliesByParent.entries) {
        if (!matchedParentIds.contains(entry.key)) {
          for (final orphan in entry.value) {
            topLevelDb.add({
              ...orphan,
              'replies': <Map<String, dynamic>>[],
            });
          }
        }
      }

      final List<Map<String, dynamic>> orderedTopLevel = topLevelDb.reversed.toList();
      if (_sortByTop) {
        _applySortOrder(orderedTopLevel);
      }

      setState(() {
        _baseCommentOffset = 0;
        _comments
          ..clear()
          ..addAll(orderedTopLevel);
        _isLoading = false;
      });

      await _persistAndNotifyCount(postId);
    } catch (e) {
      debugPrint('[FeedCommentsView] Supabase fetch error: $e');
      if (mounted && _loadedPostId == postId) setState(() => _isLoading = false);
    } finally {
      if (_activeFetchPostId == postId) {
        _activeFetchPostId = null;
      }
    }
  }

  void _insertQuickEmoji(String emoji) {
    HapticFeedback.selectionClick();
    final text = _commentController.text;
    final selection = _commentController.selection;
    final newText = selection.isValid && selection.start >= 0
        ? text.replaceRange(selection.start, selection.end, emoji)
        : '$text$emoji';
    _commentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (selection.isValid && selection.start >= 0
                ? selection.start
                : text.length) +
            emoji.length,
      ),
    );
    _commentFocusNode.requestFocus();
  }

  void _insertMention() {
    if (!_isSignedIn) {
      showGlassToast(context, 'feed_comments.login_required'.tr(), isError: true);
      return;
    }
    _insertQuickEmoji('@');
  }

  Future<void> _pickCommentImage() async {
    if (!_isSignedIn) {
      showGlassToast(context, 'feed_comments.login_required'.tr(), isError: true);
      return;
    }
    try {
      final XFile? picked = await _commentImagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1440,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty || !mounted) return;
      setState(() {
        _pendingImageBytes = bytes;
        _pendingImageName = picked.name;
      });
    } catch (e) {
      debugPrint('[FeedCommentsView] Image picker error: $e');
    }
  }

  void _clearPendingImage() {
    setState(() {
      _pendingImageBytes = null;
      _pendingImageName = null;
    });
  }

  void _openCommentImageViewer(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.94),
      builder: (dlgCtx) => Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00E5FF),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(dlgCtx).top + 12,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(dlgCtx),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _isSignedIn => Supabase.instance.client.auth.currentUser != null;

  void _handleSendComment() async {
    if (!_isSignedIn) {
      showGlassToast(context, 'feed_comments.login_required'.tr(), isError: true);
      return;
    }
    final text = _commentController.text.trim();
    final Uint8List? imageBytesToUpload = _pendingImageBytes;
    final String imageNameToUpload =
        _pendingImageName ?? 'comment_${DateTime.now().millisecondsSinceEpoch}.jpg';

    if ((text.isEmpty && imageBytesToUpload == null) || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      if (imageBytesToUpload != null) _isUploadingImage = true;
    });
    HapticFeedback.lightImpact();

    String uploadedImageUrl = '';
    if (imageBytesToUpload != null) {
      try {
        final String ext = imageNameToUpload.toLowerCase();
        final String mime = ext.endsWith('.png')
            ? 'image/png'
            : (ext.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
        uploadedImageUrl = await R2StorageService().uploadMedia(
          bytes: imageBytesToUpload,
          fileName: imageNameToUpload,
          folder: 'feed_comments',
          mimeType: mime,
        );
      } catch (e) {
        debugPrint('[FeedCommentsView] Image upload failed: $e');
        if (mounted) {
          setState(() {
            _isSubmitting = false;
            _isUploadingImage = false;
          });
          showGlassToast(
            context,
            'feed_comments.image_upload_failed'.tr(),
            isError: true,
          );
        }
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isUploadingImage = false);

    final currentUser = Supabase.instance.client.auth.currentUser;
    final identity = _getActiveCommenterIdentity();
    final String userName = identity.name;
    final String userAvatar = identity.avatar;
    final bool isCreator = identity.isOwner;

    final String postId = widget.post['id']?.toString() ?? '';
    final String? targetParentId = _replyingToCommentId;
    final String? targetReplyUser = _replyingToUser;
    final bool isReply = targetParentId != null && targetParentId.isNotEmpty;

    final String bodyWithImage = _encodeCommentTextWithImage(text, uploadedImageUrl);
    String dbCommentPayloadText = isCreator ? '[[OWNER]] $bodyWithImage' : bodyWithImage;
    final String tempId = isReply
        ? 'rp_${DateTime.now().millisecondsSinceEpoch}'
        : 'cm_${DateTime.now().millisecondsSinceEpoch}';

    if (isReply) {
      final int parentIdx =
          _comments.indexWhere((c) => c['id']?.toString() == targetParentId);

      final Map<String, dynamic> newReply = {
        'id': tempId,
        'parentId': targetParentId,
        'userId': currentUser?.id ?? '',
        'user': userName,
        'replyToUser': targetReplyUser ?? '',
        'avatar': userAvatar,
        'text': text,
        'imageUrl': uploadedImageUrl,
        'time': 'feed_comments.just_now'.tr(),
        'likes': 0,
        'isLiked': false,
        'isMyComment': true,
        'isCreator': isCreator,
        'createdAt': DateTime.now().toIso8601String(),
      };

      setState(() {
        if (parentIdx != -1) {
          final List<Map<String, dynamic>> currentReplies =
              List<Map<String, dynamic>>.from(
                  _comments[parentIdx]['replies'] as List? ?? []);
          currentReplies.add(newReply);
          _comments[parentIdx]['replies'] = currentReplies;
          _expandedCommentIds.add(targetParentId);
        } else {
          _comments.insert(0, {
            ...newReply,
            'replies': <Map<String, dynamic>>[],
          });
        }
        _replyingToCommentId = null;
        _replyingToUser = null;
        _pendingImageBytes = null;
        _pendingImageName = null;
        _showEmojiStrip = false;
      });

      final String ownerFlag = isCreator ? '|OWNER' : '';
      dbCommentPayloadText =
          '[[REPLY:$targetParentId|${targetReplyUser ?? ""}$ownerFlag]] $bodyWithImage';
    } else {
      final Map<String, dynamic> newEntry = {
        'id': tempId,
        'userId': currentUser?.id ?? '',
        'user': userName,
        'avatar': userAvatar,
        'text': text,
        'imageUrl': uploadedImageUrl,
        'time': 'feed_comments.just_now'.tr(),
        'likes': 0,
        'isLiked': false,
        'isMyComment': true,
        'isCreator': isCreator,
        'createdAt': DateTime.now().toIso8601String(),
        'replies': <Map<String, dynamic>>[],
      };

      setState(() {
        _comments.insert(0, newEntry);
        _replyingToCommentId = null;
        _replyingToUser = null;
        _pendingImageBytes = null;
        _pendingImageName = null;
        _showEmojiStrip = false;
      });

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    }

    _commentController.clear();
    await _persistAndNotifyCount(postId);

    // Simpan ke Supabase dan kemas kini ID tempatan dengan UUID sebenar supaya balasan (reply) merentas semua peranti 100% tepat
    bool dbInsertSucceeded = true;
    if (postId.length > 20) {
      try {
        final inserted = await Supabase.instance.client
            .from('feed_comments')
            .insert({
              'post_id': postId,
              'user_id': currentUser?.id,
              'user_name': userName,
              'user_avatar': userAvatar,
              'comment_text': dbCommentPayloadText,
            })
            .select()
            .single();

        final String realUuid = inserted['id']?.toString() ?? '';
        if (realUuid.isNotEmpty && mounted) {
          setState(() {
            if (!isReply) {
              final idx = _comments.indexWhere((c) => c['id'] == tempId);
              if (idx != -1) {
                _comments[idx]['id'] = realUuid;
              }
            } else {
              for (final c in _comments) {
                final replies = c['replies'] as List?;
                if (replies != null) {
                  for (final r in replies) {
                    if (r is Map && r['id'] == tempId) {
                      r['id'] = realUuid;
                    }
                  }
                }
              }
            }
          });
          await _persistAndNotifyCount(postId);
        }
      } catch (err) {
        dbInsertSucceeded = false;
        debugPrint('[FeedCommentsView] Supabase insert failed: $err');
        // Rollback komen optimistik supaya tidak hilang secara tiba-tiba selepas 8 saat
        if (mounted) {
          setState(() {
            if (!isReply) {
              _comments.removeWhere((c) => c['id'] == tempId);
            } else {
              for (final c in _comments) {
                final replies = c['replies'];
                if (replies is List) {
                  replies.removeWhere((r) => r is Map && r['id'] == tempId);
                }
              }
              _comments.removeWhere((c) => c['id'] == tempId);
            }
            if (text.isNotEmpty && _commentController.text.isEmpty) {
              _commentController.text = text;
            }
          });
          await _persistAndNotifyCount(postId);
        }
      }
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (dbInsertSucceeded) {
        showGlassToast(
          context,
          isReply ? 'feed_comments.reply_sent'.tr() : 'feed_comments.comment_sent'.tr(),
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        );
      } else {
        showGlassToast(
          context,
          'feed_comments.send_failed'.tr(),
          isError: true,
        );
      }
    }
  }

  void _handleDeleteComment(int index) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF141424) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'feed_comments.delete_comment_title'.tr(),
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'feed_comments.delete_comment_confirm'.tr(),
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF475569),
            fontSize: 13.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: Text(
              'feed_comments.cancel_btn'.tr(),
              style: TextStyle(
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: Text(
              'feed_comments.delete_btn'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    HapticFeedback.mediumImpact();
    final removed = _comments.removeAt(index);
    final String postId = widget.post['id']?.toString() ?? '';
    setState(() {});

    await _persistAndNotifyCount(postId);

    bool dbDeleted = true;
    final commentId = removed['id']?.toString();
    if (commentId != null &&
        !commentId.startsWith('cm_') &&
        !commentId.startsWith('demo_') &&
        postId.length > 20) {
      try {
        try {
          await Supabase.instance.client.rpc(
            'delete_feed_comment_cascade',
            params: {'p_comment_id': commentId},
          );
        } catch (_) {
          await Supabase.instance.client
              .from('feed_comments')
              .delete()
              .eq('id', commentId);
        }
      } catch (e) {
        dbDeleted = false;
        debugPrint('[FeedCommentsView] Supabase delete error: $e');
        if (mounted) {
          setState(() {
            _comments.insert(math.min(index, _comments.length), removed);
          });
          await _persistAndNotifyCount(postId);
        }
      }
    }

    if (mounted) {
      showGlassToast(
        context,
        dbDeleted
            ? 'feed_comments.comment_deleted'.tr()
            : 'feed_comments.delete_failed'.tr(),
        isError: !dbDeleted,
        icon: dbDeleted ? HugeIcons.strokeRoundedDelete02 : null,
      );
    }
  }

  void _handleDeleteReply(int parentIndex, int replyIndex) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF141424) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'feed_comments.delete_reply_title'.tr(),
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'feed_comments.delete_reply_confirm'.tr(),
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF475569),
            fontSize: 13.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: Text(
              'feed_comments.cancel_btn'.tr(),
              style: TextStyle(
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: Text(
              'feed_comments.delete_btn'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    HapticFeedback.mediumImpact();
    final parent = _comments[parentIndex];
    final List<Map<String, dynamic>> replies =
        List<Map<String, dynamic>>.from(parent['replies'] as List? ?? []);
    if (replyIndex < 0 || replyIndex >= replies.length) return;

    final removedReply = replies.removeAt(replyIndex);
    parent['replies'] = replies;
    final String postId = widget.post['id']?.toString() ?? '';
    setState(() {});

    await _persistAndNotifyCount(postId);

    bool dbDeleted = true;
    final replyId = removedReply['id']?.toString();
    if (replyId != null &&
        !replyId.startsWith('rp_') &&
        !replyId.startsWith('demo_') &&
        postId.length > 20) {
      try {
        try {
          await Supabase.instance.client.rpc(
            'delete_feed_comment_cascade',
            params: {'p_comment_id': replyId},
          );
        } catch (_) {
          await Supabase.instance.client
              .from('feed_comments')
              .delete()
              .eq('id', replyId);
        }
      } catch (e) {
        dbDeleted = false;
        debugPrint('[FeedCommentsView] Supabase delete reply error: $e');
        if (mounted) {
          setState(() {
            replies.insert(math.min(replyIndex, replies.length), removedReply);
            parent['replies'] = replies;
          });
          await _persistAndNotifyCount(postId);
        }
      }
    }

    if (mounted) {
      showGlassToast(
        context,
        dbDeleted
            ? 'feed_comments.reply_deleted'.tr()
            : 'feed_comments.delete_failed'.tr(),
        isError: !dbDeleted,
        icon: dbDeleted ? HugeIcons.strokeRoundedDelete02 : null,
      );
    }
  }

  void _handleReply({
    required String parentCommentId,
    required String targetUser,
  }) {
    if (!_isSignedIn) {
      showGlassToast(context, 'feed_comments.login_required'.tr(), isError: true);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _replyingToCommentId = parentCommentId;
      _replyingToUser = targetUser;
      _expandedCommentIds.add(parentCommentId);
    });
    _commentFocusNode.requestFocus();
  }

  Future<void> _persistCommentLike(
    String commentId,
    bool nowLiked,
    int newLikes, {
    bool isOwner = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (nowLiked) {
        _likedCommentIds.add(commentId);
      } else {
        _likedCommentIds.remove(commentId);
      }
      await prefs.setStringList('ngam_liked_feed_comments', _likedCommentIds.toList());
    } catch (_) {}

    if (commentId.length > 20 &&
        !commentId.startsWith('cm_') &&
        !commentId.startsWith('rp_')) {
      try {
        await Supabase.instance.client.rpc(
          'toggle_feed_comment_like',
          params: {
            'p_comment_id': commentId,
            'p_delta': nowLiked ? 1 : -1,
            'p_is_owner': isOwner,
          },
        );
      } catch (_) {
        try {
          await Supabase.instance.client
              .from('feed_comments')
              .update({'likes_count': newLikes})
              .eq('id', commentId);
        } catch (e) {
          debugPrint('[FeedCommentsView] Like sync error: $e');
        }
      }
    }
  }

  void _toggleLikeComment(int index) async {
    if (!_isSignedIn) {
      showGlassToast(context, 'feed_comments.login_required'.tr(), isError: true);
      return;
    }
    HapticFeedback.lightImpact();
    final c = _comments[index];
    final String cid = c['id']?.toString() ?? '';
    final bool isCommentLiked = c['isLiked'] == true;
    final int commentLikes = (c['likes'] as num?)?.toInt() ?? 0;
    final bool nowLiked = !isCommentLiked;
    final int newLikes = nowLiked ? commentLikes + 1 : math.max(0, commentLikes - 1);

    setState(() {
      c['isLiked'] = nowLiked;
      c['likes'] = newLikes;
      if (_isCurrentUserStoreOwner) {
        c['likedByOwner'] = nowLiked;
      }
    });

    if (cid.isNotEmpty) {
      await _persistCommentLike(
        cid,
        nowLiked,
        newLikes,
        isOwner: _isCurrentUserStoreOwner,
      );
    }
    final String postId = widget.post['id']?.toString() ?? '';
    await _persistAndNotifyCount(postId);
  }

  void _toggleLikeReply(int parentIndex, int replyIndex) async {
    if (!_isSignedIn) {
      showGlassToast(context, 'feed_comments.login_required'.tr(), isError: true);
      return;
    }
    HapticFeedback.lightImpact();
    final parent = _comments[parentIndex];
    final List<Map<String, dynamic>> replies =
        List<Map<String, dynamic>>.from(parent['replies'] as List? ?? []);
    if (replyIndex < 0 || replyIndex >= replies.length) return;

    final r = replies[replyIndex];
    final String rid = r['id']?.toString() ?? '';
    final bool isLiked = r['isLiked'] == true;
    final int likes = (r['likes'] as num?)?.toInt() ?? 0;
    final bool nowLiked = !isLiked;
    final int newLikes = nowLiked ? likes + 1 : math.max(0, likes - 1);

    setState(() {
      r['isLiked'] = nowLiked;
      r['likes'] = newLikes;
      if (_isCurrentUserStoreOwner) {
        r['likedByOwner'] = nowLiked;
      }
      parent['replies'] = replies;
    });

    if (rid.isNotEmpty) {
      await _persistCommentLike(
        rid,
        nowLiked,
        newLikes,
        isOwner: _isCurrentUserStoreOwner,
      );
    }
    final String postId = widget.post['id']?.toString() ?? '';
    await _persistAndNotifyCount(postId);
  }

  Widget _buildBadgePill({
    required String text,
    required Color color,
    required Color bgColor,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNestedReplyItem({
    required Map<String, dynamic> reply,
    required String parentCommentId,
    required int parentIndex,
    required int replyIndex,
    required String currentUserName,
    required String shopName,
    required bool isDark,
  }) {
    final String replyUser =
        reply['user']?.toString() ?? 'feed_comments.default_customer'.tr();
    final String replyToUser = reply['replyToUser']?.toString() ?? '';
    final String replyText = reply['text']?.toString() ?? '';
    final String replyImageUrl = reply['imageUrl']?.toString() ?? '';
    final bool isReplyLiked = reply['isLiked'] == true;
    final int replyLikes = (reply['likes'] as num?)?.toInt() ?? 0;
    final bool isMyReply = _isSignedIn &&
        (reply['isMyComment'] == true || replyUser == currentUserName);
    final bool isCreator = reply['isCreator'] == true ||
        (shopName.isNotEmpty &&
            replyUser.toLowerCase().trim() == shopName.toLowerCase().trim());

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFeedAvatar(
            name: replyUser,
            size: 26,
            imageUrl: reply['avatar']?.toString(),
            borderColor: isCreator
                ? const Color(0xFF00E5FF)
                : (isDark ? Colors.white12 : Colors.black12),
            borderWidth: isCreator ? 1.4 : 1.0,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TikTok Reply Header: Username · Creator ▸ TargetUser
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      replyUser,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.72)
                            : const Color(0xFF475569),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isCreator) ...[
                      Text(
                        ' · ',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'feed_comments.badge_creator'.tr(),
                        style: const TextStyle(
                          color: Color(0xFF22D3EE),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (isMyReply)
                      _buildBadgePill(
                        text: 'feed_comments.badge_you'.tr(),
                        color: const Color(0xFF00E5FF),
                        bgColor: const Color(0xFF00E5FF).withValues(alpha: 0.14),
                      ),
                    if (replyToUser.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 13,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
                      ),
                      Text(
                        replyToUser,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : const Color(0xFF475569),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                if (replyText.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    replyText,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
                if (replyImageUrl.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _openCommentImageViewer(replyImageUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 132, maxHeight: 144),
                        child: CachedNetworkImage(
                          imageUrl: replyImageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 110,
                            height: 110,
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 110,
                            height: 80,
                            color: isDark ? Colors.white10 : Colors.black12,
                            child: const Icon(Icons.broken_image_outlined, size: 22),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                // TikTok Inline Meta & Action Row: Time · Reply · [Delete]      ♡ count   ↪
                Row(
                  children: [
                    Text(
                      reply['time']?.toString() ?? 'feed_comments.just_now'.tr(),
                      style: TextStyle(
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _handleReply(
                        parentCommentId: parentCommentId,
                        targetUser: replyUser,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          'feed_comments.reply_btn'.tr(),
                          style: TextStyle(
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (isMyReply || _isCurrentUserStoreOwner) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _handleDeleteReply(parentIndex, replyIndex),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            'feed_comments.delete_btn'.tr(),
                            style: TextStyle(
                              color: Colors.redAccent.withValues(alpha: 0.85),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _toggleLikeReply(parentIndex, replyIndex),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isReplyLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 16,
                              color: isReplyLiked
                                  ? const Color(0xFFFE2C55)
                                  : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                            ),
                            if (replyLikes > 0 || isReplyLiked) ...[
                              const SizedBox(width: 4),
                              Text(
                                '$replyLikes',
                                style: TextStyle(
                                  color: isReplyLiked
                                      ? const Color(0xFFFE2C55)
                                      : (isDark
                                          ? Colors.white54
                                          : const Color(0xFF64748B)),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _handleReply(
                        parentCommentId: parentCommentId,
                        targetUser: replyUser,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.rotationY(math.pi),
                          child: Icon(
                            Icons.reply_rounded,
                            size: 17,
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final shopName = widget.post['shopName']?.toString() ?? 'Ngam Feed';
    final shopHandle = widget.post['shopHandle']?.toString() ?? '';
    final shopAvatar = widget.post['shopAvatar']?.toString() ?? '';
    final caption = widget.post['caption']?.toString() ??
        widget.post['title']?.toString() ??
        '';

    final identity = _getActiveCommenterIdentity();
    final String currentUserName = identity.name;
    final String currentUserAvatar = identity.avatar;
    final bool isOwner = identity.isOwner;
    final bool canSend =
        (_hasInputText || _pendingImageBytes != null) && !_isSubmitting;

    return Column(
      children: [
        // 1. Mobile Drag Handle (Only on bottom sheet)
        if (!widget.isDesktop)
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 2),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

        // 2. Creator Info Snippet (Desktop signature header)
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
                          const Icon(Icons.verified_rounded,
                              size: 14, color: Color(0xFF00E5FF)),
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
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCancel01,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        size: 17,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

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

        if (widget.isDesktop)
          Divider(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
            height: 1,
          ),

        // 3. TikTok Centered Comments Header ("8 comments ≡") + Right Close X
        Padding(
          padding: EdgeInsets.fromLTRB(
            14,
            widget.isDesktop ? 10 : 6,
            12,
            10,
          ),
          child: SizedBox(
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleSort,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'feed_comments.count_label'.tr(
                          args: [_totalCommentCount.toString()],
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: _sortByTop
                            ? 'feed_comments.sort_top'.tr()
                            : 'feed_comments.sort_newest'.tr(),
                        child: Icon(
                          Icons.filter_list_rounded,
                          size: 17,
                          color: _sortByTop
                              ? const Color(0xFF00E5FF)
                              : (isDark ? Colors.white70 : const Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.isDesktop)
                  Positioned(
                    right: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onClose,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : Colors.black.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                          size: 17,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 4. Comments & Nested Replies List
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
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
                                  color: isDark
                                      ? Colors.white38
                                      : const Color(0xFF94A3B8),
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'feed_comments.empty_title'.tr(),
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF1E293B),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'feed_comments.empty_subtitle'.tr(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white38
                                    : const Color(0xFF94A3B8),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                      itemCount: _comments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (_, idx) {
                        final c = _comments[idx];
                        final String commentId =
                            c['id']?.toString() ?? 'cm_$idx';
                        final bool isCommentLiked = c['isLiked'] == true;
                        final int commentLikes =
                            (c['likes'] as num?)?.toInt() ?? 0;
                        final String commentText = c['text']?.toString() ?? '';
                        final String commentImageUrl =
                            c['imageUrl']?.toString() ?? '';
                        final String commentUser = c['user']?.toString() ??
                            'feed_comments.default_customer'.tr();
                        final bool isMyComment = _isSignedIn &&
                            (c['isMyComment'] == true ||
                                commentUser == currentUserName);
                        final bool isCreator = c['isCreator'] == true ||
                            (shopName.isNotEmpty &&
                                commentUser.toLowerCase().trim() ==
                                    shopName.toLowerCase().trim());

                        final List<Map<String, dynamic>> replies =
                            (c['replies'] as List?)
                                    ?.map((e) =>
                                        Map<String, dynamic>.from(e as Map))
                                    .toList() ??
                                [];
                        final bool hasOwnerReply =
                            replies.any((r) => r['isCreator'] == true);
                        final bool isLikedByOwner =
                            c['likedByOwner'] == true || hasOwnerReply;
                        final bool isExpanded =
                            _expandedCommentIds.contains(commentId);
                        final bool isBeingRepliedTo =
                            _replyingToCommentId == commentId;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: isBeingRepliedTo
                              ? const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6)
                              : EdgeInsets.zero,
                          decoration: BoxDecoration(
                            color: isBeingRepliedTo
                                ? const Color(0xFF00E5FF)
                                    .withValues(alpha: 0.06)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Parent Comment Row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFeedAvatar(
                                    name: commentUser,
                                    size: 36,
                                    imageUrl: c['avatar']?.toString(),
                                    borderColor: isCreator
                                        ? const Color(0xFF00E5FF)
                                        : (isDark
                                            ? Colors.white12
                                            : Colors.black12),
                                    borderWidth: isCreator ? 1.4 : 1.0,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              commentUser,
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white
                                                        .withValues(alpha: 0.72)
                                                    : const Color(0xFF475569),
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (isCreator) ...[
                                              Text(
                                                ' · ',
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.white38
                                                      : Colors.black38,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                'feed_comments.badge_creator'
                                                    .tr(),
                                                style: const TextStyle(
                                                  color: Color(0xFF22D3EE),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                            if (isMyComment)
                                              _buildBadgePill(
                                                text: 'feed_comments.badge_you'
                                                    .tr(),
                                                color: const Color(0xFF00E5FF),
                                                bgColor: const Color(0xFF00E5FF)
                                                    .withValues(alpha: 0.14),
                                              ),
                                          ],
                                        ),
                                        if (commentText.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            commentText,
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(0xFF0F172A),
                                              fontSize: 13.5,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                        if (commentImageUrl.isNotEmpty) ...[
                                          const SizedBox(height: 7),
                                          GestureDetector(
                                            onTap: () =>
                                                _openCommentImageViewer(
                                                    commentImageUrl),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                  maxWidth: 148,
                                                  maxHeight: 162,
                                                ),
                                                child: CachedNetworkImage(
                                                  imageUrl: commentImageUrl,
                                                  fit: BoxFit.cover,
                                                  placeholder: (_, __) =>
                                                      Container(
                                                    width: 120,
                                                    height: 120,
                                                    color: isDark
                                                        ? Colors.white10
                                                        : Colors.black12,
                                                  ),
                                                  errorWidget: (_, __, ___) =>
                                                      Container(
                                                    width: 120,
                                                    height: 88,
                                                    color: isDark
                                                        ? Colors.white10
                                                        : Colors.black12,
                                                    child: const Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                      size: 24,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (isLikedByOwner && !isCreator) ...[
                                          const SizedBox(height: 5),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFE2C55)
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'feed_comments.liked_by_owner'
                                                  .tr(),
                                              style: const TextStyle(
                                                color: Color(0xFFFE2C55),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        // TikTok Meta & Action Row: Time   Reply   [Delete]      ♡ count   ↪
                                        Row(
                                          children: [
                                            Text(
                                              c['time']?.toString() ??
                                                  'feed_comments.just_now'.tr(),
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white38
                                                    : const Color(0xFF94A3B8),
                                                fontSize: 11.5,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () => _handleReply(
                                                parentCommentId: commentId,
                                                targetUser: commentUser,
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 2),
                                                child: Text(
                                                  'feed_comments.reply_btn'
                                                      .tr(),
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? Colors.white54
                                                        : const Color(
                                                            0xFF64748B),
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (isMyComment ||
                                                _isCurrentUserStoreOwner) ...[
                                              const SizedBox(width: 16),
                                              GestureDetector(
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                onTap: () =>
                                                    _handleDeleteComment(idx),
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 2),
                                                  child: Text(
                                                    'feed_comments.delete_btn'
                                                        .tr(),
                                                    style: TextStyle(
                                                      color: Colors.redAccent
                                                          .withValues(
                                                              alpha: 0.85),
                                                      fontSize: 11.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                            const Spacer(),
                                            GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () =>
                                                  _toggleLikeComment(idx),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 2),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isCommentLiked
                                                          ? Icons
                                                              .favorite_rounded
                                                          : Icons
                                                              .favorite_border_rounded,
                                                      size: 16.5,
                                                      color: isCommentLiked
                                                          ? const Color(
                                                              0xFFFE2C55)
                                                          : (isDark
                                                              ? Colors.white54
                                                              : const Color(
                                                                  0xFF64748B)),
                                                    ),
                                                    if (commentLikes > 0 ||
                                                        isCommentLiked) ...[
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '$commentLikes',
                                                        style: TextStyle(
                                                          color: isCommentLiked
                                                              ? const Color(
                                                                  0xFFFE2C55)
                                                              : (isDark
                                                                  ? Colors
                                                                      .white54
                                                                  : const Color(
                                                                      0xFF64748B)),
                                                          fontSize: 11.5,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onTap: () => _handleReply(
                                                parentCommentId: commentId,
                                                targetUser: commentUser,
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 2,
                                                        vertical: 2),
                                                child: Transform(
                                                  alignment: Alignment.center,
                                                  transform:
                                                      Matrix4.rotationY(math.pi),
                                                  child: Icon(
                                                    Icons.reply_rounded,
                                                    size: 17.5,
                                                    color: isDark
                                                        ? Colors.white54
                                                        : const Color(
                                                            0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              // Nested Replies Section directly underneath parent comment
                              if (replies.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 46),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (isExpanded)
                                        Container(
                                          padding:
                                              const EdgeInsets.only(left: 10),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              left: BorderSide(
                                                color: isDark
                                                    ? Colors.white
                                                        .withValues(alpha: 0.12)
                                                    : Colors.black
                                                        .withValues(alpha: 0.10),
                                                width: 1.3,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: List.generate(
                                              replies.length,
                                              (rIdx) => _buildNestedReplyItem(
                                                reply: replies[rIdx],
                                                parentCommentId: commentId,
                                                parentIndex: idx,
                                                replyIndex: rIdx,
                                                currentUserName:
                                                    currentUserName,
                                                shopName: shopName,
                                                isDark: isDark,
                                              ),
                                            ),
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            setState(() {
                                              if (isExpanded) {
                                                _expandedCommentIds
                                                    .remove(commentId);
                                              } else {
                                                _expandedCommentIds
                                                    .add(commentId);
                                              }
                                            });
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 22,
                                                height: 1.2,
                                                color: isDark
                                                    ? Colors.white24
                                                    : Colors.black26,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                isExpanded
                                                    ? 'feed_comments.hide_replies'
                                                        .tr()
                                                    : 'feed_comments.view_replies'
                                                        .tr(args: [
                                                        replies.length
                                                            .toString()
                                                      ]),
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.white54
                                                      : const Color(0xFF64748B),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(width: 2),
                                              Icon(
                                                isExpanded
                                                    ? Icons
                                                        .keyboard_arrow_up_rounded
                                                    : Icons
                                                        .keyboard_arrow_down_rounded,
                                                size: 16,
                                                color: isDark
                                                    ? Colors.white54
                                                    : const Color(0xFF64748B),
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
                        );
                      },
                    ),
        ),

        // 5. Sticky Bottom Input Field (TikTok Clean Pill + Photo/Emoji/@ Icons)
        Container(
          padding: EdgeInsets.fromLTRB(
            14,
            10,
            14,
            widget.isDesktop ? 14 : (10 + MediaQuery.of(context).padding.bottom),
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF16161B) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.07),
              ),
            ),
          ),
          child: !_isSignedIn
              ? Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.35),
                        ),
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedLockPassword,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'feed_comments.sign_in_to_comment'.tr(),
                        style: TextStyle(
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (!widget.isDesktop) {
                            Navigator.pop(context);
                          }
                          Navigator.of(context).pushNamed('/login');
                        },
                        borderRadius: BorderRadius.circular(100),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00E5FF), Color(0xFF0284C7)],
                            ),
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            'feed_comments.sign_in_btn'.tr(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Collapsible Quick Emoji Bar (opened via Emoji icon in pill)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: _showEmojiStrip
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: _quickEmojis
                                    .map(
                                      (emoji) => GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => _insertQuickEmoji(emoji),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          child: Text(
                                            emoji,
                                            style: const TextStyle(fontSize: 20),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    // Reply indicator badge
                    if (_replyingToUser != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.subdirectory_arrow_right_rounded,
                              size: 14,
                              color: Color(0xFF00E5FF),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'feed_comments.replying_to'.tr(),
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF64748B),
                                fontSize: 11.5,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                '@$_replyingToUser',
                                style: const TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() {
                                  _replyingToCommentId = null;
                                  _replyingToUser = null;
                                });
                              },
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Pending Photo Attachment Thumbnail Preview
                    if (_pendingImageBytes != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.memory(
                                    _pendingImageBytes!,
                                    width: 58,
                                    height: 58,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                if (_isUploadingImage)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF00E5FF),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: -6,
                                  right: -6,
                                  child: GestureDetector(
                                    onTap: _clearPendingImage,
                                    child: Tooltip(
                                      message: 'feed_comments.remove_image'.tr(),
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: Colors.black87,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.white,
                                          size: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_isUploadingImage) ...[
                              const SizedBox(width: 10),
                              Text(
                                'feed_comments.uploading_image'.tr(),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF475569),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                    // TikTok Bottom Input Row: Avatar | Transparent Pill [Add comment... 🖼 😊 @] | [Send]
                    Row(
                      children: [
                        _buildFeedAvatar(
                          name: currentUserName,
                          size: 34,
                          imageUrl: currentUserAvatar,
                          borderColor: isOwner
                              ? const Color(0xFF00E5FF)
                              : (isDark ? Colors.white12 : Colors.black12),
                          borderWidth: isOwner ? 1.4 : 1.0,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.09)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.only(left: 14, right: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _commentController,
                                    focusNode: _commentFocusNode,
                                    textInputAction: TextInputAction.send,
                                    keyboardType: TextInputType.text,
                                    onSubmitted: (_) => _handleSendComment(),
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                      fontSize: 13.5,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: _replyingToUser != null
                                          ? 'feed_comments.reply_hint'
                                              .tr(args: [_replyingToUser!])
                                          : (isOwner
                                              ? 'feed_comments.reply_as_owner_hint'
                                                  .tr(args: [shopName])
                                              : 'feed_comments.add_comment_hint'
                                                  .tr()),
                                      hintStyle: TextStyle(
                                        color: isDark
                                            ? Colors.white54
                                            : const Color(0xFF64748B),
                                        fontSize: 13.5,
                                      ),
                                      filled: false,
                                      fillColor: Colors.transparent,
                                      isDense: true,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 10),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _pickCommentImage,
                                  tooltip:
                                      'feed_comments.attach_photo_tooltip'.tr(),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 36,
                                  ),
                                  icon: Icon(
                                    Icons.image_outlined,
                                    size: 20,
                                    color: _pendingImageBytes != null
                                        ? const Color(0xFF00E5FF)
                                        : (isDark
                                            ? Colors.white70
                                            : const Color(0xFF475569)),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    setState(() =>
                                        _showEmojiStrip = !_showEmojiStrip);
                                  },
                                  tooltip: 'feed_comments.emoji_tooltip'.tr(),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 36,
                                  ),
                                  icon: Icon(
                                    _showEmojiStrip
                                        ? Icons.keyboard_alt_outlined
                                        : Icons.sentiment_satisfied_alt_outlined,
                                    size: 20,
                                    color: _showEmojiStrip
                                        ? const Color(0xFF00E5FF)
                                        : (isDark
                                            ? Colors.white70
                                            : const Color(0xFF475569)),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _insertMention,
                                  tooltip:
                                      'feed_comments.mention_tooltip'.tr(),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 30,
                                    minHeight: 36,
                                  ),
                                  icon: Icon(
                                    Icons.alternate_email_rounded,
                                    size: 19.5,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_hasInputText ||
                            _pendingImageBytes != null ||
                            _isSubmitting) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: canSend ? _handleSendComment : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFFE2C55),
                                    Color(0xFFE11D48),
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 15,
                                        height: 15,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.arrow_upward_rounded,
                                        color: Colors.white,
                                        size: 19,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ],
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
  final bool isInsideCarousel;
  final Widget? bottomContent;
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
    this.isInsideCarousel = false,
    this.bottomContent,
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
  double _dragStartX = 0.0;
  double _dragStartRatio = 0.0;
  bool _showPlayIndicator = false;
  Timer? _playIndicatorTimer;

  void _onRegionScrubStart(double globalX, double currentRatio) {
    HapticFeedback.selectionClick();
    _dragStartX = globalX;
    _dragStartRatio = currentRatio;
    setState(() {
      _isScrubbing = true;
      _scrubRatio = currentRatio;
    });
  }

  void _onRegionScrubUpdate(double globalX, double barWidth) {
    if (!_isScrubbing) return;
    final double deltaX = globalX - _dragStartX;
    final double deltaRatio = deltaX / (barWidth * 0.85);
    final double newRatio = (_dragStartRatio + deltaRatio).clamp(0.0, 1.0);
    setState(() {
      _scrubRatio = newRatio;
    });
  }

  void _onRegionScrubEnd(Duration duration) {
    if (!_isScrubbing) return;
    final targetMs = (duration.inMilliseconds * _scrubRatio).toInt();
    _controller.seekTo(Duration(milliseconds: targetMs));
    HapticFeedback.lightImpact();
    setState(() => _isScrubbing = false);
  }

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

    // Semak jika video telah siap dimuat awal (preloaded) di latar belakang!
    final cached = FeedVideoPreloadManager.getController(cleanUrl);
    if (cached != null) {
      _controller = cached;
      _controller.addListener(_videoListener);
      if (_controller.value.isInitialized) {
        _isInitialized = true;
        _hasError = false;
        final double aspect = _controller.value.aspectRatio;
        if (aspect > 0) {
          widget.onAspectRatioDetermined?.call(aspect);
        }
        _applyPlayState();
        return;
      }
    } else {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(cleanUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      FeedVideoPreloadManager._cache[cleanUrl] = _controller;
    }

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

      _applyPlayState();
    }).catchError((e) {
      debugPrint('[FeedVideoPlayer] Error loading video: $e (attempt $_retryCount)');
      if (_retryCount < 2 && mounted) {
        _retryCount++;
        Future.delayed(const Duration(milliseconds: 300), () {
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

  void _applyPlayState() {
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
      if (FeedVideoPreloadManager.getController(oldWidget.videoUrl) == null) {
        _controller.pause();
        _controller.dispose();
      } else {
        _controller.pause();
      }
      _isInitialized = false;
      _hasError = false;
      _retryCount = 0;
      _initializeController();
      return;
    }

    if (oldWidget.isCurrentPage != widget.isCurrentPage && !widget.isCurrentPage) {
      _playIndicatorTimer?.cancel();
      _showPlayIndicator = false;
      _isUserPaused = false;
      if (_isInitialized) {
        _controller.pause();
        _controller.seekTo(Duration.zero);
      }
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
    if (FeedVideoPreloadManager.getController(widget.videoUrl) == null) {
      _controller.pause();
      _controller.dispose();
    } else {
      _controller.pause();
      _controller.seekTo(Duration.zero);
    }
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

        // Position the "Lihat Melintang" pill safely above bottom content if landscape
        final double pillBottom = widget.bottomOffset + 140;

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Base Video Surface (TikTok Style: fit-width edge-to-edge from top without side cropping)
            IgnorePointer(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: widget.isDesktop
                      ? (isLandscape ? BoxFit.contain : BoxFit.cover)
                      : (isLandscape ? BoxFit.contain : BoxFit.fitWidth),
                  clipBehavior: Clip.hardEdge,
                  alignment: (widget.isDesktop || isLandscape) ? Alignment.center : Alignment.topCenter,
                  child: SizedBox(
                    width: _controller.value.size.width > 0 ? _controller.value.size.width : 720,
                    height: _controller.value.size.height > 0 ? _controller.value.size.height : 1280,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
            ),

            // 1.1 Top Subtle Shadow Gradient (Behind top status bar & tabs, keeps tabs legible without dimming the video)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: widget.isDesktop ? 80 : 90,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 1.2 Bottom Subtle Shadow Gradient (Strictly BEHIND caption, text is NEVER tinted or darkened!)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: widget.isDesktop ? 180 : (widget.bottomOffset + 180),
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.65),
                      ],
                    ),
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

        // 5. Floating Scrub Timestamp Bubble when Dragging Timeline (TikTok Style Pill)
        if (_isScrubbing)
          Positioned(
            bottom: widget.isDesktop ? 60 : (widget.bottomOffset + 140),
            left: 0,
            right: 0,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.65),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                          blurRadius: 18,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedPlay,
                          color: Color(0xFF00E5FF),
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_formatDuration(scrubTime)} / ${_formatDuration(duration)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // 6. Unified TikTok Bottom Interactive Zone (Caption + Scrubber with Auto Horizontal Slide Drag)
        Positioned(
          left: 0,
          right: widget.isDesktop ? 0 : 76,
          bottom: 0,
          height: widget.isDesktop ? 220 : (widget.bottomOffset + 260),
          child: widget.isInsideCarousel
              ? IgnorePointer(
                  ignoring: widget.bottomContent == null,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (widget.bottomContent != null)
                        Positioned(
                          left: 16,
                          right: 0,
                          bottom: widget.bottomOffset + 6,
                          child: widget.bottomContent!,
                        ),
                    ],
                  ),
                )
              : GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: (details) {
                    _onRegionScrubStart(details.globalPosition.dx, currentRatio);
                  },
                  onHorizontalDragUpdate: (details) {
                    _onRegionScrubUpdate(details.globalPosition.dx, constraints.maxWidth);
                  },
                  onHorizontalDragEnd: (details) {
                    _onRegionScrubEnd(duration);
                  },
                  onHorizontalDragCancel: () {
                    setState(() => _isScrubbing = false);
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Bottom Content (Caption, Store info, CTA)
                      if (widget.bottomContent != null)
                        Positioned(
                          left: 16,
                          right: 0,
                          bottom: widget.bottomOffset + 6,
                          child: widget.bottomContent!,
                        ),
                    ],
                  ),
                ),
        ),

        // 7. Interactive Video Timeline Scrubber (TikTok Signature Ultra-Clean Progress Bar)
        Positioned(
          left: 0,
          right: 0,
          bottom: widget.isDesktop ? 2 : (widget.bottomOffset - 16),
          child: LayoutBuilder(
            builder: (context, barConstraints) {
              final barWidth = barConstraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (details) {
                  _onRegionScrubStart(details.globalPosition.dx, currentRatio);
                },
                onHorizontalDragUpdate: (details) {
                  _onRegionScrubUpdate(details.globalPosition.dx, barWidth);
                },
                onHorizontalDragEnd: (details) {
                  _onRegionScrubEnd(duration);
                },
                onTapDown: (details) {
                  HapticFeedback.selectionClick();
                  final ratio = (details.localPosition.dx / barWidth).clamp(0.0, 1.0);
                  final targetMs = (duration.inMilliseconds * ratio).toInt();
                  _controller.seekTo(Duration(milliseconds: targetMs));
                },
                child: Container(
                  height: 38, // Large touch hit target for effortless scrubbing
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Base background track with subtle glass/shadow effect
                      Container(
                        height: _isScrubbing ? 6.0 : 3.0,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: _isScrubbing ? 0.35 : 0.22),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                      // Progress track with glowing cyan / bright white accent
                      FractionallySizedBox(
                        widthFactor: currentRatio,
                        child: Container(
                          height: _isScrubbing ? 6.0 : 3.0,
                          decoration: BoxDecoration(
                            gradient: _isScrubbing
                                ? const LinearGradient(
                                    colors: [Color(0xFF00E5FF), Color(0xFF38BDF8)],
                                  )
                                : null,
                            color: _isScrubbing ? null : Colors.white.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: _isScrubbing
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF00E5FF).withValues(alpha: 0.8),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                      // Glowing scrubber thumb when dragging (like TikTok)
                      if (_isScrubbing)
                        Align(
                          alignment: Alignment(-1.0 + (currentRatio * 2.0), 0.0),
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF00E5FF),
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.9),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ],
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

// =============================================================================
// Widget: Carousel Media Gaya TikTok (Gambar & Video Campur, Portrait & Landscape)
// =============================================================================
class _FeedCarouselMediaView extends StatefulWidget {
  final String postId;
  final List<Map<String, String>> items;
  final bool isCurrentPage;
  final bool isPausedExternally;
  final bool isMuted;
  final double bottomOffset;
  final bool isDesktop;
  final VoidCallback onToggleMute;
  final void Function(Offset position)? onDoubleTap;
  final void Function(bool isPlaying)? onPlayStateChanged;

  const _FeedCarouselMediaView({
    super.key,
    required this.postId,
    required this.items,
    required this.isCurrentPage,
    required this.isPausedExternally,
    required this.isMuted,
    required this.bottomOffset,
    required this.isDesktop,
    required this.onToggleMute,
    this.onDoubleTap,
    this.onPlayStateChanged,
  });

  @override
  State<_FeedCarouselMediaView> createState() => _FeedCarouselMediaViewState();
}

class _FeedCarouselMediaViewState extends State<_FeedCarouselMediaView> {
  final PageController _pageController = PageController();
  int _activeIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int idx) {
    if (idx < 0 || idx >= widget.items.length) return;
    _pageController.animateToPage(
      idx,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.items.length,
            onPageChanged: (idx) {
              setState(() => _activeIndex = idx);
            },
            itemBuilder: (ctx, i) {
              final item = widget.items[i];
              final url = item['url'] ?? '';
              final isVideo = item['type'] == 'video';

              if (isVideo) {
                return _FeedVideoPlayerItem(
                  key: ValueKey('carousel_vid_${widget.postId}_${i}_$url'),
                  videoUrl: url,
                  isCurrentPage: widget.isCurrentPage && i == _activeIndex,
                  isPausedExternally: widget.isPausedExternally,
                  isMuted: widget.isMuted,
                  bottomOffset: widget.bottomOffset,
                  isDesktop: widget.isDesktop,
                  isInsideCarousel: true,
                  bottomContent: null,
                  onToggleMute: widget.onToggleMute,
                  onDoubleTap: widget.onDoubleTap,
                  onPlayStateChanged: widget.onPlayStateChanged,
                );
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTapDown: (details) =>
                    widget.onDoubleTap?.call(details.globalPosition),
                child: SizedBox.expand(
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
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
                  ),
                ),
              );
            },
          ),

          // Badge bilangan slaid (cth: 1 / 4)
          Positioned(
            top: widget.isDesktop ? 16 : MediaQuery.paddingOf(context).top + 54,
            right: 14,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Text(
                  '${_activeIndex + 1} / ${widget.items.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // Dot Indicator ala TikTok Photo Mode
          Positioned(
            left: 0,
            right: 0,
            bottom: widget.isDesktop ? 14 : widget.bottomOffset + 128,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.items.length, (i) {
                  final bool isActive = i == _activeIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF00E5FF)
                          : Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ),

          // Anak panah kiri/kanan untuk Desktop
          if (widget.isDesktop && _activeIndex > 0)
            Positioned(
              left: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _goToPage(_activeIndex - 1),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          if (widget.isDesktop && _activeIndex < widget.items.length - 1)
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _goToPage(_activeIndex + 1),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
