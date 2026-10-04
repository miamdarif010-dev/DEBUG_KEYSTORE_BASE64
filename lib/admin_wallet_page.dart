import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class AdminWalletPage extends StatefulWidget {
  const AdminWalletPage({super.key});

  @override
  State<AdminWalletPage> createState() => _AdminWalletPageState();
}

class _AdminWalletPageState extends State<AdminWalletPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(
    region: 'asia-northeast3',
  );

  bool _processing = false;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 2,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // =========================================================
  // ACCOUNT MASKING
  // =========================================================

  String _maskedAccount(String account) {
    final clean = account.trim();

    if (clean.isEmpty) {
      return '';
    }

    if (clean.length <= 4) {
      return '****';
    }

    if (clean.length <= 7) {
      return '****${clean.substring(clean.length - 2)}';
    }

    return '**** **** ${clean.substring(clean.length - 4)}';
  }

  // =========================================================
  // METHOD NAME
  // =========================================================

  String _methodName(String? method) {
    switch (method?.toLowerCase()) {
      case 'bkash':
        return 'bKash';

      case 'nagad':
        return 'Nagad';

      case 'rocket':
        return 'Rocket';

      case 'bank':
        return 'Bank Transfer';

      default:
        return method ?? 'Unknown';
    }
  }

  // =========================================================
  // APPROVE TRANSACTION
  // =========================================================

  Future<void> _approveTransaction(
    String userId,
    String transactionId,
  ) async {
    if (_processing) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      final callable =
          _functions.httpsCallable(
        'approveWalletTransaction',
      );

      final result = await callable.call({
        'userId': userId,
        'transactionId': transactionId,
      });

      if (!mounted) {
        return;
      }

      final data =
          Map<String, dynamic>.from(
        result.data as Map,
      );

      final newBalance =
          data['newBalance'] ?? 0;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transaction approved. New balance: ৳$newBalance',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ??
                'Could not approve transaction.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Something went wrong: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  // =========================================================
  // REJECT TRANSACTION
  // =========================================================

  Future<void> _rejectTransaction(
    String userId,
    String transactionId,
    String reason,
  ) async {
    if (_processing) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      final callable =
          _functions.httpsCallable(
        'rejectWalletTransaction',
      );

      await callable.call({
        'userId': userId,
        'transactionId': transactionId,
        'reason': reason,
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Transaction rejected successfully.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ??
                'Could not reject transaction.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Something went wrong: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  // =========================================================
  // ASK REJECTION REASON
  // =========================================================

  Future<void> _askReason(
    String userId,
    String transactionId,
  ) async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Reject Transaction',
          ),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText:
                  'Enter rejection reason',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final value =
                    controller.text.trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  value,
                );
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (reason == null ||
        reason.trim().isEmpty) {
      return;
    }

    await _rejectTransaction(
      userId,
      transactionId,
      reason.trim(),
    );
  }

  // =========================================================
  // CONFIRM ACTION
  // =========================================================

  Future<void> _confirmAction({
    required bool approve,
    required String userId,
    required String transactionId,
  }) async {
    if (approve) {
      final confirmed =
          await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Approve Transaction?',
            ),
            content: const Text(
              'Are you sure you want to approve this wallet transaction?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },
                child: const Text('Approve'),
              ),
            ],
          );
        },
      );

      if (confirmed == true) {
        await _approveTransaction(
          userId,
          transactionId,
        );
      }
    } else {
      await _askReason(
        userId,
        transactionId,
      );
    }
  }

  // =========================================================
  // SHOW DETAILS
  // =========================================================

  void _showDetails(
    DocumentSnapshot snapshot,
  ) {
    final data =
        snapshot.data()
            as Map<String, dynamic>? ??
            {};

    final amount =
        data['amount'] ?? 0;

    final type =
        data['type']?.toString() ??
            '';

    final source =
        data['source']?.toString() ??
            '';

    final method =
        data['paymentMethod']?.toString() ??
            data['withdrawalMethod']?.toString() ??
            '';

    final account =
        data['accountNumber']?.toString() ??
            '';

    final status =
        data['status']?.toString() ??
            '';

    final reason =
        data['reason']?.toString() ??
            data['rejectionReason']?.toString() ??
            '';

    final trxId =
        data['trxId']?.toString() ?? '';

    final senderNumber =
        data['senderNumber']?.toString() ?? '';

    final createdAt =
        data['createdAt'] as Timestamp?;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Transaction Details',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _detailRow(
                  'Amount',
                  '৳$amount',
                ),
                _detailRow(
                  'Type',
                  type,
                ),
                _detailRow(
                  'Source',
                  source,
                ),
                _detailRow(
                  'Method',
                  _methodName(method),
                ),
                _detailRow(
                  'Status',
                  status,
                ),

                // -------------------------------------------------
                // MASKED ACCOUNT NUMBER
                // -------------------------------------------------

                if (account.isNotEmpty)
                  _detailRow(
                    'Account',
                    _maskedAccount(account),
                  ),

                if (trxId.isNotEmpty)
                  _detailRow(
                    'TrxID',
                    trxId,
                  ),

                if (senderNumber.isNotEmpty)
                  _detailRow(
                    'Sender',
                    senderNumber,
                  ),

                if (reason.isNotEmpty)
                  _detailRow(
                    'Reason',
                    reason,
                  ),

                if (createdAt != null)
                  _detailRow(
                    'Created',
                    createdAt
                        .toDate()
                        .toString(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // TRANSACTION CARD
  // =========================================================

  Widget _transactionCard(
    DocumentSnapshot snapshot, {
    bool duplicateTrx = false,
  }) {
    final data =
        snapshot.data()
            as Map<String, dynamic>? ??
            {};

    final userId =
        data['userId']?.toString() ??
            '';

    final transactionId =
        snapshot.id;

    final amount =
        data['amount'] ?? 0;

    final method =
        data['paymentMethod']?.toString() ??
            data['withdrawalMethod']?.toString() ??
            '';

    final account =
        data['accountNumber']?.toString() ??
            '';

    final trxId =
        data['trxId']?.toString() ?? '';

    final senderNumber =
        data['senderNumber']?.toString() ?? '';

    final createdAt =
        data['createdAt'] as Timestamp?;

    final createdText =
        createdAt == null
            ? 'Processing...'
            : createdAt
                .toDate()
                .toString();

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Icon(
                    data['source'] ==
                            'deposit'
                        ? Icons
                            .account_balance_wallet
                        : Icons
                            .payments,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        '৳$amount',
                        style:
                            const TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        _methodName(
                          method,
                        ),
                        style:
                            TextStyle(
                          color: Colors
                              .grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _showDetails(
                      snapshot,
                    );
                  },
                  icon: const Icon(
                    Icons.info_outline,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 10,
            ),

            if (trxId.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(
                    Icons.confirmation_number_outlined,
                    size: 18,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child: SelectableText(
                      'TrxID: $trxId',
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 6,
              ),
            ],

            if (senderNumber.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(
                    Icons.smartphone,
                    size: 18,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child: SelectableText(
                      'Sender: $senderNumber',
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 6,
              ),
            ],

            if (duplicateTrx) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red
                      .withValues(alpha: 0.10),
                  borderRadius:
                      BorderRadius.circular(8),
                ),
                child: const Text(
                  'Warning: another pending request has the same TrxID.',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(
                height: 6,
              ),
            ],

            if (account.isNotEmpty)
              Row(
                children: [
                  const Icon(
                    Icons.phone,
                    size: 18,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Text(
                    _maskedAccount(
                      account,
                    ),
                  ),
                ],
              ),

            const SizedBox(
              height: 6,
            ),

            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 18,
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    createdText,
                    style:
                        TextStyle(
                      color: Colors
                          .grey[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 14,
            ),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _processing
                            ? null
                            : () {
                                _confirmAction(
                                  approve:
                                      false,
                                  userId:
                                      userId,
                                  transactionId:
                                      transactionId,
                                );
                              },
                    icon: const Icon(
                      Icons.close,
                    ),
                    label:
                        const Text(
                      'Reject',
                    ),
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _processing
                            ? null
                            : () {
                                _confirmAction(
                                  approve:
                                      true,
                                  userId:
                                      userId,
                                  transactionId:
                                      transactionId,
                                );
                              },
                    icon: const Icon(
                      Icons.check,
                    ),
                    label:
                        const Text(
                      'Approve',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // TRANSACTION STREAM
  // =========================================================

  Stream<QuerySnapshot> _transactionStream(
    String source,
  ) {
    return _firestore
        .collectionGroup(
          'walletTransactions',
        )
        .where(
          'source',
          isEqualTo: source,
        )
        .where(
          'status',
          isEqualTo: 'pending',
        )
        .orderBy(
          'createdAt',
          descending: true,
        )
        .snapshots();
  }

  // =========================================================
  // TRANSACTION LIST
  // =========================================================

  Widget _transactionList(
    String source,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _transactionStream(source),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(20),
              child: Text(
                'Could not load transactions.\n\n${snapshot.error}',
                textAlign:
                    TextAlign.center,
              ),
            ),
          );
        }

        final documents =
            snapshot.data?.docs ??
                [];

        if (documents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Icon(
                  source == 'deposit'
                      ? Icons
                          .account_balance_wallet_outlined
                      : Icons
                          .payments_outlined,
                  size: 60,
                  color:
                      Colors.grey[500],
                ),
                const SizedBox(
                  height: 12,
                ),
                Text(
                  source == 'deposit'
                      ? 'No pending deposits'
                      : 'No pending withdrawals',
                  style:
                      TextStyle(
                    fontSize: 16,
                    color:
                        Colors.grey[700],
                  ),
                ),
              ],
            ),
          );
        }

        final trxCounts = <String, int>{};

        for (final doc in documents) {
          final map =
              doc.data() as Map<String, dynamic>? ??
                  {};

          final t =
              map['trxId']?.toString() ?? '';

          if (t.isNotEmpty) {
            trxCounts[t] =
                (trxCounts[t] ?? 0) + 1;
          }
        }

        return RefreshIndicator(
          onRefresh: () async {
            await Future<void>.delayed(
              const Duration(
                milliseconds: 500,
              ),
            );
          },
          child: ListView.builder(
            padding:
                const EdgeInsets.all(12),
            itemCount:
                documents.length,
            itemBuilder: (
              context,
              index,
            ) {
              final map =
                  documents[index].data()
                          as Map<String, dynamic>? ??
                      {};

              final t =
                  map['trxId']?.toString() ?? '';

              return _transactionCard(
                documents[index],
                duplicateTrx:
                    t.isNotEmpty &&
                        (trxCounts[t] ?? 0) > 1,
              );
            },
          ),
        );
      },
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wallet Management',
        ),
        centerTitle: true,
        bottom: TabBar(
          controller:
              _tabController,
          tabs: const [
            Tab(
              icon:
                  Icon(Icons.add_card),
              text: 'Deposits',
            ),
            Tab(
              icon:
                  Icon(Icons.payments),
              text: 'Withdrawals',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller:
            _tabController,
        children: [
          _transactionList(
            'deposit',
          ),
          _transactionList(
            'withdrawal',
          ),
        ],
      ),
    );
  }
}
