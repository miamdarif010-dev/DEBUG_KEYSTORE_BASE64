import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String caption;
  final String sellerName;

  const VideoPlayerPage({
    super.key,
    required this.videoUrl,
    required this.caption,
    required this.sellerName,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showPlayIcon = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      try {
        await controller.initialize();
      } catch (_) {
        await controller.dispose();
        rethrow;
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }

      controller.setLooping(true);
      controller.play();

      setState(() {
        _controller = controller;
        _isInitialized = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _showPlayIcon = true;
      } else {
        _controller!.play();
        _showPlayIcon = true;
        // hide the icon again shortly after resuming playback
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _showPlayIcon = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.sellerName, style: const TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.broken_image, color: Colors.white54, size: 60),
                        SizedBox(height: 12),
                        Text(
                          'ভিডিও লোড করা যায়নি',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    )
                  : _isInitialized && _controller != null
                      ? GestureDetector(
                          onTap: _togglePlayPause,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AspectRatio(
                                aspectRatio: _controller!.value.aspectRatio > 0
                                    ? _controller!.value.aspectRatio
                                    : 16 / 9,
                                child: VideoPlayer(_controller!),
                              ),
                              AnimatedOpacity(
                                opacity: _showPlayIcon ? 1 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black38,
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(
                                    _controller!.value.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const CircularProgressIndicator(color: Colors.white),
            ),
          ),
          if (widget.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.caption,
                  style: const TextStyle(color: Colors.white),
                  softWrap: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
