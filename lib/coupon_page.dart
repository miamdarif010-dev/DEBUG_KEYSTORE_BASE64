import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CouponStatus { available, inactive, expired, usedUp }

class CouponPage extends StatefulWidget {
  const CouponPage({super.key});

  @override
  State<CouponPage> createState() => _CouponPageState();
}

class _CouponPageState extends State<CouponPage> {
  final TextEditingController _codeController = TextEditingController();

  bool _checkingCode = false;

  static const String _pendingCouponKey = 'buynova_pending_coupon';

  // Created once, so setState() does not recreate the stream.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _couponStream =
      FirebaseFirestore.instance
          .collection('coupons')
          .where('isActive', isEqualTo: true)
          .snapshots();

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _getExpiryDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Single source of truth for coupon availability.
  CouponStatus _couponStatus(Map<String, dynamic> data) {
    if (data['isActive'] != true) return CouponStatus.inactive;

    final expiry = _getExpiryDate(data['expiresAt']);
    if (expiry != null && expiry.isBefore(DateTime.now())) {
      return CouponStatus.expired;
    }

    final usageLimit = _toDouble(data['usageLimit']);
    final usedCount = _toDouble(data['usedCount']);
    if (usageLimit > 0 && usedCount >= usageLimit) {
      return CouponStatus.usedUp;
    }

    return CouponStatus.available;
  }

  String _statusLabel(CouponStatus status) {
    switch (status) {
      case CouponStatus.available:
        return 'Active';
      case CouponStatus.inactive:
        return 'Inactive';
      case CouponStatus.expired:
        return 'Expired';
      case CouponStatus.usedUp:
        return 'Fully Used';
    }
  }

  String _discountText(Map<String, dynamic> data) {
    final type =
        data['discountType']?.toString().toLowerCase().trim() ?? 'fixed';
    final value = _toDouble(data['discountValue']);

    if (type == 'percentage') {
      return '${value.toStringAsFixed(0)}% OFF';
    }
    return '৳${value.toStringAsFixed(0)} OFF';
  }

  String _formatDate(dynamic value) {
    final date = _getExpiryDate(value);
    if (date == null) return 'No expiry date';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _checkCoupon() async {
    final code = _codeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      _showMessage('Please enter a coupon code.');
      return;
    }

    setState(() => _checkingCode = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('coupons')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (!mounted) return;

      if (querySnapshot.docs.isEmpty) {
        _showCouponResult(
          title: 'Coupon Not Found',
          message: 'This coupon code does not exist.',
          icon: Icons.error_outline,
          color: Colors.red,
        );
        return;
      }

      final data = querySnapshot.docs.first.data();

      switch (_couponStatus(data)) {
        case CouponStatus.inactive:
          _showCouponResult(
            title: 'Coupon Inactive',
            message: 'This coupon is no longer active.',
            icon: Icons.block_outlined,
            color: Colors.orange,
          );
          return;
        case CouponStatus.expired:
          _showCouponResult(
            title: 'Coupon Expired',
            message: 'This coupon has expired.',
            icon: Icons.event_busy_outlined,
            color: Colors.red,
          );
          return;
        case CouponStatus.usedUp:
          _showCouponResult(
            title: 'Coupon Fully Used',
            message: 'This coupon has reached its usage limit.',
            icon: Icons.block_outlined,
            color: Colors.orange,
          );
          return;
        case CouponStatus.available:
          break;
      }

      final maximumDiscount = _toDouble(data['maximumDiscount']);
      final minimumOrder = _toDouble(data['minimumOrder']);
      final isPercentage =
          (data['discountType']?.toString().toLowerCase().trim() ?? 'fixed') ==
              'percentage';

      var message = _discountText(data);
      if (isPercentage && maximumDiscount > 0) {
        message += ' • Up to ৳${maximumDiscount.toStringAsFixed(0)}';
      }
      if (minimumOrder > 0) {
        message += '\nMinimum order: ৳${minimumOrder.toStringAsFixed(0)}';
      }

      _showCouponResult(
        title: 'Coupon Available',
        message: message,
        icon: Icons.local_offer_outlined,
        color: Colors.green,
      );
    } on FirebaseException catch (error) {
      debugPrint('Coupon check Firebase error: ${error.code} ${error.message}');
      if (!mounted) return;

      _showCouponResult(
        title: 'Coupon Check Error',
        message: 'Could not check the coupon. Please try again later.',
        icon: Icons.error_outline,
        color: Colors.red,
      );
    } catch (error) {
      debugPrint('Coupon check error: $error');
      if (!mounted) return;

      _showCouponResult(
        title: 'Coupon Check Error',
        message: 'Something went wrong. Please try again.',
        icon: Icons.error_outline,
        color: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _checkingCode = false);
      }
    }
  }

  Future<void> _selectCoupon(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingCouponKey, cleanCode);

      if (!mounted) return;

      _codeController.text = cleanCode;
      _showMessage(
        'Coupon $cleanCode selected. It will be verified again at checkout.',
      );
    } catch (error) {
      debugPrint('Select coupon error: $error');
      if (!mounted) return;
      _showMessage('Could not select this coupon. Please try again.');
    }
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  void _showCouponResult({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _couponCard(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();

    final code = data['code']?.toString() ?? '';
    final minimumOrder = _toDouble(data['minimumOrder']);
    final maximumDiscount = _toDouble(data['maximumDiscount']);
    final expiresAt = data['expiresAt'];

    final status = _couponStatus(data);
    final available = status == CouponStatus.available;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
                      const SizedBox(height: 3),
                      Text(
                        _discountText(data),
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (available ? Colors.green : Colors.red)
                        .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      color: available ? Colors.green : Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (minimumOrder > 0)
              _infoRow(
                Icons.shopping_cart_outlined,
                'Minimum order',
                '৳${minimumOrder.toStringAsFixed(0)}',
              ),
            if (maximumDiscount > 0)
              _infoRow(
                Icons.discount_outlined,
                'Maximum discount',
                '৳${maximumDiscount.toStringAsFixed(0)}',
              ),
            _infoRow(
              Icons.event_outlined,
              'Valid until',
              _formatDate(expiresAt),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: available ? () => _selectCoupon(code) : null,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  available ? 'Use This Coupon' : _statusLabel(status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'No coupons available right now.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'New promotions will appear here.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(Object? error) {
    debugPrint('Load coupons error: $error');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.error_outline, size: 45, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'Could not load coupons.\nPlease try again later.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        title: const Text(
          'Coupons & Promo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Have a promo code?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'Enter coupon code',
                          prefixIcon: const Icon(
                            Icons.confirmation_number_outlined,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onSubmitted: (_) {
                          if (!_checkingCode) _checkCoupon();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _checkingCode ? null : _checkCoupon,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _checkingCode
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Check'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _couponStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.redAccent),
                  );
                }

                if (snapshot.hasError) {
                  return _errorState(snapshot.error);
                }

                final documents = (snapshot.data?.docs ?? [])
                    .where((doc) =>
                        _couponStatus(doc.data()) == CouponStatus.available)
                    .toList();

                if (documents.isEmpty) return _emptyState();

                // Soonest expiry first; coupons without expiry go last.
                documents.sort((a, b) {
                  final aDate = _getExpiryDate(a.data()['expiresAt']);
                  final bDate = _getExpiryDate(b.data()['expiresAt']);

                  if (aDate != null && bDate != null) {
                    return aDate.compareTo(bDate);
                  }
                  if (aDate != null) return -1;
                  if (bDate != null) return 1;
                  return 0;
                });

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                  children: [
                    const Text(
                      'Available Coupons',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...documents.map(_couponCard),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}
