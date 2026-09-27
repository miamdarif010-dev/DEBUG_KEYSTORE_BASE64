import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'buyer_page.dart';
import 'edit_profile_page.dart';
import 'settings_page.dart';
import 'admin_panel_page.dart';
import 'entrepreneur_page.dart';
import 'watch_earn_page.dart';
import 'seller_page.dart';

class UserProfilePage extends StatefulWidget {
  final String? userId;
  final String? initialName;
  final String? initialProfileImageUrl;

  const UserProfilePage({
    super.key,
    this.userId,
    this.initialName,
    this.initialProfileImageUrl,
  });

  @override
  State<UserProfilePage> createState() =>
      _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  bool _isLoading = true;

  String _name = '';
  String _phone = '';
  String _profileImageUrl = '';
  String _email = '';

  String _sellerStatus = '';
  String _entrepreneurStatus = '';
  String _role = '';

  int _totalLikes = 0;
  int _totalViews = 0;
  int _totalShares = 0;
  int _totalComments = 0;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _userSub;

  User? get currentUser =>
      FirebaseAuth.instance.currentUser;

  String? get _targetUserId {
    final id = widget.userId?.trim();

    if (id != null && id.isNotEmpty) {
      return id;
    }

    return currentUser?.uid;
  }

  bool get _isOwnProfile {
    final target = _targetUserId;
    final current = currentUser?.uid;

    if (target == null || current == null) {
      return true;
    }

    return target == current;
  }

  bool get _isAdmin {
    if (!_isOwnProfile) {
      return false;
    }

    return _role.toLowerCase() == 'admin' ||
        currentUser?.email?.toLowerCase() ==
            'miamdarif010@gmail.com';
  }

  bool get _isSellerApproved =>
      _sellerStatus.toLowerCase() == 'approved';

  bool get _isEntrepreneurApproved =>
      _entrepreneurStatus.toLowerCase() == 'approved';

