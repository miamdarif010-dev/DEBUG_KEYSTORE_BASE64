import 'package:flutter/material.dart';

import 'favorites_page.dart';
import 'cart_page.dart';
import 'my_orders_page.dart';
import 'buyer_support_page.dart';
import 'notifications_page.dart';
import 'buyer_messages_page.dart';
import 'my_videos_page.dart';

class BuyerPage extends StatelessWidget {
  const BuyerPage({super.key});

  // =========================================================
  // OPEN VIDEOS
  // =========================================================

  void _openVideos(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MyVideosPage(),
      ),
    );
  }

  // =========================================================
  // OPEN PAGE
  // =========================================================

  void _openPage(
    BuildContext context,
    Widget page,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Buyer',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =================================================
            // HEADER
            // =================================================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(
                        alpha: 0.10,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      size: 34,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Buyer Account',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Shop products, manage orders and '
                          'enjoy BuyNova services.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // =================================================
            // FOUR QUICK BOXES
            // =================================================

            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.35,
              children: [
                _quickBox(
                  icon: Icons.receipt_long_outlined,
                  title: 'My Orders',
                  onTap: () {
                    _openPage(
                      context,
                      const MyOrdersPage(),
                    );
                  },
                ),
                _quickBox(
                  icon: Icons.favorite_border,
                  title: 'Favorites',
                  onTap: () {
                    _openPage(
                      context,
                      const FavoritesPage(),
                    );
                  },
                ),
                _quickBox(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Cart',
                  onTap: () {
                    _openPage(
                      context,
                      const CartPage(),
                    );
                  },
                ),
                _quickBox(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  onTap: () {
                    _openPage(
                      context,
                      const NotificationsPage(),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // =================================================
            // SHOPPING
            // =================================================

            const Text(
              'Shopping',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            _largeBox(
              icon: Icons.message_outlined,
              title: 'Messages',
              subtitle:
                  'Chat with sellers and manage conversations.',
              onTap: () {
                _openPage(
                  context,
                  const BuyerMessagesPage(),
                );
              },
            ),

            _largeBox(
              icon: Icons.video_library_outlined,
              title: 'Videos',
              subtitle:
                  'Watch, upload and manage your BuyNova videos.',
              onTap: () {
                _openVideos(context);
              },
            ),

            const SizedBox(height: 18),

            // =================================================
            // SUPPORT
            // =================================================

            const Text(
              'Support',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            _largeBox(
              icon: Icons.support_agent_outlined,
              title: 'Help & Support',
              subtitle:
                  'Get help with your BuyNova account and orders.',
              onTap: () {
                _openPage(
                  context,
                  const BuyerSupportPage(),
                );
              },
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // QUICK BOX
  // =========================================================

  Widget _quickBox({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 9),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // LARGE BOX
  // =========================================================

  Widget _largeBox({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.redAccent,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
