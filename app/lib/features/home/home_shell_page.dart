import 'package:flutter/material.dart';

import '../../core/constants/app_config.dart';
import '../../core/services/friend_service.dart';
import '../../core/services/friend_store.dart';
import '../../core/services/message_service.dart';
import '../../core/services/websocket_service.dart';
import '../../core/widgets/im_state_panel.dart';
import '../../shell/app_shell.dart';
import '../chat/chat_list_page.dart';
import '../contacts/contacts_page.dart';
import '../settings/settings_page.dart';

class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key});

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  final GlobalKey<ContactsPageState> _contactsKey =
      GlobalKey<ContactsPageState>();
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const ChatListPage(),
      ContactsPage(key: _contactsKey),
      const _DiscoveryEntryPage(),
      const SettingsPage(),
    ];
    _initializeSessionServices();
  }

  Future<void> _initializeSessionServices() async {
    if (!AppConfig.useMockData) {
      try {
        await WebSocketService.instance.connect();
      } catch (error) {
        debugPrint('Failed to connect WebSocket: $error');
      }
    }
    try {
      final incoming = await FriendService().fetchFriendRequests(
        direction: 'incoming',
        status: 'pending',
      );
      FriendStore.instance.setPendingIncoming(incoming.length);
    } catch (_) {
      // Badge priming is best effort and must not block the shell.
    }
  }

  void _handleSelected(int index) {
    if (index == 1) {
      _contactsKey.currentState?.refreshContacts(force: false);
    }
  }

  void _handleReselected(int index) {
    if (index == 1) {
      _contactsKey.currentState?.refreshContacts(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        MessageService.instance,
        FriendStore.instance,
      ]),
      builder: (context, _) => AppShell(
        mobilePages: _pages,
        desktopPages: _pages,
        badgeCounts: [
          MessageService.instance.chats.fold<int>(
            0,
            (sum, chat) => sum + chat.unreadCount,
          ),
          FriendStore.instance.pendingIncoming,
          0,
          0,
        ],
        onMobileSelected: _handleSelected,
        onMobileReselect: _handleReselected,
      ),
    );
  }
}

class _DiscoveryEntryPage extends StatelessWidget {
  const _DiscoveryEntryPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('发现')),
      body: const ImStatePanel(
        icon: Icons.explore_outlined,
        title: '发现',
        message: '相关功能将在服务合同完成后开放',
      ),
    );
  }
}
