import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BuyerChatPage extends StatefulWidget {
  final String conversationId;
  final String sellerId;
  final String sellerName;

  // true হলে recipient-কে Reseller হিসেবে দেখাবে।
  // Default false রাখায় পুরোনো navigation-ও কাজ করবে।
  final bool isReseller;

  const BuyerChatPage({
    super.key,
    required this.conversationId,
    required this.sellerId,
    required this.sellerName,
    this.isReseller = false,
  });

  @override
  State<BuyerChatPage> createState() => _BuyerChatPageState();
}

class _BuyerChatPageState extends State<BuyerChatPage> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final TextEditingController _messageController =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  bool _sending = false;
  bool _conversationReady = false;

  String _buyerName = 'Buyer';

  User? get _user => _auth.currentUser;

  String get _buyerId => _user?.uid ?? '';

  DocumentReference<Map<String, dynamic>>
      get _conversationRef {
    return _firestore
        .collection('conversations')
        .doc(widget.conversationId);
  }

  CollectionReference<Map<String, dynamic>>
      get _messagesRef {
    return _conversationRef.collection('messages');
  }

  String get _recipientType {
    return widget.isReseller ? 'Reseller' : 'Seller';
  }

  @override
  void initState() {
    super.initState();
    _ensureConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // =========================================================
  // GET BUYER NAME
  // =========================================================

  Future<String> _getBuyerName() async {
    if (_buyerId.isEmpty) {
      return 'Buyer';
    }

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(_buyerId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();

        final name = data?['name'];

        if (name is String &&
            name.trim().isNotEmpty) {
          return name.trim();
        }

        final displayName =
            data?['displayName'];

        if (displayName is String &&
            displayName.trim().isNotEmpty) {
          return displayName.trim();
        }
      }
    } catch (_) {
      // Continue with Firebase Auth fallback.
    }

    final authName = _user?.displayName;

    if (authName != null &&
        authName.trim().isNotEmpty) {
      return authName.trim();
    }

    return 'Buyer';
  }

  // =========================================================
  // CREATE / UPDATE CONVERSATION
  // =========================================================

  Future<void> _ensureConversation() async {
    if (_buyerId.isEmpty) {
      return;
    }

    try {
      final buyerName =
          await _getBuyerName();

      if (mounted) {
        setState(() {
          _buyerName = buyerName;
        });
      }

      final conversationSnapshot =
          await _conversationRef.get();

      if (!conversationSnapshot.exists) {
        await _conversationRef.set({
          'conversationId':
              widget.conversationId,
          'buyerId': _buyerId,
          'buyerName': buyerName,
          'sellerId': widget.sellerId,
          'sellerName': widget.sellerName,
          'lastMessage': '',
          'lastMessageAt':
              FieldValue.serverTimestamp(),
          'buyerUnreadCount': 0,
          'sellerUnreadCount': 0,
          'createdAt':
              FieldValue.serverTimestamp(),
          'updatedAt':
              FieldValue.serverTimestamp(),
        });
      } else {
        final existingData =
            conversationSnapshot.data();

        final existingBuyerName =
            existingData?['buyerName'];

        final existingSellerName =
            existingData?['sellerName'];

        // Keep the existing conversation structure.
        // Only refresh names if necessary.
        if (existingBuyerName != buyerName ||
            existingSellerName !=
                widget.sellerName) {
          await _conversationRef.update({
            'buyerName': buyerName,
            'sellerName': widget.sellerName,
            'updatedAt':
                FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted) {
        setState(() {
          _conversationReady = true;
        });
      }

      await _markMessagesAsRead();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _conversationReady = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open chat: $e',
          ),
        ),
      );
    }
  }

  // =========================================================
  // MARK RECEIVED MESSAGES AS READ
  // =========================================================

  Future<void> _markMessagesAsRead() async {
    if (_buyerId.isEmpty) {
      return;
    }

    try {
      final snapshot = await _messagesRef
          .where(
            'receiverId',
            isEqualTo: _buyerId,
          )
          .where(
            'isRead',
            isEqualTo: false,
          )
          .get();

      if (snapshot.docs.isNotEmpty) {
        final batch =
            _firestore.batch();

        for (final doc in snapshot.docs) {
          batch.update(
            doc.reference,
            {
              'isRead': true,
              'readAt':
                  FieldValue.serverTimestamp(),
            },
          );
        }

        batch.update(
          _conversationRef,
          {
            'buyerUnreadCount': 0,
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
        );

        await batch.commit();
      } else {
        await _conversationRef.set(
          {
            'buyerUnreadCount': 0,
          },
          SetOptions(merge: true),
        );
      }
    } catch (_) {
      // Do not interrupt chat if read status update fails.
    }
  }

  // =========================================================
  // SEND MESSAGE
  // =========================================================

  Future<void> _sendMessage() async {
    if (_buyerId.isEmpty) {
      return;
    }

    final message =
        _messageController.text.trim();

    if (message.isEmpty || _sending) {
      return;
    }

    if (!_conversationReady) {
      await _ensureConversation();

      if (!_conversationReady) {
        return;
      }
    }

    if (!mounted) return;

    setState(() {
      _sending = true;
    });

    try {
      final messageRef =
          _messagesRef.doc();

      final batch =
          _firestore.batch();

      // -----------------------------------------------------
      // CREATE MESSAGE
      // -----------------------------------------------------

      batch.set(
        messageRef,
        {
          'senderId': _buyerId,
          'receiverId': widget.sellerId,
          'message': message,
          'isRead': false,
          'createdAt':
              FieldValue.serverTimestamp(),
        },
      );

      // -----------------------------------------------------
      // UPDATE CONVERSATION
      // -----------------------------------------------------

      batch.update(
        _conversationRef,
        {
          'buyerId': _buyerId,
          'buyerName': _buyerName,
          'sellerId': widget.sellerId,
          'sellerName': widget.sellerName,
          'lastMessage': message,
          'lastMessageAt':
              FieldValue.serverTimestamp(),
          'sellerUnreadCount':
              FieldValue.increment(1),
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      _messageController.clear();

      await Future.delayed(
        const Duration(milliseconds: 150),
      );

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Message could not be sent: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  // =========================================================
  // SCROLL TO BOTTOM
  // =========================================================

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }

    _scrollController.animateTo(
      0,
      duration:
          const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // =========================================================
  // FORMAT TIME
  // =========================================================

  String _formatTime(
    Timestamp? timestamp,
  ) {
    if (timestamp == null) {
      return '';
    }

    final date =
        timestamp.toDate();

    final hour = date.hour > 12
        ? date.hour - 12
        : date.hour == 0
            ? 12
            : date.hour;

    final minute =
        date.minute
            .toString()
            .padLeft(2, '0');

    final period =
        date.hour >= 12
            ? 'PM'
            : 'AM';

    return '$hour:$minute $period';
  }

  // =========================================================
  // MESSAGE BUBBLE
  // =========================================================

  Widget _messageBubble(
    Map<String, dynamic> data,
  ) {
    final senderId =
        data['senderId'] as String? ?? '';

    final isMine =
        senderId == _buyerId;

    final message =
        data['message'] as String? ?? '';

    final isRead =
        data['isRead'] as bool? ?? false;

    final timestamp =
        data['createdAt'] as Timestamp?;

    return Align(
      alignment: isMine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context)
                      .size
                      .width *
                  0.78,
        ),
        margin:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 5,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration:
            BoxDecoration(
          color: isMine
              ? Colors.redAccent
              : Colors.grey.shade200,
          borderRadius:
              BorderRadius.only(
            topLeft:
                const Radius.circular(18),
            topRight:
                const Radius.circular(18),
            bottomLeft:
                Radius.circular(
              isMine ? 18 : 4,
            ),
            bottomRight:
                Radius.circular(
              isMine ? 4 : 18,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            Align(
              alignment:
                  Alignment.centerLeft,
              child: Text(
                message,
                style: TextStyle(
                  color: isMine
                      ? Colors.white
                      : Colors.black87,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Text(
                  _formatTime(timestamp),
                  style: TextStyle(
                    color: isMine
                        ? Colors.white70
                        : Colors.black54,
                    fontSize: 10,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead
                        ? Icons.done_all
                        : Icons.check,
                    size: 14,
                    color: isRead
                        ? Colors.white
                        : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // EMPTY CHAT
  // =========================================================

  Widget _emptyChat() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration:
                  BoxDecoration(
                color: Colors.redAccent
                    .withValues(
                  alpha: 0.10,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isReseller
                    ? Icons
                        .storefront_outlined
                    : Icons
                        .chat_bubble_outline,
                size: 42,
                color:
                    Colors.redAccent,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Start a conversation',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a message to ${widget.sellerName}',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // MESSAGE LIST
  // =========================================================

  Widget _messageList() {
    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream: _messagesRef
          .orderBy(
            'createdAt',
            descending: true,
          )
          .snapshots(),
      builder:
          (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(24),
              child: Text(
                'Unable to load messages.\n\n'
                '${snapshot.error}',
                textAlign:
                    TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        final docs =
            snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _emptyChat();
        }

        WidgetsBinding.instance
            .addPostFrameCallback(
          (_) {
            _markMessagesAsRead();
          },
        );

        return ListView.builder(
          controller:
              _scrollController,
          reverse: true,
          padding:
              const EdgeInsets.only(
            top: 16,
            bottom: 16,
          ),
          itemCount: docs.length,
          itemBuilder:
              (context, index) {
            final data =
                docs[index].data();

            return _messageBubble(
              data,
            );
          },
        );
      },
    );
  }

  // =========================================================
  // MESSAGE INPUT
  // =========================================================

  Widget _messageInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding:
            const EdgeInsets.fromLTRB(
          10,
          8,
          10,
          8,
        ),
        decoration:
            BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(
                alpha: 0.06,
              ),
              blurRadius: 8,
              offset:
                  const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller:
                    _messageController,
                minLines: 1,
                maxLines: 5,
                textInputAction:
                    TextInputAction
                        .newline,
                decoration:
                    InputDecoration(
                  hintText:
                      'Type a message...',
                  filled: true,
                  fillColor:
                      Colors.grey.shade100,
                  contentPadding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius
                            .circular(24),
                    borderSide:
                        BorderSide.none,
                  ),
                ),
                onSubmitted: (_) {
                  if (!_sending) {
                    _sendMessage();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color:
                  Colors.redAccent,
              shape:
                  const CircleBorder(),
              child: InkWell(
                customBorder:
                    const CircleBorder(),
                onTap: _sending
                    ? null
                    : _sendMessage,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<
                                      Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color:
                                Colors.white,
                            size: 21,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
    return Scaffold(
      backgroundColor:
          Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            Colors.white,
        foregroundColor:
            Colors.black87,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor:
                  Colors.redAccent
                      .withValues(
                alpha: 0.10,
              ),
              child: Icon(
                widget.isReseller
                    ? Icons
                        .storefront
                    : Icons
                        .storefront,
                color:
                    Colors.redAccent,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    widget.sellerName,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  Text(
                    _recipientType,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors
                          .grey
                          .shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _messageList(),
          ),
          _messageInput(),
        ],
      ),
    );
  }
}
