import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Shared in-memory cache of natural image aspect ratios (width / height).
///
/// Resolving an image once in the Home masonry grid immediately provides its
/// exact aspect ratio to [ProductDetailScreen] with zero layout jump.
class NaturalImageAspectCache {
  NaturalImageAspectCache._();

  static final Map<String, double> _ratios = <String, double>{};
  static final Map<String, Future<double?>> _inFlight =
      <String, Future<double?>>{};

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

    final ImageProvider provider =
        kIsWeb ? NetworkImage(key) : CachedNetworkImageProvider(key);
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

  @override
  void initState() {
    super.initState();
    _loadRatio();
  }

  @override
  void didUpdateWidget(covariant NaturalAspectNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadRatio();
    }
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
                  width: double.infinity,
                  height: imgHeight,
                  fit: fit,
                  gaplessPlayback: true,
                  frameBuilder: (ctx, child, frame, wasSynchronouslyLoaded) {
                    if (wasSynchronouslyLoaded || frame != null) {
                      return child;
                    }
                    return widget.placeholderBuilder(ctx, imgHeight);
                  },
                  errorBuilder: (ctx, _, __) =>
                      widget.errorBuilder(ctx, imgHeight),
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
  }
}
