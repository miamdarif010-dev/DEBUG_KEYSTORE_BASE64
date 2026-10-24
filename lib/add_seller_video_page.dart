import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
  static const Duration _maxDuration = Duration(seconds: 90);
  static const Duration _uploadTimeout = Duration(minutes: 3);
  static const String _region = 'asia-northeast3';

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionController = TextEditingController();

  XFile? _selectedVideo;
  VideoPlayerController? _videoController;

  bool _isUploading = false;
  double _uploadProgress = 0.0;

  List<Map<String, dynamic>> _myProducts = [];
  bool _loadingProducts = false;

  String? _selectedProductId;
  String? _selectedProductName;
  double? _selectedProductPrice;
  String? _selectedProductImageUrl;

  @override
  void initState() {
    super.initState();
    _loadMyProducts();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
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
  // PICK VIDEO  (fixed: old controller is only disposed after the
  // new one is ready, and a failed initialize() no longer leaks)
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
      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      final old = _videoController;

      setState(() {
        _selectedVideo = video;
        _videoController = controller;
      });

      // Dispose the old one AFTER the UI no longer uses it.
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
  // CLOUDINARY
  // ============================================================

  Future<String> _uploadVideoToCloudinary(File file) async {
    try {
      final sigResult = await FirebaseFunctions.instanceFor(region: _region)
          .httpsCallable('getVideoUploadSignature')
          .call();

      final s = Map<String, dynamic>.from(sigResult.data as Map);

      if (mounted) setState(() => _uploadProgress = 0.2);

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/${s['cloudName']}/video/upload',
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

        throw Exception(
          'Cloudinary upload failed (HTTP ${streamed.statusCode}): $message',
        );
      }

      final secureUrl = (jsonDecode(body) as Map)['secure_url']?.toString();

      if (secureUrl == null || secureUrl.isEmpty) {
        throw Exception('Cloudinary did not return a video URL.');
      }

      if (mounted) setState(() => _uploadProgress = 0.82);

      return secureUrl;
    } on TimeoutException {
      throw Exception(
        'Video upload timed out. Please check your internet connection '
        'and try again.',
      );
    } on SocketException catch (e) {
      throw Exception('Network error while uploading video: $e');
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Server error (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Best effort cleanup when the upload worked but saving the record failed.
  /// Note: your `deleteCloudinaryVideo` function reads the Firestore doc to
  /// check the owner, so it must also accept a video whose doc doesn't exist
  /// yet (compare the public_id prefix with the caller's uid instead).
  Future<void> _cleanupOrphan(String videoId, String videoUrl) async {
    try {
      await FirebaseFunctions.instanceFor(region: _region)
          .httpsCallable('deleteCloudinaryVideo')
          .call(<String, dynamic>{
        'videoId': videoId,
        'videoUrl': videoUrl,
        'thumbnailUrl': _createThumbnailUrl(videoUrl),
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

  // ============================================================
  // PROFILE
  // ============================================================

  Future<Map<String, String>> _getUserProfileData(User user) async {
    String userName = '';
    String profileImageUrl = '';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();
      final n = data?['name']?.toString().trim();
      final img = data?['profileImageUrl']?.toString().trim();

      if (n != null && n.isNotEmpty) userName = n;
      if (img != null && img.isNotEmpty) profileImageUrl = img;
    } catch (_) {}

    if (userName.isEmpty) {
      final d = user.displayName?.trim();
      if (d != null && d.isNotEmpty) userName = d;
    }

    // NOTE: the email is NOT used as a public name any more.
    if (userName.isEmpty) userName = 'BuyNova User';

    return {'name': userName, 'profileImageUrl': profileImageUrl};
  }

  // ============================================================
  // POST
  // ============================================================

  Future<void> _postVideo() async {
    if (_isUploading) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _snack('Please login first.');
      return;
    }

    if (_selectedVideo == null) {
      _snack('Please select a video first.');
      return;
    }

    final caption = _captionController.text.trim();

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.05;
    });

    String? uploadedUrl;
    DocumentReference<Map<String, dynamic>>? videoRef;

    try {
      final uid = user.uid;
      final profile = await _getUserProfileData(user);
      final userName = profile['name'] ?? 'BuyNova User';
      final profileImageUrl = profile['profileImageUrl'] ?? '';

      if (mounted) setState(() => _uploadProgress = 0.10);

      uploadedUrl = await _uploadVideoToCloudinary(File(_selectedVideo!.path));

      if (mounted) setState(() => _uploadProgress = 0.88);

      final thumbnailUrl = _createThumbnailUrl(uploadedUrl);

      videoRef = FirebaseFirestore.instance.collection('sellerVideos').doc();

      // No userEmail here: this collection is readable by everyone.
      // Counters / moderation fields should be forced by Firestore rules
      // or set by a Cloud Function.
      final videoData = <String, dynamic>{
        'videoId': videoRef.id,
        'userId': uid,
        'sellerId': uid,
        'userName': userName,
        'sellerName': userName,
        'profileImageUrl': profileImageUrl,
        'sellerProfileImageUrl': profileImageUrl,
        'videoUrl': uploadedUrl,
        'thumbnailUrl': thumbnailUrl,
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

      await videoRef.set(videoData);

      if (mounted) setState(() => _uploadProgress = 1.0);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video posted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      // Upload worked but saving failed -> don't leave a stray file behind.
      if (uploadedUrl != null && videoRef != null) {
        await _cleanupOrphan(videoRef.id, uploadedUrl);
      }

      _snack('Could not post video:\n$e', seconds: 8);
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

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
  // UI
  // ============================================================

  Widget _buildPreview() {
    if (_selectedVideo == null) {
      return GestureDetector(
        onTap: _pickVideo,
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_library_outlined, size: 60),
                SizedBox(height: 12),
                Text(
                  'Select Video',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 6),
                Text(
                  'Vertical video works best • 60 MB • 90 seconds',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final c = _videoController;
    final ready = c != null && c.value.isInitialized;

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(18),
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
                    Icons.play_circle_fill,
                    size: 70,
                    color: Colors.white,
                  ),
                ),
              ),
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: _removeSelectedVideo,
                  icon: const Icon(Icons.close, color: Colors.white),
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
    final width = MediaQuery.of(context).size.width;

    return PopScope(
      canPop: !_isUploading,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isUploading) {
          _snack('Please wait until the video upload finishes.');
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Post Video'), centerTitle: true),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Reels-shaped preview, not taller than the screen allows.
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: width * 0.62),
                    child: _buildPreview(),
                  ),
                ),
                const SizedBox(height: 14),
                if (_selectedVideo != null)
                  OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickVideo,
                    icon: const Icon(Icons.video_file),
                    label: const Text('Change Video'),
                  ),
                const SizedBox(height: 14),
                TextField(
                  controller: _captionController,
                  maxLines: 4,
                  maxLength: 500,
                  enabled: !_isUploading,
                  decoration: InputDecoration(
                    labelText: 'Caption',
                    hintText: 'Write something about your video...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
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
                      labelText: 'Tag a Product',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('No product'),
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
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: (_selectedProductImageUrl != null &&
                                  _selectedProductImageUrl!.isNotEmpty)
                              ? Image.network(
                                  _selectedProductImageUrl!,
                                  width: 60,
                                  height: 60,
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_selectedProductPrice != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Text(
                                    '৳${_selectedProductPrice!.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
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
                  Text(
                    'Uploading video... '
                    '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _postVideo,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.publish_outlined),
                    label: Text(_isUploading ? 'Uploading...' : 'Post Video'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
      width: 60,
      height: 60,
      color: Colors.grey.shade300,
      child: const Icon(Icons.inventory_2_outlined),
    );
  }
}
