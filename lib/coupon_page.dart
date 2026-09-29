import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CouponPage extends StatefulWidget {
  const CouponPage({super.key});

  @override
  State<CouponPage> createState() => _CouponPageState();
}

class _CouponPageState extends State<CouponPage> {
  final TextEditingController _codeController =
      TextEditingController();

  bool _checkingCode = false;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  // =========================================================
  // CHECK COUPON
  // =========================================================

  Future<void> _checkCoupon() async {
    final code =
        _codeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      _showMessage('Please enter a coupon code.');
      return;
    }

    setState(() {
      _checkingCode = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('coupons')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (!mounted) return;

      if (snapshot.docs.isEmpty) {
        _showCouponResult(
          title: 'Coupon Not Found',
          message:
              'This coupon code does not exist.',
          icon: Icons.error_outline,
          color: Colors.red,
        );
        return;
      }

      final document = snapshot.docs.first;
      final data = document.data();

      // =====================================================
      // ACTIVE CHECK
      // =====================================================

      final bool isActive =
          data['isActive'] == true;

      if (!isActive) {
        _showCouponResult(
          title: 'Coupon Inactive',
          message:
              'This coupon is no longer active.',
          icon: Icons.block_outlined,
          color: Colors.orange,
        );
        return;
      }

      // =====================================================
      // EXPIRATION CHECK
      // =====================================================

      final expiresAt =
          data['expiresAt'];

      final expiryDate =
          _getExpiryDate(expiresAt);

      if (expiryDate != null &&
          expiryDate.isBefore(DateTime.now())) {
        _showCouponResult(
          title: 'Coupon Expired',
          message:
              'This coupon has expired.',
          icon:
              Icons.event_busy_outlined,
          color: Colors.red,
        );
        return;
      }

      // =====================================================
      // COUPON VALUES
      // =====================================================

      final discountType =
          data['discountType']
                  ?.toString()
                  .toLowerCase()
                  .trim() ??
              'fixed';

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

      String discountText;

      if (discountType == 'percentage') {
        discountText =
            '${discountValue.toStringAsFixed(0)}% OFF';

        if (maximumDiscount > 0) {
          discountText +=
              ' • Up to ৳${maximumDiscount.toStringAsFixed(0)}';
        }
      } else {
        discountText =
            '৳${discountValue.toStringAsFixed(0)} OFF';
      }

      String minimumText = '';

      if (minimumOrder > 0) {
        minimumText =
            'Minimum order: ৳${minimumOrder.toStringAsFixed(0)}';
      }

      _showCouponResult(
        title: 'Coupon Available',
        message: minimumText.isEmpty
            ? discountText
            : '$discountText\n$minimumText',
        icon:
            Icons.local_offer_outlined,
        color: Colors.green,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Could not check coupon. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _checkingCode = false;
        });
      }
    }
  }

  // =========================================================
  // CONVERT NUMBER
  // =========================================================

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  // =========================================================
  // GET EXPIRATION DATE
  // =========================================================

  DateTime? _getExpiryDate(dynamic value) {
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

  // =========================================================
  // CHECK IF EXPIRED
  // =========================================================

  bool _isExpired(dynamic value) {
    final expiryDate =
        _getExpiryDate(value);

    if (expiryDate == null) {
      return false;
    }

    return expiryDate.isBefore(
      DateTime.now(),
    );
  }

  // =========================================================
  // COUPON RESULT
  // =========================================================

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
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Icon(
                icon,
                color: color,
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: Text(title),
              ),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child:
                  const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================
  // FORMAT EXPIRATION
  // =========================================================

  String _formatDate(dynamic value) {
    final date =
        _getExpiryDate(value);

    if (date == null) {
      return 'No expiry date';
    }

    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    final year =
        date.year.toString();

    return '$day/$month/$year';
  }

  // =========================================================
  // DISCOUNT TEXT
  // =========================================================

  String _discountText(
    Map<String, dynamic> data,
  ) {
    final type =
        data['discountType']
                ?.toString()
                .toLowerCase()
                .trim() ??
            'fixed';

    final value =
        _toDouble(
      data['discountValue'],
    );

    if (type == 'percentage') {
      return '${value.toStringAsFixed(0)}% OFF';
    }

    return '৳${value.toStringAsFixed(0)} OFF';
  }

  // =========================================================
  // COUPON CARD
  // =========================================================

  Widget _couponCard(
    QueryDocumentSnapshot<Map<String, dynamic>>
        document,
  ) {
    final data =
        document.data();

    final code =
        data['code']?.toString() ?? '';

    final minimumOrder =
        _toDouble(
      data['minimumOrder'],
    );

    final maximumDiscount =
        _toDouble(
      data['maximumDiscount'],
    );

    final expiresAt =
        data['expiresAt'];

    final bool firestoreActive =
        data['isActive'] == true;

    final bool expired =
        _isExpired(expiresAt);

    final bool available =
        firestoreActive && !expired;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      elevation: 1,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration:
                      BoxDecoration(
                    color: Colors.redAccent
                        .withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                  ),
                  child:
                      const Icon(
                    Icons
                        .local_offer_outlined,
                    color:
                        Colors.redAccent,
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
                        code,
                        style:
                            const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        _discountText(
                          data,
                        ),
                        style:
                            const TextStyle(
                          color:
                              Colors.redAccent,
                          fontSize: 15,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration:
                      BoxDecoration(
                    color: available
                        ? Colors.green
                            .withValues(
                            alpha: 0.10,
                          )
                        : Colors.red
                            .withValues(
                            alpha: 0.10,
                          ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      20,
                    ),
                  ),
                  child: Text(
                    available
                        ? 'Active'
                        : expired
                            ? 'Expired'
                            : 'Inactive',
                    style: TextStyle(
                      color: available
                          ? Colors.green
                          : Colors.red,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 14,
            ),

            if (minimumOrder > 0)
              _infoRow(
                Icons
                    .shopping_cart_outlined,
                'Minimum order',
                '৳${minimumOrder.toStringAsFixed(0)}',
              ),

            if (maximumDiscount > 0)
              _infoRow(
                Icons
                    .discount_outlined,
                'Maximum discount',
                '৳${maximumDiscount.toStringAsFixed(0)}',
              ),

            _infoRow(
              Icons
                  .event_outlined,
              'Valid until',
              _formatDate(
                expiresAt,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            SizedBox(
              width:
                  double.infinity,
              child:
                  OutlinedButton.icon(
                onPressed:
                    available
                        ? () {
                            _codeController
                                .text = code;

                            _showMessage(
                              'Coupon $code selected. You can apply it during checkout.',
                            );
                          }
                        : null,
                icon:
                    const Icon(
                  Icons
                      .content_copy_outlined,
                ),
                label:
                    Text(
                  expired
                      ? 'Coupon Expired'
                      : 'Use This Coupon',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // INFO ROW
  // =========================================================

  Widget _infoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 7,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color:
                Colors.grey.shade600,
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Text(
              title,
              style:
                  TextStyle(
                color:
                    Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style:
                const TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            Colors.redAccent,
        foregroundColor:
            Colors.white,
        title:
            const Text(
          'Coupons & Promo',
          style:
              TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),

      body: Column(
        children: [
          // ===================================================
          // ENTER CODE
          // ===================================================

          Container(
            width:
                double.infinity,
            padding:
                const EdgeInsets.all(
              16,
            ),
            decoration:
                const BoxDecoration(
              color:
                  Colors.white,
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black12,
                  blurRadius:
                      6,
                  offset:
                      Offset(0, 2),
                ),
              ],
            ),
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                const Text(
                  'Have a promo code?',
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
                      child:
                          TextField(
                        controller:
                            _codeController,
                        textCapitalization:
                            TextCapitalization
                                .characters,
                        decoration:
                            InputDecoration(
                          hintText:
                              'Enter coupon code',
                          prefixIcon:
                              const Icon(
                            Icons
                                .confirmation_number_outlined,
                          ),
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                          ),
                        ),
                        onSubmitted:
                            (_) =>
                                _checkCoupon(),
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    SizedBox(
                      height: 54,
                      child:
                          ElevatedButton(
                        onPressed:
                            _checkingCode
                                ? null
                                : _checkCoupon,
                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              Colors
                                  .redAccent,
                          foregroundColor:
                              Colors.white,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                          ),
                        ),
                        child:
                            _checkingCode
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2.5,
                                      color:
                                          Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Check',
                                  ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ===================================================
          // AVAILABLE COUPONS
          // ===================================================

          Expanded(
            child:
                StreamBuilder<
                    QuerySnapshot<
                        Map<String,
                            dynamic>>>(
              stream:
                  FirebaseFirestore
                      .instance
                      .collection(
                          'coupons')
                      .where(
                        'isActive',
                        isEqualTo:
                            true,
                      )
                      .snapshots(),

              builder:
                  (context, snapshot) {
                if (snapshot
                        .connectionState ==
                    ConnectionState
                        .waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(
                      color:
                          Colors.redAccent,
                    ),
                  );
                }

                if (snapshot
                    .hasError) {
                  return Center(
                    child:
                        Padding(
                      padding:
                          const EdgeInsets
                              .all(
                        24,
                      ),
                      child:
                          Column(
                        mainAxisSize:
                            MainAxisSize
                                .min,
                        children: [
                          const Icon(
                            Icons
                                .error_outline,
                            size: 45,
                            color:
                                Colors.grey,
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          const Text(
                            'Could not load coupons.',
                            textAlign:
                                TextAlign
                                    .center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final documents =
                    snapshot.data?.docs ??
                        [];

                // ------------------------------------------------
                // REMOVE EXPIRED COUPONS FROM AVAILABLE LIST
                // ------------------------------------------------

                final availableDocuments =
                    documents.where(
                  (document) {
                    final data =
                        document.data();

                    return !_isExpired(
                      data['expiresAt'],
                    );
                  },
                ).toList();

                if (availableDocuments
                    .isEmpty) {
                  return Center(
                    child:
                        Padding(
                      padding:
                          const EdgeInsets
                              .all(
                        24,
                      ),
                      child:
                          Column(
                        mainAxisSize:
                            MainAxisSize
                                .min,
                        children: [
                          Icon(
                            Icons
                                .local_offer_outlined,
                            size: 60,
                            color: Colors
                                .grey
                                .shade400,
                          ),
                          const SizedBox(
                            height: 12,
                          ),
                          const Text(
                            'No coupons available right now.',
                            textAlign:
                                TextAlign
                                    .center,
                            style:
                                TextStyle(
                              fontSize:
                                  16,
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                          const SizedBox(
                            height: 6,
                          ),
                          Text(
                            'New promotions will appear here.',
                            style:
                                TextStyle(
                              color: Colors
                                  .grey
                                  .shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final sorted =
                    [...availableDocuments];

                sorted.sort(
                  (a, b) {
                    final aData =
                        a.data();

                    final bData =
                        b.data();

                    final aDate =
                        aData[
                            'expiresAt'];

                    final bDate =
                        bData[
                            'expiresAt'];

                    if (aDate
                            is Timestamp &&
                        bDate
                            is Timestamp) {
                      return aDate
                          .compareTo(
                        bDate,
                      );
                    }

                    return 0;
                  },
                );

                return ListView(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    16,
                    16,
                    16,
                    30,
                  ),
                  children: [
                    const Text(
                      'Available Coupons',
                      style:
                          TextStyle(
                        fontSize:
                            20,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    ...sorted.map(
                      (document) =>
                          _couponCard(
                        document,
                      ),
                    ),
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
