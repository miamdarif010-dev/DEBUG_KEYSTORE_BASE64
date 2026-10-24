import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// TikTok / Facebook Reels style player.
///
/// Swipe up/down to change video, tap to pause/play, like, copy link,
/// attached product card, seek bar.
///
/// Each map in [videos] must contain `id` (the Firestore doc id) plus the
/// normal sellerVideos fields (videoUrl, caption, userName, ...).
class VideoPlayerPage extends StatefulWidget {
  final List<Map<String, dynamic>> videos;
  final int initialIndex;

  const VideoPlayerPage({
    super.key,
    required this.videos,
    this.initialIndex = 0,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final PageController _pageController;

  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _failed = {};

  int _current = 0;
  bool _paused = false;

  // Video ids whose view was already recorded in this session.
  final Set<String> _viewed = {};

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex.clamp(0, widget.videos.length - 1);
    _pageController = PageController(initialPage: _current);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _prepare(_current);
    _prepare(_current + 1);
    _recordView(_current);
  }

  /// One doc per user: sellerVideos/{id}/views/{uid}.
  /// The Cloud Function `onViewCreated` bumps viewCount from it.
  /// The owner's own views are not counted.
  Future<void> _recordView(int index) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || index < 0 || index >= widget.videos.length) return;

    final data = widget.videos[index];
    final id = (data['id'] ?? '').toString();
    if (id.isEmpty || _viewed.contains(id)) return;

    _viewed.add(id);

    final ownerId = (data['userId'] ?? data['sellerId'] ?? '').toString();
    if (ownerId == user.uid) return;

    try {
      final ref = FirebaseFirestore.instance
          .collection('sellerVideos')
          .doc(id)
          .collection('views')
          .doc(user.uid);

      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({'createdAt': FieldValue.serverTimestamp()});
      }
    } catch (_) {}
  }

  Future<void> _prepare(int i) async {
    if (i < 0 || i >= widget.videos.length) return;
    if (_controllers.containsKey(i) || _failed.contains(i)) return;

    final url = (widget.videos[i]['videoUrl'] ?? '').toString();

    if (url.isEmpty) {
      if (mounted) setState(() => _failed.add(i));
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controllers[i] = controller;

    try {
      await controller.initialize();
    } catch (_) {
      if (_controllers[i] == controller) _controllers.remove(i);
      await controller.dispose();
      if (mounted) setState(() => _failed.add(i));
      return;
    }

    // Page was trimmed / screen closed while loading.
    if (!mounted || _controllers[i] != controller) {
      await controller.dispose();
      return;
    }

    controller.setLooping(true);

    if (i == _current && !_paused) {
      controller.play();
    }

    setState(() {});
  }

  void _onPageChanged(int index) {
    for (final entry in _controllers.entries) {
      if (entry.key != index) entry.value.pause();
    }

    setState(() {
      _current = index;
      _paused = false;
    });

    _controllers[index]?.seekTo(Duration.zero);
    _controllers[index]?.play();

    _prepare(index);
    _prepare(index + 1);
    _prepare(index - 1);
    _recordView(index);

    // Keep only previous, current and next in memory.
    final far = _controllers.keys.where((k) => (k - index).abs() > 1).toList();
    for (final k in far) {
      _controllers.remove(k)?.dispose();
    }
  }

  void _togglePlay() {
    final c = _controllers[_current];
    if (c == null || !c.value.isInitialized) return;

    setState(() {
      if (c.value.isPlaying) {
        c.pause();
        _paused = true;
      } else {
        c.play();
        _paused = false;
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.videos.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) => _buildReel(index),
      ),
    );
  }

  Widget _buildReel(int index) {
    final data = widget.videos[index];
    final controller = _controllers[index];
    final ready = controller != null && controller.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        // VIDEO
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePlay,
          child: _failed.contains(index)
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, color: Colors.white54, size: 60),
                      SizedBox(height: 12),
                      Text(
                        'Could not load video.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                )
              : ready
                  ? _videoFill(controller)
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
        ),

        // PAUSE ICON
        if (index == _current && _paused)
          const IgnorePointer(
            child: Center(
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white70,
                size: 90,
              ),
            ),
          ),

        // BOTTOM GRADIENT
        const IgnorePointer(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 280,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
        ),

        // RIGHT ACTIONS
        Positioned(
          right: 10,
          bottom: 90,
          child: _ReelActions(
            key: ValueKey(data['id']),
            data: data,
          ),
        ),

        // BOTTOM INFO
        Positioned(
          left: 14,
          right: 80,
          bottom: 28,
          child: _ReelInfo(data: data),
        ),

        // SEEK BAR
        if (ready)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white30,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _videoFill(VideoPlayerController c) {
    final size = c.value.size;
    final isPortrait = size.height >= size.width;

    return SizedBox.expand(
      child: FittedBox(
        // Portrait videos fill the screen (like TikTok), landscape fit inside.
        fit: isPortrait ? BoxFit.cover : BoxFit.contain,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(c),
        ),
      ),
    );
  }
}

