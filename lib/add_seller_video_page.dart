import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class AddSellerVideoPage extends StatefulWidget {
  const AddSellerVideoPage({super.key});

  @override
  State<AddSellerVideoPage> createState() => _AddSellerVideoPageState();
}

class _AddSellerVideoPageState extends State<AddSellerVideoPage> {
  static const int _maxVideoBytes = 60 * 1024 * 1024;
  static const int _maxAudioBytes = 10 * 1024 * 1024;
  static const int _maxPhotos = 5;
  static const Duration _maxDuration = Duration(seconds: 90);
  static const Duration _uploadTimeout = Duration(minutes: 3);
  static const String _region = 'asia-northeast3';

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionController = TextEditingController();

  // VIDEO (or photos, never both)
  XFile? _selectedVideo;
  VideoPlayerController? _videoController;

  // PHOTOS
  List<XFile> _photos = [];
  final PageController _photoPageController = PageController();
  int _currentPhotoIndex = 0;

  // MUSIC (optional, works with video and photos)
  File? _audioFile;
  String? _audioName;
  final AudioPlayer _previewPlayer = AudioPlayer();
  bool _previewPlaying = false;

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _isMuted = false;

  List<Map<String, dynamic>> _myProducts = [];
  bool _loadingProducts = false;

  String? _selectedProductId;
  String? _selectedProductName;
  double? _selectedProductPrice;
  String? _selectedProductImageUrl;

  bool get _hasMedia => _selectedVideo != null || _photos.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadMyProducts();

