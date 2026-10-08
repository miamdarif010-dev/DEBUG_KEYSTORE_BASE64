import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  // =========================================================
  // PRODUCT MEDIA
  // =========================================================

  static const int _maxImages = 10;

  final List<File> _pickedImages = [];
  final List<String> _uploadedImageUrls = [];

  File? _pickedVideo;
  String? _uploadedVideoUrl;

  bool _isUploadingPhoto = false;
  bool _isUploadingVideo = false;
  bool _isUploading = false;
  bool _isCheckingSeller = true;
  bool _isApprovedSeller = false;

  String _sellerCode = '';

  // =========================================================
  // CLOUDINARY SETTINGS
  // =========================================================

  static const String _cloudName = 'riassg6d';
  static const String _uploadPreset = 'buynova_products';

  @override
  void initState() {
    super.initState();
    _checkSellerApproval();
  }

  // =========================================================
  // CHECK SELLER APPROVAL
  // =========================================================

  Future<void> _checkSellerApproval() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _isApprovedSeller = false;
        _isCheckingSeller = false;
      });

      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snapshot.data();

      final sellerStatus =
          data?['sellerStatus']?.toString().trim();

      final sellerCode =
          data?['sellerCode']?.toString().trim() ?? '';

      if (!mounted) return;

      setState(() {
        _isApprovedSeller = sellerStatus == 'approved';
        _sellerCode = sellerCode;
        _isCheckingSeller = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isApprovedSeller = false;
        _isCheckingSeller = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not check seller status: $e',
          ),
        ),
      );
    }
  }

  // =========================================================
  // PICK MULTIPLE IMAGES
  // =========================================================

  Future<void> _pickImages() async {
    if (!_isApprovedSeller) {
      _showSellerMessage();
      return;
    }

    if (_isUploadingPhoto || _isUploadingVideo || _isUploading) {
      return;
    }

    if (_pickedImages.length >= _maxImages) {
      _showMessage(
        'You can add up to $_maxImages product images.',
      );
      return;
    }

    try {
      final remaining =
          _maxImages - _pickedImages.length;

      final picked = await _imagePicker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1400,
        maxHeight: 1400,
      );

      if (picked.isEmpty) {
        return;
      }

      final selected = picked.take(remaining).toList();

      setState(() {
        for (final image in selected) {
          _pickedImages.add(
            File(image.path),
          );
        }
      });

      if (picked.length > remaining) {
        _showMessage(
          'Only $_maxImages images can be added.',
        );
      }

      await _uploadSelectedImages(selected);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not select photos: $e',
          ),
        ),
      );
    }
  }

  // =========================================================
  // UPLOAD SELECTED IMAGES
  // =========================================================

  Future<void> _uploadSelectedImages(
    List<XFile> selected,
  ) async {
    if (selected.isEmpty) return;

    if (!mounted) return;

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      for (final image in selected) {
        final url = await _uploadImageToCloudinary(
          File(image.path),
        );

        if (url.isNotEmpty) {
          _uploadedImageUrls.add(url);
        }
      }

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selected.length} image(s) uploaded successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Some image uploads failed: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  // =========================================================
  // CLOUDINARY IMAGE UPLOAD
  // =========================================================

  Future<String> _uploadImageToCloudinary(
    File imageFile,
  ) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );

    final request = http.MultipartRequest(
      'POST',
      uri,
    );

    request.fields['upload_preset'] =
        _uploadPreset;

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
      ),
    );

    final streamedResponse =
        await request.send();

    final response =
        await http.Response.fromStream(
      streamedResponse,
    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'Cloudinary image upload failed: '
        '${response.statusCode}',
      );
    }

    final Map<String, dynamic> result =
        jsonDecode(response.body);

    final secureUrl =
        result['secure_url']?.toString();

    if (secureUrl == null ||
        secureUrl.isEmpty) {
      throw Exception(
        'Cloudinary did not return image URL.',
      );
    }

    return secureUrl;
  }

  // =========================================================
  // REMOVE IMAGE
  // =========================================================

  void _removeImage(int index) {
    if (_isUploadingPhoto || _isUploading) {
      return;
    }

    if (index < 0 ||
        index >= _pickedImages.length) {
      return;
    }

    setState(() {
      _pickedImages.removeAt(index);

      if (index < _uploadedImageUrls.length) {
        _uploadedImageUrls.removeAt(index);
      }
    });
  }

  // =========================================================
  // PICK VIDEO
  // =========================================================

  Future<void> _pickVideo() async {
    if (!_isApprovedSeller) {
      _showSellerMessage();
      return;
    }

    if (_isUploadingPhoto ||
        _isUploadingVideo ||
        _isUploading) {
      return;
    }

    try {
      final picked =
          await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration:
            const Duration(
          seconds: 60,
        ),
      );

      if (picked == null) {
        return;
      }

      final file = File(picked.path);

      setState(() {
        _pickedVideo = file;
        _uploadedVideoUrl = null;
        _isUploadingVideo = true;
      });

      final videoUrl =
          await _uploadVideoToCloudinary(
        file,
      );

      if (!mounted) return;

      setState(() {
        _uploadedVideoUrl = videoUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Product video uploaded successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _pickedVideo = null;
        _uploadedVideoUrl = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Video upload failed: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingVideo = false;
        });
      }
    }
  }

  // =========================================================
  // CLOUDINARY VIDEO UPLOAD
  // =========================================================

  Future<String> _uploadVideoToCloudinary(
    File videoFile,
  ) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/video/upload',
    );

    final request = http.MultipartRequest(
      'POST',
      uri,
    );

    request.fields['upload_preset'] =
        _uploadPreset;

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        videoFile.path,
      ),
    );

    final streamedResponse =
        await request.send();

    final response =
        await http.Response.fromStream(
      streamedResponse,
    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'Cloudinary video upload failed: '
        '${response.statusCode}\n'
        '${response.body}',
      );
    }

    final Map<String, dynamic> result =
        jsonDecode(response.body);

    final secureUrl =
        result['secure_url']?.toString();

    if (secureUrl == null ||
        secureUrl.isEmpty) {
      throw Exception(
        'Cloudinary did not return video URL.',
      );
    }

    return secureUrl;
  }

  // =========================================================
  // REMOVE VIDEO
  // =========================================================

  void _removeVideo() {
    if (_isUploadingVideo || _isUploading) {
      return;
    }

    setState(() {
      _pickedVideo = null;
      _uploadedVideoUrl = null;
    });
  }

  // =========================================================
  // SELLER MESSAGE
  // =========================================================

  void _showSellerMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Only approved sellers can add products.',
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // =========================================================
  // UPLOAD PRODUCT
  // =========================================================

  Future<void> _uploadProduct() async {
    if (!_isApprovedSeller) {
      _showSellerMessage();
      return;
    }

    final title =
        _titleController.text.trim();

    final priceText =
        _priceController.text.trim();

    final description =
        _descriptionController.text.trim();

    final category =
        _categoryController.text.trim();

    // =======================================================
    // VALIDATE PRICE
    // =======================================================

    final price =
        double.tryParse(priceText);

    if (title.isEmpty ||
        price == null ||
        price <= 0 ||
        description.isEmpty) {
      _showMessage(
        'Please enter product name, valid BDT price and description.',
      );

      return;
    }

    // =======================================================
    // WAIT FOR MEDIA UPLOAD
    // =======================================================

    if (_isUploadingPhoto) {
      _showMessage(
        'Please wait until all image uploads finish.',
      );

      return;
    }

    if (_isUploadingVideo) {
      _showMessage(
        'Please wait until the video upload finishes.',
      );

      return;
    }

    // =======================================================
    // CURRENT USER
    // =======================================================

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Please login first.',
      );

      return;
    }

    if (_isUploading) {
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // =====================================================
      // READ CURRENT USER DATA
      // =====================================================

      final userSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      final userData =
          userSnapshot.data() ?? {};

      final sellerStatus =
          userData['sellerStatus']
                  ?.toString()
                  .trim() ??
              '';

      final sellerCode =
          userData['sellerCode']
                  ?.toString()
                  .trim() ??
              '';

      if (sellerStatus != 'approved') {
        throw Exception(
          'Your seller account is not approved.',
        );
      }

      // =====================================================
      // SELLER NAME
      // =====================================================

      final sellerName =
          userData['name']
                  ?.toString()
                  .trim() ??
              '';

      // =====================================================
      // SELLER EMAIL
      // =====================================================

      final sellerEmail =
          user.email ?? '';

      // =====================================================
      // PRODUCT DOCUMENT
      // =====================================================

      final firestore =
          FirebaseFirestore.instance;

      final productRef =
          firestore
              .collection('products')
              .doc();

      // =====================================================
      // MAIN IMAGE
      // =====================================================

      final mainImageUrl =
          _uploadedImageUrls.isNotEmpty
              ? _uploadedImageUrls.first
              : '';

      // =====================================================
      // PRODUCT DATA
      // =====================================================

      final productData =
          <String, dynamic>{
        // ---------------------------------------------------
        // BASIC PRODUCT INFORMATION
        // ---------------------------------------------------

        'name': title,

        // ---------------------------------------------------
        // PRICE
        // ---------------------------------------------------

        'price': price,
        'currency': 'BDT',
        'currencySymbol': '৳',

        // ---------------------------------------------------
        // DESCRIPTION
        // ---------------------------------------------------

        'description': description,

        // ---------------------------------------------------
        // MAIN IMAGE
        // ---------------------------------------------------

        'imageUrl': mainImageUrl,

        // ---------------------------------------------------
        // MULTIPLE IMAGES
        // ---------------------------------------------------

        'imageUrls':
            List<String>.from(
          _uploadedImageUrls,
        ),

        // Compatibility with Product Details Page.
        'images':
            List<String>.from(
          _uploadedImageUrls,
        ),

        // ---------------------------------------------------
        // PRODUCT VIDEO
        // ---------------------------------------------------

        'videoUrl':
            _uploadedVideoUrl ?? '',

        // ---------------------------------------------------
        // CATEGORY
        // ---------------------------------------------------

        'category': category.isNotEmpty
            ? category
            : 'General',

        // ---------------------------------------------------
        // SELLER INFORMATION
        // ---------------------------------------------------

        'sellerId': user.uid,

        'sellerCode': sellerCode,

        'sellerEmail': sellerEmail,

        'sellerName': sellerName,

        'sellerApproved': true,

        // ---------------------------------------------------
        // PRODUCT STATUS
        // ---------------------------------------------------

        'active': true,

        'status': 'active',

        // ---------------------------------------------------
        // PRODUCT STATS
        // ---------------------------------------------------

        'rating': 5,

        'reviewCount': 0,

        'stock': 10,

        'views': 0,

        'salesCount': 0,

        // ---------------------------------------------------
        // TIMESTAMP
        // ---------------------------------------------------

        'createdAt':
            FieldValue.serverTimestamp(),
      };

      // =====================================================
      // SAVE PRODUCT FIRST
      // =====================================================

      await productRef.set(
        productData,
      );

      // =====================================================
      // CREATE GLOBAL NOTIFICATION
      // =====================================================

      try {
        final notificationRef =
            firestore
                .collection(
                  'global_notifications',
                )
                .doc();

        await notificationRef.set(
          {
            'type':
                'new_product',

            'title':
                'New Product Added',

            'message':
                '$title is now available on BuyNova.',

            'productId':
                productRef.id,

            'productName':
                title,

            'productImageUrl':
                mainImageUrl,

            'productPrice':
                price,

            'currency':
                'BDT',

            'currencySymbol':
                '৳',

            'sellerId':
                user.uid,

            'sellerCode':
                sellerCode,

            'sellerName':
                sellerName,

            'active':
                true,

            'createdAt':
                FieldValue
                    .serverTimestamp(),
          },
        );
      } catch (notificationError) {
        debugPrint(
          'Global notification creation failed: '
          '$notificationError',
        );
      }

      // =====================================================
      // SUCCESS
      // =====================================================

      if (!mounted) return;

      _titleController.clear();
      _priceController.clear();
      _descriptionController.clear();
      _categoryController.clear();

      setState(() {
        _pickedImages.clear();
        _uploadedImageUrls.clear();

        _pickedVideo = null;
        _uploadedVideoUrl = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Product uploaded successfully!',
          ),
        ),
      );

      await Future<void>.delayed(
        const Duration(
          milliseconds: 500,
        ),
      );

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration:
              const Duration(seconds: 5),
          content: Text(
            'Product upload failed:\n$e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();

    super.dispose();
  }

  // =========================================================
  // SELLER NOT APPROVED VIEW
  // =========================================================

  Widget _sellerNotApprovedView() {
    return Center(
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.storefront_rounded,
              size: 80,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 20),
            const Text(
              'Seller Approval Required',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Only approved BuyNova sellers can add products.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color:
                    Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed:
                  _checkSellerApproval,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Check Again',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // IMAGE PICKER SECTION
  // =========================================================

  Widget _buildImagePickerSection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Product Images',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${_pickedImages.length}/$_maxImages',
              style: TextStyle(
                color:
                    Colors.grey.shade600,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Text(
          'Add up to $_maxImages photos. The first photo will be the main product image.',
          style: TextStyle(
            color:
                Colors.grey.shade600,
            fontSize: 13,
          ),
        ),

        const SizedBox(height: 12),

        GestureDetector(
          onTap: _pickImages,
          child: Container(
            height: 155,
            width: double.infinity,
            decoration:
                BoxDecoration(
              color:
                  Colors.grey.shade200,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              border: Border.all(
                color:
                    Colors.grey.shade400,
              ),
            ),
            child:
                _pickedImages.isEmpty
                    ? Column(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                        children: [
                          Icon(
                            Icons
                                .add_photo_alternate_outlined,
                            size: 45,
                            color: Colors
                                .grey
                                .shade600,
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          Text(
                            'Tap to select product photos',
                            style:
                                TextStyle(
                              color: Colors
                                  .grey
                                  .shade600,
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        children: [
                          ClipRRect(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                            child:
                                Image.file(
                              _pickedImages
                                  .first,
                              width:
                                  double.infinity,
                              height: 155,
                              fit: BoxFit
                                  .cover,
                            ),
                          ),
                          Positioned(
                            left: 10,
                            bottom: 10,
                            child:
                                Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal:
                                    10,
                                vertical:
                                    6,
                              ),
                              decoration:
                                  BoxDecoration(
                                color: Colors
                                    .black54,
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  20,
                                ),
                              ),
                              child:
                                  Text(
                                '${_pickedImages.length} photos',
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child:
                                Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal:
                                    12,
                                vertical:
                                    7,
                              ),
                              decoration:
                                  BoxDecoration(
                                color: Colors
                                    .redAccent,
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  20,
                                ),
                              ),
                              child:
                                  const Text(
                                'Add Photos',
                                style:
                                    TextStyle(
                                  color:
                                      Colors.white,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        ),

        const SizedBox(height: 12),

        if (_pickedImages.isNotEmpty)
          SizedBox(
            height: 92,
            child: ListView.builder(
              scrollDirection:
                  Axis.horizontal,
              itemCount:
                  _pickedImages.length,
              itemBuilder:
                  (context, index) {
                return Container(
                  width: 82,
                  margin:
                      const EdgeInsets.only(
                    right: 8,
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius
                                .circular(
                          9,
                        ),
                        child:
                            Image.file(
                          _pickedImages[
                              index],
                          width: 82,
                          height: 82,
                          fit: BoxFit.cover,
                        ),
                      ),

                      Positioned(
                        right: 2,
                        top: 2,
                        child:
                            GestureDetector(
                          onTap: () =>
                              _removeImage(
                            index,
                          ),
                          child:
                              Container(
                            width: 24,
                            height: 24,
                            decoration:
                                const BoxDecoration(
                              color:
                                  Colors.red,
                              shape: BoxShape
                                  .circle,
                            ),
                            child:
                                const Icon(
                              Icons.close,
                              color: Colors
                                  .white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),

                      if (index == 0)
                        Positioned(
                          left: 4,
                          bottom: 4,
                          child:
                              Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal:
                                  5,
                              vertical:
                                  2,
                            ),
                            decoration:
                                BoxDecoration(
                              color: Colors
                                  .redAccent,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                5,
                              ),
                            ),
                            child:
                                const Text(
                              'MAIN',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white,
                                fontSize:
                                    8,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

        if (_isUploadingPhoto)
          const Padding(
            padding:
                EdgeInsets.only(
              top: 12,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Uploading images...',
                ),
              ],
            ),
          ),
      ],
    );
  }

  // =========================================================
  // VIDEO PICKER SECTION
  // =========================================================

  Widget _buildVideoPickerSection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Video',
          style: TextStyle(
            fontSize: 18,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Add one short product video. Maximum length: 60 seconds.',
          style: TextStyle(
            color:
                Colors.grey.shade600,
            fontSize: 13,
          ),
        ),

        const SizedBox(height: 12),

        if (_pickedVideo == null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  _pickVideo,
              icon: const Icon(
                Icons.video_library_outlined,
              ),
              label: const Text(
                'Choose Product Video',
              ),
              style:
                  OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 15,
                ),
                foregroundColor:
                    Colors.redAccent,
                side:
                    const BorderSide(
                  color:
                      Colors.redAccent,
                ),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(14),
            decoration:
                BoxDecoration(
              color:
                  Colors.grey.shade100,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              border: Border.all(
                color:
                    Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration:
                      BoxDecoration(
                    color: Colors.black,
                    borderRadius:
                        BorderRadius.circular(
                      9,
                    ),
                  ),
                  child: const Icon(
                    Icons.play_circle_fill,
                    color:
                        Colors.white,
                    size: 35,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Product Video',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        _uploadedVideoUrl != null
                            ? 'Uploaded successfully'
                            : 'Uploading...',
                        style: TextStyle(
                          color: _uploadedVideoUrl !=
                                  null
                              ? Colors.green
                              : Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_isUploadingVideo)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                else
                  IconButton(
                    onPressed:
                        _removeVideo,
                    icon:
                        const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Product',
        ),
      ),
      body: _isCheckingSeller
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : !_isApprovedSeller
              ? _sellerNotApprovedView()
              : Padding(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  child:
                      SingleChildScrollView(
                    child: Column(
                      children: [
                        // =================================================
                        // SELLER INFO
                        // =================================================

                        Container(
                          width:
                              double.infinity,
                          padding:
                              const EdgeInsets
                                  .all(
                            14,
                          ),
                          decoration:
                              BoxDecoration(
                            color: Theme.of(
                              context,
                            )
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              14,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons
                                    .verified_user_rounded,
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              Expanded(
                                child:
                                    Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    const Text(
                                      'Approved Seller',
                                      style:
                                          TextStyle(
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 3,
                                    ),
                                    Text(
                                      _sellerCode
                                              .isNotEmpty
                                          ? 'Seller ID: $_sellerCode'
                                          : 'Seller ID: ${FirebaseAuth.instance.currentUser?.uid ?? 'N/A'}',
                                      style:
                                          TextStyle(
                                        fontSize:
                                            13,
                                        color: Colors
                                            .grey
                                            .shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons
                                    .check_circle,
                                color:
                                    Colors.green,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          height: 18,
                        ),

                        // =================================================
                        // MULTIPLE IMAGES
                        // =================================================

                        _buildImagePickerSection(),

                        const SizedBox(
                          height: 22,
                        ),

                        // =================================================
                        // PRODUCT VIDEO
                        // =================================================

                        _buildVideoPickerSection(),

                        const SizedBox(
                          height: 20,
                        ),

                        // =================================================
                        // PRODUCT NAME
                        // =================================================

                        TextField(
                          controller:
                              _titleController,
                          textInputAction:
                              TextInputAction
                                  .next,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Product Name',
                            border:
                                OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        // =================================================
                        // PRICE — BDT
                        // =================================================

                        TextField(
                          controller:
                              _priceController,
                          keyboardType:
                              const TextInputType
                                  .numberWithOptions(
                            decimal:
                                true,
                          ),
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Price (৳ BDT)',
                            hintText:
                                'Example: 1500',
                            prefixText:
                                '৳ ',
                            border:
                                OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        // =================================================
                        // CATEGORY
                        // =================================================

                        TextField(
                          controller:
                              _categoryController,
                          textInputAction:
                              TextInputAction
                                  .next,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Category',
                            hintText:
                                'Example: Men, Women, Electronics',
                            border:
                                OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        // =================================================
                        // DESCRIPTION
                        // =================================================

                        TextField(
                          controller:
                              _descriptionController,
                          maxLines: 3,
                          maxLength: 1000,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Description',
                            border:
                                OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(
                          height: 20,
                        ),

                        // =================================================
                        // UPLOAD BUTTON
                        // =================================================

                        SizedBox(
                          width:
                              double.infinity,
                          height: 50,
                          child:
                              ElevatedButton(
                            onPressed:
                                (_isUploading ||
                                        _isUploadingPhoto ||
                                        _isUploadingVideo)
                                    ? null
                                    : _uploadProduct,
                            child:
                                _isUploading
                                    ? const SizedBox(
                                        height:
                                            22,
                                        width:
                                            22,
                                        child:
                                            CircularProgressIndicator(
                                          color:
                                              Colors.white,
                                          strokeWidth:
                                              2,
                                        ),
                                      )
                                    : const Text(
                                        'Upload Product',
                                      ),
                          ),
                        ),

                        const SizedBox(
                          height: 20,
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
