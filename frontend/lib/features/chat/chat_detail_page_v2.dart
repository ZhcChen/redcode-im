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
  });

  final String roomId;
  final String chatName;
  final String? chatAvatar;
  final ChatType chatType;

  @override
  State<ChatDetailPageV2> createState() => _ChatDetailPageV2State();
}

enum _MessageAction { copy, quote, forward, pin, delete }

class _ChatDetailPageV2State extends State<ChatDetailPageV2> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final GlobalKey _inputAreaKey = GlobalKey();
  double _lastKeyboardInset = 0.0;

  late ChatProvider _chatProvider;
  bool _isAtBottom = true;
  String? _lastMessageId;
  int _lastMessageCount = 0;

  bool _showEmojiPanel = false;
  bool _showMorePanel = false;
  bool _memberCountLoading = false;
  bool _memberCountLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _chatProvider = ChatProvider();
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

    // 进入聊天室
    await _chatProvider.enterChatRoom(widget.roomId, chat);

    if (!mounted) return;
    if (widget.chatType == ChatType.group) {
      await _loadMemberCount();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _chatProvider.leaveChatRoom();
    _chatProvider.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _chatProvider.sendTextMessage(text);
    _textController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_inputFocusNode);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
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
      if (!mounted) return;
      setState(() {
        _memberCountLoading = false;
      });
    }
  }

  String _groupMemberSubtitle(ChatProvider provider) {
    final cachedCount = provider.cachedMemberCount(widget.roomId);
    if (cachedCount != null) {
      return '共${cachedCount}人';
    }
    if (_memberCountLoadFailed) {
      return '成员加载失败，点击重试';
    }
    return '成员加载中...';
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _chatProvider,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(child: _buildMessageList()),
              _buildInputArea(),
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
              onTap: () => Navigator.of(context).pop(),
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
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.chatType == ChatType.group) ...[
                  const SizedBox(height: 2),
                  Consumer<ChatProvider>(
                    builder: (context, provider, _) {
                      final subtitle = _groupMemberSubtitle(provider);
                      return GestureDetector(
                        onTap: _memberCountLoadFailed
                            ? () => _loadMemberCount(forceRefresh: true)
                            : null,
                        child: Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            decoration: _memberCountLoadFailed
                                ? TextDecoration.underline
                                : TextDecoration.none,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
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
  }

  Widget _buildMessageList() {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _processMessages(provider.messages);
        });

        if (provider.messages.isEmpty) {
          return Center(
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
          );
        }

        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        if (bottomInset != _lastKeyboardInset) {
          if (bottomInset > _lastKeyboardInset && _isAtBottom) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _scrollToBottom();
            });
          }
          _lastKeyboardInset = bottomInset;
        }

        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomInset),
          itemCount: provider.messages.length,
          itemBuilder: (context, index) {
            final message = provider.messages[index];
            final previousMessage = index > 0
                ? provider.messages[index - 1]
                : null;

            final showTimestamp = message.shouldShowTimestamp(previousMessage);
            final dayLabel = message.displayTime;
            final canShowReadReceipts = provider.shouldShowReadReceipts(
              message,
            );

            return Column(
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
                ),
              ],
            );
          },
        );
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 语音按钮
            _IconButton(icon: AppAssets.iconVoice, onTap: _toggleVoice),
            const SizedBox(width: 8),

            // 输入框
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

            // 表情按钮
            _IconButton(
              icon: AppAssets.iconEmoji,
              isActive: _showEmojiPanel,
              onTap: _toggleEmoji,
            ),
            const SizedBox(width: 4),

            // 发送/更多按钮
            Consumer<ChatProvider>(
              builder: (context, provider, child) {
                final hasText = _textController.text.trim().isNotEmpty;

                if (hasText) {
                  return Material(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: provider.isSending ? null : _sendMessage,
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        child: provider.isSending
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
                } else {
                  return _IconButton(
                    icon: AppAssets.iconAdd,
                    isActive: _showMorePanel,
                    onTap: _toggleMore,
                  );
                }
              },
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
  }

  void _toggleMore() {
    setState(() {
      _showMorePanel = !_showMorePanel;
      _showEmojiPanel = false;
    });

    if (_showMorePanel) {
      FocusScope.of(context).unfocus();
    }
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
      selection: TextSelection.collapsed(
        offset: start + emoji.length,
      ),
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
        Overlay.of(context)?.context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    const menuWidth = 176.0;
    const menuPadding = 12.0;
    const actionHeight = 36.0;
    const itemSpacing = 4.0;
    const verticalOffset = 32.0;
    final menuHeight = menuPadding * 2 + actionHeight * 5 + itemSpacing * 4;

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
      barrierColor: Colors.black.withOpacity(0.03),
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
                              buildActionButton(
                                dialogContext,
                                '复制文本',
                                _MessageAction.copy,
                                icon: Icons.copy_rounded,
                              ),
                              const SizedBox(height: itemSpacing),
                              buildActionButton(
                                dialogContext,
                                '引用',
                                _MessageAction.quote,
                                icon: Icons.format_quote_rounded,
                              ),
                              const SizedBox(height: itemSpacing),
                              buildActionButton(
                                dialogContext,
                                '转发',
                                _MessageAction.forward,
                                icon: Icons.reply_rounded,
                              ),
                              const SizedBox(height: itemSpacing),
                              buildActionButton(
                                dialogContext,
                                '置顶',
                                _MessageAction.pin,
                                icon: Icons.push_pin_outlined,
                              ),
                              const SizedBox(height: itemSpacing),
                              buildActionButton(
                                dialogContext,
                                '删除',
                                _MessageAction.delete,
                                danger: true,
                                icon: Icons.delete_outline,
                              ),
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
        await Clipboard.setData(ClipboardData(text: message.content));
        break;
      case _MessageAction.quote:
        final quoted = message.content.trim();
        final current = _textController.text;
        final buffer = StringBuffer();
        if (current.trim().isNotEmpty) {
          buffer.write(current);
          if (!current.endsWith('\n')) {
            buffer.write('\n');
          }
        }
        buffer.write('> $quoted\n');
        final nextText = buffer.toString();
        _textController
          ..text = nextText
          ..selection = TextSelection.fromPosition(
            TextPosition(offset: nextText.length),
          );
        FocusScope.of(context).requestFocus(_inputFocusNode);
        break;
      case _MessageAction.forward:
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('转发功能尚未实现')));
        break;
      case _MessageAction.pin:
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('置顶功能尚未实现')));
        break;
      case _MessageAction.delete:
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('删除功能尚未实现')));
        break;
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
      _scrollToBottom();
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

