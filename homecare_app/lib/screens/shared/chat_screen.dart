import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../config/theme.dart';
import '../../models/chat_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/healthcare_ui.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.threadId,
    required this.bookingId,
    required this.currentUserId,
    required this.currentUserName,
    required this.counterpartName,
  });

  final String threadId;
  final String bookingId;
  final String currentUserId;
  final String currentUserName;
  final String counterpartName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _firestoreService = FirestoreService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  int _lastMessageCount = 0;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HealthcareBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    TopGlassButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FrostCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.counterpartName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Secure in-app chat for booking support',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<ChatThreadModel?>(
                    stream: _firestoreService.streamChatThread(widget.threadId),
                    builder: (context, threadSnapshot) {
                      final thread = threadSnapshot.data;
                      if (threadSnapshot.connectionState == ConnectionState.waiting &&
                          thread == null) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (thread == null) {
                        return const EmptyStateView(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'Chat room is getting ready',
                          subtitle:
                              'Please wait a moment while we prepare the conversation.',
                        );
                      }

                      return Column(
                        children: [
                          Expanded(
                            child: StreamBuilder<List<ChatMessageModel>>(
                              stream: _firestoreService
                                  .streamChatMessages(widget.threadId),
                              builder: (context, snapshot) {
                                final messages = snapshot.data ?? const [];
                                if (messages.length != _lastMessageCount) {
                                  _lastMessageCount = messages.length;
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _scrollToBottom();
                                  });
                                }

                                if (messages.isEmpty) {
                                  return const EmptyStateView(
                                    icon: Icons.forum_outlined,
                                    title: 'No messages yet',
                                    subtitle:
                                        'Start the conversation when you need help or want to coordinate the visit.',
                                  );
                                }

                                return FrostCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    itemCount: messages.length,
                                    itemBuilder: (context, index) {
                                      final message = messages[index];
                                      return _ChatBubble(
                                        message: message,
                                        isMine:
                                            message.senderId == widget.currentUserId,
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                          FrostCard(
                            padding: const EdgeInsets.all(12),
                            borderRadius: BorderRadius.circular(24),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    minLines: 1,
                                    maxLines: 4,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _sendMessage(),
                                    decoration: const InputDecoration(
                                      hintText: 'Type your message...',
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                TapScale(
                                  onTap: _isSending ? null : _sendMessage,
                                  child: ElevatedButton(
                                    onPressed: _isSending ? null : _sendMessage,
                                    style: ElevatedButton.styleFrom(
                                      shape: const CircleBorder(),
                                      padding: const EdgeInsets.all(14),
                                      minimumSize: const Size(52, 52),
                                    ),
                                    child: _isSending
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.send_rounded),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);

    try {
      await _firestoreService.sendChatMessage(
        threadId: widget.threadId,
        bookingId: widget.bookingId,
        senderId: widget.currentUserId,
        senderName: widget.currentUserName,
        text: text,
      );
      _messageController.clear();
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to send message: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.isMine});

  final ChatMessageModel message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final alignment = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isMine ? AppTheme.accentLight : AppTheme.background;
    final borderColor = isMine ? AppTheme.accent.withValues(alpha: 0.18) : AppTheme.divider;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: alignment,
              children: [
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      message.senderName,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppTheme.accent),
                    ),
                  ),
                Text(
                  message.text,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timeago.format(message.createdAt, locale: 'en_short'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
