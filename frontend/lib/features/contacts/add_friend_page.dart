import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/friend_service.dart';
import '../../core/services/websocket_service.dart';
import '../../core/services/message_service.dart';
import '../../core/storage/token_storage.dart';
import '../auth/models/auth_user.dart';
import 'models/friend_models.dart';

class AddFriendPage extends StatefulWidget {
  const AddFriendPage({
    super.key,
    this.existingFriendIds = const <String>{},
    this.showRequestsFirst = false,
  });

  final Set<String> existingFriendIds;
  final bool showRequestsFirst;

  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  final TextEditingController _searchController = TextEditingController();
  final FriendService _friendService = FriendService();
  final TokenStorage _tokenStorage = const TokenStorage();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey _requestsKey = GlobalKey();

  List<AuthUser> _searchResults = [];
  List<FriendRequestInfo> _incoming = [];
  List<FriendRequestInfo> _outgoing = [];
  Set<String> _friendIds = {};
  final Set<String> _requestingUserIds = {};

  bool _searching = false;
  bool _hasSearched = false;
  bool _loadingRequests = true;
  bool _changed = false;
  String? _currentUserId;
  AuthUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _friendIds = {...widget.existingFriendIds};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePage();
    });
  }

  Future<void> _initializePage() async {
    await _loadSession();
    await _loadRequests(focusRequests: widget.showRequestsFirst);
  }

  Future<void> _loadSession() async {
    final session = await _tokenStorage.readSession();
    if (!mounted) return;
    setState(() {
      _currentUserId = session?.user.id;
      _currentUser = session?.user;
    });
  }

  Future<void> _loadRequests({bool focusRequests = false}) async {
    setState(() {
      _loadingRequests = true;
    });

    try {
      final results = await Future.wait([
        _friendService.fetchFriendRequests(
          direction: 'incoming',
          status: 'pending',
        ),
        _friendService.fetchFriendRequests(
          direction: 'outgoing',
          status: 'pending',
        ),
        _friendService.fetchFriends(),
      ]);

      if (!mounted) return;

      final incoming = results[0] as List<FriendRequestInfo>;
      final outgoing = results[1] as List<FriendRequestInfo>;
      final friends = results[2] as List<FriendInfo>;

      setState(() {
        _incoming = incoming;
        _outgoing = outgoing;
        _friendIds = {
          ...widget.existingFriendIds,
          ...friends.map((f) => f.user.id),
        };
        _loadingRequests = false;
      });

      if (focusRequests && _incoming.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToRequests(),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingRequests = false;
      });
      _showSnack(error is FriendServiceException ? error.message : '加载好友请求失败');
    }
  }

  Future<void> _reloadAll() async {
    await _loadRequests();
    if (_hasSearched && _searchController.text.trim().isNotEmpty) {
      await _performSearch(refreshOnly: true);
    }
  }

  Future<void> _performSearch({bool refreshOnly = false}) async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      if (!refreshOnly) {
        _showSnack('请输入搜索内容');
      }
      return;
    }

    if (!refreshOnly) {
      setState(() {
        _searching = true;
        _hasSearched = true;
      });
    }

    try {
      debugPrint('开始搜索用户: $keyword');
      final results = await _friendService.searchUsers(keyword);
      debugPrint('搜索结果: ${results.length} 个用户');
      for (final user in results) {
        debugPrint(
          '用户: id=${user.id}, username=${user.username}, displayName=${user.displayName}',
        );
      }
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        debugPrint(
          'setState 完成，_searchResults.length = ${_searchResults.length}',
        );
      });
    } catch (error) {
      debugPrint('搜索失败: $error');
      if (!mounted) return;
      _showSnack(error is FriendServiceException ? error.message : '搜索失败');
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      } else {
        _searching = false;
      }
    }
  }

  Future<String?> _showAddFriendDialog(AuthUser user) async {
    final controller = TextEditingController(text: _buildDefaultGreeting(user));
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('添加好友'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('发送好友请求时附带一句话：'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLength: 120,
                decoration: const InputDecoration(
                  hintText: '请输入打招呼内容，可留空',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.surfaceMuted,
                    backgroundImage:
                        (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                        ? const Icon(Icons.person_outline)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          user.email ?? '账号：${user.username}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('发送'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _sendRequest(AuthUser user) async {
    if (_requestingUserIds.contains(user.id)) return;

    final message = await _showAddFriendDialog(user);
    if (message == null) {
      return;
    }

    setState(() {
      _requestingUserIds.add(user.id);
    });

    try {
      final trimmed = message.trim();
      final request = await _friendService.sendFriendRequest(
        user.id,
        message: trimmed.isEmpty ? null : message,
      );
      if (!mounted) return;
      setState(() {
        _outgoing.removeWhere((item) => item.id == request.id);
        _outgoing.add(request);
        _requestingUserIds.remove(user.id);
        _changed = true;
      });
      _showSnack('好友请求已发送');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _requestingUserIds.remove(user.id);
      });
      _showSnack(error is FriendServiceException ? error.message : '发送好友请求失败');
    }
  }

  Future<void> _respondRequest(
    FriendRequestInfo request,
    FriendRequestAction action,
  ) async {
    try {
      final updated = await _friendService.respondFriendRequest(
        request.id,
        action,
      );
      if (!mounted) return;

      setState(() {
        _incoming.removeWhere((item) => item.id == request.id);
        _changed = true;
        if (updated.status == FriendRequestStatus.accepted) {
          final counterpartyId = updated.isIncoming
              ? updated.requester.id
              : updated.addressee.id;
          _friendIds.add(counterpartyId);
        }
      });

      // 同意后：确保创建单聊会话、加入 WS 房间并刷新会话列表
      if (action == FriendRequestAction.accept &&
          updated.status == FriendRequestStatus.accepted) {
        try {
          final counterpartyId = updated.isIncoming
              ? updated.requester.id
              : updated.addressee.id;
          final ensure = await _friendService.ensurePrivateChat(counterpartyId);

          // 立即加入该房间，确保后续消息能实时推送
          await WebSocketService.instance.joinRoom(ensure.roomId);

          // 若请求里包含打招呼内容，先用占位消息刷新聊天列表的显示
          if ((updated.message ?? '').trim().isNotEmpty) {
            await MessageService.instance.handleWebSocketMessage(
              WebSocketMessage(
                id: 'local-${DateTime.now().microsecondsSinceEpoch}',
                roomId: ensure.roomId,
                senderId: counterpartyId,
                senderUsername: updated.counterparty.username,
                senderNickname: updated.counterparty.nickname,
                senderAvatarUrl:
                    updated.counterparty.avatarUrl ?? ensure.friendAvatar,
                content: updated.message!.trim(),
                messageType: 'text',
                timestamp: DateTime.now(),
                extra: {
                  'room_type': ensure.roomType,
                  'room_name': ensure.roomName,
                  'sender_nickname': updated.counterparty.nickname,
                  'sender_username': updated.counterparty.username,
                },
                quotedMessage: null,
              ),
            );
          }

          // 再拉一次服务端会话，确保与后端状态一致
          await MessageService.instance.fetchChats();
        } catch (e) {
          debugPrint('ensure chat/join or refresh chats failed: $e');
        }
      }

      _showSnack(action == FriendRequestAction.accept ? '已添加好友' : '已拒绝该请求');
    } catch (error) {
      if (!mounted) return;
      _showSnack(error is FriendServiceException ? error.message : '处理请求失败');
    }
  }

  void _scrollToRequests() {
    final context = _requestsKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _close() {
    Navigator.of(context).pop(_changed);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _buildDefaultGreeting(AuthUser user) {
    final currentName = _currentUser?.displayName ?? '熊讯朋友';
    return '你好，我是$currentName，想添加你为好友';
  }

  bool _isSelf(AuthUser user) =>
      _currentUserId != null && user.id == _currentUserId;

  bool _isFriend(AuthUser user) => _friendIds.contains(user.id);

  bool _hasPendingOutgoing(AuthUser user) => _outgoing.any(
    (request) =>
        !request.isIncoming &&
        request.addressee.id == user.id &&
        request.status == FriendRequestStatus.pending,
  );

  FriendRequestInfo? _pendingIncomingRequest(AuthUser user) {
    for (final request in _incoming) {
      if (request.isIncoming &&
          request.requester.id == user.id &&
          request.status == FriendRequestStatus.pending) {
        return request;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _close();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('添加朋友'),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.close), onPressed: _close),
        ),
        backgroundColor: AppColors.background,
        body: RefreshIndicator(
          onRefresh: _reloadAll,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              _buildSearchCard(),
              const SizedBox(height: 24),
              if (_hasSearched) _buildSearchResults(),
              if (_hasSearched) const SizedBox(height: 24),
              _buildRequestSection(
                key: _requestsKey,
                title: '新的好友请求',
                requests: _incoming,
                incoming: true,
              ),
              const SizedBox(height: 24),
              _buildRequestSection(
                title: '我发出的申请',
                requests: _outgoing,
                incoming: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '手机号 / 用户名 / 邮箱',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _performSearch(),
              onChanged: (value) {
                if (value.isEmpty && _hasSearched) {
                  setState(() {
                    _hasSearched = false;
                    _searchResults.clear();
                  });
                }
              },
              decoration: InputDecoration(
                hintText: '输入好友账号，搜索并添加',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          if (_hasSearched) {
                            setState(() {
                              _hasSearched = false;
                              _searchResults.clear();
                            });
                          }
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _searching ? null : _performSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _searching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '搜索',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    debugPrint(
      '_buildSearchResults 被调用，_searching=$_searching, _searchResults.length=${_searchResults.length}',
    );

    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          '未找到匹配的用户',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    debugPrint('准备渲染 ${_searchResults.length} 个搜索结果');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '搜索结果',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        // 修复：使用 ListView.builder 替代 map 展开
        ...List.generate(
          _searchResults.length,
          (index) => _buildSearchResultTile(_searchResults[index]),
        ),
      ],
    );
  }

  Widget _buildSearchResultTile(AuthUser user) {
    debugPrint('_buildSearchResultTile 被调用: user=${user.username}');
    final isSelf = _isSelf(user);
    final isFriend = _isFriend(user);
    final pendingIncoming = _pendingIncomingRequest(user);
    final pendingOutgoing = _hasPendingOutgoing(user);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.surfaceMuted,
          backgroundImage:
              (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
              ? NetworkImage(user.avatarUrl!)
              : null,
          child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
              ? const Icon(Icons.person_outline)
              : null,
        ),
        title: Text(user.displayName),
        subtitle: Text(user.email ?? '账号：${user.username}'),
        trailing: _buildResultActions(
          user,
          isSelf: isSelf,
          isFriend: isFriend,
          pendingIncoming: pendingIncoming,
          pendingOutgoing: pendingOutgoing,
        ),
      ),
    );
  }

  Widget _buildResultActions(
    AuthUser user, {
    required bool isSelf,
    required bool isFriend,
    FriendRequestInfo? pendingIncoming,
    required bool pendingOutgoing,
  }) {
    if (isSelf) {
      return const _StatusTag(label: '本人');
    }

    if (isFriend) {
      return const _StatusTag(label: '已添加');
    }

    if (pendingOutgoing) {
      return const _StatusTag(label: '等待确认');
    }

    if (pendingIncoming != null) {
      // 修复：限制宽度，使用更紧凑的按钮布局
      return SizedBox(
        width: 140,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _respondRequest(
                  pendingIncoming,
                  FriendRequestAction.accept,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('同意', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _respondRequest(
                  pendingIncoming,
                  FriendRequestAction.decline,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('拒绝', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 70,
      child: ElevatedButton(
        onPressed: _requestingUserIds.contains(user.id)
            ? null
            : () => _sendRequest(user),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          minimumSize: const Size(0, 32),
        ),
        child: _requestingUserIds.contains(user.id)
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('添加', style: TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildRequestSection({
    Key? key,
    required String title,
    required List<FriendRequestInfo> requests,
    required bool incoming,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_loadingRequests)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (requests.isEmpty && !_loadingRequests)
            Text(
              incoming ? '暂无新的好友请求' : '暂无待处理的申请',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 14,
              ),
            )
          else
            // 修复：使用 List.generate 替代 map 展开
            ...List.generate(
              requests.length,
              (index) => _buildRequestTile(requests[index], incoming),
            ),
        ],
      ),
    );
  }

  Widget _buildRequestTile(FriendRequestInfo request, bool incoming) {
    final user = request.counterparty;
    final subtitle = user.email ?? '账号：${user.username}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.surfaceMuted,
          backgroundImage:
              (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
              ? NetworkImage(user.avatarUrl!)
              : null,
          child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
              ? const Icon(Icons.person_outline)
              : null,
        ),
        title: Text(user.displayName),
        subtitle: Text(subtitle),
        trailing: incoming
            ? _IncomingRequestActions(
                onAccept: () =>
                    _respondRequest(request, FriendRequestAction.accept),
                onDecline: () =>
                    _respondRequest(request, FriendRequestAction.decline),
              )
            : const _StatusTag(label: '等待确认'),
      ),
    );
  }
}

class _IncomingRequestActions extends StatelessWidget {
  const _IncomingRequestActions({
    required this.onAccept,
    required this.onDecline,
  });

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(label: '同意', color: Colors.green, onPressed: onAccept),
        const SizedBox(width: 6),
        _ActionButton(label: '拒绝', color: Colors.grey, onPressed: onDecline),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          minimumSize: const Size(0, 32),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }
}
