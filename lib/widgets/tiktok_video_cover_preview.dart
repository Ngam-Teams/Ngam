import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Coordinates muted TikTok-style grid autoplay so only a small number of
/// currently visible video cards (default: up to 2) play at once as the user
/// scrolls, while all other visible video cards stay paused on their actual
/// video cover frame.
class GridVideoAutoplayCoordinator {
  final int maxConcurrent;
  final ValueNotifier<Set<String>> activeIds = ValueNotifier<Set<String>>(<String>{});
  final Map<String, BuildContext> _registered = <String, BuildContext>{};
  Timer? _debounce;
  bool _disposed = false;

  GridVideoAutoplayCoordinator({this.maxConcurrent = 2});

  void register(String id, BuildContext context) {
    if (_disposed || id.isEmpty) return;
    _registered[id] = context;
    scheduleUpdate();
  }

  void unregister(String id, BuildContext context) {
    if (_registered[id] == context) {
      _registered.remove(id);
    }
    if (!_disposed && activeIds.value.contains(id)) {
      final next = Set<String>.from(activeIds.value)..remove(id);
      activeIds.value = next;
      scheduleUpdate();
    }
  }

  void scheduleUpdate() {
    if (_disposed) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 110), _recompute);
  }

  void pauseAll() {
    if (_disposed) return;
    if (activeIds.value.isNotEmpty) {
      activeIds.value = <String>{};
    }
  }

  void _recompute() {
    if (_disposed) return;

    final List<({String id, double score})> candidates = [];
    final List<String> stale = [];

    for (final entry in _registered.entries) {
      final ctx = entry.value;
      if (!ctx.mounted) {
        stale.add(entry.key);
        continue;
      }
      final ro = ctx.findRenderObject();
      if (ro is! RenderBox || !ro.hasSize || !ro.attached) continue;

      final size = ro.size;
      if (size.height <= 0 || size.width <= 0) continue;

      final topLeft = ro.localToGlobal(Offset.zero);
      final viewport = MediaQuery.sizeOf(ctx);

      final visibleTop = topLeft.dy.clamp(0.0, viewport.height);
      final visibleBottom = (topLeft.dy + size.height).clamp(0.0, viewport.height);
      final visibleH = (visibleBottom - visibleTop).clamp(0.0, size.height);

      final visibleLeft = topLeft.dx.clamp(0.0, viewport.width);
      final visibleRight = (topLeft.dx + size.width).clamp(0.0, viewport.width);
      final visibleW = (visibleRight - visibleLeft).clamp(0.0, size.width);

      final vFrac = visibleH / size.height;
      final hFrac = visibleW / size.width;

      if (vFrac >= 0.45 && hFrac >= 0.50) {
        final centerY = topLeft.dy + size.height * 0.5;
        final sweetSpotY = viewport.height * 0.42;
        final distance = (centerY - sweetSpotY).abs();
        candidates.add((id: entry.key, score: distance));
      }
    }

    for (final id in stale) {
      _registered.remove(id);
    }

    candidates.sort((a, b) => a.score.compareTo(b.score));
    final Set<String> next = candidates
        .take(maxConcurrent)
        .map((c) => c.id)
        .toSet();

    if (!setEquals(activeIds.value, next)) {
      activeIds.value = next;
    }
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _registered.clear();
    activeIds.dispose();
  }
}

/// Renders a TikTok-style video card cover in a grid:
/// - Always extracts and displays the video's own real cover frame (seeking
///   slightly past t=0 to avoid black leading frames).
/// - Muted autoplays smoothly when selected by [GridVideoAutoplayCoordinator]
///   as the user scrolls, and pauses cleanly on its cover frame otherwise.
class TikTokVideoCoverPreview extends StatefulWidget {
  final String videoId;
  final String videoUrl;
  final String fallbackThumbnailUrl;
  final GridVideoAutoplayCoordinator coordinator;
  final Widget fallbackWidget;
  final bool isDark;

  const TikTokVideoCoverPreview({
    super.key,
    required this.videoId,
    required this.videoUrl,
    required this.fallbackThumbnailUrl,
    required this.coordinator,
    required this.fallbackWidget,
    required this.isDark,
  });

  @override
  State<TikTokVideoCoverPreview> createState() =>
      _TikTokVideoCoverPreviewState();
}

