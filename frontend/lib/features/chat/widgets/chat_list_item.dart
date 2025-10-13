import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/chat_conversation.dart';

typedef AvatarBuilder = Widget Function(String? avatar);

class ChatListItem extends StatelessWidget {
  const ChatListItem({
    super.key,
    required this.conversation,
    required this.avatarBuilder,
    required this.onTap,
  });

  final ChatConversation conversation;
  final AvatarBuilder avatarBuilder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: conversation.isPinned ? AppColors.surfaceMuted : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatar(),
              const SizedBox(width: 16),
              Expanded(child: _buildContent(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return SizedBox(
      width: 56,
      height: 56,
      child: avatarBuilder(conversation.avatar),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                conversation.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              conversation.timeLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textQuaternary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                conversation.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textQuaternary,
                ),
              ),
            ),
            if (conversation.unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Text(
                  conversation.unreadCount.toString(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
