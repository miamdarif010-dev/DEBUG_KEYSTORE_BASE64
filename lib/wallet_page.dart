import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = false;

  User? get _user => _auth.currentUser;

  DocumentReference<Map<String, dynamic>> get _userRef {
    return _firestore.collection('users').doc(_user!.uid);
  }

  CollectionReference<Map<String, dynamic>> get _transactionsRef {
    return _userRef.collection('walletTransactions');
  }

  // =========================================================
  // HELPERS
  // =========================================================

  String _money(dynamic value) {
    final number = value is num ? value.toDouble() : 0.0;

    if (number == number.roundToDouble()) {
      return '৳${number.toInt()}';
    }

    return '৳${number.toStringAsFixed(2)}';
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Processing...';

    final date = timestamp.toDate();

    final hour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day}/${date.month}/${date.year} '
        '$hour:$minute $period';
  }

  String _maskAccount(String account) {
    if (account.length <= 4) {
      return account;
    }

    final visible = account.substring(account.length - 4);

    return '•••• $visible';
  }

  String _statusText(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';

      case 'rejected':
        return 'Rejected';

      case 'pending':
        return 'Pending';

      default:
        return status.isEmpty ? 'Unknown' : status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;

      case 'rejected':
        return Colors.red;

      case 'pending':
        return Colors.orange;

      default:
        return Colors.grey;
    }
  }

  String _transactionTitle(Map<String, dynamic> data) {
    final source = data['source']?.toString() ?? '';
    final type = data['type']?.toString() ?? '';

    if (source == 'deposit' || type == 'credit') {
      return 'Add Money';
    }

    if (source == 'withdrawal' || type == 'debit') {
      return 'Withdrawal';
    }

    return 'Wallet Transaction';
  }

  IconData _transactionIcon(Map<String, dynamic> data) {
    final source = data['source']?.toString() ?? '';
    final type = data['type']?.toString() ?? '';

    if (source == 'deposit' || type == 'credit') {
      return Icons.add_circle;
    }

    if (source == 'withdrawal' || type == 'debit') {
      return Icons.account_balance_wallet;
    }

    return Icons.receipt_long;
  }

  // =========================================================
  // ADD MONEY
  // =========================================================

  Future<Map<String, String>> _loadPaymentInfo() async {
    try {
      final doc = await _firestore
          .collection('platformSettings')
          .doc('paymentInfo')
          .get();

      final data = doc.data() ?? {};

      // -------------------------------------------------------
      // New Firestore field names:
      //
      // bkashNumber
      // nagadNumber
      // rocketNumber
      // bankAccount
      //
      // Old field names are also supported for compatibility.
      // -------------------------------------------------------

      String readPaymentField(
        String newField,
        String oldField,
      ) {
        final newValue = data[newField]?.toString().trim() ?? '';

        if (newValue.isNotEmpty) {
          return newValue;
        }

        return data[oldField]?.toString().trim() ?? '';
      }

      return {
        'bkash': readPaymentField(
          'bkashNumber',
          'bkash',
        ),
        'nagad': readPaymentField(
          'nagadNumber',
          'nagad',
        ),
        'rocket': readPaymentField(
          'rocketNumber',
          'rocket',
        ),
        'bank': readPaymentField(
          'bankAccount',
          'bank',
        ),
      };
    } catch (_) {
      return {
        'bkash': '',
        'nagad': '',
        'rocket': '',
        'bank': '',
      };
    }
  }

  Future<void> _showAddMoneyDialog() async {
    final paymentInfo = await _loadPaymentInfo();

    if (!mounted) return;

    final amountController = TextEditingController();
    final senderController = TextEditingController();
    final trxController = TextEditingController();

    String selectedMethod = 'bkash';

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final destination = paymentInfo[selectedMethod] ?? '';

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.add_circle,
                    color: Colors.green,
                  ),
                  SizedBox(width: 10),
                  Text('Add Money'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '৳ ',
                        border: OutlineInputBorder(),
                        hintText: 'Minimum ৳100',
                      ),
                    ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: selectedMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'bkash',
                          child: Text('bKash'),
                        ),
                        DropdownMenuItem(
                          value: 'nagad',
                          child: Text('Nagad'),
                        ),
                        DropdownMenuItem(
                          value: 'rocket',
                          child: Text('Rocket'),
                        ),
                        DropdownMenuItem(
                          value: 'bank',
                          child: Text('Bank Transfer'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedMethod = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: destination.isEmpty
                          ? Text(
                              selectedMethod == 'bank'
                                  ? 'Bank account is not set yet. Please contact BuyNova support before sending money.'
                                  : '${selectedMethod == 'bkash' ? 'bKash' : selectedMethod == 'nagad' ? 'Nagad' : 'Rocket'} payment number is not set yet. Please contact BuyNova support before sending money.',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : Text(
                              'Step 1: Send money to this '
                              '${selectedMethod == 'bank' ? 'account' : 'number'}:\n'
                              '$destination\n\n'
                              'Step 2: Enter your number and the Transaction ID below.',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: senderController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Your sender number / account',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: trxController,
                      textCapitalization:
                          TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Transaction ID (TrxID)',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Your Add Money request will remain pending until an admin verifies the payment and approves it.',
                        style: TextStyle(
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () async {
                          final amount = double.tryParse(
                            amountController.text.trim(),
                          );

                          if (amount == null || amount < 100) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Minimum Add Money amount is ৳100.'),
                              ),
                            );
                            return;
                          }

                          final sender =
                              senderController.text.trim();

                          final trx = trxController.text
                              .trim()
                              .toUpperCase();

                          if (sender.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter your sender number.',
                                ),
                              ),
                            );
                            return;
                          }

                          if (trx.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter a valid Transaction ID.',
                                ),
                              ),
                            );
                            return;
                          }

                          Navigator.pop(dialogContext);

                          await _createDepositRequest(
                            amount,
                            selectedMethod,
                            sender,
                            trx,
                          );
                        },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
    senderController.dispose();
    trxController.dispose();
  }

  Future<void> _createDepositRequest(
    double amount,
    String method,
    String senderNumber,
    String trxId,
  ) async {
    if (_user == null) return;

    setState(() {
      _loading = true;
    });

    try {
      String methodName;

      switch (method) {
        case 'nagad':
          methodName = 'Nagad';
          break;

        case 'rocket':
          methodName = 'Rocket';
          break;

        case 'bank':
          methodName = 'Bank Transfer';
          break;

        default:
          methodName = 'bKash';
      }

      await _transactionsRef.add({
        'userId': _user!.uid,
        'type': 'credit',
        'source': 'deposit',
        'status': 'pending',
        'amount': amount,
        'currency': 'BDT',
        'currencySymbol': '৳',
        'paymentMethod': method,
        'paymentMethodName': methodName,
        'senderNumber': senderNumber,
        'trxId': trxId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add Money request submitted successfully.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not submit request: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // =========================================================
  // WITHDRAW
  // =========================================================

  Future<void> _showWithdrawMoneyDialog() async {
    final amountController = TextEditingController();
    final accountController = TextEditingController();

    String selectedMethod = 'bkash';

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.arrow_circle_up,
                    color: Colors.redAccent,
                  ),
                  SizedBox(width: 10),
                  Text('Withdraw Money'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Withdrawal Amount',
                        prefixText: '৳ ',
                        border: OutlineInputBorder(),
                        hintText: 'Minimum ৳100',
                      ),
                    ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: selectedMethod,
                      decoration: const InputDecoration(
                        labelText: 'Withdrawal Method',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'bkash',
                          child: Text('bKash'),
                        ),
                        DropdownMenuItem(
                          value: 'nagad',
                          child: Text('Nagad'),
                        ),
                        DropdownMenuItem(
                          value: 'rocket',
                          child: Text('Rocket'),
                        ),
                        DropdownMenuItem(
                          value: 'bank',
                          child: Text('Bank Transfer'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedMethod = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: accountController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: selectedMethod == 'bank'
                            ? 'Bank Account Number'
                            : 'Mobile Account Number',
                        prefixIcon: const Icon(
                          Icons.account_balance,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Your withdrawal will stay pending until an admin reviews and approves it.',
                        style: TextStyle(
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _loading
                      ? null
                      : () async {
                          final amount = double.tryParse(
                            amountController.text.trim(),
                          );

                          final account =
                              accountController.text.trim();

                          if (amount == null || amount < 100) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Minimum withdrawal amount is ৳100.'),
                              ),
                            );
                            return;
                          }

                          if (account.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter a valid account number.',
                                ),
                              ),
                            );
                            return;
                          }

                          Navigator.pop(dialogContext);

                          await _createWithdrawalRequest(
                            amount,
                            selectedMethod,
                            account,
                          );
                        },
                  child: const Text('Submit Withdrawal'),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
    accountController.dispose();
  }

  Future<void> _createWithdrawalRequest(
    double amount,
    String method,
    String account,
  ) async {
    if (_user == null) return;

    setState(() {
      _loading = true;
    });

    try {
      final userSnapshot = await _userRef.get();

      if (!userSnapshot.exists) {
        throw Exception('User account not found.');
      }

      final data = userSnapshot.data() ?? {};

      final currentBalance =
          (data['cashBalance'] as num?)?.toDouble() ?? 0.0;

      if (amount > currentBalance) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Insufficient wallet balance. Available: ${_money(currentBalance)}',
            ),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      String methodName;

      switch (method) {
        case 'nagad':
          methodName = 'Nagad';
          break;

        case 'rocket':
          methodName = 'Rocket';
          break;

        case 'bank':
          methodName = 'Bank Transfer';
          break;

        default:
          methodName = 'bKash';
      }

      await _transactionsRef.add({
        'userId': _user!.uid,
        'type': 'debit',
        'source': 'withdrawal',
        'status': 'pending',
        'amount': amount,
        'currency': 'BDT',
        'currencySymbol': '৳',
        'withdrawalMethod': method,
        'withdrawalMethodName': methodName,
        'accountNumber': account,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Withdrawal request submitted successfully.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not submit withdrawal: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // =========================================================
  // TRANSACTION DETAILS
  // =========================================================

  Future<void> _showTransactionDetails(
    Map<String, dynamic> data,
  ) async {
    final source = data['source']?.toString() ?? '';
    final type = data['type']?.toString() ?? '';
    final status = data['status']?.toString() ?? 'pending';

    final amount =
        (data['amount'] as num?)?.toDouble() ?? 0.0;

    final createdAt = data['createdAt'] as Timestamp?;

    final isWithdrawal =
        source == 'withdrawal' || type == 'debit';

    final account =
        data['accountNumber']?.toString() ?? '';

    final methodName =
        data['withdrawalMethodName']?.toString() ??
            data['paymentMethodName']?.toString() ??
            '';

    final trxId = data['trxId']?.toString() ?? '';

    final reason =
        data['reason']?.toString() ??
            data['adminReason']?.toString() ??
            '';

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  isWithdrawal
                      ? 'Withdrawal Details'
                      : 'Add Money Details',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 18),

                _detailRow(
                  'Amount',
                  _money(amount),
                ),

                _detailRow(
                  'Status',
                  _statusText(status),
                  valueColor: _statusColor(status),
                ),

                if (methodName.isNotEmpty)
                  _detailRow(
                    'Method',
                    methodName,
                  ),

                if (!isWithdrawal && trxId.isNotEmpty)
                  _detailRow(
                    'TrxID',
                    trxId,
                  ),

                if (isWithdrawal && account.isNotEmpty)
                  _detailRow(
                    'Account',
                    _maskAccount(account),
                  ),

                if (createdAt != null)
                  _detailRow(
                    'Date',
                    _formatDate(createdAt),
                  ),

                if (reason.isNotEmpty)
                  _detailRow(
                    'Reason',
                    reason,
                  ),

                const SizedBox(height: 10),

                if (status == 'pending')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Colors.orange.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'This transaction is waiting for admin approval.',
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(
    String title,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MAIN UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final user = _user;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please login to use Wallet.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wallet',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userRef.snapshots(),
        builder: (context, snapshot) {
          final userData = snapshot.data?.data() ?? {};

          final cashBalance =
              (userData['cashBalance'] as num?)?.toDouble() ?? 0.0;

          final points =
              (userData['points'] as num?)?.toInt() ?? 0;

          final lifetimePoints =
              (userData['lifetimePoints'] as num?)?.toInt() ?? 0;

          return RefreshIndicator(
            onRefresh: () async {
              await _userRef.get(
                const GetOptions(
                  source: Source.server,
                ),
              );
            },
            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                // =================================================
                // WALLET BALANCE CARD
                // =================================================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [
                        Colors.redAccent,
                        Colors.deepOrange,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 42,
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        'Wallet Balance',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        _money(cashBalance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _loading
                                  ? null
                                  : _showAddMoneyDialog,
                              icon: const Icon(
                                Icons.add,
                              ),
                              label: const Text(
                                'Add Money',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.white,
                                foregroundColor:
                                    Colors.redAccent,
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _loading
                                  ? null
                                  : _showWithdrawMoneyDialog,
                              icon: const Icon(
                                Icons.arrow_upward,
                              ),
                              label: const Text(
                                'Withdraw',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    Colors.white,
                                side: const BorderSide(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // =================================================
                // POINTS
                // =================================================

                Row(
                  children: [
                    Expanded(
                      child: _infoCard(
                        icon: Icons.stars,
                        title: 'Points',
                        value: points.toString(),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: _infoCard(
                        icon: Icons.emoji_events,
                        title: 'Lifetime Points',
                        value:
                            lifetimePoints.toString(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // =================================================
                // TRANSACTION HISTORY
                // =================================================

                const Text(
                  'Transaction History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: _transactionsRef
                      .orderBy(
                        'createdAt',
                        descending: true,
                      )
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(30),
                        child: Center(
                          child:
                              CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Container(
                        padding:
                            const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red
                              .withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Could not load transactions.\n${snapshot.error}',
                        ),
                      );
                    }

                    final docs =
                        snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(16),
                          color: Colors.grey
                              .withValues(alpha: 0.08),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 42,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'No transactions yet.',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: docs.map((doc) {
                        final data = doc.data();

                        final source =
                            data['source']
                                ?.toString() ??
                                '';

                        final type =
                            data['type']
                                ?.toString() ??
                                '';

                        final status =
                            data['status']
                                ?.toString() ??
                                'pending';

                        final amount =
                            (data['amount'] as num?)
                                    ?.toDouble() ??
                                0.0;

                        final isWithdrawal =
                            source ==
                                    'withdrawal' ||
                                type == 'debit';

                        final timestamp =
                            data['createdAt']
                                as Timestamp?;

                        final methodName =
                            data['withdrawalMethodName']
                                    ?.toString() ??
                                data['paymentMethodName']
                                    ?.toString() ??
                                '';

                        return Card(
                          margin:
                              const EdgeInsets.only(
                            bottom: 10,
                          ),
                          elevation: 0.5,
                          child: ListTile(
                            onTap: () =>
                                _showTransactionDetails(
                              data,
                            ),

                            leading: CircleAvatar(
                              backgroundColor:
                                  (isWithdrawal
                                          ? Colors.red
                                          : Colors.green)
                                      .withValues(
                                alpha: 0.10,
                              ),
                              child: Icon(
                                _transactionIcon(
                                  data,
                                ),
                                color: isWithdrawal
                                    ? Colors.red
                                    : Colors.green,
                              ),
                            ),

                            title: Text(
                              _transactionTitle(data),
                              style: const TextStyle(
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),

                            subtitle: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                const SizedBox(height: 3),

                                if (methodName.isNotEmpty)
                                  Text(
                                    methodName,
                                    style:
                                        const TextStyle(
                                      fontSize: 12,
                                    ),
                                  ),

                                Text(
                                  _formatDate(timestamp),
                                  style:
                                      const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),

                                const SizedBox(height: 3),

                                Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        _statusColor(
                                      status,
                                    ).withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius:
                                        BorderRadius
                                            .circular(6),
                                  ),
                                  child: Text(
                                    _statusText(status),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          _statusColor(
                                        status,
                                      ),
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            trailing: Text(
                              '${isWithdrawal ? '-' : '+'}${_money(amount)}',
                              style: TextStyle(
                                color: isWithdrawal
                                    ? Colors.red
                                    : Colors.green,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  // =========================================================
  // INFO CARD
  // =========================================================

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey.withValues(alpha: 0.08),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.orange,
            size: 28,
          ),

          const SizedBox(height: 8),

          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            value,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
