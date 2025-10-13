import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import 'models/chat_conversation.dart';
import 'models/chat_message.dart';
import 'widgets/chat_message_bubble.dart';

class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  late List<ChatMessage> _messages;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _showEmojiPanel = false;
  bool _showMorePanel = false;

  @override
  void initState() {
    super.initState();
    _messages = _mockMessages();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus && (_showEmojiPanel || _showMorePanel)) {
        setState(() {
          _showEmojiPanel = false;
          _showMorePanel = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            if (widget.conversation.isPinned)
              const _NoticeBar(message: '已置顶会话，仅展示最近消息（mock）'),
            const SizedBox(height: 8),
            Expanded(child: _buildMessageList()),
            _buildInputArea(),
            if (_showEmojiPanel)
              _EmojiPanel(onEmojiSelected: _handleEmojiSelected),
            if (_showMorePanel)
              _MoreActionsPanel(onActionSelected: _handleMoreAction),
          ],
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    AppAssets.loginLeft,
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                      AppColors.textPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ConversationAvatar(avatar: widget.conversation.avatar),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.conversation.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '人数 128 · 仅演示用 mock 数据',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                color: AppColors.textPrimary,
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x00E5E8EC),
                  Color(0xFFE5E8EC),
                  Color(0x00E5E8EC),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return GestureDetector(
      onTap: _handleBackgroundTap,
      behavior: HitTestBehavior.translucent,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          final previous = index > 0 ? _messages[index - 1] : null;
          final showTimestamp =
              previous == null ||
              message.timestamp.difference(previous.timestamp).inMinutes >= 10;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showTimestamp)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _formatTime(message.timestamp),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ChatMessageBubble(message: message),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: _toggleMorePanel,
              icon: Icon(
                Icons.add_circle_outline,
                color: _showMorePanel
                    ? AppColors.primary
                    : AppColors.textQuaternary,
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _textController,
                  focusNode: _inputFocusNode,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: '输入消息...',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _toggleEmojiPanel,
              icon: Icon(
                _showEmojiPanel
                    ? Icons.keyboard_rounded
                    : Icons.emoji_emotions_outlined,
                color: _showEmojiPanel
                    ? AppColors.primary
                    : AppColors.textQuaternary,
              ),
            ),
            const SizedBox(width: 4),
            ElevatedButton(
              onPressed: _handleSend,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(64, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('发送'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(
        ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          senderId: 'self',
          senderName: '我',
          content: text,
          timestamp: DateTime.now(),
          isSelf: true,
        ),
      );
    });
    _textController.clear();
    _hidePanels();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _toggleEmojiPanel() {
    if (_showEmojiPanel) {
      setState(() => _showEmojiPanel = false);
      _inputFocusNode.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _showEmojiPanel = true;
      _showMorePanel = false;
    });
    _scrollToBottom();
  }

  void _toggleMorePanel() {
    if (_showMorePanel) {
      setState(() => _showMorePanel = false);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _showMorePanel = true;
      _showEmojiPanel = false;
    });
    _scrollToBottom();
  }

  void _handleEmojiSelected(String emoji) {
    final text = _textController.text;
    final selection = _textController.selection;
    if (!selection.isValid) {
      _textController.text += emoji;
      _textController.selection = TextSelection.collapsed(
        offset: _textController.text.length,
      );
    } else {
      final newText = text.replaceRange(selection.start, selection.end, emoji);
      final cursorPosition = selection.start + emoji.length;
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursorPosition),
      );
    }
  }

  void _handleMoreAction(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _hidePanels() {
    if (_showEmojiPanel || _showMorePanel) {
      setState(() {
        _showEmojiPanel = false;
        _showMorePanel = false;
      });
    }
  }

  void _handleBackgroundTap() {
    FocusScope.of(context).unfocus();
    _hidePanels();
  }

  List<ChatMessage> _mockMessages() {
    final now = DateTime.now();
    return [
      ChatMessage(
        id: 'm1',
        senderId: 'u1',
        senderName: '产品小熊',
        content: '大家好，欢迎加入熊视界项目群，本群目前主要讨论新版客户端迭代。',
        timestamp: now.subtract(const Duration(hours: 5, minutes: 10)),
      ),
      ChatMessage(
        id: 'm2',
        senderId: 'u2',
        senderName: '设计-Joy',
        content: 'UI 第三版已经上传到 Figma，大家可以先看看布局。',
        timestamp: now.subtract(const Duration(hours: 2, minutes: 36)),
      ),
      ChatMessage(
        id: 'm3',
        senderId: 'u3',
        senderName: '后端-阿锋',
        content: '短信服务的联调文档在 Confluence，上线前请提前对一下回调。',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 12)),
      ),
      ChatMessage(
        id: 'm4',
        senderId: 'self',
        senderName: '我',
        content: '收到～我稍后整理 Flutter 页面结构，先 mock 数据。',
        timestamp: now.subtract(const Duration(minutes: 28)),
        isSelf: true,
      ),
      ChatMessage(
        id: 'm5',
        senderId: 'u3',
        senderName: '后端-阿锋',
        content: '有问题随时 @ 我。',
        timestamp: now.subtract(const Duration(minutes: 25)),
      ),
      ChatMessage(
        id: 'm5-img',
        senderId: 'u2',
        senderName: '设计-Joy',
        type: ChatMessageType.image,
        imageAsset: AppAssets.loginLogo,
        timestamp: now.subtract(const Duration(minutes: 12)),
      ),
      ChatMessage(
        id: 'm6',
        senderId: 'self',
        senderName: '我',
        content: 'OK，正在迁移聊天 UI，稍后推断测试。',
        timestamp: now.subtract(const Duration(minutes: 4)),
        isSelf: true,
      ),
    ];
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (now.difference(time).inDays >= 1) {
      final month = time.month.toString().padLeft(2, '0');
      final day = time.day.toString().padLeft(2, '0');
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return '$month-$day $hour:$minute';
    }
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _NoticeBar extends StatelessWidget {
  const _NoticeBar({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.campaign_outlined,
            color: AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({this.avatar});

  final String? avatar;

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    final borderRadius = BorderRadius.circular(size / 2);

    if (avatar != null && avatar!.isNotEmpty) {
      final value = avatar!;
      if (value.startsWith('http')) {
        return ClipRRect(
          borderRadius: borderRadius,
          child: Image.network(
            value,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      }
      if (value.endsWith('.svg')) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: borderRadius,
          ),
          padding: const EdgeInsets.all(6),
          child: SvgPicture.asset(value, fit: BoxFit.contain),
        );
      }
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.asset(value, width: size, height: size, fit: BoxFit.cover),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: borderRadius,
      ),
      padding: const EdgeInsets.all(6),
      child: SvgPicture.asset(AppAssets.defaultAvatar),
    );
  }
}

