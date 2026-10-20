part of 'admin_panel_page.dart';

extension _AdminCatalogPart on _AdminPanelPageState {
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
}
