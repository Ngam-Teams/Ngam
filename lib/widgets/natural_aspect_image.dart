import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Shared in-memory cache of natural image aspect ratios (width / height)
/// plus Web/PWA resume recovery epoch to prevent WebGL texture eviction blanks.
class NaturalImageAspectCache {
  NaturalImageAspectCache._();

  static final Map<String, double> _ratios = <String, double>{};
  static final Map<String, Future<double?>> _inFlight =
      <String, Future<double?>>{};

  /// Incremented when the app/PWA returns from background so any evicted
  /// WebGL textures automatically repaint from browser HTTP cache.
  static final ValueNotifier<int> resumeEpoch = ValueNotifier<int>(0);

  static void notifyAppResumed() {
    if (kIsWeb) {
      PaintingBinding.instance.imageCache.clearLiveImages();
      resumeEpoch.value = resumeEpoch.value + 1;
    }
  }

  static double? get(String url) {
    final key = url.trim();
    if (key.isEmpty) return null;
    return _ratios[key];
  }

  static Future<double?> resolve(String url) {
    final key = url.trim();
    if (key.isEmpty) return Future<double?>.value(null);
    final cached = _ratios[key];
    if (cached != null) return Future<double?>.value(cached);
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final completer = Completer<double?>();
    _inFlight[key] = completer.future;

    // Share the exact same 600px resized ImageProvider as the rendered widget
    // so full-res photos are never decoded twice into WebGL memory.
    final ImageProvider baseProvider =
        kIsWeb ? NetworkImage(key) : CachedNetworkImageProvider(key);
    final ImageProvider provider =
        ResizeImage.resizeIfNeeded(600, null, baseProvider);
    final ImageStream stream = provider.resolve(ImageConfiguration.empty);

    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        double? ratio;
        if (w > 0 && h > 0) {
          ratio = w / h;
          _ratios[key] = ratio;
        }
        stream.removeListener(listener);
        _inFlight.remove(key);
        if (!completer.isCompleted) completer.complete(ratio);
      },
      onError: (_, __) {
        stream.removeListener(listener);
        _inFlight.remove(key);
        if (!completer.isCompleted) completer.complete(null);
      },
    );

    stream.addListener(listener);
    return completer.future;
  }
}

/// Renders a network image sized strictly to its natural aspect ratio so
/// portrait, square, and landscape photos are displayed at full height
/// without unwanted cropping in masonry grids.
class NaturalAspectNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double defaultAspectRatio;
  final double minAspectRatio;
  final double maxAspectRatio;
  final Widget Function(BuildContext context, double height) placeholderBuilder;
  final Widget Function(BuildContext context, double height) errorBuilder;
  final List<Widget> overlayChildren;

  const NaturalAspectNetworkImage({
    super.key,
    required this.imageUrl,
    this.defaultAspectRatio = 1.0,
    this.minAspectRatio = 0.45,
    this.maxAspectRatio = 2.2,
    required this.placeholderBuilder,
    required this.errorBuilder,
    this.overlayChildren = const [],
  });

  @override
  State<NaturalAspectNetworkImage> createState() =>
      _NaturalAspectNetworkImageState();
}

class _NaturalAspectNetworkImageState extends State<NaturalAspectNetworkImage> {
  double? _naturalRatio;
  int _retryCount = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _loadRatio();
  }

  @override
  void didUpdateWidget(covariant NaturalAspectNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _retryCount = 0;
      _retryTimer?.cancel();
      _loadRatio();
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _scheduleAutoRetry() {
    if (_retryCount >= 2 || _retryTimer?.isActive == true) return;
    _retryTimer = Timer(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      final url = widget.imageUrl.trim();
      if (url.isNotEmpty) {
        ResizeImage.resizeIfNeeded(600, null, NetworkImage(url)).evict();
      }
      setState(() => _retryCount++);
    });
  }

  void _loadRatio() {
    final cached = NaturalImageAspectCache.get(widget.imageUrl);
    _naturalRatio = cached;
    if (cached != null || widget.imageUrl.trim().isEmpty) return;

    final requestedUrl = widget.imageUrl;
    NaturalImageAspectCache.resolve(requestedUrl).then((ratio) {
      if (!mounted || widget.imageUrl != requestedUrl || ratio == null) return;
      if (_naturalRatio != ratio) {
        setState(() => _naturalRatio = ratio);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double rawRatio = _naturalRatio ?? widget.defaultAspectRatio;
    final double clampedRatio =
        rawRatio.clamp(widget.minAspectRatio, widget.maxAspectRatio);
    // Use BoxFit.contain if the photo's natural aspect exceeds the extreme
    // clamp bounds so it still never crops, otherwise cover fills edge-to-edge.
    final bool isClamped = (rawRatio - clampedRatio).abs() > 0.01;
    final BoxFit fit = isClamped ? BoxFit.contain : BoxFit.cover;

    return ValueListenableBuilder<int>(
      valueListenable: NaturalImageAspectCache.resumeEpoch,
      builder: (context, epoch, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 180.0;
            final double imgHeight = width / clampedRatio;

            return SizedBox(
              width: double.infinity,
              height: imgHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.imageUrl.trim().isEmpty)
                    widget.errorBuilder(context, imgHeight)
                  else if (kIsWeb)
                    Image.network(
                      widget.imageUrl,
                      key: ValueKey('${widget.imageUrl}_${epoch}_$_retryCount'),
                      width: double.infinity,
                      height: imgHeight,
                      cacheWidth: 600,
                      fit: fit,
                      gaplessPlayback: true,
                      frameBuilder: (ctx, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded || frame != null) {
                          return child;
                        }
                        return widget.placeholderBuilder(ctx, imgHeight);
                      },
                      errorBuilder: (ctx, _, __) {
                        _scheduleAutoRetry();
                        return _retryCount < 2
                            ? widget.placeholderBuilder(ctx, imgHeight)
                            : widget.errorBuilder(ctx, imgHeight);
                      },
                    )
                  else
                    CachedNetworkImage(
                      imageUrl: widget.imageUrl,
                      width: double.infinity,
                      height: imgHeight,
                      fit: fit,
                      fadeInDuration: const Duration(milliseconds: 180),
                      memCacheWidth: 600,
                      placeholder: (ctx, _) =>
                          widget.placeholderBuilder(ctx, imgHeight),
                      errorWidget: (ctx, _, __) =>
                          widget.errorBuilder(ctx, imgHeight),
                    ),
                  ...widget.overlayChildren,
                ],
              ),
            );
          },
        );
      },
    );
  }
}