class _ChatInfoDrawer extends StatelessWidget {
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

    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: drawerWidth,
        height: mq.size.height,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              bottomLeft: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 32,
                offset: Offset(-12, 0),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: topPadding,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
              ),
              _buildHeader(context),
              const Divider(height: 1, thickness: 0.5),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: bottomPadding + 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      if (chat.type == ChatType.single)
                        _PersonalChatPanel(chat: chat)
                      else
                        _GroupChatPanel(
                          chat: chat,
                          provider: provider,
                          onRefreshMembers: onRefreshMembers,
                        ),
                      const SizedBox(height: 32),
                      _DrawerSection(
                        title: '功能与设置',
                        children: [
                          _DrawerActionTile(
                            icon: Icons.search,
                            label: '查找聊天记录',
                            onTap: () {
                              debugPrint('Search messages');
                              onClose();
                            },
                          ),
                          if (chat.type == ChatType.group)
                            _DrawerActionTile(
                              icon: Icons.notifications_off_outlined,
                              label: '消息免打扰',
                              onTap: () {
                                debugPrint('Toggle mute');
                                onClose();
                              },
                            ),
                          _DrawerActionTile(
                            icon: Icons.cleaning_services_outlined,
                            label: '清空聊天记录',
                            danger: true,
                            onTap: () {
                              debugPrint('Clear conversation');
                              onClose();
                            },
                          ),
                        ],
                      ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              chat.type == ChatType.group ? '群聊详情' : '聊天详情',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            onPressed: onClose,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}

class _PersonalChatPanel extends StatelessWidget {
  const _PersonalChatPanel({required this.chat});

