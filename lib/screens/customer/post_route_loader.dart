import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../services/saved_service.dart';
import '../../widgets/glass_toast.dart';
import '../../widgets/glass_share_sheet.dart';
import '../explore/business_store_view.dart';
import 'customer_home_screen.dart';

/// Skrin Memuatkan Pos / Video Tunggal daripada Pautan Deep Link (e.g. https://ngam.dev/p/:id)
class PostRouteLoader extends StatefulWidget {
  final String postId;

  const PostRouteLoader({super.key, required this.postId});

  @override
  State<PostRouteLoader> createState() => _PostRouteLoaderState();
}

class _PostRouteLoaderState extends State<PostRouteLoader> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _post;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isMuted = false;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _fetchPostData();
  }

  @override
  void dispose() {
    _videoController?.pause();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _fetchPostData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final targetId = widget.postId.trim();

    // 1. Semak data demo terlebih dahulu (untuk pos 1, 2, 3)
    if (targetId == '1') {
      _loadPostMap({
        'id': '1',
        'shopName': 'Barber Danial',
        'shopHandle': '@barberdanial',
        'shopAvatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=200',
        'category': 'barber',
        'timeAgo': '35 min lepas',
        'location': 'Bangi Sentral',
        'image': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
        'mediaType': 'video',
        'title': 'Low Taper Fade + Beard Sculpting',
        'caption': 'Hasil sentuhan kemas petang ini untuk regular bro Hazim. Slot walk-in dan giliran petang ni masih dibuka sampai jam 10 malam! #barber #taperfade #ngam',
        'ctaText': 'AMBIL GILIRAN',
        'likes': 142,
        'comments': 19,
        'shopData': {
          'name': 'Barber Danial',
          'category': 'barber',
          'rating': 4.9,
          'image': 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?q=80&w=400',
        },
      });
      return;
    } else if (targetId == '2') {
      _loadPostMap({
        'id': '2',
        'shopName': 'SpeedWash Detailing Autocare',
        'shopHandle': '@speedwash_detailing',
        'shopAvatar': 'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?q=80&w=200',
        'category': 'carwash',
        'timeAgo': '1 jam lepas',
        'location': 'Seksyen 9, Bangi',
        'image': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4',
        'mediaType': 'video',
        'title': 'Cermin Kereta Bersinar Bak Kristal',
        'caption': 'Pakej Nano Wax Coating + Interior Steam Wash promosi khas pertengahan bulan. Hilangkan watermark dan bau hapak kereta anda sekarang! #detailing #carwash #ngam',
        'ctaText': 'MASUK TERUS',
        'likes': 89,
        'comments': 8,
        'shopData': {
          'name': 'SpeedWash Detailing Autocare',
          'category': 'carwash',
          'rating': 4.8,
          'image': 'https://images.unsplash.com/photo-1520340356584-f9917d1eea6f?q=80&w=400',
        },
      });
      return;
    }

    // 2. Tarik pos dari Supabase
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
            likes_count,
            comments_count,
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
          .eq('id', targetId)
          .maybeSingle();

      if (res != null) {
        final biz = (res['businesses'] as Map?) ?? {};
        final String shopName = (biz['business_name'] as String?)?.trim() ?? 'Kedai di Ngam';
        final String shopAvatar = (biz['business_logo_url'] as String?)?.trim() ?? '';
        final String shopHandle = (biz['business_handle'] as String?)?.trim() ?? '@kedai';
        final String mediaUrl = (res['media_url'] as String?)?.trim() ?? '';
        final bool isVideo = (res['media_type'] == 'video') ||
            mediaUrl.toLowerCase().endsWith('.mp4') ||
            mediaUrl.toLowerCase().contains('/video/');

        _loadPostMap({
          'id': res['id']?.toString() ?? targetId,
          'businessId': res['business_id']?.toString(),
          'shopName': shopName,
          'shopHandle': shopHandle,
          'shopAvatar': shopAvatar,
          'category': res['category'] ?? biz['business_industry'] ?? 'Umum',
          'image': mediaUrl,
          'mediaType': isVideo ? 'video' : 'image',
          'title': res['title'] ?? '',
          'caption': res['caption'] ?? '',
          'ctaText': res['cta_text'] ?? 'AMBIL GILIRAN',
          'likes': (res['likes_count'] as num?)?.toInt() ?? 0,
          'comments': (res['comments_count'] as num?)?.toInt() ?? 0,
          'shopData': {
            'id': biz['id'] ?? res['business_id'],
            'name': shopName,
            'business_name': shopName,
            'business_handle': shopHandle,
            'logo_url': shopAvatar,
            'image': shopAvatar,
            'business_logo_url': shopAvatar,
            'category': biz['business_industry'] ?? 'Umum',
            'rating': 4.9,
          },
        });
        return;
      }
    } catch (e) {
      debugPrint('[PostRouteLoader] Error fetching post: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Kandungan ini tidak dijumpai atau telah dipadam.';
      });
    }
  }

  void _loadPostMap(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      _post = data;
      _isLoading = false;
    });

    final String mediaUrl = (data['image'] ?? '').toString().trim();
    final bool isVideo = data['mediaType'] == 'video' ||
        mediaUrl.toLowerCase().endsWith('.mp4') ||
        mediaUrl.toLowerCase().contains('/video/');

    if (isVideo && mediaUrl.isNotEmpty) {
      final uri = Uri.tryParse(mediaUrl);
      if (uri != null) {
        _videoController = VideoPlayerController.networkUrl(
          uri,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        _videoController!.initialize().then((_) {
          if (!mounted) return;
          setState(() {
            _isVideoInitialized = true;
          });
          _videoController!.setLooping(true);
          _videoController!.setVolume(_isMuted ? 0.0 : 1.0).catchError((_) {});
          _videoController!.play();
        }).catchError((err) {
          debugPrint('[PostRouteLoader] Video init error: $err');
        });
      }
    }
  }

  void _togglePlay() {
    if (_videoController == null || !_isVideoInitialized) return;
    HapticFeedback.lightImpact();
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _isPlaying = false;
      } else {
        _videoController!.play();
        _isPlaying = true;
      }
    });
  }

  void _toggleMute() {
    if (_videoController == null) return;
    setState(() {
      _isMuted = !_isMuted;
    });
    _videoController!.setVolume(_isMuted ? 0.0 : 1.0).catchError((_) {});
    showGlassToast(
      context,
      _isMuted ? 'Audio Dimatikan' : 'Audio Dihidupkan',
      icon: _isMuted ? HugeIcons.strokeRoundedVolumeOff : HugeIcons.strokeRoundedVolumeHigh,
    );
  }

  void _openStore() {
    if (_post == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessStoreView(shop: _post!['shopData'] ?? {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0F17),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00E5FF),
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (_errorMessage != null || _post == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomerHomeScreen(initialIndex: 2)),
                );
              }
            },
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert02,
                  color: Color(0xFFEF4444),
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Ralat memuatkan hantaran',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const CustomerHomeScreen(initialIndex: 2)),
                    );
                  },
                  icon: const Icon(Icons.video_library_rounded, size: 18),
                  label: const Text('Buka Ngam Feed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final post = _post!;
    final String mediaUrl = (post['image'] ?? '').toString();
    final bool isVideo = post['mediaType'] == 'video' || mediaUrl.contains('.mp4');
    final String postId = post['id']?.toString() ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. VIDEO / IMAGE CONTENT
          GestureDetector(
            onTap: _togglePlay,
            behavior: HitTestBehavior.opaque,
            child: isVideo && _videoController != null && _isVideoInitialized
                ? Center(
                    child: AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio > 0
                          ? _videoController!.value.aspectRatio
                          : (9 / 16),
                      child: VideoPlayer(_videoController!),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: mediaUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedVideo01,
                        color: Colors.white54,
                        size: 40,
                      ),
                    ),
                  ),
          ),

          // 2. Play Indicator (when paused)
          if (!_isPlaying)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),

          // 3. TOP BAR: Back Button & Ngam Brand
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const CustomerHomeScreen(initialIndex: 2)),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E5FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'NGAM FEED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 4. RIGHT ACTION BAR (Simpan, Kongsi, Audio, Info Kedai)
          Positioned(
            right: 14,
            bottom: 120,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Save Button (Reactive)
                ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: SavedService.savedPostsNotifier,
                  builder: (context, _, __) {
                    final bool isSaved = SavedService.isPostSaved(postId);
                    return GestureDetector(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final nowSaved = await SavedService.toggleSavePost(post);
                        if (context.mounted) {
                          showGlassToast(
                            context,
                            nowSaved
                                ? 'Hantaran disimpan ke koleksi anda'
                                : 'Hantaran dikeluarkan dari simpanan',
                            icon: HugeIcons.strokeRoundedBookmark02,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: Icon(
                          isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          color: isSaved ? const Color(0xFFFBBF24) : Colors.white,
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Share Button
                GestureDetector(
                  onTap: () => showGlassShareSheet(context, post: post),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedShare01,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Audio Mute/Unmute
                if (isVideo)
                  GestureDetector(
                    onTap: _toggleMute,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Icon(
                        _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 5. BOTTOM OVERLAY: Creator info, caption, and Action CTA
          Positioned(
            left: 16,
            right: 80,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Creator Handle & Avatar
                GestureDetector(
                  onTap: _openStore,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white24,
                        backgroundImage: post['shopAvatar'] != null && post['shopAvatar'].isNotEmpty
                            ? CachedNetworkImageProvider(post['shopAvatar'])
                            : null,
                        child: post['shopAvatar'] == null || post['shopAvatar'].isEmpty
                            ? Text(
                                post['shopName']?[0] ?? 'N',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        post['shopName'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(color: Colors.black87, blurRadius: 6),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Title & Caption
                if ((post['title'] ?? '').isNotEmpty)
                  Text(
                    post['title'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 6),
                      ],
                    ),
                  ),
                if ((post['caption'] ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      post['caption'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // Primary CTA Button (Ambil Giliran / Lihat Kedai)
                GestureDetector(
                  onTap: _openStore,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedStore01,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          post['ctaText'] ?? 'LIHAT KEDAI',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
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
}
