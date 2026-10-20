part of 'admin_panel_page.dart';

extension _AdminRequestsPart on _AdminPanelPageState {
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
}
