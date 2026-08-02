import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../models/chat_model.dart';

enum ConversationMenuAction { pin, mentions, muted, archive }

const conversationContextMenuKey = ValueKey('conversation-context-menu');

Future<ConversationMenuAction?> showConversationContextMenu({
  required BuildContext context,
  required String chatName,
  required Offset anchor,
  required bool isPinned,
  required ChatNotificationMode notificationMode,
}) {
  return showGeneralDialog<ConversationMenuAction>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: true,
    barrierLabel: '关闭会话操作',
    barrierColor: const Color(0x1F0F172A),
    transitionDuration: AppMotion.resolve(context, AppMotion.fast),
    pageBuilder: (context, animation, secondaryAnimation) {
      final media = MediaQuery.of(context);
      const margin = 12.0;
      final width = math.min(210.0, media.size.width - margin * 2);
      const height = 188.0;
      final minTop = media.padding.top + margin;
      final maxLeft = math.max(margin, media.size.width - width - margin);
      final maxTop = math.max(
        minTop,
        media.size.height - media.padding.bottom - height - margin,
      );
      final left = anchor.dx.clamp(margin, maxLeft).toDouble();
      final top = anchor.dy.clamp(minTop, maxTop).toDouble();

      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: width,
            child: Semantics(
              label: '$chatName 会话操作',
              container: true,
              explicitChildNodes: true,
              child: Material(
                key: conversationContextMenuKey,
                color: Theme.of(context).colorScheme.surface,
                elevation: 10,
                shadowColor: const Color(0x330F172A),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: FocusTraversalGroup(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MenuButton(
                          label: isPinned ? '取消置顶' : '置顶会话',
                          autofocus: true,
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(ConversationMenuAction.pin),
                        ),
                        _MenuButton(
                          label: '仅提及',
                          selected:
                              notificationMode == ChatNotificationMode.mentions,
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(ConversationMenuAction.mentions),
                        ),
                        _MenuButton(
                          label: '静音',
                          selected:
                              notificationMode == ChatNotificationMode.muted,
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(ConversationMenuAction.muted),
                        ),
                        _MenuButton(
                          label: '归档会话',
                          danger: true,
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(ConversationMenuAction.archive),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          alignment: Alignment.topLeft,
          child: child,
        ),
      );
    },
  );
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.danger = false,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final bool danger;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = danger
        ? AppColors.danger
        : selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: TextButton(
        autofocus: autofocus,
        onPressed: onPressed,
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: foreground,
          backgroundColor: selected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            if (selected) const Icon(Icons.check, size: 18),
          ],
        ),
      ),
    );
  }
}
