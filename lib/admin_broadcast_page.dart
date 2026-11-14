import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

/// Admin: send a notice to ALL users.
///
/// - Shows in every user's Notifications page (bell icon on Home).
/// - Also arrives as a phone push (functions/push.js ->
///   onGlobalNotificationCreatedPush).
/// - "App update" can carry a link (for example the Play Store page).
class AdminBroadcastPage extends StatefulWidget {
  const AdminBroadcastPage({super.key});

  @override
  State<AdminBroadcastPage> createState() => _AdminBroadcastPageState();
}

class _AdminBroadcastPageState extends State<AdminBroadcastPage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _message = TextEditingController();
  final TextEditingController _image = TextEditingController();
  final TextEditingController _link = TextEditingController();

  final FirebaseFunctions _fn =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  String _kind = 'announcement';
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _image.dispose();
    _link.dispose();
    super.dispose();
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red : null,
        ),
      );
  }

  Future<void> _send() async {
    if (_sending) return;

    final title = _title.text.trim();
    final message = _message.text.trim();
    final image = _image.text.trim();
    final link = _link.text.trim();

    if (title.isEmpty || message.isEmpty) {
      _snack('Title and message are required.', error: true);
      return;
    }

    if (image.isNotEmpty && !image.startsWith('https://')) {
      _snack('Image link must start with https://', error: true);
      return;
    }

    if (link.isNotEmpty && !link.startsWith('https://')) {
      _snack('Link must start with https://', error: true);
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send to ALL users?'),
        content: Text('"$title"\n\n$message'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _sending = true);

    try {
      await _fn.httpsCallable('sendAdminNotice').call({
        'title': title,
        'message': message,
        'kind': _kind,
        'imageUrl': image,
        'link': link,
      });

      if (!mounted) return;

      _title.clear();
      _message.clear();
      _image.clear();
      _link.clear();

      _snack('Notice sent to all users.');
    } on FirebaseFunctionsException catch (e) {
      _snack(e.message ?? 'Could not send the notice.', error: true);
    } catch (e) {
      _snack('Could not send the notice: $e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _remove(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('global_notifications')
          .doc(id)
          .update({'active': false, 'isActive': false});

      _snack('Notice removed from all users.');
    } catch (e) {
      _snack('Could not remove: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Send a notice to all users',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Users get a phone notification and it also appears in the '
            'bell icon on Home.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'announcement',
                label: Text('Notice'),
                icon: Icon(Icons.campaign_outlined),
              ),
              ButtonSegment(
                value: 'app_update',
                label: Text('App update'),
                icon: Icon(Icons.system_update_outlined),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: _sending
                ? null
                : (value) => setState(() => _kind = value.first),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            enabled: !_sending,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _message,
            enabled: !_sending,
            maxLength: 500,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Message',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _link,
            enabled: !_sending,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: _kind == 'app_update'
                  ? 'Update link (Play Store) - optional'
                  : 'Link - optional',
              hintText: 'https://...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _image,
            enabled: !_sending,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Image link - optional',
              hintText: 'https://...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_sending ? 'Sending...' : 'Send to all users'),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Recent notices',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('global_notifications')
                .where('active', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = (snapshot.data?.docs ?? [])
                  .where((d) {
                    final type = d.data()['type']?.toString() ?? '';
                    return type == 'announcement' || type == 'app_update';
                  })
                  .toList();

              docs.sort((a, b) {
                final at = a.data()['createdAt'];
                final bt = b.data()['createdAt'];

                final am = at is Timestamp ? at.millisecondsSinceEpoch : 0;
                final bm = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;

                return bm.compareTo(am);
              });

              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No active notices.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                );
              }

              return Column(
                children: [
                  for (final d in docs.take(20))
                    Card(
                      elevation: 0,
                      child: ListTile(
                        leading: Icon(
                          d.data()['type'] == 'app_update'
                              ? Icons.system_update_outlined
                              : Icons.campaign_outlined,
                        ),
                        title: Text(
                          d.data()['title']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          d.data()['message']?.toString() ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove for everyone',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _remove(d.id),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
