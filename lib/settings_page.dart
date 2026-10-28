import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'login_page.dart';
import 'app_settings.dart';
import 'app_strings.dart';

/// TODO: put your real support email here.
const String kSupportEmail = 'support@buynova.com';
const String kAppVersion = '1.0.0';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  User? get _user => FirebaseAuth.instance.currentUser;

  // ---------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message.tr)));
  }

  String _authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong password. Please try again.';
      case 'weak-password':
        return 'Password is too weak (minimum 6 characters).';
      case 'requires-recent-login':
        return 'Please login again and retry.';
      case 'email-already-in-use':
        return 'This email is already used by another account.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'invalid-phone-number':
        return 'Invalid phone number. Use format +8210XXXXXXXX';
      case 'invalid-verification-code':
        return 'Wrong verification code.';
      case 'credential-already-in-use':
      case 'provider-already-linked':
        return 'This phone number is already used.';
      default:
        return e.message ?? 'Something went wrong.';
    }
  }

  bool get _hasPasswordProvider =>
      _user?.providerData.any((p) => p.providerId == 'password') ?? false;

  bool get _hasGoogleProvider =>
      _user?.providerData.any((p) => p.providerId == 'google.com') ?? false;

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title.tr),
        content: Text(message.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmText.tr),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<String?> _askText({
    required String title,
    required String label,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
    String confirmText = 'OK',
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title.tr),
        content: TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          autofocus: true,
          decoration: InputDecoration(
            labelText: label.tr,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'.tr),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(confirmText.tr),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  /// Firebase needs a recent login for sensitive actions.
  Future<bool> _reauthenticate() async {
    final user = _user;
    if (user == null) return false;

    try {
      if (_hasPasswordProvider && user.email != null) {
        final password = await _askText(
          title: 'Confirm your identity',
          label: 'Current password',
          obscure: true,
          confirmText: 'Continue',
        );
        if (password == null || password.isEmpty) return false;

        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(
            email: user.email!,
            password: password,
          ),
        );
        return true;
      }

      if (_hasGoogleProvider) {
        await user.reauthenticateWithProvider(GoogleAuthProvider());
        return true;
      }

      _showMessage('Please logout and login again, then retry.');
      return false;
    } on FirebaseAuthException catch (e) {
      _showMessage(_authError(e));
      return false;
    }
  }

  Future<void> _refreshUser() async {
    try {
      await _user?.reload();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------
  // LOGOUT / DELETE
  // ---------------------------------------------------------------

  Future<void> _logout() async {
    final ok = await _confirm(
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'Logout',
    );
    if (!ok) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _deleteAccount() async {
    final ok = await _confirm(
      title: 'Delete Account',
      message: '${'Are you sure you want to delete your account?'.tr}\n\n'
          '${'This action cannot be undone.'.tr}',
      confirmText: 'Delete',
    );
    if (!ok) return;

    final reauthed = await _reauthenticate();
    if (!reauthed) return;

    _showMessage('Deleting account...');

    // The server deletes your data AND the login account.
    try {
      await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('deleteMyAccount')
          .call();
    } on FirebaseFunctionsException catch (e) {
      _showMessage(e.message ?? 'Could not delete the account.');
      return;
    } catch (_) {
      _showMessage('Could not delete the account. Check your internet.');
      return;
    }

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // ---------------------------------------------------------------
  // ACCOUNT & SECURITY
  // ---------------------------------------------------------------

  Future<void> _changePassword() async {
    final user = _user;
    if (user == null) return;

    if (!_hasPasswordProvider) {
      _showMessage(
        'You signed in with Google, so there is no app password to change.',
      );
      return;
    }

    final current = TextEditingController();
    final newPass = TextEditingController();
    final confirm = TextEditingController();
    String? error;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text('Change Password'.tr),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: current,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Current password'.tr,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPass,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'New password'.tr,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirm,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirm new password'.tr,
                        border: const OutlineInputBorder(),
                        errorText: error,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext, 'reset'),
                        child: Text('Forgot? Send reset email'.tr),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Cancel'.tr),
                ),
                FilledButton(
                  onPressed: () {
                    if (current.text.isEmpty) {
                      setLocal(() => error = 'Enter your current password');
                    } else if (newPass.text.length < 6) {
                      setLocal(() => error = 'Minimum 6 characters');
                    } else if (newPass.text != confirm.text) {
                      setLocal(() => error = 'Passwords do not match');
                    } else {
                      Navigator.pop(dialogContext, 'save');
                    }
                  },
                  child: Text('Update'.tr),
                ),
              ],
            );
          },
        );
      },
    );

    final currentText = current.text;
    final newText = newPass.text;
    current.dispose();
    newPass.dispose();
    confirm.dispose();

    if (result == 'reset') {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: user.email!,
        );
        _showMessage('Password reset email sent to ${user.email}');
      } on FirebaseAuthException catch (e) {
        _showMessage(_authError(e));
      }
      return;
    }

    if (result != 'save') return;

    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: currentText,
        ),
      );
      await user.updatePassword(newText);
      _showMessage('Password updated successfully.');
    } on FirebaseAuthException catch (e) {
      _showMessage(_authError(e));
    }
  }

  Future<void> _changeEmail() async {
    final user = _user;
    if (user == null) return;

    final newEmail = await _askText(
      title: 'Change Email',
      label: 'New email address',
      keyboardType: TextInputType.emailAddress,
      confirmText: 'Continue',
    );
    if (newEmail == null || newEmail.isEmpty) return;

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(newEmail)) {
      _showMessage('Invalid email address.');
      return;
    }

    final reauthed = await _reauthenticate();
    if (!reauthed) return;

    try {
      await user.verifyBeforeUpdateEmail(newEmail);
      _showMessage(
        'Verification link sent to $newEmail. '
        'Your email changes after you open the link.',
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(_authError(e));
    }
  }

  Future<void> _attachPhone(User user, PhoneAuthCredential credential) async {
    final hasPhone = user.providerData.any((p) => p.providerId == 'phone');
    if (hasPhone) {
      await user.updatePhoneNumber(credential);
    } else {
      await user.linkWithCredential(credential);
    }
  }

  Future<void> _changePhone() async {
    final user = _user;
    if (user == null) return;

    final phone = await _askText(
      title: 'Phone Number',
      label: 'Phone with country code',
      hint: '+8210XXXXXXXX',
      keyboardType: TextInputType.phone,
      confirmText: 'Send code',
    );
    if (phone == null || phone.isEmpty) return;

    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      _showMessage('Use international format, e.g. +8210XXXXXXXX');
      return;
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (credential) async {
        try {
          await _attachPhone(user, credential);
          await _refreshUser();
          _showMessage('Phone number saved.');
        } on FirebaseAuthException catch (e) {
          _showMessage(_authError(e));
        }
      },
      verificationFailed: (e) => _showMessage(_authError(e)),
      codeSent: (verificationId, resendToken) async {
        if (!mounted) return;
        final code = await _askText(
          title: 'Enter verification code',
          label: '6-digit code',
          keyboardType: TextInputType.number,
          confirmText: 'Verify',
        );
        if (code == null || code.length < 6) return;

        try {
          final credential = PhoneAuthProvider.credential(
            verificationId: verificationId,
            smsCode: code,
          );
          await _attachPhone(user, credential);
          await _refreshUser();
          _showMessage('Phone number saved.');
        } on FirebaseAuthException catch (e) {
          _showMessage(_authError(e));
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Unknown';
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }

  void _showLoginSecurity() {
    final user = _user;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final providers = user.providerData
            .map((p) {
              switch (p.providerId) {
                case 'password':
                  return 'Email & Password';
                case 'google.com':
                  return 'Google';
                case 'phone':
                  return 'Phone';
                default:
                  return p.providerId;
              }
            })
            .join(', ');

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Login & Security',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _InfoRow('Sign-in method', providers.isEmpty ? '-' : providers),
                _InfoRow('Email', user.email ?? 'Not available'),
                _InfoRow(
                  'Email verified',
                  user.emailVerified ? 'Yes' : 'No',
                ),
                _InfoRow('Account created',
                    _formatDate(user.metadata.creationTime)),
                _InfoRow('Last sign in',
                    _formatDate(user.metadata.lastSignInTime)),
                const SizedBox(height: 12),
                if (!user.emailVerified && user.email != null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.mark_email_read_outlined),
                      label: Text('Send verification email'.tr),
                      onPressed: () async {
                        try {
                          await user.sendEmailVerification();
                          _showMessage('Verification email sent.');
                        } on FirebaseAuthException catch (e) {
                          _showMessage(_authError(e));
                        }
                      },
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: Text('Refresh status'.tr),
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await _refreshUser();
                      _showMessage('Status refreshed.');
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------
  // DIALOGS: language, currency, video quality
  // ---------------------------------------------------------------

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return ValueListenableBuilder<String>(
          valueListenable: AppSettings.language,
          builder: (context, language, child) {
            return AlertDialog(
              title: Text('Language'.tr),
              content: RadioGroup<String>(
                groupValue: language,
                onChanged: (value) {
                  if (value == null) return;
                  AppSettings.setLanguage(value);
                  Navigator.pop(dialogContext);
                },
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String>(
                      value: 'English',
                      title: Text('English'),
                    ),
                    RadioListTile<String>(
                      value: 'বাংলা',
                      title: Text('বাংলা'),
                    ),
                    RadioListTile<String>(
                      value: '한국어',
                      title: Text('한국어'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCurrencyDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return ValueListenableBuilder<String>(
          valueListenable: AppSettings.currency,
          builder: (context, currency, child) {
            return AlertDialog(
              title: Text('Currency'.tr),
              content: RadioGroup<String>(
                groupValue: currency,
                onChanged: (value) {
                  if (value == null) return;
                  AppSettings.setCurrency(value);
                  Navigator.pop(dialogContext);
                },
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String>(
                      value: 'KRW',
                      title: Text('₩ Korean Won'),
                    ),
                    RadioListTile<String>(
                      value: 'BDT',
                      title: Text('৳ Bangladeshi Taka'),
                    ),
                    RadioListTile<String>(
                      value: 'USD',
                      title: Text('\$ US Dollar'),
                    ),
                    RadioListTile<String>(
                      value: 'INR',
                      title: Text('₹ Indian Rupee'),
                    ),
                    RadioListTile<String>(
                      value: 'EUR',
                      title: Text('€ Euro'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showVideoQualityDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return ValueListenableBuilder<String>(
          valueListenable: AppSettings.videoQuality,
          builder: (context, quality, child) {
            return AlertDialog(
              title: Text('Video Quality'.tr),
              content: RadioGroup<String>(
                groupValue: quality,
                onChanged: (value) {
                  if (value == null) return;
                  AppSettings.setVideoQuality(value);
                  Navigator.pop(dialogContext);
                },
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String>(value: 'Auto', title: Text('Auto')),
                    RadioListTile<String>(value: 'Low', title: Text('Low')),
                    RadioListTile<String>(
                        value: 'Medium', title: Text('Medium')),
                    RadioListTile<String>(value: 'High', title: Text('High')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _currencyName(String currency) {
    switch (currency) {
      case 'BDT':
        return '৳ Bangladeshi Taka';
      case 'USD':
        return '\$ US Dollar';
      case 'INR':
        return '₹ Indian Rupee';
      case 'EUR':
        return '€ Euro';
      case 'KRW':
      default:
        return '₩ Korean Won';
    }
  }

  // ---------------------------------------------------------------
  // PRIVACY / HELP
  // ---------------------------------------------------------------

  void _showMediaPermissionsInfo() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Media Permissions'.tr),
        content: const Text(
          'Photo, video and camera access is controlled by your phone.\n\n'
          'Android: Settings → Apps → BuyNova → Permissions\n'
          'iPhone: Settings → BuyNova → Photos / Camera',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('OK'.tr),
          ),
        ],
      ),
    );
  }

  void _showContactSupport() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Contact Support'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email us at:'.tr),
            const SizedBox(height: 8),
            const SelectableText(
              kSupportEmail,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Close'.tr),
          ),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: kSupportEmail),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              _showMessage('Email address copied.');
            },
            child: Text('Copy email'.tr),
          ),
        ],
      ),
    );
  }

  Future<void> _reportProblem() async {
    final controller = TextEditingController();

    final send = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Report a Problem'.tr),
        content: TextField(
          controller: controller,
          maxLines: 5,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Describe the problem...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Copy report'.tr),
          ),
        ],
      ),
    );

    final text = controller.text.trim();
    controller.dispose();

    if (send != true) return;
    if (text.isEmpty) {
      _showMessage('Please describe the problem first.');
      return;
    }

    final report = 'BuyNova problem report\n'
        'App version: $kAppVersion\n'
        'User: ${_user?.uid ?? 'guest'}\n\n'
        '$text';

    await Clipboard.setData(ClipboardData(text: report));
    _showMessage('Report copied. Send it to $kSupportEmail');
  }

  void _openPage(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _resetAllSettings() async {
    final ok = await _confirm(
      title: 'Reset all settings',
      message: 'All settings will go back to default values.',
      confirmText: 'Reset',
    );
    if (!ok) return;

    await AppSettings.resetAll();
    _showMessage('All settings reset.');
  }

  // ---------------------------------------------------------------
  // REUSABLE TILES
  // ---------------------------------------------------------------

  Widget _switchTile({
    required ValueNotifier<bool> notifier,
    required IconData icon,
    required String title,
    required String subtitle,
    required Future<void> Function(bool) onChanged,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, value, child) {
        return SwitchListTile(
          secondary: Icon(icon),
          title: Text(title.tr),
          subtitle: Text(subtitle.tr),
          value: value,
          onChanged: (newValue) {
            AppSettings.haptic();
            onChanged(newValue);
          },
        );
      },
    );
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title.tr),
      subtitle: subtitle == null ? null : Text(subtitle.tr),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        AppSettings.haptic();
        onTap();
      },
    );
  }

  // ---------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppSettings.language,
      builder: (context, _, __) => _buildPage(context),
    );
  }

  Widget _buildPage(BuildContext context) {
    final user = _user;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'.tr),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          // ================= GENERAL =================
          const _SectionTitle(icon: Icons.tune, title: 'General'),

          _switchTile(
            notifier: AppSettings.notifications,
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Receive BuyNova notifications',
            onChanged: AppSettings.setNotifications,
          ),

          ValueListenableBuilder<String>(
            valueListenable: AppSettings.language,
            builder: (context, language, child) {
              return _navTile(
                icon: Icons.language_outlined,
                title: 'Language',
                subtitle: language,
                onTap: _showLanguageDialog,
              );
            },
          ),

          ValueListenableBuilder<String>(
            valueListenable: AppSettings.currency,
            builder: (context, currency, child) {
              return _navTile(
                icon: Icons.currency_exchange,
                title: 'Currency',
                subtitle: _currencyName(currency),
                onTap: _showCurrencyDialog,
              );
            },
          ),

          // ================= APPEARANCE =================
          const _SectionTitle(
            icon: Icons.palette_outlined,
            title: 'Appearance',
          ),

          ValueListenableBuilder<ThemeMode>(
            valueListenable: AppSettings.themeMode,
            builder: (context, themeMode, child) {
              final isDark = themeMode == ThemeMode.dark;

              return SwitchListTile(
                secondary: Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode_outlined,
                ),
                title: Text('Dark Mode'.tr),
                subtitle: Text(
                  (isDark ? 'Dark theme is enabled' : 'Use light theme').tr,
                ),
                value: isDark,
                onChanged: (value) {
                  AppSettings.haptic();
                  AppSettings.setDarkMode(value);
                },
              );
            },
          ),

          ValueListenableBuilder<double>(
            valueListenable: AppSettings.textScale,
            builder: (context, scale, child) {
              return ListTile(
                leading: const Icon(Icons.text_fields),
                title: Text('Text Size'.tr),
                subtitle: Slider(
                  value: scale,
                  min: 0.8,
                  max: 1.4,
                  divisions: 6,
                  label: '${(scale * 100).round()}%',
                  onChanged: (v) => AppSettings.textScale.value = v,
                  onChangeEnd: (v) => AppSettings.setTextScale(v),
                ),
                trailing: Text('${(scale * 100).round()}%'),
              );
            },
          ),

          _switchTile(
            notifier: AppSettings.reduceMotion,
            icon: Icons.animation_outlined,
            title: 'Reduce Motion',
            subtitle: 'Reduce animations in the app',
            onChanged: AppSettings.setReduceMotion,
          ),

          _switchTile(
            notifier: AppSettings.vibration,
            icon: Icons.vibration_outlined,
            title: 'Vibration',
            subtitle: 'Use vibration for interactions',
            onChanged: AppSettings.setVibration,
          ),

          // ================= VIDEOS =================
          const _SectionTitle(
            icon: Icons.video_library_outlined,
            title: 'Videos',
          ),

          _switchTile(
            notifier: AppSettings.autoPlayVideos,
            icon: Icons.play_circle_outline,
            title: 'Auto Play Videos',
            subtitle: 'Automatically play videos',
            onChanged: AppSettings.setAutoPlayVideos,
          ),

          _switchTile(
            notifier: AppSettings.videoSound,
            icon: Icons.volume_up_outlined,
            title: 'Video Sound',
            subtitle: 'Play sound automatically',
            onChanged: AppSettings.setVideoSound,
          ),

          ValueListenableBuilder<String>(
            valueListenable: AppSettings.videoQuality,
            builder: (context, quality, child) {
              return _navTile(
                icon: Icons.high_quality_outlined,
                title: 'Video Quality',
                subtitle: quality,
                onTap: _showVideoQualityDialog,
              );
            },
          ),

          _switchTile(
            notifier: AppSettings.dataSaver,
            icon: Icons.data_saver_on_outlined,
            title: 'Data Saver',
            subtitle: 'Reduce mobile data usage',
            onChanged: AppSettings.setDataSaver,
          ),

          // ================= ACCOUNT & SECURITY =================
          const _SectionTitle(
            icon: Icons.security_outlined,
            title: 'Account & Security',
          ),

          if (user != null) ...[
            _navTile(
              icon: Icons.lock_outline,
              title: 'Change Password',
              subtitle: _hasPasswordProvider
                  ? 'Update your password'
                  : 'Not available for Google sign-in',
              onTap: _changePassword,
            ),
            _navTile(
              icon: Icons.email_outlined,
              title: 'Email Address',
              subtitle: user.email ?? 'Not available',
              onTap: _changeEmail,
            ),
            _navTile(
              icon: Icons.phone_outlined,
              title: 'Phone Number',
              subtitle: (user.phoneNumber != null &&
                      user.phoneNumber!.isNotEmpty)
                  ? user.phoneNumber!
                  : 'Add phone number',
              onTap: _changePhone,
            ),
            _navTile(
              icon: Icons.login_outlined,
              title: 'Login & Security',
              subtitle: user.emailVerified
                  ? 'Email verified'
                  : 'Email not verified',
              onTap: _showLoginSecurity,
            ),
            _navTile(
              icon: Icons.delete_outline,
              title: 'Delete Account',
              subtitle: 'Permanently delete your account',
              onTap: _deleteAccount,
            ),
          ] else
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text('You are not logged in'.tr),
              subtitle: Text('Login to manage your account'.tr),
            ),

          // ================= PRIVACY =================
          const _SectionTitle(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy',
          ),

          ValueListenableBuilder<List<String>>(
            valueListenable: AppSettings.blockedUsers,
            builder: (context, blocked, child) {
              return _navTile(
                icon: Icons.block_outlined,
                title: 'Blocked Users',
                subtitle: blocked.isEmpty
                    ? 'No blocked users'
                    : '${blocked.length} ${'blocked'.tr}',
                onTap: () => _openPage(const _BlockedUsersPage()),
              );
            },
          ),

          _navTile(
            icon: Icons.perm_media_outlined,
            title: 'Media Permissions',
            subtitle: 'Manage photo and video permissions',
            onTap: _showMediaPermissionsInfo,
          ),

          // ================= HELP & SUPPORT =================
          const _SectionTitle(
            icon: Icons.help_outline,
            title: 'Help & Support',
          ),

          _navTile(
            icon: Icons.help_center_outlined,
            title: 'Help Center',
            onTap: () => _openPage(const _TextPage(
              title: 'Help Center',
              sections: _helpSections,
            )),
          ),
          _navTile(
            icon: Icons.support_agent_outlined,
            title: 'Contact Support',
            onTap: _showContactSupport,
          ),
          _navTile(
            icon: Icons.report_problem_outlined,
            title: 'Report a Problem',
            onTap: _reportProblem,
          ),
          _navTile(
            icon: Icons.question_answer_outlined,
            title: 'FAQ',
            onTap: () => _openPage(const _FaqPage()),
          ),

          // ================= STORAGE =================
          const _SectionTitle(
            icon: Icons.cleaning_services_outlined,
            title: 'Storage',
          ),

          _navTile(
            icon: Icons.cleaning_services_outlined,
            title: 'Clear Temporary Settings',
            subtitle: 'Reset temporary video settings',
            onTap: () async {
              await AppSettings.clearCache();
              _showMessage('Temporary settings cleared.');
            },
          ),
          _navTile(
            icon: Icons.restart_alt,
            title: 'Reset All Settings',
            subtitle: 'Restore default settings',
            onTap: _resetAllSettings,
          ),

          // ================= ABOUT =================
          const _SectionTitle(icon: Icons.info_outline, title: 'About'),

          _navTile(
            icon: Icons.info_outline,
            title: 'About BuyNova',
            subtitle: 'BuyNova shopping platform',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'BuyNova',
                applicationVersion: kAppVersion,
                applicationLegalese: '© BuyNova',
              );
            },
          ),
          _navTile(
            icon: Icons.description_outlined,
            title: 'Terms & Conditions',
            onTap: () => _openPage(const _TextPage(
              title: 'Terms & Conditions',
              sections: _termsSections,
            )),
          ),
          _navTile(
            icon: Icons.policy_outlined,
            title: 'Privacy Policy',
            onTap: () => _openPage(const _TextPage(
              title: 'Privacy Policy',
              sections: _privacySections,
            )),
          ),

          // ================= LOGOUT =================
          if (user != null) ...[
            const Divider(height: 30),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text('Logout'.tr),
              onTap: _logout,
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================
// SMALL WIDGETS
// =============================================================

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 21),
          const SizedBox(width: 10),
          Text(
            title.tr,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

// =============================================================
// BLOCKED USERS PAGE (stored locally)
// =============================================================

class _BlockedUsersPage extends StatelessWidget {
  const _BlockedUsersPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Blocked Users'.tr)),
      body: ValueListenableBuilder<List<String>>(
        valueListenable: AppSettings.blockedUsers,
        builder: (context, blocked, child) {
          if (blocked.isEmpty) {
            return Center(child: Text('You have not blocked anyone.'.tr));
          }
          return ListView.separated(
            itemCount: blocked.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final id = blocked[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_off)),
                title: Text(id),
                trailing: TextButton(
                  onPressed: () => AppSettings.unblockUser(id),
                  child: Text('Unblock'.tr),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// =============================================================
// FAQ PAGE
// =============================================================

class _FaqPage extends StatelessWidget {
  const _FaqPage();

  static const _items = <(String, String)>[
    (
      'How do I place an order?',
      'Open a product, choose your options and tap Buy / Add to cart, '
          'then follow the checkout steps.'
    ),
    (
      'How can I change my password?',
      'Settings → Account & Security → Change Password.'
    ),
    (
      'How do I change the app currency?',
      'Settings → General → Currency and pick your currency.'
    ),
    (
      'Videos use too much data. What can I do?',
      'Turn on Data Saver and set Video Quality to Low in Settings → Videos.'
    ),
    (
      'How do I delete my account?',
      'Settings → Account & Security → Delete Account. '
          'This cannot be undone.'
    ),
    (
      'How do I contact support?',
      'Settings → Help & Support → Contact Support.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('FAQ'.tr)),
      body: ListView(
        children: [
          for (final item in _items)
            ExpansionTile(
              title: Text(item.$1),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(item.$2)],
            ),
        ],
      ),
    );
  }
}

// =============================================================
// TEXT PAGES (Help, Terms, Privacy)
// =============================================================

class _TextPage extends StatelessWidget {
  final String title;
  final List<(String, String)> sections;

  const _TextPage({required this.title, required this.sections});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title.tr)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final s in sections) ...[
            Text(
              s.$1,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(s.$2),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

const List<(String, String)> _helpSections = [
  (
    'Getting started',
    'Create an account or login, browse products and videos, and place '
        'orders from the product page.'
  ),
  (
    'Account',
    'You can change your password, email and phone number from '
        'Settings → Account & Security.'
  ),
  (
    'Still need help?',
    'Use Settings → Help & Support → Contact Support or Report a Problem.'
  ),
];

// NOTE: replace these with your real legal text before publishing.
const List<(String, String)> _termsSections = [
  (
    '1. Using BuyNova',
    'By using BuyNova you agree to use the app lawfully and not to misuse '
        'the platform, other users or sellers.'
  ),
  (
    '2. Accounts',
    'You are responsible for keeping your login details safe and for all '
        'activity under your account.'
  ),
  (
    '3. Orders & payments',
    'Prices, availability and delivery times are shown at checkout and may '
        'change before an order is confirmed.'
  ),
  (
    '4. Changes',
    'We may update these terms. Continued use of the app means you accept '
        'the updated terms.'
  ),
];

const List<(String, String)> _privacySections = [
  (
    'Information we collect',
    'Account details such as email or phone number, and the activity needed '
        'to run the app (orders, preferences).'
  ),
  (
    'How we use it',
    'To provide and improve BuyNova, process orders, and keep your account '
        'secure.'
  ),
  (
    'Your control',
    'You can change your account details or delete your account at any time '
        'from Settings.'
  ),
  (
    'Contact',
    'Questions about privacy? Contact $kSupportEmail.'
  ),
];
