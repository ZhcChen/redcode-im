import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/message_service.dart';
import 'providers/chat_provider.dart';
import 'models/chat_model.dart';
import 'models/message_model.dart';
import 'models/message_reader.dart';

class ChatDetailPageV2 extends StatefulWidget {
  const ChatDetailPageV2({
    super.key,
    required this.roomId,
    required this.chatName,
    this.chatAvatar,
    this.chatType = ChatType.single,
    this.chatProvider,
  });

  final String roomId;
  final String chatName;
  final String? chatAvatar;
  final ChatType chatType;
  final ChatProvider? chatProvider;

  @override
  State<ChatDetailPageV2> createState() => _ChatDetailPageV2State();
}

enum _MessageAction { copy, quote, forward, pin, delete }

class _MessageActionEntry {
  const _MessageActionEntry({
    required this.action,
    required this.label,
    required this.icon,
    this.danger = false,
  });

  final _MessageAction action;
  final String label;
  final IconData icon;
  final bool danger;
}

class _ChatDetailPageV2State extends State<ChatDetailPageV2>
    with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final GlobalKey _inputAreaKey = GlobalKey();
  double _lastKeyboardInset = 0.0;
  double _keyboardInset = 0.0; // 当前键盘高度，用于避免频繁查询 MediaQuery
  Timer? _keyboardUpdateTimer; // 防抖定时器，减少键盘动画期间的 setState 调用

  late ChatProvider _chatProvider;
  late final bool _ownsProvider;
  bool _isAtBottom = true;
  bool _skipNextScrollAnimation = true;
  double _messageListOpacity = 0.0;
  String? _lastMessageId;
  int _lastMessageCount = 0;
  Message? _quotedMessage;
  final Map<String, GlobalKey> _messageItemKeys = {};

  bool _showEmojiPanel = false;
  bool _showMorePanel = false;
  bool _memberCountLoading = false;
  bool _memberCountLoadFailed = false;
  bool _wasKeyboardVisible = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsProvider = widget.chatProvider == null;
    _chatProvider = widget.chatProvider ?? ChatProvider();
    _initChat();
    _scrollController.addListener(_onScroll);

    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus && (_showEmojiPanel || _showMorePanel)) {
        setState(() {
          _showEmojiPanel = false;
          _showMorePanel = false;
        });
      }
    });
  }

  Future<void> _initChat() async {
    // 创建Chat对象
    final chat = Chat(
      id: widget.roomId,
      roomId: widget.roomId,
      name: widget.chatName,
      avatar: widget.chatAvatar,
      type: widget.chatType,
      lastMessage: '',
      lastMessageTime: DateTime.now(),
    );

    // 进入聊天室（首次渲染完成后再加载历史，减少闪动）
    await _chatProvider.enterChatRoom(
      widget.roomId,
      chat,
      delayHistoryLoad: true,
    );

    if (!mounted) return;
    final hasCachedMessages = _chatProvider.messages.isNotEmpty;
    setState(() {
      _messageListOpacity = hasCachedMessages ? 1.0 : 0.0;
    });

    // 页面进入后自动滚动到底部（无动画）
    if (hasCachedMessages) {
      _scrollToBottom(animated: false);
    }

    if (widget.chatType == ChatType.group) {
      await _loadMemberCount();
    }
  }

  @override
  void dispose() {
    _keyboardUpdateTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _chatProvider.leaveChatRoom();
    if (_ownsProvider) {
      _chatProvider.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final viewInset = view.viewInsets.bottom / view.devicePixelRatio;
    
    // 使用防抖机制，减少键盘动画期间的频繁 setState
    // 限制更新频率为每 16ms 一次（约 60fps），避免过度重建
    if ((viewInset - _keyboardInset).abs() > 0.5) {
      _keyboardUpdateTimer?.cancel();
      _keyboardUpdateTimer = Timer(const Duration(milliseconds: 16), () {
        if (!mounted) return;
        // 使用 scheduleMicrotask 确保在下一帧更新，避免阻塞当前帧
        scheduleMicrotask(() {
          if (!mounted) return;
          setState(() {
            _keyboardInset = viewInset;
          });
        });
        
        if (viewInset > _lastKeyboardInset) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _scrollToBottom(animated: false);
          });
        }
      });
    }
    _lastKeyboardInset = viewInset;
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _chatProvider.sendTextMessage(text, quotedMessage: _quotedMessage);
    if (_quotedMessage != null) {
      setState(() => _quotedMessage = null);
    }
    _textController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_inputFocusNode);
    });
    _scrollToBottom(animated: false);
  }

  void _scrollToBottom({int retry = 0, bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) {
        if (retry < 10) {
          _scrollToBottom(retry: retry + 1, animated: animated);
        }
        return;
      }

      final position = _scrollController.position;
      final target = position.maxScrollExtent;
      final shouldAnimate = animated && !_skipNextScrollAnimation;
      _skipNextScrollAnimation = false;

      if (shouldAnimate) {
        try {
          _scrollController
              .animateTo(
                target,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
              )
              .whenComplete(_settleToBottom);
        } catch (_) {
          if (retry < 5) {
            _scrollToBottom(retry: retry + 1, animated: animated);
          }
        }
      } else {
        if ((position.pixels - target).abs() > 0.5) {
          _scrollController.jumpTo(target);
        }
        _settleToBottom();
      }
    });
  }

  void _settleToBottom({int attempt = 0}) {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final remaining = position.maxScrollExtent - position.pixels;
    if (remaining <= 0.5) {
      return;
    }

    if (attempt >= 8) {
      final lastId = _lastMessageId;
      if (lastId != null) {
        final key = _messageItemKeys[lastId];
        final targetContext = key?.currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            duration: Duration.zero,
            alignment: 1.0,
          );
        }
      }
      return;
    }

    _scrollController.jumpTo(position.maxScrollExtent);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _settleToBottom(attempt: attempt + 1);
    });
  }

  Future<void> _loadMemberCount({bool forceRefresh = false}) async {
    if (widget.chatType != ChatType.group) return;
    if (_memberCountLoading && !forceRefresh) return;

    setState(() {
      _memberCountLoading = true;
      _memberCountLoadFailed = false;
    });

    try {
      await _chatProvider.getRoomMemberCount(
        widget.roomId,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _memberCountLoadFailed = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _memberCountLoadFailed = true;
      });
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(SnackBar(content: Text('加载群成员失败：$e')));
    } finally {
      if (mounted) {
        setState(() {
          _memberCountLoading = false;
        });
      } else {
        _memberCountLoading = false;
      }
    }
  }

  String _groupMemberSubtitle(ChatProvider provider) {
    final cachedCount = provider.cachedMemberCount(widget.roomId);
    if (cachedCount != null) {
      return '共$cachedCount人';
    }
    if (_memberCountLoadFailed) {
      return '成员加载失败，点击重试';
    }
    return '成员加载中...';
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = _keyboardInset > 0.0;

    if (keyboardVisible && !_wasKeyboardVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToBottom(animated: false);
      });
    }
    _wasKeyboardVisible = keyboardVisible;

    final double listBottomPadding = (_showEmojiPanel || _showMorePanel)
        ? 16.0
        : 12.0;

    return ChangeNotifierProvider.value(
      value: _chatProvider,
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          top: true,
          bottom: false, // 禁用底部 SafeArea，减少键盘动画时的布局计算
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: RepaintBoundary(
                  child: _buildMessageList(listBottomPadding),
                ),
              ),
              RepaintBoundary(
                child: _buildInputArea(),
              ),
              if (_showEmojiPanel)
                _EmojiPanel(onEmojiSelected: _handleEmojiSelected),
              if (_showMorePanel)
                _MoreActionsPanel(onActionSelected: _handleMoreAction),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        final showUpdating = provider.isLoading && provider.messages.isEmpty;
        final statusStyle = theme.textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        );

        return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _handleBackNavigation,
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 头像
              if (widget.chatAvatar != null) ...[
                CircleAvatar(
                  radius: 18,
                  backgroundImage: AssetImage(widget.chatAvatar!),
                ),
                const SizedBox(width: 12),
              ],

              // 标题
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chatName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.chatType == ChatType.group) ...[
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: _memberCountLoadFailed
                            ? () => _loadMemberCount(forceRefresh: true)
                            : null,
                        child: Text(
                          _groupMemberSubtitle(provider),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            decoration: _memberCountLoadFailed
                                ? TextDecoration.underline
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      child: child,
                    ),
                  );
                },
                child: showUpdating
                    ? Padding(
                        key: const ValueKey('header-updating'),
                        padding: const EdgeInsets.only(left: 8),
                        child: Text('(更新中...)', style: statusStyle),
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('header-updating-off'),
                      ),
              ),

              // 更多按钮
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _showChatInfo,
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.more_horiz,
                      size: 24,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleBackNavigation() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

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
            setState(() {
              _messageListOpacity = 1.0;
            });
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

          // 使用 Opacity 替代 AnimatedOpacity，避免键盘动画期间的额外性能开销
          // 只有在初始加载时才需要动画，后续直接使用静态 Opacity
          final messageListWidget = ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
              itemCount: messages.length + (hasPinnedBanner ? 1 : 0),
              // 性能优化：增加缓存范围，减少滚动时的重建
              cacheExtent: 500,
              // 性能优化：消息列表不需要保持状态
              addAutomaticKeepAlives: false,
              // 性能优化：启用重绘边界，减少不必要的重绘
              addRepaintBoundaries: true,
              itemBuilder: (context, index) {
                if (hasPinnedBanner && index == 0) {
                  // ignore: unnecessary_non_null_assertion
                  final pinned = pinnedMessage!;
                  return RepaintBoundary(
                    child: _PinnedMessageBanner(
                      message: pinned,
                      onTap: () => _scrollToMessage(pinned.id),
                      onUnpin: () => unawaited(_togglePinMessage(pinned)),
                    ),
                  );
                }

                final effectiveIndex = hasPinnedBanner ? index - 1 : index;
                final message = messages[effectiveIndex];
                final previousMessage = effectiveIndex > 0
                    ? messages[effectiveIndex - 1]
                    : null;
                final itemKey = _messageItemKeys.putIfAbsent(
                  message.id,
                  () => GlobalKey(),
                );

                final showTimestamp = message.shouldShowTimestamp(
                  previousMessage,
                );
                final dayLabel = message.displayTime;
                final canShowReadReceipts = provider.shouldShowReadReceipts(
                  message,
                );

                // 使用 RepaintBoundary 包裹每个消息项，避免不必要的重绘
                return RepaintBoundary(
                  key: itemKey,
                  child: Column(
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
                      ),
                    ],
                  ),
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
              : Opacity(
                  opacity: 1.0,
                  child: messageListWidget,
                );
        }

        return content;
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      key: _inputAreaKey,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 优化 AnimatedSwitcher：使用更简单的动画，减少键盘动画期间的性能开销
            // 移除 ClipRect 以减少额外的裁剪计算
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              // 简化 transition，只使用 FadeTransition，移除 SizeTransition 以减少布局计算
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                  alignment: Alignment.bottomCenter,
                );
              },
              child: _quotedMessage == null
                  ? const SizedBox.shrink(key: ValueKey('empty'))
                  : _QuotePreviewBar(
                      key: ValueKey(_quotedMessage!.id),
                      message: _quotedMessage!,
                      onClose: _clearQuotedMessage,
                      onTap: () => _scrollToMessage(_quotedMessage!.id),
                    ),
            ),
            if (_quotedMessage != null) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _IconButton(icon: AppAssets.iconVoice, onTap: _toggleVoice),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 36,
                      maxHeight: 112,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _inputFocusNode,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _sendMessage(),
                      onEditingComplete: () {},
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        hintText: '发送消息...',
                        hintStyle: TextStyle(color: AppColors.textTertiary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _IconButton(
                  icon: AppAssets.iconEmoji,
                  isActive: _showEmojiPanel,
                  onTap: _toggleEmoji,
                ),
                const SizedBox(width: 4),
                // 使用 Selector 替代 Consumer，只在 isSending 变化时重建，减少键盘动画时的重建
                Selector<ChatProvider, bool>(
                  selector: (_, provider) => provider.isSending,
                  builder: (context, isSending, child) {
                    final hasText = _textController.text.trim().isNotEmpty;

                    if (hasText) {
                      return Material(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: isSending ? null : _sendMessage,
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            child: isSending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      );
                    }

                    return _IconButton(
                      icon: AppAssets.iconAdd,
                      isActive: _showMorePanel,
                      onTap: _toggleMore,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleVoice() {
    // TODO: 实现语音功能
    debugPrint('Toggle voice');
  }

  void _toggleEmoji() {
    setState(() {
      _showEmojiPanel = !_showEmojiPanel;
      _showMorePanel = false;
    });

    if (_showEmojiPanel) {
      FocusScope.of(context).unfocus();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottom(animated: false);
    });
  }

  void _toggleMore() {
    setState(() {
      _showMorePanel = !_showMorePanel;
      _showEmojiPanel = false;
    });

    if (_showMorePanel) {
      FocusScope.of(context).unfocus();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottom(animated: false);
    });
  }

  void _clearQuotedMessage() {
    if (_quotedMessage == null) return;
    setState(() => _quotedMessage = null);
  }

  void _scrollToMessage(String messageId) {
    final key = _messageItemKeys[messageId];
    final targetContext = key?.currentContext;
    if (targetContext == null) {
      _handleQuotedMessageNotFound();
      return;
    }

    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      alignment: 0.1,
    );
  }

  void _handleQuotedMessageNotFound() {
    if (!_chatProvider.isLoading) {
      unawaited(_chatProvider.loadMoreMessages(limit: 50));
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      const SnackBar(content: Text('暂未找到被引用的消息，已尝试加载更多历史记录')),
    );
  }

  void _handleEmojiSelected(String emoji) {
    final selection = _textController.selection;
    final text = _textController.text;

    int start = selection.start;
    int end = selection.end;
    if (!selection.isValid || start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }

    final newText = text.replaceRange(start, end, emoji);

    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  void _handleMoreAction(String action) {
    switch (action) {
      case 'album':
        _pickImage();
        break;
      case 'camera':
        _takePhoto();
        break;
      case 'location':
        _shareLocation();
        break;
      case 'file':
        _pickFile();
        break;
    }

    setState(() {
      _showMorePanel = false;
    });
  }

  Future<void> _showMessageActions(
    Offset tapPosition,
    Message message,
    bool isSelf,
  ) async {
    if (mounted && (_showEmojiPanel || _showMorePanel)) {
      setState(() {
        _showEmojiPanel = false;
        _showMorePanel = false;
      });
    }
    final overlay =
        Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    const menuWidth = 176.0;
    const menuPadding = 12.0;
    const actionHeight = 36.0;
    const itemSpacing = 4.0;
    const verticalOffset = 32.0;

    final isTextMessage = message.type == MessageType.text;
    final isPinned = _chatProvider.isMessagePinned(message);
    final actionEntries = <_MessageActionEntry>[];

    if (isTextMessage && !message.isDeleted) {
      actionEntries.add(
        const _MessageActionEntry(
          action: _MessageAction.copy,
          label: '复制文本',
          icon: Icons.copy_rounded,
        ),
      );
    }

    if (!message.isDeleted) {
      actionEntries.add(
        const _MessageActionEntry(
          action: _MessageAction.quote,
          label: '引用',
          icon: Icons.format_quote_rounded,
        ),
      );
    }

    if (isTextMessage && !message.isDeleted) {
      actionEntries.add(
        const _MessageActionEntry(
          action: _MessageAction.forward,
          label: '转发',
          icon: Icons.reply_rounded,
        ),
      );
    }

    if (!message.isDeleted) {
      actionEntries.add(
        _MessageActionEntry(
          action: _MessageAction.pin,
          label: isPinned ? '取消置顶' : '置顶',
          icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
        ),
      );
    }

    actionEntries.add(
      const _MessageActionEntry(
        action: _MessageAction.delete,
        label: '删除',
        icon: Icons.delete_outline,
        danger: true,
      ),
    );

    if (actionEntries.isEmpty) {
      return;
    }

    final menuHeight =
        menuPadding * 2 +
        actionHeight * actionEntries.length +
        itemSpacing * math.max(0, actionEntries.length - 1);

    final media = MediaQuery.of(context);
    final padding = media.padding;
    final availableWidth = overlay.size.width - padding.left - padding.right;
    final availableHeight = overlay.size.height - padding.top - padding.bottom;

    double left = isSelf
        ? tapPosition.dx - padding.left - menuWidth + menuPadding
        : tapPosition.dx - padding.left - menuPadding;
    double maxLeft = availableWidth - menuWidth - 12.0;
    if (maxLeft < 12.0) {
      maxLeft = 12.0;
    }
    left = left.clamp(12.0, maxLeft);

    double effectiveBottom = availableHeight - 12.0;
    if (_inputAreaKey.currentContext != null) {
      final inputBox =
          _inputAreaKey.currentContext!.findRenderObject() as RenderBox?;
      if (inputBox != null && inputBox.hasSize) {
        final inputTopGlobal = inputBox.localToGlobal(Offset.zero).dy;
        final inputTopLocal = inputTopGlobal - padding.top;
        effectiveBottom = math.min(effectiveBottom, inputTopLocal - 12.0);
      }
    }
    if (effectiveBottom < menuHeight + 24.0) {
      effectiveBottom = menuHeight + 24.0;
    }

    double maxTop = effectiveBottom - menuHeight;
    if (maxTop < 12.0) {
      maxTop = 12.0;
    }

    double top = tapPosition.dy - padding.top - verticalOffset;
    if (top > maxTop) {
      top = tapPosition.dy - padding.top - menuHeight - verticalOffset;
    }
    top = top.clamp(12.0, maxTop);

    if (top + menuHeight > effectiveBottom) {
      top = effectiveBottom - menuHeight;
      if (top < 12.0) {
        top = 12.0;
      }
    }

    Widget buildActionButton(
      BuildContext dialogContext,
      String label,
      _MessageAction value, {
      bool danger = false,
      IconData? icon,
    }) {
      final textStyle = TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: danger ? AppColors.danger : AppColors.textPrimary,
      );

      return InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => Navigator.of(dialogContext).pop(value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Icon(
                icon ?? Icons.more_horiz,
                size: 20,
                color: danger ? AppColors.danger : AppColors.iconSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: textStyle)),
            ],
          ),
        ),
      );
    }

    final action = await showGeneralDialog<_MessageAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'message-actions',
      barrierColor: Colors.black.withValues(alpha: 0.03),
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        );
        final scaleAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInBack,
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => Navigator.of(dialogContext).pop(),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                Positioned(
                  left: left + padding.left,
                  top: top + padding.top,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.85,
                      end: 1.0,
                    ).animate(scaleAnimation),
                    alignment: isSelf ? Alignment.topRight : Alignment.topLeft,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      elevation: 4,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: menuWidth,
                          maxWidth: menuWidth,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(menuPadding),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (
                                var i = 0;
                                i < actionEntries.length;
                                i++
                              ) ...[
                                if (i > 0) const SizedBox(height: itemSpacing),
                                buildActionButton(
                                  dialogContext,
                                  actionEntries[i].label,
                                  actionEntries[i].action,
                                  danger: actionEntries[i].danger,
                                  icon: actionEntries[i].icon,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == null || !mounted) return;
    await _handleMessageAction(action, message);
  }

  Future<void> _handleMessageAction(
    _MessageAction action,
    Message message,
  ) async {
    switch (action) {
      case _MessageAction.copy:
        if (message.type == MessageType.text && !message.isDeleted) {
          await Clipboard.setData(ClipboardData(text: message.content));
        }
        break;
      case _MessageAction.quote:
        if (message.isDeleted) {
          return;
        }
        setState(() => _quotedMessage = message);
        FocusScope.of(context).requestFocus(_inputFocusNode);
        break;
      case _MessageAction.forward:
        if (!mounted) return;
        await _forwardMessage(message);
        break;
      case _MessageAction.pin:
        if (!mounted) return;
        await _togglePinMessage(message);
        break;
      case _MessageAction.delete:
        if (!mounted) return;
        await _confirmDeleteMessage(message);
        break;
    }
  }

  Future<void> _forwardMessage(Message message) async {
    if (message.type != MessageType.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前版本仅支持转发文本消息')));
      return;
    }

    final chats = List<Chat>.from(_chatProvider.chats);
    if (chats.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无可转发的会话')));
      return;
    }

    final selectedChat = await showModalBottomSheet<Chat>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final height = MediaQuery.of(sheetContext).size.height * 0.72;
        return SizedBox(
          height: height,
          child: _ForwardTargetSheet(chats: chats, message: message),
        );
      },
    );

    if (!mounted || selectedChat == null) return;

    try {
      await _chatProvider.forwardMessage(message, selectedChat);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已转发到${selectedChat.name}')));
    } on UnsupportedError {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前仅支持转发文本消息')));
    } catch (e) {
      debugPrint('Forward message failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('转发失败，请稍后重试')));
    }
  }

  Future<void> _togglePinMessage(Message message) async {
    final isPinned = _chatProvider.isMessagePinned(message);
    try {
      if (isPinned) {
        await _chatProvider.unpinMessage(message);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已取消置顶')));
      } else {
        await _chatProvider.pinMessage(message);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('消息已置顶')));
      }
    } catch (e) {
      debugPrint('Pin message failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('操作失败，请稍后重试')));
    }
  }

  Future<void> _confirmDeleteMessage(Message message) async {
    final title = message.isDeleted ? '移除消息记录' : '删除消息';
    final contentText = message.isDeleted
        ? '从本地聊天记录中移除这条已删除的消息？'
        : '删除后将在本地隐藏该消息，其他设备暂不会同步，确认删除？';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(contentText),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await _chatProvider.deleteMessage(message);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('消息已删除')));
    } catch (e) {
      debugPrint('Delete message failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试')));
    }
  }

  Future<void> _showMessageReaders(Message message) async {
    final chat = _chatProvider.currentChat;
    if (chat == null || chat.type != ChatType.group) {
      return;
    }

    final cachedCount = _chatProvider.cachedMemberCount(chat.roomId);
    int memberCount = cachedCount ?? 0;

    if (cachedCount == null) {
      try {
        memberCount = await _chatProvider.getRoomMemberCount(chat.roomId);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已读列表获取失败，请稍后重试')));
        return;
      }
    }

    if (memberCount > 100) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('群聊成员超过100人，暂不支持查看详细已读列表')));
      return;
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReadReceiptsSheet(
        provider: _chatProvider,
        message: message,
        totalMembers: memberCount,
      ),
    );
  }

  void _pickImage() async {
    // TODO: 实现图片选择
    debugPrint('Pick image');
  }

  void _takePhoto() async {
    // TODO: 实现拍照
    debugPrint('Take photo');
  }

  void _shareLocation() {
    // TODO: 实现位置分享
    debugPrint('Share location');
  }

  void _pickFile() {
    // TODO: 实现文件选择
    debugPrint('Pick file');
  }

  void _showChatInfo() {
    final chat =
        _chatProvider.currentChat ??
        Chat(
          id: widget.roomId,
          roomId: widget.roomId,
          name: widget.chatName,
          avatar: widget.chatAvatar,
          type: widget.chatType,
          lastMessage: '',
          lastMessageTime: DateTime.now(),
        );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'chat-info',
      barrierColor: const Color(0x99000000),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _ChatInfoDrawer(
          chat: chat,
          provider: _chatProvider,
          onClose: () => Navigator.of(context).pop(),
          onRefreshMembers: widget.chatType == ChatType.group
              ? () => _loadMemberCount(forceRefresh: true)
              : null,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  void _onScroll() {
    final isNearBottom = _isListNearBottom();
    if (isNearBottom != _isAtBottom) {
      setState(() => _isAtBottom = isNearBottom);
    }
  }

  void _processMessages(List<Message> messages) {
    final previousCount = _lastMessageCount;
    final latestId = messages.isNotEmpty ? messages.last.id : null;
    final changed =
        latestId != _lastMessageId || messages.length != _lastMessageCount;

    if (!changed) return;

    final wasAtBottom = _isAtBottom;
    final isNearBottom = _isListNearBottom();
    _isAtBottom = isNearBottom;
    _lastMessageId = latestId;
    _lastMessageCount = messages.length;

    final shouldAutoScroll =
        wasAtBottom || previousCount == 0 || (!_hasScrollableContent());

    if (shouldAutoScroll) {
      _scrollToBottom(animated: false);
    }
  }

  bool _isListNearBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    if (!position.hasPixels) return true;
    final max = position.maxScrollExtent;
    if (max <= 0) return true;
    final offsetFromBottom = max - position.pixels;
    return offsetFromBottom <= 32;
  }

  bool _hasScrollableContent() {
    if (!_scrollController.hasClients) return false;
    final position = _scrollController.position;
    return position.maxScrollExtent > 0;
  }
}