  final Chat chat;

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
                Navigator.of(context).pop();
              },
            ),
            _DrawerActionTile(
              icon: Icons.block,
              label: '屏蔽或删除联系人',
              onTap: () {
                debugPrint('Block or delete contact');
                Navigator.of(context).pop();
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
    this.onRefreshMembers,
  });

  final Chat chat;
  final ChatProvider provider;
  final Future<void> Function()? onRefreshMembers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extra = chat.extra ?? const <String, dynamic>{};
    final description = extra['description'] as String?;
    final initiatorId = extra['initiator_id'] as String?;
    final memberCount = provider.cachedMemberCount(chat.roomId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          chat.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.people_outline,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              memberCount != null ? '共$memberCount人' : '成员加载中...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (onRefreshMembers != null)
              TextButton(onPressed: onRefreshMembers, child: const Text('刷新')),
          ],
        ),
        if (description != null && description.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            description.trim(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (initiatorId != null && initiatorId.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '创建人：$initiatorId',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _DrawerSection(
          title: '群聊管理',
          children: [
            _DrawerActionTile(
              icon: Icons.group_outlined,
              label: '查看群成员',
              onTap: () {
                debugPrint('View group members');
                Navigator.of(context).pop();
              },
            ),
            _DrawerActionTile(
              icon: Icons.person_add_alt,
              label: '邀请好友入群',
              onTap: () {
                debugPrint('Invite member');
                Navigator.of(context).pop();
              },
            ),
            _DrawerActionTile(
              icon: Icons.settings_outlined,
              label: '群管理设置',
              onTap: () {
                debugPrint('Manage group settings');
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ],
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
    this.trailing,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
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
              trailing ??
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

/// 消息气泡
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onResend,
    this.canShowReadReceipts = false,
    this.onShowReadReceipts,
    this.onBubbleTap,
  });

  final Message message;
  final VoidCallback onResend;
  final bool canShowReadReceipts;
  final VoidCallback? onShowReadReceipts;
  final void Function(Offset tapPosition, Message message, bool isSelf)?
  onBubbleTap;

  static const double _avatarRadius = 18;
  static const double _avatarSpacing = 8;

  @override
  Widget build(BuildContext context) {
    return message.isSelf
        ? _buildSelfBubble(context)
        : _buildPeerBubble(context);
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
    final displayName = message.displaySenderName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(false),
          const SizedBox(width: _avatarSpacing),
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
      crossAxisAlignment: message.isSelf
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [body, const SizedBox(height: 6), timeRow],
    );
  }

  Widget _buildMessageBody(BuildContext context) {
    switch (message.type) {
      case MessageType.text:
        return Text(
          message.content,
          style: TextStyle(
            fontSize: 15,
            color: message.isSelf ? Colors.white : AppColors.textPrimary,
          ),
        );
      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                message.content, // TODO: 使用网络图片
                width: 200,
                fit: BoxFit.cover,
              ),
            ),
            if (message.extra?['caption'] != null) ...[
              const SizedBox(height: 4),
              Text(
                message.extra!['caption'],
                style: TextStyle(
                  fontSize: 14,
                  color: message.isSelf ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ],
        );
      default:
        return Text(
          '[不支持的消息类型]',
          style: TextStyle(
            fontSize: 14,
            color: message.isSelf ? Colors.white70 : AppColors.textSecondary,
          ),
        );
    }
  }

  Widget _buildBubbleContainer(
    BuildContext context, {
    required Widget child,
    required bool isSelf,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (details) =>
            onBubbleTap?.call(details.globalPosition, message, isSelf),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelf ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isSelf ? 16 : 4),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isSelf ? 16 : 16),
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
      ),
    );
  }

  Widget _buildBubbleTimeRow(BuildContext context) {
    final theme = Theme.of(context);
    final timeStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 11,
      color: message.isSelf
          ? Colors.white.withValues(alpha: 0.8)
          : AppColors.textQuaternary,
    );

    final timeText = Text(_formatBubbleTime(), style: timeStyle);
    Widget? status;
    if (message.isSelf) {
      status = _buildStatusIndicator();
      if (status != null &&
          canShowReadReceipts &&
          message.status == MessageStatus.read &&
          onShowReadReceipts != null) {
        status = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onShowReadReceipts,
          child: Padding(padding: const EdgeInsets.all(4), child: status),
        );
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: message.isSelf
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        timeText,
        if (status != null) ...[const SizedBox(width: 8), status],
      ],
    );
  }

  Widget _buildAvatar(bool isSelf) {
    final avatar = message.senderAvatar;
    if (avatar != null && avatar.isNotEmpty) {
      if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
        return CircleAvatar(
          radius: _avatarRadius,
          backgroundImage: NetworkImage(avatar),
          backgroundColor: AppColors.surface,
        );
      }
      return CircleAvatar(
        radius: _avatarRadius,
        backgroundImage: AssetImage(avatar),
        backgroundColor: AppColors.surface,
      );
    }

    final name = message.displaySenderName.trim();
    final initial = name.isNotEmpty ? name[0] : '?';

    return CircleAvatar(
      radius: _avatarRadius,
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

  Widget? _buildStatusIndicator() {
    switch (message.status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      case MessageStatus.sent:
        return const Icon(Icons.done, size: 14, color: Colors.white);
      case MessageStatus.delivered:
        return null;
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 14, color: Colors.white);
      case MessageStatus.failed:
        return GestureDetector(
          onTap: onResend,
          child: const Icon(Icons.priority_high, size: 16, color: Colors.red),
        );
    }
  }

  String _formatBubbleTime() {
    final local = message.timestamp.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
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
    this.useMonochrome = true,
  });

  final String icon;
  final VoidCallback onTap;
  final bool isActive;
  final bool useMonochrome;

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
                ? AppColors.primary.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            icon,
            width: 24,
            height: 24,
            colorFilter: useMonochrome
                ? ColorFilter.mode(
                    isActive ? AppColors.primary : AppColors.iconSecondary,
                    BlendMode.srcIn,
                  )
                : null,
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
