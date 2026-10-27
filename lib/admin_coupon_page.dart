import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Admin: create, edit, pause and delete coupons.
/// Saves into the `coupons` collection. Users see changes live on the
/// Coupons & Promo page.
class AdminCouponPage extends StatefulWidget {
  const AdminCouponPage({super.key});

  @override
  State<AdminCouponPage> createState() => _AdminCouponPageState();
}

class _AdminCouponPageState extends State<AdminCouponPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =========================================================
  // HELPERS
  // =========================================================

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _discountText(Map<String, dynamic> data) {
    final type = data['discountType']?.toString().toLowerCase() ?? 'fixed';
    final value = _toDouble(data['discountValue']);

    if (type == 'percentage') return '${value.toStringAsFixed(0)}% OFF';

    return '৳${value.toStringAsFixed(0)} OFF';
  }

  String _formatDate(dynamic value) {
    if (value is! Timestamp) return 'No expiry';

    final d = value.toDate();

    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  InputDecoration _decoration(String label, IconData icon,
      {String? hint, String? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  // =========================================================
  // CREATE / EDIT COUPON
  // =========================================================

  Future<void> _showCouponForm({
    DocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    final data = document?.data();

    final codeController =
        TextEditingController(text: data?['code']?.toString() ?? '');
    final discountController =
        TextEditingController(text: data?['discountValue']?.toString() ?? '');
    final minimumController =
        TextEditingController(text: data?['minimumOrder']?.toString() ?? '0');
    final maximumController = TextEditingController(
        text: data?['maximumDiscount']?.toString() ?? '0');

    String discountType = data?['discountType']?.toString() ?? 'percentage';
    bool isActive = data?['isActive'] != false;

    final existingExpiry = data?['expiresAt'];

    DateTime expiryDate = existingExpiry is Timestamp
        ? existingExpiry.toDate()
        : DateTime.now().add(const Duration(days: 30));

    String? errorMessage;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> selectExpiryDate() async {
              final selected = await showDatePicker(
                context: context,
                initialDate: expiryDate.isBefore(DateTime.now())
                    ? DateTime.now()
                    : expiryDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );

              if (selected == null) return;

              setDialogState(() {
                expiryDate = DateTime(
                  selected.year,
                  selected.month,
                  selected.day,
                  23,
                  59,
                  59,
                );
              });
            }

            void fail(String message) {
              setDialogState(() => errorMessage = message);
            }

            Future<void> saveCoupon() async {
              if (saving) return;

              final code = codeController.text.trim().toUpperCase();
              final discount = double.tryParse(discountController.text.trim());
              final minimumOrder =
                  double.tryParse(minimumController.text.trim());
              final maximumDiscount =
                  double.tryParse(maximumController.text.trim());

              if (code.isEmpty) return fail('Please enter a coupon code.');

              if (discount == null || discount <= 0) {
                return fail('Please enter a valid discount.');
              }

              if (discountType == 'percentage' && discount > 100) {
                return fail('Percentage discount cannot exceed 100%.');
              }

              if (minimumOrder == null || minimumOrder < 0) {
                return fail('Please enter a valid minimum order.');
              }

              if (maximumDiscount == null || maximumDiscount < 0) {
                return fail('Please enter a valid maximum discount.');
              }

              if (expiryDate.isBefore(DateTime.now())) {
                return fail('Expiry date must be in the future.');
              }

              setDialogState(() {
                errorMessage = null;
                saving = true;
              });

              try {
                // Duplicate code check
                final duplicates = await _firestore
                    .collection('coupons')
                    .where('code', isEqualTo: code)
                    .limit(5)
                    .get();

                for (final duplicate in duplicates.docs) {
                  if (document == null || duplicate.id != document.id) {
                    setDialogState(() {
                      saving = false;
                      errorMessage = 'This coupon code already exists.';
                    });
                    return;
                  }
                }

                final couponData = <String, dynamic>{
                  'code': code,
                  'discountType': discountType,
                  'discountValue': discount,
                  'minimumOrder': minimumOrder,
                  'maximumDiscount': maximumDiscount,
                  'isActive': isActive,
                  'expiresAt': Timestamp.fromDate(expiryDate),
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (document == null) {
                  couponData['createdAt'] = FieldValue.serverTimestamp();

                  await _firestore.collection('coupons').add(couponData);
                } else {
                  await _firestore
                      .collection('coupons')
                      .doc(document.id)
                      .update(couponData);
                }

                if (dialogContext.mounted) Navigator.pop(dialogContext);

                _showMessage(
                  document == null
                      ? 'Coupon created successfully.'
                      : 'Coupon updated successfully.',
                );
              } catch (_) {
                setDialogState(() {
                  saving = false;
                  errorMessage = 'Could not save coupon.';
                });
              }
            }

            return AlertDialog(
              title: Text(document == null ? 'Create Coupon' : 'Edit Coupon'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 420,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: _decoration(
                          'Coupon Code',
                          Icons.confirmation_number_outlined,
                          hint: 'Example: WELCOME10',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: discountType,
                        decoration:
                            _decoration('Discount Type', Icons.discount_outlined),
                        items: const [
                          DropdownMenuItem(
                            value: 'percentage',
                            child: Text('Percentage (%)'),
                          ),
                          DropdownMenuItem(
                            value: 'fixed',
                            child: Text('Fixed Amount (৳)'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() => discountType = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: discountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _decoration(
                          discountType == 'percentage'
                              ? 'Discount Percentage'
                              : 'Discount Amount',
                          Icons.price_check_outlined,
                          suffix: discountType == 'percentage' ? '%' : '৳',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: minimumController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _decoration(
                          'Minimum Order',
                          Icons.shopping_cart_outlined,
                          suffix: '৳',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: maximumController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _decoration(
                          'Maximum Discount',
                          Icons.vertical_align_bottom_outlined,
                          hint: '0 = No limit',
                          suffix: '৳',
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: selectExpiryDate,
                        child: InputDecorator(
                          decoration:
                              _decoration('Expiry Date', Icons.event_outlined),
                          child: Text(
                            '${expiryDate.day.toString().padLeft(2, '0')}/'
                            '${expiryDate.month.toString().padLeft(2, '0')}/'
                            '${expiryDate.year}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Coupon Active'),
                        subtitle: const Text(
                          'Customers can use this coupon when active.',
                        ),
                        value: isActive,
                        activeThumbColor: Colors.redAccent,
                        onChanged: (value) {
                          setDialogState(() => isActive = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : saveCoupon,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(document == null ? 'Create' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
    discountController.dispose();
    minimumController.dispose();
    maximumController.dispose();
  }

  // =========================================================
  // DELETE / TOGGLE
  // =========================================================

  Future<void> _deleteCoupon(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final code = document.data()?['code']?.toString() ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Coupon?'),
          content: Text('Are you sure you want to delete "$code"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('coupons').doc(document.id).delete();

      _showMessage('Coupon deleted.');
    } catch (_) {
      _showMessage('Could not delete coupon.');
    }
  }

  Future<void> _toggleCoupon(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final current = document.data()?['isActive'] == true;

    try {
      await _firestore.collection('coupons').doc(document.id).update({
        'isActive': !current,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showMessage(current ? 'Coupon deactivated.' : 'Coupon activated.');
    } catch (_) {
      _showMessage('Could not update coupon.');
    }
  }

  // =========================================================
  // COUPON CARD
  // =========================================================

  Widget _couponCard(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? {};

    final code = data['code']?.toString() ?? '';
    final isActive = data['isActive'] == true;
    final minimum = _toDouble(data['minimumOrder']);
    final maximum = _toDouble(data['maximumDiscount']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_offer_outlined,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        code,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _discountText(data),
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showCouponForm(document: document);
                    } else if (value == 'toggle') {
                      _toggleCoupon(document);
                    } else if (value == 'delete') {
                      _deleteCoupon(document);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            isActive
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                          ),
                          const SizedBox(width: 8),
                          Text(isActive ? 'Deactivate' : 'Activate'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _smallInfo('Minimum', '৳${minimum.toStringAsFixed(0)}'),
                const SizedBox(width: 20),
                _smallInfo(
                  'Max Discount',
                  maximum <= 0 ? 'No limit' : '৳${maximum.toStringAsFixed(0)}',
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isActive ? Colors.green : Colors.red)
                        .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(
                      color: isActive ? Colors.green : Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.event_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Expires: ${_formatDate(data['expiresAt'])}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallInfo(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        title: const Text(
          'Coupon Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCouponForm(),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Coupon'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('coupons').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Could not load coupons.'),
              ),
            );
          }

          final documents = snapshot.data?.docs ?? [];

          if (documents.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_offer_outlined,
                      size: 65,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No coupons created yet.',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap "Create Coupon" to create your first promotion.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }

          // Active coupons first.
          final sorted = [...documents]..sort((a, b) {
              final aActive = a.data()['isActive'] == true;
              final bActive = b.data()['isActive'] == true;

              if (aActive == bActive) return 0;

              return aActive ? -1 : 1;
            });

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              Row(
                children: [
                  const Icon(Icons.local_offer_outlined,
                      color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Text(
                    '${documents.length} Coupon${documents.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...sorted.map(_couponCard),
            ],
          );
        },
      ),
    );
  }
}
