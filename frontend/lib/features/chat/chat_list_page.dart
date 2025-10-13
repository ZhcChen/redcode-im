import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import 'chat_detail_page.dart';
import 'models/chat_conversation.dart';
import 'widgets/chat_list_item.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  late List<ChatConversation> _conversations;

  @override
  void initState() {
    super.initState();
    _conversations = _mockConversations();
    _sortConversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('在线'),
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Image.asset(AppAssets.loginLogo, fit: BoxFit.contain),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 600));
          if (!mounted) return;
          setState(() {
            _conversations = _mockConversations();
            _sortConversations();
          });
        },
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: _conversations.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 92),
          itemBuilder: (context, index) {
            final conversation = _conversations[index];
            return Slidable(
              key: ValueKey(conversation.id),
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.4,
                children: [
                  SlidableAction(
                    onPressed: (_) => _togglePinned(conversation),
                    foregroundColor: Colors.white,
                    backgroundColor: AppColors.primary,
                    label: conversation.isPinned ? '取消置顶' : '置顶',
                  ),
                  SlidableAction(
                    onPressed: (_) => _deleteConversation(conversation),
                    foregroundColor: Colors.white,
                    backgroundColor: AppColors.danger,
                    label: '删除',
                  ),
                ],
              ),
              child: ChatListItem(
                conversation: conversation,
                avatarBuilder: (avatar) {
                  if (avatar == null || avatar.isEmpty) {
                    return SvgPicture.asset(AppAssets.defaultAvatar);
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(48),
                    child: Image.network(avatar, fit: BoxFit.cover),
                  );
                },
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ChatDetailPage(conversation: conversation),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _togglePinned(ChatConversation conversation) {
    setState(() {
      final index = _conversations.indexWhere((e) => e.id == conversation.id);
      if (index == -1) return;
      _conversations[index] = conversation.copyWith(
        isPinned: !conversation.isPinned,
      );
      _sortConversations();
    });
  }

  void _deleteConversation(ChatConversation conversation) {
    setState(() {
      _conversations.removeWhere((e) => e.id == conversation.id);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已删除 ${conversation.name}（mock）')));
  }

  void _sortConversations() {
    _conversations.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.lastMessageTime.compareTo(a.lastMessageTime);
    });
  }

  List<ChatConversation> _mockConversations() {
    final now = DateTime.now();
    return [
      ChatConversation(
        id: '1',
        name: '熊视界官方群',
        lastMessage: '欢迎体验新版聊天体验，点击查看更新内容。',
        lastMessageTime: now.subtract(const Duration(minutes: 3)),
        unreadCount: 3,
        isPinned: true,
      ),
      ChatConversation(
        id: '2',
        name: '产品研发部',
        lastMessage: '陈晨：今天的需求评审资料请查收～',
        lastMessageTime: now.subtract(const Duration(hours: 1, minutes: 12)),
        unreadCount: 0,
      ),
      ChatConversation(
        id: '3',
        name: '设计资源共享',
        lastMessage: 'Alice 邀请你查看最新的设计稿。',
        lastMessageTime: now.subtract(const Duration(hours: 5)),
        unreadCount: 2,
      ),
      ChatConversation(
        id: '4',
        name: '星火计划',
        lastMessage: '计划书已经上传，大家看看。',
        lastMessageTime: now.subtract(const Duration(days: 1, hours: 2)),
        unreadCount: 0,
      ),
      ChatConversation(
        id: '5',
        name: 'AI 研究组',
        lastMessage: '最新模型迭代日志分享在 wiki 啦！',
        lastMessageTime: now.subtract(const Duration(days: 2, hours: 3)),
        unreadCount: 5,
      ),
    ];
  }
}
