import 'package:flutter/material.dart';

class ChatSection extends StatelessWidget {
  const ChatSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: const Color(0xFFF5F7FB),
      child: Row(
        children: [
          SizedBox(
            width: 320,
            child: Column(
              children: [
                _ConversationHeader(theme: theme),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _mockConversations.length,
                    separatorBuilder: (_, __) => const Divider(indent: 72, endIndent: 16, height: 1),
                    itemBuilder: (context, index) {
                      final conversation = _mockConversations[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(conversation.name.substring(0, 1)),
                        ),
                        title: Text(conversation.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          conversation.preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          conversation.timeLabel,
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                        ),
                        onTap: () {},
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                _ChatHeader(theme: theme),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    itemCount: _mockMessages.length,
                    itemBuilder: (context, index) {
                      final message = _mockMessages[index];
                      final isMine = message.isMine;
                      final alignment = isMine ? Alignment.centerRight : Alignment.centerLeft;
                      final bubbleColor = isMine
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceVariant;
                      final textColor = isMine ? Colors.white : Colors.black87;

                      return Align(
                        alignment: alignment,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          constraints: const BoxConstraints(maxWidth: 420),
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(message.content, style: TextStyle(color: textColor)),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                _Composer(theme: theme),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('会话列表', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: '搜索联系人或会话',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: const Text('张'),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('张三', style: theme.textTheme.titleLarge),
                Text(
                  '在线 · 正在输入…',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.push_pin_outlined),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.emoji_emotions_outlined),
                tooltip: '表情',
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.attach_file_outlined),
                tooltip: '附件',
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.mic_none_rounded),
                tooltip: '语音',
              ),
              const Spacer(),
              FilledButton.tonal(
                onPressed: () {},
                child: const Text('清空'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            maxLines: 5,
            minLines: 3,
            decoration: InputDecoration(
              hintText: '输入消息，按 Enter 发送',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () {},
              child: const Text('发送'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationPreview {
  const _ConversationPreview(this.name, this.preview, this.timeLabel);

  final String name;
  final String preview;
  final String timeLabel;
}

class _MessagePreview {
  const _MessagePreview({required this.content, required this.isMine});

  final String content;
  final bool isMine;
}

const _mockConversations = <_ConversationPreview>[
  _ConversationPreview('张三', '今晚有空聊聊项目吗？', '08:32'),
  _ConversationPreview('创业群', 'Alice: PPT 更新完毕', '昨天'),
  _ConversationPreview('产品设计组', '你收藏的文档已更新', '昨天'),
  _ConversationPreview('王五', '收到，稍后发你', '周三'),
];

const _mockMessages = <_MessagePreview>[
  _MessagePreview(content: '嗨，今日的桌面端版本已经准备好。', isMine: false),
  _MessagePreview(content: '太好了，我正在整理迁移计划。', isMine: true),
  _MessagePreview(content: '记得同步下 Flutter 适配的最新设计稿。', isMine: false),
  _MessagePreview(content: '了解，晚上之前发你。', isMine: true),
];
