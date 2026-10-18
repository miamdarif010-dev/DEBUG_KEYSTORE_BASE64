import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'video_player_page.dart';

/// Shows the published videos of ONE user (from the `sellerVideos`
/// collection, the same one the Videos/Reels feed uses) as a grid.
///
/// Used on the profile page:
///  - own profile  -> isOwner: true  (shows [headerAction], e.g. "Manage")
///  - other's page -> isOwner: false
class UserVideosGrid extends StatelessWidget {
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

  int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }

    return value.toString();
  }

  void _openVideo(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final videoUrl = (data['videoUrl'] ?? '').toString();

    if (videoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video URL is not available.'),
        ),
      );
      return;
    }

    final name = (data['userName'] ??
            data['sellerName'] ??
            'BuyNova User')
        .toString();

    final caption = (data['caption'] ?? '').toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          videoUrl: videoUrl,
          sellerName: name,
          caption: caption,
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.black12,
      child: const Center(
        child: Icon(
          Icons.video_library_outlined,
          color: Colors.grey,
          size: 30,
        ),
      ),
    );
  }

  Widget _header(int count) {
    return Row(
      children: [
        const Icon(
          Icons.play_circle_fill,
          color: Colors.redAccent,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            count == 0 ? 'Videos' : 'Videos ($count)',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (isOwner && onUpload != null)
          IconButton(
            tooltip: 'Upload video',
            visualDensity: VisualDensity.compact,
            onPressed: onUpload,
            icon: const Icon(
              Icons.add_circle_outline,
              color: Colors.redAccent,
            ),
          ),
        if (isOwner && onManage != null)
          TextButton(
            onPressed: onManage,
            child: const Text('Manage'),
          ),
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
      // Two equality filters only, so no composite index is needed.
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('sellerVideos')
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'published')
            .snapshots(),
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

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(0),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
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
                      isOwner
                          ? 'You have not posted any video yet.'
                          : 'No videos yet.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                if (isOwner && onUpload != null)
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: onUpload,
                      icon: const Icon(Icons.upload),
                      label: const Text('Post a video'),
                    ),
                  ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(docs.length),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 0.62,
                ),
                itemBuilder: (context, index) {
                  final data = docs[index].data();

                  final thumbnailUrl =
                      (data['thumbnailUrl'] ?? '').toString();

                  final views = _toInt(
                    data['viewCount'] ?? data['views'],
                  );

                  return GestureDetector(
                    onTap: () => _openVideo(context, data),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (thumbnailUrl.isNotEmpty)
                            Image.network(
                              thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _placeholder(),
                            )
                          else
                            _placeholder(),
                          const Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
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
                                  colors: [
                                    Colors.black87,
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.visibility_outlined,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 3),
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
