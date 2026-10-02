import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'available_products_page.dart';
import 'my_store_page.dart';
import 'reseller_orders_page.dart';
import 'my_profit_page.dart';
import 'news_feed_page.dart';

class EntrepreneurPage extends StatefulWidget {
  const EntrepreneurPage({super.key});

  @override
  State<EntrepreneurPage> createState() =>
      _EntrepreneurPageState();
}

class _EntrepreneurPageState
    extends State<EntrepreneurPage> {
  bool _loading = true;

  String _status = 'none';
  String _entrepreneurCode = '';

  User? get currentUser =>
      FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadEntrepreneurData();
  }

  // =========================================================
  // LOAD ENTREPRENEUR DATA
  // =========================================================

  Future<void> _loadEntrepreneurData() async {
    final user = currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};

        if (mounted) {
          setState(() {
            _status =
                data['entrepreneurStatus']?.toString() ??
                    'none';

            _entrepreneurCode =
                data['entrepreneurCode']?.toString() ??
                    '';
          });
        }
      }
    } catch (e) {
      debugPrint(
        'Entrepreneur loading error: $e',
      );
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  // =========================================================
  // MY STORE
  // =========================================================

  Future<void> _openMyStore() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const MyStorePage(),
      ),
    );
  }

  // =========================================================
  // AVAILABLE PRODUCTS
  // =========================================================

  Future<void> _openAvailableProducts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const AvailableProductsPage(),
      ),
    );
  }

  // =========================================================
  // RESELLER ORDERS
  // =========================================================

  Future<void> _openResellerOrders() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const ResellerOrdersPage(),
      ),
    );
  }

  // =========================================================
  // VIDEOS
  // =========================================================

  Future<void> _openVideos() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const NewsFeedPage(),
      ),
    );
  }

  // =========================================================
  // MY PROFIT
  // =========================================================

  Future<void> _openMyProfit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const MyProfitPage(),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          const Color(0xFFFFF9F7),
      appBar: AppBar(
        title: const Text(
          'Entrepreneur / Reseller',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor:
            Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh:
            _loadEntrepreneurData,
        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _headerCard(),

              const SizedBox(
                height: 18,
              ),

              if (_status ==
                  'approved') ...[
                _approvedSection(),
              ] else if (_status ==
                  'pending') ...[
                _pendingSection(),
              ] else if (_status ==
                  'rejected') ...[
                _rejectedSection(),
              ] else ...[
                _notRegisteredSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _headerCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.04,
            ),
            blurRadius: 12,
            offset:
                const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color:
                  Colors.redAccent.withValues(
                alpha: 0.10,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.business_center_outlined,
              size: 40,
              color: Colors.redAccent,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          const Text(
            'Entrepreneur / Reseller',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            'Find products from BuyNova sellers, '
            'set your own selling price and earn profit.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // NOT REGISTERED
  // =========================================================

  Widget _notRegisteredSection() {
    return _ResellerMembershipCard(
      onSuccess: _loadEntrepreneurData,
    );
  }

  // =========================================================
  // PENDING
  // =========================================================

  Widget _pendingSection() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
            Colors.orange.shade50,
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color:
                  Colors.orange.withValues(
                alpha: 0.12,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_top,
              color:
                  Colors.orange,
              size: 28,
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Request Pending',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                SizedBox(
                  height: 5,
                ),

                Text(
                  'Your Entrepreneur / Reseller '
                  'request is waiting for admin approval.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // REJECTED
  // =========================================================

  Widget _rejectedSection() {
    return _ResellerMembershipCard(
      onSuccess: _loadEntrepreneurData,
      rejected: true,
    );
  }

  // =========================================================
  // APPROVED
  // =========================================================

  Widget _approvedSection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        // =====================================================
        // APPROVED STATUS BOX
        // =====================================================

        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color:
                Colors.green.shade50,
            borderRadius:
                BorderRadius.circular(16),
            border: Border.all(
              color:
                  Colors.green.withValues(
                alpha: 0.20,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color:
                      Colors.green.withValues(
                    alpha: 0.12,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color:
                      Colors.green,
                  size: 30,
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Entrepreneur Approved',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    if (_entrepreneurCode
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        'Entrepreneur ID: '
                        '$_entrepreneurCode',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],

                    const SizedBox(
                      height: 4,
                    ),

                    const Text(
                      'Your reseller account is active.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 22,
        ),

        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        // =====================================================
        // OVERVIEW BOXES
        // =====================================================

        Row(
          children: [
            Expanded(
              child: _overviewBox(
                icon:
                    Icons.store_outlined,
                title:
                    'My Store',
                subtitle:
                    'Manage store',
                onTap:
                    _openMyStore,
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child: _overviewBox(
                icon:
                    Icons.search_outlined,
                title:
                    'Find Products',
                subtitle:
                    'Browse products',
                onTap:
                    _openAvailableProducts,
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 12,
        ),

        Row(
          children: [
            Expanded(
              child: _overviewBox(
                icon:
                    Icons.shopping_bag_outlined,
                title:
                    'Orders',
                subtitle:
                    'Reseller orders',
                onTap:
                    _openResellerOrders,
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child: _overviewBox(
                icon:
                    Icons.account_balance_wallet_outlined,
                title:
                    'My Profit',
                subtitle:
                    'Track profit',
                onTap:
                    _openMyProfit,
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 24,
        ),

        const Text(
          'Business Management',
          style: TextStyle(
            fontSize: 20,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        // =====================================================
        // LARGE BUSINESS BOXES
        // =====================================================

        _businessBox(
          icon:
              Icons.store_outlined,
          title:
              'My Store',
          subtitle:
              'Manage products you want to resell.',
          onTap:
              _openMyStore,
        ),

        _businessBox(
          icon:
              Icons.add_business_outlined,
          title:
              'Find Products',
          subtitle:
              'Browse products from BuyNova sellers.',
          onTap:
              _openAvailableProducts,
        ),

        _businessBox(
          icon:
              Icons.video_library_outlined,
          title:
              'Videos',
          subtitle:
              'Watch, upload and manage your BuyNova videos.',
          onTap:
              _openVideos,
        ),

        _businessBox(
          icon:
              Icons.shopping_bag_outlined,
          title:
              'Reseller Orders',
          subtitle:
              'Manage orders from your customers.',
          onTap:
              _openResellerOrders,
        ),

        _businessBox(
          icon:
              Icons.account_balance_wallet_outlined,
          title:
              'My Profit',
          subtitle:
              'Track your reseller profit.',
          onTap:
              _openMyProfit,
        ),
      ],
    );
  }

  // =========================================================
  // OVERVIEW BOX
  // =========================================================

  Widget _overviewBox({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius:
          BorderRadius.circular(16),
      onTap:
          onTap,
      child: Container(
        padding:
            const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              Colors.white,
          borderRadius:
              BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(
                alpha: 0.04,
              ),
              blurRadius:
                  10,
              offset:
                  const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color:
                    Colors.redAccent.withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                color:
                    Colors.redAccent,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            Text(
              title,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 15,
              ),
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              subtitle,
              style:
                  TextStyle(
                color:
                    Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // LARGE BUSINESS BOX
  // =========================================================

  Widget _businessBox({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.04,
            ),
            blurRadius:
                10,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color:
            Colors.transparent,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(16),
          onTap:
              onTap,
          child: Padding(
            padding:
                const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color:
                        Colors.redAccent.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                  child: Icon(
                    icon,
                    color:
                        Colors.redAccent,
                    size: 28,
                  ),
                ),

                const SizedBox(
                  width: 14,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                            const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        subtitle,
                        style:
                            TextStyle(
                          color:
                              Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        Colors.grey.shade100,
                    shape:
                        BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// RESELLER MEMBERSHIP CARD
// =====================================================================

class _ResellerMembershipCard
    extends StatefulWidget {
  final VoidCallback onSuccess;
  final bool rejected;

  const _ResellerMembershipCard({
    required this.onSuccess,
    this.rejected = false,
  });

  @override
  State<_ResellerMembershipCard> createState() =>
      _ResellerMembershipCardState();
}

class _ResellerMembershipCardState
    extends State<_ResellerMembershipCard> {
  final FirebaseFirestore _db =
      FirebaseFirestore.instance;

  bool _processing = false;

  double _resellerFee = 1000.0;

  bool _freeCampaignEnabled = false;

  DateTime? _campaignStart;
  DateTime? _campaignEnd;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // =========================================================
  // LOAD MONETIZATION SETTINGS
  // =========================================================

  Future<void> _loadSettings() async {
    try {
      final snapshot = await _db
          .collection('platformSettings')
          .doc('monetization')
          .get();

      if (!mounted) return;

      final data = snapshot.data();

      if (data == null) {
        return;
      }

      setState(() {
        _resellerFee =
            _toDouble(
                  data['resellerMembershipFee'],
                ) ??
                1000.0;

        _freeCampaignEnabled =
            data['freeCampaignEnabled'] == true;

        _campaignStart =
            _toDateTime(
          data['freeCampaignStart'],
        );

        _campaignEnd =
            _toDateTime(
          data['freeCampaignEnd'],
        );
      });
    } catch (e) {
      debugPrint(
        'Reseller membership settings error: $e',
      );
    }
  }

  // =========================================================
  // NUMBER CONVERSION
  // =========================================================

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    );
  }

  // =========================================================
  // DATE CONVERSION
  // =========================================================

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  // =========================================================
  // FREE CAMPAIGN
  // =========================================================

  bool _isFreeCampaignActive() {
    if (!_freeCampaignEnabled) {
      return false;
    }

    final now = DateTime.now();

    if (_campaignStart != null &&
        now.isBefore(_campaignStart!)) {
      return false;
    }

    if (_campaignEnd != null &&
        now.isAfter(_campaignEnd!)) {
      return false;
    }

    return true;
  }

  // =========================================================
  // MONEY FORMAT
  // =========================================================

  String _formatMoney(double amount) {
    if (amount == amount.roundToDouble()) {
      return '৳${amount.toStringAsFixed(0)}';
    }

    return '৳${amount.toStringAsFixed(2)}';
  }

  // =========================================================
  // DATE FORMAT
  // =========================================================

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Not set';
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
  // PAY RESELLER MEMBERSHIP
  // =========================================================

  Future<void> _payMembership() async {
    if (_processing) {
      return;
    }

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Please login first.',
        isError: true,
      );
      return;
    }

    final freeCampaign =
        _isFreeCampaignActive();

    final double displayedFee =
        freeCampaign
            ? 0.0
            : _resellerFee;

    final confirmed =
        await _showPaymentConfirmation(
      displayedFee,
      freeCampaign,
    );

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _processing = true;
    });

    try {
      final functions =
          FirebaseFunctions.instanceFor(
        region:
            'asia-northeast3',
      );

      final callable =
          functions.httpsCallable(
        'payMembershipRegistrationFee',
      );

      // IMPORTANT:
      // The Cloud Function decides the actual
      // reseller fee and free campaign status.
      //
      // The client does NOT send the fee.
      final result =
          await callable.call({
        'role': 'reseller',
      });

      if (!mounted) return;

      final raw =
          result.data is Map
              ? Map<String, dynamic>.from(
                  result.data as Map,
                )
              : <String, dynamic>{};

      final success =
          raw['success'] == true;

      final free =
          raw['freeCampaign'] == true;

      final amount =
          _toDouble(
                raw['amount'],
              ) ??
              0.0;

      final newBalance =
          _toDouble(
        raw['newBalance'],
      );

      if (success) {
        String message;

        if (free || amount <= 0.0) {
          message =
              'Free Entrepreneur / Reseller membership request submitted successfully.';
        } else if (newBalance != null) {
          message =
              'Reseller membership payment successful.\n'
              'Paid: ${_formatMoney(amount)}\n'
              'Wallet balance: ${_formatMoney(newBalance)}';
        } else {
          message =
              'Reseller membership payment successful.';
        }

        _showSuccessDialog(
          message,
        );
      } else {
        _showMessage(
          'Membership payment could not be completed.',
          isError: true,
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      String message =
          e.message ??
              'Membership payment failed.';

      switch (e.code) {
        case 'failed-precondition':
          message =
              e.message ??
                  'Your Entrepreneur / Reseller membership request cannot be processed right now.';
          break;

        case 'permission-denied':
          message =
              e.message ??
                  'You do not have permission to complete this payment.';
          break;

        case 'unauthenticated':
          message =
              'Please login again and try.';
          break;

        case 'resource-exhausted':
          message =
              e.message ??
                  'Your wallet balance is not enough.';
          break;

        case 'invalid-argument':
          message =
              e.message ??
                  'Invalid membership request.';
          break;

        case 'already-exists':
          message =
              e.message ??
                  'A membership request already exists.';
          break;

        case 'not-found':
          message =
              e.message ??
                  'Membership settings were not found.';
          break;
      }

      _showMessage(
        message,
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Something went wrong.\n$e',
        isError: true,
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
  // CONFIRM PAYMENT
  // =========================================================

  Future<bool> _showPaymentConfirmation(
    double displayedFee,
    bool freeCampaign,
  ) async {
    final result =
        await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Entrepreneur / Reseller Membership',
          ),
          content: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              if (freeCampaign) ...[
                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.all(12),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.green.withValues(
                      alpha: 0.08,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child:
                      const Row(
                    children: [
                      Icon(
                        Icons.local_offer,
                        color:
                            Colors.green,
                      ),
                      SizedBox(
                        width: 8,
                      ),
                      Expanded(
                        child:
                            Text(
                          'Free membership campaign is active.',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.w600,
                            color:
                                Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 14,
                ),
              ],

              const Text(
                'Reseller Membership Fee',
                style:
                    TextStyle(
                  fontSize: 13,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                freeCampaign
                    ? 'FREE'
                    : _formatMoney(
                        displayedFee,
                      ),
                style:
                    TextStyle(
                  fontSize: 26,
                  fontWeight:
                      FontWeight.bold,
                  color: freeCampaign
                      ? Colors.green
                      : Colors.redAccent,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              Text(
                freeCampaign
                    ? 'Your Entrepreneur / Reseller registration request will be submitted without a membership fee.'
                    : 'The membership fee will be deducted from your BuyNova Wallet.',
                style:
                    TextStyle(
                  color:
                      Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text(
                'Cancel',
              ),
            ),

            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.redAccent,
                foregroundColor:
                    Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
                  Text(
                freeCampaign
                    ? 'Continue'
                    : 'Pay & Apply',
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  // =========================================================
  // SUCCESS DIALOG
  // =========================================================

  void _showSuccessDialog(
    String message,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible:
          false,
      builder:
          (dialogContext) {
        return AlertDialog(
          icon:
              const Icon(
            Icons.check_circle,
            color:
                Colors.green,
            size: 52,
          ),

          title:
              const Text(
            'Request Submitted',
          ),

          content:
              Text(
            message,
            textAlign:
                TextAlign.center,
          ),

          actions: [
            SizedBox(
              width:
                  double.infinity,
              child:
                  ElevatedButton(
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.redAccent,
                  foregroundColor:
                      Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                  );

                  widget.onSuccess();
                },
                child:
                    const Text(
                  'Done',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor:
              isError
                  ? Colors.red.shade700
                  : Colors.green.shade700,
          content:
              Text(message),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final freeCampaign =
        _isFreeCampaignActive();

    final double displayedFee =
        freeCampaign
            ? 0.0
            : _resellerFee;

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border:
            Border.all(
          color:
              Colors.redAccent.withValues(
            alpha: 0.18,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.04,
            ),
            blurRadius:
                10,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width:
                    52,
                height:
                    52,
                decoration:
                    BoxDecoration(
                  color:
                      Colors.redAccent.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child:
                    const Icon(
                  Icons.business_center_outlined,
                  color:
                      Colors.redAccent,
                  size:
                      28,
                ),
              ),

              const SizedBox(
                width:
                    14,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.rejected
                          ? 'Request Again'
                          : 'Become an Entrepreneur',
                      style:
                          const TextStyle(
                        fontSize:
                            17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height:
                          4,
                    ),

                    const Text(
                      'Register your BuyNova Reseller membership.',
                      style:
                          TextStyle(
                        fontSize:
                            13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                18,
          ),

          // =====================================================
          // FEE
          // =====================================================

          Container(
            width:
                double.infinity,
            padding:
                const EdgeInsets.all(16),
            decoration:
                BoxDecoration(
              color:
                  freeCampaign
                      ? Colors.green.withValues(
                          alpha: 0.08,
                        )
                      : Colors.redAccent.withValues(
                          alpha: 0.06,
                        ),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child:
                Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  color:
                      Colors.redAccent,
                ),

                const SizedBox(
                  width:
                      12,
                ),

                Expanded(
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Membership Fee',
                        style:
                            TextStyle(
                          fontSize:
                              12,
                          color:
                              Colors.grey,
                        ),
                      ),

                      const SizedBox(
                        height:
                            3,
                      ),

                      Text(
                        freeCampaign
                            ? 'FREE'
                            : _formatMoney(
                                displayedFee,
                              ),
                        style:
                            TextStyle(
                          fontSize:
                              22,
                          fontWeight:
                              FontWeight.bold,
                          color:
                              freeCampaign
                                  ? Colors.green
                                  : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),

                if (freeCampaign)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal:
                          10,
                      vertical:
                          6,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.green,
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                    child:
                        const Text(
                      'FREE',
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize:
                            11,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(
            height:
                10,
          ),

          // =====================================================
          // CAMPAIGN INFO
          // =====================================================

          if (_freeCampaignEnabled)
            Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets.all(12),
              decoration:
                  BoxDecoration(
                color:
                    Colors.blue.withValues(
                  alpha: 0.06,
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child:
                  Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color:
                        Colors.blue,
                    size:
                        20,
                  ),

                  const SizedBox(
                    width:
                        8,
                  ),

                  Expanded(
                    child:
                        Text(
                      freeCampaign
                          ? 'Free membership campaign is active now.'
                          : 'Free membership campaign is not active right now.',
                      style:
                          TextStyle(
                        fontSize:
                            12,
                        color:
                            Colors.grey.shade700,
                        height:
                            1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_freeCampaignEnabled)
            const SizedBox(
              height:
                  10,
            ),

          // =====================================================
          // PAYMENT BUTTON
          // =====================================================

          SizedBox(
            width:
                double.infinity,
            height:
                50,
            child:
                ElevatedButton.icon(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.redAccent,
                foregroundColor:
                    Colors.white,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
              onPressed:
                  _processing
                      ? null
                      : _payMembership,
              icon:
                  _processing
                      ? const SizedBox(
                          width:
                              18,
                          height:
                              18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                            color:
                                Colors.white,
                          ),
                        )
                      : Icon(
                          freeCampaign
                              ? Icons
                                  .how_to_reg_outlined
                              : Icons
                                  .account_balance_wallet_outlined,
                        ),
              label:
                  Text(
                _processing
                    ? 'Processing...'
                    : freeCampaign
                        ? 'Apply as Reseller'
                        : 'Pay & Apply as Reseller',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(
            height:
                8,
          ),

          Text(
            freeCampaign
                ? 'Your request will be processed through BuyNova.'
                : 'Payment is securely processed through your BuyNova Wallet.',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              fontSize:
                  11,
              color:
                  Colors.grey.shade600,
            ),
          ),

          if (_campaignStart != null ||
              _campaignEnd != null) ...[
            const SizedBox(
              height:
                  10,
            ),
            Text(
              'Campaign: '
              '${_formatDate(_campaignStart)}'
              ' → '
              '${_formatDate(_campaignEnd)}',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize:
                    11,
                color:
                    Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
