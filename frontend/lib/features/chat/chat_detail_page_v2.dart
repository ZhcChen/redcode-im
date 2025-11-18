import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:provider/provider.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_config.dart';
import '../../core/services/message_service.dart';
import '../../core/services/emoji_pack_service.dart';
import '../../core/services/emoji_item_service.dart';
import '../../core/widgets/tip_dialog.dart';
import '../../features/emoji/models/emoji_pack_models.dart';
import 'providers/chat_provider.dart';
import 'models/chat_model.dart';
import 'models/message_model.dart';
import 'models/message_reader.dart';
import 'group_settings_page.dart';

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
    _dispatchSend(text: text);
  }

  Future<void> _dispatchSend({
    String? text,
    List<MessageAttachmentDraft> attachments = const [],
  }) async {
    final trimmed = text?.trim();
    if ((trimmed == null || trimmed.isEmpty) && attachments.isEmpty) {
      return;
    }

    try {
      await _chatProvider.sendRichMessage(
        text: trimmed,
        attachments: attachments,
        quotedMessage: _quotedMessage,
      );
      if (!mounted) return;
      if (trimmed != null && trimmed.isNotEmpty) {
        _textController.clear();
      }
      if (_quotedMessage != null) {
        setState(() => _quotedMessage = null);
      }
      setState(() {
        _showEmojiPanel = false;
        _showMorePanel = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        FocusScope.of(context).requestFocus(_inputFocusNode);
        _scrollToBottom(animated: false);
      });
    } catch (error) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(SnackBar(content: Text('发送消息失败：$error')));
    }
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: ChangeNotifierProvider.value(
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
                RepaintBoundary(child: _buildInputArea()),
                if (_showEmojiPanel)
                  _EmojiPanel(onEmojiSelected: _handleEmojiSelected),
                if (_showMorePanel)
                  _MoreActionsPanel(onActionSelected: _handleMoreAction),
              ],
            ),
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
              : Opacity(opacity: 1.0, child: messageListWidget);
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
                return FadeTransition(opacity: animation, child: child);
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
            ChatInputWidget(
              controller: _textController,
              focusNode: _inputFocusNode,
              onSendMessage: _sendMessage,
              onToggleVoice: _toggleVoice,
              onToggleEmoji: _toggleEmoji,
              onToggleMore: _toggleMore,
              showEmojiPanel: _showEmojiPanel,
              showMorePanel: _showMorePanel,
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

  void _showErrorSnack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleEmojiSelected(String emoji) {
    // 判断是图片 URL 还是 emoji 字符
    final isImageUrl =
        emoji.startsWith('http://') || emoji.startsWith('https://');

    if (isImageUrl) {
      // 图片表情：下载图片并作为图片消息发送
      unawaited(_sendEmojiImage(emoji));
    } else {
      // Emoji 字符：插入到输入框
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
  }

  Future<void> _sendEmojiImage(String imageUrl) async {
    try {
      // 下载表情图片
      final response = await http.get(Uri.parse(imageUrl));

      if (response.statusCode != 200) {
        throw Exception('下载表情图片失败: ${response.statusCode}');
      }

      // 获取 content type
      final contentType =
          response.headers['content-type'] ??
          response.headers['Content-Type'] ??
          'image/png';

      // 从 URL 推断文件扩展名
      String fileName = 'emoji.png';
      try {
        final uri = Uri.parse(imageUrl);
        final pathname = uri.path;
        final match = RegExp(
          r'\.(gif|jpg|jpeg|png|webp)$',
          caseSensitive: false,
        ).firstMatch(pathname);
        if (match != null) {
          fileName = 'emoji.${match.group(1)}';
        }
      } catch (e) {
        // 如果 URL 解析失败，使用默认文件名
      }

      // 保存到临时文件
      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File(p.join(tempDir.path, fileName));
      await tempFile.writeAsBytes(response.bodyBytes);

      // 读取图片尺寸
      final bytes = await tempFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final width = image.width;
      final height = image.height;
      image.dispose();
      codec.dispose();

      // 创建图片附件草稿
      final draft = MessageAttachmentDraft(
        type: MessagePartType.image,
        file: tempFile,
        displayName: fileName,
        mime: contentType.toLowerCase(),
        width: width,
        height: height,
      );

      // 发送消息
      final text = _textController.text.trim();
      await _dispatchSend(
        text: text.isNotEmpty ? text : null,
        attachments: [draft],
      );

      // 清理临时目录（延迟清理，确保文件已上传）
      Future.delayed(const Duration(seconds: 5), () {
        try {
          tempDir.delete(recursive: true);
        } catch (e) {
          // 忽略清理错误
        }
      });
    } catch (error) {
      if (!mounted) return;
      _showErrorSnack('发送表情失败：$error');
    }
  }

  void _handleMoreAction(String action) {
    switch (action) {
      case 'album':
        unawaited(_pickImage());
        break;
      case 'camera':
        unawaited(_takePhoto());
        break;
      case 'file':
        unawaited(_pickFile());
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final files = await picker.pickMultiImage(
        imageQuality: 90,
        maxWidth: 4096,
        maxHeight: 4096,
      );
      if (files == null || files.isEmpty) {
        return;
      }

      final drafts = <MessageAttachmentDraft>[];
      for (final file in files) {
        drafts.add(await _createImageDraft(file));
      }

      final text = _textController.text.trim();
      await _dispatchSend(
        text: text.isNotEmpty ? text : null,
        attachments: drafts,
      );
    } on PlatformException catch (error) {
      _showErrorSnack('访问相册失败：${error.message ?? error.code}');
    } catch (error) {
      _showErrorSnack('处理图片失败：$error');
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    try {
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 4096,
        maxHeight: 4096,
      );
      if (photo == null) {
        return;
      }

      final draft = await _createImageDraft(photo);
      final text = _textController.text.trim();
      await _dispatchSend(
        text: text.isNotEmpty ? text : null,
        attachments: [draft],
      );
    } on PlatformException catch (error) {
      _showErrorSnack('启动相机失败：${error.message ?? error.code}');
    } catch (error) {
      _showErrorSnack('处理照片失败：$error');
    }
  }

  Future<void> _pickFile() async {
    try {
      final files = await openFiles(
        acceptedTypeGroups: const [XTypeGroup(label: 'all-files')],
      );
      if (files.isEmpty) {
        return;
      }

      final drafts = <MessageAttachmentDraft>[];
      for (final file in files) {
        drafts.add(await _createFileDraft(file));
      }

      final text = _textController.text.trim();
      await _dispatchSend(
        text: text.isNotEmpty ? text : null,
        attachments: drafts,
      );
    } on PlatformException catch (error) {
      _showErrorSnack('访问文件失败：${error.message ?? error.code}');
    } catch (error) {
      _showErrorSnack('处理文件失败：$error');
    }
  }

  Future<MessageAttachmentDraft> _createImageDraft(XFile source) async {
    final file = await _materializeXFile(source);
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final width = image.width;
    final height = image.height;
    image.dispose();
    codec.dispose();

    final mimeType = (source.mimeType ?? lookupMimeType(file.path) ?? 'image/*')
        .toLowerCase();
    if (!AppConfig.allowedImageMimeTypes.contains(mimeType)) {
      throw StateError('暂不支持该图片格式 ($mimeType)');
    }

    return MessageAttachmentDraft(
      type: MessagePartType.image,
      file: file,
      displayName: p.basename(file.path),
      mime: mimeType,
      width: width,
      height: height,
    );
  }

  Future<MessageAttachmentDraft> _createFileDraft(XFile source) async {
    final file = await _materializeXFile(source);
    final mimeType =
        (source.mimeType ??
                lookupMimeType(file.path) ??
                'application/octet-stream')
            .toLowerCase();

    late final MessagePartType partType;
    if (AppConfig.allowedVideoMimeTypes.contains(mimeType)) {
      partType = MessagePartType.video;
    } else if (AppConfig.allowedAudioMimeTypes.contains(mimeType)) {
      partType = MessagePartType.audio;
    } else if (AppConfig.allowedFileMimeTypes.contains(mimeType)) {
      partType = MessagePartType.file;
    } else {
      throw StateError('暂不支持该文件类型 ($mimeType)');
    }

    return MessageAttachmentDraft(
      type: partType,
      file: file,
      displayName: p.basename(file.path),
      mime: mimeType,
    );
  }

  Future<File> _materializeXFile(XFile source) async {
    if (source.path.isNotEmpty) {
      final file = File(source.path);
      if (await file.exists()) {
        return file;
      }
    }

    final tempDir = await getTemporaryDirectory();
    final target = File(p.join(tempDir.path, source.name));
    await target.writeAsBytes(await source.readAsBytes(), flush: true);
    return target;
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

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            GroupSettingsPage(chat: chat, chatProvider: _chatProvider),
      ),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth * 0.8;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
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
    debugPrint('========== _buildPrimaryContent 开始 ==========');
    debugPrint('消息ID: ${_message.id}');
    debugPrint('消息类型: ${_message.type}');
    debugPrint('消息内容: "${_message.content}"');
    debugPrint('消息parts数量: ${_message.parts.length}');

    if (_message.isDeleted) {
      debugPrint('消息已删除');
      return _buildDeletedContent(context);
    }

    final parts = [..._message.parts]
      ..sort((a, b) => a.position.compareTo(b.position));

    debugPrint('排序后的parts数量: ${parts.length}');
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      debugPrint(
        '  part[$i]: type=${part.type}, position=${part.position}, text="${part.text}", attachment=${part.attachment != null}',
      );
      if (part.attachment != null) {
        debugPrint(
          '    attachment: key=${part.attachment!.key}, name=${part.attachment!.name}',
        );
      }
    }

    if (parts.isNotEmpty) {
      debugPrint('使用parts渲染消息');
      final widgets = <Widget>[];
      for (final part in parts) {
        final widget = _buildPartWidget(context, part);
        if (widget == null) {
          debugPrint('  part ${part.type} 返回null，跳过');
          continue;
        }
        if (widgets.isNotEmpty) {
          widgets.add(const SizedBox(height: 8));
        }
        widgets.add(widget);
      }

      if (widgets.isNotEmpty) {
        debugPrint('使用parts渲染，共${widgets.length}个widget');
        debugPrint('========== _buildPrimaryContent 结束（使用parts）==========');
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: _isSelf
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: widgets,
        );
      }
    }

    debugPrint('使用legacy content渲染');
    debugPrint('========== _buildPrimaryContent 结束（使用legacy）==========');
    return _buildLegacyContent(context);
  }

  Widget _buildLegacyContent(BuildContext context) {
    debugPrint('========== _buildLegacyContent 开始 ==========');
    debugPrint('消息类型: ${_message.type}');
    debugPrint('消息内容: "${_message.content}"');

    Widget content;
    switch (_message.type) {
      case MessageType.text:
        debugPrint('处理文本消息');
        content = _buildTextWithEmojis(_message.content, isSelf: _isSelf);
        break;
      case MessageType.image:
        content = Text(
          '[图片]',
          style: TextStyle(
            fontSize: 15,
            color: _isSelf ? Colors.white : AppColors.textPrimary,
          ),
        );
        break;
      case MessageType.video:
        content = Text(
          '[视频]',
          style: TextStyle(
            fontSize: 15,
            color: _isSelf ? Colors.white : AppColors.textPrimary,
          ),
        );
        break;
      case MessageType.audio:
        content = Text(
          '[语音]',
          style: TextStyle(
            fontSize: 15,
            color: _isSelf ? Colors.white : AppColors.textPrimary,
          ),
        );
        break;
      case MessageType.file:
        content = Text(
          '[文件]',
          style: TextStyle(
            fontSize: 15,
            color: _isSelf ? Colors.white : AppColors.textPrimary,
          ),
        );
        break;
      case MessageType.system:
        content = Text(
          _message.content,
          style: TextStyle(
            fontSize: 14,
            color: _isSelf ? Colors.white70 : AppColors.textSecondary,
          ),
        );
        break;
      case MessageType.mixed:
        content = Text(
          _message.content,
          style: TextStyle(
            fontSize: 15,
            color: _isSelf ? Colors.white : AppColors.textPrimary,
          ),
        );
        break;
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

  Widget? _buildPartWidget(BuildContext context, MessagePart part) {
    debugPrint('========== _buildPartWidget 开始 ==========');
    debugPrint('part类型: ${part.type}');
    debugPrint('part文本: "${part.text}"');
    debugPrint('part attachment: ${part.attachment != null}');

    switch (part.type) {
      case MessagePartType.text:
        final text = part.text?.trim();
        debugPrint('处理文本part，文本: "$text"');
        if (text == null || text.isEmpty) {
          debugPrint('文本为空，返回null');
          return null;
        }
        debugPrint('调用_buildTextWithEmojis处理文本part');
        return _buildTextWithEmojis(text, isSelf: _isSelf);
      case MessagePartType.image:
        return _AttachmentImageView(
          message: _message,
          part: part,
          isSelf: _isSelf,
        );
      case MessagePartType.video:
        return _AttachmentFileTile(
          message: _message,
          part: part,
          isSelf: _isSelf,
          icon: Icons.movie,
          fallbackLabel: '视频',
        );
      case MessagePartType.audio:
        return _AttachmentFileTile(
          message: _message,
          part: part,
          isSelf: _isSelf,
          icon: Icons.audiotrack,
          fallbackLabel: '语音',
        );
      case MessagePartType.file:
        return _AttachmentFileTile(
          message: _message,
          part: part,
          isSelf: _isSelf,
          icon: Icons.insert_drive_file,
          fallbackLabel: '文件',
        );
    }
  }

  Widget _buildTextWithEmojis(String text, {required bool isSelf}) {
    debugPrint('========== _buildTextWithEmojis 开始 ==========');
    debugPrint('输入文本: "$text"');
    debugPrint('文本长度: ${text.length}');
    debugPrint('isSelf: $isSelf');

    // 识别文本中的表情URL（http://或https://开头的URL）
    // 更精确的正则：匹配完整的URL，包括可能的查询参数和片段
    final emojiUrlPattern = RegExp(
      r'(https?://[^\s<>"{}|\\^`\[\]]+)',
      caseSensitive: false,
    );
    final matches = emojiUrlPattern.allMatches(text);

    debugPrint('正则匹配结果: ${matches.length} 个匹配');
    for (final match in matches) {
      debugPrint('  匹配[${match.start}-${match.end}]: "${match.group(0)}"');
    }

    if (matches.isEmpty) {
      // 没有表情URL，直接显示文本
      debugPrint('没有找到URL，直接显示文本');
      debugPrint('========== _buildTextWithEmojis 结束（无URL）==========');
      return Text(
        text,
        style: TextStyle(
          fontSize: 15,
          color: isSelf ? Colors.white : AppColors.textPrimary,
        ),
      );
    }

    debugPrint('找到 ${matches.length} 个URL，开始构建混合内容');

    // 有表情URL，需要混合显示文本和图片
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // 添加匹配前的文本
      if (match.start > lastEnd) {
        final beforeText = text.substring(lastEnd, match.start);
        debugPrint('添加文本片段: "$beforeText"');
        spans.add(
          TextSpan(
            text: beforeText,
            style: TextStyle(
              fontSize: 15,
              color: isSelf ? Colors.white : AppColors.textPrimary,
            ),
          ),
        );
      }

      // 添加表情图片
      final emojiUrl = match.group(0)!;
      debugPrint('添加表情图片组件，URL: "$emojiUrl"');
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _CachedEmojiInText(imageUrl: emojiUrl, size: 24.0),
        ),
      );

      lastEnd = match.end;
    }

    // 添加剩余的文本
    if (lastEnd < text.length) {
      final afterText = text.substring(lastEnd);
      debugPrint('添加剩余文本: "$afterText"');
      spans.add(
        TextSpan(
          text: afterText,
          style: TextStyle(
            fontSize: 15,
            color: isSelf ? Colors.white : AppColors.textPrimary,
          ),
        ),
      );
    }

    debugPrint('总共构建了 ${spans.length} 个span');
    debugPrint('========== _buildTextWithEmojis 结束 ==========');
    return Text.rich(TextSpan(children: spans));
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
            topLeft: Radius.circular(isSelf ? 16 : 0),
            topRight: const Radius.circular(16),
            bottomLeft: const Radius.circular(16),
            bottomRight: Radius.circular(isSelf ? 0 : 16),
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
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

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
      case MessageType.audio:
        return '[语音消息]';
      case MessageType.video:
        return '[视频消息]';
      case MessageType.file:
        return '[文件消息]';
      case MessageType.system:
        return '[系统消息]';
      case MessageType.mixed:
        return '[多媒体消息]';
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

