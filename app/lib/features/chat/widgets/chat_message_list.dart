part of '../chat_detail_page_v2.dart';

extension _ChatMessageListView on _ChatDetailPageV2State {
  Widget _buildMessageList(double bottomPadding) {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        // 使用 SchedulerBinding 确保在下一帧处理，避免在 build 阶段执行副作用
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _processMessages(provider.messages);
        });

        final hasMessages = provider.messages.isNotEmpty;

        if (hasMessages && _messageListOpacity < 1.0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _revealMessageList();
          });
        }

        Widget content;
        if (!hasMessages) {
          content = Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: AppColors.textTertiary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无消息',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '开始聊天吧',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          final messages = provider.messages;
          final pinnedMessage = provider.pinnedMessage;
          final hasPinnedBanner =
              pinnedMessage != null && messages.contains(pinnedMessage);
          _messageItemKeys.retainIds(messages.map((message) => message.id));

          // 使用 Opacity 替代 AnimatedOpacity，避免键盘动画期间的额外性能开销
          // 只有在初始加载时才需要动画，后续直接使用静态 Opacity
          final messageListWidget = ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              16,
              hasPinnedBanner ? 8 : 12, // 有置顶 banner 时减少顶部间距
              16,
              bottomPadding,
            ),
            itemCount: messages.length,
            // 性能优化：增加缓存范围，减少滚动时的重建
            cacheExtent: 500,
            // 性能优化：消息列表不需要保持状态
            addAutomaticKeepAlives: false,
            // 性能优化：启用重绘边界，减少不必要的重绘
            addRepaintBoundaries: true,
            itemBuilder: (context, index) {
              final message = messages[index];
              final previousMessage = index > 0 ? messages[index - 1] : null;
              final isSelected = _selectedMessageIds.contains(message.id);

              final showTimestamp = message.shouldShowTimestamp(
                previousMessage,
              );
              final dayLabel = message.displayTime;
              final canShowReadReceipts = provider.shouldShowReadReceipts(
                message,
              );
              final shouldAnimateEntry = _messageEntryAnimationIds.contains(
                message.id,
              );

              Widget itemContent = Column(
                children: [
                  if (showTimestamp && dayLabel.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      dayLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _MessageBubble(
                    message: message,
                    onResend: () => provider.resendMessage(message.id),
                    canShowReadReceipts: canShowReadReceipts,
                    onShowReadReceipts: canShowReadReceipts
                        ? () => _showMessageReaders(message)
                        : null,
                    onBubbleTap: _showMessageActions,
                    onQuoteTap: _scrollToMessage,
                    onStartSelection: () => _startMultiSelect(message),
                    onToggleSelection: () => _toggleMessageSelection(message),
                    isSelected: isSelected,
                    multiSelectMode: _multiSelectMode,
                    isHighlighted: _highlightedMessageId == message.id,
                  ),
                  // 消息反应标签
                  if (message.reactions != null &&
                      message.reactions!.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        top: 6,
                        left: message.isSelf ? 0 : 56,
                        right: message.isSelf ? 56 : 0,
                      ),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: message.isSelf
                            ? WrapAlignment.end
                            : WrapAlignment.start,
                        children: message.reactions!.map((reaction) {
                          return InkWell(
                            onTap: _chatProvider.isRelayOnlyMode
                                ? null
                                : () => _handleReactionTagTap(
                                    message,
                                    reaction.reactionKey,
                                  ),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: reaction.hasSelf
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: reaction.hasSelf
                                    ? Border.all(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.3,
                                        ),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    reaction.reactionKey,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${reaction.count}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              );

              if (shouldAnimateEntry) {
                itemContent = _MessageEntryTransition(child: itemContent);
              }

              return RepaintBoundary(
                key: _messageItemKeys.keyFor(message.id),
                child: itemContent,
              );
            },
          );

          content = _messageListOpacity < 1.0
              ? AnimatedOpacity(
                  opacity: _messageListOpacity,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: messageListWidget,
                )
              : Opacity(opacity: 1.0, child: messageListWidget);
        }

        return content;
      },
    );
  }
}

class _MessageEntryTransition extends StatefulWidget {
  const _MessageEntryTransition({required this.child});

  final Widget child;

  @override
  State<_MessageEntryTransition> createState() =>
      _MessageEntryTransitionState();
}

class _MessageEntryTransitionState extends State<_MessageEntryTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curve);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}

/// 消息气泡

class _ScrollToBottomButton extends StatelessWidget {
  const _ScrollToBottomButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 28,
            color: Color(0xFF1F1F1F),
          ),
        ),
      ),
    );
  }
}
