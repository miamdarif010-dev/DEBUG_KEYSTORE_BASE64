import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  // ============================================================
  // CLOUDINARY
  // ============================================================

  static const String _cloudName = 'riassg6d';
  static const String _imageUploadPreset = 'buynova_products';
  static const String _videoUploadPreset = 'buynova_products';

  static const int _maxImages = 10;
  static const int _maxVideoSeconds = 60;

  // ============================================================
  // FIREBASE / PICKER
  // ============================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController =
      TextEditingController();

  // ============================================================
  // DATA
  // ============================================================

  final List<XFile> _pickedImages = <XFile>[];
  final List<String> _uploadedImageUrls = <String>[];

  XFile? _pickedVideo;
  String? _uploadedVideoUrl;

  String _selectedCategory = 'Phones';

  bool _isCheckingSeller = true;
  bool _isApprovedSeller = false;
  bool _isUploading = false;
  bool _isSaving = false;

  String? _sellerName;
  String? _shopName;

  // ============================================================
  // CATEGORIES
  // ============================================================

  final List<String> _categories = const [
    'Phones',
    'Laptops',
    'Watches',
    'Earbuds',
    'Cameras',
    'Fashion',
    'Shoes',
    'Bags',
    'Beauty',
    'Sports',
    'Toys',
    'Grocery',
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadSellerInformation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ============================================================
  // SELLER INFORMATION
  // ============================================================

  Future<void> _loadSellerInformation() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _isCheckingSeller = false;
        _isApprovedSeller = false;
      });

      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _firestore.collection('users').doc(user.uid).get();

      final Map<String, dynamic> data = snapshot.data() ?? {};

      final String sellerStatus =
          (data['sellerStatus'] ?? 'none').toString().toLowerCase();

      final String role = (data['role'] ?? '').toString().toLowerCase();

      final bool approved =
          sellerStatus == 'approved' || role == 'admin';

      if (!mounted) return;

      setState(() {
        _isCheckingSeller = false;
        _isApprovedSeller = approved;

        _sellerName = (data['name'] ?? data['displayName'] ?? '')
            .toString()
            .trim();

        _shopName = (data['shopName'] ?? data['storeName'] ?? '')
            .toString()
            .trim();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCheckingSeller = false;
        _isApprovedSeller = false;
      });

      _showSnackBar(
        'Seller information load failed: $e',
        isError: true,
      );
    }
  }

  // ============================================================
  // PICK MULTIPLE IMAGES
  // ============================================================

  Future<void> _pickImages() async {
    if (_isUploading || _isSaving) return;

    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1400,
        maxHeight: 1400,
      );

      if (images.isEmpty) return;

      final int remaining = _maxImages - _pickedImages.length;

      if (remaining <= 0) {
        _showSnackBar(
          'Maximum $_maxImages images allowed.',
          isError: true,
        );
        return;
      }

      final List<XFile> selected =
          images.take(remaining).toList(growable: false);

      setState(() {
        _pickedImages.addAll(selected);
      });

      if (images.length > remaining) {
        _showSnackBar(
          'Only $_maxImages images can be added.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar(
        'Image selection failed: $e',
        isError: true,
      );
    }
  }

  // ============================================================
  // REMOVE IMAGE
  // ============================================================

  void _removeImage(int index) {
    if (index < 0 || index >= _pickedImages.length) return;

    setState(() {
      _pickedImages.removeAt(index);

      if (_uploadedImageUrls.length > index) {
        _uploadedImageUrls.removeAt(index);
      }
    });
  }

  // ============================================================
  // PICK VIDEO
  // ============================================================

  Future<void> _pickVideo() async {
    if (_isUploading || _isSaving) return;

    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: _maxVideoSeconds),
      );

      if (video == null) return;

      setState(() {
        _pickedVideo = video;
        _uploadedVideoUrl = null;
      });
    } catch (e) {
      _showSnackBar(
        'Video selection failed: $e',
        isError: true,
      );
    }
  }

  // ============================================================
  // REMOVE VIDEO
  // ============================================================

  void _removeVideo() {
    if (_isUploading || _isSaving) return;

    setState(() {
      _pickedVideo = null;
      _uploadedVideoUrl = null;
    });
  }

  // ============================================================
  // CLOUDINARY IMAGE UPLOAD
  // ============================================================

  Future<String?> _uploadImageToCloudinary(XFile image) async {
    try {
      final Uri url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );

      final http.MultipartRequest request =
          http.MultipartRequest('POST', url);

      request.fields['upload_preset'] = _imageUploadPreset;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          image.path,
        ),
      );

      final http.StreamedResponse streamedResponse = await request.send();

      final String responseBody =
          await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode < 200 ||
          streamedResponse.statusCode >= 300) {
        debugPrint(
          'Cloudinary image upload failed: '
          '${streamedResponse.statusCode} $responseBody',
        );
        return null;
      }

      final dynamic decoded = jsonDecode(responseBody);

      if (decoded is Map<String, dynamic>) {
        final String? secureUrl = decoded['secure_url']?.toString();

        if (secureUrl != null && secureUrl.isNotEmpty) {
          return secureUrl;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Cloudinary image upload exception: $e');
      return null;
    }
  }

  // ============================================================
  // CLOUDINARY VIDEO UPLOAD
  // ============================================================

  Future<String?> _uploadVideoToCloudinary(XFile video) async {
    try {
      final Uri url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/video/upload',
      );

      final http.MultipartRequest request =
          http.MultipartRequest('POST', url);

      request.fields['upload_preset'] = _videoUploadPreset;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          video.path,
        ),
      );

      final http.StreamedResponse streamedResponse = await request.send();

      final String responseBody =
          await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode < 200 ||
          streamedResponse.statusCode >= 300) {
        debugPrint(
          'Cloudinary video upload failed: '
          '${streamedResponse.statusCode} $responseBody',
        );
        return null;
      }

      final dynamic decoded = jsonDecode(responseBody);

      if (decoded is Map<String, dynamic>) {
        final String? secureUrl = decoded['secure_url']?.toString();

        if (secureUrl != null && secureUrl.isNotEmpty) {
          return secureUrl;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Cloudinary video upload exception: $e');
      return null;
    }
  }

  // ============================================================
  // UPLOAD ALL MEDIA
  // ============================================================

  Future<bool> _uploadSelectedMedia() async {
    if (_pickedImages.isEmpty) {
      _showSnackBar(
        'Please select at least one product image.',
        isError: true,
      );
      return false;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final List<String> imageUrls = <String>[];

      for (int i = 0; i < _pickedImages.length; i++) {
        if (!mounted) return false;

        _showUploadProgress(
          'Uploading image ${i + 1}/${_pickedImages.length}...',
        );

        final String? imageUrl =
            await _uploadImageToCloudinary(_pickedImages[i]);

        if (imageUrl == null || imageUrl.isEmpty) {
          _showSnackBar(
            'Image ${i + 1} upload failed. Please try again.',
            isError: true,
          );

          return false;
        }

        imageUrls.add(imageUrl);
      }

      String? videoUrl;

      if (_pickedVideo != null) {
        if (!mounted) return false;

        _showUploadProgress('Uploading product video...');

        videoUrl = await _uploadVideoToCloudinary(_pickedVideo!);

        if (videoUrl == null || videoUrl.isEmpty) {
          _showSnackBar(
            'Video upload failed. Please check your Cloudinary video upload preset.',
            isError: true,
          );

          return false;
        }
      }

      if (!mounted) return false;

      setState(() {
        _uploadedImageUrls
          ..clear()
          ..addAll(imageUrls);

        _uploadedVideoUrl = videoUrl;
      });

      return true;
    } catch (e) {
      _showSnackBar(
        'Media upload failed: $e',
        isError: true,
      );

      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // ============================================================
  // SAVE PRODUCT
  // ============================================================

  Future<void> _addProduct() async {
    if (_isSaving || _isUploading) return;

    final User? user = _auth.currentUser;

    if (user == null) {
      _showSnackBar(
        'Please login first.',
        isError: true,
      );
      return;
    }

    if (!_isApprovedSeller) {
      _showSnackBar(
        'Only approved sellers can add products.',
        isError: true,
      );
      return;
    }

    final String name = _nameController.text.trim();
    final String priceText = _priceController.text.trim();
    final String description = _descriptionController.text.trim();

    if (name.isEmpty) {
      _showSnackBar(
        'Please enter product name.',
        isError: true,
      );
      return;
    }

    final double? price = double.tryParse(
      priceText.replaceAll(',', ''),
    );

    if (price == null || price <= 0) {
      _showSnackBar(
        'Please enter a valid price.',
        isError: true,
      );
      return;
    }

    if (description.isEmpty) {
      _showSnackBar(
        'Please enter product description.',
        isError: true,
      );
      return;
    }

    if (_pickedImages.isEmpty) {
      _showSnackBar(
        'Please select at least one product image.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final bool uploaded = await _uploadSelectedMedia();

      if (!uploaded) {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
        return;
      }

      if (_uploadedImageUrls.isEmpty) {
        throw Exception('No product image was uploaded.');
      }

      final DocumentSnapshot<Map<String, dynamic>> userSnapshot =
          await _firestore.collection('users').doc(user.uid).get();

      final Map<String, dynamic> userData =
          userSnapshot.data() ?? <String, dynamic>{};

      final String sellerName = _sellerName?.isNotEmpty == true
          ? _sellerName!
          : (userData['name'] ?? userData['displayName'] ?? 'Seller')
              .toString();

      final String shopName = _shopName?.isNotEmpty == true
          ? _shopName!
          : (userData['shopName'] ?? userData['storeName'] ?? '')
              .toString();

      final DocumentReference<Map<String, dynamic>> productRef =
          _firestore.collection('products').doc();

      final Map<String, dynamic> productData =
          <String, dynamic>{
        'name': name,
        'price': price,
        'currency': 'BDT',
        'currencySymbol': '৳',

        'category': _selectedCategory,
        'description': description,

        'imageUrl': _uploadedImageUrls.first,

        'imageUrls': List<String>.from(_uploadedImageUrls),
        'images': List<String>.from(_uploadedImageUrls),
        'productImages': List<String>.from(_uploadedImageUrls),
        'gallery': List<String>.from(_uploadedImageUrls),

        'videoUrl': _uploadedVideoUrl ?? '',
        'productVideoUrl': _uploadedVideoUrl ?? '',

        'sellerId': user.uid,
        'sellerUid': user.uid,
        'sellerName': sellerName,
        'shopName': shopName,

        'status': 'active',
        'isActive': true,
        'approved': true,

        'rating': 0.0,
        'reviewCount': 0,
        'soldCount': 0,
        'views': 0,
        'favoritesCount': 0,

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await productRef.set(productData);

      try {
        await _firestore
            .collection('global_notifications')
            .add({
          'type': 'new_product',
          'title': 'New Product Added',
          'message': '$name is now available on BuyNova.',
          'productId': productRef.id,
          'productName': name,
          'productImage': _uploadedImageUrls.first,
          'imageUrl': _uploadedImageUrls.first,
          'price': price,
          'currency': 'BDT',
          'currencySymbol': '৳',
          'sellerId': user.uid,
          'sellerName': sellerName,
          'shopName': shopName,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint(
          'Global notification creation failed: $e',
        );
      }

      if (!mounted) return;

      _showSnackBar(
        'Product added successfully!',
      );

      _nameController.clear();
      _priceController.clear();
      _descriptionController.clear();

      setState(() {
        _pickedImages.clear();
        _uploadedImageUrls.clear();
        _pickedVideo = null;
        _uploadedVideoUrl = null;
        _selectedCategory = 'Phones';
      });

      await Future<void>.delayed(
        const Duration(milliseconds: 700),
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Product save failed: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  void _showUploadProgress(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _showSnackBar(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : null,
        ),
      );
  }

  // ============================================================
  // IMAGE PICKER CARD
  // ============================================================

  Widget _buildImageSection() {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Product Images',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${_pickedImages.length}/$_maxImages',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Add up to $_maxImages product images.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            if (_pickedImages.isEmpty)
              InkWell(
                onTap: _pickImages,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  height: 170,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 48,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Tap to select product images',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'You can select multiple images',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  SizedBox(
                    height: 105,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pickedImages.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final XFile image = _pickedImages[index];

                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(image.path),
                                width: 105,
                                height: 105,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) {
                                  return Container(
                                    width: 105,
                                    height: 105,
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 5,
                              right: 5,
                              child: InkWell(
                                onTap: () => _removeImage(index),
                                borderRadius:
                                    BorderRadius.circular(20),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                            if (index == 0)
                              Positioned(
                                left: 5,
                                bottom: 5,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Main',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickedImages.length >= _maxImages
                          ? null
                          : _pickImages,
                      icon: const Icon(
                        Icons.add_photo_alternate_outlined,
                      ),
                      label: Text(
                        _pickedImages.length >= _maxImages
                            ? 'Maximum images reached'
                            : 'Add More Images',
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // VIDEO SECTION
  // ============================================================

  Widget _buildVideoSection() {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.video_library_outlined,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Product Video',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  'Optional',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Add one short product video. Maximum $_maxVideoSeconds seconds.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            if (_pickedVideo == null)
              InkWell(
                onTap: _pickVideo,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  height: 125,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.video_call_outlined,
                        size: 42,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Select Product Video',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Optional',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.play_circle_outline,
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _pickedVideo!.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _removeVideo,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            if (_pickedVideo != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Choose Different Video'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BASIC TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textInputAction:
          maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            width: 2,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CATEGORY DROPDOWN
  // ============================================================

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Category',
        prefixIcon: const Icon(
          Icons.category_outlined,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      items: _categories.map((String category) {
        return DropdownMenuItem<String>(
          value: category,
          child: Text(category),
        );
      }).toList(),
      onChanged: _isSaving || _isUploading
          ? null
          : (String? value) {
              if (value == null) return;

              setState(() {
                _selectedCategory = value;
              });
            },
    );
  }

  // ============================================================
  // SELLER INFO
  // ============================================================

  Widget _buildSellerInfo() {
    final User? user = _auth.currentUser;

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 24,
              child: Icon(
                Icons.storefront_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Seller',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    (_sellerName?.isNotEmpty == true)
                        ? _sellerName!
                        : (user?.email ?? 'Seller'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_shopName?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      _shopName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Approved',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSeller) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Add Product'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isApprovedSeller) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Add Product'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 70,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Seller Approval Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Only approved BuyNova sellers can add products.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 25),
                ElevatedButton.icon(
                  onPressed: _loadSellerInformation,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bool busy = _isSaving || _isUploading;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Product',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSellerInfo(),

              const SizedBox(height: 16),

              _buildImageSection(),

              const SizedBox(height: 16),

              _buildVideoSection(),

              const SizedBox(height: 16),

              Card(
                elevation: 1,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: 'Product Name',
                        hint: 'Enter product name',
                        icon: Icons.shopping_bag_outlined,
                      ),

                      const SizedBox(height: 14),

                      _buildTextField(
                        controller: _priceController,
                        label: 'Price (BDT)',
                        hint: 'Enter price',
                        icon: Icons.payments_outlined,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),

                      const SizedBox(height: 14),

                      _buildCategoryDropdown(),

                      const SizedBox(height: 14),

                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        hint: 'Describe your product',
                        icon: Icons.description_outlined,
                        maxLines: 6,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              if (_uploadedImageUrls.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.green.withValues(alpha: 0.08),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cloud_done_outlined,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${_uploadedImageUrls.length} image(s) uploaded'
                          '${_uploadedVideoUrl != null ? ' + video' : ''}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: busy ? null : _addProduct,
                  icon: busy
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.cloud_upload_outlined,
                        ),
                  label: Text(
                    _isUploading
                        ? 'Uploading Media...'
                        : _isSaving
                            ? 'Saving Product...'
                            : 'Add Product',
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Your first image will be used as the main product image. '
                'All selected images and the optional video will be '
                'available on the product details page.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