class _TikTokVideoCoverPreviewState extends State<TikTokVideoCoverPreview> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isPlaying = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    widget.coordinator.activeIds.addListener(_handleActiveChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.coordinator.register(widget.videoId, context);
    });
    _initController();
  }

  @override
  void didUpdateWidget(covariant TikTokVideoCoverPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coordinator != widget.coordinator) {
      oldWidget.coordinator.activeIds.removeListener(_handleActiveChanged);
      oldWidget.coordinator.unregister(oldWidget.videoId, context);
      widget.coordinator.activeIds.addListener(_handleActiveChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.coordinator.register(widget.videoId, context);
      });
    }
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      _initController();
    }
  }

  Future<void> _initController() async {
    final raw = widget.videoUrl.trim();
    final uri = Uri.tryParse(raw);
    if (raw.isEmpty || uri == null || !uri.hasScheme) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    try {
      final ctrl = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = ctrl;
      await ctrl.initialize();
      if (!mounted || _controller != ctrl) {
        await ctrl.dispose();
        return;
      }
      await ctrl.setLooping(true);
      await ctrl.setVolume(0.0);

      // Seek slightly past t=0 to grab a vibrant video cover frame instead of a black frame.
      if (ctrl.value.duration > const Duration(milliseconds: 350)) {
        try {
          await ctrl.seekTo(const Duration(milliseconds: 200));
        } catch (_) {}
      }

      if (!mounted || _controller != ctrl) return;
      final shouldPlay =
          widget.coordinator.activeIds.value.contains(widget.videoId);
      if (shouldPlay) {
        try {
          await ctrl.play();
        } catch (_) {}
      }

      if (mounted && _controller == ctrl) {
        setState(() {
          _initialized = true;
          _isPlaying = shouldPlay;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  void _handleActiveChanged() {
    final ctrl = _controller;
    if (!mounted || !_initialized || ctrl == null) return;

    final shouldPlay =
        widget.coordinator.activeIds.value.contains(widget.videoId);
    if (shouldPlay && !_isPlaying) {
      ctrl.setVolume(0.0);
      ctrl.play().then((_) {
        if (mounted && _controller == ctrl) {
          setState(() => _isPlaying = true);
        }
      }).catchError((_) {});
    } else if (!shouldPlay && _isPlaying) {
      ctrl.pause().then((_) {
        if (mounted && _controller == ctrl) {
          setState(() => _isPlaying = false);
        }
      }).catchError((_) {});
    }
  }

  void _disposeController() {
    final ctrl = _controller;
    _controller = null;
    _initialized = false;
    _isPlaying = false;
    _hasError = false;
    ctrl?.dispose();
  }

  @override
  void dispose() {
    widget.coordinator.activeIds.removeListener(_handleActiveChanged);
    widget.coordinator.unregister(widget.videoId, context);
    _disposeController();
    super.dispose();
  }

  Widget _buildFallbackLayer() {
    final thumb = widget.fallbackThumbnailUrl.trim();
    if (thumb.isEmpty) return widget.fallbackWidget;
    if (kIsWeb) {
      return Image.network(
        thumb,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => widget.fallbackWidget,
      );
    }
    return CachedNetworkImage(
      imageUrl: thumb,
      fit: BoxFit.cover,
      memCacheWidth: 420,
      placeholder: (_, __) => widget.fallbackWidget,
      errorWidget: (_, __, ___) => widget.fallbackWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    final bool showVideo = _initialized && !_hasError && ctrl != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Temporary poster while the video cover frame decodes
        _buildFallbackLayer(),

        // Crisp full-bleed real video cover frame + muted scroll autoplay
        if (showVideo)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: 1.0,
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: ctrl.value.size.width > 0
                      ? ctrl.value.size.width
                      : 720,
                  height: ctrl.value.size.height > 0
                      ? ctrl.value.size.height
                      : 1280,
                  child: VideoPlayer(ctrl),
                ),
              ),
            ),
          ),

        // Subtle TikTok-style muted-playing badge when autoplaying
        if (showVideo && _isPlaying)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.52),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 0.8,
                ),
              ),
              child: const Icon(
                Icons.volume_off_rounded,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
      ],
    );
  }
}
