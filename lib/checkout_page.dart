import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'my_orders_page.dart';
import 'address_book_page.dart';

class CheckoutItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String? imageUrl;

  final bool isResellerProduct;
  final String? entrepreneurUid;
  final String? sellerId;
  final String? supplierProductId;
  final double? supplierPrice;
  final double? resellerProfit;

  CheckoutItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
    this.isResellerProduct = false,
    this.entrepreneurUid,
    this.sellerId,
    this.supplierProductId,
    this.supplierPrice,
    this.resellerProfit,
  });

  double get total => price * quantity;
}

class CheckoutPage extends StatefulWidget {
  final List<CheckoutItem> items;
  final bool clearCartOnSuccess;

  const CheckoutPage({
    super.key,
    required this.items,
    this.clearCartOnSuccess = true,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _functionsRegion = 'asia-northeast3';

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _couponController = TextEditingController();

  // Must match CouponPage
  static const String _pendingCouponKey = 'buynova_pending_coupon';

  String _paymentMethod = 'Cash on Delivery';

  bool _placingOrder = false;
  bool _checkingCoupon = false;

  // NOTE: discount / delivery fee / totals shown here are only a preview.
  // The real values are calculated by the server (createOrder function).
  double _discount = 0;
  String? _couponCode;
  String? _couponMessage;

  double _walletBalance = 0;
  bool _loadingWalletBalance = false;

  Map<String, dynamic>? _selectedAddress;
  String? _selectedAddressId;

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: _functionsRegion);

  // ============================================================
  // DELIVERY FEE (preview only)
  // Inside Dhaka: ৳60, Outside Dhaka: ৳120
  // ============================================================

  String get _deliveryZone =>
      _selectedAddress?['deliveryZone']?.toString() ?? '';

  bool get _hasDeliveryZone =>
      _deliveryZone == 'inside_dhaka' || _deliveryZone == 'outside_dhaka';

  bool get _isInsideDhaka {
    final address = _selectedAddress;
    if (address == null) return false;

    final zone = _deliveryZone;
    if (zone == 'inside_dhaka') return true;
    if (zone == 'outside_dhaka') return false;

    final text =
        '${address['city'] ?? ''} ${address['district'] ?? ''}'.toLowerCase();

    return text.contains('dhaka') || text.contains('ঢাকা');
  }

  double get _deliveryFee {
    if (_selectedAddress == null) return 60;
    return _isInsideDhaka ? 60 : 120;
  }

  double get subtotal =>
      widget.items.fold(0, (sum, item) => sum + item.total);

  double get grandTotal {
    final value = subtotal + _deliveryFee - _discount;
    return value < 0 ? 0 : value;
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadDefaultAddress();
    _loadWalletBalance();
    _loadSavedCoupon();
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  // ============================================================
  // COUPON SELECTED FROM COUPON PAGE
  // ============================================================

  Future<void> _loadSavedCoupon() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_pendingCouponKey);

      if (savedCode == null || savedCode.trim().isEmpty) return;

      // Consume the pending coupon once.
      await prefs.remove(_pendingCouponKey);

      if (!mounted) return;

      setState(() {
        _couponController.text = savedCode.trim().toUpperCase();
      });

      await _checkCoupon(showMessage: true);
    } catch (_) {
      // Coupon loading is optional.
    }
  }

  // ============================================================
  // WALLET
  // ============================================================

  Future<void> _loadWalletBalance() async {
    if (!mounted) return;

    setState(() => _loadingWalletBalance = true);

    try {
      if (_auth.currentUser == null) return;

      final result =
          await _functions.httpsCallable('getWalletBalance').call();

      final data = Map<String, dynamic>.from(result.data as Map);
      final dynamic balanceValue = data['balance'] ?? data['cashBalance'] ?? 0;
      final balance = (balanceValue as num).toDouble();

      if (!mounted) return;
      setState(() => _walletBalance = balance);
    } catch (_) {
      if (!mounted) return;
      setState(() => _walletBalance = 0);
    } finally {
      if (mounted) {
        setState(() => _loadingWalletBalance = false);
      }
    }
  }

  bool get _walletHasEnoughBalance => _walletBalance >= grandTotal;

  // ============================================================
  // ADDRESS
  // ============================================================

  Future<void> _loadDefaultAddress() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final addressesRef =
          _firestore.collection('users').doc(user.uid).collection('addresses');

      final defaultSnapshot = await addressesRef
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();

      if (defaultSnapshot.docs.isNotEmpty) {
        if (!mounted) return;

        setState(() {
          _selectedAddress = defaultSnapshot.docs.first.data();
          _selectedAddressId = defaultSnapshot.docs.first.id;
        });
        return;
      }

      final anySnapshot = await addressesRef.limit(1).get();

      if (anySnapshot.docs.isNotEmpty) {
        if (!mounted) return;

        setState(() {
          _selectedAddress = anySnapshot.docs.first.data();
          _selectedAddressId = anySnapshot.docs.first.id;
        });
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final address = userDoc.data()?['address'];

      if (address is Map) {
        if (!mounted) return;

        setState(() {
          _selectedAddress = Map<String, dynamic>.from(address);
          _selectedAddressId = null; // legacy address stored on user doc
        });
      }
    } catch (_) {}
  }

  Future<void> _openAddressBook() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddressBookPage()),
    );

    await _loadDefaultAddress();
  }

  // ============================================================
  // COUPON (preview check - server validates again on order)
  // ============================================================

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  DateTime? _couponExpiry(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  void _resetCoupon(String? message) {
    if (!mounted) return;

    setState(() {
      _discount = 0;
      _couponCode = null;
      _couponMessage = message;
    });
  }

  Future<bool> _checkCoupon({bool showMessage = true}) async {
    final code = _couponController.text.trim().toUpperCase();

    if (code.isEmpty) {
      if (showMessage) _resetCoupon('Please enter a coupon code.');
      return false;
    }

    if (mounted) {
      setState(() {
        _checkingCoupon = true;
        if (showMessage) _couponMessage = null;
      });
    }

    try {
      final snapshot = await _firestore
          .collection('coupons')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        _resetCoupon('Invalid coupon code.');
        return false;
      }

      final data = snapshot.docs.first.data();

      if (data['isActive'] != true) {
        _resetCoupon('This coupon is not active.');
        return false;
      }

      final expiresAt = _couponExpiry(data['expiresAt']);
      if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
        _resetCoupon('This coupon has expired.');
        return false;
      }

      final double usageLimit = _toDouble(data['usageLimit']);
      final double usedCount = _toDouble(data['usedCount']);
      if (usageLimit > 0 && usedCount >= usageLimit) {
        _resetCoupon('This coupon has reached its usage limit.');
        return false;
      }

      final String discountType =
          (data['discountType'] ?? 'fixed').toString().toLowerCase().trim();
      final double discountValue = _toDouble(data['discountValue']);
      final double minimumOrder = _toDouble(data['minimumOrder']);
      final double maximumDiscount = _toDouble(data['maximumDiscount']);

      if (minimumOrder > 0 && subtotal < minimumOrder) {
        _resetCoupon(
          'Minimum order amount is ৳${minimumOrder.toStringAsFixed(2)}.',
        );
        return false;
      }

      double calculatedDiscount;

      if (discountType == 'percentage') {
        calculatedDiscount = subtotal * discountValue / 100;

        if (maximumDiscount > 0 && calculatedDiscount > maximumDiscount) {
          calculatedDiscount = maximumDiscount;
        }
      } else {
        calculatedDiscount = discountValue;
      }

      if (calculatedDiscount < 0) calculatedDiscount = 0;
      if (calculatedDiscount > subtotal) calculatedDiscount = subtotal;

      if (mounted) {
        setState(() {
          _discount = calculatedDiscount;
          _couponCode = code;
          _couponMessage = calculatedDiscount > 0
              ? 'Coupon applied. Discount: '
                  '৳${calculatedDiscount.toStringAsFixed(2)}'
              : 'Coupon applied, but no discount was calculated.';
        });
      }

      return true;
    } catch (_) {
      _resetCoupon('Could not validate coupon. Please try again.');
      return false;
    } finally {
      if (mounted) {
        setState(() => _checkingCoupon = false);
      }
    }
  }

  // ============================================================
  // WALLET PRE-CHECK
  // ============================================================

  Future<bool> _validateWalletBeforeOrder() async {
    await _loadWalletBalance();

    if (!_walletHasEnoughBalance) {
      if (!mounted) return false;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Insufficient Wallet Balance'),
          content: Text(
            'Your BuyNova Wallet balance is '
            '৳${_walletBalance.toStringAsFixed(2)}, '
            'but this order requires '
            '৳${grandTotal.toStringAsFixed(2)}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      return false;
    }

    return true;
  }

  // ============================================================
  // PLACE ORDER
  // The server calculates prices, discount, delivery fee and total.
  // ============================================================

  Future<void> _placeOrder() async {
    if (_placingOrder) return;

    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Please login first.');
      return;
    }

    if (widget.items.isEmpty) {
      _showMessage('Your cart is empty.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_selectedAddress == null) {
      _showMessage('Please select a delivery address.');
      return;
    }

    if (!_hasDeliveryZone) {
      _showMessage(
        'Please edit your address and choose Inside Dhaka or Outside Dhaka.',
      );
      return;
    }

    setState(() => _placingOrder = true);

    try {
      // Revalidate coupon (preview)
      if (_couponController.text.trim().isNotEmpty) {
        final couponValid = await _checkCoupon();
        if (!couponValid) return;
      } else {
        _resetCoupon(null);
      }

      // Wallet pre-check (UX only, the server checks again)
      final bool isWallet = _paymentMethod == 'BuyNova Wallet';

      if (isWallet) {
        final enough = await _validateWalletBeforeOrder();
        if (!enough) return;
      }

      // ------------------------------------------------------
      // CREATE ORDER ON SERVER
      // ------------------------------------------------------

      final createResult = await _functions.httpsCallable('createOrder').call({
        'items': widget.items
            .map((item) => {
                  'productId': item.id,
                  'quantity': item.quantity,
                  'isResellerProduct': item.isResellerProduct,
                })
            .toList(),
        'couponCode': _couponCode,
        'paymentMethod': _paymentMethod,
        'addressId': _selectedAddressId,
      });

      final createData = Map<String, dynamic>.from(createResult.data as Map);
      final String orderId = createData['orderId'].toString();

      // ------------------------------------------------------
      // WALLET PAYMENT
      // ------------------------------------------------------

      if (isWallet) {
        try {
          final result = await _functions
              .httpsCallable('placeWalletOrder')
              .call({'orderId': orderId});

          final resultData = Map<String, dynamic>.from(result.data as Map);

          final bool success = resultData['success'] == true ||
              resultData['alreadyPaid'] == true;

          if (!success) {
            throw Exception('Wallet payment could not be completed.');
          }
        } catch (_) {
          // Do not leave an unpaid order behind.
          await _cancelUnpaidOrder(orderId);
          rethrow;
        }
      }

      // ------------------------------------------------------
      // CLEAR CART
      // ------------------------------------------------------

      if (widget.clearCartOnSuccess) {
        await _clearCart(user.uid);
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text('Order Placed'),
            ],
          ),
          content: Text(
            isWallet
                ? 'Your order has been placed and paid successfully using BuyNova Wallet.'
                : 'Your order has been placed successfully.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MyOrdersPage()),
      );
    } catch (e) {
      debugPrint('Place order error: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _placingOrder = false);
      }
    }
  }

  String _friendlyError(Object error) {
    // Messages thrown by our own server function are safe to show.
    if (error is FirebaseFunctionsException) {
      final message = error.message ?? '';

      if (message.toLowerCase().contains('insufficient')) {
        return 'Your BuyNova Wallet balance is not enough for this order.';
      }

      switch (error.code) {
        case 'unauthenticated':
          return 'Please login again.';
        case 'invalid-argument':
        case 'failed-precondition':
        case 'not-found':
          if (message.isNotEmpty) return message;
      }
    }

    final text = error.toString().toLowerCase();

    if (text.contains('insufficient')) {
      return 'Your BuyNova Wallet balance is not enough for this order.';
    }

    return 'Something went wrong. Please try again.';
  }

  Future<void> _cancelUnpaidOrder(String orderId) async {
    try {
      await _functions
          .httpsCallable('cancelUnpaidOrder')
          .call({'orderId': orderId});
    } catch (e) {
      debugPrint('Cancel unpaid order error: $e');
    }
  }

  // ============================================================
  // CLEAR CART
  // ============================================================

  Future<void> _clearCart(String uid) async {
    try {
      final cartSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('cart')
          .get();

      if (cartSnapshot.docs.isEmpty) return;

      final batch = _firestore.batch();

      for (final doc in cartSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (_) {
      // Order has already been successfully placed.
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ============================================================
  // ADDRESS CARD
  // ============================================================

  Widget _buildAddressCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Delivery Address',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: _openAddressBook,
                  child: Text(_selectedAddress == null ? 'Add' : 'Change'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedAddress == null)
              const Text(
                'No delivery address selected.',
                style: TextStyle(color: Colors.grey),
              )
            else
              _buildAddressText(),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressText() {
    final address = _selectedAddress!;

    final name = address['name']?.toString() ?? '';
    final phone = address['phone']?.toString() ?? '';
    final line1 = address['address']?.toString() ??
        address['addressLine1']?.toString() ??
        '';
    final city = address['city']?.toString() ?? '';
    final postalCode = address['postalCode']?.toString() ??
        address['zipCode']?.toString() ??
        '';

    final zoneText = _deliveryZone == 'inside_dhaka'
        ? 'Inside Dhaka'
        : _deliveryZone == 'outside_dhaka'
            ? 'Outside Dhaka'
            : '';

    Widget line(String text) => Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(text),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name.isNotEmpty)
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        if (phone.isNotEmpty) line(phone),
        if (line1.isNotEmpty) line(line1),
        if (city.isNotEmpty || postalCode.isNotEmpty)
          line('$city ${postalCode.isNotEmpty ? postalCode : ''}'.trim()),
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            zoneText.isEmpty
                ? 'Delivery area not set. Tap Change, then edit '
                    'this address and choose Inside/Outside Dhaka.'
                : zoneText,
            style: TextStyle(
              fontSize: 12,
              color: zoneText.isEmpty
                  ? Colors.orange.shade800
                  : Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PAYMENT SECTION
  // ============================================================

  Widget _buildPaymentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            RadioGroup<String>(
              groupValue: _paymentMethod,
              onChanged: (value) async {
                if (value == null) return;

                setState(() => _paymentMethod = value);

                if (value == 'BuyNova Wallet') {
                  await _loadWalletBalance();
                }
              },
              child: Column(
                children: [
                  const RadioListTile<String>(
                    value: 'Cash on Delivery',
                    title: Text('Cash on Delivery'),
                    subtitle: Text('Pay when your order arrives.'),
                    secondary: Icon(Icons.local_shipping),
                  ),
                  RadioListTile<String>(
                    value: 'BuyNova Wallet',
                    title: const Text('BuyNova Wallet'),
                    subtitle: _loadingWalletBalance
                        ? const Text('Checking wallet balance...')
                        : Text(
                            'Balance: ৳${_walletBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                    secondary: const Icon(Icons.account_balance_wallet),
                  ),
                ],
              ),
            ),
            if (_paymentMethod == 'BuyNova Wallet') ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: (_walletHasEnoughBalance ? Colors.green : Colors.red)
                      .withValues(alpha: 0.08),
                ),
                child: Row(
                  children: [
                    Icon(
                      _walletHasEnoughBalance
                          ? Icons.check_circle
                          : Icons.warning,
                      color:
                          _walletHasEnoughBalance ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _walletHasEnoughBalance
                            ? 'Wallet balance is enough for this order.'
                            : 'Insufficient Wallet balance. Please add money before paying.',
                        style: TextStyle(
                          color: _walletHasEnoughBalance
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // COUPON SECTION
  // ============================================================

  Widget _buildCouponSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Coupon',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'Enter coupon code',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) {
                      if (!_checkingCoupon) _checkCoupon();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _checkingCoupon ? null : _checkCoupon,
                  child: _checkingCoupon
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Apply'),
                ),
              ],
            ),
            if (_couponMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _couponMessage!,
                style: TextStyle(
                  color: _discount > 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ORDER ITEMS
  // ============================================================

  Widget _buildOrderItems() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...widget.items.map((item) {
              final hasImage =
                  item.imageUrl != null && item.imageUrl!.isNotEmpty;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.grey.shade200,
                      ),
                      child: hasImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                item.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.image_not_supported);
                                },
                              ),
                            )
                          : const Icon(Icons.shopping_bag),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Qty: ${item.quantity}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '৳${item.total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryRow('Subtotal', subtotal),
            const SizedBox(height: 8),
            _summaryRow(
              _hasDeliveryZone
                  ? 'Delivery Fee (${_isInsideDhaka ? 'Inside' : 'Outside'} Dhaka)'
                  : 'Delivery Fee',
              _deliveryFee,
            ),
            if (_discount > 0) ...[
              const SizedBox(height: 8),
              _summaryRow('Discount', -_discount, color: Colors.green),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Grand Total',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '৳${grandTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String title, double value, {Color? color}) {
    final prefix = value < 0 ? '- ' : '';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title),
        Text(
          '$prefix৳${value.abs().toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontWeight: color != null ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildAddressCard(),
            const SizedBox(height: 12),
            _buildOrderItems(),
            const SizedBox(height: 12),
            _buildCouponSection(),
            const SizedBox(height: 12),
            _buildPaymentSection(),
            const SizedBox(height: 12),
            _buildSummary(),
            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _placingOrder ? null : _placeOrder,
                child: _placingOrder
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _paymentMethod == 'BuyNova Wallet'
                            ? 'Pay ৳${grandTotal.toStringAsFixed(2)} with Wallet'
                            : 'Place Order',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
