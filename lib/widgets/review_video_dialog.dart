import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Dialog interaktif untuk memainkan video ulasan pelanggan dengan kawalan play/pause & scrubbing.
class ReviewVideoDialog extends StatefulWidget {
  final String videoUrl;
  final String title;

  const ReviewVideoDialog({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  static void show(BuildContext context, {required String videoUrl, required String title}) {
    showDialog(
      context: context,
      builder: (_) => ReviewVideoDialog(videoUrl: videoUrl, title: title),
    );
  }

  @override
  State<ReviewVideoDialog> createState() => _ReviewVideoDialogState();
}

class _ReviewVideoDialogState extends State<ReviewVideoDialog> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    final uri = Uri.tryParse(widget.videoUrl);
    if (uri != null) {
      _controller = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller!.initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller!.play();
          _controller!.setLooping(true);
        }
      }).catchError((err) {
        debugPrint('[ReviewVideoPlayer] Video init failed: $err');
        if (mounted) setState(() => _hasError = true);
      });
    } else {
      _hasError = true;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black.withValues(alpha: 0.94),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Player View
              AspectRatio(
                aspectRatio: _isInitialized ? _controller!.value.aspectRatio : (9 / 16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isInitialized && _controller != null)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                          });
                        },
                        child: VideoPlayer(_controller!),
                      )
                    else if (_hasError)
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 48),
                          SizedBox(height: 8),
                          Text('Tidak dapat memainkan video', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      )
                    else
                      const CircularProgressIndicator(color: Colors.blue),

                    if (_isInitialized && _controller != null && !_controller!.value.isPlaying)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white30),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
                      ),
                  ],
                ),
              ),

              // Video Progress Bar
              if (_isInitialized && _controller != null)
                VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.blue,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white12,
                  ),
                ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
