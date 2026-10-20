part of 'admin_panel_page.dart';

// ================================================================
// ADMIN ORDER MODEL
// ================================================================

class _AdminOrderItem {
  final String id;
  final Map<String, dynamic> data;
  final String type;
  final String collection;

  const _AdminOrderItem({
    required this.id,
    required this.data,
    required this.type,
    required this.collection,
  });
}

// ================================================================
// REUSABLE ADMIN SECTION PAGE
// ================================================================

class _AdminSectionPage extends StatelessWidget {
  final String title;

  final Stream<QuerySnapshot<Map<String, dynamic>>>?
      notificationStream;

  final String notificationLabel;

  final Widget child;

  const _AdminSectionPage({
    required this.title,
    required this.child,
    this.notificationStream,
    this.notificationLabel = 'Items',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          if (notificationStream != null)
            _notificationCard(context),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _notificationCard(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: notificationStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(
              12,
              12,
              12,
              6,
            ),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.notifications_outlined,
                  color: Colors.orange,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Notification count unavailable.',
                  ),
                ),
              ],
            ),
          );
        }

        final count = snapshot.data?.docs.length ?? 0;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(
            12,
            12,
            12,
            6,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '🔔 $count $notificationLabel',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
