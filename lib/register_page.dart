import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import 'home_page.dart';

enum _PasswordStrength {
  empty,
  weak,
  medium,
  strong,
}

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

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  static final RegExp _emailRegExp = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]"
    r"(?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?"
    r"(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );

  static final RegExp _phoneRegExp = RegExp(
    r'^\+?[0-9]{10,14}$',
  );

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

  // ============================================================
  // REAL-TIME VALIDATION
  // ============================================================

  void _onNameChanged() {
    final name = _nameController.text.trim();

    if (!mounted) return;

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

    if (!mounted) return;

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

    if (!mounted) return;

    setState(() {
      if (phone.isEmpty) {
        _phoneError = null;
      } else if (!_phoneRegExp.hasMatch(phone)) {
        _phoneError = 'Enter a valid phone number.';
      } else {
        _phoneError = null;
      }
    });
  }

  void _onPasswordChanged() {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (!mounted) return;

    // IMPORTANT:
    // Do NOT call _onConfirmChanged() here because that method
    // contains its own setState(). Doing that caused nested setState().
    setState(() {
      _passwordStrength = _calculateStrength(password);

      if (password.isNotEmpty && password.length < 6) {
        _passwordError = 'Password must be at least 6 characters.';
      } else {
        _passwordError = null;
      }

      // Re-check confirm password inside the SAME setState.
      if (confirmPassword.isNotEmpty) {
        if (confirmPassword != password) {
          _confirmError = 'Passwords do not match.';
        } else {
          _confirmError = null;
        }
      }
    });
  }

  void _onConfirmChanged() {
    final confirm = _confirmPasswordController.text;
    final password = _passwordController.text;

    if (!mounted) return;

    setState(() {
      if (confirm.isEmpty) {
        _confirmError = null;
      } else if (confirm != password) {
        _confirmError = 'Passwords do not match.';
      } else {
        _confirmError = null;
      }
    });
  }

  _PasswordStrength _calculateStrength(String password) {
    if (password.isEmpty) {
      return _PasswordStrength.empty;
    }

    int score = 0;

    if (password.length >= 6) {
      score++;
    }

    if (password.length >= 10) {
      score++;
    }

    if (RegExp(r'[A-Z]').hasMatch(password)) {
      score++;
    }

    if (RegExp(r'[0-9]').hasMatch(password)) {
      score++;
    }

    if (RegExp(r'[!@#$%^&*(),.?":{}|<>_\-]').hasMatch(password)) {
      score++;
    }

    if (score <= 1) {
      return _PasswordStrength.weak;
    }

    if (score <= 3) {
      return _PasswordStrength.medium;
    }

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

  // ============================================================
  // IMAGE PICKING
  // ============================================================

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );

      if (image == null) {
        return;
      }

      final bytes = await image.readAsBytes();

      if (!mounted) {
        return;
      }

      setState(() {
        _pickedImageBytes = bytes;
      });
    } catch (e) {
      _showMessage(
        'Unable to pick an image. Please try again.',
      );
    }
  }

  Future<String?> _uploadProfileImage(String uid) async {
    final bytes = _pickedImageBytes;

    if (bytes == null) {
      return null;
    }

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images/$uid.jpg');

      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'image/jpeg',
        ),
      );

      return await ref.getDownloadURL();
    } catch (e) {
      // Profile image failure should not stop account creation.
      return null;
    }
  }

  // ============================================================
  // FULL VALIDATION
  // ============================================================

  bool _runFullValidation() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (!mounted) {
      return false;
    }

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

  // ============================================================
  // SEND VERIFICATION EMAIL
  // ============================================================

  Future<void> _sendVerificationEmail(User user) async {
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(
        code: 'verification-email-failed',
        message: e.message,
      );
    } catch (_) {
      throw FirebaseAuthException(
        code: 'verification-email-failed',
        message: 'Unable to send the verification email.',
      );
    }
  }

  // ============================================================
  // REGISTRATION
  // ============================================================

  Future<void> _handleRegister() async {
    if (_isLoading || _isSocialLoading) {
      return;
    }

    if (!_runFullValidation()) {
      if (!_agreedToTerms) {
        _showMessage(
          'Please agree to the Terms & Conditions.',
        );
      }

      return;
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (!mounted) {
      return;
    }

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

      // ----------------------------------------------------------
      // Update Firebase Auth profile
      // ----------------------------------------------------------

      await user.updateDisplayName(name);

      final photoUrl = await _uploadProfileImage(user.uid);

      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      // ----------------------------------------------------------
      // Create Firestore profile
      // ----------------------------------------------------------

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(
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
      } catch (_) {
        // If Firestore profile creation fails, try to remove
        // the newly-created Auth account.
        try {
          await user.delete();
        } catch (_) {
          await FirebaseAuth.instance.signOut();
        }

        throw FirebaseAuthException(
          code: 'profile-save-failed',
          message: 'Could not save your profile. Please try again.',
        );
      }

      // ----------------------------------------------------------
      // SEND EMAIL VERIFICATION LINK
      // ----------------------------------------------------------

      await _sendVerificationEmail(user);

      if (!mounted) {
        return;
      }

      // ----------------------------------------------------------
      // OPEN VERIFICATION PAGE
      // ----------------------------------------------------------

      final verificationCompleted = await _showVerificationPage(email);

      if (!mounted) {
        return;
      }

      // IMPORTANT:
      // If user presses "Back to Login" without verifying,
      // registration is NOT treated as completed.
      if (verificationCompleted != true) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) {
          return;
        }

        _showMessage(
          'Please verify your email before logging in.',
        );

        Navigator.of(context).pop();
        return;
      }

      // ----------------------------------------------------------
      // VERIFIED SUCCESS
      // ----------------------------------------------------------

      await FirebaseAuth.instance.signOut();

      if (!mounted) {
        return;
      }

      _showSuccessMessage(
        'Account created and email verified. Please login to continue.',
      );

      await Future<void>.delayed(
        const Duration(milliseconds: 500),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      String errorMessage =
          'Unable to create your account.';

      switch (e.code) {
        case 'email-already-in-use':
          errorMessage =
              'An account already exists with this email.';
          break;

        case 'invalid-email':
          errorMessage =
              'Please enter a valid email address.';
          break;

        case 'weak-password':
          errorMessage =
              'The password is too weak.';
          break;

        case 'operation-not-allowed':
          errorMessage =
              'Email and password authentication is disabled.';
          break;

        case 'network-request-failed':
          errorMessage =
              'Network error. Please check your connection.';
          break;

        case 'too-many-requests':
          errorMessage =
              'Too many requests. Please try again later.';
          break;

        case 'verification-email-failed':
          errorMessage =
              'Your account was created, but the verification email could not be sent. Please check your internet connection and try again.';
          break;

        case 'profile-save-failed':
          errorMessage =
              e.message ??
              'Could not save your profile. Please try again.';
          break;

        case 'registration-failed':
          errorMessage =
              e.message ??
              'Unable to create your account.';
          break;

        default:
          errorMessage =
              e.message ??
              errorMessage;
      }

      _showMessage(errorMessage);
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // SOCIAL SIGN-IN
  // ============================================================

  Future<void> _saveSocialUserToFirestore(User user) async {
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

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

    await docRef.set(
      data,
      SetOptions(merge: true),
    );
  }

  void _goToAppHomeAfterSocialLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const HomePage(),
      ),
      (route) => false,
    );
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading || _isSocialLoading) {
      return;
    }

    setState(() {
      _isSocialLoading = true;
    });

    try {
      final GoogleSignInAccount? googleUser =
          await _googleSignIn.signIn();

      if (googleUser == null) {
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final user = userCredential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'google-sign-in-failed',
          message: 'Could not sign in with Google.',
        );
      }

      await _saveSocialUserToFirestore(user);

      if (!mounted) {
        return;
      }

      _showSuccessMessage(
        'Signed in with Google.',
      );

      _goToAppHomeAfterSocialLogin();
    } on FirebaseAuthException catch (e) {
      _showFirebaseAuthError(e);
    } catch (_) {
      _showMessage(
        'Google sign-in failed. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSocialLoading = false;
        });
      }
    }
  }

  Future<void> _handleFacebookSignIn() async {
    if (_isLoading || _isSocialLoading) {
      return;
    }

    setState(() {
      _isSocialLoading = true;
    });

    try {
      final LoginResult result =
          await FacebookAuth.instance.login(
        permissions: [
          'email',
          'public_profile',
        ],
      );

      if (result.status == LoginStatus.cancelled) {
        return;
      }

      if (result.status != LoginStatus.success ||
          result.accessToken == null) {
        throw FirebaseAuthException(
          code: 'facebook-sign-in-failed',
          message: result.message ??
              'Could not sign in with Facebook.',
        );
      }

      final credential =
          FacebookAuthProvider.credential(
        result.accessToken!.tokenString,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final user = userCredential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'facebook-sign-in-failed',
          message: 'Could not sign in with Facebook.',
        );
      }

      await _saveSocialUserToFirestore(user);

      if (!mounted) {
        return;
      }

      _showSuccessMessage(
        'Signed in with Facebook.',
      );

      _goToAppHomeAfterSocialLogin();
    } on FirebaseAuthException catch (e) {
      _showFirebaseAuthError(e);
    } catch (_) {
      _showMessage(
        'Facebook sign-in failed. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSocialLoading = false;
        });
      }
    }
  }

  void _showFirebaseAuthError(
    FirebaseAuthException e,
  ) {
    String message =
        'Unable to complete sign-in.';

    switch (e.code) {
      case 'account-exists-with-different-credential':
        message =
            'An account already exists with the same email but a different sign-in method.';
        break;

      case 'invalid-credential':
        message =
            'The sign-in credential is invalid or has expired.';
        break;

      case 'network-request-failed':
        message =
            'Network error. Please check your connection.';
        break;

      case 'user-disabled':
        message =
            'This account has been disabled.';
        break;

      default:
        message =
            e.message ?? message;
    }

    _showMessage(message);
  }

  // ============================================================
  // VERIFICATION PAGE
  // ============================================================

  Future<bool?> _showVerificationPage(
    String email,
  ) async {
    if (!mounted) {
      return false;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EmailVerificationPage(
          email: email,
        ),
      ),
    );

    return result;
  }

  // ============================================================
  // MESSAGES
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

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
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
  }

  // ============================================================
  // REGISTER UI
  // ============================================================

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
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),

                // PROFILE IMAGE
                GestureDetector(
                  onTap: _isLoading
                      ? null
                      : _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor:
                            const Color(0xFFDCE8F8),
                        backgroundImage:
                            _pickedImageBytes != null
                                ? MemoryImage(
                                    _pickedImageBytes!,
                                  )
                                : null,
                        child:
                            _pickedImageBytes == null
                                ? const Icon(
                                    Icons.person_add_alt_1,
                                    size: 40,
                                    color: Color(
                                      0xFF326295,
                                    ),
                                  )
                                : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding:
                              const EdgeInsets.all(4),
                          decoration:
                              const BoxDecoration(
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

                // NAME
                TextField(
                  controller: _nameController,
                  textInputAction:
                      TextInputAction.next,
                  textCapitalization:
                      TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(
                      Icons.person_outline,
                    ),
                    border:
                        const OutlineInputBorder(),
                    errorText: _nameError,
                  ),
                ),

                const SizedBox(height: 16),

                // EMAIL
                TextField(
                  controller: _emailController,
                  keyboardType:
                      TextInputType.emailAddress,
                  textInputAction:
                      TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                    ),
                    border:
                        const OutlineInputBorder(),
                    errorText: _emailError,
                  ),
                ),

                const SizedBox(height: 16),

                // PHONE
                TextField(
                  controller: _phoneController,
                  keyboardType:
                      TextInputType.phone,
                  textInputAction:
                      TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Phone (optional)',
                    prefixIcon: const Icon(
                      Icons.phone_outlined,
                    ),
                    border:
                        const OutlineInputBorder(),
                    errorText: _phoneError,
                  ),
                ),

                const SizedBox(height: 16),

                // PASSWORD
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction:
                      TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                    ),
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
                                _obscurePassword =
                                    !_obscurePassword;
                              });
                            },
                    ),
                    border:
                        const OutlineInputBorder(),
                    errorText: _passwordError,
                  ),
                ),

                if (_passwordStrength !=
                    _PasswordStrength.empty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(4),
                          child:
                              LinearProgressIndicator(
                            value:
                                _strengthFraction(),
                            minHeight: 6,
                            backgroundColor:
                                Colors.grey.shade300,
                            color:
                                _strengthColor(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _strengthLabel(),
                        style: TextStyle(
                          color:
                              _strengthColor(),
                          fontWeight:
                              FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // CONFIRM PASSWORD
                TextField(
                  controller:
                      _confirmPasswordController,
                  obscureText:
                      _obscureConfirmPassword,
                  textInputAction:
                      TextInputAction.done,
                  onSubmitted: (_) {
                    if (!_isLoading) {
                      _handleRegister();
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(
                      Icons.lock_reset_outlined,
                    ),
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
                    border:
                        const OutlineInputBorder(),
                    errorText: _confirmError,
                  ),
                ),

                const SizedBox(height: 16),

                // TERMS
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreedToTerms,
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              setState(() {
                                _agreedToTerms =
                                    value ?? false;

                                if (_agreedToTerms) {
                                  _showTermsError =
                                      false;
                                }
                              });
                            },
                    ),
                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.only(
                          top: 12,
                        ),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              color: Colors.black87,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    'I agree to the ',
                              ),
                              TextSpan(
                                text:
                                    'Terms & Conditions',
                                style: TextStyle(
                                  color:
                                      Color(0xFF326295),
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                              TextSpan(
                                text: ' and ',
                              ),
                              TextSpan(
                                text:
                                    'Privacy Policy',
                                style: TextStyle(
                                  color:
                                      Color(0xFF326295),
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                              TextSpan(
                                text: '.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                if (_showTermsError)
                  Align(
                    alignment:
                        Alignment.centerLeft,
                    child: Padding(
                      padding:
                          const EdgeInsets.only(
                        left: 12,
                      ),
                      child: Text(
                        'You must agree to continue.',
                        style: TextStyle(
                          color:
                              Theme.of(context)
                                  .colorScheme
                                  .error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // CREATE ACCOUNT
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF326295),
                      disabledBackgroundColor:
                          const Color(0xFF9DB1C8),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          25,
                        ),
                      ),
                    ),
                    onPressed: _isLoading
                        ? null
                        : _handleRegister,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  Colors.white,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // OR
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color:
                            Colors.grey.shade400,
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 10,
                      ),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color:
                              Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color:
                            Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // GOOGLE
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style:
                        OutlinedButton.styleFrom(
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          25,
                        ),
                      ),
                      side: BorderSide(
                        color:
                            Colors.grey.shade400,
                      ),
                    ),
                    onPressed:
                        (_isLoading ||
                                _isSocialLoading)
                            ? null
                            : _handleGoogleSignIn,
                    icon: _isSocialLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const CircleAvatar(
                            radius: 10,
                            backgroundColor:
                                Colors.white,
                            child: Text(
                              'G',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight
                                        .bold,
                                fontSize: 13,
                                color: Color(
                                  0xFF4285F4,
                                ),
                              ),
                            ),
                          ),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(
                        color:
                            Colors.black87,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // FACEBOOK
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(
                        0xFF1877F2,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          25,
                        ),
                      ),
                    ),
                    onPressed:
                        (_isLoading ||
                                _isSocialLoading)
                            ? null
                            : _handleFacebookSignIn,
                    icon: _isSocialLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.facebook,
                            color:
                                Colors.white,
                          ),
                    label: const Text(
                      'Continue with Facebook',
                      style: TextStyle(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed:
                      (_isLoading ||
                              _isSocialLoading)
                          ? null
                          : () {
                              Navigator.pop(
                                context,
                              );
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

// ============================================================================
// EMAIL VERIFICATION PAGE
// ============================================================================

class EmailVerificationPage extends StatefulWidget {
  final String email;

  const EmailVerificationPage({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState
    extends State<EmailVerificationPage> {
  bool _isChecking = false;
  bool _isResending = false;

  Timer? _autoPollTimer;
  Timer? _cooldownTimer;

  int _resendCooldown = 0;

  static const int _resendCooldownSeconds = 60;

  static const Duration _autoPollInterval =
      Duration(seconds: 5);

  @override
  void initState() {
    super.initState();

    _startAutoPolling();
  }

  @override
  void dispose() {
    _autoPollTimer?.cancel();
    _cooldownTimer?.cancel();

    super.dispose();
  }

  // ============================================================
  // AUTO CHECK
  // ============================================================

  void _startAutoPolling() {
    _autoPollTimer =
        Timer.periodic(_autoPollInterval, (_) {
      _checkVerification(
        silent: true,
      );
    });
  }

  // ============================================================
  // RESEND COOLDOWN
  // ============================================================

  void _startResendCooldown() {
    if (!mounted) {
      return;
    }

    setState(() {
      _resendCooldown =
          _resendCooldownSeconds;
    });

    _cooldownTimer?.cancel();

    _cooldownTimer =
        Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          if (_resendCooldown > 0) {
            _resendCooldown--;
          }
        });

        if (_resendCooldown <= 0) {
          timer.cancel();
        }
      },
    );
  }

  // ============================================================
  // CHECK VERIFICATION
  // ============================================================

  Future<void> _checkVerification({
    bool silent = false,
  }) async {
    if (_isChecking) {
      return;
    }

    if (!silent) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isChecking = true;
      });
    }

    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!silent) {
          _showMessage(
            'Your session has expired. Please login again.',
          );
        }

        return;
      }

      await user.reload();

      final refreshedUser =
          FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        if (!silent) {
          _showMessage(
            'Unable to check your account. Please login again.',
          );
        }

        return;
      }

      if (refreshedUser.emailVerified) {
        _autoPollTimer?.cancel();

        if (!mounted) {
          return;
        }

        _showSuccessMessage(
          'Email verified successfully.',
        );

        await Future<void>.delayed(
          const Duration(milliseconds: 500),
        );

        if (!mounted) {
          return;
        }

        Navigator.pop(
          context,
          true,
        );

        return;
      }

      if (!silent) {
        _showMessage(
          'Your email is not verified yet. Please open the verification link in your email and try again.',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!silent) {
        _showFirebaseError(e);
      }
    } catch (_) {
      if (!silent) {
        _showMessage(
          'Unable to check email verification status.',
        );
      }
    } finally {
      if (mounted && !silent) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  // ============================================================
  // RESEND VERIFICATION
  // ============================================================

  Future<void> _resendVerification() async {
    if (_isResending ||
        _resendCooldown > 0) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isResending = true;
    });

    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showMessage(
          'Your session has expired. Please login again.',
        );

        return;
      }

      await user.reload();

      final refreshedUser =
          FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        _showMessage(
          'Unable to access your account.',
        );

        return;
      }

      if (refreshedUser.emailVerified) {
        _showSuccessMessage(
          'Your email is already verified.',
        );

        return;
      }

      // Firebase sends the normal verification LINK.
      await refreshedUser.sendEmailVerification();

      _showSuccessMessage(
        'A new verification email has been sent.',
      );

      _startResendCooldown();
    } on FirebaseAuthException catch (e) {
      _showFirebaseError(e);
    } catch (_) {
      _showMessage(
        'Unable to send the verification email.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  // ============================================================
  // FIREBASE ERROR
  // ============================================================

  void _showFirebaseError(
    FirebaseAuthException e,
  ) {
    String message =
        'Unable to complete the request.';

    switch (e.code) {
      case 'too-many-requests':
        message =
            'Too many requests. Please wait and try again later.';
        break;

      case 'network-request-failed':
        message =
            'Network error. Please check your internet connection.';
        break;

      case 'user-not-found':
        message =
            'The account could not be found.';
        break;

      case 'invalid-email':
        message =
            'The email address is invalid.';
        break;

      case 'user-disabled':
        message =
            'This account has been disabled.';
        break;

      case 'requires-recent-login':
        message =
            'Please login again and try this action.';
        break;

      case 'too-many-requests':
        message =
            'Too many verification requests. Please wait before requesting another email.';
        break;

      default:
        if (e.message != null &&
            e.message!.isNotEmpty) {
          message =
              '${e.code}: ${e.message}';
        } else {
          message = e.code;
        }
    }

    _showMessage(message);
  }

  // ============================================================
  // MESSAGES
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
  }

  void _showSuccessMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
  }

  // ============================================================
  // VERIFICATION UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Verify Your Email'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(24),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 46,
                  backgroundColor:
                      Color(0xFFDCE8F8),
                  child: Icon(
                    Icons
                        .mark_email_read_outlined,
                    size: 48,
                    color:
                        Color(0xFF326295),
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Check Your Email',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'We sent a verification link to:',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color:
                        Colors.grey.shade700,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  widget.email,
                  textAlign:
                      TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  'Open the email and tap the verification link. '
                  'This page will automatically detect when your '
                  'email is verified, or you can tap '
                  '"I Have Verified" yourself.',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 30),

                // I HAVE VERIFIED
                SizedBox(
                  width:
                      double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(
                        0xFF326295,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          25,
                        ),
                      ),
                    ),
                    onPressed: _isChecking
                        ? null
                        : () =>
                            _checkVerification(),
                    child: _isChecking
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Text(
                            'I Have Verified',
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  Colors.white,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 14),

                // RESEND
                SizedBox(
                  width:
                      double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    style:
                        OutlinedButton.styleFrom(
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          25,
                        ),
                      ),
                      side:
                          const BorderSide(
                        color:
                            Color(0xFF326295),
                      ),
                    ),
                    onPressed:
                        (_isResending ||
                                _resendCooldown >
                                    0)
                            ? null
                            : _resendVerification,
                    child: _isResending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _resendCooldown >
                                    0
                                ? 'Resend in ${_resendCooldown}s'
                                : 'Resend Verification Email',
                            style:
                                const TextStyle(
                              color:
                                  Color(
                                0xFF326295,
                              ),
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 18),

                // BACK TO LOGIN
                TextButton(
                  onPressed:
                      _isChecking ||
                              _isResending
                          ? null
                          : () async {
                              _autoPollTimer
                                  ?.cancel();

                              await FirebaseAuth
                                  .instance
                                  .signOut();

                              if (!mounted) {
                                return;
                              }

                              Navigator.pop(
                                context,
                                false,
                              );
                            },
                  child: const Text(
                    'Back to Login',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