class _ChatInfoDrawer extends StatefulWidget {
  const _ChatInfoDrawer({
    required this.chat,
    required this.provider,
    required this.onClose,
    this.onRefreshMembers,
  });

  final Chat chat;
  final ChatProvider provider;
  final VoidCallback onClose;
  final Future<void> Function()? onRefreshMembers;

  @override
  State<_ChatInfoDrawer> createState() => _ChatInfoDrawerState();
}

class _ChatInfoDrawerState extends State<_ChatInfoDrawer> {
  bool _isMuted = false;
  bool _isPinned = false;
  bool _isForbidden = false;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final strictMinWidth = mq.size.width * 0.9;
    final widthCandidate = mq.size.width * 0.92;
    final double drawerWidth;
    if (strictMinWidth > 335) {
      drawerWidth = widthCandidate.clamp(strictMinWidth, 480);
    } else {
      drawerWidth = widthCandidate.clamp(335, 480);
    }

    final topPadding = mq.padding.top;
    final bottomPadding = mq.padding.bottom;
    final isGroupOwner = widget.chat.extra?['is_owner'] == true ||
        widget.chat.extra?['isOwner'] == true;

    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: drawerWidth,
        height: mq.size.height,
        child: Container(
          color: AppColors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: topPadding,
                color: AppColors.surface,
              ),
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: bottomPadding + 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.chat.type == ChatType.single)
                        _PersonalChatPanel(chat: widget.chat, onClose: widget.onClose)
                      else
                        _GroupChatPanel(
                          chat: widget.chat,
                          provider: widget.provider,
                          onRefreshMembers: widget.onRefreshMembers,
                          onClose: widget.onClose,
                        ),
                      const SizedBox(height: 16),
                      _buildSettingsSection(context, isGroupOwner),
                      if (widget.chat.type == ChatType.group) ...[
                        const SizedBox(height: 24),
                        _buildBottomActions(context, isGroupOwner),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final memberCount = widget.provider.cachedMemberCount(widget.chat.roomId);
    final title = widget.chat.type == ChatType.group
        ? '聊天信息${memberCount != null ? "($memberCount)" : ""}'
        : '聊天详情';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            onPressed: widget.onClose,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, bool isGroupOwner) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (widget.chat.type == ChatType.group && isGroupOwner)
            _SwitchTile(
              label: '禁止发送消息',
              value: _isForbidden,
              onChanged: (value) {
                setState(() => _isForbidden = value);
                debugPrint('Toggle forbidden: $value');
              },
            ),
          _SwitchTile(
            label: '消息免打扰',
            value: _isMuted,
            onChanged: (value) {
              setState(() => _isMuted = value);
              debugPrint('Toggle mute: $value');
            },
          ),
          _SwitchTile(
            label: '置顶聊天',
            value: _isPinned,
            onChanged: (value) {
              setState(() => _isPinned = value);
              debugPrint('Toggle pin: $value');
            },
          ),
          _SettingTile(
            label: '立即投诉举报',
            onTap: () {
              widget.onClose();
              _showReportDialog(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, bool isGroupOwner) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                widget.onClose();
                _showClearMessagesDialog(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBC6847),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '清空聊天记录',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                widget.onClose();
                if (isGroupOwner) {
                  _showDissolveGroupDialog(context);
                } else {
                  _showQuitGroupDialog(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isGroupOwner
                    ? const Color(0xFFBC2222)
                    : const Color(0xFFBC6847),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isGroupOwner ? '解散群组' : '退出群聊',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearMessagesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空聊天记录'),
        content: const Text('确认要清空聊天记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              debugPrint('Clear messages confirmed');
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showQuitGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出群聊'),
        content: const Text('确认要退出群聊吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              debugPrint('Quit group confirmed');
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showDissolveGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解散群组'),
        content: const Text('确认要解散群聊吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              debugPrint('Dissolve group confirmed');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确定要举报他吗？'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: '请输入举报内容',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('再想想'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              debugPrint('Report submitted: ${controller.text}');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

class _PersonalChatPanel extends StatelessWidget {
  const _PersonalChatPanel({required this.chat, required this.onClose});

  final Chat chat;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extra = chat.extra ?? const <String, dynamic>{};
    final nickname =
        extra['friend_nickname'] ??
        extra['friendNickname'] ??
        extra['friend_name'] ??
        extra['friendName'];
    final account = extra['friend_username'] ?? extra['friendUsername'];
    final remark = extra['friend_remark'] ?? extra['remark'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.surfaceMuted,
              child: Text(
                chat.name.isNotEmpty ? chat.name.characters.first : '?',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (remark is String && remark.trim().isNotEmpty)
                    _SubtitleRow(label: '备注', value: remark.trim()),
                  if (nickname is String && nickname.trim().isNotEmpty)
                    _SubtitleRow(label: '昵称', value: nickname.trim()),
                  if (account is String && account.trim().isNotEmpty)
                    _SubtitleRow(label: '账号', value: account.trim()),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _DrawerSection(
          title: '快捷操作',
          children: [
            _DrawerActionTile(
              icon: Icons.person,
              label: '查看资料',
              onTap: () {
                debugPrint('View personal profile');
                onClose();
              },
            ),
            _DrawerActionTile(
              icon: Icons.block,
              label: '屏蔽或删除联系人',
              onTap: () {
                debugPrint('Block or delete contact');
                onClose();
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _GroupChatPanel extends StatelessWidget {
  const _GroupChatPanel({
    required this.chat,
    required this.provider,
    required this.onClose,
    this.onRefreshMembers,
  });

  final Chat chat;
  final ChatProvider provider;
  final VoidCallback onClose;
  final Future<void> Function()? onRefreshMembers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final memberCount = provider.cachedMemberCount(chat.roomId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 群成员网格
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMemberGrid(context),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 群信息设置
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _SettingTile(
                label: '群聊名称',
                value: chat.name,
                onTap: () {
                  onClose();
                  debugPrint('Edit group name');
                },
              ),
              _SettingTile(
                label: '群头像',
                trailing: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.surfaceMuted,
                  backgroundImage: chat.avatar != null
                      ? AssetImage(chat.avatar!)
                      : null,
                  child: chat.avatar == null
                      ? const Icon(Icons.group, size: 20)
                      : null,
                ),
                onTap: () {
                  onClose();
                  debugPrint('Edit group avatar');
                },
              ),
              _SettingTile(
                label: '群公告',
                value: chat.extra?['notice'] as String? ?? '无',
                onTap: () {
                  onClose();
                  debugPrint('Edit group notice');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemberGrid(BuildContext context) {
    // 模拟成员数据
    final members = List.generate(
      8,
      (index) => {
        'name': '成员${index + 1}',
        'avatar': null,
      },
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 12,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: members.length + 2, // +2 for add and remove buttons
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildActionMember(
            context,
            Icons.person_add,
            '添加',
            () => debugPrint('Add member'),
          );
        }
        if (index == 1) {
          return _buildActionMember(
            context,
            Icons.person_remove,
            '移除',
            () => debugPrint('Remove member'),
          );
        }
        final member = members[index - 2];
        return _buildMemberItem(context, member);
      },
    );
  }

  Widget _buildMemberItem(BuildContext context, Map<String, dynamic> member) {
    return GestureDetector(
      onTap: () => debugPrint('Member tapped: ${member['name']}'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.surfaceMuted,
            child: Text(
              member['name'].toString().substring(0, 1),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            member['name'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionMember(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 24,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  const _DrawerSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...children.map(
          (child) =>
              Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
        ),
      ],
    );
  }
}

class _DrawerActionTile extends StatelessWidget {
  const _DrawerActionTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: danger ? AppColors.danger : AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: danger ? AppColors.danger : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubtitleRow extends StatelessWidget {
  const _SubtitleRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '$label：$value',
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
              ),
              if (value != null)
                Flexible(
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              if (trailing != null) trailing!,
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 消息气泡

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.message,
    required this.onResend,
    this.canShowReadReceipts = false,
    this.onShowReadReceipts,
    this.onBubbleTap,
    this.onQuoteTap,
  });

  final Message message;
  final VoidCallback onResend;
  final bool canShowReadReceipts;
  final VoidCallback? onShowReadReceipts;
  final void Function(Offset tapPosition, Message message, bool isSelf)?
  onBubbleTap;
  final void Function(String messageId)? onQuoteTap;

  static const double _avatarRadius = 12;
  static const double _avatarSpacing = 8;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  Message get _message => widget.message;
  bool get _isSelf => _message.isSelf;

  @override
  Widget build(BuildContext context) {
    return _isSelf ? _buildSelfBubble(context) : _buildPeerBubble(context);
  }

  Widget _buildSelfBubble(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: _buildBubbleContainer(
              context,
              child: _buildMessageContent(context),
              isSelf: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeerBubble(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = _message.displaySenderName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(false),
          const SizedBox(width: _MessageBubble._avatarSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 8),
                _buildBubbleContainer(
                  context,
                  child: _buildMessageContent(context),
                  isSelf: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    final body = _buildMessageBody(context);
    final timeRow = _buildBubbleTimeRow(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: _isSelf
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [body, const SizedBox(height: 6), timeRow],
    );
  }

  Widget _buildMessageBody(BuildContext context) {
    final quoted = _message.quotedMessage;
    final children = <Widget>[];

    if (quoted != null) {
      children.add(
        _QuotedMessagePreview(
          quoted: quoted,
          isSelf: _isSelf,
          onTap: widget.onQuoteTap == null
              ? null
              : () => widget.onQuoteTap!(quoted.id),
        ),
      );
      children.add(const SizedBox(height: 6));
    }

    children.add(_buildPrimaryContent(context));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: _isSelf
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildPrimaryContent(BuildContext context) {
    if (_message.isDeleted) {
      return _buildDeletedContent(context);
    }

    Widget content;
    switch (_message.type) {
      case MessageType.text:
        content = Text(
          _message.content,
          style: TextStyle(
            fontSize: 15,
            color: _isSelf ? Colors.white : AppColors.textPrimary,
          ),
        );
        break;
      case MessageType.image:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                _message.content, // TODO: 使用网络图片
                width: 200,
                fit: BoxFit.cover,
              ),
            ),
            if (_message.extra?['caption'] != null) ...[
              const SizedBox(height: 4),
              Text(
                _message.extra!['caption'],
                style: TextStyle(
                  fontSize: 14,
                  color: _isSelf ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ],
        );
        break;
      default:
        content = Text(
          '[不支持的消息类型]',
          style: TextStyle(
            fontSize: 14,
            color: _isSelf ? Colors.white70 : AppColors.textSecondary,
          ),
        );
    }

    final forwardInfo = _message.forwardInfo;
    if (forwardInfo != null) {
      return _ForwardedMessageContent(
        forwardInfo: forwardInfo,
        isSelf: _isSelf,
        child: content,
      );
    }

    return content;
  }

  Widget _buildDeletedContent(BuildContext context) {
    final color = _isSelf ? Colors.white70 : AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.info_outline, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _message.isSelf ? '你已删除这条消息' : '消息已删除',
            style: TextStyle(fontSize: 13, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildBubbleContainer(
    BuildContext context, {
    required Widget child,
    required bool isSelf,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) =>
          widget.onBubbleTap?.call(details.globalPosition, _message, isSelf),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelf ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isSelf ? 16 : 4),
            bottomRight: Radius.circular(isSelf ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildBubbleTimeRow(BuildContext context) {
    final theme = Theme.of(context);
    final timeStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 11,
      color: _isSelf
          ? Colors.white.withValues(alpha: 0.8)
          : AppColors.textQuaternary,
    );

    final timeText = Text(_formatBubbleTime(), style: timeStyle);
    final pinnedIcon = _message.isPinned
        ? Icon(
            Icons.push_pin,
            size: 14,
            color: _isSelf
                ? Colors.white.withValues(alpha: 0.85)
                : AppColors.textTertiary,
          )
        : null;
    Widget? status;
    if (_message.isSelf) {
      final readTap =
          (widget.canShowReadReceipts &&
              _message.status == MessageStatus.read &&
              widget.onShowReadReceipts != null)
          ? widget.onShowReadReceipts
          : null;
      status = _buildStatusIndicator(onReadTap: readTap);
    }

    const double statusRowHeight = 16;
    return SizedBox(
      height: statusRowHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: _isSelf
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(alignment: Alignment.centerLeft, child: timeText),
          if (pinnedIcon != null) ...[const SizedBox(width: 6), pinnedIcon],
          if (status != null) ...[const SizedBox(width: 8), status],
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isSelf) {
    final avatar = _message.senderAvatar;
    if (avatar != null && avatar.isNotEmpty) {
      if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
        return CircleAvatar(
          radius: _MessageBubble._avatarRadius,
          backgroundImage: NetworkImage(avatar),
          backgroundColor: AppColors.surface,
        );
      }
      return CircleAvatar(
        radius: _MessageBubble._avatarRadius,
        backgroundImage: AssetImage(avatar),
        backgroundColor: AppColors.surface,
      );
    }

    final name = _message.displaySenderName.trim();
    final initial = name.isNotEmpty ? name[0] : '?';

    return CircleAvatar(
      radius: _MessageBubble._avatarRadius,
      backgroundColor: isSelf
          ? AppColors.primary.withValues(alpha: 0.85)
          : AppColors.primary.withValues(alpha: 0.12),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 14,
          color: isSelf ? Colors.white : AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget? _buildStatusIndicator({VoidCallback? onReadTap}) {
    const double statusBoxSize = 16;
    Widget wrap(Widget child, {VoidCallback? onTap}) {
      final boxed = SizedBox(
        width: statusBoxSize,
        height: statusBoxSize,
        child: Center(child: child),
      );
      if (onTap != null) {
        return GestureDetector(onTap: onTap, child: boxed);
      }
      return boxed;
    }

    switch (_message.status) {
      case MessageStatus.sending:
        return wrap(
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );
      case MessageStatus.sent:
        return wrap(const Icon(Icons.done, size: 12, color: Colors.white));
      case MessageStatus.delivered:
        return null;
      case MessageStatus.read:
        return wrap(
          const Icon(Icons.done_all, size: 13, color: Colors.white),
          onTap: onReadTap,
        );
      case MessageStatus.failed:
        return wrap(
          const Icon(Icons.priority_high, size: 14, color: Colors.red),
          onTap: widget.onResend,
        );
    }
  }

  String _formatBubbleTime() {
    final local = _message.timestamp.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _QuotedMessagePreview extends StatelessWidget {
  const _QuotedMessagePreview({
    required this.quoted,
    required this.isSelf,
    this.onTap,
  });

  final QuotedMessage quoted;
  final bool isSelf;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = isSelf
        ? Colors.white.withValues(alpha: 0.18)
        : AppColors.surfaceMuted;
    final borderColor = isSelf
        ? Colors.white.withValues(alpha: 0.24)
        : AppColors.divider;
    final titleColor = isSelf
        ? Colors.white.withValues(alpha: 0.85)
        : AppColors.textSecondary;
    final bodyColor = isSelf ? Colors.white : AppColors.textPrimary;

    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatar(),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  quoted.displaySenderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            quoted.previewText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, height: 1.2, color: bodyColor),
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }

  Widget _buildAvatar() {
    const double size = 24;
    final avatar = quoted.senderAvatar;
    if (avatar != null && avatar.isNotEmpty) {
      if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
        return CircleAvatar(
          radius: size / 2,
          backgroundImage: NetworkImage(avatar),
          backgroundColor: AppColors.surface,
        );
      }
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: AssetImage(avatar),
        backgroundColor: AppColors.surface,
      );
    }

    final name = quoted.displaySenderName.trim();
    final initial = name.isNotEmpty ? name[0] : '?';
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: isSelf
          ? AppColors.primary.withValues(alpha: 0.85)
          : AppColors.primary.withValues(alpha: 0.12),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 12,
          color: isSelf ? Colors.white : AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _QuotePreviewBar extends StatelessWidget {
  const _QuotePreviewBar({
    super.key,
    required this.message,
    required this.onClose,
    this.onTap,
  });

  final Message message;
  final VoidCallback onClose;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final quoted = QuotedMessage.fromMessage(message);
    final previewText = '${quoted.displaySenderName}: ${quoted.previewText}';
    final textWidget = Text(
      previewText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
    );

    final content = onTap == null
        ? textWidget
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: textWidget,
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.format_quote_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(child: content),
          GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              width: 28,
              height: 28,
              child: Center(
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForwardedMessageContent extends StatelessWidget {
  const _ForwardedMessageContent({
    required this.forwardInfo,
    required this.isSelf,
    required this.child,
  });

  final ForwardInfo forwardInfo;
  final bool isSelf;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final titleColor = isSelf
        ? Colors.white.withValues(alpha: 0.9)
        : AppColors.textSecondary;
    final subtitleColor = isSelf
        ? Colors.white.withValues(alpha: 0.7)
        : AppColors.textTertiary;

    IconData icon;
    switch (forwardInfo.sourceType) {
      case ForwardSourceType.group:
        icon = Icons.groups_2_rounded;
        break;
      case ForwardSourceType.favorite:
        icon = Icons.star_rounded;
        break;
      case ForwardSourceType.user:
        icon = Icons.person_rounded;
        break;
      case ForwardSourceType.unknown:
        icon = Icons.forward_to_inbox_rounded;
        break;
    }

    final originSender = forwardInfo.originSenderName?.trim();
    final showOriginSender =
        originSender != null &&
        originSender.isNotEmpty &&
        originSender != forwardInfo.displaySourceName;

    return Column(
      crossAxisAlignment: isSelf
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: titleColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '转发自 ${forwardInfo.displaySourceName}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
            ),
          ],
        ),
        if (showOriginSender) ...[
          const SizedBox(height: 2),
          Text(
            '原发送人：$originSender',
            style: TextStyle(fontSize: 11, color: subtitleColor),
          ),
        ],
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _PinnedMessageBanner extends StatelessWidget {
  const _PinnedMessageBanner({
    required this.message,
    required this.onTap,
    required this.onUnpin,
  });

  final Message message;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _buildPreviewText();
    final forwardInfo = message.forwardInfo;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.push_pin, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '已置顶',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (forwardInfo != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '转发自 ${forwardInfo.displaySourceName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: message.isDeleted
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
                splashRadius: 18,
                onPressed: onUnpin,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildPreviewText() {
    if (message.isDeleted) {
      return '消息已删除';
    }
    switch (message.type) {
      case MessageType.text:
        return message.content;
      case MessageType.image:
        return '[图片消息]';
      case MessageType.voice:
        return '[语音消息]';
      case MessageType.video:
        return '[视频消息]';
      case MessageType.file:
        return '[文件消息]';
      case MessageType.system:
        return '[系统消息]';
    }
  }
}

class _ForwardTargetSheet extends StatefulWidget {
  const _ForwardTargetSheet({required this.chats, required this.message});

  final List<Chat> chats;
  final Message message;

  @override
  State<_ForwardTargetSheet> createState() => _ForwardTargetSheetState();
}

class _ForwardTargetSheetState extends State<_ForwardTargetSheet> {
  late List<Chat> _filtered;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.chats;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onKeywordChanged(String value) {
    final keyword = value.trim().toLowerCase();
    setState(() {
      if (keyword.isEmpty) {
        _filtered = widget.chats;
      } else {
        _filtered = widget.chats
            .where((chat) => chat.name.toLowerCase().contains(keyword))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewText = widget.message.isDeleted
        ? '消息已删除'
        : widget.message.type == MessageType.text
        ? widget.message.content
        : '[消息]';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '选择转发目标',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Text(
                previewText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _controller,
                onChanged: _onKeywordChanged,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '搜索会话',
                  icon: Icon(Icons.search, size: 18),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        '未找到匹配的会话',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final chat = _filtered[index];
                        return _ForwardTargetTile(
                          chat: chat,
                          onTap: () => Navigator.of(context).pop(chat),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForwardTargetTile extends StatelessWidget {
  const _ForwardTargetTile({required this.chat, required this.onTap});

  final Chat chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      chat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _typeLabel(chat.type),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    const double size = 40;
    if (chat.avatar != null && chat.avatar!.isNotEmpty) {
      if (chat.avatar!.startsWith('http')) {
        return CircleAvatar(
          radius: size / 2,
          backgroundImage: NetworkImage(chat.avatar!),
          backgroundColor: AppColors.surface,
        );
      }
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: AssetImage(chat.avatar!),
        backgroundColor: AppColors.surface,
      );
    }

    final initial = chat.name.isNotEmpty ? chat.name[0] : '?';
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.surfaceMuted,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  String _typeLabel(ChatType type) {
    switch (type) {
      case ChatType.group:
        return '群聊';
      case ChatType.favorite:
        return '收藏夹';
      case ChatType.single:
        return '单聊';
    }
  }
}

class _ReadReceiptsSheet extends StatefulWidget {
  const _ReadReceiptsSheet({
    required this.provider,
    required this.message,
    required this.totalMembers,
  });

  final ChatProvider provider;
  final Message message;
  final int totalMembers;

  @override
  State<_ReadReceiptsSheet> createState() => _ReadReceiptsSheetState();
}

class _ReadReceiptsSheetState extends State<_ReadReceiptsSheet> {
  List<MessageReader> _readers = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final readers = await widget.provider.fetchMessageReaders(
        widget.message,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _readers = readers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '已读 ${_readers.length}/${widget.totalMembers}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: '刷新',
                      onPressed: _isLoading
                          ? null
                          : () => _load(forceRefresh: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildBody(controller)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ScrollController controller) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('获取已读成员失败', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _load(forceRefresh: true),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_readers.isEmpty) {
      return Center(
        child: Text(
          '暂时没有成员已读',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: ListView.separated(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemBuilder: (context, index) {
          final reader = _readers[index];
          return ListTile(
            leading: _buildAvatar(reader),
            title: Text(reader.displayName),
            subtitle: Text(
              _formatReadTime(reader.readAt),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: _readers.length,
      ),
    );
  }

  Widget _buildAvatar(MessageReader reader) {
    final avatar = reader.avatarUrl;
    if (avatar != null && avatar.isNotEmpty) {
      if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
        return CircleAvatar(backgroundImage: NetworkImage(avatar));
      }
      return CircleAvatar(backgroundImage: AssetImage(avatar));
    }

    final initial = reader.displayName.isNotEmpty
        ? reader.displayName.substring(0, 1)
        : '?';
    return CircleAvatar(
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatReadTime(DateTime time) {
    final now = DateTime.now();
    final sameDay =
        now.year == time.year && now.month == time.month && now.day == time.day;
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    if (sameDay) {
      return '今天 $hh:$mm';
    }
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '$month-$day $hh:$mm';
  }
}

/// 图标按钮
class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  final String icon;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            icon,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(
              isActive ? AppColors.primary : AppColors.iconSecondary,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}

/// 表情面板
class _EmojiPanel extends StatelessWidget {
  const _EmojiPanel({required this.onEmojiSelected});

  final Function(String) onEmojiSelected;

  static const List<String> emojis = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😆',
    '😅',
    '🤣',
    '😂',
    '🙂',
    '🙃',
    '😉',
    '😊',
    '😇',
    '🥰',
    '😍',
    '🤩',
    '😘',
    '😗',
    '😚',
    '😙',
    '😋',
    '😛',
    '😜',
    '🤪',
    '😝',
    '🤑',
    '🤗',
    '🤭',
    '🤫',
    '🤔',
    '🤐',
    '🤨',
    '😐',
    '😑',
    '😶',
    '😏',
    '😒',
    '🙄',
    '😬',
    '🤥',
    '😌',
    '😔',
    '😪',
    '🤤',
    '😴',
    '😷',
    '🤒',
    '🤕',
    '🤢',
    '🤮',
    '🤧',
    '🥵',
    '🥶',
    '🥴',
    '😵',
    '🤯',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: emojis.length,
        itemBuilder: (context, index) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onEmojiSelected(emojis[index]),
              child: Center(
                child: Text(
                  emojis[index],
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 更多操作面板
class _MoreActionsPanel extends StatelessWidget {
  const _MoreActionsPanel({required this.onActionSelected});

  final Function(String) onActionSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ActionItem(
            icon: Icons.photo,
            label: '相册',
            onTap: () => onActionSelected('album'),
          ),
          _ActionItem(
            icon: Icons.camera_alt,
            label: '拍摄',
            onTap: () => onActionSelected('camera'),
          ),
          _ActionItem(
            icon: Icons.location_on,
            label: '位置',
            onTap: () => onActionSelected('location'),
          ),
          _ActionItem(
            icon: Icons.folder,
            label: '文件',
            onTap: () => onActionSelected('file'),
          ),
        ],
      ),
    );
  }
}

/// 操作项
class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 28, color: AppColors.iconPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
