import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'login_page.dart';
import 'cart_page.dart';
import 'add_seller_video_page.dart';
import 'watch_earn_page.dart';
import 'categories_page.dart';
import 'user_profile_page.dart';

class NewsFeedPage extends StatefulWidget {
  const NewsFeedPage({super.key});

  @override
  State<NewsFeedPage> createState() => _NewsFeedPageState();
}

class _NewsFeedPageState extends State<NewsFeedPage> {
  final PageController _pageController = PageController();

  int _currentPage = 0;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  void _openLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
    );
  }

  void _openPostVideo() {
    final user = currentUser;

    if (user == null) {
      _openLogin();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddSellerVideoPage(),
      ),
    );
  }

  void _openWatchEarn() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const WatchEarnPage(),
      ),
    );
  }

  void _onBottomNavigationTap(int index) {
    switch (index) {
      case 0:
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;

      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CategoriesPage(),
          ),
        );
        break;

      case 2:
        _openPostVideo();
        break;

      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CartPage(),
          ),
        );
        break;

      case 4:
        final user = currentUser;

        if (user == null) {
          _openLogin();
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfilePage(
                userId: user.uid,
              ),
            ),
          );
        }
        break;
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortVideos(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted =
        List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);

    sorted.sort((a, b) {
      final aTimestamp = a.data()['createdAt'];
      final bTimestamp = b.data()['createdAt'];

      DateTime aDate = DateTime.fromMillisecondsSinceEpoch(0);
      DateTime bDate = DateTime.fromMillisecondsSinceEpoch(0);

      if (aTimestamp is Timestamp) {
        aDate = aTimestamp.toDate();
      }

      if (bTimestamp is Timestamp) {
        bDate = bTimestamp.toDate();
      }

      return bDate.compareTo(aDate);
    });

    return sorted;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('sellerVideos')
              .where('status', isEqualTo: 'published')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState(
                snapshot.error.toString(),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              );
            }

            final docs = _sortVideos(
              snapshot.data?.docs ?? [],
            );

            if (docs.isEmpty) {
              return _buildEmptyState();
            }

            return Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: docs.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final data = _toMap(docs[index].data());

                    return _ReelsVideoItem(
                      key: ValueKey(docs[index].id),
                      videoId: docs[index].id,
                      data: data,
                      isActive: index == _currentPage,
                    );
                  },
                ),

                Positioned(
                  top: 12,
                  left: 12,
                  child: _watchEarnCircleButton(),
                ),

                Positioned(
                  top: 12,
                  right: 12,
                  child: _topButton(
                    icon: Icons.close,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                ),

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildVideoBottomNavigation(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Stack(
      children: [
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.video_library_outlined,
                color: Colors.white54,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'No videos available',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Be the first to upload a video.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: _watchEarnCircleButton(),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: _topButton(
            icon: Icons.close,
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildVideoBottomNavigation(),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 60,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unable to load videos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: _watchEarnCircleButton(),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: _topButton(
            icon: Icons.close,
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildVideoBottomNavigation(),
        ),
      ],
    );
  }

  Widget _buildVideoBottomNavigation() {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.72),
            Colors.black.withValues(alpha: 0.94),
          ],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _bottomNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Home',
              onTap: () => _onBottomNavigationTap(0),
            ),
          ),
          Expanded(
            child: _bottomNavItem(
              icon: Icons.grid_view_outlined,
              activeIcon: Icons.grid_view,
              label: 'Categories',
              onTap: () => _onBottomNavigationTap(1),
            ),
          ),
          SizedBox(
            width: 72,
            child: Center(
              child: _coloredPlusButton(),
            ),
          ),
          Expanded(
            child: _bottomNavItem(
              icon: Icons.shopping_cart_outlined,
              activeIcon: Icons.shopping_cart,
              label: 'Cart',
              onTap: () => _onBottomNavigationTap(3),
            ),
          ),
          Expanded(
            child: _bottomNavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profile',
              onTap: () => _onBottomNavigationTap(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _coloredPlusButton() {
    return GestureDetector(
      onTap: _openPostVideo,
      child: Container(
        width: 52,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF25F4EE),
              Colors.white,
              Color(0xFFFF0050),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withValues(alpha: 0.25),
              blurRadius: 8,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.pinkAccent.withValues(alpha: 0.20),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        padding: const EdgeInsets.all(2),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }

  Widget _watchEarnCircleButton() {
    return GestureDetector(
      onTap: _openWatchEarn,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white54,
            width: 1,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.card_giftcard,
              color: Colors.white,
              size: 21,
            ),
            SizedBox(height: 1),
            Text(
              'Earn',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Map<String, dynamic> _toMap(
    Map<String, dynamic>? value,
  ) {
    if (value == null) {
      return <String, dynamic>{};
    }

    return Map<String, dynamic>.from(value);
  }
}

class _ReelsVideoItem extends StatefulWidget {
  final String videoId;
  final Map<String, dynamic> data;
  final bool isActive;

  const _ReelsVideoItem({
    super.key,
    required this.videoId,
    required this.data,
    required this.isActive,
  });

  @override
  State<_ReelsVideoItem> createState() => _ReelsVideoItemState();
}

class _ReelsVideoItemState extends State<_ReelsVideoItem> {
  VideoPlayerController? _controller;
  Timer? _watchTimer;

  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isLoadingVideo = true;

  bool _isLiked = false;
  bool _isLoadingLike = false;

  bool _rewardClaimed = false;
  bool _rewardEligible = true;
  bool _isClaimingReward = false;

  bool _viewRecorded = false;

  int _watchSeconds = 0;
  final int _requiredWatchSeconds = 10;
  final int _rewardPoints = 5;

  int _likeCount = 0;
  int _commentCount = 0;
  int _viewCount = 0;
  int _shareCount = 0;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  String get _sellerId {
    return (widget.data['sellerId'] ??
            widget.data['userId'] ??
            '')
        .toString();
  }

  String get _sellerName {
    final value = (widget.data['sellerName'] ??
            widget.data['userName'] ??
            'User')
        .toString()
        .trim();

    return value.isEmpty ? 'User' : value;
  }

  String get _sellerProfileImageUrl {
    return (widget.data['sellerProfileImageUrl'] ??
            widget.data['profileImageUrl'] ??
            '')
        .toString();
  }

  String get _caption {
    return (widget.data['caption'] ?? '').toString();
  }

  String get _videoUrl {
    return (widget.data['videoUrl'] ?? '').toString();
  }

  String get _productId {
    return (widget.data['productId'] ?? '').toString();
  }

  String get _productName {
    return (widget.data['productName'] ?? '').toString();
  }

  String get _productImageUrl {
    return (widget.data['productImageUrl'] ?? '').toString();
  }

  double? get _productPrice {
    final value = widget.data['productPrice'];

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  int _readCounter(
    String newKey,
    String oldKey,
  ) {
    final newValue = widget.data[newKey];

    if (newValue is num) {
      return newValue.toInt();
    }

    final oldValue = widget.data[oldKey];

    if (oldValue is num) {
      return oldValue.toInt();
    }

    return 0;
  }

  @override
  void initState() {
    super.initState();

    _likeCount = _readCounter('likeCount', 'likesCount');
    _commentCount = _readCounter('commentCount', 'commentsCount');
    _viewCount = _readCounter('viewCount', 'viewsCount');
    _shareCount = _readCounter('shareCount', 'sharesCount');

    final rewardValue = widget.data['rewardEligible'];

    if (rewardValue is bool) {
      _rewardEligible = rewardValue;
    }

    _loadVideo();
    _checkLike();
    _checkReward();
  }

  @override
  void didUpdateWidget(covariant _ReelsVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _playVideo();
      } else {
        _pauseVideo();
      }

      _updateWatchTimer();
    }
  }

  Future<void> _loadVideo() async {
    if (_videoUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoadingVideo = false;
        });
      }
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(_videoUrl),
      );

      _controller = controller;

      await controller.initialize();

      controller.setLooping(true);
      controller.addListener(_videoListener);

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _isInitialized = true;
        _isLoadingVideo = false;
      });

      if (widget.isActive) {
        await _playVideo();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingVideo = false;
          _isInitialized = false;
        });
      }
    }
  }

  void _videoListener() {
    if (!mounted || _controller == null) {
      return;
    }

    final playing = _controller!.value.isPlaying;

    if (playing != _isPlaying) {
      setState(() {
        _isPlaying = playing;
      });

      _updateWatchTimer();
    }
  }

  Future<void> _playVideo() async {
    final controller = _controller;

    if (controller == null || !_isInitialized) {
      return;
    }

    try {
      await controller.play();

      if (mounted) {
        setState(() {
          _isPlaying = true;
        });
      }

      _recordView();
      _updateWatchTimer();
    } catch (_) {}
  }

  Future<void> _pauseVideo() async {
    final controller = _controller;

    if (controller == null) {
      return;
    }

    try {
      await controller.pause();

      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }

      _updateWatchTimer();
    } catch (_) {}
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) {
      return;
    }

    if (_controller!.value.isPlaying) {
      _pauseVideo();
    } else {
      _playVideo();
    }
  }

  void _updateWatchTimer() {
    _watchTimer?.cancel();

    if (!_rewardEligible ||
        _rewardClaimed ||
        !widget.isActive ||
        !_isPlaying) {
      return;
    }

    if (_watchSeconds >= _requiredWatchSeconds) {
      return;
    }

    _watchTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (!widget.isActive ||
            !_isPlaying ||
            _rewardClaimed ||
            !_rewardEligible) {
          timer.cancel();
          return;
        }

        if (_watchSeconds < _requiredWatchSeconds) {
          setState(() {
            _watchSeconds++;
          });
        }

        if (_watchSeconds >= _requiredWatchSeconds) {
          timer.cancel();
        }
      },
    );
  }

  Future<void> _checkReward() async {
    final user = currentUser;

    if (user == null || !_rewardEligible) {
      return;
    }

    try {
      final claimId = '${user.uid}_${widget.videoId}';

      final doc = await FirebaseFirestore.instance
          .collection('watchRewardClaims')
          .doc(claimId)
          .get();

      if (!mounted) {
        return;
      }

      if (doc.exists) {
        setState(() {
          _rewardClaimed = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _claimReward() async {
    final user = currentUser;

    if (user == null) {
      _showMessage('Please login to claim your reward.');
      return;
    }

    if (!_rewardEligible ||
        _rewardClaimed ||
        _watchSeconds < _requiredWatchSeconds ||
        _isClaimingReward) {
      return;
    }

    setState(() {
      _isClaimingReward = true;
    });

    try {
      final claimId = '${user.uid}_${widget.videoId}';

      final claimRef = FirebaseFirestore.instance
          .collection('watchRewardClaims')
          .doc(claimId);

      final existing = await claimRef.get();

      if (existing.exists) {
        if (mounted) {
          setState(() {
            _rewardClaimed = true;
            _isClaimingReward = false;
          });
        }
        return;
      }

      await claimRef.set({
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'videoId': widget.videoId,
        'status': 'pending',
        'source': 'watch_video',
        'watchSeconds': _watchSeconds,
        'requiredSeconds': _requiredWatchSeconds,
        'rewardPoints': _rewardPoints,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _rewardClaimed = true;
        _isClaimingReward = false;
      });

      _showMessage('Reward claim submitted.');
    } catch (_) {
      if (mounted) {
        setState(() {
          _isClaimingReward = false;
        });

        _showMessage('Unable to submit reward claim.');
      }
    }
  }

  Future<void> _checkLike() async {
    final user = currentUser;

    if (user == null) {
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('sellerVideos')
          .doc(widget.videoId)
          .collection('likes')
          .doc(user.uid)
          .get();

      if (!mounted) {
        return;
      }

      setState(() {
        _isLiked = doc.exists;
      });
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    final user = currentUser;

    if (user == null) {
      _showMessage('Please login to like this video.');
      return;
    }

    if (_isLoadingLike) {
      return;
    }

    setState(() {
      _isLoadingLike = true;
    });

    try {
      final videoRef = FirebaseFirestore.instance
          .collection('sellerVideos')
          .doc(widget.videoId);

      final likeRef = videoRef
          .collection('likes')
          .doc(user.uid);

      final sellerId = _sellerId;

      final sellerRef = sellerId.isEmpty
          ? null
          : FirebaseFirestore.instance
              .collection('users')
              .doc(sellerId);

      await FirebaseFirestore.instance.runTransaction(
        (transaction) async {
          final likeSnapshot = await transaction.get(likeRef);
          final videoSnapshot = await transaction.get(videoRef);

          final data = videoSnapshot.data() ?? {};

          int count = 0;

          if (data['likeCount'] is num) {
            count = (data['likeCount'] as num).toInt();
          } else if (data['likesCount'] is num) {
            count = (data['likesCount'] as num).toInt();
          }

          bool isLiking = true;

          if (likeSnapshot.exists) {
            transaction.delete(likeRef);

            if (count > 0) {
              count--;
            }

            isLiking = false;
          } else {
            transaction.set(likeRef, {
              'userId': user.uid,
              'createdAt': FieldValue.serverTimestamp(),
            });

            count++;
          }

          transaction.update(videoRef, {
            'likeCount': count,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          if (sellerRef != null) {
            transaction.set(
              sellerRef,
              {
                'totalLikes': FieldValue.increment(
                  isLiking ? 1 : -1,
                ),
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          }
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLiked = !_isLiked;

        if (_isLiked) {
          _likeCount++;
        } else if (_likeCount > 0) {
          _likeCount--;
        }

        _isLoadingLike = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingLike = false;
        });

        _showMessage('Unable to update like.');
      }
    }
  }

  Future<void> _recordView() async {
    if (_viewRecorded) {
      return;
    }

    _viewRecorded = true;

    final user = currentUser;

    try {
      final videoRef = FirebaseFirestore.instance
          .collection('sellerVideos')
          .doc(widget.videoId);

      final viewId = user?.uid ??
          'guest_${DateTime.now().millisecondsSinceEpoch}';

      final viewRef = videoRef
          .collection('views')
          .doc(viewId);

      final viewSnapshot = await viewRef.get();

      if (viewSnapshot.exists) {
        return;
      }

      final sellerId = _sellerId;

      final sellerRef = sellerId.isEmpty
          ? null
          : FirebaseFirestore.instance
              .collection('users')
              .doc(sellerId);

      await FirebaseFirestore.instance.runTransaction(
        (transaction) async {
          final videoSnapshot = await transaction.get(videoRef);

          if (!videoSnapshot.exists) {
            return;
          }

          final data = videoSnapshot.data() ?? {};

          int count = 0;

          if (data['viewCount'] is num) {
            count = (data['viewCount'] as num).toInt();
          } else if (data['viewsCount'] is num) {
            count = (data['viewsCount'] as num).toInt();
          }

          transaction.set(viewRef, {
            'userId': user?.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });

          transaction.update(videoRef, {
            'viewCount': count + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          if (sellerRef != null) {
            transaction.set(
              sellerRef,
              {
                'totalViews': FieldValue.increment(1),
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          }
        },
      );

      if (mounted) {
        setState(() {
          _viewCount++;
        });
      }
    } catch (_) {}
  }

  Future<void> _shareVideo() async {
    if (_videoUrl.isEmpty) {
      return;
    }

    try {
      await Share.share(
        'Check out this video on BuyNova:\n$_videoUrl',
      );

      await FirebaseFirestore.instance
          .collection('sellerVideos')
          .doc(widget.videoId)
          .update({
        'shareCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final sellerId = _sellerId;

      if (sellerId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(sellerId)
            .set(
          {
            'totalShares': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      if (mounted) {
        setState(() {
          _shareCount++;
        });
      }
    } catch (_) {}
  }

  Future<void> _showComments() async {
    final user = currentUser;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (_) {
        return _CommentsSheet(
          videoId: widget.videoId,
          sellerId: _sellerId,
          currentUser: user,
        );
      },
    );

    if (!mounted) {
      return;
    }

    try {
      final videoDoc = await FirebaseFirestore.instance
          .collection('sellerVideos')
          .doc(widget.videoId)
          .get();

      final data = videoDoc.data();

      if (data == null) {
        return;
      }

      if (data['commentCount'] is num) {
        setState(() {
          _commentCount =
              (data['commentCount'] as num).toInt();
        });
      }
    } catch (_) {}
  }

  Future<void> _openSellerProfile() async {
    if (_sellerId.isEmpty) {
      _showMessage('User profile is unavailable.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          userId: _sellerId,
          initialName: _sellerName,
          initialProfileImageUrl: _sellerProfileImageUrl,
        ),
      ),
    );
  }

  Future<void> _openProduct() async {
    if (_productId.isEmpty) {
      _showMessage('Product is unavailable.');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CartPage(),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    _watchTimer?.cancel();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildVideo(),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 390,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.10),
                      Colors.black.withValues(alpha: 0.88),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: 68,
            left: 15,
            child: _buildRewardButton(),
          ),

          Positioned(
            right: 12,
            bottom: 150,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionButton(
                  icon: _isLiked
                      ? Icons.favorite
                      : Icons.favorite_border,
                  label: _likeCount.toString(),
                  color: _isLiked ? Colors.red : Colors.white,
                  onTap: _toggleLike,
                ),
                const SizedBox(height: 18),
                _actionButton(
                  icon: Icons.comment_outlined,
                  label: _commentCount.toString(),
                  onTap: _showComments,
                ),
                const SizedBox(height: 18),
                _actionButton(
                  icon: Icons.share_outlined,
                  label: _shareCount.toString(),
                  onTap: _shareVideo,
                ),
                const SizedBox(height: 18),
                _actionButton(
                  icon: Icons.visibility_outlined,
                  label: _viewCount.toString(),
                  onTap: () {},
                ),
              ],
            ),
          ),

          Positioned(
            left: 15,
            right: 75,
            bottom: 88,
            child: _buildBottomInformation(),
          ),
        ],
      ),
    );
  }

  Widget _buildVideo() {
    if (_isLoadingVideo) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Center(
        child: Icon(
          Icons.video_library_outlined,
          color: Colors.white54,
          size: 70,
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio == 0
            ? 9 / 16
            : _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );
  }

  Widget _buildBottomInformation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _openSellerProfile,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _profileAvatar(),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _sellerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right,
                color: Colors.white70,
                size: 20,
              ),
            ],
          ),
        ),

        if (_caption.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _caption,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],

        if (_productId.isNotEmpty || _productName.isNotEmpty) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _openProduct,
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 310,
              ),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white24,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _productImage(),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          _productName.isEmpty
                              ? 'View product'
                              : _productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_productPrice != null)
                          Padding(
                            padding:
                                const EdgeInsets.only(top: 3),
                            child: Text(
                              'à§³${_productPrice!.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _profileAvatar() {
    if (_sellerProfileImageUrl.isEmpty) {
      return const CircleAvatar(
        radius: 22,
        backgroundColor: Colors.white24,
        child: Icon(
          Icons.person,
          color: Colors.white,
        ),
      );
    }

    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.white24,
      backgroundImage: NetworkImage(
        _sellerProfileImageUrl,
      ),
    );
  }

  Widget _productImage() {
    if (_productImageUrl.isEmpty) {
      return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.shopping_bag_outlined,
          color: Colors.white70,
          size: 23,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        _productImageUrl,
        width: 46,
        height: 46,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: 46,
            height: 46,
            color: Colors.white12,
            child: const Icon(
              Icons.image_not_supported_outlined,
              color: Colors.white54,
            ),
          );
        },
      ),
    );
  }

  Widget _buildRewardButton() {
    if (!_rewardEligible) {
      return const SizedBox.shrink();
    }

    if (_rewardClaimed) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white24,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.greenAccent,
              size: 18,
            ),
            SizedBox(width: 6),
            Text(
              'Claim Submitted',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_watchSeconds >= _requiredWatchSeconds) {
      return GestureDetector(
        onTap: _isClaimingReward ? null : _claimReward,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isClaimingReward)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              else
                const Icon(
                  Icons.card_giftcard,
                  color: Colors.black,
                  size: 18,
                ),
              const SizedBox(width: 6),
              Text(
                _isClaimingReward
                    ? 'Submitting'
                    : 'Claim +$_rewardPoints',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white24,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.card_giftcard,
            color: Colors.white,
            size: 17,
          ),
          const SizedBox(width: 6),
          Text(
            '$_watchSeconds/$_requiredWatchSeconds sec',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              shape: BoxShape.circle,
            ),
            child: _isLoadingLike &&
                    icon == Icons.favorite_border
                ? const Padding(
                    padding: EdgeInsets.all(13),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    icon,
                    color: color,
                    size: 25,
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final String videoId;
  final String sellerId;
  final User? currentUser;

  const _CommentsSheet({
    required this.videoId,
    required this.sellerId,
    required this.currentUser,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _commentController =
      TextEditingController();

  bool _sending = false;

  Future<void> _sendComment() async {
    final user = widget.currentUser;

    if (user == null) {
      _showMessage('Please login to comment.');
      return;
    }

    final text = _commentController.text.trim();

    if (text.isEmpty || _sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? {};

      final name =
          (userData['name'] ?? user.displayName ?? 'User')
              .toString();

      final profileImageUrl =
          (userData['profileImageUrl'] ?? '').toString();

      final videoRef = FirebaseFirestore.instance
          .collection('sellerVideos')
          .doc(widget.videoId);

      final commentRef =
          videoRef.collection('comments').doc();

      final sellerId = widget.sellerId;

      final sellerRef = sellerId.isEmpty
          ? null
          : FirebaseFirestore.instance
              .collection('users')
              .doc(sellerId);

      await FirebaseFirestore.instance.runTransaction(
        (transaction) async {
          final videoSnapshot =
              await transaction.get(videoRef);

          if (!videoSnapshot.exists) {
            throw Exception('Video not found');
          }

          final data = videoSnapshot.data() ?? {};

          int count = 0;

          if (data['commentCount'] is num) {
            count =
                (data['commentCount'] as num).toInt();
          } else if (data['commentsCount'] is num) {
            count =
                (data['commentsCount'] as num).toInt();
          }

          transaction.set(commentRef, {
            'commentId': commentRef.id,
            'userId': user.uid,
            'userName': name,
            'userEmail': user.email ?? '',
            'profileImageUrl': profileImageUrl,
            'text': text,
            'createdAt': FieldValue.serverTimestamp(),
          });

          transaction.update(videoRef, {
            'commentCount': count + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          if (sellerRef != null) {
            transaction.set(
              sellerRef,
              {
                'totalComments': FieldValue.increment(1),
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          }
        },
      );

      _commentController.clear();

      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
        });

        _showMessage('Unable to add comment.');
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            Container(
              width: 45,
              height: 5,
              margin:
                  const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const Text(
              'Comments',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('sellerVideos')
                    .doc(widget.videoId)
                    .collection('comments')
                    .orderBy(
                      'createdAt',
                      descending: true,
                    )
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Unable to load comments.',
                        style: TextStyle(
                          color: Colors.white54,
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No comments yet.',
                        style: TextStyle(
                          color: Colors.white54,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data();

                      final name =
                          (data['userName'] ?? 'User')
                              .toString();

                      final text =
                          (data['text'] ?? '').toString();

                      final imageUrl =
                          (data['profileImageUrl'] ?? '')
                              .toString();

                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            _commentAvatar(imageUrl),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding:
                                    const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style:
                                          const TextStyle(
                                        color: Colors.white,
                                        fontWeight:
                                            FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      text,
                                      style:
                                          const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (user == null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginPage(),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        'Login to comment',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  12,
                  8,
                  12,
                  12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Write a comment...',
                          hintStyle: const TextStyle(
                            color: Colors.white38,
                          ),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sending ? null : _sendComment,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: _sending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Icon(
                                Icons.send,
                                color: Colors.black,
                                size: 20,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _commentAvatar(String imageUrl) {
    if (imageUrl.isEmpty) {
      return const CircleAvatar(
        radius: 19,
        backgroundColor: Colors.white24,
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: 20,
        ),
      );
    }

    return CircleAvatar(
      radius: 19,
      backgroundImage: NetworkImage(imageUrl),
      backgroundColor: Colors.white24,
    );
  }
}
