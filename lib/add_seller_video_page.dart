import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class AddSellerVideoPage extends StatefulWidget {
  const AddSellerVideoPage({super.key});

  @override
  State<AddSellerVideoPage> createState() =>
      _AddSellerVideoPageState();
}

class _AddSellerVideoPageState
    extends State<AddSellerVideoPage> {
  // ============================================================
  // CLOUDINARY
  // ============================================================

  static const String _cloudName = 'riassg6d';

  static const String _uploadPreset =
      'buynova_products';

  static const int _maxVideoBytes =
      60 * 1024 * 1024;

  static const Duration _uploadTimeout =
      Duration(minutes: 3);

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final ImagePicker _picker = ImagePicker();

  final TextEditingController _captionController =
      TextEditingController();

  // ============================================================
  // VIDEO
  // ============================================================

  XFile? _selectedVideo;

  VideoPlayerController? _videoController;

  bool _isUploading = false;

  double _uploadProgress = 0.0;

  // ============================================================
  // PRODUCTS
  // ============================================================

  List<Map<String, dynamic>> _myProducts = [];

  bool _loadingProducts = false;

  String? _selectedProductId;
  String? _selectedProductName;
  double? _selectedProductPrice;
  String? _selectedProductImageUrl;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadMyProducts();
  }

  // ============================================================
  // LOAD MY PRODUCTS
  // ============================================================

  Future<void> _loadMyProducts() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _loadingProducts = true;
      });
    }

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('products')
              .where(
                'sellerId',
                isEqualTo: user.uid,
              )
              .get();

      final products =
          snapshot.docs.map((doc) {
        final data = doc.data();

        return <String, dynamic>{
          'id': doc.id,
          ...data,
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _myProducts = products;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not load products: $e',
          ),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _loadingProducts = false;
      });
    }
  }

  // ============================================================
  // PICK VIDEO
  // ============================================================

  Future<void> _pickVideo() async {
    if (_isUploading) return;

    try {
      final XFile? video =
          await _picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (video == null) {
        return;
      }

      final file = File(video.path);

      final fileSize =
          await file.length();

      if (fileSize > _maxVideoBytes) {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Video size must be 60 MB or less.',
            ),
          ),
        );

        return;
      }

      await _videoController?.dispose();

      final controller =
          VideoPlayerController.file(file);

      await controller.initialize();

      final duration =
          controller.value.duration;

      if (duration >
          const Duration(seconds: 90)) {
        await controller.dispose();

        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Video must be 90 seconds or less.',
            ),
          ),
        );

        return;
      }

      controller.setLooping(true);

      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _selectedVideo = video;
        _videoController = controller;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not select video: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // SELECT PRODUCT
  // ============================================================

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

    Map<String, dynamic>? selected;

    for (final product in _myProducts) {
      if (product['id'] == productId) {
        selected = product;
        break;
      }
    }

    if (selected == null) {
      return;
    }

    setState(() {
      _selectedProductId = productId;

      _selectedProductName =
          (selected!['name'] ?? 'Product')
              .toString();

      _selectedProductPrice =
          _toDouble(selected['price']);

      _selectedProductImageUrl =
          selected['imageUrl']?.toString();
    });
  }

  // ============================================================
  // CLOUDINARY UPLOAD
  // ============================================================

  Future<String?> _uploadVideoToCloudinary(
    File file,
  ) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/'
      '$_cloudName/video/upload',
    );

    http.Client? client;

    try {
      final multipartRequest =
          http.MultipartRequest(
        'POST',
        uri,
      );

      multipartRequest.fields[
              'upload_preset'] =
          _uploadPreset;

      // Every upload gets its OWN unique Cloudinary name.
      // Without this, uploads can end up under the same name and
      // a new video replaces the old one for everybody.
      final String uploaderId =
          FirebaseAuth.instance.currentUser?.uid ?? 'guest';

      final String uniqueSuffix =
          '${DateTime.now().microsecondsSinceEpoch}_'
          '${Random().nextInt(1 << 31)}';

      multipartRequest.fields['public_id'] =
          'buynova_videos/${uploaderId}_$uniqueSuffix';

      multipartRequest.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
        ),
      );

      final streamedMultipart =
          multipartRequest.finalize();

      final contentLength =
          multipartRequest.contentLength;

      final streamedRequest =
          http.StreamedRequest(
        'POST',
        uri,
      );

      streamedRequest.headers.addAll(
        multipartRequest.headers,
      );

      streamedRequest.contentLength =
          contentLength;

      int bytesSent = 0;

      final completer =
          Completer<void>();

      streamedMultipart.listen(
        (chunk) {
          if (chunk.isEmpty) return;

          streamedRequest.sink.add(chunk);

          bytesSent += chunk.length;

          if (contentLength > 0 &&
              mounted) {
            final ratio =
                bytesSent / contentLength;

            setState(() {
              _uploadProgress =
                  0.15 + (ratio * 0.65);
            });
          }
        },
        onError: (
          Object error,
          StackTrace stackTrace,
        ) {
          if (!completer.isCompleted) {
            completer.completeError(
              error,
              stackTrace,
            );
          }
        },
        onDone: () {
          streamedRequest.sink.close();

          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        cancelOnError: true,
      );

      await completer.future;

      client = http.Client();

      final response =
          await client
              .send(streamedRequest)
              .timeout(
                _uploadTimeout,
              );

      final responseBody =
          await response.stream
              .bytesToString();

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        String errorMessage =
            responseBody;

        try {
          final decoded =
              jsonDecode(responseBody);

          if (decoded
              is Map<String, dynamic>) {
            final error =
                decoded['error'];

            if (error
                is Map<String, dynamic>) {
              errorMessage =
                  error['message']
                          ?.toString() ??
                      responseBody;
            } else if (error != null) {
              errorMessage =
                  error.toString();
            }
          }
        } catch (_) {}

        throw Exception(
          'Cloudinary upload failed '
          '(HTTP ${response.statusCode}): '
          '$errorMessage',
        );
      }

      final decoded =
          jsonDecode(responseBody);

      final secureUrl =
          decoded['secure_url']
              ?.toString();

      if (secureUrl == null ||
          secureUrl.isEmpty) {
        throw Exception(
          'Cloudinary did not return a video URL.',
        );
      }

      if (mounted) {
        setState(() {
          _uploadProgress = 0.82;
        });
      }

      return secureUrl;
    } on TimeoutException {
      throw Exception(
        'Video upload timed out. '
        'Please check your internet connection '
        'and try again.',
      );
    } on SocketException catch (e) {
      throw Exception(
        'Network error while uploading video: $e',
      );
    } catch (e) {
      throw Exception(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      client?.close();
    }
  }

  // ============================================================
  // THUMBNAIL
  // ============================================================

  String _createThumbnailUrl(
    String videoUrl,
  ) {
    try {
      final uri =
          Uri.parse(videoUrl);

      final path = uri.path;

      if (!path.contains(
        '/video/upload/',
      )) {
        return videoUrl;
      }

      final thumbnailPath =
          path.replaceFirst(
        '/video/upload/',
        '/video/upload/so_0/',
      );

      final lastDot =
          thumbnailPath.lastIndexOf('.');

      String finalPath;

      if (lastDot != -1) {
        finalPath =
            '${thumbnailPath.substring(
          0,
          lastDot,
        )}.jpg';
      } else {
        finalPath =
            '$thumbnailPath.jpg';
      }

      return uri
          .replace(
            path: finalPath,
          )
          .toString();
    } catch (_) {
      return videoUrl;
    }
  }

  // ============================================================
  // GET USER PROFILE DATA
  // ============================================================

  Future<Map<String, String>>
      _getUserProfileData(
    User user,
  ) async {
    String userName = '';
    String profileImageUrl = '';

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      final data = doc.data();

      final firestoreName =
          data?['name']
              ?.toString()
              .trim();

      final firestoreImage =
          data?['profileImageUrl']
              ?.toString()
              .trim();

      if (firestoreName != null &&
          firestoreName.isNotEmpty) {
        userName = firestoreName;
      }

      if (firestoreImage != null &&
          firestoreImage.isNotEmpty) {
        profileImageUrl =
            firestoreImage;
      }
    } catch (_) {}

    if (userName.isEmpty) {
      final displayName =
          user.displayName?.trim();

      if (displayName != null &&
          displayName.isNotEmpty) {
        userName = displayName;
      }
    }

    if (userName.isEmpty) {
      final email =
          user.email?.trim();

      if (email != null &&
          email.isNotEmpty) {
        userName = email;
      }
    }

    if (userName.isEmpty) {
      userName = 'BuyNova User';
    }

    return {
      'name': userName,
      'profileImageUrl':
          profileImageUrl,
    };
  }

  // ============================================================
  // POST VIDEO
  // ============================================================

  Future<void> _postVideo() async {
    if (_isUploading) return;

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please login first.',
          ),
        ),
      );

      return;
    }

    if (_selectedVideo == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a video first.',
          ),
        ),
      );

      return;
    }

    final caption =
        _captionController.text.trim();

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.05;
    });

    try {
      // ========================================================
      // CURRENT LOGGED-IN USER ID
      // ========================================================

      final String uid = user.uid;

      final String userEmail =
          user.email?.trim() ?? '';

      final profile =
          await _getUserProfileData(
        user,
      );

      final String userName =
          profile['name'] ??
              'BuyNova User';

      final String profileImageUrl =
          profile['profileImageUrl'] ?? '';

      if (mounted) {
        setState(() {
          _uploadProgress = 0.10;
        });
      }

      // ========================================================
      // UPLOAD VIDEO TO CLOUDINARY
      // ========================================================

      final videoFile =
          File(_selectedVideo!.path);

      final videoUrl =
          await _uploadVideoToCloudinary(
        videoFile,
      );

      if (videoUrl == null ||
          videoUrl.isEmpty) {
        throw Exception(
          'Cloudinary did not return a valid video URL.',
        );
      }

      if (mounted) {
        setState(() {
          _uploadProgress = 0.88;
        });
      }

      final thumbnailUrl =
          _createThumbnailUrl(
        videoUrl,
      );

      // ========================================================
      // IMPORTANT:
      // EVERY VIDEO GETS A NEW FIRESTORE DOCUMENT
      // ========================================================

      final videoRef =
          FirebaseFirestore.instance
              .collection('sellerVideos')
              .doc();

      final videoData =
          <String, dynamic>{
        // ------------------------------------------------------
        // OWNER / USER INFORMATION
        // ------------------------------------------------------

        'videoId': videoRef.id,

        'userId': uid,

        'sellerId': uid,

        'userEmail': userEmail,

        'userName': userName,

        'sellerName': userName,

        'profileImageUrl':
            profileImageUrl,

        'sellerProfileImageUrl':
            profileImageUrl,

        // ------------------------------------------------------
        // VIDEO
        // ------------------------------------------------------

        'videoUrl': videoUrl,

        'thumbnailUrl': thumbnailUrl,

        'caption': caption,

        // ------------------------------------------------------
        // STATUS
        // ------------------------------------------------------

        'status': 'published',

        'moderationStatus':
            'approved',

        // ------------------------------------------------------
        // COUNTS
        // ------------------------------------------------------

        'likeCount': 0,

        'commentCount': 0,

        'viewCount': 0,

        'shareCount': 0,

        // ------------------------------------------------------
        // ARRAYS
        // ------------------------------------------------------

        'likes': <String>[],

        'comments': <String>[],

        'views': <String>[],

        'shares': <String>[],

        // ------------------------------------------------------
        // REWARD
        // ------------------------------------------------------

        'rewardEligible': true,

        // ------------------------------------------------------
        // TIME
        // ------------------------------------------------------

        'createdAt':
            FieldValue.serverTimestamp(),

        'updatedAt':
            FieldValue.serverTimestamp(),
      };

      // ========================================================
      // ATTACHED PRODUCT
      // ========================================================

      if (_selectedProductId != null) {
        videoData['productId'] =
            _selectedProductId;

        videoData['productName'] =
            _selectedProductName;

        videoData['productPrice'] =
            _selectedProductPrice;

        videoData['productImageUrl'] =
            _selectedProductImageUrl;
      }

      // ========================================================
      // SAVE VIDEO
      // ========================================================

      await videoRef.set(videoData);

      if (mounted) {
        setState(() {
          _uploadProgress = 1.0;
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Video posted successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      await Future.delayed(
        const Duration(
          milliseconds: 500,
        ),
      );

      if (!mounted) return;

      await _cleanupVideo();

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not post video:\n$e',
          ),
          duration:
              const Duration(seconds: 8),
        ),
      );
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
  // REMOVE VIDEO
  // ============================================================

  Future<void>
      _removeSelectedVideo() async {
    if (_isUploading) return;

    await _videoController?.pause();

    await _videoController?.dispose();

    _videoController = null;

    if (!mounted) return;

    setState(() {
      _selectedVideo = null;
    });
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  Future<void> _cleanupVideo() async {
    await _videoController?.pause();

    await _videoController?.dispose();

    _videoController = null;

    _selectedVideo = null;
  }

  // ============================================================
  // DOUBLE
  // ============================================================

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  // ============================================================
  // BACK
  // ============================================================

  Future<bool>
      _handleBackAttempt() async {
    if (_isUploading) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please wait until the video upload finishes.',
          ),
        ),
      );

      return false;
    }

    return true;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _captionController.dispose();

    _videoController?.dispose();

    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isUploading,
      onPopInvokedWithResult: (
        didPop,
        result,
      ) {
        if (!didPop && _isUploading) {
          _handleBackAttempt();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Post Video',
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                // ==================================================
                // VIDEO PICKER
                // ==================================================

                if (_selectedVideo == null)
                  GestureDetector(
                    onTap: _pickVideo,
                    child: Container(
                      height: 260,
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.grey.shade100,
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                        border: Border.all(
                          color:
                              Colors.grey.shade300,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                        children: [
                          Icon(
                            Icons
                                .video_library_outlined,
                            size: 60,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Select Video',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Maximum 60 MB • 90 seconds',
                            style: TextStyle(
                              color:
                                  Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    height: 360,
                    decoration:
                        BoxDecoration(
                      color: Colors.black,
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                    ),
                    clipBehavior:
                        Clip.antiAlias,
                    child: Stack(
                      alignment:
                          Alignment.center,
                      children: [
                        if (_videoController !=
                                null &&
                            _videoController!
                                .value
                                .isInitialized)
                          GestureDetector(
                            onTap: () {
                              if (_videoController!
                                  .value
                                  .isPlaying) {
                                _videoController!
                                    .pause();
                              } else {
                                _videoController!
                                    .play();
                              }

                              setState(() {});
                            },
                            child: AspectRatio(
                              aspectRatio:
                                  _videoController!
                                      .value
                                      .aspectRatio,
                              child:
                                  VideoPlayer(
                                _videoController!,
                              ),
                            ),
                          ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Material(
                            color:
                                Colors.black54,
                            shape:
                                const CircleBorder(),
                            child:
                                IconButton(
                              onPressed:
                                  _removeSelectedVideo,
                              icon:
                                  const Icon(
                                Icons.close,
                                color:
                                    Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if (_videoController !=
                                null &&
                            !_videoController!
                                .value
                                .isPlaying)
                          const IgnorePointer(
                            child: Icon(
                              Icons
                                  .play_circle_fill,
                              size: 70,
                              color:
                                  Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 18),

                if (_selectedVideo != null)
                  OutlinedButton.icon(
                    onPressed: _isUploading
                        ? null
                        : _pickVideo,
                    icon: const Icon(
                      Icons.video_file,
                    ),
                    label: const Text(
                      'Change Video',
                    ),
                  ),

                const SizedBox(height: 18),

                // ==================================================
                // CAPTION
                // ==================================================

                TextField(
                  controller:
                      _captionController,
                  maxLines: 4,
                  maxLength: 500,
                  enabled: !_isUploading,
                  decoration:
                      InputDecoration(
                    labelText: 'Caption',
                    hintText:
                        'Write something about your video...',
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ==================================================
                // PRODUCT
                // ==================================================

                if (_loadingProducts)
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                    child: Center(
                      child:
                          CircularProgressIndicator(),
                    ),
                  )
                else
                  DropdownButtonFormField<
                      String>(
                    initialValue:
                        _selectedProductId,
                    isExpanded: true,
                    decoration:
                        InputDecoration(
                      labelText:
                          'Attach Product',
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<
                          String>(
                        value: null,
                        child: Text(
                          'No product',
                        ),
                      ),
                      ..._myProducts.map(
                        (product) {
                          final id =
                              product['id']
                                  .toString();

                          final name =
                              product['name']
                                      ?.toString() ??
                                  'Product';

                          return DropdownMenuItem<
                              String>(
                            value: id,
                            child: Text(
                              name,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                            ),
                          );
                        },
                      ),
                    ],
                    onChanged:
                        _isUploading
                            ? null
                            : _selectProduct,
                  ),

                // ==================================================
                // SELECTED PRODUCT
                // ==================================================

                if (_selectedProductId != null)
                  ...[
                    const SizedBox(height: 12),
                    Container(
                      padding:
                          const EdgeInsets.all(
                        12,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.grey.shade100,
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (_selectedProductImageUrl !=
                                  null &&
                              _selectedProductImageUrl!
                                  .isNotEmpty)
                            ClipRRect(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                10,
                              ),
                              child:
                                  Image.network(
                                _selectedProductImageUrl!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (
                                  context,
                                  error,
                                  stackTrace,
                                ) {
                                  return Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors
                                        .grey
                                        .shade300,
                                    child:
                                        const Icon(
                                      Icons
                                          .image_not_supported,
                                    ),
                                  );
                                },
                              ),
                            )
                          else
                            Container(
                              width: 60,
                              height: 60,
                              decoration:
                                  BoxDecoration(
                                color: Colors
                                    .grey
                                    .shade300,
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  10,
                                ),
                              ),
                              child:
                                  const Icon(
                                Icons
                                    .inventory_2_outlined,
                              ),
                            ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  _selectedProductName ??
                                      'Product',
                                  maxLines: 2,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .w600,
                                  ),
                                ),
                                const SizedBox(
                                  height: 5,
                                ),
                                if (_selectedProductPrice !=
                                    null)
                                  Text(
                                    '৳${_selectedProductPrice!.toStringAsFixed(2)}',
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                const SizedBox(height: 18),

                // ==================================================
                // INFO
                // ==================================================

                Container(
                  padding:
                      const EdgeInsets.all(16),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.blue.shade50,
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Anyone with a BuyNova account can post videos. Every video is saved under the ID of the account that posted it.',
                          style: TextStyle(
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ==================================================
                // PROGRESS
                // ==================================================

                if (_isUploading) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Uploading video... '
                    '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value:
                        _uploadProgress,
                    minHeight: 8,
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ==================================================
                // POST
                // ==================================================

                SizedBox(
                  height: 54,
                  child:
                      ElevatedButton.icon(
                    onPressed:
                        _isUploading
                            ? null
                            : _postVideo,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons
                                .publish_outlined,
                          ),
                    label: Text(
                      _isUploading
                          ? 'Uploading...'
                          : 'Post Video',
                    ),
                    style:
                        ElevatedButton.styleFrom(
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
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
}
