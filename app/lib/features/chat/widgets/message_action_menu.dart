import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/design_tokens.dart';

enum MessageAction { copy, quote, forward, pin, delete, reaction }

const messageActionMenuKey = ValueKey('message-action-menu');

class _MessageActionEntry {
  const _MessageActionEntry({
    required this.action,
    required this.label,
    required this.icon,
    this.danger = false,
  });

  final MessageAction action;
  final String label;
  final IconData icon;
  final bool danger;
}

Future<MessageAction?> showMessageActionMenu({
  required BuildContext context,
  required Offset anchor,
  required bool isSelf,
  required bool isTextMessage,
  required bool isDeleted,
  required bool isPinned,
  required bool isRelayOnlyMode,
  double? bottomBoundary,
}) {
  final entries = _buildEntries(
    isTextMessage: isTextMessage,
    isDeleted: isDeleted,
    isPinned: isPinned,
    isRelayOnlyMode: isRelayOnlyMode,
  );
  if (entries.isEmpty) return Future.value();

  return showGeneralDialog<MessageAction>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: true,
    barrierLabel: '关闭消息操作',
    barrierColor: const Color(0x0D0F172A),
    transitionDuration: AppMotion.resolve(context, AppMotion.fast),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final media = MediaQuery.of(dialogContext);
      const margin = 12.0;
      const preferredWidth = 176.0;
      const itemHeight = 44.0;
      const panelPadding = 6.0;
      final width = math.min(preferredWidth, media.size.width - margin * 2);
      final height = entries.length * itemHeight + panelPadding * 2;
      final minTop = media.padding.top + margin;
      final viewportBottom = media.size.height - media.padding.bottom - margin;
      final effectiveBottom = math.min(
        viewportBottom,
        bottomBoundary ?? viewportBottom,
      );
      final maxLeft = math.max(margin, media.size.width - width - margin);
      final maxTop = math.max(minTop, effectiveBottom - height);
      final preferredLeft = isSelf
          ? anchor.dx - width + margin
          : anchor.dx - margin;
      final left = preferredLeft.clamp(margin, maxLeft).toDouble();
      final preferredTop = anchor.dy - 32;
      final top = preferredTop.clamp(minTop, maxTop).toDouble();

      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: width,
            child: Semantics(
              label: '消息操作',
              container: true,
              explicitChildNodes: true,
              child: Material(
                key: messageActionMenuKey,
                color: Theme.of(dialogContext).colorScheme.surface,
                elevation: 10,
                shadowColor: const Color(0x330F172A),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(dialogContext).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(panelPadding),
                  child: FocusTraversalGroup(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var index = 0; index < entries.length; index++)
                          _ActionButton(
                            entry: entries[index],
                            autofocus: index == 0,
                            onPressed: () => Navigator.of(
                              dialogContext,
                            ).pop(entries[index].action),
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
          alignment: isSelf ? Alignment.topRight : Alignment.topLeft,
          child: child,
        ),
      );
    },
  );
}

List<_MessageActionEntry> _buildEntries({
  required bool isTextMessage,
  required bool isDeleted,
  required bool isPinned,
  required bool isRelayOnlyMode,
}) {
  return <_MessageActionEntry>[
    if (isTextMessage && !isDeleted)
      const _MessageActionEntry(
        action: MessageAction.copy,
        label: '复制文本',
        icon: Icons.copy_rounded,
      ),
    if (!isRelayOnlyMode && !isDeleted)
      const _MessageActionEntry(
        action: MessageAction.quote,
        label: '引用',
        icon: Icons.format_quote_rounded,
      ),
    if (!isRelayOnlyMode && isTextMessage && !isDeleted)
      const _MessageActionEntry(
        action: MessageAction.forward,
        label: '转发',
        icon: Icons.reply_rounded,
      ),
    if (!isRelayOnlyMode && !isDeleted)
      _MessageActionEntry(
        action: MessageAction.pin,
        label: isPinned ? '取消置顶' : '置顶',
        icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
      ),
    if (!isRelayOnlyMode && !isDeleted)
      const _MessageActionEntry(
        action: MessageAction.reaction,
        label: '添加反应',
        icon: Icons.emoji_emotions_outlined,
      ),
    if (!isRelayOnlyMode)
      const _MessageActionEntry(
        action: MessageAction.delete,
        label: '删除',
        icon: Icons.delete_outline,
        danger: true,
      ),
  ];
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.entry,
    required this.onPressed,
    required this.autofocus,
  });

  final _MessageActionEntry entry;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final foreground = entry.danger
        ? AppColors.danger
        : Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: TextButton.icon(
        autofocus: autofocus,
        onPressed: onPressed,
        icon: Icon(entry.icon, size: 18),
        label: Text(entry.label),
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: foreground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }
}
