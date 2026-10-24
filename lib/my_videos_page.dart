import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'add_seller_video_page.dart';
import 'video_player_page.dart';

class MyVideosPage extends StatefulWidget {
  const MyVideosPage({super.key});

  @override
  State<MyVideosPage> createState() => _MyVideosPageState();
}

class _MyVideosPageState extends State<MyVideosPage> {
  User? get currentUser => FirebaseAuth.instance.currentUser;

  static const int _videoLimit = 100;

  final Set<String> _deletingIds = {};

  // Created once, so setState() doesn't re-subscribe and flash a spinner.
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _buildStream();
  }

  // where() + orderBy() needs a composite index (userId ASC, createdAt DESC).
  Stream<QuerySnapshot<Map<String, dynamic>>> _buildStream() {
    final user = currentUser;

    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('sellerVideos')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(_videoLimit)
        .snapshots();
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _openAddVideo() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddSellerVideoPage()),
    );
  }

  void _openVideo(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      int index) {
    final videos = docs
        .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
        .toList();

    if ((videos[index]['videoUrl'] ?? '').toString().isEmpty) {
      _snack('Video URL is not available.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(videos: videos, initialIndex: index),
      ),
    );
  }

  Future<void> _editCaption(String videoId, String current) async {
    final newText = await showDialog<String>(
      context: context,
      builder: (_) => _CaptionDialog(initial: current),
    );

    if (newText == null || newText == current) return;

    try {
      await FirebaseFirestore.instance
          .collection('sellerVideos')
          .doc(videoId)
          .update({
        'caption': newText,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _snack('Caption updated.');
    } catch (e) {
      _snack('Could not update caption: $e');
    }
  }

  Future<void> _deleteVideo(String videoId) async {
    final user = currentUser;
    if (user == null || _deletingIds.contains(videoId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Video'),
        content: const Text('Are you sure you want to delete this video?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingIds.add(videoId));

    try {
      final videoRef =
          FirebaseFirestore.instance.collection('sellerVideos').doc(videoId);

      final videoDoc = await videoRef.get();

      if (!videoDoc.exists) {
        _snack('Video no longer exists.');
        return;
      }

      final data = videoDoc.data();
      final ownerId = (data?['userId'] ?? '').toString();
      final sellerId = (data?['sellerId'] ?? '').toString();

      if (ownerId != user.uid && sellerId != user.uid) {
        _snack('You can only delete your own videos.');
        return;
      }

      final videoUrl = (data?['videoUrl'] ?? '').toString();
      final thumbnailUrl = (data?['thumbnailUrl'] ?? '').toString();

      // Cloudinary first (the function reads this doc to check the owner),
      // then the Firestore record.
      if (videoUrl.isNotEmpty) {
        try {
          await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
              .httpsCallable('deleteCloudinaryVideo')
              .call(<String, dynamic>{
            'videoId': videoId,
            'videoUrl': videoUrl,
            'thumbnailUrl': thumbnailUrl,
          });
        } catch (e) {
          debugPrint('Cloudinary cleanup failed: $e');
        }
      }

      await videoRef.delete();

      _snack('Video deleted successfully.');
    } catch (e) {
      _snack('Could not delete video: $e');
    } finally {
      if (mounted) setState(() => _deletingIds.remove(videoId));
    }
  }

  void _snack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatCount(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  // ============================================================
  // GRID TILE
  // ============================================================

  Widget _tile(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int index,
  ) {
    final doc = docs[index];
    final data = doc.data();

    final thumb = (data['thumbnailUrl'] ?? '').toString();
    final caption = (data['caption'] ?? '').toString();
    final status = (data['status'] ?? 'published').toString();
    final views = _toInt(data['viewCount'] ?? data['views']);
    final likes = _toInt(data['likeCount'] ?? data['likes']);
    final deleting = _deletingIds.contains(doc.id);

    return GestureDetector(
      onTap: deleting ? null : () => _openVideo(docs, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumb.isNotEmpty)
              Image.network(
                thumb,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            else
              _placeholder(),

            // bottom stats
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.play_arrow,
                        color: Colors.white, size: 15),
                    Text(
                      _formatCount(views),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.favorite,
                        color: Colors.white, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      _formatCount(likes),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // status badge (only when not published)
            if (status != 'published')
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

            // menu
            Positioned(
              top: 2,
              right: 2,
              child: deleting
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          color: Colors.white, size: 20),
                      onSelected: (v) {
                        if (v == 'edit') _editCaption(doc.id, caption);
                        if (v == 'delete') _deleteVideo(doc.id);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit caption'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.black12,
      child: const Center(
        child: Icon(Icons.video_library_outlined, size: 32, color: Colors.grey),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 70),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.video_library_outlined,
                size: 72, color: Colors.grey),
            const SizedBox(height: 18),
            const Text(
              'No Videos Yet',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload your first BuyNova video and it will appear here '
              'and in the main Videos feed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _openAddVideo,
              icon: const Icon(Icons.add),
              label: const Text('Upload Video'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Videos'), centerTitle: true),
        body: const Center(child: Text('Please log in to view your videos.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Videos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _openAddVideo,
            icon: const Icon(Icons.add),
            tooltip: 'Upload Video',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 55, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    const Text(
                      'Could not load your videos.',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _stream = _buildStream()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) return _emptyState();

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: docs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 0.62,
            ),
            itemBuilder: (context, index) => _tile(docs, index),
          );
        },
      ),
    );
  }
}

/// Own StatefulWidget so the controller is disposed together with the
/// dialog (disposing it right after showDialog() can crash during the
/// close animation).
class _CaptionDialog extends StatefulWidget {
  final String initial;

  const _CaptionDialog({required this.initial});

  @override
  State<_CaptionDialog> createState() => _CaptionDialogState();
}

class _CaptionDialogState extends State<_CaptionDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Caption'),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        maxLength: 500,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