  @override
  void initState() {
    super.initState();

    if (_isOwnProfile) {
      _listenUserData();
    } else {
      _loadPublicProfile();
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  void _listenUserData() {
    final uid = _targetUserId;

    if (uid == null || uid.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      return;
    }

    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
      (doc) {
        _applyUserData(doc.data());
      },
      onError: (error) {
        debugPrint(
          'User profile stream error: $error',
        );

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _loadPublicProfile() async {
    final uid = _targetUserId;

    if (mounted) {
      setState(() {
        _name =
            widget.initialName?.trim().isNotEmpty == true
                ? widget.initialName!.trim()
                : 'BuyNova User';

        _profileImageUrl =
            widget.initialProfileImageUrl?.trim() ?? '';

        _isLoading = false;
      });
    }

    if (uid == null || uid.isEmpty) {
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        _applyUserData(
          doc.data(),
          keepLoadingFalse: true,
        );
      }
    } catch (e) {
      debugPrint(
        'Public profile read skipped: $e',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    final uid = _targetUserId;

    if (uid == null || uid.isEmpty) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      _applyUserData(doc.data());
    } catch (e) {
      debugPrint(
        'Load user profile error: $e',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  int _readInt(Map<String, dynamic> map, String key) {
    final value = map[key];

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  void _applyUserData(
    Map<String, dynamic>? data, {
    bool keepLoadingFalse = false,
  }) {
    final map = data ?? <String, dynamic>{};

    final firestoreName =
        map['name']?.toString().trim() ?? '';

    final firestorePhone =
        map['phone']?.toString().trim() ?? '';

    final firestoreEmail =
        map['email']?.toString().trim() ?? '';

    final firestoreImage =
        map['profileImageUrl']?.toString().trim() ?? '';

    if (!mounted) return;

    setState(() {
      if (firestoreName.isNotEmpty) {
        _name = firestoreName;
      } else if (_name.isEmpty) {
        _name = widget.initialName?.trim() ?? '';
      }

      if (firestorePhone.isNotEmpty) {
        _phone = firestorePhone;
      }

      if (firestoreEmail.isNotEmpty) {
        _email = firestoreEmail;
      } else if (_isOwnProfile) {
        _email = currentUser?.email?.trim() ?? '';
      }

      if (firestoreImage.isNotEmpty) {
        _profileImageUrl = firestoreImage;
      } else if (_profileImageUrl.isEmpty) {
        _profileImageUrl =
            widget.initialProfileImageUrl?.trim() ?? '';
      }

      _sellerStatus =
          map['sellerStatus']?.toString() ?? '';

      _entrepreneurStatus =
          map['entrepreneurStatus']?.toString() ?? '';

      _role = map['role']?.toString() ?? '';

      _totalLikes = _readInt(map, 'totalLikes');
      _totalViews = _readInt(map, 'totalViews');
      _totalShares = _readInt(map, 'totalShares');
      _totalComments = _readInt(map, 'totalComments');

      _isLoading = false;
    });
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }

    return value.toString();
  }

  void _push(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );
  }

  void _openEditProfile() {
    _push(const EditProfilePage());
  }

  void _openAdmin() {
    _push(const AdminPanelPage());
  }

  void _openBuyer() {
    _push(const BuyerPage());
  }

  void _openReseller() {
    _push(const EntrepreneurPage());
  }

  void _openSeller() {
    _push(const SellerPage());
  }

  void _openEarn() {
    _push(const WatchEarnPage());
  }

  void _openSettings() {
    _push(const SettingsPage());
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  ImageProvider<Object>? _profileImage() {
    if (_profileImageUrl.trim().isEmpty) {
      return null;
    }

    return NetworkImage(
      _profileImageUrl.trim(),
    );
  }

  Widget _statItem({
    required IconData icon,
    required int value,
    required String label,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.redAccent,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            _formatCount(value),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _statItem(
            icon: Icons.visibility_outlined,
            value: _totalViews,
            label: 'Views',
          ),
          _statItem(
            icon: Icons.favorite_border,
            value: _totalLikes,
            label: 'Likes',
          ),
          _statItem(
            icon: Icons.comment_outlined,
            value: _totalComments,
            label: 'Comments',
          ),
          _statItem(
            icon: Icons.share_outlined,
            value: _totalShares,
            label: 'Shares',
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final color = iconColor ?? Colors.redAccent;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.10),
        child: Icon(
          icon,
          color: color,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle),
      trailing: const Icon(
        Icons.chevron_right,
      ),
      onTap: onTap,
    );
  }

  Future<void> _showLogoutDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Logout',
          ),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Logout',
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _logout();
    }
  }

  Widget _buildPublicProfile() {
    final image = _profileImage();

    return Scaffold(
      backgroundColor: const Color(0xfff6f6f6),
      appBar: AppBar(
        title: const Text(
          'Profile',
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 58,
                          backgroundColor:
                              Colors.grey.shade200,
                          backgroundImage: image,
                          child: image == null
                              ? const Icon(
                                  Icons.person,
                                  size: 55,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _name.isEmpty
                              ? 'BuyNova User'
                              : _name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'BuyNova Member',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 15),
                        if (_isSellerApproved)
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  Colors.green.withValues(alpha: 0.10),
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified,
                                  color: Colors.green,
                                  size: 17,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Seller',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_isEntrepreneurApproved)
                          Padding(
                            padding:
                                const EdgeInsets.only(top: 8),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    Colors.blue.withValues(alpha: 0.10),
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.business_center,
                                    color: Colors.blue,
                                    size: 17,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Entrepreneur',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _statsRow(),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.redAccent,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This is a BuyNova user profile.',
                            style: TextStyle(
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOwnProfile() {
    final user = currentUser;

    return Scaffold(
      backgroundColor: const Color(0xfff6f6f6),
      appBar: AppBar(
        title: const Text(
          'My Profile',
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: SingleChildScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _openEditProfile,
                            child: Stack(
                              alignment:
                                  Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 58,
                                  backgroundColor:
                                      Colors.grey.shade200,
                                  backgroundImage:
                                      _profileImage(),
                                  child:
                                      _profileImage() == null
                                          ? const Icon(
                                              Icons.person,
                                              size: 55,
                                              color:
                                                  Colors.grey,
                                            )
                                          : null,
                                ),
                                Container(
                                  padding:
                                      const EdgeInsets.all(8),
                                  decoration:
                                      const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _name.isEmpty
                                ? 'BuyNova User'
                                : _name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _email.isEmpty
                                ? (user?.email ?? '')
                                : _email,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                          if (_phone.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              _phone,
                              style: const TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _openEditProfile,
                              icon: const Icon(
                                Icons.edit,
                              ),
                              label: const Text(
                                'Edit Profile',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _statsRow(),
                    const SizedBox(height: 14),
                    if (_isAdmin)
                      _sectionCard(
                        title: 'Admin',
                        icon:
                            Icons.admin_panel_settings,
                        children: [
                          _menuItem(
                            icon: Icons.dashboard,
                            title: 'Admin Panel',
                            subtitle:
                                'Manage BuyNova',
                            onTap: _openAdmin,
                          ),
                        ],
                      ),
                    _sectionCard(
                      title: 'Buyer / Customer',
                      icon: Icons.shopping_bag,
                      children: [
                        _menuItem(
                          icon: Icons.shopping_cart,
                          title: 'Buyer',
                          subtitle:
                              'Browse and shop products',
                          onTap: _openBuyer,
                        ),
                      ],
                    ),
                    _sectionCard(
                      title: 'Reseller',
                      icon: Icons.business_center,
                      children: [
                        _menuItem(
                          icon:
                              Icons.business_center,
                          title:
                              'Entrepreneur / Reseller',
                          subtitle:
                              _isEntrepreneurApproved
                                  ? 'Approved'
                                  : 'Manage reseller account',
                          onTap: _openReseller,
                        ),
                      ],
                    ),
                    _sectionCard(
                      title: 'Seller',
                      icon: Icons.storefront,
                      children: [
                        _menuItem(
                          icon: Icons.store,
                          title: 'Seller',
                          subtitle:
                              _isSellerApproved
                                  ? 'Approved seller'
                                  : 'Manage seller account',
                          onTap: _openSeller,
                        ),
                      ],
                    ),
                    _sectionCard(
                      title: 'Earn & Rewards',
                      icon: Icons.monetization_on,
                      children: [
                        _menuItem(
                          icon: Icons.play_circle_fill,
                          title: 'Watch & Earn',
                          subtitle:
                              'Watch videos and earn',
                          onTap: _openEarn,
                        ),
                      ],
                    ),
                    _sectionCard(
                      title: 'Settings',
                      icon: Icons.settings,
                      children: [
                        _menuItem(
                          icon: Icons.settings,
                          title: 'Settings',
                          subtitle:
                              'Manage your account settings',
                          onTap: _openSettings,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _showLogoutDialog,
                        icon: const Icon(
                          Icons.logout,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null && !_isOwnProfile) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
        ),
        body: const Center(
          child: Text(
            'Profile is unavailable.',
          ),
        ),
      );
    }

    if (!_isOwnProfile) {
      return _buildPublicProfile();
    }

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Profile'),
        ),
        body: const Center(
          child: Text(
            'Please log in to view your profile.',
          ),
        ),
      );
    }

    return _buildOwnProfile();
  }
}
