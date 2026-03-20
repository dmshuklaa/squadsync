import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:squadsync/core/supabase/supabase_client.dart';
import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/features/chat/data/chat_repository.dart';
import 'package:squadsync/features/chat/providers/chat_providers.dart';
import 'package:squadsync/shared/models/chat_message.dart';
import 'package:squadsync/shared/widgets/avatar_widget.dart';
import 'package:squadsync/shared/widgets/error_state_widget.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  final String teamId;
  final String teamName;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    _messageController.clear();

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await const ChatRepository().sendMessage(
        teamId: widget.teamId,
        senderId: userId,
        content: content,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.teamId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.teamName),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // TODO: show team info
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Message list ──────────────────────────────
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
              error: (e, _) => ErrorStateWidget(
                message: 'Error loading messages: $e',
                onRetry: () =>
                    ref.invalidate(chatMessagesProvider(widget.teamId)),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(height: 12),
                        const Text('No messages yet',
                            style: AppTextStyles.body),
                        Text(
                          'Start the conversation!',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textHint),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) => _ChatBubble(
                    message: messages[i],
                    currentUserId:
                        supabase.auth.currentUser?.id ?? '',
                    onEdit: (msg) => _showEditDialog(msg),
                    onDelete: (msg) => _confirmDelete(msg),
                  ),
                );
              },
            ),
          ),

          // ── Message input ─────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                  top: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Message ${widget.teamName}...',
                      hintStyle: const TextStyle(
                          color: AppColors.textHint),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                            color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                            color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                            color: AppColors.accent),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                    maxLines: null,
                    textCapitalization:
                        TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _messageController,
                  builder: (context, value, _) {
                    final hasText = value.text.trim().isNotEmpty;
                    return AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 200),
                      child: hasText
                          ? IconButton(
                              onPressed: _sendMessage,
                              icon: const Icon(
                                  Icons.send_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    AppColors.accent,
                                foregroundColor:
                                    AppColors.primary,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: AppColors.textHint,
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(ChatMessage message) async {
    final controller =
        TextEditingController(text: message.content);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed == true && controller.text.trim().isNotEmpty) {
      try {
        await const ChatRepository().editMessage(
          messageId: message.id,
          content: controller.text.trim(),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error editing: $e')),
        );
      }
    }
    controller.dispose();
  }

  Future<void> _confirmDelete(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text(
            'This will show "This message was deleted" to all members.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await const ChatRepository().deleteMessage(message.id);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting: $e')),
        );
      }
    }
  }
}

// ── Chat bubble ────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.currentUserId,
    required this.onEdit,
    required this.onDelete,
  });

  final ChatMessage message;
  final String currentUserId;
  final void Function(ChatMessage) onEdit;
  final void Function(ChatMessage) onDelete;

  @override
  Widget build(BuildContext context) {
    final isMe = message.senderId == currentUserId;

    return GestureDetector(
      onLongPress: isMe && !message.isDeleted
          ? () => _showMessageOptions(context)
          : null,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe) ...[
              AvatarWidget(
                fullName: message.senderFullName ?? '?',
                avatarUrl: message.senderAvatarUrl,
                size: 32,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 4, bottom: 2),
                      child: Text(
                        message.senderFullName ?? '',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe
                            ? AppColors.primary
                            : AppColors.surface,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: isMe
                              ? const Radius.circular(18)
                              : const Radius.circular(4),
                          bottomRight: isMe
                              ? const Radius.circular(4)
                              : const Radius.circular(18),
                        ),
                        border: isMe
                            ? null
                            : Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        message.displayContent,
                        style: TextStyle(
                          color: isMe
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontSize: 15,
                          fontStyle: message.isDeleted
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                      if (message.edited && !message.deleted) ...[
                        const SizedBox(width: 4),
                        const Text(
                          'edited',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textHint,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isMe) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.edit_outlined, color: AppColors.accent),
              title: const Text('Edit'),
              onTap: () {
                Navigator.of(ctx).pop();
                onEdit(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.error),
              title: const Text('Delete',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.of(ctx).pop();
                onDelete(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);

    if (msgDay == today) return DateFormat('h:mm a').format(dt);
    if (now.difference(dt).inDays < 7) {
      return DateFormat('EEE h:mm a').format(dt);
    }
    return DateFormat('d MMM').format(dt);
  }
}
