part of 'admin_panel_page.dart';

extension _AdminUsersPart on _AdminPanelPageState {
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
}