class _EmojiPanel extends StatelessWidget {
  const _EmojiPanel({required this.onEmojiSelected});

  final ValueChanged<String> onEmojiSelected;

  static const List<String> _emojis = [
    '😀',
    '😁',
    '😂',
    '🥲',
    '😍',
    '😘',
    '🤔',
    '😎',
    '😢',
    '😭',
    '👍',
    '👋',
    '🙏',
    '🔥',
    '🌟',
    '❤️',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _emojis
              .map(
                (emoji) => GestureDetector(
                  onTap: () => onEmojiSelected(emoji),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _MoreActionsPanel extends StatelessWidget {
  const _MoreActionsPanel({required this.onActionSelected});

  final ValueChanged<String> onActionSelected;

  static final List<_MoreAction> _actions = [
    _MoreAction(
      icon: Icons.photo_outlined,
      label: '相册',
      message: '打开相册选择图片（mock）',
    ),
    _MoreAction(
      icon: Icons.camera_alt_outlined,
      label: '拍摄',
      message: '启动相机（mock）',
    ),
    _MoreAction(
      icon: Icons.insert_drive_file_outlined,
      label: '文件',
      message: '选择文件发送（mock）',
    ),
    _MoreAction(
      icon: Icons.location_on_outlined,
      label: '位置',
      message: '共享位置（mock）',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: SafeArea(
        top: false,
        child: Wrap(
          spacing: 28,
          runSpacing: 16,
          children: _actions
              .map(
                (action) => _MoreActionTile(
                  action: action,
                  onTap: () => onActionSelected(action.message),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _MoreActionTile extends StatelessWidget {
  const _MoreActionTile({required this.action, required this.onTap});

  final _MoreAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(action.icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreAction {
  const _MoreAction({
    required this.icon,
    required this.label,
    required this.message,
  });

  final IconData icon;
  final String label;
  final String message;
}
