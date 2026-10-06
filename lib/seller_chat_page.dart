import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SellerChatPage extends StatefulWidget {
  final String conversationId;

  // Kept as buyerId for compatibility with the existing
  // Firestore conversation structure.
  // This can represent the other participant:
  // Buyer, Seller, or Reseller.
  final String buyerId;
  final String buyerName;

  // Optional role information for the other participant.
  // Existing calls do not need to provide this.
  final bool isReseller;

  const SellerChatPage({
    super.key,
    required this.conversationId,
    required this.buyerId,
    required this.buyerName,
    this.isReseller = false,
  });

  @override
  State<SellerChatPage> createState() =>
      _SellerChatPageState();
}

class _SellerChatPageState
    extends State<SellerChatPage> {
  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final TextEditingController
      _messageController =
      TextEditingController();

  final ScrollController
      _scrollController =
      ScrollController();

  String? _sellerId;
  String _sellerName = 'Seller';

  bool _conversationReady = false;
  bool _initializing = true;
  bool _sending = false;
  bool _markingRead = false;

  // The other participant's detected role.
  String _otherParticipantRole = 'Buyer';

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
      return;
    }

    _sellerId = user.uid;

    try {
      await _loadSellerName();
      await _loadOtherParticipantRole();
      await _ensureConversation();
      await _markMessagesAsRead();
    } catch (e) {
      debugPrint(
        'Chat initialization error: $e',
      );
    }

    if (mounted) {
      setState(() {
        _initializing = false;
      });
    }
  }

  Future<void> _loadSellerName() async {
    final sellerId = _sellerId;

    if (sellerId == null) {
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(sellerId)
          .get();

      final data = snapshot.data();

      if (data != null) {
        final name = data['name'];

        if (name is String &&
            name.trim().isNotEmpty) {
          _sellerName = name.trim();
          return;
        }

        final displayName =
            data['displayName'];

        if (displayName is String &&
            displayName.trim().isNotEmpty) {
          _sellerName =
              displayName.trim();
          return;
        }
      }
    } catch (e) {
      debugPrint(
        'Seller name load error: $e',
      );
    }

    final authName =
        _auth.currentUser?.displayName;

    if (authName != null &&
        authName.trim().isNotEmpty) {
      _sellerName =
          authName.trim();
    }
  }

  Future<void>
      _loadOtherParticipantRole() async {
    // Explicit reseller flag has priority.
    if (widget.isReseller) {
      _otherParticipantRole =
          'Reseller';
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(widget.buyerId)
          .get();

      final data = snapshot.data();

      if (data == null) {
        _otherParticipantRole =
            'Buyer';
        return;
      }

      final entrepreneurStatus =
          data['entrepreneurStatus']
              ?.toString()
              .toLowerCase();

      final role =
          data['role']
              ?.toString()
              .toLowerCase();

      final sellerStatus =
          data['sellerStatus']
              ?.toString()
              .toLowerCase();

      if (entrepreneurStatus ==
              'approved' ||
          role == 'reseller' ||
          role == 'entrepreneur') {
        _otherParticipantRole =
            'Reseller';
        return;
      }

      if (sellerStatus ==
              'approved' ||
          role == 'seller') {
        _otherParticipantRole =
            'Seller';
        return;
      }

      _otherParticipantRole =
          'Buyer';
    } catch (e) {
      debugPrint(
        'Other participant role load error: $e',
      );

      _otherParticipantRole =
          widget.isReseller
              ? 'Reseller'
              : 'Buyer';
    }
  }

  IconData get _otherParticipantIcon {
    switch (_otherParticipantRole) {
      case 'Reseller':
        return Icons.store;
      case 'Seller':
        return Icons.storefront;
      default:
        return Icons.person_outline;
    }
  }

  String get _otherParticipantTitle {
    switch (_otherParticipantRole) {
      case 'Reseller':
        return 'Reseller';
      case 'Seller':
        return 'Seller';
      default:
        return 'Buyer';
    }
  }

  Future<void> _ensureConversation() async {
    final sellerId = _sellerId;

    if (sellerId == null) {
      return;
    }

    final conversationRef =
        _firestore
            .collection('conversations')
            .doc(widget.conversationId);

    final snapshot =
        await conversationRef.get();

    if (!snapshot.exists) {
      await conversationRef.set({
        'conversationId':
            widget.conversationId,

        // Existing schema is preserved.
        // The current user is the seller-side
        // participant for this conversation.
        'buyerId':
            widget.buyerId,

        'buyerName':
            widget.buyerName,

        'sellerId':
            sellerId,

        'sellerName':
            _sellerName,

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

      _conversationReady = true;
      return;
    }

    final data = snapshot.data();

    if (data == null) {
      return;
    }

    final existingBuyerId =
        data['buyerId'];

    final existingSellerId =
        data['sellerId'];

    if (existingBuyerId !=
            widget.buyerId ||
        existingSellerId !=
            sellerId) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'This conversation is not available.',
            ),
          ),
        );
      }

      return;
    }

    final updates =
        <String, dynamic>{};

    if (data['buyerName'] !=
            widget.buyerName &&
        widget.buyerName
            .trim()
            .isNotEmpty) {
      updates['buyerName'] =
          widget.buyerName.trim();
    }

    if (data['sellerName'] !=
            _sellerName &&
        _sellerName
            .trim()
            .isNotEmpty) {
      updates['sellerName'] =
          _sellerName.trim();
    }

    if (updates.isNotEmpty) {
      updates['updatedAt'] =
          FieldValue.serverTimestamp();

      await conversationRef
          .update(updates);
    }

    _conversationReady = true;
  }

  Future<void> _markMessagesAsRead() async {
    if (_markingRead) {
      return;
    }

    final sellerId = _sellerId;

    if (sellerId == null ||
        !_conversationReady) {
      return;
    }

    _markingRead = true;

    try {
      final messagesSnapshot =
          await _firestore
              .collection('conversations')
              .doc(widget.conversationId)
              .collection('messages')
              .where(
                'receiverId',
                isEqualTo: sellerId,
              )
              .get();

      final batch =
          _firestore.batch();

      int unreadMessages = 0;

      for (final document
          in messagesSnapshot.docs) {
        final data =
            document.data();

        if (data['isRead'] == false) {
          unreadMessages++;

          batch.update(
            document.reference,
            {
              'isRead': true,
              'readAt':
                  FieldValue
                      .serverTimestamp(),
            },
          );
        }
      }

      if (unreadMessages > 0) {
        batch.update(
          _firestore
              .collection('conversations')
              .doc(widget.conversationId),
          {
            'sellerUnreadCount': 0,
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
        );

        await batch.commit();
      }
    } catch (e) {
      debugPrint(
        'Mark messages read error: $e',
      );
    } finally {
      _markingRead = false;
    }
  }

  Future<void> _sendMessage() async {
    final sellerId = _sellerId;

    if (sellerId == null ||
        !_conversationReady ||
        _sending) {
      return;
    }

    final message =
        _messageController.text.trim();

    if (message.isEmpty) {
      return;
    }

    if (message.length > 5000) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Message is too long. Maximum 5000 characters.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      final conversationRef =
          _firestore
              .collection('conversations')
              .doc(widget.conversationId);

      final messageRef =
          conversationRef
              .collection('messages')
              .doc();

      final batch =
          _firestore.batch();

      batch.set(
        messageRef,
        {
          'senderId': sellerId,
          'receiverId':
              widget.buyerId,
          'message': message,
          'isRead': false,
          'createdAt':
              FieldValue.serverTimestamp(),
        },
      );

      batch.update(
        conversationRef,
        {
          'buyerId':
              widget.buyerId,

          'buyerName':
              widget.buyerName,

          'sellerId':
              sellerId,

          'sellerName':
              _sellerName,

          'lastMessage':
              message,

          'lastMessageAt':
              FieldValue.serverTimestamp(),

          'buyerUnreadCount':
              FieldValue.increment(1),

          'updatedAt':
              FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      _messageController.clear();

      await Future<void>.delayed(
        const Duration(
          milliseconds: 100,
        ),
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Unable to send message: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController
        .hasClients) {
      return;
    }

    _scrollController.animateTo(
      _scrollController
          .position
          .maxScrollExtent,
      duration:
          const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  String _formatMessageTime(
    dynamic value,
  ) {
    if (value is! Timestamp) {
      return '';
    }

    final date =
        value.toDate();

    final hour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
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

  Widget _messageBubble(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        document,
  ) {
    final data =
        document.data();

    final sellerId =
        _sellerId;

    final senderId =
        data['senderId'];

    final isMine =
        sellerId != null &&
            senderId == sellerId;

    final message =
        data['message'];

    final text =
        message is String
            ? message
            : '';

    final time =
        _formatMessageTime(
      data['createdAt'],
    );

    final isRead =
        data['isRead'] == true;

    return Align(
      alignment: isMine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(
          maxWidth:
              MediaQuery.of(context)
                  .size
                  .width *
              0.78,
        ),
        margin:
            EdgeInsets.only(
          left:
              isMine ? 55 : 12,
          right:
              isMine ? 12 : 55,
          top: 5,
          bottom: 5,
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
                const Radius.circular(16),
            topRight:
                const Radius.circular(16),
            bottomLeft:
                Radius.circular(
              isMine ? 16 : 4,
            ),
            bottomRight:
                Radius.circular(
              isMine ? 4 : 16,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isMine
                    ? Colors.white
                    : Colors.black87,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: isMine
                          ? Colors.white70
                          : Colors.grey.shade600,
                      fontSize: 10,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(
                      width: 4,
                    ),
                    Icon(
                      isRead
                          ? Icons.done_all
                          : Icons.done,
                      size: 14,
                      color: isRead
                          ? Colors.white
                          : Colors.white70,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyChat() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(32),
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
                _otherParticipantIcon,
                size: 40,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Chat with ${widget.buyerName}',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Send a message to start the conversation.',
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

  Stream<QuerySnapshot<
          Map<String, dynamic>>>
      _messagesStream() {
    return _firestore
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .orderBy(
          'createdAt',
          descending: false,
        )
        .snapshots();
  }

  Widget _messageList() {
    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream: _messagesStream(),
      builder:
          (context, snapshot) {
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
                    color:
                        Colors.redAccent,
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  const Text(
                    'Unable to load messages.',
                    style:
                        TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    'Please check your connection and try again.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
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

        if (snapshot
                .connectionState ==
            ConnectionState
                .waiting) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        final documents =
            snapshot.data?.docs ??
                [];

        if (documents.isEmpty) {
          return _emptyChat();
        }

        WidgetsBinding.instance
            .addPostFrameCallback(
          (_) {
            if (mounted) {
              _scrollToBottom();
            }
          },
        );

        return ListView.builder(
          controller:
              _scrollController,
          padding:
              const EdgeInsets.only(
            top: 16,
            bottom: 16,
          ),
          itemCount:
              documents.length,
          itemBuilder:
              (context, index) {
            return _messageBubble(
              documents[index],
            );
          },
        );
      },
    );
  }

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
              blurRadius: 8,
              offset:
                  const Offset(0, -2),
              color: Colors.black
                  .withValues(
                alpha: 0.06,
              ),
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
                textCapitalization:
                    TextCapitalization
                        .sentences,
                decoration:
                    InputDecoration(
                  hintText:
                      'Write a message...',
                  filled: true,
                  fillColor:
                      Colors.grey.shade100,
                  contentPadding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      24,
                    ),
                    borderSide:
                        BorderSide.none,
                  ),
                ),
                onSubmitted: (_) {
                  _sendMessage();
                },
              ),
            ),
            const SizedBox(
              width: 8,
            ),
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
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color:
                                Colors.white,
                            size: 22,
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

  @override
  Widget build(
    BuildContext context,
  ) {
    final sellerId =
        _sellerId;

    if (sellerId == null) {
      return Scaffold(
        appBar: AppBar(
          title:
              Text(widget.buyerName),
          centerTitle: true,
        ),
        body: const Center(
          child: Text(
            'Please login to use chat.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration:
                  BoxDecoration(
                color: Colors.redAccent
                    .withValues(
                  alpha: 0.10,
                ),
                shape:
                    BoxShape.circle,
              ),
              child: Icon(
                _otherParticipantIcon,
                color:
                    Colors.redAccent,
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    widget.buyerName
                            .trim()
                            .isEmpty
                        ? 'User'
                        : widget.buyerName,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  Text(
                    _otherParticipantTitle,
                    style:
                        TextStyle(
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
      body: _initializing
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : Column(
              children: [
                Expanded(
                  child:
                      _messageList(),
                ),
                if (_conversationReady)
                  _messageInput(),
              ],
            ),
    );
  }
}
