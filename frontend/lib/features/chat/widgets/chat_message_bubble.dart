import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/chat_message.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.type == ChatMessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          message.content,
          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          textAlign: TextAlign.center,
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
            child: Container(
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
          ),
        ],
      ),
    );
  }
}