// ============================================================
// BOTTOM INFO (user, caption, product)
// ============================================================

class _ReelInfo extends StatefulWidget {
  final Map<String, dynamic> data;

  const _ReelInfo({required this.data});

  @override
  State<_ReelInfo> createState() => _ReelInfoState();
}

class _ReelInfoState extends State<_ReelInfo> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    final name =
        (d['userName'] ?? d['sellerName'] ?? 'BuyNova User').toString();
    final caption = (d['caption'] ?? '').toString();
    final avatar =
        (d['profileImageUrl'] ?? d['sellerProfileImageUrl'] ?? '').toString();

    final productName = (d['productName'] ?? '').toString();
    final productImage = (d['productImageUrl'] ?? '').toString();
    final productPrice = d['productPrice'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (productName.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: productImage.isNotEmpty
                      ? Image.network(
                          productImage,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _productFallback(),
                        )
                      : _productFallback(),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (productPrice is num)
                        Text(
                          '৳${productPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isEmpty
                  ? const Icon(Icons.person, color: Colors.white, size: 18)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              caption,
              maxLines: _expanded ? 12 : 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, height: 1.3),
            ),
          ),
        ],
      ],
    );
  }

  Widget _productFallback() {
    return Container(
      width: 42,
      height: 42,
      color: Colors.white24,
      child: const Icon(Icons.inventory_2_outlined, color: Colors.white),
    );
  }
}

// ============================================================
// RIGHT SIDE ACTIONS (like, views, share)
// ============================================================

class _ReelActions extends StatefulWidget {
  final Map<String, dynamic> data;

  const _ReelActions({super.key, required this.data});

  @override
  State<_ReelActions> createState() => _ReelActionsState();
}

class _ReelActionsState extends State<_ReelActions> {
  bool _liked = false;
  bool _busy = false;
  int _likeDelta = 0;

  String get _videoId => (widget.data['id'] ?? '').toString();

  DocumentReference<Map<String, dynamic>>? get _likeRef {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _videoId.isEmpty) return null;

    return FirebaseFirestore.instance
        .collection('sellerVideos')
        .doc(_videoId)
        .collection('likes')
        .doc(user.uid);
  }

  @override
  void initState() {
    super.initState();
    _loadLiked();
  }

  Future<void> _loadLiked() async {
    try {
      final ref = _likeRef;
      if (ref == null) return;

      final snap = await ref.get();

      if (!mounted) return;
      setState(() => _liked = snap.exists);
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    final ref = _likeRef;

    if (ref == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first.')),
      );
      return;
    }

    if (_busy) return;
    _busy = true;

    final wasLiked = _liked;

    // Optimistic update
    setState(() {
      _liked = !wasLiked;
      _likeDelta += wasLiked ? -1 : 1;
    });

    try {
      if (wasLiked) {
        await ref.delete();
      } else {
        await ref.set({'createdAt': FieldValue.serverTimestamp()});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _liked = wasLiked;
          _likeDelta += wasLiked ? 1 : -1;
        });
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _copyLink() async {
    final url = (widget.data['videoUrl'] ?? '').toString();
    if (url.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: url));

    // One doc per user: sellerVideos/{id}/shares/{uid} -> shareCount.
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _videoId.isNotEmpty) {
        final ref = FirebaseFirestore.instance
            .collection('sellerVideos')
            .doc(_videoId)
            .collection('shares')
            .doc(user.uid);
        final snap = await ref.get();
        if (!snap.exists) {
          await ref.set({'createdAt': FieldValue.serverTimestamp()});
        }
      }
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Video link copied.')),
    );
  }

  int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final likes = (_toInt(widget.data['likeCount'] ?? widget.data['likes']) +
            _likeDelta)
        .clamp(0, 1 << 31);
    final views = _toInt(widget.data['viewCount'] ?? widget.data['views']);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionButton(
          icon: _liked ? Icons.favorite : Icons.favorite_border,
          color: _liked ? Colors.redAccent : Colors.white,
          label: _fmt(likes),
          onTap: _toggleLike,
        ),
        const SizedBox(height: 18),
        _actionButton(
          icon: Icons.visibility_outlined,
          color: Colors.white,
          label: _fmt(views),
        ),
        const SizedBox(height: 18),
        _actionButton(
          icon: Icons.share,
          color: Colors.white,
          label: 'Share',
          onTap: _copyLink,
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Icon(icon, color: color, size: 34),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
