import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  String _email = '';
  String _profileImageUrl = '';

  User? get currentUser => FirebaseAuth.instance.currentUser;

  // =========================================================
  // CLOUDINARY SETTINGS
  // =========================================================

  static const String _cloudName = 'riassg6d';
  static const String _uploadPreset = 'buynova_products';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // =========================================================
  // LOAD PROFILE
  // =========================================================

  Future<void> _loadProfile() async {
    final user = currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};

      if (!mounted) return;

      setState(() {
        _email = user.email ?? data['email']?.toString() ?? '';

        _nameController.text =
            data['name']?.toString() ??
            user.displayName ??
            '';

        _phoneController.text =
            data['phone']?.toString() ?? '';

        _profileImageUrl =
            data['profileImageUrl']?.toString() ?? '';
      });
    } catch (e) {
      debugPrint('Profile loading error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load profile.'),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // =========================================================
  // PICK PHOTO
  // =========================================================

  Future<void> _changePhoto() async {
    if (_isUploadingPhoto || _isSaving) return;

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (pickedFile == null) {
        return;
      }

      await _uploadToCloudinary(File(pickedFile.path));
    } catch (e) {
      debugPrint('Photo selection error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not select photo.'),
        ),
      );
    }
  }

  // =========================================================
  // UPLOAD TO CLOUDINARY
  // =========================================================

  Future<void> _uploadToCloudinary(File imageFile) async {
    if (!mounted) return;

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );

      final request = http.MultipartRequest(
        'POST',
        uri,
      );

      request.fields['upload_preset'] = _uploadPreset;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );

      final streamedResponse = await request.send();

      final response = await http.Response.fromStream(
        streamedResponse,
      );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'Cloudinary upload failed: ${response.statusCode}',
        );
      }

      final Map<String, dynamic> result =
          jsonDecode(response.body);

      final String? secureUrl =
          result['secure_url']?.toString();

      if (secureUrl == null || secureUrl.isEmpty) {
        throw Exception(
          'Cloudinary did not return an image URL.',
        );
      }

      final user = currentUser;

      if (user == null) {
        throw Exception('User is not logged in.');
      }

      // Save image URL directly to Firestore.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'profileImageUrl': secureUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _profileImageUrl = secureUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile photo uploaded successfully!',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Photo upload failed. Please try again.',
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
  // SAVE PROFILE
  // =========================================================

  Future<void> _saveChanges() async {
    final user = currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first.'),
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name.'),
        ),
      );
      return;
    }

    if (_isUploadingPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please wait until the photo upload finishes.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'uid': user.uid,
          'email': user.email,
          'name': name,
          'phone': phone,
          'profileImageUrl': _profileImageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await user.updateDisplayName(name);
      await user.reload();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile updated successfully!',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint('Profile save error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save your profile. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // =========================================================
  // PROFILE PHOTO
  // =========================================================

  Widget _profilePhoto() {
    if (_profileImageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 58,
        backgroundImage: NetworkImage(
          _profileImageUrl,
        ),
      );
    }

    return const CircleAvatar(
      radius: 58,
      child: Icon(
        Icons.person,
        size: 62,
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
      ),

      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // =================================================
                  // PROFILE PHOTO
                  // =================================================

                  Stack(
                    alignment: Alignment.center,
                    children: [
                      _profilePhoto(),

                      if (_isUploadingPhoto)
                        Container(
                          width: 116,
                          height: 116,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black54,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // =================================================
                  // CHANGE PHOTO
                  // =================================================

                  OutlinedButton.icon(
                    onPressed:
                        (_isUploadingPhoto || _isSaving)
                            ? null
                            : _changePhoto,
                    icon: const Icon(
                      Icons.camera_alt_outlined,
                    ),
                    label: Text(
                      _isUploadingPhoto
                          ? 'Uploading...'
                          : 'Change Photo',
                    ),
                  ),

                  const SizedBox(height: 30),

                  // =================================================
                  // NAME
                  // =================================================

                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter your name',
                      prefixIcon: Icon(
                        Icons.person_outline,
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // =================================================
                  // PHONE
                  // =================================================

                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: 'Enter your phone number',
                      prefixIcon: Icon(
                        Icons.phone_outlined,
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // =================================================
                  // EMAIL
                  // =================================================

                  TextField(
                    controller: TextEditingController(
                      text: _email,
                    ),
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                      ),
                      suffixIcon: Icon(
                        Icons.lock_outline,
                      ),
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // =================================================
                  // SAVE
                  // =================================================

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed:
                          (_isSaving || _isUploadingPhoto)
                              ? null
                              : _saveChanges,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.save_outlined,
                            ),
                      label: Text(
                        _isSaving
                            ? 'Saving...'
                            : 'Save Changes',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
