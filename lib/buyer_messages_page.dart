import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'buyer_chat_page.dart';
import 'seller_chat_page.dart';

class BuyerMessagesPage extends StatefulWidget {
  const BuyerMessagesPage({super.key});

  @override
  State<BuyerMessagesPage> createState() => _BuyerMessagesPageState();
}

class _BuyerMessagesPageState extends State<BuyerMessagesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get _userId => _auth.currentUser?.uid;

  Stream<QuerySnapshot<Map<String, dynamic>>> _conversationStream() {
    final userId = _userId;

    if (userId == null) {
      return const Stream.empty();
    }

    // Show every conversation where the current user is
    // either participant.
    return _firestore
        .collection('conversations')
        .where(
          Filter.or(
            Filter('buyerId', isEqualTo: userId),
            Filter('sellerId', isEqualTo: userId),
          ),
        )
        .snapshots();
  }

  bool _isBuyerSide(Map<String, dynamic> data) {
    return data['buyerId'] == _userId;
  }

  int _unreadCount(Map<String, dynamic> data) {
    final value = _isBuyerSide(data)
        ? data['buyerUnreadCount']
        : data['sellerUnreadCount'];

    if (value is int) {
      return value < 0 ? 0 : value;
    }

    if (value is num) {
      final count = value.toInt();
      return count < 0 ? 0 : count;
    }

    return 0;
  }

  String _otherUserName(Map<String, dynamic> data) {
    if (_isBuyerSide(data)) {
      final name = data['sellerName'];

      if (name is String && name.trim().isNotEmpty) {
        return name.trim();
      }

      return 'Seller';
    }

    final name = data['buyerName'];

    if (name is String && name.trim().isNotEmpty) {
      return name.trim();
    }

    return 'User';
  }

  
    if (_isBuyerSide(data)) {
      final id = data['sellerId'];

      if (id is String) {
        return id.trim();
      }

      return '';
    }

    final id = data['buyerId'];

    if (id is String) {
      return id.trim();
    }

    return '';
  }

  String _lastMessage(Map<String, dynamic> data) {
    final message = data['lastMessage'];

    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    return 'Start a conversation';
  }

  String _conversationId(
    Map<String, dynamic> data,
    String fallbackId,
  ) {
    final value = data['conversationId'];

    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return fallbackId;
  }

  DateTime? _lastMessageDate(
    Map<String, dynamic> data,
  ) {
    final value = data['lastMessageAt'];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String _formatTime(dynamic value) {
    if (value is! Timestamp) {
      return '';
    }

    final date = value.toDate();
    final now = DateTime.now();

    final isToday =
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    if (isToday) {
      final hour = date.hour == 0
          ? 12
          : date.hour > 12
              ? date.hour - 12
              : date.hour;

      final minute =
          date.minute.toString().padLeft(2, '0');

      final period =
          date.hour >= 12 ? 'PM' : 'AM';

      return '$hour:$minute $period';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  void _openChat({
    required String conversationId,
    required Map<String, dynamic> data,
  }) {
    final currentUserId = _userId;

    if (currentUserId == null) {
      return;
    }

    final isBuyerSide = data['buyerId'] == currentUserId;

    if (isBuyerSide) {
      final sellerId = data['sellerId'];

      if (sellerId is! String ||
          sellerId.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Recipient information is missing.',
            ),
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BuyerChatPage(
            conversationId: conversationId,
            sellerId: sellerId.trim(),
            sellerName: _otherUserName(data),
          ),
        ),
      );
    } else {
      final buyerId = data['buyerId'];

      if (buyerId is! String ||
          buyerId.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Recipient information is missing.',
            ),
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SellerChatPage(
            conversationId: conversationId,
            buyerId: buyerId.trim(),
            buyerName: _otherUserName(data),
          ),
        ),
      );
    }
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(
                  alpha: 0.10,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 44,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Messages Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your conversations will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conversationTile(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final unread = _unreadCount(data);
    final otherName = _otherUserName(data);
    final lastMessage = _lastMessage(data);
    final time = _formatTime(
      data['lastMessageAt'],
    );

    final conversationId = _conversationId(
      data,
      documentId,
    );

    return Card(
      margin: const EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 10,
      ),
      elevation: 1,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(
                  alpha: 0.10,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: Colors.redAccent,
                size: 27,
              ),
            ),
            if (unread > 0)
              Positioned(
                right: -3,
                top: -3,
                child: Container(
                  constraints:
                      const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    unread > 99
                        ? '99+'
                        : unread.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                otherName,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: unread > 0
                      ? FontWeight.bold
                      : FontWeight.w600,
                ),
              ),
            ),
            if (time.isNotEmpty)
              Text(
                time,
                style: TextStyle(
                  color: unread > 0
                      ? Colors.redAccent
                      : Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: unread > 0
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding:
              const EdgeInsets.only(top: 5),
          child: Text(
            lastMessage,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: TextStyle(
              color: unread > 0
                  ? Colors.black87
                  : Colors.grey.shade600,
              fontWeight: unread > 0
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
        ),
        onTap: () {
          _openChat(
            conversationId: conversationId,
            data: data,
          );
        },
      ),
    );
  }

  List<QueryDocumentSnapshot<
      Map<String, dynamic>>> _sortedDocuments(
    List<QueryDocumentSnapshot<
            Map<String, dynamic>>>
        documents,
  ) {
    final sorted =
        List<QueryDocumentSnapshot<
            Map<String, dynamic>>>.from(
      documents,
    );

    sorted.sort((a, b) {
      final dateA =
          _lastMessageDate(a.data());
      final dateB =
          _lastMessageDate(b.data());

      if (dateA == null && dateB == null) {
        return 0;
      }

      if (dateA == null) return 1;
      if (dateB == null) return -1;

      return dateB.compareTo(dateA);
    });

    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Messages'),
          centerTitle: true,
        ),
        body: const Center(
          child: Text(
            'Please login to view your messages.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        centerTitle: true,
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _conversationStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Unable to load messages.',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your connection and try again.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final documents =
              _sortedDocuments(
            snapshot.data?.docs ?? [],
          );

          if (documents.isEmpty) {
            return _emptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              await Future<void>.delayed(
                const Duration(
                  milliseconds: 400,
                ),
              );
            },
            child: ListView.builder(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.only(
                top: 16,
                bottom: 24,
              ),
              itemCount: documents.length,
              itemBuilder:
                  (context, index) {
                final document =
                    documents[index];

                return _conversationTile(
                  document.id,
                  document.data(),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
