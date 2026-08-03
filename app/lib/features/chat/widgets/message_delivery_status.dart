import 'package:flutter/material.dart';

import '../../../core/services/message_service.dart';
import '../../../core/theme/design_tokens.dart';

class MessageDeliveryStatus extends StatelessWidget {
  const MessageDeliveryStatus({
    super.key,
    required this.status,
    required this.color,
    this.readColor,
    this.onReadTap,
    this.onRetry,
    this.compact = false,
  });

  final MessageStatus status;
  final Color color;
  final Color? readColor;
  final VoidCallback? onReadTap;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final indicator = switch (status) {
      MessageStatus.sending => SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
      MessageStatus.sent => Icon(Icons.check, size: 14, color: color),
      MessageStatus.delivered => Icon(Icons.done_all, size: 14, color: color),
      MessageStatus.read => Icon(
        Icons.done_all,
        size: 14,
        color: readColor ?? color,
      ),
      MessageStatus.failed => const Icon(
        Icons.error_outline,
        size: 16,
        color: Colors.red,
      ),
    };

    final callback = switch (status) {
      MessageStatus.failed => onRetry,
      MessageStatus.read => onReadTap,
      _ => null,
    };
    final label = switch (status) {
      MessageStatus.sending => '发送中',
      MessageStatus.sent => '已发送',
      MessageStatus.delivered => '已送达',
      MessageStatus.read => '已读',
      MessageStatus.failed => onRetry == null ? '发送失败' : '发送失败，点击重试',
    };

    if (callback == null) {
      return Semantics(
        key: ValueKey('message-delivery-status-${status.name}'),
        label: label,
        child: indicator,
      );
    }

    final control = Semantics(
      key: ValueKey('message-delivery-status-${status.name}'),
      button: true,
      label: label,
      child: InkResponse(
        key: ValueKey('message-delivery-action-${status.name}'),
        onTap: callback,
        radius: AppControlSize.minTapTarget / 2,
        child: SizedBox.square(
          dimension: compact ? 28 : AppControlSize.minTapTarget,
          child: Center(child: indicator),
        ),
      ),
    );
    return Tooltip(message: label, child: control);
  }
}
