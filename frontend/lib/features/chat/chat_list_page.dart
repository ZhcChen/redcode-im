import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/room_avatar_service.dart';
import '../../core/services/user_avatar_service.dart';
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
    final List<Chat> chats = provider.filteredChats;
    final isLoading = provider.isChatsLoading && provider.chats.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _ChatListHeader(
            searchKeyword: provider.searchKeyword,
            onSearchChanged: (keyword) => provider.setSearchKeyword(keyword),
            onSearchCleared: () => provider.clearSearch(),
            onMenuSelected: (action) => _handleMenuSelected(context, action),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : chats.isEmpty
                ? _EmptyPlaceholder(
                    isEmptySearch: provider.searchKeyword.isNotEmpty,
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 0),
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      final chat = chats[index];
                      final isFavorite = chat.type == ChatType.favorite;

                      final item = ChatListItem(
                        chat: chat,
                        avatarBuilder: (avatar) => _ChatAvatar(
                          chat: chat,
                        ),
                        showBottomDivider: index != chats.length - 1,
                        onTap: () {
                          Navigator.of(context).push(
                            _buildChatDetailRoute(chat: chat),
                          );
                        },
                      );

                      if (isFavorite) {
                        return item;
                      }

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
                        child: item,
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

          navigator.push(_buildChatDetailRoute(chat: chat));
        });
  }
}

PageRoute<void> _buildChatDetailRoute({required Chat chat}) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (routeContext, animation, secondaryAnimation) {
      return ChatDetailPageV2(
        roomId: chat.roomId,
        chatName: chat.name,
        chatAvatar: chat.avatar,
        chatType: chat.type,
      );
    },
    transitionsBuilder: (routeContext, animation, secondaryAnimation, child) {
      final enterCurve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final fadeCurve = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.05, 0.9, curve: Curves.easeIn),
        reverseCurve: Curves.easeOutQuad,
      );

      final incoming = Tween<Offset>(
        begin: const Offset(1.0, 0),
        end: Offset.zero,
      ).animate(enterCurve);

      final outgoing = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.12, 0),
      ).animate(
        CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
      );

      return SlideTransition(
        position: outgoing,
        child: SlideTransition(
          position: incoming,
          child: FadeTransition(
            opacity: fadeCurve,
            child: child,
          ),
        ),
      );
    },
  );
}

class _FavoriteAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(AppAssets.chatFavorite, width: 56, height: 56);
  }
}

class _ChatListHeader extends StatefulWidget {
  const _ChatListHeader({
    required this.searchKeyword,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onMenuSelected,
  });

  final String searchKeyword;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final ValueChanged<_ChatMenuAction> onMenuSelected;

  @override
  State<_ChatListHeader> createState() => _ChatListHeaderState();
}

