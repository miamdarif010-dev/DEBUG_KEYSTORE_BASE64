import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_page.dart';
import 'login_page.dart';

// ============================================================
// WHO MUST ENTER THE EMAIL CODE
//
// Only brand-new accounts made with email + password.
// Google sign-in is already verified by Google, and accounts
// created before this date are not asked.
//
// Change the date to the day you publish this update.
// ============================================================
final DateTime kEmailCodeRequiredAfter = DateTime.utc(2026, 10, 27);

/// uid of the user who already passed the check in this app session.
String? emailCodeOkUid;

/// true  -> show the code page before the user can use the app.
Future<bool> needsEmailCode(User user) async {
  final usesPassword = user.providerData.any(
    (info) => info.providerId == 'password',
  );

  if (!usesPassword) {
    return false;
  }

  final created = user.metadata.creationTime;

  if (created == null || created.toUtc().isBefore(kEmailCodeRequiredAfter)) {
    return false;
  }

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return snapshot.data()?['emailCodeVerified'] != true;
  } catch (_) {
    // If the check itself fails (offline), do not lock the person out.
    return false;
  }
}

class VerifyCodePage extends StatefulWidget {
  const VerifyCodePage({super.key});

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  final _codeController = TextEditingController();

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  Timer? _timer;

  int _secondsLeft = 0;
  bool _isSending = false;
  bool _isVerifying = false;
  String _info = '';
  String _error = '';

  String get _email => FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _sendCode();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  String _messageOf(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.message ?? 'Something went wrong. Please try again.';
    }

    return 'Something went wrong. Please try again.';
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();

    setState(() {
      _secondsLeft = seconds;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
        });
        return;
      }

      setState(() {
        _secondsLeft--;
      });
    });
  }

  void _goHome() {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      emailCodeOkUid = user.uid;
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
      (route) => false,
    );
  }

  Future<void> _sendCode() async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
      _error = '';
      _info = '';
    });

    try {
      final result = await _functions.httpsCallable('sendLoginCode').call();

      final data = Map<String, dynamic>.from(result.data as Map);

      if (data['alreadyVerified'] == true) {
        _goHome();
        return;
      }

      if (!mounted) return;

      setState(() {
        _info = 'A 6 digit code was sent to $_email';
      });

      _startCountdown((data['resendAfterSeconds'] as num?)?.toInt() ?? 60);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = _messageOf(e);
      });

      _startCountdown(30);
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();

    if (code.length != 6) {
      setState(() {
        _error = 'Please enter the 6 digit code.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = '';
    });

    try {
      await _functions.httpsCallable('verifyLoginCode').call({'code': code});

      _goHome();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = _messageOf(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _useAnotherAccount() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isSending || _isVerifying;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFFDCE8F8),
                    child: Icon(
                      Icons.mark_email_read_outlined,
                      size: 40,
                      color: Color(0xFF326295),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Verify your email',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _info.isNotEmpty
                        ? _info
                        : 'We are sending a 6 digit code to $_email',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize: 28,
                      letterSpacing: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    onSubmitted: (_) {
                      if (!isBusy) _verify();
                    },
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: '------',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
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
                      onPressed: isBusy ? null : _verify,
                      child: _isVerifying
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Verify',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed:
                        (isBusy || _secondsLeft > 0) ? null : _sendCode,
                    child: Text(
                      _secondsLeft > 0
                          ? 'Send a new code in ${_secondsLeft}s'
                          : 'Send a new code',
                    ),
                  ),
                  TextButton(
                    onPressed: isBusy ? null : _useAnotherAccount,
                    child: const Text('Use a different account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
