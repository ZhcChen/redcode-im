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
      body: Column(
        children: [
          _ChatListHeader(
            onSearchTap: _handleSearchTap,
            onMenuSelected: _handleMenuSelected,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future<void>.delayed(const Duration(milliseconds: 600));
                if (!mounted) return;
                setState(() {
                  _conversations = _mockConversations();
                  _sortConversations();
                });
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: _conversations.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 92),
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
          ),
        ],
      ),
    );
  }

  void _handleSearchTap() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('搜索功能暂未接入（mock）')));
  }

  void _handleMenuSelected(_ChatMenuAction action) {
    final message = switch (action) {
      _ChatMenuAction.addFriend => '添加好友入口（mock）',
      _ChatMenuAction.createGroup => '创建群聊入口（mock）',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

class _ChatListHeader extends StatelessWidget {
  const _ChatListHeader({
    required this.onSearchTap,
    required this.onMenuSelected,
  });

  final VoidCallback onSearchTap;
  final ValueChanged<_ChatMenuAction> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _ChatMenuButton(onSelected: onMenuSelected),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: onSearchTap,
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.search,
                          size: 20,
                          color: AppColors.textTertiary,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '搜索',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.tune,
                          size: 20,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMenuButton extends StatelessWidget {
  const _ChatMenuButton({required this.onSelected});

  final ValueChanged<_ChatMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ChatMenuAction>(
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _ChatMenuAction.addFriend,
          child: _ChatMenuItem(icon: AppAssets.chatAdd, label: '添加好友'),
        ),
        PopupMenuItem(
          value: _ChatMenuAction.createGroup,
          child: _ChatMenuItem(icon: AppAssets.chatCreate, label: '创建群聊'),
        ),
      ],
      child: Container(
        width: _menuButtonSize(context),
        height: _menuButtonSize(context),
        alignment: Alignment.center,
        child: SvgPicture.asset(
          AppAssets.chatMenu,
          width: _menuIconSize(context),
          height: _menuIconSize(context),
        ),
      ),
    );
  }

  double _menuButtonSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = screenWidth / 375;
    return (24 * scale).clamp(22, 32);
  }

  double _menuIconSize(BuildContext context) {
    final button = _menuButtonSize(context);
    return (button * 0.7).clamp(16, 24);
  }
}

class _ChatMenuItem extends StatelessWidget {
  const _ChatMenuItem({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SvgPicture.asset(icon, width: 20, height: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

enum _ChatMenuAction { addFriend, createGroup }
