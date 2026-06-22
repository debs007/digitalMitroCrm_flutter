import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_colors.dart';

/// In-app video player for chat attachments — streams directly from the
/// public Cloudinary URL, no download needed.
class VideoPreviewScreen extends StatefulWidget {
  final String url;

  const VideoPreviewScreen({super.key, required this.url});

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  late VideoPlayerController _controller;
  bool _isReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _isReady = true);
      _controller.play();
    }).catchError((_) {
      if (mounted) setState(() => _error = 'Could not play this video.');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: _error != null
            ? Text(_error!, style: const TextStyle(color: Colors.white))
            : !_isReady
                ? const CircularProgressIndicator(color: Colors.white)
                : AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _controller.value.isPlaying ? _controller.pause() : _controller.play();
                      }),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          VideoPlayer(_controller),
                          if (!_controller.value.isPlaying)
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                              child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                            ),
                        ],
                      ),
                    ),
                  ),
      ),
      bottomNavigationBar: _isReady
          ? Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(playedColor: AppColors.primary, bufferedColor: Colors.white24),
              ),
            )
          : null,
    );
  }
}
