import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_coupon_page.dart';
import 'admin_wallet_page.dart';

const String kAdminEmail = 'miamdarif010@gmail.com';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  bool _checkingAuth = true;
  bool _isAuthorized = false;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;

    final authorized = user != null &&
        (user.email ?? '').toLowerCase() == kAdminEmail.toLowerCase();

    if (!mounted) return;

    setState(() {
      _checkingAuth = false;
      _isAuthorized = authorized;
    });
  }

  // ============================================================
  // SEQUENTIAL CODE GENERATION
  // ============================================================

  Future<String> _generateSequentialSellerCode() async {
    final counterRef = _db.collection('counters').doc('sellerCounter');

    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      final current = (snapshot.data()?['value'] as num?)?.toInt() ?? 0;
      final next = current + 1;

      transaction.set(
        counterRef,
        {'value': next},
        SetOptions(merge: true),
      );

      return 'SELL-${next.toString().padLeft(6, '0')}';
    });
  }

  Future<String> _generateSequentialEntrepreneurCode() async {
    final counterRef =
        _db.collection('counters').doc('entrepreneurCounter');

    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);

      final current = (snapshot.data()?['value'] as num?)?.toInt() ?? 0;
      final next = current + 1;

      transaction.set(
        counterRef,
        {'value': next},
        SetOptions(merge: true),
      );

      return 'ENT-${next.toString().padLeft(6, '0')}';
    });
  }

  // ============================================================
  // OPEN SECTION
  // ============================================================

  void _openSection({
    required String title,
    required Widget page,
    Stream<QuerySnapshot<Map<String, dynamic>>>? notificationStream,
    String notificationLabel = 'Items',
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AdminSectionPage(
          title: title,
          notificationStream: notificationStream,
          notificationLabel: notificationLabel,
          child: page,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_checkingAuth) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 70,
                  color: Colors.red,
                ),
                SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'You do not have permission to access the Admin Panel.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Panel',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _dashboard(),
    );
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _dashboard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('users').snapshots(),
      builder: (context, userSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _db.collection('products').snapshots(),
          builder: (context, productSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db.collection('orders').snapshots(),
              builder: (context, orderSnapshot) {
                final users = userSnapshot.data?.docs ?? [];
                final products = productSnapshot.data?.docs ?? [];
                final orders = orderSnapshot.data?.docs ?? [];

                final sellers = users.where(
                  (doc) =>
                      (doc.data()['sellerStatus'] ?? '') == 'approved',
                ).length;

                final entrepreneurs = users.where(
                  (doc) =>
                      (doc.data()['entrepreneurStatus'] ?? '') ==
                      'approved',
                ).length;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _dashboardHeader(),
                      const SizedBox(height: 18),

                      const Text(
                        'Management',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      _adminMenuBox(
                        icon: Icons.people_alt_outlined,
                        title: 'Users / Buyers',
                        subtitle: '${users.length} users',
                        onTap: () {
                          _openSection(
                            title: 'Users / Buyers',
                            notificationStream:
                                _db.collection('users').snapshots(),
                            notificationLabel: 'Buyers / Users',
                            page: _usersTab(),
                          );
                        },
                      ),

                      _adminMenuBox(
                        icon: Icons.storefront_outlined,
                        title: 'Sellers',
                        subtitle: '$sellers approved sellers',
                        onTap: () {
                          _openSection(
                            title: 'Sellers',
                            notificationStream: _db
                                .collection('users')
                                .where(
                                  'sellerStatus',
                                  isEqualTo: 'approved',
                                )
                                .snapshots(),
                            notificationLabel: 'Sellers',
                            page: _sellersTab(),
                          );
                        },
                      ),

                      _adminMenuBox(
                        icon: Icons.person_add_alt_1_outlined,
                        title: 'Resellers / Entrepreneurs',
                        subtitle:
                            '$entrepreneurs approved entrepreneurs',
                        onTap: () {
                          _openSection(
                            title: 'Resellers / Entrepreneurs',
                            notificationStream: _db
                                .collection('users')
                                .where(
                                  'entrepreneurStatus',
                                  isEqualTo: 'approved',
                                )
                                .snapshots(),
                            notificationLabel: 'Entrepreneurs',
                            page: _resellersTab(),
                          );
                        },
                      ),

                      _adminMenuBox(
                        icon: Icons.inventory_2_outlined,
                        title: 'Products',
                        subtitle: '${products.length} seller products',
                        onTap: () {
                          _openSection(
                            title: 'Products',
                            notificationStream:
                                _db.collection('products').snapshots(),
                            notificationLabel: 'Products',
                            page: _productsTab(),
                          );
                        },
                      ),

                      _adminMenuBox(
                        icon: Icons.pending_actions_outlined,
                        title: 'Seller Requests',
                        subtitle: 'Pending seller applications',
                        onTap: () {
                          _openSection(
                            title: 'Seller Requests',
                            notificationStream: _db
                                .collection('users')
                                .where(
                                  'sellerStatus',
                                  isEqualTo: 'pending',
                                )
                                .snapshots(),
                            notificationLabel:
                                'Pending Seller Requests',
                            page: _sellerRequestsTab(),
                          );
                        },
                      ),

                      _adminMenuBox(
                        icon: Icons.person_add_alt_1_outlined,
                        title: 'Entrepreneur Requests',
                        subtitle:
                            'Pending entrepreneur applications',
                        onTap: () {
                          _openSection(
                            title: 'Entrepreneur Requests',
                            notificationStream: _db
                                .collection('users')
                                .where(
                                  'entrepreneurStatus',
                                  isEqualTo: 'pending',
                                )
                                .snapshots(),
                            notificationLabel:
                                'Pending Entrepreneur Requests',
                            page: _entrepreneurRequestsTab(),
                          );
                        },
                      ),

                      _adminMenuBox(
                        icon: Icons.sync_alt_outlined,
                        title: 'Relationships',
                        subtitle: 'Seller ↔ Reseller products',
                        onTap: () {
                          _openSection(
                            title: 'Relationships',
                            notificationStream: _db
                                .collection('reseller_products')
                                .snapshots(),
                            notificationLabel: 'Relationships',
                            page: _relationshipsTab(),
                          );
                        },
                      ),

                      _adminMenuBox(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Orders',
                        subtitle: '${orders.length} customer orders',
                        onTap: () {
                          _openSection(
                            title: 'Orders',
                            notificationStream:
                                _db.collection('orders').snapshots(),
                            notificationLabel: 'Customer Orders',
                            page: _ordersTab(),
                          );
                        },
                      ),

                      _adminMenuBox(
                        icon: Icons.local_offer_outlined,
                        title: 'Coupons',
                        subtitle: 'Manage BuyNova coupons',
                        onTap: () {
                          _openSection(
                            title: 'Coupons',
                            notificationStream:
                                _db.collection('coupons').snapshots(),
                            notificationLabel: 'Coupons',
                            page: const AdminCouponPage(),
                          );
                        },
                      ),

                      _adminMenuBox(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Wallet',
                        subtitle: 'Manage wallet transactions',
                        onTap: () {
                          _openSection(
                            title: 'Wallet',
                            notificationStream: _db
                                .collectionGroup('walletTransactions')
                                .snapshots(),
                            notificationLabel: 'Wallet Transactions',
                            page: const AdminWalletPage(),
                          );
                        },
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _dashboardHeader() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.12),
              child: Icon(
                Icons.admin_panel_settings_outlined,
                size: 34,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BuyNova Admin',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage users, sellers, products, orders and more.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminMenuBox({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.10),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // USERS
  // ============================================================

  Widget _usersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorView(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = [...(snapshot.data?.docs ?? [])];

        docs.sort((a, b) {
          final aName = (a.data()['name'] ?? '').toString().toLowerCase();
          final bName = (b.data()['name'] ?? '').toString().toLowerCase();
          return aName.compareTo(bName);
        });

        if (docs.isEmpty) {
          return const Center(
            child: Text('No users found.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];

            return _userCard(
              doc.id,
              doc.data(),
            );
          },
        );
      },
    );
  }

  Widget _userCard(
    String uid,
    Map<String, dynamic> data,
  ) {
    final name = (data['name'] ?? 'No Name').toString();
    final email = (data['email'] ?? 'No Email').toString();

    final sellerStatus =
        (data['sellerStatus'] ?? 'none').toString();

    final entrepreneurStatus =
        (data['entrepreneurStatus'] ?? 'none').toString();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: _profileAvatar(data),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(email),
            const SizedBox(height: 6),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: [
                if (sellerStatus == 'approved')
                  _statusChip('Seller', Colors.green),
                if (entrepreneurStatus == 'approved')
                  _statusChip('Reseller', Colors.blue),
                if (sellerStatus == 'pending')
                  _statusChip('Seller Pending', Colors.orange),
                if (entrepreneurStatus == 'pending')
                  _statusChip('Reseller Pending', Colors.orange),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _AdminSectionPage(
                title: 'User Details',
                child: _userDetailsTab(
                  uid,
                  data,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // SELLERS
  // ============================================================

  Widget _sellersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('users')
          .where(
            'sellerStatus',
            isEqualTo: 'approved',
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorView(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = [...(snapshot.data?.docs ?? [])];

        docs.sort((a, b) {
          final aName = (a.data()['name'] ?? '').toString().toLowerCase();
          final bName = (b.data()['name'] ?? '').toString().toLowerCase();
          return aName.compareTo(bName);
        });

        if (docs.isEmpty) {
          return const Center(
            child: Text('No approved sellers found.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            return _roleUserCard(
              docs[index].id,
              docs[index].data(),
              'Seller',
            );
          },
        );
      },
    );
  }

  // ============================================================
  // RESELLERS
  // ============================================================

  Widget _resellersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('users')
          .where(
            'entrepreneurStatus',
            isEqualTo: 'approved',
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorView(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = [...(snapshot.data?.docs ?? [])];

        docs.sort((a, b) {
          final aName = (a.data()['name'] ?? '').toString().toLowerCase();
          final bName = (b.data()['name'] ?? '').toString().toLowerCase();
          return aName.compareTo(bName);
        });

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No approved entrepreneurs found.',
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            return _roleUserCard(
              docs[index].id,
              docs[index].data(),
              'Entrepreneur',
            );
          },
        );
      },
    );
  }

  Widget _roleUserCard(
    String uid,
    Map<String, dynamic> data,
    String role,
  ) {
    final name = (data['name'] ?? 'No Name').toString();
    final email = (data['email'] ?? 'No Email').toString();

    final code = role == 'Seller'
        ? (data['sellerCode'] ?? '').toString()
        : (data['entrepreneurCode'] ?? '').toString();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: _profileAvatar(data),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(email),
            const SizedBox(height: 5),
            Wrap(
              spacing: 6,
              children: [
                _statusChip(
                  role,
                  role == 'Seller' ? Colors.green : Colors.blue,
                ),
                if (code.isNotEmpty)
                  _statusChip(code, Colors.grey),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _AdminSectionPage(
                title: 'User Details',
                child: _userDetailsTab(
                  uid,
                  data,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _profileAvatar(Map<String, dynamic> data) {
    final imageUrl =
        (data['profileImageUrl'] ?? '').toString();

    if (imageUrl.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(imageUrl),
      );
    }

    return const CircleAvatar(
      child: Icon(Icons.person),
    );
  }

  // ============================================================
  // USER DETAILS
  // ============================================================

  Widget _userDetailsTab(
    String uid,
    Map<String, dynamic> userData,
  ) {
    final name = (userData['name'] ?? 'No Name').toString();
    final email = (userData['email'] ?? 'No Email').toString();
    final phone = (userData['phone'] ?? 'Not added').toString();

    final sellerStatus =
        (userData['sellerStatus'] ?? 'none').toString();

    final entrepreneurStatus =
        (userData['entrepreneurStatus'] ?? 'none').toString();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _profileAvatar(userData),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(email),
                const SizedBox(height: 5),
                Text(phone),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        _detailCard(
          title: 'Basic Profile',
          icon: Icons.person_outline,
          children: [
            _summaryRow('UID', uid),
            _summaryRow('Name', name),
            _summaryRow('Email', email),
            _summaryRow('Phone', phone),
          ],
        ),

        _detailCard(
          title: 'Buyer / Customer',
          icon: Icons.shopping_cart_outlined,
          children: [
            _summaryRow('Account', 'Active'),
          ],
        ),

        _detailCard(
          title: 'Seller',
          icon: Icons.storefront_outlined,
          children: [
            _summaryRow('Status', sellerStatus),
            if ((userData['sellerCode'] ?? '')
                .toString()
                .isNotEmpty)
              _summaryRow(
                'Seller Code',
                userData['sellerCode'].toString(),
              ),
          ],
        ),

        _detailCard(
          title: 'Reseller / Entrepreneur',
          icon: Icons.business_center_outlined,
          children: [
            _summaryRow('Status', entrepreneurStatus),
            if ((userData['entrepreneurCode'] ?? '')
                .toString()
                .isNotEmpty)
              _summaryRow(
                'Entrepreneur Code',
                userData['entrepreneurCode'].toString(),
              ),
          ],
        ),

        _walletDetails(uid),

        _detailCard(
          title: 'Products',
          icon: Icons.inventory_2_outlined,
          children: [
            SizedBox(
              height: 250,
              child: _userProducts(
                uid,
                userData,
              ),
            ),
          ],
        ),

        _detailCard(
          title: 'Videos',
          icon: Icons.video_library_outlined,
          children: [
            SizedBox(
              height: 180,
              child: _userVideos(uid),
            ),
          ],
        ),

        _detailCard(
          title: 'Orders',
          icon: Icons.shopping_bag_outlined,
          children: [
            SizedBox(
              height: 300,
              child: _userOrders(uid),
            ),
          ],
        ),

        const SizedBox(height: 14),

        Card(
          elevation: 0,
          child: ListTile(
            leading: const Icon(
              Icons.delete_outline,
              color: Colors.red,
            ),
            title: const Text(
              'Delete User',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'Delete this Firebase user account.',
            ),
            onTap: () => _deleteUser(uid),
          ),
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _detailCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
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
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  // ============================================================
  // WALLET DETAILS
  // ============================================================

  Widget _walletDetails(String uid) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};

        final cash = _toDouble(data['cashBalance']);
        final points = _toInt(data['pointsBalance']);
        final lifetimePoints = _toInt(data['lifetimePoints']);

        return _detailCard(
          title: 'Wallet',
          icon: Icons.account_balance_wallet_outlined,
          children: [
            _summaryRow(
              'Cash Balance',
              '৳${cash.toStringAsFixed(2)}',
            ),
            _summaryRow(
              'Points',
              points.toString(),
            ),
            _summaryRow(
              'Lifetime Points',
              lifetimePoints.toString(),
            ),
            const SizedBox(height: 8),
            const Text(
              'Recent Transactions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 180,
              child: StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: _db
                    .collection('users')
                    .doc(uid)
                    .collection('walletTransactions')
                    .snapshots(),
                builder: (context, txSnapshot) {
                  if (txSnapshot.hasError) {
                    return Text(txSnapshot.error.toString());
                  }

                  if (txSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final docs = [
                    ...(txSnapshot.data?.docs ?? [])
                  ];

                  docs.sort((a, b) {
                    final aDate =
                        _dateFromValue(a.data()['createdAt']);
                    final bDate =
                        _dateFromValue(b.data()['createdAt']);
                    return bDate.compareTo(aDate);
                  });

                  final limitedDocs = docs.take(10).toList();

                  if (limitedDocs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No wallet transactions.',
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: limitedDocs.length,
                    itemBuilder: (context, index) {
                      final tx = limitedDocs[index].data();

                      final amount = _toDouble(tx['amount']);
                      final type =
                          (tx['type'] ?? '').toString();
                      final status =
                          (tx['status'] ?? '').toString();

                      return ListTile(
                        dense: true,
                        leading: Icon(
                          type == 'credit'
                              ? Icons.add_circle_outline
                              : Icons.remove_circle_outline,
                        ),
                        title: Text(
                          '৳${amount.toStringAsFixed(2)}',
                        ),
                        subtitle: Text(
                          '${tx['source'] ?? 'Transaction'} • '
                          '$status',
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // USER PRODUCTS
  // ============================================================

  Widget _userProducts(
    String uid,
    Map<String, dynamic> userData,
  ) {
    final email = (userData['email'] ?? '').toString();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('products').snapshots(),
      builder: (context, sellerSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _db.collection('reseller_products').snapshots(),
          builder: (context, resellerSnapshot) {
            if (sellerSnapshot.hasError) {
              return _errorView(
                sellerSnapshot.error.toString(),
              );
            }

            if (resellerSnapshot.hasError) {
              return _errorView(
                resellerSnapshot.error.toString(),
              );
            }

            if (sellerSnapshot.connectionState ==
                    ConnectionState.waiting ||
                resellerSnapshot.connectionState ==
                    ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final sellerDocs = sellerSnapshot.data?.docs ?? [];
            final resellerDocs = resellerSnapshot.data?.docs ?? [];

            final sellerProducts = sellerDocs.where((doc) {
              final data = doc.data();

              final sellerId =
                  (data['sellerId'] ?? '').toString();

              final userId =
                  (data['userId'] ?? '').toString();

              final ownerId =
                  (data['ownerId'] ?? '').toString();

              final sellerUid =
                  (data['sellerUid'] ?? '').toString();

              final sellerEmail =
                  (data['sellerEmail'] ?? '').toString();

              return sellerId == uid ||
                  userId == uid ||
                  ownerId == uid ||
                  sellerUid == uid ||
                  (email.isNotEmpty &&
                      sellerEmail == email);
            }).toList();

            final resellerProducts = resellerDocs.where((doc) {
              final data = doc.data();

              final entrepreneurId =
                  (data['entrepreneurId'] ?? '').toString();

              final userId =
                  (data['userId'] ?? '').toString();

              final entrepreneurUid =
                  (data['entrepreneurUid'] ?? '').toString();

              final resellerId =
                  (data['resellerId'] ?? '').toString();

              final entrepreneurEmail =
                  (data['entrepreneurEmail'] ?? '').toString();

              return entrepreneurId == uid ||
                  userId == uid ||
                  entrepreneurUid == uid ||
                  resellerId == uid ||
                  (email.isNotEmpty &&
                      entrepreneurEmail == email);
            }).toList();

            if (sellerProducts.isEmpty &&
                resellerProducts.isEmpty) {
              return const Center(
                child: Text(
                  'No products found for this user.',
                ),
              );
            }

            return ListView(
              children: [
                if (sellerProducts.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Seller Products',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                ...sellerProducts.map((doc) {
                  final data = doc.data();

                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.storefront_outlined,
                    ),
                    title: Text(
                      (data['name'] ??
                              data['productName'] ??
                              'Product')
                          .toString(),
                    ),
                    subtitle: Text(
                      'Price: ৳${_toDouble(data['price']).toStringAsFixed(2)}',
                    ),
                  );
                }),

                if (resellerProducts.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(
                      top: 10,
                      bottom: 6,
                    ),
                    child: Text(
                      'Reseller Products',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                ...resellerProducts.map((doc) {
                  final data = doc.data();

                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.sync_alt_outlined,
                    ),
                    title: Text(
                      (data['productName'] ??
                              data['name'] ??
                              'Product')
                          .toString(),
                    ),
                    subtitle: Text(
                      'Supplier: ৳${_toDouble(data['supplierPrice']).toStringAsFixed(2)} • '
                      'Selling: ৳${_toDouble(data['sellingPrice']).toStringAsFixed(2)}',
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // USER VIDEOS
  // ============================================================

  Widget _userVideos(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('sellerVideos')
          .where(
            'sellerId',
            isEqualTo: uid,
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorView(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text('No videos found.'),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();

            return ListTile(
              dense: true,
              leading: const Icon(
                Icons.play_circle_outline,
              ),
              title: Text(
                (data['title'] ??
                        data['caption'] ??
                        'Seller Video')
                    .toString(),
              ),
              subtitle: Text(
                (data['videoUrl'] ?? '').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // USER ORDERS
  // ============================================================

  Widget _userOrders(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('orders').snapshots(),
      builder: (context, customerSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _db.collection('seller_orders').snapshots(),
          builder: (context, sellerSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db.collection('reseller_orders').snapshots(),
              builder: (context, resellerSnapshot) {
                if (customerSnapshot.hasError) {
                  return _errorView(
                    customerSnapshot.error.toString(),
                  );
                }

                if (sellerSnapshot.hasError) {
                  return _errorView(
                    sellerSnapshot.error.toString(),
                  );
                }

                if (resellerSnapshot.hasError) {
                  return _errorView(
                    resellerSnapshot.error.toString(),
                  );
                }

                if (customerSnapshot.connectionState ==
                        ConnectionState.waiting ||
                    sellerSnapshot.connectionState ==
                        ConnectionState.waiting ||
                    resellerSnapshot.connectionState ==
                        ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final List<_AdminOrderItem> orders = [];

                for (final doc
                    in customerSnapshot.data?.docs ?? []) {
                  final data = doc.data();

                  if (_orderBelongsToUser(data, uid)) {
                    orders.add(
                      _AdminOrderItem(
                        id: doc.id,
                        data: data,
                        type: 'Customer Order',
                        collection: 'orders',
                      ),
                    );
                  }
                }

                for (final doc
                    in sellerSnapshot.data?.docs ?? []) {
                  final data = doc.data();

                  if (_orderBelongsToUser(data, uid)) {
                    orders.add(
                      _AdminOrderItem(
                        id: doc.id,
                        data: data,
                        type: 'Seller Order',
                        collection: 'seller_orders',
                      ),
                    );
                  }
                }

                for (final doc
                    in resellerSnapshot.data?.docs ?? []) {
                  final data = doc.data();

                  if (_orderBelongsToUser(data, uid)) {
                    orders.add(
                      _AdminOrderItem(
                        id: doc.id,
                        data: data,
                        type: 'Reseller Order',
                        collection: 'reseller_orders',
                      ),
                    );
                  }
                }

                orders.sort(
                  (a, b) => _dateFromValue(
                    b.data['createdAt'],
                  ).compareTo(
                    _dateFromValue(
                      a.data['createdAt'],
                    ),
                  ),
                );

                if (orders.isEmpty) {
                  return const Center(
                    child: Text('No orders found.'),
                  );
                }

                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];

                    return _adminOrderListTile(order);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  bool _orderBelongsToUser(
    Map<String, dynamic> data,
    String uid,
  ) {
    const possibleFields = [
      'customerId',
      'userId',
      'buyerId',
      'sellerId',
      'sellerUid',
      'entrepreneurId',
      'entrepreneurUid',
      'resellerId',
      'resellerUid',
    ];

    for (final field in possibleFields) {
      if ((data[field] ?? '').toString() == uid) {
        return true;
      }
    }

    return false;
  }

  Widget _adminOrderListTile(_AdminOrderItem order) {
    final data = order.data;

    final total = _toDouble(
      data['totalAmount'] ??
          data['total'] ??
          data['sellingTotal'] ??
          data['subtotal'],
    );

    final status = (data['status'] ??
            data['orderStatus'] ??
            'Pending')
        .toString();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(
          order.type == 'Reseller Order'
              ? Icons.sync_alt_outlined
              : order.type == 'Seller Order'
                  ? Icons.storefront_outlined
                  : Icons.shopping_bag_outlined,
        ),
        title: Text(
          order.type,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Order ${order.id}\n'
          '৳${total.toStringAsFixed(2)} • $status',
        ),
        isThreeLine: true,
      ),
    );
  }

  // ============================================================
  // DELETE USER
  // ============================================================

  Future<void> _deleteUser(String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete User?'),
          content: const Text(
            'This will permanently delete the Firebase user account. '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('adminDeleteUser');

      await callable.call({
        'uid': uid,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User deleted successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete user: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // SELLER REQUESTS
  // ============================================================

  Widget _sellerRequestsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('users')
          .where(
            'sellerStatus',
            isEqualTo: 'pending',
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorView(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No pending seller requests.',
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            return _requestCard(
              uid: docs[index].id,
              data: docs[index].data(),
              role: 'Seller',
              onApprove: () => _confirmSellerAction(
                docs[index].id,
                true,
              ),
              onReject: () => _confirmSellerAction(
                docs[index].id,
                false,
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // ENTREPRENEUR REQUESTS
  // ============================================================

  Widget _entrepreneurRequestsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('users')
          .where(
            'entrepreneurStatus',
            isEqualTo: 'pending',
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorView(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No pending entrepreneur requests.',
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            return _requestCard(
              uid: docs[index].id,
              data: docs[index].data(),
              role: 'Entrepreneur',
              onApprove: () =>
                  _confirmEntrepreneurAction(
                docs[index].id,
                true,
              ),
              onReject: () =>
                  _confirmEntrepreneurAction(
                docs[index].id,
                false,
              ),
            );
          },
        );
      },
    );
  }

  Widget _requestCard({
    required String uid,
    required Map<String, dynamic> data,
    required String role,
    required VoidCallback onApprove,
    required VoidCallback onReject,
  }) {
    final name =
        (data['name'] ?? 'No Name').toString();

    final email =
        (data['email'] ?? 'No Email').toString();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _profileAvatar(data),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(email),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _summaryRow('Role', role),
            _summaryRow('UID', uid),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(
                      Icons.close,
                    ),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(
                      Icons.check,
                    ),
                    label: const Text('Approve'),
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
  // SELLER APPROVE / REJECT
  // ============================================================

  Future<void> _confirmSellerAction(
    String uid,
    bool approve,
  ) async {
    final action = approve ? 'approve' : 'reject';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            '${approve ? 'Approve' : 'Reject'} Seller',
          ),
          content: Text(
            'Are you sure you want to $action this seller request?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              child: Text(
                approve ? 'Approve' : 'Reject',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _updateSellerStatus(
      uid,
      approve ? 'approved' : 'rejected',
    );
  }

  Future<void> _updateSellerStatus(
    String uid,
    String status,
  ) async {
    try {
      final updates = <String, dynamic>{
        'sellerStatus': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status == 'approved') {
        final existingSnapshot =
            await _db.collection('users').doc(uid).get();

        final existingCode =
            (existingSnapshot.data()?['sellerCode'] ?? '')
                .toString();

        updates['sellerCode'] = existingCode.isNotEmpty
            ? existingCode
            : await _generateSequentialSellerCode();

        updates['sellerApprovedAt'] =
            FieldValue.serverTimestamp();
      }

      await _db
          .collection('users')
          .doc(uid)
          .set(
            updates,
            SetOptions(merge: true),
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Seller $status successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // ENTREPRENEUR APPROVE / REJECT
  // ============================================================

  Future<void> _confirmEntrepreneurAction(
    String uid,
    bool approve,
  ) async {
    final action = approve ? 'approve' : 'reject';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            '${approve ? 'Approve' : 'Reject'} Entrepreneur',
          ),
          content: Text(
            'Are you sure you want to $action this entrepreneur request?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              child: Text(
                approve ? 'Approve' : 'Reject',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _updateEntrepreneurStatus(
      uid,
      approve ? 'approved' : 'rejected',
    );
  }

  Future<void> _updateEntrepreneurStatus(
    String uid,
    String status,
  ) async {
    try {
      final updates = <String, dynamic>{
        'entrepreneurStatus': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status == 'approved') {
        final existingSnapshot =
            await _db.collection('users').doc(uid).get();

        final existingCode =
            (existingSnapshot.data()?['entrepreneurCode'] ?? '')
                .toString();

        updates['entrepreneurCode'] =
            existingCode.isNotEmpty
                ? existingCode
                : await _generateSequentialEntrepreneurCode();

        updates['entrepreneurApprovedAt'] =
            FieldValue.serverTimestamp();
      }

      await _db
          .collection('users')
          .doc(uid)
          .set(
            updates,
            SetOptions(merge: true),
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Entrepreneur $status successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // RELATIONSHIPS
  // ============================================================

  Widget _relationshipsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('reseller_products')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorView(snapshot.error.toString());
        }

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No Seller ↔ Reseller relationships found.',
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();

            final supplierPrice =
                _toDouble(data['supplierPrice']);

            final sellingPrice =
                _toDouble(data['sellingPrice']);

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      (data['productName'] ??
                              data['name'] ??
                              'Product')
                          .toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _summaryRow(
                      'Seller Code',
                      (data['sellerCode'] ?? 'N/A').toString(),
                    ),
                    _summaryRow(
                      'Reseller Code',
                      (data['entrepreneurCode'] ??
                              data['resellerCode'] ??
                              'N/A')
                          .toString(),
                    ),
                    _summaryRow(
                      'Supplier Price',
                      '৳${supplierPrice.toStringAsFixed(2)}',
                    ),
                    _summaryRow(
                      'Selling Price',
                      '৳${sellingPrice.toStringAsFixed(2)}',
                    ),
                    _summaryRow(
                      'Profit',
                      '৳${(sellingPrice - supplierPrice).toStringAsFixed(2)}',
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

  // ============================================================
  // PRODUCTS
  // ============================================================

  Widget _productsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorView(snapshot.error.toString());
        }

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = [...(snapshot.data?.docs ?? [])];

        docs.sort((a, b) {
          final aDate =
              _dateFromValue(a.data()['createdAt']);
          final bDate =
              _dateFromValue(b.data()['createdAt']);

          return bDate.compareTo(aDate);
        });

        if (docs.isEmpty) {
          return const Center(
            child: Text('No products found.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();

            final imageUrl =
                (data['imageUrl'] ?? '').toString();

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: imageUrl.isNotEmpty
                    ? CircleAvatar(
                        backgroundImage:
                            NetworkImage(imageUrl),
                      )
                    : const CircleAvatar(
                        child: Icon(
                          Icons.image_outlined,
                        ),
                      ),
                title: Text(
                  (data['name'] ??
                          data['productName'] ??
                          'Product')
                      .toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '৳${_toDouble(data['price']).toStringAsFixed(2)} • '
                  '${data['category'] ?? 'No Category'}',
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  onPressed: () =>
                      _deleteProduct(doc.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Product?'),
          content: const Text(
            'This product will be removed from BuyNova.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _db
          .collection('products')
          .doc(productId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Product deleted successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete product: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // ORDERS
  // ============================================================

  Widget _ordersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('orders').snapshots(),
      builder: (context, customerSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _db.collection('seller_orders').snapshots(),
          builder: (context, sellerSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db.collection('reseller_orders').snapshots(),
              builder: (context, resellerSnapshot) {
                if (customerSnapshot.hasError) {
                  return _errorView(
                    customerSnapshot.error.toString(),
                  );
                }

                if (sellerSnapshot.hasError) {
                  return _errorView(
                    sellerSnapshot.error.toString(),
                  );
                }

                if (resellerSnapshot.hasError) {
                  return _errorView(
                    resellerSnapshot.error.toString(),
                  );
                }

                if (customerSnapshot.connectionState ==
                        ConnectionState.waiting ||
                    sellerSnapshot.connectionState ==
                        ConnectionState.waiting ||
                    resellerSnapshot.connectionState ==
                        ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final List<_AdminOrderItem> allOrders = [];

                for (final doc
                    in customerSnapshot.data?.docs ?? []) {
                  allOrders.add(
                    _AdminOrderItem(
                      id: doc.id,
                      data: doc.data(),
                      type: 'Customer Order',
                      collection: 'orders',
                    ),
                  );
                }

                for (final doc
                    in sellerSnapshot.data?.docs ?? []) {
                  allOrders.add(
                    _AdminOrderItem(
                      id: doc.id,
                      data: doc.data(),
                      type: 'Direct Seller Order',
                      collection: 'seller_orders',
                    ),
                  );
                }

                for (final doc
                    in resellerSnapshot.data?.docs ?? []) {
                  allOrders.add(
                    _AdminOrderItem(
                      id: doc.id,
                      data: doc.data(),
                      type: 'Reseller Order',
                      collection: 'reseller_orders',
                    ),
                  );
                }

                allOrders.sort(
                  (a, b) => _dateFromValue(
                    b.data['createdAt'],
                  ).compareTo(
                    _dateFromValue(
                      a.data['createdAt'],
                    ),
                  ),
                );

                if (allOrders.isEmpty) {
                  return const Center(
                    child: Text('No orders found.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: allOrders.length,
                  itemBuilder: (context, index) {
                    return _adminOrderCard(
                      allOrders[index],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _adminOrderCard(_AdminOrderItem order) {
    final data = order.data;

    final total = _toDouble(
      data['totalAmount'] ??
          data['total'] ??
          data['sellingTotal'] ??
          data['subtotal'],
    );

    final status = (data['status'] ??
            data['orderStatus'] ??
            'Pending')
        .toString();

    final paymentStatus =
        (data['paymentStatus'] ?? 'Pending').toString();

    final customerName =
        (data['customerName'] ?? '').toString();

    final customerPhone =
        (data['customerPhone'] ?? '').toString();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  order.type == 'Reseller Order'
                      ? Icons.sync_alt_outlined
                      : order.type == 'Direct Seller Order'
                          ? Icons.storefront_outlined
                          : Icons.shopping_bag_outlined,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.type,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            _summaryRow(
              'Order ID',
              order.id,
            ),

            _summaryRow(
              'Total',
              '৳${total.toStringAsFixed(2)}',
            ),

            _summaryRow(
              'Order Status',
              status,
            ),

            _summaryRow(
              'Payment',
              paymentStatus,
            ),

            if (customerName.isNotEmpty)
              _summaryRow(
                'Customer',
                customerName,
              ),

            if (customerPhone.isNotEmpty)
              _summaryRow(
                'Phone',
                customerPhone,
              ),

            if (order.type == 'Reseller Order')
              _summaryRow(
                'Order Source',
                'Reseller → Seller delivery',
              ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateAdminOrderStatus(
                      order,
                      'Cancelled',
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _updateAdminOrderStatus(
                      order,
                      'Completed',
                    ),
                    child: const Text('Complete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateAdminOrderStatus(
    _AdminOrderItem order,
    String status,
  ) async {
    try {
      final collection = _db.collection(order.collection);

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (order.collection == 'orders') {
        updates['status'] = status;
      } else {
        updates['orderStatus'] = status;
      }

      await collection.doc(order.id).update(updates);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order updated to $status.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update order: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Widget _statusChip(
    String text,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _summaryRow(
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Error:\n$error',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  DateTime _dateFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

// ================================================================
// ADMIN ORDER MODEL
// ================================================================

class _AdminOrderItem {
  final String id;
  final Map<String, dynamic> data;
  final String type;
  final String collection;

  const _AdminOrderItem({
    required this.id,
    required this.data,
    required this.type,
    required this.collection,
  });
}

// ================================================================
// REUSABLE ADMIN SECTION PAGE
// ================================================================

class _AdminSectionPage extends StatelessWidget {
  final String title;

  final Stream<QuerySnapshot<Map<String, dynamic>>>?
      notificationStream;

  final String notificationLabel;

  final Widget child;

  const _AdminSectionPage({
    required this.title,
    required this.child,
    this.notificationStream,
    this.notificationLabel = 'Items',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          if (notificationStream != null)
            _notificationCard(context),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _notificationCard(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: notificationStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(
              12,
              12,
              12,
              6,
            ),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.notifications_outlined,
                  color: Colors.orange,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Notification count unavailable.',
                  ),
                ),
              ],
            ),
          );
        }

        final count = snapshot.data?.docs.length ?? 0;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(
            12,
            12,
            12,
            6,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '🔔 $count $notificationLabel',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
