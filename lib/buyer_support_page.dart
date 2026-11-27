import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'return_refund_page.dart';

const String _kSupportEmail = 'miamdarif1234@gmail.com';

class BuyerSupportPage extends StatelessWidget {
  const BuyerSupportPage({super.key});

  Future<void> _emailSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _kSupportEmail,
      queryParameters: {'subject': 'BuyNova support'},
    );

    var opened = false;

    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }

    if (opened || !context.mounted) return;

    await Clipboard.setData(const ClipboardData(text: _kSupportEmail));

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email address copied: $_kSupportEmail'),
      ),
    );
  }

  void _showMessage(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
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

  Widget _supportItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.redAccent,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: const Icon(
          Icons.chevron_right,
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.redAccent,
                  Colors.red.shade700,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.support_agent,
                  color: Colors.white,
                  size: 42,
                ),
                SizedBox(height: 12),
                Text(
                  'How can we help you?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Find answers or contact BuyNova Support.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Support Categories',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          _supportItem(
            context: context,
            icon: Icons.help_outline,
            title: 'Frequently Asked Questions',
            subtitle: 'Find answers to common questions.',
            onTap: () {
              _showMessage(
                context,
                'FAQ',
                'Orders: open My Orders to see status.\n'
                'Password: Settings > Account & Security.\n'
                'More help: email $_kSupportEmail',
              );
            },
          ),

          _supportItem(
            context: context,
            icon: Icons.shopping_bag_outlined,
            title: 'Order Help',
            subtitle: 'Problems with your order?',
            onTap: () {
              _showMessage(
                context,
                'Order Help',
                'You can get help with order status, cancellation and order issues.',
              );
            },
          ),

          _supportItem(
            context: context,
            icon: Icons.payment_outlined,
            title: 'Payment Help',
            subtitle: 'Payment and transaction problems.',
            onTap: () {
              _showMessage(
                context,
                'Payment Help',
                'For a payment or wallet problem, email $_kSupportEmail with your transaction ID.',
              );
            },
          ),

          _supportItem(
            context: context,
            icon: Icons.local_shipping_outlined,
            title: 'Delivery Help',
            subtitle: 'Track or report a delivery problem.',
            onTap: () {
              _showMessage(
                context,
                'Delivery Help',
                'Open My Orders to track your delivery. If it is late, email $_kSupportEmail with your order ID.',
              );
            },
          ),

          // RETURN & REFUND
          _supportItem(
            context: context,
            icon: Icons.assignment_return_outlined,
            title: 'Return & Refund',
            subtitle: 'Request a return or refund.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReturnRefundPage(),
                ),
              );
            },
          ),

          _supportItem(
            context: context,
            icon: Icons.person_outline,
            title: 'Account Help',
            subtitle: 'Problems with your BuyNova account.',
            onTap: () {
              _showMessage(
                context,
                'Account Help',
                'For account problems, email $_kSupportEmail from the email address of your account.',
              );
            },
          ),

          const SizedBox(height: 14),

          const Text(
            'Contact Us',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          _supportItem(
            context: context,
            icon: Icons.chat_outlined,
            title: 'Contact BuyNova Support',
            subtitle: 'Send a message to our support team.',
            onTap: () {
              _emailSupport(context);
            },
          ),

          _supportItem(
            context: context,
            icon: Icons.email_outlined,
            title: 'Email Support',
            subtitle: 'Send us your question or problem.',
            onTap: () {
              _emailSupport(context);
            },
          ),

          const SizedBox(height: 20),

          Center(
            child: Text(
              'BuyNova Support',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
