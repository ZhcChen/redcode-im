import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/friend_service.dart';
import '../../core/services/websocket_service.dart';
import '../../core/services/message_service.dart';
import '../../core/storage/token_storage.dart';
import '../../core/widgets/tip_dialog.dart';
import '../auth/models/auth_user.dart';
import 'models/friend_models.dart';

class AddFriendPage extends StatefulWidget {
  const AddFriendPage({
    super.key,
    this.existingFriendIds = const <String>{},
    this.showRequestsFirst = false,
    this.skipInitialLoad = false,
    this.initialSearchResults = const <AuthUser>[],
    this.initialIncomingRequests = const <FriendRequestInfo>[],
    this.initialOutgoingRequests = const <FriendRequestInfo>[],
    this.initialCurrentUser,
  });

  final Set<String> existingFriendIds;
  final bool showRequestsFirst;
  final bool skipInitialLoad;
  final List<AuthUser> initialSearchResults;
  final List<FriendRequestInfo> initialIncomingRequests;
  final List<FriendRequestInfo> initialOutgoingRequests;
  final AuthUser? initialCurrentUser;

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
    _searchResults = List<AuthUser>.of(widget.initialSearchResults);
    _incoming = List<FriendRequestInfo>.of(widget.initialIncomingRequests);
    _outgoing = List<FriendRequestInfo>.of(widget.initialOutgoingRequests);
    _currentUser = widget.initialCurrentUser;
    _currentUserId = widget.initialCurrentUser?.id;
    _hasSearched = _searchResults.isNotEmpty;
    _loadingRequests = !widget.skipInitialLoad;

    if (widget.skipInitialLoad) {
      return;
    }

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
    // 关闭键盘
    FocusScope.of(context).unfocus();

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
    final result = await TipDialog.showConfirmWithResult<String>(
      context,
      title: '添加好友',
      contentWidget: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _UserAvatar(user: user, size: 44),
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
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _buildUserSubtitle(user),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '附言',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '向对方简单介绍自己，方便更快通过。',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLength: 120,
            minLines: 3,
            maxLines: 4,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '请输入打招呼内容，可留空',
              hintStyle: const TextStyle(color: AppColors.textTertiary),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
      confirmText: '发送',
      cancelText: '取消',
      onConfirm: () async {
        return controller.text;
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
                forwardMessage: null,
                parts: const [],
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

  String _buildUserSubtitle(AuthUser user) {
    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email;
    }
    return '账号：${user.username}';
  }

  String _buildRequestMessage(
    FriendRequestInfo request, {
    required bool incoming,
  }) {
    final message = request.message?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    return incoming ? '对方暂未填写附言' : '已发送好友申请，等待对方确认';
  }

  String _formatRequestTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${date.month}/${date.day}';
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

  Widget _buildHintPanel(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _buildResultStatePanel({required String label, required String hint}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              hint,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _StatusTag(label: label),
        ],
      ),
    );
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
      color: Colors.white,
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
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _performSearch(),
              onChanged: (value) {
                setState(() {});
                if (value.isEmpty && _hasSearched) {
                  setState(() {
                    _hasSearched = false;
                    _searchResults.clear();
                  });
                }
              },
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '输入好友账号，搜索并添加',
                hintStyle: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 16,
                ),
                filled: true,
                fillColor: AppColors.surfaceMuted,
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                  size: 24,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
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
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _searching ? null : _performSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 2,
                  shadowColor: AppColors.primary.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _searching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            '搜索',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _UserAvatar(user: user, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _buildUserSubtitle(user),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildResultActions(
            user,
            isSelf: isSelf,
            isFriend: isFriend,
            pendingIncoming: pendingIncoming,
            pendingOutgoing: pendingOutgoing,
          ),
        ],
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
      return _buildResultStatePanel(label: '本人', hint: '这是你当前登录的账号');
    }

    if (isFriend) {
      return _buildResultStatePanel(label: '已添加', hint: '你们已经是好友了');
    }

    if (pendingOutgoing) {
      return _buildResultStatePanel(label: '等待确认', hint: '好友申请已发出，等待对方确认。');
    }

    if (pendingIncoming != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHintPanel('对方已向你发来好友申请，处理后会自动建立单聊会话。'),
          const SizedBox(height: 12),
          _IncomingRequestActions(
            onAccept: () =>
                _respondRequest(pendingIncoming, FriendRequestAction.accept),
            onDecline: () =>
                _respondRequest(pendingIncoming, FriendRequestAction.decline),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHintPanel('发送申请时可附上一句打招呼内容，方便对方更快识别你。'),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _requestingUserIds.contains(user.id)
                ? null
                : () => _sendRequest(user),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _requestingUserIds.contains(user.id)
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    '添加好友',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _UserAvatar(user: user, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _buildUserSubtitle(user),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!incoming) const _StatusTag(label: '等待确认'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      incoming ? '对方附言' : '我的附言',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatRequestTime(request.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _buildRequestMessage(request, incoming: incoming),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          if (incoming) ...[
            const SizedBox(height: 12),
            _IncomingRequestActions(
              onAccept: () =>
                  _respondRequest(request, FriendRequestAction.accept),
              onDecline: () =>
                  _respondRequest(request, FriendRequestAction.decline),
            ),
          ],
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user, this.size = 46});

  final AuthUser user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = user.displayName.isNotEmpty
        ? user.displayName[0].toUpperCase()
        : '?';

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
          ? NetworkImage(user.avatarUrl!)
          : null,
      child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
          ? Text(
              initial,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.32,
              ),
            )
          : null,
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
      children: [
        Expanded(
          child: _ActionButton(
            label: '同意',
            color: AppColors.primary,
            onPressed: onAccept,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            label: '拒绝',
            color: const Color(0xFFB7BEC8),
            onPressed: onDecline,
          ),
        ),
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
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
