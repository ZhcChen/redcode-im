import 'package:flutter/material.dart';
import '../../core/widgets/app_badge.dart';
import 'package:provider/provider.dart';

import '../../core/services/websocket_service.dart';
import 'chat_detail_page_v2.dart';
import 'providers/chat_provider.dart';
import 'models/chat_model.dart';

/// 示例：如何使用新的聊天系统
class ChatExamplePage extends StatefulWidget {
  const ChatExamplePage({super.key});

  @override
  State<ChatExamplePage> createState() => _ChatExamplePageState();
}

class _ChatExamplePageState extends State<ChatExamplePage> {
  @override
  void initState() {
    super.initState();
    _initServices();
  }

  /// 初始化服务
  Future<void> _initServices() async {
    // 1. 连接WebSocket
    await WebSocketService.instance.connect();

    // 2. 监听连接状态（可选）
    WebSocketService.instance.addListener(() {
      final status = WebSocketService.instance.status;
      debugPrint('WebSocket status: $status');

      if (status == ConnectionStatus.error) {
        // 显示错误提示
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('连接断开，正在重连...')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('聊天示例')),
      body: ListView(
        children: [
          // WebSocket连接状态
          _ConnectionStatus(),

          const Divider(),

          // 测试聊天室列表
          _TestChatList(),
        ],
      ),
    );
  }
}

/// 连接状态显示
class _ConnectionStatus extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WebSocketService.instance,
      builder: (context, child) {
        final status = WebSocketService.instance.status;
        final connectionId = WebSocketService.instance.connectionId;

        Color statusColor;
        String statusText;

        switch (status) {
          case ConnectionStatus.connecting:
            statusColor = Colors.orange;
            statusText = '连接中...';
            break;
          case ConnectionStatus.connected:
            statusColor = Colors.blue;
            statusText = '已连接（未认证）';
            break;
          case ConnectionStatus.authenticated:
            statusColor = Colors.green;
            statusText = '已认证';
            break;
          case ConnectionStatus.disconnected:
            statusColor = Colors.grey;
            statusText = '未连接';
            break;
          case ConnectionStatus.error:
            statusColor = Colors.red;
            statusText = '连接错误';
            break;
        }

        return ListTile(
          leading: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
            ),
          ),
          title: Text('WebSocket状态: $statusText'),
          subtitle: connectionId != null ? Text('连接ID: $connectionId') : null,
          trailing: status == ConnectionStatus.disconnected
              ? ElevatedButton(
                  onPressed: () => WebSocketService.instance.connect(),
                  child: const Text('连接'),
                )
              : status == ConnectionStatus.authenticated
              ? ElevatedButton(
                  onPressed: () => WebSocketService.instance.disconnect(),
                  child: const Text('断开'),
                )
              : null,
        );
      },
    );
  }
}

/// 测试聊天室列表
class _TestChatList extends StatelessWidget {
  // 测试数据
  final List<Map<String, dynamic>> testChats = [
    {
      'roomId': '00000000-0000-0000-0000-000000000001',
      'name': '测试群聊',
      'avatar': null,
      'type': ChatType.group,
    },
    {
      'roomId': '00000000-0000-0000-0000-000000000002',
      'name': 'Alice',
      'avatar': null,
      'type': ChatType.single,
    },
    {
      'roomId': '00000000-0000-0000-0000-000000000003',
      'name': 'Bob',
      'avatar': null,
      'type': ChatType.single,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            '测试聊天室',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        ...testChats.map(
          (chat) => ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey[300],
              child: Icon(
                chat['type'] == ChatType.group ? Icons.group : Icons.person,
                color: Colors.white,
              ),
            ),
            title: Text(chat['name']),
            subtitle: Text('房间ID: ${chat['roomId']}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _openChat(context, chat),
          ),
        ),
      ],
    );
  }

  void _openChat(BuildContext context, Map<String, dynamic> chat) {
    // 检查WebSocket是否已认证
    if (WebSocketService.instance.status != ConnectionStatus.authenticated) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先连接WebSocket')));
      return;
    }

    // 打开聊天详情页
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailPageV2(
          roomId: chat['roomId'],
          chatName: chat['name'],
          chatAvatar: chat['avatar'],
          chatType: chat['type'],
        ),
      ),
    );
  }
}

/// 示例：如何在其他页面使用ChatProvider
class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider()..loadChats(),
      child: Scaffold(
        appBar: AppBar(title: const Text('聊天列表')),
        body: Consumer<ChatProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.chats.isEmpty) {
              return const Center(child: Text('暂无聊天'));
            }

            return ListView.builder(
              itemCount: provider.chats.length,
              itemBuilder: (context, index) {
                final chat = provider.chats[index];
                return Dismissible(
                  key: Key(chat.id),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    provider.deleteChat(chat.id);
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: chat.avatar != null
                          ? AssetImage(chat.avatar!)
                          : null,
                      child: chat.avatar == null ? Text(chat.name[0]) : null,
                    ),
                    title: Row(
                      children: [
                        if (chat.isPinned) ...[
                          const Icon(Icons.push_pin, size: 16),
                          const SizedBox(width: 4),
                        ],
                        Expanded(child: Text(chat.name)),
                        if (chat.isMuted) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.volume_off, size: 16),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      chat.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          chat.displayTime,
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (chat.unreadCount > 0) ...[
                          const SizedBox(height: 4),
                          // 使用通用角标组件
                          AppBadge(
                            count: chat.unreadCount,
                            size: 18,
                            fontSize: 11,
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatDetailPageV2(
                            roomId: chat.roomId,
                            chatName: chat.name,
                            chatAvatar: chat.avatar,
                            chatType: chat.type,
                          ),
                        ),
                      );
                    },
                    onLongPress: () {
                      // 显示操作菜单
                      _showChatOptions(context, provider, chat);
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showChatOptions(
    BuildContext context,
    ChatProvider provider,
    Chat chat,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              chat.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
            ),
            title: Text(chat.isPinned ? '取消置顶' : '置顶聊天'),
            onTap: () {
              provider.pinChat(chat.id, !chat.isPinned);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(chat.isMuted ? Icons.volume_up : Icons.volume_off),
            title: Text(chat.isMuted ? '取消静音' : '消息免打扰'),
            onTap: () {
              provider.muteChat(chat.id, !chat.isMuted);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.clear_all),
            title: const Text('清空聊天记录'),
            onTap: () {
              provider.clearChatMessages(chat.roomId);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('删除聊天', style: TextStyle(color: Colors.red)),
            onTap: () {
              provider.deleteChat(chat.id);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
