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
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _couponController =
      TextEditingController();

  // ============================================================
  // BUY NOVA PENDING COUPON KEY
  // Must match CouponPage
  // ============================================================

  static const String _pendingCouponKey =
    'buynova_pending_coupon';

  String _paymentMethod = 'Cash on Delivery';

  bool _placingOrder = false;
  bool _checkingCoupon = false;

  double _discount = 0;

  String? _couponCode;
  String? _couponMessage;

  double _walletBalance = 0;
  bool _loadingWalletBalance = false;

  Map<String, dynamic>? _selectedAddress;

  // ============================================================
  // DELIVERY FEE
  // Inside Dhaka: ৳60
  // Outside Dhaka: ৳120
  // ============================================================

  String get _deliveryZone {
    return _selectedAddress?['deliveryZone']
            ?.toString() ??
        '';
  }

  bool get _hasDeliveryZone {
    return _deliveryZone == 'inside_dhaka' ||
        _deliveryZone == 'outside_dhaka';
  }

  bool get _isInsideDhaka {
    final address = _selectedAddress;

    if (address == null) return false;

    final zone = _deliveryZone;

    if (zone == 'inside_dhaka') return true;
    if (zone == 'outside_dhaka') return false;

    final text =
        '${address['city'] ?? ''} '
        '${address['district'] ?? ''}'
            .toLowerCase();

    return text.contains('dhaka') ||
        text.contains('ঢাকা');
  }

  double get _deliveryFee {
    if (_selectedAddress == null) return 60;

    return _isInsideDhaka ? 60 : 120;
  }

  double get subtotal {
    return widget.items.fold(
      0,
      (sum, item) => sum + item.total,
    );
  }

  double get grandTotal {
    final value =
        subtotal + _deliveryFee - _discount;

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
  // LOAD COUPON SELECTED FROM COUPON PAGE
  // ============================================================

  Future<void> _loadSavedCoupon() async {
    try {
      final prefs =
          await SharedPreferences.getInstance();

      final savedCode =
          prefs.getString(_pendingCouponKey);

      if (savedCode == null ||
          savedCode.trim().isEmpty) {
        return;
      }

      final cleanCode =
          savedCode.trim().toUpperCase();

      // Consume the pending coupon once.
      await prefs.remove(
        _pendingCouponKey,
      );

      if (!mounted) return;

      setState(() {
        _couponController.text =
            cleanCode;
      });

      // Automatically validate the selected coupon.
      await _checkCoupon(
        showMessage: true,
      );
    } catch (_) {
      // Coupon loading is optional.
    }
  }

  // ============================================================
  // WALLET
  // ============================================================

  Future<void> _loadWalletBalance() async {
    if (!mounted) return;

    setState(() {
      _loadingWalletBalance = true;
    });

    try {
      final user = _auth.currentUser;

      if (user == null) {
        return;
      }

      final callable =
          FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      ).httpsCallable(
        'getWalletBalance',
      );

      final result =
          await callable.call();

      final data =
          Map<String, dynamic>.from(
        result.data as Map,
      );

      final dynamic balanceValue =
          data['balance'] ??
              data['cashBalance'] ??
              0;

      final balance =
          (balanceValue as num).toDouble();

      if (!mounted) return;

      setState(() {
        _walletBalance = balance;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _walletBalance = 0;
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _loadingWalletBalance = false;
      });
    }
  }

  bool get _walletHasEnoughBalance {
    return _walletBalance >= grandTotal;
  }

  // ============================================================
  // ADDRESS
  // ============================================================

  Future<void> _loadDefaultAddress() async {
    final user = _auth.currentUser;

    if (user == null) return;

    try {
      final addressesRef =
          _firestore
              .collection('users')
              .doc(user.uid)
              .collection('addresses');

      final defaultSnapshot =
          await addressesRef
              .where(
                'isDefault',
                isEqualTo: true,
              )
              .limit(1)
              .get();

      if (defaultSnapshot.docs.isNotEmpty) {
        if (!mounted) return;

        setState(() {
          _selectedAddress =
              defaultSnapshot.docs.first.data();
        });

        return;
      }

      final anySnapshot =
          await addressesRef
              .limit(1)
              .get();

      if (anySnapshot.docs.isNotEmpty) {
        if (!mounted) return;

        setState(() {
          _selectedAddress =
              anySnapshot.docs.first.data();
        });

        return;
      }

      final userDoc =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .get();

      final data = userDoc.data();

      if (data == null) return;

      final address = data['address'];

      if (address is Map) {
        if (!mounted) return;

        setState(() {
          _selectedAddress =
              Map<String, dynamic>.from(
            address,
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _openAddressBook() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const AddressBookPage(),
      ),
    );

    await _loadDefaultAddress();
  }

  // ============================================================
  // COUPON HELPERS
  // ============================================================

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? 0;
    }

    return 0;
  }

  DateTime? _couponExpiry(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  // ============================================================
  // CHECK / APPLY COUPON
  // ============================================================

  Future<bool> _checkCoupon({
    bool showMessage = true,
  }) async {
    final code =
        _couponController.text
            .trim()
            .toUpperCase();

    if (code.isEmpty) {
      if (mounted && showMessage) {
        setState(() {
          _couponMessage =
              'Please enter a coupon code.';
          _discount = 0;
          _couponCode = null;
        });
      }

      return false;
    }

    if (mounted) {
      setState(() {
        _checkingCoupon = true;

        if (showMessage) {
          _couponMessage = null;
        }
      });
    }

    try {
      final snapshot =
          await _firestore
              .collection('coupons')
              .where(
                'code',
                isEqualTo: code,
              )
              .limit(1)
              .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _discount = 0;
            _couponCode = null;
            _couponMessage =
                'Invalid coupon code.';
          });
        }

        return false;
      }

      final data =
          snapshot.docs.first.data();

      // --------------------------------------------------------
      // ACTIVE CHECK
      // --------------------------------------------------------

      final bool isActive =
          data['isActive'] == true;

      if (!isActive) {
        if (mounted) {
          setState(() {
            _discount = 0;
            _couponCode = null;
            _couponMessage =
                'This coupon is not active.';
          });
        }

        return false;
      }

      // --------------------------------------------------------
      // EXPIRY CHECK
      // --------------------------------------------------------

      final expiresAt =
          _couponExpiry(
        data['expiresAt'],
      );

      if (expiresAt != null &&
          expiresAt.isBefore(
            DateTime.now(),
          )) {
        if (mounted) {
          setState(() {
            _discount = 0;
            _couponCode = null;
            _couponMessage =
                'This coupon has expired.';
          });
        }

        return false;
      }

      // --------------------------------------------------------
      // COUPON VALUES
      // --------------------------------------------------------

      final String discountType =
          (data['discountType'] ??
                  'fixed')
              .toString()
              .toLowerCase()
              .trim();

      final double discountValue =
          _toDouble(
        data['discountValue'],
      );

      final double minimumOrder =
          _toDouble(
        data['minimumOrder'],
      );

      final double maximumDiscount =
          _toDouble(
        data['maximumDiscount'],
      );

      // --------------------------------------------------------
      // MINIMUM ORDER
      // --------------------------------------------------------

      if (minimumOrder > 0 &&
          subtotal < minimumOrder) {
        if (mounted) {
          setState(() {
            _discount = 0;
            _couponCode = null;
            _couponMessage =
                'Minimum order amount is '
                '৳${minimumOrder.toStringAsFixed(2)}.';
          });
        }

        return false;
      }

      // --------------------------------------------------------
      // CALCULATE DISCOUNT
      // --------------------------------------------------------

      double calculatedDiscount;

      if (discountType ==
          'percentage') {
        calculatedDiscount =
            subtotal *
                discountValue /
                100;

        if (maximumDiscount > 0 &&
            calculatedDiscount >
                maximumDiscount) {
          calculatedDiscount =
              maximumDiscount;
        }
      } else {
        calculatedDiscount =
            discountValue;
      }

      if (calculatedDiscount < 0) {
        calculatedDiscount = 0;
      }

      if (calculatedDiscount >
          subtotal) {
        calculatedDiscount =
            subtotal;
      }

      // --------------------------------------------------------
      // APPLY
      // --------------------------------------------------------

      if (mounted) {
        setState(() {
          _discount =
              calculatedDiscount;

          _couponCode = code;

          _couponMessage =
              calculatedDiscount > 0
                  ? 'Coupon applied. Discount: '
                      '৳${calculatedDiscount.toStringAsFixed(2)}'
                  : 'Coupon applied, but no discount was calculated.';
        });
      }

      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _discount = 0;
          _couponCode = null;
          _couponMessage =
              'Could not validate coupon. Please try again.';
        });
      }

      return false;
    } finally {
      if (mounted) {
        setState(() {
          _checkingCoupon = false;
        });
      }
    }
  }

  // ============================================================
  // PAYMENT
  // ============================================================

  Future<bool>
      _validateWalletBeforeOrder() async {
    await _loadWalletBalance();

    if (!_walletHasEnoughBalance) {
      if (!mounted) return false;

      await showDialog(
        context: context,
        builder: (_) =>
            AlertDialog(
          title: const Text(
            'Insufficient Wallet Balance',
          ),
          content: Text(
            'Your BuyNova Wallet balance is '
            '৳${_walletBalance.toStringAsFixed(2)}, '
            'but this order requires '
            '৳${grandTotal.toStringAsFixed(2)}.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
              ),
              child:
                  const Text('OK'),
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
  // ============================================================

  Future<void> _placeOrder() async {
    if (_placingOrder) return;

    final user =
        _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Please login first.',
      );
      return;
    }

    if (widget.items.isEmpty) {
      _showMessage(
        'Your cart is empty.',
      );
      return;
    }

    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    if (_selectedAddress == null) {
      _showMessage(
        'Please select a delivery address.',
      );
      return;
    }

    if (!_hasDeliveryZone) {
      _showMessage(
        'Please edit your address and choose '
        'Inside Dhaka or Outside Dhaka.',
      );
      return;
    }

    setState(() {
      _placingOrder = true;
    });

    try {
      // --------------------------------------------------------
      // REVALIDATE COUPON
      // --------------------------------------------------------

      if (_couponController.text
          .trim()
          .isNotEmpty) {
        final couponValid =
            await _checkCoupon();

        if (!couponValid) {
          return;
        }
      } else {
        _discount = 0;
        _couponCode = null;
      }

      // --------------------------------------------------------
      // WALLET BALANCE
      // --------------------------------------------------------

      if (_paymentMethod ==
          'BuyNova Wallet') {
        final enough =
            await _validateWalletBeforeOrder();

        if (!enough) {
          return;
        }
      }

      // --------------------------------------------------------
      // MAIN ORDER
      // --------------------------------------------------------

      final orderRef =
          _firestore
              .collection('orders')
              .doc();

      final orderId =
          orderRef.id;

      final List<
              Map<String, dynamic>>
          orderItems = [];

      for (final item
          in widget.items) {
        orderItems.add({
          'productId': item.id,
          'name': item.name,
          'price': item.price,
          'quantity': item.quantity,
          'total': item.total,
          'imageUrl': item.imageUrl,
          'isResellerProduct':
              item.isResellerProduct,
          'entrepreneurUid':
              item.entrepreneurUid,
          'sellerId': item.sellerId,
          'supplierProductId':
              item.supplierProductId,
          'supplierPrice':
              item.supplierPrice,
          'resellerProfit':
              item.resellerProfit,
        });
      }

      final Map<String, dynamic>
          orderData = {
        'orderId': orderId,
        'userId': user.uid,
        'customerId': user.uid,
        'items': orderItems,
        'subtotal': subtotal,
        'deliveryFee': _deliveryFee,
        'deliveryZone': _deliveryZone,
        'discount': _discount,
        'total': grandTotal,
        'grandTotal': grandTotal,
        'currency': 'BDT',
        'couponCode': _couponCode,
        'paymentMethod':
            _paymentMethod,
        'paymentStatus': 'pending',
        'orderStatus': 'placed',
        'address': _selectedAddress,
        'createdAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      };

      // --------------------------------------------------------
      // GROUP SELLER ORDERS
      // --------------------------------------------------------

      final Map<String,
              List<CheckoutItem>>
          sellerGroups = {};

      for (final item
          in widget.items) {
        if (item.isResellerProduct) {
          continue;
        }

        String? sellerId =
            item.sellerId;

        if (sellerId == null ||
            sellerId.isEmpty) {
          try {
            final productDoc =
                await _firestore
                    .collection(
                        'products')
                    .doc(item.id)
                    .get();

            if (productDoc.exists) {
              final productData =
                  productDoc.data();

              sellerId =
                  productData?[
                              'sellerId']
                          ?.toString() ??
                      productData?[
                              'ownerId']
                          ?.toString();
            }
          } catch (_) {}
        }

        if (sellerId == null ||
            sellerId.isEmpty) {
          sellerId =
              'unknown_seller';
        }

        sellerGroups.putIfAbsent(
          sellerId,
          () => [],
        );

        sellerGroups[sellerId]!
            .add(item);
      }

      // --------------------------------------------------------
      // GROUP RESELLER ORDERS
      // --------------------------------------------------------

      final Map<String,
              List<CheckoutItem>>
          resellerGroups = {};

      for (final item
          in widget.items) {
        if (!item.isResellerProduct) {
          continue;
        }

        final entrepreneurUid =
            item.entrepreneurUid ??
                user.uid;

        final sellerId =
            item.sellerId ??
                'unknown_seller';

        final groupKey =
            '${entrepreneurUid}_$sellerId';

        resellerGroups.putIfAbsent(
          groupKey,
          () => [],
        );

        resellerGroups[groupKey]!
            .add(item);
      }

      final WriteBatch batch =
          _firestore.batch();

      // --------------------------------------------------------
      // MAIN ORDER
      // --------------------------------------------------------

      batch.set(
        orderRef,
        orderData,
      );

      // --------------------------------------------------------
      // SELLER ORDERS
      // --------------------------------------------------------

      for (final entry
          in sellerGroups.entries) {
        final sellerId =
            entry.key;

        final items =
            entry.value;

        final sellerSubtotal =
            items.fold<double>(
          0,
          (sum, item) =>
              sum + item.total,
        );

        final sellerOrderRef =
            _firestore
                .collection(
                    'seller_orders')
                .doc();

        batch.set(
          sellerOrderRef,
          {
            'orderId': orderId,
            'sellerOrderId':
                sellerOrderRef.id,
            'sellerId': sellerId,
            'buyerId': user.uid,
            'customerId': user.uid,
            'userId': user.uid,
            'items': items.map(
              (item) {
                return {
                  'productId':
                      item.id,
                  'name': item.name,
                  'price':
                      item.price,
                  'quantity':
                      item.quantity,
                  'total':
                      item.total,
                  'imageUrl':
                      item.imageUrl,
                };
              },
            ).toList(),
            'subtotal':
                sellerSubtotal,
            'currency': 'BDT',
            'paymentMethod':
                _paymentMethod,
            'paymentStatus':
                'pending',
            'orderStatus':
                'placed',
            'createdAt':
                FieldValue
                    .serverTimestamp(),
            'updatedAt':
                FieldValue
                    .serverTimestamp(),
          },
        );
      }

      // --------------------------------------------------------
      // RESELLER / ENTREPRENEUR ORDERS
      // --------------------------------------------------------

      for (final entry
          in resellerGroups.entries) {
        final items =
            entry.value;

        if (items.isEmpty) {
          continue;
        }

        final entrepreneurUid =
            items.first
                    .entrepreneurUid ??
                user.uid;

        final sellerId =
            items.first.sellerId ??
                'unknown_seller';

        final sellingTotal =
            items.fold<double>(
          0,
          (sum, item) =>
              sum + item.total,
        );

        final supplierTotal =
            items.fold<double>(
          0,
          (sum, item) {
            final supplierPrice =
                item.supplierPrice ??
                    0;

            return sum +
                (supplierPrice *
                    item.quantity);
          },
        );

        final resellerProfit =
            sellingTotal -
                supplierTotal;

        final resellerOrderRef =
            _firestore
                .collection(
                    'reseller_orders')
                .doc();

        batch.set(
          resellerOrderRef,
          {
            'orderId': orderId,
            'resellerOrderId':
                resellerOrderRef.id,
            'entrepreneurUid':
                entrepreneurUid,
            'buyerId': user.uid,
            'customerId': user.uid,
            'userId': user.uid,
            'sellerId': sellerId,
            'customerName':
                _selectedAddress?[
                            'name']
                        ?.toString() ??
                    '',
            'customerPhone':
                _selectedAddress?[
                            'phone']
                        ?.toString() ??
                    '',
            'address':
                _selectedAddress?[
                            'address']
                        ?.toString() ??
                    '',
            'deliveryZone':
                _deliveryZone,
            'items': items.map(
              (item) {
                return {
                  'productId':
                      item.id,
                  'name':
                      item.name,
                  'price':
                      item.price,
                  'quantity':
                      item.quantity,
                  'total':
                      item.total,
                  'imageUrl':
                      item.imageUrl,
                  'supplierProductId':
                      item.supplierProductId,
                  'supplierPrice':
                      item.supplierPrice,
                  'resellerProfit':
                      item.resellerProfit,
                };
              },
            ).toList(),
            'sellingTotal':
                sellingTotal,
            'supplierTotal':
                supplierTotal,
            'resellerProfit':
                resellerProfit,
            'profit':
                resellerProfit,
            'currency': 'BDT',
            'paymentMethod':
                _paymentMethod,
            'paymentStatus':
                'pending',
            'orderStatus':
                'placed',
            'createdAt':
                FieldValue
                    .serverTimestamp(),
            'updatedAt':
                FieldValue
                    .serverTimestamp(),
          },
        );
      }

      // --------------------------------------------------------
      // COMMIT ORDER
      // --------------------------------------------------------

      await batch.commit();

      // --------------------------------------------------------
      // BUY NOVA WALLET PAYMENT
      // --------------------------------------------------------

      if (_paymentMethod ==
          'BuyNova Wallet') {
        final callable =
            FirebaseFunctions
                .instanceFor(
          region:
              'asia-northeast3',
        ).httpsCallable(
          'placeWalletOrder',
        );

        final result =
            await callable.call({
          'orderId': orderId,
        });

        final resultData =
            Map<String, dynamic>.from(
          result.data as Map,
        );

        final bool success =
            resultData['success'] ==
                    true ||
                resultData[
                        'alreadyPaid'] ==
                    true;

        if (!success) {
          throw Exception(
            'Wallet payment could not be completed.',
          );
        }
      }

      // --------------------------------------------------------
      // CLEAR CART
      // --------------------------------------------------------

      if (widget.clearCartOnSuccess) {
        await _clearCart(
          user.uid,
        );
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible:
            false,
        builder: (_) =>
            AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
              ),
              SizedBox(
                width: 10,
              ),
              Text('Order Placed'),
            ],
          ),
          content: Text(
            _paymentMethod ==
                    'BuyNova Wallet'
                ? 'Your order has been placed and paid successfully using BuyNova Wallet.'
                : 'Your order has been placed successfully.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );
              },
              child:
                  const Text(
                'Continue',
              ),
            ),
          ],
        ),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const MyOrdersPage(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String message =
          'Something went wrong. Please try again.';

      final errorText =
          e.toString();

      if (errorText.contains(
              'insufficient') ||
          errorText.contains(
              'Insufficient')) {
        message =
            'Your BuyNova Wallet balance is not enough for this order.';
      } else if (errorText.contains(
          'unauthenticated')) {
        message =
            'Please login again.';
      } else if (errorText.contains(
          'not-found')) {
        message =
            'Order or Wallet service was not found.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
              Text(message),
          duration:
              const Duration(
            seconds: 4,
          ),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _placingOrder = false;
      });
    }
  }

  // ============================================================
  // CLEAR CART
  // ============================================================

  Future<void> _clearCart(
    String uid,
  ) async {
    try {
      final cartSnapshot =
          await _firestore
              .collection('users')
              .doc(uid)
              .collection('cart')
              .get();

      if (cartSnapshot.docs.isEmpty) {
        return;
      }

      final batch =
          _firestore.batch();

      for (final doc
          in cartSnapshot.docs) {
        batch.delete(
          doc.reference,
        );
      }

      await batch.commit();
    } catch (_) {
      // Order has already been successfully placed.
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(message),
      ),
    );
  }

  // ============================================================
  // ADDRESS CARD
  // ============================================================

  Widget _buildAddressCard() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                ),
                const SizedBox(
                  width: 8,
                ),
                const Expanded(
                  child: Text(
                    'Delivery Address',
                    style:
                        TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed:
                      _openAddressBook,
                  child: Text(
                    _selectedAddress ==
                            null
                        ? 'Add'
                        : 'Change',
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 8,
            ),
            if (_selectedAddress ==
                null)
              const Text(
                'No delivery address selected.',
                style:
                    TextStyle(
                  color: Colors.grey,
                ),
              )
            else
              _buildAddressText(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ADDRESS TEXT
  // ============================================================

  Widget _buildAddressText() {
    final address =
        _selectedAddress!;

    final name =
        address['name']
                ?.toString() ??
            '';

    final phone =
        address['phone']
                ?.toString() ??
            '';

    final line1 =
        address['address']
                ?.toString() ??
            address['addressLine1']
                ?.toString() ??
            '';

    final city =
        address['city']
                ?.toString() ??
            '';

    final postalCode =
        address['postalCode']
                ?.toString() ??
            address['zipCode']
                ?.toString() ??
            '';

    final zoneText =
        _deliveryZone ==
                'inside_dhaka'
            ? 'Inside Dhaka'
            : _deliveryZone ==
                    'outside_dhaka'
                ? 'Outside Dhaka'
                : '';

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment
              .start,
      children: [
        if (name.isNotEmpty)
          Text(
            name,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        if (phone.isNotEmpty)
          Padding(
            padding:
                const EdgeInsets.only(
              top: 3,
            ),
            child:
                Text(phone),
          ),
        if (line1.isNotEmpty)
          Padding(
            padding:
                const EdgeInsets.only(
              top: 3,
            ),
            child:
                Text(line1),
          ),
        if (city.isNotEmpty ||
            postalCode.isNotEmpty)
          Padding(
            padding:
                const EdgeInsets.only(
              top: 3,
            ),
            child: Text(
              '$city '
                      '${postalCode.isNotEmpty ? postalCode : ''}'
                  .trim(),
            ),
          ),
        Padding(
          padding:
              const EdgeInsets.only(
            top: 3,
          ),
          child: Text(
            zoneText.isEmpty
                ? 'Delivery area not set. Tap Change, then edit '
                    'this address and choose Inside/Outside Dhaka.'
                : zoneText,
            style:
                TextStyle(
              fontSize: 12,
              color: zoneText
                      .isEmpty
                  ? Colors.orange
                      .shade800
                  : Colors.grey
                      .shade600,
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
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            const Text(
              'Payment Method',
              style:
                  TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            RadioGroup<String>(
              groupValue:
                  _paymentMethod,
              onChanged:
                  (value) async {
                if (value == null) {
                  return;
                }

                setState(() {
                  _paymentMethod =
                      value;
                });

                if (value ==
                    'BuyNova Wallet') {
                  await _loadWalletBalance();
                }
              },
              child: Column(
                children: [
                  RadioListTile<
                      String>(
                    value:
                        'Cash on Delivery',
                    title:
                        const Text(
                      'Cash on Delivery',
                    ),
                    subtitle:
                        const Text(
                      'Pay when your order arrives.',
                    ),
                    secondary:
                        const Icon(
                      Icons
                          .local_shipping,
                    ),
                  ),
                  RadioListTile<
                      String>(
                    value:
                        'BuyNova Wallet',
                    title:
                        const Text(
                      'BuyNova Wallet',
                    ),
                    subtitle:
                        _loadingWalletBalance
                            ? const Text(
                                'Checking wallet balance...',
                              )
                            : Text(
                                'Balance: '
                                '৳${_walletBalance.toStringAsFixed(2)}',
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.green,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                ),
                              ),
                    secondary:
                        const Icon(
                      Icons
                          .account_balance_wallet,
                    ),
                  ),
                ],
              ),
            ),
            if (_paymentMethod ==
                'BuyNova Wallet') ...[
              const SizedBox(
                height: 6,
              ),
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.all(
                  12,
                ),
                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius
                          .circular(
                    12,
                  ),
                  color:
                      _walletHasEnoughBalance
                          ? Colors.green
                              .withValues(
                              alpha: 0.08,
                            )
                          : Colors.red
                              .withValues(
                              alpha: 0.08,
                            ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _walletHasEnoughBalance
                          ? Icons
                              .check_circle
                          : Icons.warning,
                      color:
                          _walletHasEnoughBalance
                              ? Colors.green
                              : Colors.red,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Text(
                        _walletHasEnoughBalance
                            ? 'Wallet balance is enough for this order.'
                            : 'Insufficient Wallet balance. Please add money before paying.',
                        style:
                            TextStyle(
                          color:
                              _walletHasEnoughBalance
                                  ? Colors.green
                                  : Colors.red,
                          fontWeight:
                              FontWeight
                                  .w600,
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
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            const Text(
              'Coupon',
              style:
                  TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller:
                        _couponController,
                    textCapitalization:
                        TextCapitalization
                            .characters,
                    decoration:
                        const InputDecoration(
                      hintText:
                          'Enter coupon code',
                      border:
                          OutlineInputBorder(),
                    ),
                    onSubmitted:
                        (_) =>
                            _checkCoupon(),
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                ElevatedButton(
                  onPressed:
                      _checkingCoupon
                          ? null
                          : _checkCoupon,
                  child:
                      _checkingCoupon
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : const Text(
                              'Apply',
                            ),
                ),
              ],
            ),
            if (_couponMessage !=
                null) ...[
              const SizedBox(
                height: 8,
              ),
              Text(
                _couponMessage!,
                style:
                    TextStyle(
                  color:
                      _discount > 0
                          ? Colors.green
                          : Colors.red,
                  fontWeight:
                      FontWeight.w500,
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
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            const Text(
              'Order Items',
              style:
                  TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            ...widget.items.map(
              (item) {
                return Padding(
                  padding:
                      const EdgeInsets
                          .only(
                    bottom: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration:
                            BoxDecoration(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            10,
                          ),
                          color: Colors
                              .grey
                              .shade200,
                        ),
                        child:
                            item.imageUrl !=
                                        null &&
                                    item.imageUrl!
                                        .isNotEmpty
                                ? ClipRRect(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      10,
                                    ),
                                    child:
                                        Image.network(
                                      item.imageUrl!,
                                      fit: BoxFit
                                          .cover,
                                      errorBuilder:
                                          (
                                        _,
                                        __,
                                        ___,
                                      ) {
                                        return const Icon(
                                          Icons
                                              .image_not_supported,
                                        );
                                      },
                                    ),
                                  )
                                : const Icon(
                                    Icons
                                        .shopping_bag,
                                  ),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 2,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),
                            const SizedBox(
                              height: 4,
                            ),
                            Text(
                              'Qty: ${item.quantity}',
                              style:
                                  const TextStyle(
                                color:
                                    Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '৳${item.total.toStringAsFixed(2)}',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
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
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryRow(
              'Subtotal',
              subtotal,
            ),
            const SizedBox(
              height: 8,
            ),
            _summaryRow(
              _hasDeliveryZone
                  ? 'Delivery Fee (${_isInsideDhaka ? 'Inside' : 'Outside'} Dhaka)'
                  : 'Delivery Fee',
              _deliveryFee,
            ),
            if (_discount > 0) ...[
              const SizedBox(
                height: 8,
              ),
              _summaryRow(
                'Discount',
                -_discount,
                color:
                    Colors.green,
              ),
            ],
            const Divider(
              height: 24,
            ),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
              children: [
                const Text(
                  'Grand Total',
                  style:
                      TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                Text(
                  '৳${grandTotal.toStringAsFixed(2)}',
                  style:
                      const TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
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
  // SUMMARY ROW
  // ============================================================

  Widget _summaryRow(
    String title,
    double value, {
    Color? color,
  }) {
    final prefix =
        value < 0 ? '- ' : '';

    return Row(
      mainAxisAlignment:
          MainAxisAlignment
              .spaceBetween,
      children: [
        Text(title),
        Text(
          '$prefix৳${value.abs().toStringAsFixed(2)}',
          style:
              TextStyle(
            color: color,
            fontWeight:
                color != null
                    ? FontWeight.w600
                    : null,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Checkout'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding:
              const EdgeInsets.all(12),
          children: [
            _buildAddressCard(),
            const SizedBox(
              height: 12,
            ),
            _buildOrderItems(),
            const SizedBox(
              height: 12,
            ),
            _buildCouponSection(),
            const SizedBox(
              height: 12,
            ),
            _buildPaymentSection(),
            const SizedBox(
              height: 12,
            ),
            _buildSummary(),
            const SizedBox(
              height: 20,
            ),
            SizedBox(
              height: 54,
              child:
                  ElevatedButton(
                onPressed:
                    _placingOrder
                        ? null
                        : _placeOrder,
                child:
                    _placingOrder
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2.5,
                              color:
                                  Colors.white,
                            ),
                          )
                        : Text(
                            _paymentMethod ==
                                    'BuyNova Wallet'
                                ? 'Pay ৳${grandTotal.toStringAsFixed(2)} with Wallet'
                                : 'Place Order',
                            style:
                                const TextStyle(
                              fontSize:
                                  16,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
              ),
            ),
            const SizedBox(
              height: 30,
            ),
          ],
        ),
      ),
    );
  }
}


