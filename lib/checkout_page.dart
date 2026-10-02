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

  // Wallet remains disabled until the Cloud Functions
  // payment flow is deployed and tested.
  static const bool _walletEnabled = false;

  static const String _functionsRegion = 'asia-northeast3';

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _couponController =
      TextEditingController();

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

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(
        region: _functionsRegion,
      );

  // ============================================================
  // DELIVERY
  // ============================================================

  String get _deliveryZone =>
      _selectedAddress?['deliveryZone']?.toString() ?? '';

  bool get _hasDeliveryZone =>
      _deliveryZone == 'inside_dhaka' ||
      _deliveryZone == 'outside_dhaka';

  bool get _isInsideDhaka {
    final address = _selectedAddress;

    if (address == null) {
      return false;
    }

    if (_deliveryZone == 'inside_dhaka') {
      return true;
    }

    if (_deliveryZone == 'outside_dhaka') {
      return false;
    }

    final text =
        '${address['city'] ?? ''} '
        '${address['district'] ?? ''}'
            .toLowerCase();

    return text.contains('dhaka') ||
        text.contains('ঢাকা');
  }

  double get _deliveryFee {
    if (_selectedAddress == null) {
      return 60;
    }

    return _isInsideDhaka ? 60 : 120;
  }

  double get subtotal {
    return widget.items.fold<double>(
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
  // MONEY
  // ============================================================

  double _roundMoney(double value) {
    return double.parse(
      value.toStringAsFixed(2),
    );
  }

  // ============================================================
  // COUPON ALLOCATION
  // ============================================================

  double _discountForGroup({
    required double groupSubtotal,
    required double remainingDiscount,
    required int groupIndex,
    required int totalGroups,
  }) {
    if (_discount <= 0 ||
        subtotal <= 0 ||
        groupSubtotal <= 0 ||
        totalGroups <= 0) {
      return 0;
    }

    if (groupIndex == totalGroups - 1) {
      return _roundMoney(
        remainingDiscount.clamp(
          0,
          _discount,
        ),
      );
    }

    final proportional =
        _discount *
        (groupSubtotal / subtotal);

    final rounded =
        _roundMoney(proportional);

    return _roundMoney(
      rounded.clamp(
        0,
        remainingDiscount,
      ),
    );
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
  // SAVED COUPON
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

      await prefs.remove(_pendingCouponKey);

      if (!mounted) return;

      setState(() {
        _couponController.text =
            savedCode.trim().toUpperCase();
      });

      await _checkCoupon(
        showMessage: true,
      );
    } catch (_) {
      // Saved coupon is optional.
    }
  }

  // ============================================================
  // WALLET
  // ============================================================

  Future<void> _loadWalletBalance() async {
    if (!_walletEnabled) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _loadingWalletBalance = true;
    });

    try {
      final user = _auth.currentUser;

      if (user == null) {
        return;
      }

      final result =
          await _functions
              .httpsCallable(
                'getWalletBalance',
              )
              .call();

      if (result.data is! Map) {
        throw Exception(
          'Invalid wallet response.',
        );
      }

      final data =
          Map<String, dynamic>.from(
        result.data as Map,
      );

      final dynamic balanceValue =
          data['balance'] ??
          data['cashBalance'] ??
          0;

      final double balance =
          balanceValue is num
              ? balanceValue.toDouble()
              : double.tryParse(
                    balanceValue.toString(),
                  ) ??
                  0;

      if (!mounted) return;

      setState(() {
        _walletBalance = balance;
      });
    } catch (e) {
      debugPrint(
        'Wallet balance error: $e',
      );

      if (!mounted) return;

      setState(() {
        _walletBalance = 0;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingWalletBalance = false;
        });
      }
    }
  }

  bool get _walletHasEnoughBalance {
    return _walletBalance >= grandTotal;
  }

  Future<bool> _validateWalletBeforeOrder() async {
    await _loadWalletBalance();

    if (_walletHasEnoughBalance) {
      return true;
    }

    if (!mounted) {
      return false;
    }

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    return false;
  }

  // ============================================================
  // ADDRESS
  // ============================================================

  Future<void> _loadDefaultAddress() async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final addressesRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('addresses');

      final defaultSnapshot = await addressesRef
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
          await addressesRef.limit(1).get();

      if (anySnapshot.docs.isNotEmpty) {
        if (!mounted) return;

        setState(() {
          _selectedAddress =
              anySnapshot.docs.first.data();
        });

        return;
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final address =
          userDoc.data()?['address'];

      if (address is Map) {
        if (!mounted) return;

        setState(() {
          _selectedAddress =
              Map<String, dynamic>.from(
            address,
          );
        });
      }
    } catch (e) {
      debugPrint(
        'Load address error: $e',
      );
    }
  }

  // FIX #1/#2:
  // Keep the method private and use the same name everywhere.
  Future<void> _openAddressBook() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        // FIX: MaterialPageRoute.builder requires BuildContext.
        builder: (_) => const AddressBookPage(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDefaultAddress();
  }

  // ============================================================
  // CUSTOMER DELIVERY DATA
  // ============================================================

  Map<String, dynamic> _customerDeliveryData(
    User user,
  ) {
    final address =
        _selectedAddress == null
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(
                _selectedAddress!,
              );

    final String name =
        address['name']?.toString() ?? '';

    final String phone =
        address['phone']?.toString() ?? '';

    final String email =
        user.email ?? '';

    final String addressText =
        address['address']?.toString() ??
        address['addressLine1']?.toString() ??
        '';

    final String city =
        address['city']?.toString() ?? '';

    final String district =
        address['district']?.toString() ?? '';

    final String postalCode =
        address['postalCode']?.toString() ??
        address['zipCode']?.toString() ??
        '';

    return {
      'customerName': name,
      'customerPhone': phone,
      'customerEmail': email,

      'address': addressText,
      'city': city,
      'district': district,
      'postalCode': postalCode,

      'deliveryZone': _deliveryZone,

      'deliveryAddress': address,

      'customerAddress': address,
    };
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

  DateTime? _couponExpiry(
    dynamic value,
  ) {
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

  void _resetCoupon(
    String? message,
  ) {
    if (!mounted) {
      return;
    }

    setState(() {
      _discount = 0;
      _couponCode = null;
      _couponMessage = message;
    });
  }

  // ============================================================
  // CHECK COUPON
  // ============================================================

  Future<bool> _checkCoupon({
    bool showMessage = true,
  }) async {
    final code =
        _couponController.text
            .trim()
            .toUpperCase();

    if (code.isEmpty) {
      if (showMessage) {
        _resetCoupon(
          'Please enter a coupon code.',
        );
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
      final snapshot = await _firestore
          .collection('coupons')
          .where(
            'code',
            isEqualTo: code,
          )
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        _resetCoupon(
          'Invalid coupon code.',
        );
        return false;
      }

      final data =
          snapshot.docs.first.data();

      if (data['isActive'] != true) {
        _resetCoupon(
          'This coupon is not active.',
        );
        return false;
      }

      final expiresAt =
          _couponExpiry(
        data['expiresAt'],
      );

      if (expiresAt != null &&
          expiresAt.isBefore(
            DateTime.now(),
          )) {
        _resetCoupon(
          'This coupon has expired.',
        );
        return false;
      }

      final double usageLimit =
          _toDouble(
        data['usageLimit'],
      );

      final double usedCount =
          _toDouble(
        data['usedCount'],
      );

      if (usageLimit > 0 &&
          usedCount >= usageLimit) {
        _resetCoupon(
          'This coupon has reached its usage limit.',
        );

        return false;
      }

      final String discountType =
          (data['discountType'] ?? 'fixed')
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

      if (minimumOrder > 0 &&
          subtotal < minimumOrder) {
        _resetCoupon(
          'Minimum order amount is '
          '৳${minimumOrder.toStringAsFixed(2)}.',
        );

        return false;
      }

      double calculatedDiscount;

      if (discountType == 'percentage') {
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

      if (calculatedDiscount > subtotal) {
        calculatedDiscount = subtotal;
      }

      calculatedDiscount =
          _roundMoney(
        calculatedDiscount,
      );

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
      debugPrint(
        'Coupon validation error: $e',
      );

      _resetCoupon(
        'Could not validate coupon. Please try again.',
      );

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
  // SELLER LOOKUP
  // ============================================================

  Future<String> _findSellerId(
    CheckoutItem item,
  ) async {
    final existingSellerId =
        item.sellerId;

    if (existingSellerId != null &&
        existingSellerId.trim().isNotEmpty) {
      return existingSellerId.trim();
    }

    for (final collection in const [
      'products',
      'Products',
    ]) {
      try {
        final doc = await _firestore
            .collection(collection)
            .doc(item.id)
            .get();

        if (!doc.exists) {
          continue;
        }

        final data = doc.data();

        if (data == null) {
          continue;
        }

        final sellerId =
            data['sellerId']?.toString();

        if (sellerId != null &&
            sellerId.trim().isNotEmpty) {
          return sellerId.trim();
        }

        final ownerId =
            data['ownerId']?.toString();

        if (ownerId != null &&
            ownerId.trim().isNotEmpty) {
          return ownerId.trim();
        }
      } catch (e) {
        debugPrint(
          'Seller lookup error '
          '($collection/${item.id}): $e',
        );
      }
    }

    return 'unknown_seller';
  }

  // ============================================================
  // SELLER ORDER ITEM
  // ============================================================

  Map<String, dynamic> _sellerOrderItem(
    CheckoutItem item,
  ) {
    return {
      'productId': item.id,
      'name': item.name,
      'price': item.price,
      'quantity': item.quantity,
      'total': item.total,
      'imageUrl': item.imageUrl,
    };
  }

  // ============================================================
  // RESELLER ORDER ITEM
  // ============================================================

  Map<String, dynamic> _resellerOrderItem(
    CheckoutItem item,
  ) {
    return {
      'productId': item.id,
      'name': item.name,
      'price': item.price,
      'quantity': item.quantity,
      'total': item.total,
      'imageUrl': item.imageUrl,
      'supplierProductId':
          item.supplierProductId,
      'supplierPrice':
          item.supplierPrice,
      'resellerProfit':
          item.resellerProfit,
    };
  }

  // ============================================================
  // PLACE ORDER
  // ============================================================

  Future<void> _placeOrder() async {
    if (_placingOrder) {
      return;
    }

    final user = _auth.currentUser;

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

    if (!_formKey.currentState!.validate()) {
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
      // ========================================================
      // REVALIDATE COUPON
      // ========================================================

      if (_couponController.text
          .trim()
          .isNotEmpty) {
        final couponValid =
            await _checkCoupon();

        if (!couponValid) {
          return;
        }
      } else {
        _resetCoupon(null);
      }

      // ========================================================
      // PAYMENT
      // ========================================================

      final bool isWallet =
          _walletEnabled &&
          _paymentMethod ==
              'BuyNova Wallet';

      if (isWallet) {
        final enough =
            await _validateWalletBeforeOrder();

        if (!enough) {
          return;
        }
      }

      // ========================================================
      // CUSTOMER DELIVERY DATA
      // ========================================================

      final customerDeliveryData =
          _customerDeliveryData(user);

      // ========================================================
      // MAIN ORDER
      // ========================================================

      final orderRef =
          _firestore
              .collection('orders')
              .doc();

      final orderId =
          orderRef.id;

      final List<
          Map<String, dynamic>> orderItems =
          widget.items.map(
        (item) {
          return {
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
            'sellerId':
                item.sellerId,
            'supplierProductId':
                item.supplierProductId,
            'supplierPrice':
                item.supplierPrice,
            'resellerProfit':
                item.resellerProfit,
          };
        },
      ).toList();

      final Map<String, dynamic> orderData = {
        'orderId': orderId,

        'userId': user.uid,
        'customerId': user.uid,

        'items': orderItems,

        'subtotal': subtotal,
        'deliveryFee': _deliveryFee,
        'deliveryZone': _deliveryZone,

        'discount': _discount,
        'couponDiscount': _discount,

        'total': grandTotal,
        'grandTotal': grandTotal,

        'currency': 'BDT',
        'currencySymbol': '৳',

        'couponCode': _couponCode,

        'paymentMethod': _paymentMethod,
        'paymentStatus': 'pending',

        'orderStatus': 'placed',

        ...customerDeliveryData,

        'address': _selectedAddress,

        'createdAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      };

      // ========================================================
      // NORMAL SELLER GROUPS
      // ========================================================

      final Map<String, List<CheckoutItem>>
          sellerGroups = {};

      for (final item in widget.items) {
        if (item.isResellerProduct) {
          continue;
        }

        final sellerId =
            await _findSellerId(item);

        sellerGroups
            .putIfAbsent(
              sellerId,
              () => <CheckoutItem>[],
            )
            .add(item);
      }

      // ========================================================
      // RESELLER GROUPS
      // ========================================================

      final Map<String, List<CheckoutItem>>
          resellerGroups = {};

      for (final item in widget.items) {
        if (!item.isResellerProduct) {
          continue;
        }

        final entrepreneurUid =
            (item.entrepreneurUid == null ||
                    item.entrepreneurUid!
                        .trim()
                        .isEmpty)
                ? user.uid
                : item.entrepreneurUid!
                    .trim();

        final sellerId =
            (item.sellerId == null ||
                    item.sellerId!
                        .trim()
                        .isEmpty)
                ? 'unknown_seller'
                : item.sellerId!
                    .trim();

        final groupKey =
            '${entrepreneurUid}__${sellerId}';

        resellerGroups
            .putIfAbsent(
              groupKey,
              () => <CheckoutItem>[],
            )
            .add(item);
      }

      // ========================================================
      // DISCOUNT ALLOCATION
      // ========================================================

      final int totalGroups =
          sellerGroups.length +
          resellerGroups.length;

      int discountGroupIndex = 0;

      double remainingDiscount =
          _discount;

      // ========================================================
      // BATCH
      // ========================================================

      final WriteBatch batch =
          _firestore.batch();

      // ========================================================
      // MAIN ORDER
      // ========================================================

      batch.set(
        orderRef,
        orderData,
      );

      // ========================================================
      // SELLER ORDERS
      // ========================================================

      for (final entry
          in sellerGroups.entries) {
        final items =
            entry.value;

        if (items.isEmpty) {
          continue;
        }

        final double sellerSubtotal =
            items.fold<double>(
          0,
          (sum, item) =>
              sum + item.total,
        );

        final double sellerCouponDiscount =
            _discountForGroup(
          groupSubtotal:
              sellerSubtotal,
          remainingDiscount:
              remainingDiscount,
          groupIndex:
              discountGroupIndex,
          totalGroups:
              totalGroups,
        );

        remainingDiscount =
            _roundMoney(
          remainingDiscount -
              sellerCouponDiscount,
        );

        discountGroupIndex++;

        final double netSellerEarnings =
            _roundMoney(
          sellerSubtotal -
              sellerCouponDiscount,
        );

        final sellerOrderRef =
            _firestore
                .collection('seller_orders')
                .doc();

        batch.set(
          sellerOrderRef,
          {
            'orderId': orderId,
            'sellerOrderId':
                sellerOrderRef.id,

            'sellerId': entry.key,

            'buyerId': user.uid,
            'customerId': user.uid,
            'userId': user.uid,

            // ==================================================
            // CUSTOMER DELIVERY DETAILS
            // ==================================================

            'customerName':
                customerDeliveryData[
                    'customerName'],

            'customerPhone':
                customerDeliveryData[
                    'customerPhone'],

            'customerEmail':
                customerDeliveryData[
                    'customerEmail'],

            'address':
                customerDeliveryData[
                    'address'],

            'city':
                customerDeliveryData[
                    'city'],

            'district':
                customerDeliveryData[
                    'district'],

            'postalCode':
                customerDeliveryData[
                    'postalCode'],

            'deliveryZone':
                _deliveryZone,

            'deliveryAddress':
                _selectedAddress,

            'customerAddress':
                _selectedAddress,

            'items': items
                .map(
                  _sellerOrderItem,
                )
                .toList(),

            'subtotal':
                sellerSubtotal,

            'couponCode':
                _couponCode,

            'couponDiscount':
                sellerCouponDiscount,

            'netSellerEarnings':
                netSellerEarnings,

            'currency': 'BDT',
            'currencySymbol': '৳',

            'paymentMethod':
                _paymentMethod,

            'paymentStatus':
                'pending',

            'orderStatus':
                'placed',

            'createdAt':
                FieldValue.serverTimestamp(),

            'updatedAt':
                FieldValue.serverTimestamp(),
          },
        );
      }

      // ========================================================
      // RESELLER ORDERS
      // ========================================================

      for (final entry
          in resellerGroups.entries) {
        final items =
            entry.value;

        if (items.isEmpty) {
          continue;
        }

        final entrepreneurUid =
            (items.first.entrepreneurUid == null ||
                    items.first.entrepreneurUid!
                        .trim()
                        .isEmpty)
                ? user.uid
                : items.first.entrepreneurUid!
                    .trim();

        final sellerId =
            (items.first.sellerId == null ||
                    items.first.sellerId!
                        .trim()
                        .isEmpty)
                ? 'unknown_seller'
                : items.first.sellerId!
                    .trim();

        final double sellingTotal =
            items.fold<double>(
          0,
          (sum, item) =>
              sum + item.total,
        );

        final double supplierTotal =
            items.fold<double>(
          0,
          (sum, item) =>
              sum +
              ((item.supplierPrice ?? 0) *
                  item.quantity),
        );

        // ======================================================
        // RESELLER COUPON SHARE
        // ======================================================

        final double resellerCouponDiscount =
            _discountForGroup(
          groupSubtotal:
              sellingTotal,
          remainingDiscount:
              remainingDiscount,
          groupIndex:
              discountGroupIndex,
          totalGroups:
              totalGroups,
        );

        remainingDiscount =
            _roundMoney(
          remainingDiscount -
              resellerCouponDiscount,
        );

        discountGroupIndex++;

        // ======================================================
        // NET SELLING TOTAL
        // ======================================================

        final double netSellingTotal =
            _roundMoney(
          sellingTotal -
              resellerCouponDiscount,
        );

        // ======================================================
        // FINAL RESELLER PROFIT
        // ======================================================
        //
        // Selling Total
        // - Coupon Discount
        // - Supplier Cost
        // = Reseller Profit
        //

        final double resellerProfit =
            _roundMoney(
          sellingTotal -
              resellerCouponDiscount -
              supplierTotal,
        );

        final resellerOrderRef =
            _firestore
                .collection('reseller_orders')
                .doc();

        batch.set(
          resellerOrderRef,
          {
            'orderId': orderId,

            'resellerOrderId':
                resellerOrderRef.id,

            'entrepreneurUid':
                entrepreneurUid,

            'sellerId':
                sellerId,

            'buyerId':
                user.uid,

            'customerId':
                user.uid,

            'userId':
                user.uid,

            // ==================================================
            // CUSTOMER INFORMATION
            // ==================================================

            'customerName':
                customerDeliveryData[
                    'customerName'],

            'customerPhone':
                customerDeliveryData[
                    'customerPhone'],

            'customerEmail':
                customerDeliveryData[
                    'customerEmail'],

            'address':
                customerDeliveryData[
                    'address'],

            'city':
                customerDeliveryData[
                    'city'],

            'district':
                customerDeliveryData[
                    'district'],

            'postalCode':
                customerDeliveryData[
                    'postalCode'],

            'deliveryZone':
                _deliveryZone,

            'deliveryAddress':
                _selectedAddress,

            'customerAddress':
                _selectedAddress,

            'items': items
                .map(
                  _resellerOrderItem,
                )
                .toList(),

            'sellingTotal':
                sellingTotal,

            'couponCode':
                _couponCode,

            'couponDiscount':
                resellerCouponDiscount,

            'netSellingTotal':
                netSellingTotal,

            'supplierTotal':
                supplierTotal,

            'resellerProfit':
                resellerProfit,

            // Compatibility with older UI/code.
            'profit':
                resellerProfit,

            'currency': 'BDT',
            'currencySymbol': '৳',

            'paymentMethod':
                _paymentMethod,

            'paymentStatus':
                'pending',

            'orderStatus':
                'placed',

            'createdAt':
                FieldValue.serverTimestamp(),

            'updatedAt':
                FieldValue.serverTimestamp(),
          },
        );
      }

      // ========================================================
      // COMMIT
      // ========================================================

      await batch.commit();

      // ========================================================
      // WALLET PAYMENT
      // ========================================================

      if (isWallet) {
        final result =
            await _functions
                .httpsCallable(
                  'placeWalletOrder',
                )
                .call({
          'orderId': orderId,
        });

        if (result.data is! Map) {
          throw Exception(
            'Invalid wallet payment response.',
          );
        }

        final resultData =
            Map<String, dynamic>.from(
          result.data as Map,
        );

        final bool success =
            resultData['success'] == true ||
            resultData['alreadyPaid'] == true;

        if (!success) {
          throw Exception(
            'Wallet payment could not be completed.',
          );
        }
      }

      // ========================================================
      // CLEAR CART
      // ========================================================

      if (widget.clearCartOnSuccess) {
        await _clearCart(
          user.uid,
        );
      }

      if (!mounted) {
        return;
      }

      // ========================================================
      // SUCCESS
      // ========================================================

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                ),
                SizedBox(width: 10),
                Text('Order Placed'),
              ],
            ),
            content: Text(
              isWallet
                  ? 'Your order has been placed and paid '
                      'successfully using BuyNova Wallet.'
                  : 'Your order has been placed successfully.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child:
                    const Text('Continue'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const MyOrdersPage(),
        ),
      );
    } catch (e) {
      debugPrint(
        'Place order error: $e',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            _friendlyError(e),
          ),
          duration:
              const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _placingOrder = false;
        });
      }
    }
  }

  // ============================================================
  // FRIENDLY ERROR
  // ============================================================

  String _friendlyError(
    Object error,
  ) {
    final text =
        error.toString().toLowerCase();

    if (text.contains('permission-denied') ||
        text.contains(
          'missing or insufficient permissions',
        )) {
      return 'Order could not be saved because permission '
          'was denied. Please check your account permissions '
          'and try again.';
    }

    if (text.contains('insufficient wallet') ||
        text.contains('wallet balance')) {
      return 'Your BuyNova Wallet balance is not enough '
          'for this order.';
    }

    if (text.contains('unauthenticated')) {
      return 'Please login again.';
    }

    if (text.contains('network') ||
        text.contains('unavailable')) {
      return 'Network problem. Please check your internet '
          'connection and try again.';
    }

    if (text.contains('not-found')) {
      return 'Order or Wallet service was not found.';
    }

    if (text.contains('failed-precondition')) {
      return 'This order could not be completed right now. '
          'Please try again.';
    }

    return 'Something went wrong while placing the order. '
        'Please try again.';
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
    } catch (e) {
      debugPrint(
        'Clear cart error: $e',
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
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
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Delivery Address',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed:
                      _openAddressBook,
                  child: Text(
                    _selectedAddress == null
                        ? 'Add'
                        : 'Change',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedAddress == null)
              const Text(
                'No delivery address selected.',
                style: TextStyle(
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

  Widget _buildAddressText() {
    final address =
        _selectedAddress!;

    final name =
        address['name']?.toString() ?? '';

    final phone =
        address['phone']?.toString() ?? '';

    final line1 =
        address['address']?.toString() ??
        address['addressLine1']?.toString() ??
        '';

    final city =
        address['city']?.toString() ?? '';

    final postalCode =
        address['postalCode']?.toString() ??
        address['zipCode']?.toString() ??
        '';

    final zoneText =
        _deliveryZone == 'inside_dhaka'
            ? 'Inside Dhaka'
            : _deliveryZone == 'outside_dhaka'
                ? 'Outside Dhaka'
                : '';

    Widget line(String text) {
      return Padding(
        padding:
            const EdgeInsets.only(top: 3),
        child: Text(text),
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
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
          line(phone),
        if (line1.isNotEmpty)
          line(line1),
        if (city.isNotEmpty ||
            postalCode.isNotEmpty)
          line(
            '$city '
            '${postalCode.isNotEmpty ? postalCode : ''}'
                .trim(),
          ),
        Padding(
          padding:
              const EdgeInsets.only(top: 3),
          child: Text(
            zoneText.isEmpty
                ? 'Delivery area not set. Tap Change, '
                    'then edit this address and choose '
                    'Inside/Outside Dhaka.'
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
  // PAYMENT
  // ============================================================

  Widget _buildPaymentSection() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
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
                  const RadioListTile<String>(
                    value:
                        'Cash on Delivery',
                    title: Text(
                      'Cash on Delivery',
                    ),
                    subtitle: Text(
                      'Pay when your order arrives.',
                    ),
                    secondary: Icon(
                      Icons.local_shipping,
                    ),
                  ),
                  if (_walletEnabled)
                    RadioListTile<String>(
                      value:
                          'BuyNova Wallet',
                      title: const Text(
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
                                        FontWeight.w600,
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
            if (_walletEnabled &&
                _paymentMethod ==
                    'BuyNova Wallet') ...[
              const SizedBox(height: 6),
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.all(12),
                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(12),
                  color:
                      (_walletHasEnoughBalance
                              ? Colors.green
                              : Colors.red)
                          .withValues(
                    alpha: 0.08,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _walletHasEnoughBalance
                          ? Icons.check_circle
                          : Icons.warning,
                      color:
                          _walletHasEnoughBalance
                              ? Colors.green
                              : Colors.red,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _walletHasEnoughBalance
                            ? 'Wallet balance is enough for this order.'
                            : 'Insufficient Wallet balance. '
                                'Please add money before paying.',
                        style: TextStyle(
                          color:
                              _walletHasEnoughBalance
                                  ? Colors.green
                                  : Colors.red,
                          fontWeight:
                              FontWeight.w600,
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
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Coupon',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
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
                    // FIX #4:
                    // onSubmitted requires ValueChanged<String>.
                    onSubmitted:
                        (value) {
                      if (!_checkingCoupon) {
                        _checkCoupon();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
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
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Apply',
                            ),
                ),
              ],
            ),
            if (_couponMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _couponMessage!,
                style: TextStyle(
                  color: _discount > 0
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
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Items',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...widget.items.map(
              (item) {
                final hasImage =
                    item.imageUrl != null &&
                    item.imageUrl!.isNotEmpty;

                return Padding(
                  padding:
                      const EdgeInsets.only(
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
                              BorderRadius.circular(
                            10,
                          ),
                          color:
                              Colors.grey.shade200,
                        ),
                        child: hasImage
                            ? ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(
                                  10,
                                ),
                                child:
                                    Image.network(
                                  item.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (
                                    context,
                                    error,
                                    stackTrace,
                                  ) {
                                    return const Icon(
                                      Icons
                                          .image_not_supported,
                                    );
                                  },
                                ),
                              )
                            : const Icon(
                                Icons.shopping_bag,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 2,
                              overflow:
                                  TextOverflow.ellipsis,
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Qty: ${item.quantity}',
                              style:
                                  const TextStyle(
                                color: Colors.grey,
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
            const SizedBox(height: 8),
            _summaryRow(
              _hasDeliveryZone
                  ? 'Delivery Fee '
                      '(${_isInsideDhaka ? 'Inside' : 'Outside'} Dhaka)'
                  : 'Delivery Fee',
              _deliveryFee,
            ),
            if (_discount > 0) ...[
              const SizedBox(height: 8),
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
                  MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Grand Total',
                  style: TextStyle(
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

  Widget _summaryRow(
    String title,
    double value, {
    Color? color,
  }) {
    final prefix =
        value < 0 ? '- ' : '';

    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(title),
        Text(
          '$prefix৳${value.abs().toStringAsFixed(2)}',
          style: TextStyle(
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
    final bool walletSelected =
        _walletEnabled &&
        _paymentMethod ==
            'BuyNova Wallet';

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
                onPressed:
                    _placingOrder
                        ? null
                        : _placeOrder,
                child: _placingOrder
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        walletSelected
                            ? 'Pay '
                                '৳${grandTotal.toStringAsFixed(2)} '
                                'with Wallet'
                            : 'Place Order',
                        style:
                            const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
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
