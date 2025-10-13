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

    final bubbleColor = message.isSelf ? AppColors.primary : AppColors.surface;
    final textColor = message.isSelf ? Colors.white : AppColors.textPrimary;
    final alignment = message.isSelf
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final margin = EdgeInsets.only(
      left: message.isSelf ? 80 : 0,
      right: message.isSelf ? 0 : 80,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(message.isSelf ? 20 : 6),
                bottomRight: Radius.circular(message.isSelf ? 6 : 20),
              ),
            ),
            child: Text(
              message.content,
              style: TextStyle(fontSize: 15, color: textColor, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
