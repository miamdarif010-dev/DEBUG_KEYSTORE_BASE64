// NOTE: This file uses extra packages beyond what the original code used.
// Add these to your pubspec.yaml if they are not already there:
//
//   dependencies:
//     image_picker: ^1.1.2
//     firebase_storage: ^12.3.2
//     google_sign_in: ^6.2.1
//     flutter_facebook_auth: ^7.1.1
//
// Google sign-in also needs your SHA-1/SHA-256 fingerprints added in the
// Firebase console (Android) and the reversed client ID URL scheme in
// Info.plist (iOS). Facebook sign-in needs a Facebook App ID configured in
// AndroidManifest.xml / Info.plist per the flutter_facebook_auth setup guide.
// Everything else (firebase_auth, cloud_firestore, flutter) was already in use.
//
// Email verification has been intentionally removed: accounts are created
// and the person is taken straight into the app. If you want email
// verification back later, re-add a call to `user.sendEmailVerification()`
// after account creation and gate HomePage access on `user.emailVerified`
// in login_page.dart, but first make sure Firebase is actually able to
// deliver those emails (check the Firebase console's Auth > Templates
// settings and your project's email quota).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import 'home_page.dart';

enum _PasswordStrength { empty, weak, medium, strong }

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isSocialLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  bool _showTermsError = false;

  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _confirmError;

  _PasswordStrength _passwordStrength = _PasswordStrength.empty;

  Uint8List? _pickedImageBytes;
  final ImagePicker _imagePicker = ImagePicker();

  // Reused across calls instead of creating a new instance every sign-in
  // attempt; GoogleSignIn keeps internal session state that is best kept
  // alive for the lifetime of this widget.
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  static final RegExp _emailRegExp = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );

  // Bangladeshi-style phone numbers (adjust to your target market as needed).
  static final RegExp _phoneRegExp = RegExp(r'^\+?[0-9]{10,14}$');

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
    _emailController.addListener(_onEmailChanged);
    _phoneController.addListener(_onPhoneChanged);
    _passwordController.addListener(_onPasswordChanged);
    _confirmPasswordController.addListener(_onConfirmChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ---------------- Real-time validation ----------------

  void _onNameChanged() {
    final name = _nameController.text.trim();
    setState(() {
      if (name.isEmpty) {
        _nameError = null;
      } else if (name.length < 2) {
        _nameError = 'Name is too short.';
      } else {
        _nameError = null;
      }
    });
  }

  void _onEmailChanged() {
    final email = _emailController.text.trim();
    setState(() {
      if (email.isEmpty) {
        _emailError = null;
      } else if (!_emailRegExp.hasMatch(email)) {
        _emailError = 'Enter a valid email address.';
      } else {
        _emailError = null;
      }
    });
  }

  void _onPhoneChanged() {
    final phone = _phoneController.text.trim();
    setState(() {
      if (phone.isEmpty) {
        _phoneError = null; // phone is optional
      } else if (!_phoneRegExp.hasMatch(phone)) {
        _phoneError = 'Enter a valid phone number.';
      } else {
        _phoneError = null;
      }
    });
  }

  void _onPasswordChanged() {
    final password = _passwordController.text;
    setState(() {
      _passwordStrength = _calculateStrength(password);
      if (password.isNotEmpty && password.length < 6) {
        _passwordError = 'Password must be at least 6 characters.';
      } else {
        _passwordError = null;
      }
      // Re-check confirm field if it was already filled in.
      if (_confirmPasswordController.text.isNotEmpty) {
        _onConfirmChanged();
      }
    });
  }

  void _onConfirmChanged() {
    final confirm = _confirmPasswordController.text;
    setState(() {
      if (confirm.isEmpty) {
        _confirmError = null;
      } else if (confirm != _passwordController.text) {
        _confirmError = 'Passwords do not match.';
      } else {
        _confirmError = null;
      }
    });
  }

  _PasswordStrength _calculateStrength(String password) {
    if (password.isEmpty) return _PasswordStrength.empty;

    int score = 0;
    if (password.length >= 6) score++;
    if (password.length >= 10) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>_\-]').hasMatch(password)) score++;

    if (score <= 1) return _PasswordStrength.weak;
    if (score <= 3) return _PasswordStrength.medium;
    return _PasswordStrength.strong;
  }

  Color _strengthColor() {
    switch (_passwordStrength) {
      case _PasswordStrength.weak:
        return Colors.red;
      case _PasswordStrength.medium:
        return Colors.orange;
      case _PasswordStrength.strong:
        return Colors.green;
      case _PasswordStrength.empty:
        return Colors.transparent;
    }
  }

  String _strengthLabel() {
    switch (_passwordStrength) {
      case _PasswordStrength.weak:
        return 'Weak';
      case _PasswordStrength.medium:
        return 'Medium';
      case _PasswordStrength.strong:
        return 'Strong';
      case _PasswordStrength.empty:
        return '';
    }
  }

  double _strengthFraction() {
    switch (_passwordStrength) {
      case _PasswordStrength.weak:
        return 1 / 3;
      case _PasswordStrength.medium:
        return 2 / 3;
      case _PasswordStrength.strong:
        return 1.0;
      case _PasswordStrength.empty:
        return 0.0;
    }
  }

  // ---------------- Image picking ----------------

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      // Read bytes up front (instead of relying on dart:io File) so the
      // preview and the upload both work on mobile, desktop, and web.
      final bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        _pickedImageBytes = bytes;
      });
    } catch (e) {
      _showMessage('Unable to pick an image. Please try again.');
    }
  }

  Future<String?> _uploadProfileImage(String uid) async {
    final bytes = _pickedImageBytes;

    if (bytes == null) return null;

    try {
      final ref =
          FirebaseStorage.instance.ref().child('profile_images/$uid.jpg');

      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      return await ref.getDownloadURL();
    } catch (e) {
      // Non-fatal: registration should still succeed without a profile photo.
      return null;
    }
  }

  // ---------------- Registration ----------------

  bool _runFullValidation() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      if (name.isEmpty) {
        _nameError = 'Please enter your full name.';
      } else if (name.length < 2) {
        _nameError = 'Name is too short.';
      } else {
        _nameError = null;
      }

      if (email.isEmpty) {
        _emailError = 'Please enter your email address.';
      } else if (!_emailRegExp.hasMatch(email)) {
        _emailError = 'Enter a valid email address.';
      } else {
        _emailError = null;
      }

      if (phone.isNotEmpty && !_phoneRegExp.hasMatch(phone)) {
        _phoneError = 'Enter a valid phone number.';
      } else {
        _phoneError = null;
      }

      if (password.isEmpty) {
        _passwordError = 'Please enter a password.';
      } else if (password.length < 6) {
        _passwordError = 'Password must be at least 6 characters.';
      } else {
        _passwordError = null;
      }

      if (confirmPassword.isEmpty) {
        _confirmError = 'Please confirm your password.';
      } else if (confirmPassword != password) {
        _confirmError = 'Passwords do not match.';
      } else {
        _confirmError = null;
      }

      _showTermsError = !_agreedToTerms;
    });

    return _nameError == null &&
        _emailError == null &&
        _phoneError == null &&
        _passwordError == null &&
        _confirmError == null &&
        _agreedToTerms;
  }

  Future<void> _handleRegister() async {
    if (!_runFullValidation()) {
      if (!_agreedToTerms) {
        _showMessage('Please agree to the Terms & Conditions.');
      }
      return;
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'registration-failed',
          message: 'User account could not be created.',
        );
      }

      await user.updateDisplayName(name);

      final photoUrl = await _uploadProfileImage(user.uid);
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {
            'uid': user.uid,
            'name': name,
            'email': email,
            'phone': phone,
            'profileImageUrl': photoUrl ?? '',
            'sellerStatus': 'none',
            'entrepreneurStatus': 'none',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } catch (firestoreError) {
        // Prevent an orphaned Auth account with no Firestore profile:
        // roll back by deleting the just-created Auth user.
        try {
          await user.delete();
        } catch (_) {
          // If deletion also fails, at least sign out so no broken
          // session lingers on the device.
          await FirebaseAuth.instance.signOut();
        }
        throw FirebaseAuthException(
          code: 'profile-save-failed',
          message: 'Could not save your profile. Please try again.',
        );
      }

      if (!mounted) return;

      // No email verification step: the account is already signed in from
      // createUserWithEmailAndPassword above, so take the person straight
      // into the app and clear the auth stack behind them.
      _showSuccessMessage('Account created successfully.');

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const HomePage(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Unable to create your account.';

      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'An account already exists with this email.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'weak-password':
          errorMessage = 'The password is too weak.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email and password authentication is disabled.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many requests. Please try again later.';
          break;
        case 'profile-save-failed':
          errorMessage = e.message ?? errorMessage;
          break;
      }

      _showMessage(errorMessage);
    } catch (e) {
      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ---------------- Social sign-in ----------------

  Future<void> _saveSocialUserToFirestore(User user) async {
    final docRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await docRef.get();

    final data = <String, dynamic>{
      'uid': user.uid,
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'phone': user.phoneNumber ?? '',
      'profileImageUrl': user.photoURL ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snapshot.exists) {
      data['sellerStatus'] = 'none';
      data['entrepreneurStatus'] = 'none';
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(data, SetOptions(merge: true));
  }

  void _goToAppHomeAfterSocialLogin() {
    // Google/Facebook accounts arrive already email-verified, so there is
    // no separate verification step for them â€” go straight to HomePage
    // and clear the auth stack so "back" doesn't return to login/register.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomePage()),
      (route) => false,
    );
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading || _isSocialLoading) return;

    setState(() {
      _isSocialLoading = true;
    });

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in flow.
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'google-sign-in-failed',
          message: 'Could not sign in with Google.',
        );
      }

      await _saveSocialUserToFirestore(user);

      if (!mounted) return;

      _showSuccessMessage('Signed in with Google.');
      _goToAppHomeAfterSocialLogin();
    } on FirebaseAuthException catch (e) {
      _showFirebaseAuthError(e);
    } catch (e) {
      _showMessage('Google sign-in failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSocialLoading = false;
        });
      }
    }
  }

  Future<void> _handleFacebookSignIn() async {
    if (_isLoading || _isSocialLoading) return;

    setState(() {
      _isSocialLoading = true;
    });

    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.cancelled) {
        return;
      }

      if (result.status != LoginStatus.success ||
          result.accessToken == null) {
        throw FirebaseAuthException(
          code: 'facebook-sign-in-failed',
          message: result.message ?? 'Could not sign in with Facebook.',
        );
      }

      final credential = FacebookAuthProvider.credential(
        result.accessToken!.tokenString,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'facebook-sign-in-failed',
          message: 'Could not sign in with Facebook.',
        );
      }

      await _saveSocialUserToFirestore(user);

      if (!mounted) return;

      _showSuccessMessage('Signed in with Facebook.');
      _goToAppHomeAfterSocialLogin();
    } on FirebaseAuthException catch (e) {
      _showFirebaseAuthError(e);
    } catch (e) {
      _showMessage('Facebook sign-in failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSocialLoading = false;
        });
      }
    }
  }

  void _showFirebaseAuthError(FirebaseAuthException e) {
    String message = 'Unable to complete sign-in.';

    switch (e.code) {
      case 'account-exists-with-different-credential':
        message =
            'An account already exists with the same email but a different sign-in method.';
        break;
      case 'invalid-credential':
        message = 'The sign-in credential is invalid or has expired.';
        break;
      case 'network-request-failed':
        message = 'Network error. Please check your connection.';
        break;
      case 'user-disabled':
        message = 'This account has been disabled.';
        break;
      default:
        message = e.message ?? message;
    }

    _showMessage(message);
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _isLoading ? null : _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: const Color(0xFFDCE8F8),
                        backgroundImage: _pickedImageBytes != null
                            ? MemoryImage(_pickedImageBytes!)
                            : null,
                        child: _pickedImageBytes == null
                            ? const Icon(
                                Icons.person_add_alt_1,
                                size: 40,
                                color: Color(0xFF326295),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF326295),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Create your BuyNova account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Join BuyNova and start shopping.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: const OutlineInputBorder(),
                    errorText: _nameError,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: const OutlineInputBorder(),
                    errorText: _emailError,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Phone (optional)',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: const OutlineInputBorder(),
                    errorText: _phoneError,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                    ),
                    border: const OutlineInputBorder(),
                    errorText: _passwordError,
                  ),
                ),
                if (_passwordStrength != _PasswordStrength.empty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _strengthFraction(),
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade300,
                            color: _strengthColor(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _strengthLabel(),
                        style: TextStyle(
                          color: _strengthColor(),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!_isLoading) {
                      _handleRegister();
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                    ),
                    border: const OutlineInputBorder(),
                    errorText: _confirmError,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreedToTerms,
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              setState(() {
                                _agreedToTerms = value ?? false;
                                if (_agreedToTerms) {
                                  _showTermsError = false;
                                }
                              });
                            },
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(color: Colors.black87),
                            children: [
                              TextSpan(text: 'I agree to the '),
                              TextSpan(
                                text: 'Terms & Conditions',
                                style: TextStyle(
                                  color: Color(0xFF326295),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: Color(0xFF326295),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_showTermsError)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        'You must agree to continue.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF326295),
                      disabledBackgroundColor: const Color(0xFF9DB1C8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    onPressed: _isLoading ? null : _handleRegister,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade400)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'OR',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade400)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    onPressed: (_isLoading || _isSocialLoading)
                        ? null
                        : _handleGoogleSignIn,
                    icon: _isSocialLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.white,
                            child: Text(
                              'G',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF4285F4),
                              ),
                            ),
                          ),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1877F2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    onPressed: (_isLoading || _isSocialLoading)
                        ? null
                        : _handleFacebookSignIn,
                    icon: _isSocialLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.facebook, color: Colors.white),
                    label: const Text(
                      'Continue with Facebook',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: (_isLoading || _isSocialLoading)
                      ? null
                      : () {
                          Navigator.pop(context);
                        },
                  child: const Text(
                    'Already have an account? Login',
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