/// 聊天输入框组件
class ChatInputWidget extends StatefulWidget {
  const ChatInputWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSendMessage,
    required this.onToggleVoice,
    required this.onToggleEmoji,
    required this.onToggleMore,
    required this.showEmojiPanel,
    required this.showMorePanel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSendMessage;
  final VoidCallback onToggleVoice;
  final VoidCallback onToggleEmoji;
  final VoidCallback onToggleMore;
  final bool showEmojiPanel;
  final bool showMorePanel;

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 语音按钮
        _buildVoiceButton(),

        const SizedBox(width: 8),

        // 文本输入框
        Expanded(child: _buildTextInput()),

        const SizedBox(width: 8),

        // 表情按钮
        _buildEmojiButton(),

        const SizedBox(width: 4),

        // 发送/更多按钮
        _buildSendOrMoreButton(),
      ],
    );
  }

  Widget _buildVoiceButton() {
    return _IconButton(icon: AppAssets.iconVoice, onTap: widget.onToggleVoice);
  }

  Widget _buildTextInput() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: 200.sp, // 只限制最大高度，允许自由扩展
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline, // 多行模式，回车换行
        minLines: 1,
        maxLines: null, // 允许自动扩展
        textAlignVertical: TextAlignVertical.center, // 单行时垂直居中
        onSubmitted: (_) => widget.onSendMessage(),
        onEditingComplete: () {},
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.textPrimary,
          height: 1.4, // 设置行高，改善多行显示
        ),
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.zero, // 移除内边距，由外层 Container 控制
          isDense: true, // 紧凑模式
          border: InputBorder.none,
          hintText: '发送消息...',
          hintStyle: TextStyle(color: AppColors.textTertiary),
        ),
      ),
    );
  }

  Widget _buildEmojiButton() {
    return _IconButton(
      icon: AppAssets.iconEmoji,
      isActive: widget.showEmojiPanel,
      onTap: widget.onToggleEmoji,
    );
  }

  Widget _buildSendOrMoreButton() {
    return Selector<ChatProvider, bool>(
      selector: (_, provider) => provider.isSending,
      builder: (context, isSending, child) {
        final hasText = widget.controller.text.trim().isNotEmpty;

        if (hasText) {
          return _buildSendButton(isSending);
        }

        return _buildMoreButton();
      },
    );
  }

  Widget _buildSendButton(bool isSending) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: isSending ? null : widget.onSendMessage,
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.send_rounded, size: 20, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildMoreButton() {
    return _IconButton(
      icon: AppAssets.iconAdd,
      isActive: widget.showMorePanel,
      onTap: widget.onToggleMore,
    );
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
class _EmojiPanel extends StatefulWidget {
  const _EmojiPanel({required this.onEmojiSelected});

  final Function(String) onEmojiSelected;

  @override
  State<_EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends State<_EmojiPanel> {
  int _selectedTabIndex = 1; // 默认选中 Emoji tab
  List<EmojiPack> _userPacks = [];
  bool _loadingPacks = false;
  late final EmojiItemService _emojiService = EmojiItemService();

  // 搜索相关
  final TextEditingController _searchController = TextEditingController();
  List<EmojiPack> _searchResults = [];
  bool _searchLoading = false;
  Timer? _searchTimer;

  // 套件相关
  final Map<String, List<EmojiPack>> _suitePacksCache = {};
  final Map<String, bool> _loadingSuitePacks = {};

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
  void initState() {
    super.initState();
    _loadUserPacks();
    _searchController.addListener(_handleSearchInput);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchInput);
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  void _handleSearchInput() {
    _searchTimer?.cancel();
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(keyword);
    });
  }

  Future<void> _performSearch(String keyword) async {
    setState(() {
      _searchLoading = true;
    });

    try {
      final service = EmojiPackService();
      final results = await service.searchPacks(keyword);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _searchLoading = false;
        });
      }
    } catch (e) {
      debugPrint('搜索表情包失败: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searchLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserPacks() async {
    setState(() {
      _loadingPacks = true;
    });
    try {
      final service = EmojiPackService();
      final packs = await service.getUserPacks();
      debugPrint('_loadUserPacks: 加载到 ${packs.length} 个表情包');
      for (final pack in packs) {
        debugPrint(
          '  表情包: id=${pack.id}, name=${pack.name}, packType=${pack.packType}, items数量=${pack.items.length}',
        );
      }
      setState(() {
        _userPacks = packs;
      });
    } catch (e) {
      // 静默失败，不影响表情面板显示
      debugPrint('加载表情包失败: $e');
    } finally {
      setState(() {
        _loadingPacks = false;
      });
    }
  }

  List<_TabItem> _buildTabs() {
    final tabs = <_TabItem>[];

    // 搜索 tab
    tabs.add(_TabItem(type: _TabType.search, icon: 'search', label: '搜索'));

    // Emoji tab
    tabs.add(_TabItem(type: _TabType.emoji, icon: 'emoji', label: 'Emoji'));

    // 自定义表情 tab
    tabs.add(_TabItem(type: _TabType.custom, icon: 'custom', label: '自定义'));

    // 只添加套件（packType === 1）作为动态 tab
    for (final pack in _userPacks) {
      if (pack.packType == 1) {
        tabs.add(
          _TabItem(
            type: _TabType.pack,
            icon: pack.iconUrl,
            label: pack.name,
            pack: pack,
          ),
        );
      }
    }

    return tabs;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _buildTabs();

    return Container(
      height: 320,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Column(
        children: [
          // Tab 切换栏
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ...tabs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final tab = entry.value;
                  final isSelected = _selectedTabIndex == index;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTabIndex = index;
                      });
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: EdgeInsets.only(
                        right: index < tabs.length - 1 ? 8 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Center(child: _buildTabIcon(tab.icon, isSelected)),
                    ),
                  );
                }),
              ],
            ),
          ),
          // 内容区域
          Expanded(child: _buildContent(tabs[_selectedTabIndex])),
        ],
      ),
    );
  }

  Widget _buildTabIcon(String? icon, bool isSelected) {
    if (icon == null) return const SizedBox.shrink();

    final color = isSelected ? AppColors.primary : AppColors.textSecondary;

    // 特殊图标类型
    if (icon == 'search') {
      return Icon(Icons.search, size: 20, color: color);
    } else if (icon == 'emoji') {
      return Icon(Icons.emoji_emotions_outlined, size: 20, color: color);
    } else if (icon == 'custom') {
      return Icon(Icons.favorite_outline, size: 20, color: color);
    }

    // 网络图片
    if (icon.startsWith('http')) {
      return Image.network(
        icon,
        width: 20,
        height: 20,
        errorBuilder: (_, __, ___) => Icon(Icons.image, size: 20, color: color),
      );
    }

    // Emoji 字符
    return Text(icon, style: const TextStyle(fontSize: 18));
  }

  Widget _buildContent(_TabItem tab) {
    if (_loadingPacks && tab.type == _TabType.custom) {
      return const Center(child: CircularProgressIndicator());
    }

    // 切换到套件 tab 时，如果缓存中没有数据，主动加载
    if (tab.type == _TabType.pack && tab.pack != null) {
      final suiteId = tab.pack!.id;
      if (tab.pack!.packType == 1 &&
          !_suitePacksCache.containsKey(suiteId) &&
          (_loadingSuitePacks[suiteId] != true)) {
        // 异步加载，不阻塞 UI
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadSuitePacks(suiteId);
        });
      }
    }

    // 使用 key 确保在数据变化时重新构建内容
    final contentKey = tab.type == _TabType.custom
        ? ValueKey('custom_content_${_userPacks.length}')
        : (tab.type == _TabType.pack && tab.pack != null
              ? ValueKey('pack_content_${tab.pack!.id}')
              : null);

    Widget content;
    switch (tab.type) {
      case _TabType.search:
        content = _buildSearchTab();
        break;
      case _TabType.emoji:
        content = _buildEmojiGrid();
        break;
      case _TabType.custom:
        content = _buildCustomEmojiGrid();
        break;
      case _TabType.pack:
        content = _buildPackGrid(tab.pack!);
        break;
    }

    return contentKey != null
        ? KeyedSubtree(key: contentKey, child: content)
        : content;
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索表情包或套件...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
        Expanded(
          child: _searchLoading
              ? const Center(child: CircularProgressIndicator())
              : _searchController.text.trim().isEmpty
              ? const Center(
                  child: Text(
                    '输入关键词搜索表情包或套件',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : _searchResults.isEmpty
              ? const Center(
                  child: Text(
                    '未找到相关表情包',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final pack = _searchResults[index];
                    return ListTile(
                      leading: pack.iconUrl != null
                          ? Image.network(
                              pack.iconUrl!,
                              width: 40,
                              height: 40,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.image, size: 40),
                            )
                          : const Icon(Icons.image, size: 40),
                      title: Text(pack.name),
                      subtitle: pack.description != null
                          ? Text(pack.description!)
                          : null,
                      trailing: Text(
                        pack.packType == 1 ? '套件' : '表情包',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onTap: () async {
                        // 显示确认对话框
                        final confirmed = await TipDialog.showConfirm(
                          context,
                          title: pack.packType == 1 ? '添加表情包套件' : '添加表情包',
                          content: pack.packType == 1
                              ? '确定要添加套件"${pack.name}"吗？这将添加套件下的所有表情包。'
                              : '确定要添加表情包"${pack.name}"到自定义表情吗？',
                          confirmText: '确定',
                          cancelText: '取消',
                        );

                        if (confirmed != true) return;

                        try {
                          final service = EmojiPackService();
                          if (pack.packType == 1) {
                            // 套件：使用 addUserSuite
                            final result = await service.addUserSuite(pack.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('成功添加 ${result['count']} 个表情包'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } else {
                            // 单个表情包：使用 addUserPack
                            await service.addUserPack(pack.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('添加成功'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }

                          // 重新加载用户表情包
                          await _loadUserPacks();

                          // 如果是套件，清除套件缓存以便重新加载
                          if (pack.packType == 1) {
                            _suitePacksCache.remove(pack.id);
                          }

                          // 等待状态更新完成
                          await Future.delayed(
                            const Duration(milliseconds: 100),
                          );

                          // 切换到对应的 tab
                          if (mounted) {
                            if (pack.packType == 1) {
                              // 套件：切换到套件 tab
                              // 需要等待 tabs 更新后再查找
                              await Future.delayed(
                                const Duration(milliseconds: 100),
                              );
                              final tabs = _buildTabs();
                              final suiteIndex = tabs.indexWhere(
                                (t) =>
                                    t.type == _TabType.pack &&
                                    t.pack?.id == pack.id,
                              );
                              if (suiteIndex >= 0) {
                                setState(() {
                                  _selectedTabIndex = suiteIndex;
                                });
                              }
                            } else {
                              // 单个表情包：切换到自定义 tab
                              final tabs = _buildTabs();
                              final customIndex = tabs.indexWhere(
                                (t) => t.type == _TabType.custom,
                              );
                              if (customIndex >= 0) {
                                // 强制刷新 UI
                                setState(() {
                                  _selectedTabIndex = customIndex;
                                  // 触发重新构建，确保 _userPacks 的变化被检测到
                                });
                                // 再次等待，确保 currentItems 计算完成
                                await Future.delayed(
                                  const Duration(milliseconds: 100),
                                );
                                // 再次触发 setState 确保 UI 更新
                                if (mounted) {
                                  setState(() {});
                                }
                              }
                            }
                          }
                        } catch (e) {
                          debugPrint('添加表情包失败: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e is EmojiPackServiceException
                                      ? e.message
                                      : '添加失败，请重试',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmojiGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
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
            onTap: () => widget.onEmojiSelected(emojis[index]),
            child: Center(
              child: Text(emojis[index], style: const TextStyle(fontSize: 24)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomEmojiGrid() {
    // 收集所有独立的单个表情包（packType === 0）中的表情项
    // 排除套件（packType === 1）
    final allItems = <EmojiItem>[];
    debugPrint('_buildCustomEmojiGrid: _userPacks 数量 = ${_userPacks.length}');
    for (final pack in _userPacks) {
      debugPrint(
        '  检查表情包: id=${pack.id}, name=${pack.name}, packType=${pack.packType}, items数量=${pack.items.length}',
      );
      if (pack.packType == 0) {
        debugPrint('    添加 ${pack.items.length} 个表情项');
        allItems.addAll(pack.items);
      }
    }
    debugPrint('_buildCustomEmojiGrid: 总共收集到 ${allItems.length} 个表情项');

    if (allItems.isEmpty) {
      return const Center(
        child: Text(
          '暂无自定义表情\n请在设置中添加表情包',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    // 使用 key 确保在数据变化时重新构建
    return GridView.builder(
      key: ValueKey('custom_emoji_${allItems.length}_${_userPacks.length}'),
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: allItems.length,
      itemBuilder: (context, index) {
        final item = allItems[index];
        return _CachedEmojiItem(
          imageUrl: item.imageUrl,
          onTap: () => widget.onEmojiSelected(item.imageUrl),
          emojiService: _emojiService,
        );
      },
    );
  }

  Widget _buildPackGrid(EmojiPack pack) {
    if (pack.packType == 1) {
      // 套件：显示套件下所有子表情包的 icon_url
      return _buildSuiteGrid(pack);
    } else {
      // 单个表情包：显示 pack.items
      if (pack.items.isEmpty) {
        return const Center(
          child: Text(
            '此表情包暂无表情',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        );
      }

      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: pack.items.length,
        itemBuilder: (context, index) {
          final item = pack.items[index];
          return _CachedEmojiItem(
            imageUrl: item.imageUrl,
            onTap: () => widget.onEmojiSelected(item.imageUrl),
            emojiService: _emojiService,
          );
        },
      );
    }
  }

  Widget _buildSuiteGrid(EmojiPack suitePack) {
    final suiteId = suitePack.id;
    final suitePacks = _suitePacksCache[suiteId];
    final isLoading = _loadingSuitePacks[suiteId] ?? false;

    // 如果缓存中没有且未在加载中，异步加载
    if (suitePacks == null && !isLoading) {
      _loadSuitePacks(suiteId);
    }

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (suitePacks == null || suitePacks.isEmpty) {
      return const Center(
        child: Text(
          '该套件暂无表情包\n请先添加表情包到套件',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    // 显示子表情包的 icon_url
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: suitePacks.length,
      itemBuilder: (context, index) {
        final childPack = suitePacks[index];
        if (childPack.iconUrl == null || childPack.iconUrl!.isEmpty) {
          return const SizedBox.shrink();
        }
        return _CachedEmojiItem(
          imageUrl: childPack.iconUrl!,
          onTap: () => widget.onEmojiSelected(childPack.iconUrl!),
          emojiService: _emojiService,
        );
      },
    );
  }

  Future<void> _loadSuitePacks(String suiteId) async {
    if (_suitePacksCache.containsKey(suiteId)) {
      debugPrint('套件已缓存，跳过加载: $suiteId');
      return;
    }
    if (_loadingSuitePacks[suiteId] == true) {
      debugPrint('套件正在加载中，跳过重复加载: $suiteId');
      return;
    }

    setState(() {
      _loadingSuitePacks[suiteId] = true;
    });

    try {
      debugPrint('开始加载套件表情包: $suiteId');
      final service = EmojiPackService();
      final suitePacks = await service.getSuitePacks(suiteId);
      debugPrint('套件表情包加载成功: $suiteId, 数量: ${suitePacks.length}');
      if (mounted) {
        setState(() {
          _suitePacksCache[suiteId] = suitePacks;
          _loadingSuitePacks[suiteId] = false;
        });
      }
    } catch (e) {
      debugPrint('加载套件表情包失败: $suiteId, 错误: $e');
      if (mounted) {
        setState(() {
          _suitePacksCache[suiteId] = [];
          _loadingSuitePacks[suiteId] = false;
        });
      }
    }
  }
}

enum _TabType { search, emoji, custom, pack }

class _TabItem {
  final _TabType type;
  final String? icon;
  final String label;
  final EmojiPack? pack;

  _TabItem({required this.type, this.icon, required this.label, this.pack});
}

/// 带缓存的表情项组件（支持 GIF）
class _CachedEmojiItem extends StatefulWidget {
  const _CachedEmojiItem({
    required this.imageUrl,
    required this.onTap,
    required this.emojiService,
  });

  final String imageUrl;
  final VoidCallback onTap;
  final EmojiItemService emojiService;

  @override
  State<_CachedEmojiItem> createState() => _CachedEmojiItemState();
}

class _CachedEmojiItemState extends State<_CachedEmojiItem> {
  String? _cachedPath;
  bool _loading = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadEmoji();
  }

  Future<void> _loadEmoji() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final cachedPath = await widget.emojiService.loadAndCacheEmoji(
        widget.imageUrl,
      );
      if (mounted) {
        setState(() {
          _cachedPath = cachedPath;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildImage(),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (_loading) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_error) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Icon(Icons.image, size: 24),
      );
    }

    // 优先使用缓存路径，如果缓存不存在则使用网络 URL
    // Flutter 的 Image 组件原生支持 GIF 动画
    if (_cachedPath != null) {
      return Image.file(
        File(_cachedPath!),
        fit: BoxFit.cover,
        width: 48,
        height: 48,
        errorBuilder: (_, __, ___) {
          // 缓存文件损坏，尝试重新加载
          _loadEmoji();
          return Image.network(
            widget.imageUrl,
            fit: BoxFit.cover,
            width: 48,
            height: 48,
            errorBuilder: (_, __, ___) => const Icon(Icons.image),
          );
        },
      );
    }

    return Image.network(
      widget.imageUrl,
      fit: BoxFit.cover,
      width: 48,
      height: 48,
      errorBuilder: (_, __, ___) => const Icon(Icons.image),
    );
  }
}

/// 文本消息中的表情图片组件
class _CachedEmojiInText extends StatefulWidget {
  const _CachedEmojiInText({required this.imageUrl, required this.size});

  final String imageUrl;
  final double size;

  @override
  State<_CachedEmojiInText> createState() => _CachedEmojiInTextState();
}

class _CachedEmojiInTextState extends State<_CachedEmojiInText> {
  String? _cachedPath;
  bool _loading = false;
  bool _error = false;
  late final EmojiItemService _emojiService = EmojiItemService();

  @override
  void initState() {
    super.initState();
    _loadEmoji();
  }

  Future<void> _loadEmoji() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      debugPrint('_CachedEmojiInText: 开始加载表情 ${widget.imageUrl}');
      final cachedPath = await _emojiService.loadAndCacheEmoji(widget.imageUrl);
      debugPrint('_CachedEmojiInText: 加载完成，缓存路径: $cachedPath');
      if (mounted) {
        setState(() {
          _cachedPath = cachedPath;
          _loading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('_CachedEmojiInText: 加载失败: $e');
      debugPrint('_CachedEmojiInText: 堆栈: $stackTrace');
      if (mounted) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: SizedBox(
            width: widget.size * 0.4,
            height: widget.size * 0.4,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_error) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Icon(Icons.image, size: widget.size * 0.6),
      );
    }

    // 优先使用缓存路径，如果缓存不存在则使用网络 URL
    if (_cachedPath != null) {
      return Image.file(
        File(_cachedPath!),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          // 缓存文件损坏，尝试重新加载
          _loadEmoji();
          return Image.network(
            widget.imageUrl,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.image, size: widget.size * 0.6),
          );
        },
      );
    }

    return Image.network(
      widget.imageUrl,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(Icons.image, size: widget.size * 0.6),
    );
  }
}

/// 更多操作面板

class _AttachmentImageView extends StatefulWidget {
  const _AttachmentImageView({
    required this.message,
    required this.part,
    required this.isSelf,
  });

  final Message message;
  final MessagePart part;
  final bool isSelf;

  @override
  State<_AttachmentImageView> createState() => _AttachmentImageViewState();
}

class _AttachmentImageViewState extends State<_AttachmentImageView> {
  String? _localPath;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _localPath = widget.part.attachment?.localPath;
    _load();
  }

  @override
  void didUpdateWidget(covariant _AttachmentImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.part.attachment?.key != widget.part.attachment?.key) {
      _localPath = widget.part.attachment?.localPath;
      _error = null;
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final attachment = widget.part.attachment;
    if (attachment == null) {
      setState(() {
        _loading = false;
        _error = '附件不存在';
      });
      return;
    }

    if (_localPath != null && _localPath!.isNotEmpty) {
      final file = File(_localPath!);
      if (await file.exists()) {
        setState(() {
          _loading = false;
        });
        return;
      }
    }

    try {
      final path = await MessageService.instance.ensureAttachmentCached(
        roomId: widget.message.roomId,
        message: widget.message,
        part: widget.part,
      );
      if (!mounted) return;
      setState(() {
        _localPath = path;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final attachment = widget.part.attachment;
    final size = _resolveMediaDisplaySize(
      attachment?.width,
      attachment?.height,
    );

    Widget child;
    if (_loading) {
      child = const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    } else if (_error != null) {
      child = GestureDetector(
        onTap: _load,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image, color: Colors.white70, size: 28),
            const SizedBox(height: 6),
            Text(
              '加载失败，点击重试',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white),
            ),
          ],
        ),
      );
    } else if (_localPath != null) {
      child = Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(_localPath!),
                width: size.width,
                height: size.height,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _previewImage(context),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      );
    } else {
      child = const Center(
        child: Icon(Icons.image_not_supported, color: Colors.white70),
      );
    }

    final progress = attachment?.uploadProgress;

    return Container(
      constraints: BoxConstraints(maxWidth: size.width, maxHeight: size.height),
      decoration: BoxDecoration(
        color: widget.isSelf
            ? Colors.white.withOpacity(0.25)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: child),
          if (progress != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
                child: LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  minHeight: 4,
                  backgroundColor: Colors.black.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.isSelf ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _previewImage(BuildContext context) async {
    if (_localPath == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.black.withOpacity(0.9),
            alignment: Alignment.center,
            child: InteractiveViewer(child: Image.file(File(_localPath!))),
          ),
        );
      },
    );
  }
}

class _AttachmentFileTile extends StatefulWidget {
  const _AttachmentFileTile({
    required this.message,
    required this.part,
    required this.isSelf,
    required this.icon,
    required this.fallbackLabel,
  });

  final Message message;
  final MessagePart part;
  final bool isSelf;
  final IconData icon;
  final String fallbackLabel;

  @override
  State<_AttachmentFileTile> createState() => _AttachmentFileTileState();
}

class _AttachmentFileTileState extends State<_AttachmentFileTile> {
  String? _localPath;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _localPath = widget.part.attachment?.localPath;
  }

  @override
  void didUpdateWidget(covariant _AttachmentFileTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.part.attachment?.key != widget.part.attachment?.key) {
      _localPath = widget.part.attachment?.localPath;
      _loading = false;
    }
  }

  Future<void> _handleTap() async {
    final attachment = widget.part.attachment;
    if (attachment == null) {
      return;
    }

    if (_loading || attachment.uploadProgress != null) return;

    setState(() {
      _loading = true;
    });

    try {
      final path = await MessageService.instance.ensureAttachmentCached(
        roomId: widget.message.roomId,
        message: widget.message,
        part: widget.part,
        forceDownload: true,
      );
      if (!mounted) return;
      _localPath = path;
      if (path != null && path.isNotEmpty) {
        await OpenFilex.open(path);
      } else {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(const SnackBar(content: Text('文件保存成功')));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('打开文件失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final attachment = widget.part.attachment;
    final name = attachment?.name ?? widget.fallbackLabel;
    final sizeText = _formatFileSize(attachment?.size);

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isSelf
              ? Colors.white.withOpacity(0.24)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isSelf
                    ? Colors.white.withOpacity(0.3)
                    : Colors.black.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                widget.icon,
                color: widget.isSelf ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.isSelf
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sizeText,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isSelf
                          ? Colors.white70
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (_loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.arrow_circle_down,
                size: 22,
                color: widget.isSelf ? Colors.white : AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

Size _resolveMediaDisplaySize(int? width, int? height) {
  const double maxDimension = 220;
  const double minDimension = 120;

  if (width == null || height == null || width <= 0 || height <= 0) {
    return const Size(180, 180);
  }

  var w = width.toDouble();
  var h = height.toDouble();
  final ratio = w / h;

  if (w >= h) {
    w = maxDimension;
    h = maxDimension / ratio;
    if (h < minDimension) {
      h = minDimension;
      w = minDimension * ratio;
    }
  } else {
    h = maxDimension;
    w = maxDimension * ratio;
    if (w < minDimension) {
      w = minDimension;
      h = minDimension / ratio;
    }
  }

  return Size(w, h);
}

String _formatFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) {
    return '--';
  }
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;

  if (bytes >= gb) {
    return '${(bytes / gb).toStringAsFixed(2)} GB';
  }
  if (bytes >= mb) {
    return '${(bytes / mb).toStringAsFixed(1)} MB';
  }
  if (bytes >= kb) {
    return '${(bytes / kb).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

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
