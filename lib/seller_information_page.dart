import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SellerInformationPage extends StatelessWidget {
  /// If sellerId is provided, this page shows that seller's information.
  ///
  /// If sellerId is null, it shows the currently logged-in user's
  /// seller information exactly as before.
  final String? sellerId;

  const SellerInformationPage({
    super.key,
    this.sellerId,
  });

  // =========================================================
  // STATUS COLOR
  // =========================================================

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // =========================================================
  // INFORMATION CARD
  // =========================================================

  Widget _informationCard({
    required String title,
    required String value,
    required IconData icon,
    Color? iconColor,
  }) {
    final color = iconColor ?? Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: color,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value.isEmpty ? 'Not available' : value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
    final currentUser = FirebaseAuth.instance.currentUser;

    // If sellerId is provided, open that seller.
    // Otherwise, open the currently logged-in user's profile.
    final targetSellerId = sellerId?.trim().isNotEmpty == true
        ? sellerId!.trim()
        : currentUser?.uid;

    // No seller/user ID available.
    if (targetSellerId == null || targetSellerId.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF9F7),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Seller Information',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: const Center(
          child: Text(
            'Please login first.',
          ),
        ),
      );
    }

    final bool isOwnProfile =
        currentUser != null && targetSellerId == currentUser.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.black,
        ),
        title: Text(
          isOwnProfile ? 'Seller Information' : 'Seller Profile',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(targetSellerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load seller information.\n\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Seller information not found.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // FIXED:
          // snapshot.data is guaranteed to be non-null after
          // the hasData check above.
          final data = snapshot.data!.data() ?? {};

          final name = data['name']?.toString() ?? '';

          final phone = data['phone']?.toString() ?? '';

          final email = data['email']?.toString() ??
              (isOwnProfile ? currentUser?.email ?? '' : '');

          final sellerCode = data['sellerCode']?.toString() ?? '';

          final sellerStatus =
              data['sellerStatus']?.toString() ?? 'pending';

          final shopName = data['shopName']?.toString() ?? '';

          final profileImageUrl =
              data['profileImageUrl']?.toString().trim() ?? '';

          final statusColor = _statusColor(sellerStatus);

          return RefreshIndicator(
            onRefresh: () async {
              await Future<void>.delayed(
                const Duration(milliseconds: 300),
              );
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                // =================================================
                // SELLER HEADER
                // =================================================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // PROFILE IMAGE
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(
                            alpha: 0.10,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: profileImageUrl.isNotEmpty
                              ? Image.network(
                                  profileImageUrl,
                                  width: 78,
                                  height: 78,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.storefront,
                                      size: 40,
                                      color: Colors.redAccent,
                                    );
                                  },
                                )
                              : const Icon(
                                  Icons.storefront,
                                  size: 40,
                                  color: Colors.redAccent,
                                ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        name.isEmpty ? 'BuyNova Seller' : name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      if (shopName.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          shopName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],

                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          email,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // =================================================
                // SELLER DETAILS
                // =================================================

                const Text(
                  'Seller Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                _informationCard(
                  title: 'Seller ID',
                  value: sellerCode.isEmpty
                      ? 'Not assigned'
                      : sellerCode,
                  icon: Icons.badge_outlined,
                ),

                _informationCard(
                  title: 'Seller Name',
                  value: name,
                  icon: Icons.person_outline,
                ),

                if (email.isNotEmpty)
                  _informationCard(
                    title: 'Email',
                    value: email,
                    icon: Icons.email_outlined,
                  ),

                if (phone.isNotEmpty)
                  _informationCard(
                    title: 'Phone',
                    value: phone,
                    icon: Icons.phone_outlined,
                  ),

                if (shopName.isNotEmpty)
                  _informationCard(
                    title: 'Shop Name',
                    value: shopName,
                    icon: Icons.store_outlined,
                  ),

                // =================================================
                // SELLER STATUS
                // =================================================

                const SizedBox(height: 10),

                const Text(
                  'Seller Status',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: statusColor.withValues(
                        alpha: 0.30,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          sellerStatus.toLowerCase() == 'approved'
                              ? Icons.verified
                              : Icons.info_outline,
                          color: statusColor,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Status',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              sellerStatus.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // =================================================
                // ACCOUNT INFORMATION
                // =================================================

                // Keep Firebase UID visible only on the seller's
                // own information page. This prevents exposing the
                // Firebase UID when customers view another seller.
                if (isOwnProfile) ...[
                  const Text(
                    'Account Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  _informationCard(
                    title: 'Firebase Account ID',
                    value: currentUser.uid,
                    icon: Icons.fingerprint,
                  ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
