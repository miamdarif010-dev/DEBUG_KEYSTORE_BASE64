import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_page.dart';

/// home_page.dart remembers which user already passed the email code, so the
/// check is not repeated every time the home page opens.
String? emailCodeOkUid;

/// Used by home_page.dart: true when this user must still enter the code.
Future<bool> needsEmailCode(User user) => EmailCodeGate.needsCode(user);

/// Same rule as the server (functions/orders.js -> EMAIL_CODE_AFTER) and the
/// website: email + password accounts created on/after this day must enter
/// the 6 digit email code. Google accounts and older accounts are not asked.
class EmailCodeGate {
  EmailCodeGate._();

  static final DateTime codeAfter = DateTime.utc(2026, 10, 27);

  static Future<bool> needsCode(User user) async {
    final usesPassword =
        user.providerData.any((p) => p.providerId == 'password');

    if (!usesPassword) return false;

    final created = user.metadata.creationTime;

    if (created == null || created.toUtc().isBefore(codeAfter)) return false;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      return snap.data()?['emailCodeVerified'] != true;
    } catch (_) {
      // Offline: do not block the app here. The server still checks the
      // code before an order is placed.
      return false;
    }
  }
}

class VerifyCodePage extends StatefulWidget {
  const VerifyCodePage({super.key});

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  final TextEditingController _code = TextEditingController();

  final FirebaseFunctions _fn =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  Timer? _timer;
  int _wait = 0;
  bool _sending = false;
  bool _verifying = false;
  bool _sentOnce = false;

  String get _email => FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _snack(String text, {bool error = true}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red : Colors.green,
        ),
      );
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _wait = seconds);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      setState(() {
        _wait = _wait - 1;
        if (_wait <= 0) {
          _wait = 0;
          t.cancel();
        }
      });
    });
  }

  void _goHome() {
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomePage()),
      (route) => false,
    );
  }

  Future<void> _send() async {
    if (_sending) return;

    setState(() => _sending = true);

    try {
      final result = await _fn.httpsCallable('sendLoginCode').call();
      final data = Map<String, dynamic>.from(result.data as Map);

      if (data['alreadyVerified'] == true) {
        emailCodeOkUid = FirebaseAuth.instance.currentUser?.uid;
        _goHome();
        return;
      }

      _sentOnce = true;
      _startCooldown((data['resendAfterSeconds'] as num?)?.toInt() ?? 60);
      _snack('Code sent to $_email', error: false);
    } on FirebaseFunctionsException catch (e) {
      _snack(e.message ?? 'Could not send the code.');

      // "wait N seconds": show the same wait on the button.
      final match = RegExp(r'(\d+) seconds').firstMatch(e.message ?? '');
      if (match != null) {
        _startCooldown(int.tryParse(match.group(1) ?? '') ?? 30);
      }
    } catch (_) {
      _snack('Could not send the code. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    if (_verifying) return;

    final code = _code.text.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _snack('Please enter the 6 digit code.');
      return;
    }

    setState(() => _verifying = true);

    try {
      await _fn.httpsCallable('verifyLoginCode').call({'code': code});

      emailCodeOkUid = FirebaseAuth.instance.currentUser?.uid;

      _snack('Email verified.', error: false);
      _goHome();
    } on FirebaseFunctionsException catch (e) {
      _snack(e.message ?? 'The code is not correct.');
    } catch (_) {
      _snack('Could not verify. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _useAnotherAccount() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final busy = _verifying;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your email'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Icon(Icons.mark_email_read_outlined, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Enter the 6 digit code',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _sentOnce || _sending
                      ? 'We sent a code to\n$_email'
                      : 'We will send a code to\n$_email',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _code,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 28, letterSpacing: 10),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(),
                    hintText: '------',
                  ),
                  onSubmitted: (_) => _verify(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: busy ? null : _verify,
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Verify'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: (_sending || _wait > 0 || busy) ? null : _send,
                  child: Text(
                    _wait > 0 ? 'Resend code in $_wait s' : 'Resend code',
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : _useAnotherAccount,
                  child: const Text('Use a different account'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check your Spam folder if you cannot find the email. '
                  'The code works for 10 minutes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