    _previewPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _previewPlaying = false);
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    _photoPageController.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  // ============================================================
  // PRODUCTS
  // ============================================================

  Future<void> _loadMyProducts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (mounted) setState(() => _loadingProducts = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: user.uid)
          .get();

      final products = snapshot.docs
          .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
          .toList();

      if (!mounted) return;
      setState(() => _myProducts = products);
    } catch (e) {
      _snack('Could not load products: $e');
    } finally {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  void _selectProduct(String? productId) {
    if (productId == null) {
      setState(() {
        _selectedProductId = null;
        _selectedProductName = null;
        _selectedProductPrice = null;
        _selectedProductImageUrl = null;
      });
      return;
    }

    Map<String, dynamic>? chosen;
    for (final p in _myProducts) {
      if (p['id'] == productId) {
        chosen = p;
        break;
      }
    }
    if (chosen == null) return;

    final c = chosen;

    setState(() {
      _selectedProductId = productId;
      _selectedProductName = (c['name'] ?? 'Product').toString();
      _selectedProductPrice = _toDouble(c['price']);
      _selectedProductImageUrl = c['imageUrl']?.toString();
    });
  }

  // ============================================================
  // PICK VIDEO
  // ============================================================

  Future<void> _pickVideo() async {
    if (_isUploading) return;

    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: _maxDuration,
      );

      if (video == null) return;

      final file = File(video.path);

      if (await file.length() > _maxVideoBytes) {
        _snack('Video size must be 60 MB or less.');
        return;
      }

      final controller = VideoPlayerController.file(file);

      try {
        await controller.initialize();
      } catch (e) {
        await controller.dispose();
        rethrow;
      }

      if (controller.value.duration > _maxDuration) {
        await controller.dispose();
        _snack('Video must be 90 seconds or less.');
        return;
      }

      controller.setLooping(true);
      await controller.setVolume(_audioFile != null || _isMuted ? 0 : 1);
      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      final old = _videoController;

      setState(() {
        _selectedVideo = video;
        _videoController = controller;
        _photos = []; // video and photos never together
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        old?.dispose();
      });
    } catch (e) {
      _snack('Could not select video: $e');
    }
  }

  Future<void> _removeSelectedVideo() async {
    if (_isUploading) return;

    final old = _videoController;

    setState(() {
      _videoController = null;
      _selectedVideo = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      old?.dispose();
    });
  }

  // ============================================================
  // PICK PHOTOS
  // ============================================================

  Future<void> _pickPhotos() async {
    if (_isUploading) return;

    try {
      final imgs = await _picker.pickMultiImage(limit: _maxPhotos);

      if (imgs.isEmpty) return;

      for (final img in imgs) {
        if (await File(img.path).length() > 10 * 1024 * 1024) {
          _snack('Each photo must be 10 MB or less.');
          return;
        }
      }

      if (!mounted) return;

      final old = _videoController;

      setState(() {
        _photos = imgs.take(_maxPhotos).toList();
        _selectedVideo = null; // photos and video never together
        _videoController = null;
        _currentPhotoIndex = 0;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        old?.dispose();
      });
    } catch (e) {
      _snack('Could not select photos: $e');
    }
  }

  void _removePhotos() {
    if (_isUploading) return;
    setState(() => _photos = []);
  }

  // ============================================================
  // MUSIC
  // ============================================================

  Future<void> _pickMusic() async {
    if (_isUploading) return;

    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.audio);
      final picked = res?.files.single;
      final path = picked?.path;

      if (picked == null || path == null) return;

      final f = File(path);

      if (await f.length() > _maxAudioBytes) {
        _snack('Music must be 10 MB or less.');
        return;
      }

      await _previewPlayer.stop();

      if (!mounted) return;

      setState(() {
        _audioFile = f;
        _audioName = picked.name;
        _previewPlaying = false;
      });

      // Video's own sound off while background music is selected.
      _videoController?.setVolume(0);
    } catch (e) {
      _snack('Could not select music: $e');
    }
  }

  Future<void> _removeMusic() async {
    if (_isUploading) return;

    await _previewPlayer.stop();

    if (!mounted) return;

    setState(() {
      _audioFile = null;
      _audioName = null;
      _previewPlaying = false;
    });

    if (!_isMuted) {
      _videoController?.setVolume(1);
    }
  }

  Future<void> _togglePreviewMusic() async {
    final f = _audioFile;
    if (f == null) return;

    try {
      if (_previewPlaying) {
        await _previewPlayer.pause();
        if (mounted) setState(() => _previewPlaying = false);
      } else {
        await _previewPlayer.play(DeviceFileSource(f.path));
        if (mounted) setState(() => _previewPlaying = true);
      }
    } catch (e) {
      _snack('Could not play music: $e');
    }
  }

  // ============================================================
  // CLOUDINARY UPLOAD
  // ============================================================

  Future<String> _uploadToCloudinary(
    File file, {
    String resource = 'video',
  }) async {
    try {
      final sigResult = await FirebaseFunctions.instanceFor(region: _region)
          .httpsCallable('getVideoUploadSignature')
          .call();

      final s = Map<String, dynamic>.from(sigResult.data as Map);

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/${s['cloudName']}/$resource/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['api_key'] = s['apiKey'].toString()
        ..fields['timestamp'] = s['timestamp'].toString()
        ..fields['signature'] = s['signature'].toString()
        ..fields['public_id'] = s['publicId'].toString()
        ..fields['overwrite'] = 'false'
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamed = await request.send().timeout(_uploadTimeout);
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        String message = body;
        try {
          final d = jsonDecode(body);
          if (d is Map && d['error'] is Map) {
            message = d['error']['message']?.toString() ?? body;
          }
        } catch (_) {}

        throw Exception('Cloudinary upload failed: $message');
      }

      final secureUrl = (jsonDecode(body) as Map)['secure_url']?.toString();

      if (secureUrl == null || secureUrl.isEmpty) {
        throw Exception('Cloudinary did not return a URL.');
      }

      return secureUrl;
    } on TimeoutException {
      throw Exception('Upload timed out. Please check your connection.');
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _cleanupOrphan(String videoId, String url) async {
    try {
      await FirebaseFunctions.instanceFor(region: _region)
          .httpsCallable('deleteCloudinaryVideo')
          .call(<String, dynamic>{
        'videoId': videoId,
        'videoUrl': url,
        'thumbnailUrl': _createThumbnailUrl(url),
      });
    } catch (e) {
      debugPrint('Orphan cleanup failed: $e');
    }
  }

  String _createThumbnailUrl(String videoUrl) {
    try {
      final uri = Uri.parse(videoUrl);
      final path = uri.path;

      if (!path.contains('/video/upload/')) return videoUrl;

      final thumbPath =
          path.replaceFirst('/video/upload/', '/video/upload/so_0/');
      final lastDot = thumbPath.lastIndexOf('.');
      final finalPath = lastDot != -1
          ? '${thumbPath.substring(0, lastDot)}.jpg'
          : '$thumbPath.jpg';

      return uri.replace(path: finalPath).toString();
    } catch (_) {
      return videoUrl;
    }
  }

  Future<Map<String, String>> _getUserProfileData(User user) async {
    String userName = '';
    String profileImageUrl = '';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();
      userName = data?['name']?.toString().trim() ?? '';
      profileImageUrl = data?['profileImageUrl']?.toString().trim() ?? '';
    } catch (_) {}

    if (userName.isEmpty) {
      final d = user.displayName?.trim() ?? '';
      userName = d.isEmpty ? 'BuyNova User' : d;
    }

    return {'name': userName, 'profileImageUrl': profileImageUrl};
  }

  // ============================================================
  // POST METHOD
  // ============================================================

  Future<void> _postVideo() async {
    if (_isUploading) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('Please login first.');
      return;
    }

    if (!_hasMedia) {
      _snack('Please select a video or photos first.');
      return;
    }

    final caption = _captionController.text.trim();
    final isPhoto = _photos.isNotEmpty;

    await _previewPlayer.stop();

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.05;
      _previewPlaying = false;
    });

    final cleanupUrls = <String>[];
    DocumentReference<Map<String, dynamic>>? videoRef;

    try {
      final profile = await _getUserProfileData(user);
      final userName = profile['name'] ?? 'BuyNova User';
      final profileImageUrl = profile['profileImageUrl'] ?? '';

      final totalFiles =
          (isPhoto ? _photos.length : 1) + (_audioFile != null ? 1 : 0);
      var doneFiles = 0;

      void step() {
        doneFiles++;
        if (mounted) {
          setState(() {
            _uploadProgress = 0.10 + 0.78 * (doneFiles / totalFiles);
          });
        }
      }

      String videoUrl = '';
      final imageUrls = <String>[];
      String audioUrl = '';

      if (isPhoto) {
        for (final p in _photos) {
          imageUrls
              .add(await _uploadToCloudinary(File(p.path), resource: 'image'));
          step();
        }
      } else {
        videoUrl = await _uploadToCloudinary(File(_selectedVideo!.path));
        cleanupUrls.add(videoUrl);
        step();
      }

      if (_audioFile != null) {
        audioUrl = await _uploadToCloudinary(_audioFile!);
        cleanupUrls.add(audioUrl);
        step();
      }

      if (mounted) setState(() => _uploadProgress = 0.9);

      final ref = FirebaseFirestore.instance.collection('sellerVideos').doc();
      videoRef = ref;

      final videoData = <String, dynamic>{
        'videoId': ref.id,
        'userId': user.uid,
        'sellerId': user.uid,
        'userName': userName,
        'sellerName': userName,
        'profileImageUrl': profileImageUrl,
        'sellerProfileImageUrl': profileImageUrl,
        'mediaType': isPhoto ? 'photo' : 'video',
        'videoUrl': videoUrl,
        'imageUrls': imageUrls,
        'thumbnailUrl':
            isPhoto ? imageUrls.first : _createThumbnailUrl(videoUrl),
        'audioUrl': audioUrl,
        'audioName': _audioName ?? '',
        'caption': caption,
        'status': 'published',
        'moderationStatus': 'approved',
        'likeCount': 0,
        'commentCount': 0,
        'viewCount': 0,
        'shareCount': 0,
        'rewardEligible': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_selectedProductId != null) {
        videoData['productId'] = _selectedProductId;
        videoData['productName'] = _selectedProductName;
        videoData['productPrice'] = _selectedProductPrice;
        videoData['productImageUrl'] = _selectedProductImageUrl;
      }

      await ref.set(videoData);

      if (mounted) setState(() => _uploadProgress = 1.0);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post published successfully!'),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      final failedRef = videoRef;

      if (failedRef != null) {
        for (final url in cleanupUrls) {
          await _cleanupOrphan(failedRef.id, url);
        }
      }
      _snack('Could not post:\n$e', seconds: 6);
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  void _snack(String message, {int seconds = 3}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: Duration(seconds: seconds)),
    );
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  // ============================================================
  // UI COMPONENTS
  // ============================================================

  Widget _buildEmptyPreview() {
    return GestureDetector(
      onTap: _pickVideo,
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.movie_creation_outlined,
                  size: 56, color: Colors.white54),
              SizedBox(height: 12),
              Text(
                'Select Video or Photos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '9:16 Vertical works best\nMax 60MB • Up to 5 Photos',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPreview() {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _photoPageController,
              itemCount: _photos.length,
              onPageChanged: (i) => setState(() => _currentPhotoIndex = i),
              itemBuilder: (context, i) {
                return Image.file(File(_photos[i].path), fit: BoxFit.cover);
              },
            ),

            // Top Badges
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.photo_library,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      '${_currentPhotoIndex + 1}/${_photos.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Dots Indicator at Bottom
            if (_photos.length > 1)
              Positioned(
                bottom: 15,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _photos.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentPhotoIndex == index ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _currentPhotoIndex == index
                            ? Colors.white
                            : Colors.white38,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),

            // Remove Button
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                radius: 18,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: _removePhotos,
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_photos.isNotEmpty) return _buildPhotoPreview();
    if (_selectedVideo == null) return _buildEmptyPreview();

    final c = _videoController;
    final ready = c != null && c.value.isInitialized;

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (ready)
              GestureDetector(
                onTap: () {
                  setState(() {
                    c.value.isPlaying ? c.pause() : c.play();
                  });
                },
                child: FittedBox(
                  fit: c.value.size.height >= c.value.size.width
                      ? BoxFit.cover
                      : BoxFit.contain,
                  child: SizedBox(
                    width: c.value.size.width,
                    height: c.value.size.height,
                    child: VideoPlayer(c),
                  ),
                ),
              ),
            if (ready && !c.value.isPlaying)
              const IgnorePointer(
                child: Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    size: 64,
                    color: Colors.white70,
                  ),
                ),
              ),

            // Mute / Unmute Button
            Positioned(
              left: 10,
              top: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                radius: 18,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _isMuted = !_isMuted;
                      c?.setVolume(_isMuted || _audioFile != null ? 0 : 1);
                    });
                  },
                  icon: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),

            // Close Button
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                radius: 18,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: _removeSelectedVideo,
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaButtons() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: _isUploading ? null : _pickVideo,
              icon: const Icon(Icons.videocam_rounded, size: 20),
              label: const Text('Video',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                foregroundColor:
                    _selectedVideo != null ? Colors.deepPurple : Colors.black87,
              ),
            ),
          ),
          Container(height: 20, width: 1, color: Colors.grey.shade300),
          Expanded(
            child: TextButton.icon(
              onPressed: _isUploading ? null : _pickPhotos,
              icon: const Icon(Icons.photo_library_rounded, size: 20),
              label: const Text('Photos',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                foregroundColor:
                    _photos.isNotEmpty ? Colors.deepPurple : Colors.black87,
              ),
            ),
          ),
          Container(height: 20, width: 1, color: Colors.grey.shade300),
          Expanded(
            child: TextButton.icon(
              onPressed: _isUploading ? null : _pickMusic,
              icon: const Icon(Icons.music_note_rounded, size: 20),
              label: const Text('Music',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                foregroundColor:
                    _audioFile != null ? Colors.deepPurple : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicTile() {
    if (_audioName == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurple.shade100),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _isUploading ? null : _togglePreviewMusic,
            icon: Icon(
              _previewPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
              size: 32,
              color: Colors.deepPurple,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BACKGROUND MUSIC',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                Text(
                  _audioName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isUploading ? null : _removeMusic,
            icon: const Icon(Icons.close_rounded,
                color: Colors.redAccent, size: 20),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return PopScope(
      canPop: !_isUploading,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isUploading) {
          _snack('Please wait until the upload finishes.');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Create Post',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: width * 0.58),
                    child: _buildPreview(),
                  ),
                ),
                const SizedBox(height: 16),
                _buildMediaButtons(),
                _buildMusicTile(),
                const SizedBox(height: 16),
                TextField(
                  controller: _captionController,
                  maxLines: 3,
                  maxLength: 500,
                  enabled: !_isUploading,
                  decoration: InputDecoration(
                    labelText: 'Caption',
                    hintText: 'Share something interesting about your post...',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_loadingProducts)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _selectedProductId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Tag a Product (Optional)',
                      prefixIcon: const Icon(Icons.shopping_bag_outlined),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('No product tagged'),
                      ),
                      ..._myProducts.map((p) {
                        return DropdownMenuItem<String>(
                          value: p['id'].toString(),
                          child: Text(
                            p['name']?.toString() ?? 'Product',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: _isUploading ? null : _selectProduct,
                  ),
                if (_selectedProductId != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: (_selectedProductImageUrl != null &&
                                  _selectedProductImageUrl!.isNotEmpty)
                              ? Image.network(
                                  _selectedProductImageUrl!,
                                  width: 54,
                                  height: 54,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _imgFallback(),
                                )
                              : _imgFallback(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedProductName ?? 'Product',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              if (_selectedProductPrice != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '৳${_selectedProductPrice!.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_isUploading) ...[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Uploading post...',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _postVideo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send_rounded, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Post Now',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imgFallback() {
    return Container(
      width: 54,
      height: 54,
      color: Colors.grey.shade200,
      child: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
    );
  }
}
