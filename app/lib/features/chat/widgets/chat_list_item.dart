import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_badge.dart';
import '../models/chat_model.dart';

typedef AvatarBuilder = Widget Function(String? avatar);

class ChatListItem extends StatelessWidget {
  const ChatListItem({
    super.key,
    required this.chat,
    required this.avatarBuilder,
    required this.onTap,
    this.showBottomDivider = false,
  });

  final Chat chat;
  final AvatarBuilder avatarBuilder;
  final VoidCallback onTap;
  final bool showBottomDivider;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: chat.isPinned ? AppColors.surfaceMuted : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
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
            if (showBottomDivider)
              const Divider(
                height: 1,
                thickness: 0.5,
                color: Color(0xFFE9EBEF),
                indent: 88, // 16 padding + 56 avatar + 16 gap
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return SizedBox(width: 56, height: 56, child: avatarBuilder(chat.avatar));
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
                _displayTitle(chat),
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
              chat.displayTime,
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
                chat.type == ChatType.favorite &&
                        chat.lastMessage.trim().isEmpty
                    ? '将消息转发到这里即可保存'
                    : chat.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textQuaternary,
                ),
              ),
            ),
            if (chat.unreadCount > 0 && chat.type != ChatType.favorite)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: AppBadge(
                  count: chat.unreadCount,
                  size: 18,
                  fontSize: 11,
                  backgroundColor: AppColors.primary,
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// 标题显示规则：
  /// - 单聊：优先显示备注/好友昵称/好友用户名
  /// - 群聊：显示房间名
  String _displayTitle(Chat chat) {
    if (chat.type == ChatType.group || chat.type == ChatType.favorite) {
      return chat.name;
    }
    final extra = chat.extra ?? const <String, dynamic>{};
    final candidates = <String?>[
      extra['remark'] as String?,
      extra['friend_remark'] as String?,
      extra['friendRemark'] as String?,
      extra['friend_nickname'] as String?,
      extra['friendNickname'] as String?,
      extra['friend_name'] as String?,
      extra['friendName'] as String?,
      extra['friend_username'] as String?,
      extra['friendUsername'] as String?,
    ];
    for (final v in candidates) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return chat.name;
  }
}
