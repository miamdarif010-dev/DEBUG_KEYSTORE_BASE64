// NOTE: This file also uses flutter_facebook_auth for Facebook sign-in.
// Add this to your pubspec.yaml if it isn't already there:
//
//   dependencies:
//     flutter_facebook_auth: ^7.1.1
//
// Facebook sign-in needs a Facebook App ID configured in
// AndroidManifest.xml / Info.plist per the flutter_facebook_auth setup guide,
// and Facebook must be enabled as a sign-in provider in the Firebase console.
//
// Email verification has been intentionally removed: logging in with a
// correct email/password takes the person straight into HomePage, with no
// "verify your email" gate. If you want it back later, check
// `user.emailVerified` after sign-in and re-add a verification-required
// dialog similar to what used to be here.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import 'home_page.dart';
import 'register_page.dart';

// ============================================================
// TESTING SWITCH
// true  = Google/Facebook errors show the real error text on screen
//         (use this while fixing sign-in problems).
// false = people only see a short friendly message.
// Set this to false before uploading to the Play Store.
// ============================================================
const bool _showDebugErrors = true;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isFacebookLoading = false;
  bool _isResettingPassword = false;
  bool _obscurePassword = true;

  // Reused across calls instead of creating a new instance on every tap.
  // signOut() is still called before signIn() below so the account picker
  // always appears, letting the person switch Google accounts if needed.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
    ],
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Friendly message, plus the real error while testing.
  String _failMessage(String friendly, Object error) {
    if (_showDebugErrors) {
      return '$friendly\n$error';
    }
    return friendly;
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      _showMessage('Please enter your email address.');
      return;
    }

    if (password.isEmpty) {
      _showMessage('Please enter your password.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        _showMessage('Unable to login. Please try again.');
        return;
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomePage(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Unable to login. Please try again.';

      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account was found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'The password is incorrect.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid email or password.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Please try again later.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection.';
          break;
      }

      _showMessage(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isGoogleLoading = true;
    });

    try {
      await _googleSignIn.signOut();

      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return;
      }

      final googleAuthentication = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuthentication.accessToken,
        idToken: googleAuthentication.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;

      if (user == null) {
        _showMessage('Unable to sign in with Google.');
        return;
      }

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      final userSnapshot = await userRef.get();

      if (!userSnapshot.exists) {
        await userRef.set(
          {
            'uid': user.uid,
            'name': user.displayName ?? googleUser.displayName ?? '',
            'email': user.email ?? googleUser.email,
            'phone': '',
            'profileImageUrl': user.photoURL ?? googleUser.photoUrl ?? '',
            'sellerStatus': 'none',
            'entrepreneurStatus': 'none',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } else {
        await userRef.set(
          {
            'uid': user.uid,
            'email': user.email ?? googleUser.email,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomePage(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Unable to sign in with Google.';

      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage =
              'An account already exists with this email using another sign-in method.';
          break;
        case 'credential-already-in-use':
          errorMessage = 'This Google account is already in use.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Google Sign-In is currently disabled.';
          break;
      }

      _showMessage(_failMessage(errorMessage, e.code));
    } catch (e) {
      // Common causes:
      //  ApiException: 10  -> the SHA-1/SHA-256 of the key this APK was
      //                       signed with is not in the Firebase console, or
      //                       google-services.json is an old copy.
      //  ApiException: 12500 -> Google provider or support email not set up
      //                       in Firebase Authentication.
      //  ApiException: 7   -> network problem.
      debugPrint('Google Sign-In error: $e');
      _showMessage(
        _failMessage('Google Sign-In was cancelled or failed.', e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  Future<void> _handleFacebookLogin() async {
    setState(() {
      _isFacebookLoading = true;
    });

    try {
      await FacebookAuth.instance.logOut();

      final result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.cancelled) {
        return;
      }

      if (result.status != LoginStatus.success || result.accessToken == null) {
        _showMessage(
          result.message ?? 'Unable to sign in with Facebook.',
        );
        return;
      }

      final facebookUserData = await FacebookAuth.instance.getUserData(
        fields: 'name,email,picture.width(200)',
      );

      final credential = FacebookAuthProvider.credential(
        result.accessToken!.tokenString,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;

      if (user == null) {
        _showMessage('Unable to sign in with Facebook.');
        return;
      }

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      final userSnapshot = await userRef.get();

      final facebookName = facebookUserData['name'] as String?;
      final facebookEmail = facebookUserData['email'] as String?;
      final facebookPhotoUrl =
          facebookUserData['picture']?['data']?['url'] as String?;

      if (!userSnapshot.exists) {
        await userRef.set(
          {
            'uid': user.uid,
            'name': user.displayName ?? facebookName ?? '',
            'email': user.email ?? facebookEmail ?? '',
            'phone': '',
            'profileImageUrl': user.photoURL ?? facebookPhotoUrl ?? '',
            'sellerStatus': 'none',
            'entrepreneurStatus': 'none',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } else {
        await userRef.set(
          {
            'uid': user.uid,
            'email': user.email ?? facebookEmail ?? '',
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomePage(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Unable to sign in with Facebook.';

      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage =
              'An account already exists with this email using another sign-in method.';
          break;
        case 'credential-already-in-use':
          errorMessage = 'This Facebook account is already in use.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Facebook Sign-In is currently disabled.';
          break;
      }

      _showMessage(_failMessage(errorMessage, e.code));
    } catch (e) {
      // A common cause is the Facebook key hash for this build's keystore
      // not being registered in the Facebook Developer Console, or the
      // Facebook App ID missing in the Android resources.
      debugPrint('Facebook Sign-In error: $e');
      _showMessage(
        _failMessage('Facebook Sign-In was cancelled or failed.', e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFacebookLoading = false;
        });
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('Enter your email address first.');
      return;
    }

    setState(() {
      _isResettingPassword = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      _showMessage(
        'Password reset email has been sent.',
        isError: false,
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Unable to send password reset email.';

      switch (e.code) {
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'user-not-found':
          errorMessage = 'No account was found with this email.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many requests. Please try again later.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection.';
          break;
      }

      _showMessage(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isResettingPassword = false;
        });
      }
    }
  }

  void _openRegisterPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RegisterPage(),
      ),
    );
  }

  void _showMessage(
    String message, {
    bool isError = true,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: Duration(
            seconds: (_showDebugErrors && isError) ? 10 : 4,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isLoading ||
        _isGoogleLoading ||
        _isFacebookLoading ||
        _isResettingPassword;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Color(0xFFDCE8F8),
                  child: Icon(
                    Icons.shopping_bag,
                    size: 40,
                    color: Color(0xFF326295),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'BuyNova',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Everything you love, in one place.',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!isBusy) {
                      _handleLogin();
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: isBusy
                          ? null
                          : () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isBusy ? null : _handleForgotPassword,
                    child: _isResettingPassword
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Forgot Password?',
                          ),
                  ),
                ),
                const SizedBox(height: 8),
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
                    onPressed: isBusy ? null : _handleLogin,
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
                            'Login',
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
                  children: const [
                    Expanded(
                      child: Divider(),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      side: const BorderSide(
                        color: Color(0xFF326295),
                      ),
                    ),
                    onPressed: isBusy ? null : _handleGoogleLogin,
                    icon: _isGoogleLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.g_mobiledata,
                            size: 28,
                          ),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1877F2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    onPressed: isBusy ? null : _handleFacebookLogin,
                    icon: _isFacebookLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.facebook,
                            color: Colors.white,
                          ),
                    label: const Text(
                      'Continue with Facebook',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account?",
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                    TextButton(
                      onPressed: isBusy ? null : _openRegisterPage,
                      child: const Text(
                        'Create Account',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