class _ChatListHeaderState extends State<_ChatListHeader> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchKeyword);
  }

  @override
  void didUpdateWidget(_ChatListHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchKeyword != widget.searchKeyword) {
      _searchController.text = widget.searchKeyword;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
              _ChatMenuButton(onSelected: widget.onMenuSelected),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search,
                        size: 20,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: widget.onSearchChanged,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            hintText: '搜索',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: AppColors.textTertiary,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                      if (widget.searchKeyword.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            widget.onSearchCleared();
                          },
                          child: const Icon(
                            Icons.clear,
                            size: 18,
                            color: AppColors.textTertiary,
                          ),
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

class _ChatAvatar extends StatefulWidget {
  const _ChatAvatar({required this.chat});

  final Chat chat;

  @override
  State<_ChatAvatar> createState() => _ChatAvatarState();
}

class _ChatAvatarState extends State<_ChatAvatar> {
  String? _cachedAvatarPath;
  bool _isLoading = false;
  final _userAvatarService = UserAvatarService();
  final _roomAvatarService = RoomAvatarService();

  @override
  void initState() {
    super.initState();
    _cachedAvatarPath = widget.chat.localAvatarPath;
    print('[ChatAvatar] ========== 初始化聊天头像 ==========');
    print('[ChatAvatar] roomId: ${widget.chat.roomId}');
    print('[ChatAvatar] name: ${widget.chat.name}');
    print('[ChatAvatar] type: ${widget.chat.type}');
    print('[ChatAvatar] avatarObjectKey: ${widget.chat.avatarObjectKey}');
    print('[ChatAvatar] localAvatarPath: ${widget.chat.localAvatarPath}');
    print('[ChatAvatar] avatar: ${widget.chat.avatar}');
    print('[ChatAvatar] extra: ${widget.chat.extra}');
    
    // 验证本地缓存文件是否真的存在
    bool needsLoad = false;
    if (_cachedAvatarPath != null && _cachedAvatarPath!.isNotEmpty) {
      final file = File(_cachedAvatarPath!);
      if (!file.existsSync()) {
        print('[ChatAvatar] ⚠️ 本地文件不存在: $_cachedAvatarPath');
        _cachedAvatarPath = null;
        needsLoad = true;
      } else {
        print('[ChatAvatar] ✅ 使用本地缓存: $_cachedAvatarPath');
      }
    } else {
      needsLoad = true;
    }
    
    // 如果有avatarObjectKey但没有有效的本地缓存，异步加载
    if (needsLoad &&
        widget.chat.avatarObjectKey != null &&
        widget.chat.avatarObjectKey!.isNotEmpty) {
      print('[ChatAvatar] ⚠️ 需要异步加载头像');
      _loadAvatar();
    } else if (!needsLoad) {
      // 已有本地缓存，不需要加载
    } else {
      print('[ChatAvatar] ⚠️ 无avatarObjectKey，使用默认头像');
    }
  }

  @override
  void didUpdateWidget(_ChatAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果avatarObjectKey变化，重新加载
    if (widget.chat.avatarObjectKey != oldWidget.chat.avatarObjectKey) {
      _cachedAvatarPath = widget.chat.localAvatarPath;
      if (widget.chat.avatarObjectKey != null &&
          widget.chat.avatarObjectKey!.isNotEmpty &&
          _cachedAvatarPath == null) {
        _loadAvatar();
      }
    }
  }

  Future<void> _loadAvatar() async {
    print('[ChatAvatar] _loadAvatar 被调用');
    if (_isLoading) {
      print('[ChatAvatar] ⚠️ 正在加载中，跳过');
      return;
    }
    if (widget.chat.avatarObjectKey == null ||
        widget.chat.avatarObjectKey!.isEmpty) {
      print('[ChatAvatar] ⚠️ avatarObjectKey为空，跳过');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? cachedPath;
      
      // 根据聊天类型选择不同的头像服务
      if (widget.chat.type == ChatType.single) {
        // 单聊使用用户头像服务
        final userId = widget.chat.extra?['friend_user_id'] as String? ??
            widget.chat.extra?['friendUserId'] as String? ??
            widget.chat.roomId;
        
        print('[ChatAvatar] 单聊，使用用户头像服务，userId: $userId');
        cachedPath = await _userAvatarService.loadAndCacheAvatar(
          userId: userId,
          avatarObjectKey: widget.chat.avatarObjectKey,
        );
      } else {
        // 群聊使用房间头像服务
        print('[ChatAvatar] 群聊，使用房间头像服务，roomId: ${widget.chat.roomId}');
        cachedPath = await _roomAvatarService.loadAndCacheAvatar(
          roomId: widget.chat.roomId,
          avatarObjectKey: widget.chat.avatarObjectKey,
        );
      }
      
      print('[ChatAvatar] 加载结果: $cachedPath');
      if (mounted) {
        setState(() {
          _cachedAvatarPath = cachedPath;
          _isLoading = false;
        });
        print('[ChatAvatar] ✅ 状态已更新');
      }
    } catch (e, stackTrace) {
      print('[ChatAvatar] ❌ 加载异常: $e');
      print('[ChatAvatar] 堆栈: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = widget.chat.type == ChatType.favorite;
    if (isFavorite) {
      return _FavoriteAvatar();
    }

    // 优先使用本地缓存路径
    if (_cachedAvatarPath != null && _cachedAvatarPath!.isNotEmpty) {
      final file = File(_cachedAvatarPath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(48),
          child: Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // 如果文件读取失败，显示默认头像
              return _buildDefaultAvatar();
            },
          ),
        );
      }
    }

    // 如果有avatarObjectKey但还在加载中，显示加载指示器
    if (_isLoading &&
        widget.chat.avatarObjectKey != null &&
        widget.chat.avatarObjectKey!.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(48),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // 处理其他类型的头像（asset、svg等）
    final avatar = widget.chat.avatar;
    if (avatar != null && avatar.isNotEmpty) {
      if (avatar.endsWith('.svg')) {
        return SvgPicture.asset(avatar);
      }
      // asset头像
      if (!avatar.startsWith('http://') && !avatar.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(48),
          child: Image.asset(avatar, fit: BoxFit.cover),
        );
      }
    }

    // 默认头像
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    final name = widget.chat.name.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(48),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 19,
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder({this.isEmptySearch = false});

  final bool isEmptySearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isEmptySearch ? Icons.search_off : Icons.mark_chat_unread_outlined,
            size: 56,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            isEmptySearch ? '未找到相关会话' : '暂无会话',
            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            isEmptySearch
                ? '试试其他关键词'
                : '开始一段新的聊天吧',
            style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
