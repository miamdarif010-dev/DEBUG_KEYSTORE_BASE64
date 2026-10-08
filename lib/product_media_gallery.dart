import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ProductMediaGallery extends StatefulWidget {
  final List<String> imageUrls;
  final String? videoUrl;
  final VoidCallback onCartTap;
  final int cartCount;

  const ProductMediaGallery({
    super.key,
    required this.imageUrls,
    this.videoUrl,
    required this.onCartTap,
    this.cartCount = 0,
  });

  @override
  State<ProductMediaGallery> createState() =>
      _ProductMediaGalleryState();
}

class _ProductMediaGalleryState
    extends State<ProductMediaGallery> {
  late final PageController _pageController;

  VideoPlayerController? _videoController;

  int _currentPage = 0;

  // Floating cart position
  Offset _cartPosition = const Offset(0, 250);

  List<String> get _mediaItems {
    final items = <String>[];

    for (final image in widget.imageUrls) {
      final url = image.trim();

      if (url.isNotEmpty && !items.contains(url)) {
        items.add(url);
      }
    }

    final video = widget.videoUrl?.trim() ?? '';

    if (video.isNotEmpty) {
      items.add('VIDEO::$video');
    }

    return items;
  }

  @override
  void initState() {
    super.initState();

    _pageController = PageController();

    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final videoUrl = widget.videoUrl?.trim() ?? '';

    if (videoUrl.isEmpty) {
      return;
    }

    try {
      final controller =
          VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
      );

      _videoController = controller;

      await controller.initialize();

      if (!mounted) return;

      setState(() {});

      controller.setLooping(true);
    } catch (_) {
      // Video failure should not break product page.
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    if (!_pageController.hasClients) {
      return;
    }

    _pageController.animateToPage(
      index,
      duration:
          const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _toggleVideo() {
    final controller = _videoController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }

    setState(() {});
  }

  Widget _buildImage(String url) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      height: double.infinity,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder:
            (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }

          return const Center(
            child:
                CircularProgressIndicator(),
          );
        },
        errorBuilder:
            (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade100,
            child: const Center(
              child: Icon(
                Icons.image_outlined,
                size: 70,
                color: Colors.grey,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideo() {
    final controller = _videoController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleVideo,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            color: Colors.black,
            width: double.infinity,
            height: double.infinity,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width:
                    controller.value.size.width,
                height:
                    controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),

          if (!controller.value.isPlaying)
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.black.withValues(
                  alpha: 0.55,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 40,
              ),
            ),

          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(
                  alpha: 0.55,
                ),
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: 17,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Video',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingCart() {
    final screenSize =
        MediaQuery.of(context).size;

    final maxX =
        screenSize.width - 70;

    final maxY =
        screenSize.height - 210;

    final x = _cartPosition.dx
        .clamp(8.0, maxX);

    final y = _cartPosition.dy
        .clamp(70.0, maxY);

    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _cartPosition = Offset(
              (_cartPosition.dx +
                      details.delta.dx)
                  .clamp(
                8.0,
                maxX,
              ),
              (_cartPosition.dy +
                      details.delta.dy)
                  .clamp(
                70.0,
                maxY,
              ),
            );
          });
        },
        onTap: widget.onCartTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(
                      alpha: 0.20,
                    ),
                    blurRadius: 8,
                    offset:
                        const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: Colors.redAccent,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.shopping_cart,
                color: Colors.redAccent,
                size: 28,
              ),
            ),

            if (widget.cartCount > 0)
              Positioned(
                right: -3,
                top: -4,
                child: Container(
                  constraints:
                      const BoxConstraints(
                    minWidth: 22,
                    minHeight: 22,
                  ),
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 5,
                  ),
                  decoration:
                      const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.cartCount > 99
                          ? '99+'
                          : '${widget.cartCount}',
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaItems = _mediaItems;

    if (mediaItems.isEmpty) {
      return SizedBox(
        width: double.infinity,
        height: 380,
        child: Container(
          color: Colors.grey.shade100,
          child: const Center(
            child: Icon(
              Icons.image_outlined,
              size: 80,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 380,
      child: Stack(
        children: [
          // =====================================================
          // MAIN MEDIA SLIDER
          // =====================================================

          PageView.builder(
            controller: _pageController,
            itemCount: mediaItems.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });

              final item =
                  mediaItems[index];

              if (item.startsWith('VIDEO::')) {
                _videoController?.play();
              } else {
                _videoController?.pause();
              }
            },
            itemBuilder:
                (context, index) {
              final item =
                  mediaItems[index];

              if (item.startsWith('VIDEO::')) {
                return _buildVideo();
              }

              return _buildImage(item);
            },
          ),

          // =====================================================
          // IMAGE / VIDEO COUNTER
          // =====================================================

          Positioned(
            right: 14,
            bottom: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(
                  alpha: 0.55,
                ),
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentPage + 1}/${mediaItems.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ),

          // =====================================================
          // LEFT / RIGHT ARROWS
          // =====================================================

          if (mediaItems.length > 1)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _arrowButton(
                  icon: Icons.chevron_left,
                  onTap: () {
                    final previous =
                        _currentPage - 1;

                    if (previous >= 0) {
                      _goToPage(previous);
                    }
                  },
                ),
              ),
            ),

          if (mediaItems.length > 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _arrowButton(
                  icon: Icons.chevron_right,
                  onTap: () {
                    final next =
                        _currentPage + 1;

                    if (next <
                        mediaItems.length) {
                      _goToPage(next);
                    }
                  },
                ),
              ),
            ),

          // =====================================================
          // DOT INDICATORS
          // =====================================================

          if (mediaItems.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 15,
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children:
                    List.generate(
                  mediaItems.length > 10
                      ? 10
                      : mediaItems.length,
                  (index) {
                    final active =
                        index == _currentPage;

                    return Container(
                      width: active ? 18 : 6,
                      height: 6,
                      margin:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 3,
                      ),
                      decoration:
                          BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white
                                .withValues(
                            alpha: 0.55,
                          ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // =====================================================
          // FLOATING CART
          // =====================================================

          _buildFloatingCart(),
        ],
      ),
    );
  }

  Widget _arrowButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(
            alpha: 0.35,
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
