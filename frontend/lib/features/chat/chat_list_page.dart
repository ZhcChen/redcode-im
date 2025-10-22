import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../contacts/add_friend_page.dart';
import 'chat_detail_page_v2.dart';
import 'create_group_page.dart';
import 'models/chat_model.dart';
import 'providers/chat_provider.dart';
import 'widgets/chat_list_item.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(),
      child: const _ChatListView(),
    );
  }
}

class _ChatListView extends StatelessWidget {
  const _ChatListView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final List<Chat> chats = provider.chats;
    final isLoading = provider.isChatsLoading && chats.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _ChatListHeader(
            onSearchTap: () => _showSnackBar(context, '搜索功能暂未接入'),
            onMenuSelected: (action) => _handleMenuSelected(context, action),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : chats.isEmpty
                ? const _EmptyPlaceholder()
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 0),
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      final chat = chats[index];
                      return Slidable(
                        key: ValueKey(chat.id),
                        endActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          extentRatio: 0.4,
                          children: [
                            SlidableAction(
                              onPressed: (_) =>
                                  provider.pinChat(chat.id, !chat.isPinned),
                              foregroundColor: Colors.white,
                              backgroundColor: AppColors.primary,
                              label: chat.isPinned ? '取消置顶' : '置顶',
                            ),
                            SlidableAction(
                              onPressed: (_) => provider.deleteChat(chat.id),
                              foregroundColor: Colors.white,
                              backgroundColor: AppColors.danger,
                              label: '删除',
                            ),
                          ],
                        ),
                        child: ChatListItem(
                          chat: chat,
                          avatarBuilder: (avatar) {
                            if (avatar == null || avatar.isEmpty) {
                              return SvgPicture.asset(AppAssets.defaultAvatar);
                            }
                            if (avatar.endsWith('.svg')) {
                              return SvgPicture.asset(avatar);
                            }
                            if (avatar.startsWith('http://') ||
                                avatar.startsWith('https://')) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(48),
                                child: Image.network(avatar, fit: BoxFit.cover),
                              );
                            }
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(48),
                              child: Image.asset(avatar, fit: BoxFit.cover),
                            );
                          },
                          showBottomDivider: index != chats.length - 1,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChatDetailPageV2(
                                  roomId: chat.roomId,
                                  chatName: chat.name,
                                  chatAvatar: chat.avatar,
                                  chatType: chat.type,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleMenuSelected(BuildContext context, _ChatMenuAction action) {
    switch (action) {
      case _ChatMenuAction.addFriend:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddFriendPage()));
        break;
      case _ChatMenuAction.createGroup:
        _handleCreateGroup(context);
        break;
    }
  }

  void _handleCreateGroup(BuildContext context) {
    final provider = context.read<ChatProvider>();
    final navigator = Navigator.of(context);

    navigator
        .push<String>(
          MaterialPageRoute(builder: (_) => const CreateGroupPage()),
        )
        .then((roomId) async {
          if (roomId == null || roomId.isEmpty) {
            return;
          }

          await provider.loadChats(refresh: true);

          Chat? matched;
          try {
            matched = provider.chats.firstWhere(
              (chat) => chat.roomId == roomId,
            );
          } catch (_) {
            matched = null;
          }

          if (matched == null || !navigator.mounted) {
            return;
          }

          final chat = matched;

          navigator.push(
            MaterialPageRoute(
              builder: (_) => ChatDetailPageV2(
                roomId: chat.roomId,
                chatName: chat.name,
                chatAvatar: chat.avatar,
                chatType: chat.type,
              ),
            ),
          );
        });
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

class _ChatMenuButton extends StatefulWidget {
  const _ChatMenuButton({required this.onSelected});

  final ValueChanged<_ChatMenuAction> onSelected;

  @override
  State<_ChatMenuButton> createState() => _ChatMenuButtonState();
}

class _ChatMenuButtonState extends State<_ChatMenuButton>
    with SingleTickerProviderStateMixin {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _entry;
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fade = curved;
    _scale = Tween<double>(begin: 0.95, end: 1.0).animate(curved);
  }

  double _menuButtonSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = screenWidth / 375;
    return (40 * scale).clamp(36, 48);
  }

  void _showMenu() {
    final renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final buttonSize = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);

    if (_entry != null) return;
    _controller.reset();

    _entry = OverlayEntry(
      builder: (context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _hideMenu,
                child: Container(
                  color: Colors.black.withValues(
                    alpha: 0.3 * (_fade.value.clamp(0.0, 1.0)),
                  ),
                ),
              ),
            ),
            Positioned(
              left: offset.dx + buttonSize.width / 2 - 6,
              top: offset.dy + buttonSize.height + 8 - 6,
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  alignment: Alignment.topCenter,
                  child: const _MenuArrow(),
                ),
              ),
            ),
            Positioned(
              left: offset.dx,
              top: offset.dy + buttonSize.height + 8,
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  alignment: Alignment.topLeft,
                  child: _DropdownMenu(
                    onSelected: (action) {
                      widget.onSelected(action);
                      _hideMenu();
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_entry!);
    _controller.forward();
  }

  Future<void> _hideMenu() async {
    final entry = _entry;
    _entry = null;
    if (entry != null) {
      try {
        await _controller.reverse();
      } catch (_) {}
      entry.remove();
    }
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _menuButtonSize(context);
    return GestureDetector(
      key: _buttonKey,
      onTap: _showMenu,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: SvgPicture.asset(
            AppAssets.chatMenu,
            width: size,
            height: size,
          ),
        ),
      ),
    );
  }
}

class _DropdownMenu extends StatelessWidget {
  const _DropdownMenu({required this.onSelected});

  final ValueChanged<_ChatMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DropdownItem(
              icon: AppAssets.chatAdd,
              label: '添加好友',
              onTap: () => onSelected(_ChatMenuAction.addFriend),
            ),
            const Divider(height: 1, color: Color(0xFFE5E8EC)),
            _DropdownItem(
              icon: AppAssets.chatCreate,
              label: '创建群聊',
              onTap: () => onSelected(_ChatMenuAction.createGroup),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownItem extends StatelessWidget {
  const _DropdownItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(icon, width: 20, height: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ChatMenuAction { addFriend, createGroup }

class _MenuArrow extends StatelessWidget {
  const _MenuArrow();

  @override
  Widget build(BuildContext context) {
    const size = 12.0;
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.mark_chat_unread_outlined,
            size: 56,
            color: AppColors.textTertiary,
          ),
          SizedBox(height: 16),
          Text(
            '暂无会话',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          SizedBox(height: 6),
          Text(
            '开始一段新的聊天吧',
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
