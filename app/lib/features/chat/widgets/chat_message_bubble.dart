import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/chat_message.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    this.onReactionTap,
  });

  final ChatMessage message;
  final void Function(ChatMessage message, String reactionKey)? onReactionTap;

  @override
  Widget build(BuildContext context) {
    if (message.type == ChatMessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Text(
            message.content,
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final isImageMessage =
        message.type == ChatMessageType.image &&
        (message.imageAsset != null || message.imageUrl != null);
    final bubbleColor = message.isSelf ? AppColors.primary : AppColors.surface;
    final textColor = message.isSelf ? Colors.white : AppColors.textPrimary;
    final alignment = message.isSelf
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final margin = EdgeInsets.only(
      left: message.isSelf ? 80 : 0,
      right: message.isSelf ? 0 : 80,
    );
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(message.isSelf ? 20 : 0),
      topRight: const Radius.circular(20),
      bottomLeft: const Radius.circular(20),
      bottomRight: Radius.circular(message.isSelf ? 0 : 20),
    );

    return Container(
      margin: margin,
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (!message.isSelf)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Text(
                message.senderName,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: message.isSelf
                  ? MediaQuery.of(context).size.width * 0.8
                  : double.infinity,
            ),
            child: Column(
              crossAxisAlignment: alignment,
              children: [
                Container(
                  decoration: isImageMessage
                      ? null
                      : BoxDecoration(
                          color: bubbleColor,
                          borderRadius: borderRadius,
                        ),
                  padding: isImageMessage
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: isImageMessage
                      ? ClipRRect(
                          borderRadius: borderRadius,
                          child: message.imageAsset != null
                              ? Image.asset(
                                  message.imageAsset!,
                                  width: 200,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  message.imageUrl!,
                                  width: 200,
                                  fit: BoxFit.cover,
                                ),
                        )
                      : Text(
                          message.content,
                          style: TextStyle(
                            fontSize: 15,
                            color: textColor,
                            height: 1.4,
                          ),
                        ),
                ),
                if (message.reactions.isNotEmpty)
                  _buildReactions(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactions(BuildContext context) {
    final filteredReactions =
        message.reactions.where((r) => r.count > 0).toList();

    if (filteredReactions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: filteredReactions.map((reaction) {
          return GestureDetector(
            onTap: onReactionTap != null
                ? () => onReactionTap!(message, reaction.reactionKey)
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: reaction.hasSelf
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: reaction.hasSelf
                    ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    reaction.reactionKey,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    reaction.count.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: reaction.hasSelf
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight:
                          reaction.hasSelf ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
