import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _messages = _mockMessages();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(24),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              AppAssets.loginLogo,
              height: 40,
              width: 40,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.conversation.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.conversation.unreadCount > 0
                      ? '未读 ${widget.conversation.unreadCount} 条'
                      : '群聊 · mock 成员 128',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
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
              onPressed: () {},
              icon: const Icon(Icons.add_circle_outline),
              color: AppColors.textQuaternary,
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
              onPressed: () {},
              icon: const Icon(Icons.emoji_emotions_outlined),
              color: AppColors.textQuaternary,
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
