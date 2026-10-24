import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'video_player_page.dart';

/// Published videos of ONE user as a 3-column grid (TikTok profile style).
/// Tapping a video opens the full-screen reels pager at that video, and you
/// can swipe through the rest of the user's videos.
class UserVideosGrid extends StatefulWidget {
  final String userId;
  final bool isOwner;
  final VoidCallback? onUpload;
  final VoidCallback? onManage;

  const UserVideosGrid({
    super.key,
    required this.userId,
    this.isOwner = false,
    this.onUpload,
    this.onManage,
  });

  @override
  State<UserVideosGrid> createState() => _UserVideosGridState();
}

class _UserVideosGridState extends State<UserVideosGrid> {
  static const int _limit = 60;

  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildStream() {
    // Two equality filters only, so no composite index is needed.
    return FirebaseFirestore.instance
        .collection('sellerVideos')
        .where('userId', isEqualTo: widget.userId)
        .where('status', isEqualTo: 'published')
        .limit(_limit)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    _stream = _buildStream();
  }

  @override
  void didUpdateWidget(covariant UserVideosGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _stream = _buildStream();
    }
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }

  void _openVideo(List<Map<String, dynamic>> videos, int index) {
    if ((videos[index]['videoUrl'] ?? '').toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video URL is not available.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(videos: videos, initialIndex: index),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.black12,
      child: const Center(
        child: Icon(Icons.video_library_outlined, color: Colors.grey, size: 30),
      ),
    );
  }

  Widget _header(int count) {
    return Row(
      children: [
        const Icon(Icons.play_circle_fill, color: Colors.redAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            count == 0 ? 'Videos' : 'Videos ($count)',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        if (widget.isOwner && widget.onUpload != null)
          IconButton(
            tooltip: 'Upload video',
            visualDensity: VisualDensity.compact,
            onPressed: widget.onUpload,
            icon: const Icon(Icons.add_circle_outline, color: Colors.redAccent),
          ),
        if (widget.isOwner && widget.onManage != null)
          TextButton(onPressed: widget.onManage, child: const Text('Manage')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(0),
                const SizedBox(height: 10),
                const Text(
                  'Could not load videos.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(0),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }

          final docs = [...(snapshot.data?.docs ?? [])];

          // Newest first (sorted here, avoids a Firestore index).
          docs.sort((a, b) {
            final ta = a.data()['createdAt'];
            final tb = b.data()['createdAt'];
            final da = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
            final db = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
            return db.compareTo(da);
          });

          if (docs.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(0),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  child: Center(
                    child: Text(
                      widget.isOwner
                          ? 'You have not posted any video yet.'
                          : 'No videos yet.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                if (widget.isOwner && widget.onUpload != null)
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: widget.onUpload,
                      icon: const Icon(Icons.upload),
                      label: const Text('Post a video'),
                    ),
                  ),
              ],
            );
          }

          final videos = docs
              .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(docs.length),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: videos.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 0.62,
                ),
                itemBuilder: (context, index) {
                  final data = videos[index];
                  final thumb = (data['thumbnailUrl'] ?? '').toString();
                  final views = _toInt(data['viewCount'] ?? data['views']);

                  return GestureDetector(
                    onTap: () => _openVideo(videos, index),
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
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Colors.black87, Colors.transparent],
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 15,
                                  ),
                                  Text(
                                    _formatCount(views),
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
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
