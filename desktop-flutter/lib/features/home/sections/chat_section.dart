import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ChatSection extends StatefulWidget {
  const ChatSection({super.key});

  @override
  State<ChatSection> createState() => _ChatSectionState();
}

class _ChatSectionState extends State<ChatSection> {
  final List<_Conversation> _conversations = _mockConversations;
  final List<_Message> _messages = _mockMessages;

  double _chatListWidth = 320;
  _Conversation? _selectedConversation;

  @override
  void initState() {
    super.initState();
    _selectedConversation = _conversations.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: const Color(0xFFF8F9FA),
      child: Column(
        children: [
          _buildHeader(theme),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _chatListWidth,
                  child: _buildConversationList(theme),
                ),
                _ResizeHandle(
                  onDrag: (delta) {
                    setState(() {
                      _chatListWidth = (_chatListWidth + delta).clamp(260, 420);
                    });
                  },
                  onReset: () => setState(() => _chatListWidth = 320),
                ),
                Expanded(
                  child: _selectedConversation == null
                      ? _buildEmptyWindow(theme)
                      : _buildChatWindow(theme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: Colors.white,
      child: Row(
        children: [
          SizedBox(
            width: _chatListWidth,
            child: Row(
              children: [
                SvgPicture.asset('assets/images/icon-menu.svg', width: 20, height: 20),
                const SizedBox(width: 16),
                Expanded(
                  child: _SearchInput(
                    hintText: '搜索聊天...',
                    onChanged: (value) {},
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          if (_selectedConversation != null)
            Expanded(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      _selectedConversation!.avatarLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedConversation!.name,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedConversation!.groupType == 1
                            ? '人数 ${_selectedConversation!.memberCount}'
                            : '在线 · 正在输入…',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '搜索',
                    onPressed: () {},
                    icon: const Icon(Icons.search_rounded),
                  ),
                  if (_selectedConversation!.isTop)
                    IconButton(
                      tooltip: '取消置顶',
                      onPressed: () {},
                      icon: const Icon(Icons.push_pin_outlined),
                    )
                  else
                    IconButton(
                      tooltip: '置顶聊天',
                      onPressed: () {},
                      icon: const Icon(Icons.push_pin_outlined),
                    ),
                  IconButton(
                    tooltip: '更多',
                    onPressed: () {},
                    icon: const Icon(Icons.more_vert),
                  ),
                ],
              ),
            )
          else
            const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildConversationList(ThemeData theme) {
    return Container(
      color: Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          final isSelected = _selectedConversation?.id == conversation.id;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedConversation = conversation;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isSelected ? const Color(0xFFEFFBF9) : Colors.white,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                    child: Text(
                      conversation.avatarLabel,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                conversation.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFF011627),
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              conversation.time,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                conversation.lastMessage,
                                style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF707991)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (conversation.unreadCount > 0)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  conversation.unreadCount.toString(),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (context, index) => Divider(
          indent: 72,
          endIndent: 16,
          thickness: 0.5,
          color: const Color(0xFFE5E9F0),
        ),
        itemCount: _conversations.length,
      ),
    );
  }

  Widget _buildChatWindow(ThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.white,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMine = message.isMine;
                return Align(
                  alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isMine ? theme.colorScheme.primary : const Color(0xFFF3F4F8),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMine ? 18 : 4),
                          bottomRight: Radius.circular(isMine ? 4 : 18),
                        ),
                      ),
                      child: Text(
                        message.content,
                        style: TextStyle(
                          color: isMine ? Colors.white : const Color(0xFF333333),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              Row(
                children: [
                  _ComposerIconButton(icon: 'assets/images/icon-emoji.svg', tooltip: '表情'),
                  const SizedBox(width: 12),
                  _ComposerIconButton(icon: 'assets/images/icon-upload.svg', tooltip: '附件'),
                  const SizedBox(width: 12),
                  _ComposerIconButton(icon: 'assets/images/icon-message.svg', tooltip: '快捷消息'),
                  const Spacer(),
                  TextButton(
                    onPressed: () {},
                    child: const Text('清空'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const TextField(
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: '输入消息，按 Enter 发送',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                  icon: SvgPicture.asset('assets/images/icon-send.svg', width: 16, height: 16, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
                  label: const Text('发送'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyWindow(ThemeData theme) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Text(
          '请选择一个会话开始聊天',
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onDrag, required this.onReset});

  final ValueChanged<double> onDrag;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        onDoubleTap: onReset,
        child: Container(
          width: 8,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 2,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({required this.hintText, required this.onChanged});

  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F8),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: Color(0xFF9B9BB0)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              decoration: InputDecoration(
                isDense: true,
                hintText: hintText,
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({required this.icon, required this.tooltip});

  final String icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SvgPicture.asset(icon, width: 20, height: 20),
    );
  }
}

class _Conversation {
  const _Conversation({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.isTop,
    required this.groupType,
    required this.memberCount,
    required this.unreadCount,
  });

  final String id;
  final String name;
  final String lastMessage;
  final String time;
  final bool isTop;
  final int groupType; // 0: 单聊, 1: 群聊
  final int memberCount;
  final int unreadCount;

  String get avatarLabel => name.isNotEmpty ? name.characters.first : '群';
}

class _Message {
  const _Message({required this.content, required this.isMine});

  final String content;
  final bool isMine;
}

const _mockConversations = <_Conversation>[
  _Conversation(
    id: '1',
    name: '桌面端设计讨论',
    lastMessage: 'Alice: 记得同步新的 UI 规范。',
    time: '08:32',
    isTop: true,
    groupType: 1,
    memberCount: 12,
    unreadCount: 2,
  ),
  _Conversation(
    id: '2',
    name: '张三',
    lastMessage: '今晚有空聊聊迁移计划吗？',
    time: '昨天',
    isTop: false,
    groupType: 0,
    memberCount: 2,
    unreadCount: 0,
  ),
  _Conversation(
    id: '3',
    name: '产品设计组',
    lastMessage: '你收藏的文档已更新。',
    time: '周三',
    isTop: false,
    groupType: 1,
    memberCount: 6,
    unreadCount: 5,
  ),
];

const _mockMessages = <_Message>[
  _Message(content: '嗨，桌面端 Flutter 版本的进度怎么样？', isMine: false),
  _Message(content: '刚完成 UI 框架的搭建，准备迁移组件。', isMine: true),
  _Message(content: '记得把聊天列表的拖拽宽度也实现一下。', isMine: false),
  _Message(content: '已经加上了，准备联调。', isMine: true),
];
