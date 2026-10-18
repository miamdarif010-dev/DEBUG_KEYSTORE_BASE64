import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'price_discount.dart';

class EditProductPage extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> initialData;

  const EditProductPage({
    super.key,
    required this.productId,
    required this.initialData,
  });

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;

  final ImagePicker _imagePicker = ImagePicker();

  File? _pickedImage;
  String _currentImageUrl = '';

  bool _isUploadingPhoto = false;
  bool _isSaving = false;
  bool _isLoadingProduct = true;

  // Price + discount.
  // `price` in Firestore is what the buyer pays (after discount),
  // `originalPrice` is the total price before the discount.
  double _initialTotal = 0;
  double _initialDiscount = 0;
  DiscountResult? _priceResult;

  // =========================================================
  // CLOUDINARY
  // =========================================================

  static const String _cloudName = 'riassg6d';
  static const String _uploadPreset = 'buynova_products';

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();

    final data = widget.initialData;

    _titleController = TextEditingController(
      text: data['name']?.toString() ?? '',
    );

    _descriptionController = TextEditingController(
      text: data['description']?.toString() ?? '',
    );

    _categoryController = TextEditingController(
      text: data['category']?.toString() ?? '',
    );

    _currentImageUrl = data['imageUrl']?.toString() ?? '';

    _readPrice(data);

    _loadLatestProduct();
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _readPrice(Map<String, dynamic> data) {
    final double price = _toDouble(data['price']);
    final double original = _toDouble(data['originalPrice']);

    if (original > price + 0.004) {
      _initialTotal = original;
      _initialDiscount = original - price;
    } else {
      _initialTotal = price;
      _initialDiscount = 0;
    }

    _priceResult = DiscountResult(original: _initialTotal, finalPrice: price);
  }

  // =========================================================
  // LOAD LATEST PRODUCT
  // =========================================================

  Future<void> _loadLatestProduct() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .get();

      if (!snapshot.exists) {
        if (!mounted) return;

        setState(() {
          _isLoadingProduct = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product no longer exists.')),
        );

        return;
      }

      final data = snapshot.data();

      if (data != null && mounted) {
        _titleController.text = data['name']?.toString() ?? '';
        _descriptionController.text = data['description']?.toString() ?? '';
        _categoryController.text = data['category']?.toString() ?? '';

        _readPrice(data);

        setState(() {
          _currentImageUrl = data['imageUrl']?.toString() ?? '';
          _isLoadingProduct = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingProduct = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load product: $e')),
      );
    }
  }

  // =========================================================
  // PICK IMAGE
  // =========================================================

  Future<void> _pickImage() async {
    if (_isUploadingPhoto || _isSaving) return;

    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (picked == null) return;

      await _uploadToCloudinary(File(picked.path));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select photo: $e')),
      );
    }
  }

  // =========================================================
  // CLOUDINARY UPLOAD
  // =========================================================

  Future<void> _uploadToCloudinary(File imageFile) async {
    if (!mounted) return;

    setState(() {
      _pickedImage = imageFile;
      _isUploadingPhoto = true;
    });

    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = _uploadPreset;

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      final streamedResponse = await request.send();

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Cloudinary upload failed: ${response.statusCode}\n${response.body}',
        );
      }

      final Map<String, dynamic> result = jsonDecode(response.body);

      final secureUrl = result['secure_url']?.toString();

      if (secureUrl == null || secureUrl.isEmpty) {
        throw Exception('Cloudinary did not return an image URL.');
      }

      if (!mounted) return;

      setState(() {
        _currentImageUrl = secureUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New product image uploaded.')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _pickedImage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo upload failed: $e')),
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
  // SAVE CHANGES
  // =========================================================

  Future<void> _saveChanges() async {
    if (_isSaving || _isUploadingPhoto) {
      return;
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final category = _categoryController.text.trim();
    final DiscountResult? priceResult = _priceResult;

    if (title.isEmpty) {
      _showMessage('Please enter product name.');
      return;
    }

    if (priceResult == null || priceResult.original <= 0) {
      _showMessage('Please enter a valid price.');
      return;
    }

    if (priceResult.finalPrice <= 0) {
      _showMessage('Discount must be less than the total price.');
      return;
    }

    if (description.isEmpty) {
      _showMessage('Please enter product description.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Please login first.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final productRef = FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId);

      final productSnapshot = await productRef.get();

      if (!productSnapshot.exists) {
        throw Exception('Product does not exist anymore.');
      }

      final productData = productSnapshot.data();

      if (productData == null) {
        throw Exception('Product data could not be loaded.');
      }

      // SELLER OWNERSHIP CHECK
      final sellerId = productData['sellerId']?.toString();

      if (sellerId != user.uid) {
        throw Exception('You can only edit your own products.');
      }

      // PRESERVE IMPORTANT SELLER DATA
      final sellerCode = productData['sellerCode'];

      final sellerEmail = productData['sellerEmail'];

      // `price` = what the buyer pays (after discount).
      // Cart, checkout and orders use it, so they stay correct.
      final bool hasDiscount = priceResult.hasDiscount;

      await productRef.update({
        'name': title,
        'price': priceResult.finalPrice,
        'currency': 'BDT',
        'currencySymbol': '৳',
        'originalPrice':
            hasDiscount ? priceResult.original : priceResult.finalPrice,
        'discountAmount': hasDiscount ? priceResult.amount : 0,
        'discountPercent': hasDiscount ? priceResult.percent : 0,
        'hasDiscount': hasDiscount,
        'description': description,
        'category': category.isNotEmpty ? category : 'General',
        'imageUrl': _currentImageUrl,
        'sellerId': sellerId,
        'sellerCode': sellerCode,
        'sellerEmail': sellerEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product updated successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // =========================================================
  // IMAGE PREVIEW
  // =========================================================

  Widget _imagePreview() {
    if (_pickedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(
          _pickedImage!,
          width: double.infinity,
          height: 210,
          fit: BoxFit.cover,
        ),
      );
    }

    if (_currentImageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          _currentImageUrl,
          width: double.infinity,
          height: 210,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _emptyImage();
          },
        ),
      );
    }

    return _emptyImage();
  }

  Widget _emptyImage() {
    return Container(
      width: double.infinity,
      height: 210,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo_outlined,
            size: 46,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 10),
          Text(
            'Tap to choose product image',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();

    super.dispose();
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Product'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingProduct
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // IMAGE
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _imagePreview(),
                          if (_isUploadingPhoto)
                            Container(
                              width: double.infinity,
                              height: 210,
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          if (!_isUploadingPhoto)
                            Positioned(
                              bottom: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.camera_alt_outlined,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Change',
                                      style: TextStyle(
                                        color: Colors.white,
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
                    const SizedBox(height: 20),

                    // PRODUCT NAME
                    TextField(
                      controller: _titleController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Product Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // TOTAL PRICE + DISCOUNT % + DISCOUNT AMOUNT
                    DiscountPriceInput(
                      originalLabel: 'Total Price (BDT)',
                      initialOriginal: _initialTotal,
                      initialDiscountAmount: _initialDiscount,
                      enabled: !_isSaving,
                      onChanged: (DiscountResult value) {
                        _priceResult = value;
                      },
                    ),
                    const SizedBox(height: 14),

                    // CATEGORY
                    TextField(
                      controller: _categoryController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        hintText: 'Example: Men, Women, Electronics',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // DESCRIPTION
                    TextField(
                      controller: _descriptionController,
                      maxLines: 5,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description_outlined),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // SAVE BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_isSaving || _isUploadingPhoto)
                            ? null
                            : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 23,
                                width: 23,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save_outlined),
                                  SizedBox(width: 8),
                                  Text(
                                    'Save Changes',
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
    );
  }
}
