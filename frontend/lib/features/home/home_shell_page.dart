import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/message_service.dart';
import '../../core/services/friend_store.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/services/websocket_service.dart';
import '../../core/services/friend_service.dart';
import '../chat/chat_list_page.dart';
import '../contacts/contacts_page.dart';
import '../settings/settings_page.dart';

class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key});

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  int _index = 0;
  final GlobalKey<ContactsPageState> _contactsKey =
      GlobalKey<ContactsPageState>();

  @override
  void initState() {
    super.initState();
    _initWebSocket();
    FriendStore.instance.addListener(_onFriendStoreChanged);
    _primePendingFriendBadge();
  }

  Future<void> _initWebSocket() async {
    // 登录成功后自动连接WebSocket
    try {
      final webSocketService = WebSocketService.instance;
      await webSocketService.connect();
      debugPrint('WebSocket connected after login');
    } catch (e) {
      debugPrint('Failed to connect WebSocket: $e');
    }
  }

  void _onFriendStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _primePendingFriendBadge() async {
    try {
      // 首次进入时拉取一次待处理好友请求数量，避免等待 WS 推送
      final incoming = await FriendService().fetchFriendRequests(
        direction: 'incoming',
        status: 'pending',
      );
      FriendStore.instance.setPendingIncoming(incoming.length);
    } catch (_) {
      // 忽略初始化失败
    }
  }

  static const _items = [
    _NavItem(
      label: '聊天',
      icon: AppAssets.chatTab,
      activeIcon: AppAssets.chatTabSelected,
    ),
    _NavItem(
      label: '联系人',
      icon: AppAssets.contactTab,
      activeIcon: AppAssets.contactTabSelected,
    ),
    _NavItem(
      label: '设置',
      icon: AppAssets.settingsTab,
      activeIcon: AppAssets.settingsTabSelected,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final messageService = MessageService.instance;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _index,
        children: [
          const ChatListPage(),
          ContactsPage(key: _contactsKey),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: messageService,
        builder: (context, _) {
          final unread = messageService.chats.fold<int>(
            0,
            (sum, chat) => sum + chat.unreadCount,
          );
          final pendingFriends = FriendStore.instance.pendingIncoming;
          return _buildNavBar(unread, pendingFriends);
        },
      ),
    );
  }

  Widget _buildNavBar(int chatBadgeCount, int contactBadgeCount) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, -4),
            color: Color.fromRGBO(0, 0, 0, 0.06),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final selected = _index == i;
              return Expanded(
                child: _NavButton(
                  item: item,
                  selected: selected,
                  onTap: () => _handleTabSelected(i),
                  badgeCount: i == 0
                      ? chatBadgeCount
                      : (i == 1 ? contactBadgeCount : 0),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  void _handleTabSelected(int index) {
    if (_index == index) {
      if (index == 1) {
        _contactsKey.currentState?.refreshContacts(force: true);
      }
      return;
    }

    setState(() => _index = index);
    if (index == 1) {
      // 切换到联系人页面时，静默更新（后台刷新数据）
      _contactsKey.currentState?.refreshContacts(force: false);
    }
  }

  @override
  void dispose() {
    FriendStore.instance.removeListener(_onFriendStoreChanged);
    super.dispose();
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final String icon;
  final String activeIcon;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showBadge = badgeCount > 0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 28,
            width: 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Image.asset(selected ? item.activeIcon : item.icon),
                ),
                if (showBadge)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: AppBadge(
                      count: badgeCount,
                      size: 16,
                      fontSize: 10,
                      backgroundColor: AppColors.danger, // 底部 TabBar 角标改为红色
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: selected ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
