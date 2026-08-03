import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import 'package:provider/provider.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/message_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/emoji_pack_service.dart';
import '../../core/services/emoji_item_service.dart';
import '../../core/services/upload_policy_service.dart';
import '../../core/services/room_service.dart';
import '../../core/services/websocket_service.dart';
import '../../core/storage/token_storage.dart';
import '../../core/storage/chat_draft_storage.dart';
import '../../core/storage/message_search_storage.dart';
import '../../core/theme/phone_density.dart';
import '../../core/utils/local_file_utils.dart';
import '../../core/utils/avatar_color_utils.dart';
import '../../core/widgets/tip_dialog.dart';
import '../../core/widgets/permission_gate.dart';
import '../../features/emoji/models/emoji_pack_models.dart';
import 'constants/emoji_list.dart';
import '../../core/widgets/skeleton.dart';
import 'providers/chat_provider.dart';
import 'models/chat_model.dart';
import 'models/message_model.dart';
import 'message_forward_executor.dart';
import 'group_settings_page.dart';
import 'pinned_messages_page.dart';
import 'message_search_page.dart';
import 'video_preview_page.dart';
import 'widgets/message_avatar.dart';
import 'widgets/message_action_menu.dart';
import 'widgets/message_editor_sheet.dart';
import 'widgets/message_delivery_status.dart';
import 'widgets/message_forward_sheet.dart';
import 'widgets/message_read_receipts_sheet.dart';
import 'widgets/quoted_message_avatar.dart';
import 'widgets/voice_message_widget.dart';
import '../../core/services/voice_service.dart';

part 'widgets/chat_message_bubble_v2.dart';
part 'widgets/chat_message_list.dart';
part 'widgets/chat_composer.dart';

class ChatDetailPageV2 extends StatefulWidget {
  const ChatDetailPageV2({
    super.key,
    required this.roomId,
    required this.chatName,
    this.chatAvatar,
    this.chatType = ChatType.single,
    this.chatProvider,
    this.websocketService,
    this.initialMessageId,
    this.draftStorage,
    this.permissionService,
    this.tokenStorage,
  });

  final String roomId;
  final String chatName;
  final String? chatAvatar;
  final ChatType chatType;
  final ChatProvider? chatProvider;
  final WebSocketService? websocketService;
  final String? initialMessageId;
  final ChatDraftStorage? draftStorage;
  final PermissionService? permissionService;
  final TokenStorage? tokenStorage;

  @override
  State<ChatDetailPageV2> createState() => _ChatDetailPageV2State();
}

@visibleForTesting
class ChatMessageItemKeyRegistry {
  final Map<String, GlobalKey> _keys = <String, GlobalKey>{};

  GlobalKey keyFor(String messageId) {
    return _keys.putIfAbsent(
      messageId,
      () => GlobalKey(debugLabel: 'chat-msg-$messageId'),
    );
  }

  void retainIds(Iterable<String> messageIds) {
    final activeIds = messageIds.toSet();
    _keys.removeWhere((messageId, _) => !activeIds.contains(messageId));
  }
}

/// 反应选择器底部表单
class _ReactionPickerSheet extends StatelessWidget {
  const _ReactionPickerSheet({required this.reactions});

  final List<String> reactions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: SafeArea(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: reactions.map((reaction) {
            return InkWell(
              onTap: () => Navigator.of(context).pop(reaction),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: Text(reaction, style: const TextStyle(fontSize: 28)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ChatDetailPageV2State extends State<ChatDetailPageV2>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final GlobalKey _inputAreaKey = GlobalKey();
  double _lastKeyboardInset = 0.0;
  double _keyboardInset = 0.0; // 当前键盘高度，用于避免频繁查询 MediaQuery
  Timer? _keyboardUpdateTimer; // 防抖定时器，减少键盘动画期间的 setState 调用
  Timer? _draftSaveTimer;
  late final ChatDraftStorage _draftStorage;
  bool _draftRestoreComplete = false;

  late ChatProvider _chatProvider;
  late final bool _ownsProvider;
  late final WebSocketService _webSocketService;
  bool _isAtBottom = true;
  bool _skipNextScrollAnimation = true;
  double _messageListOpacity = 0.0;
  String? _lastMessageId;
  int _lastMessageCount = 0;
  final Set<String> _messageEntryAnimationIds = <String>{};
  Message? _quotedMessage;
  bool _multiSelectMode = false;
  final Set<String> _selectedMessageIds = <String>{};
  final ChatMessageItemKeyRegistry _messageItemKeys =
      ChatMessageItemKeyRegistry();

  bool _showEmojiPanel = false;
  bool _showMorePanel = false;
  bool _showVoicePanel = false;
  bool _memberCountLoading = false;
  bool _memberCountLoadFailed = false;
  bool _wasKeyboardVisible = false;

  // 群聊 @ 提及
  bool _showMentionPanel = false;
  int _mentionStartIndex = -1;
  String _mentionKeyword = '';
  bool _mentionMembersLoading = false;
  List<_MentionMember> _mentionMembers = const <_MentionMember>[];

  // 禁言相关状态
  final RoomService _roomService = RoomService();
  late final TokenStorage _tokenStorage;
  bool _isGlobalMuted = false;
  bool _isPersonalMuted = false; // 个人禁言状态
  bool _isGroupOwnerOrAdmin = false;
  String? _highlightedMessageId; // 用于跳转高亮效果
  String? _currentUserId;
  StreamSubscription<GroupSettingsUpdatedEvent>? _groupSettingsSubscription;
  StreamSubscription<GroupMemberChangedEvent>? _groupMemberSubscription;
  StreamSubscription<TypingUpdateEvent>? _typingSubscription;

  static const Duration _typingThrottle = Duration(milliseconds: 1200);
  static const Duration _typingIdleDelay = Duration(milliseconds: 1500);
  static const int _messageEntryAnimationCacheLimit = 48;
  Timer? _typingIdleTimer;
  bool? _lastSentTypingState;
  DateTime? _lastSentTypingAt;

  final Set<String> _remoteTypingUsers = <String>{};
  final Map<String, Timer> _remoteTypingTimers = <String, Timer>{};

  @override
  void initState() {
    super.initState();
    _inputFocusNode.addListener(_handleInputFocusChanged);
    WidgetsBinding.instance.addObserver(this);
    _ownsProvider = widget.chatProvider == null;
    _chatProvider = widget.chatProvider ?? ChatProvider();
    _webSocketService =
        widget.websocketService ??
        widget.chatProvider?.webSocketService ??
        WebSocketService.instance;
    _tokenStorage = widget.tokenStorage ?? const TokenStorage();
    _draftStorage = widget.draftStorage ?? ChatDraftStorage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_initChat());
    });
    _scrollController.addListener(_onScroll);
    unawaited(_ensureCurrentUserId());
    unawaited(_restoreTextDraft());
    _textController.addListener(_handleLocalTextChanged);

    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus && (_showEmojiPanel || _showMorePanel)) {
        setState(() {
          _showEmojiPanel = false;
          _showMorePanel = false;
        });
      }

      if (!_inputFocusNode.hasFocus) {
        _stopTyping();
        if (_showMentionPanel) {
          setState(() {
            _showMentionPanel = false;
            _mentionStartIndex = -1;
            _mentionKeyword = '';
          });
        }
      }
    });

    _typingSubscription = _webSocketService.onTypingUpdate
        .where((event) => event.roomId == widget.roomId)
        .listen(_handleTypingUpdate);

    // 监听群设置更新事件（仅群聊）
    if (widget.chatType == ChatType.group) {
      _groupSettingsSubscription = _webSocketService.onGroupSettingsUpdated
          .where((event) => event.roomId == widget.roomId)
          .listen(_handleGroupSettingsUpdated);
      // 监听群成员变更事件（用于个人禁言/解禁）
      _groupMemberSubscription = _webSocketService.onGroupMemberChanged
          .where((event) => event.roomId == widget.roomId)
          .listen(_handleGroupMemberChanged);
    }
  }

  /// 处理群设置更新事件（WebSocket 推送）
  void _handleGroupSettingsUpdated(GroupSettingsUpdatedEvent event) {
    if (!mounted) return;
    setState(() {
      _isGlobalMuted = event.globalMuteEnabled;
    });
  }

  /// 处理群成员变更事件（WebSocket 推送）
  void _handleGroupMemberChanged(GroupMemberChangedEvent event) {
    if (!mounted) return;
    // 只处理当前用户的禁言/解禁事件
    if (event.memberId != _currentUserId) return;

    if (event.changeType == 'kicked') {
      _exitRemovedGroup();
    } else if (event.changeType == 'muted') {
      setState(() {
        _isPersonalMuted = true;
      });
    } else if (event.changeType == 'unmuted') {
      setState(() {
        _isPersonalMuted = false;
      });
    }
  }

  void _exitRemovedGroup() {
    final route = ModalRoute.of(context);
    if (route == null) return;

    final navigator = Navigator.of(context);
    navigator.popUntil((candidate) => candidate == route);
    if (mounted && navigator.canPop()) {
      navigator.pop('kicked');
    }
  }

  Future<void> _ensureCurrentUserId() async {
    if (_currentUserId != null && _currentUserId!.isNotEmpty) return;
    try {
      final session = await _tokenStorage.readSession();
      _currentUserId = session?.user.id;
    } catch (_) {
      // ignore
    }
  }

  void _handleLocalTextChanged() {
    _scheduleDraftSave();
    _updateMentionSuggestions();
    if (_isInputDisabled) {
      _stopTyping();
      return;
    }

    final content = _textController.text.trim();
    if (content.isEmpty) {
      _stopTyping();
      return;
    }

    _sendTyping(true);
    _typingIdleTimer?.cancel();
    _typingIdleTimer = Timer(_typingIdleDelay, () {
      if (!mounted) return;
      _sendTyping(false);
    });
  }

  Future<void> _restoreTextDraft() async {
    try {
      final session = await _tokenStorage.readSession();
      final accountId = session?.user.id;
      if (accountId == null || accountId.isEmpty) return;
      _currentUserId ??= accountId;
      final draft = await _draftStorage.load(
        accountId: accountId,
        roomId: widget.roomId,
      );
      if (!mounted || draft == null || _textController.text.isNotEmpty) return;
      _textController.text = draft;
      _textController.selection = TextSelection.collapsed(offset: draft.length);
    } catch (_) {
      // 草稿恢复失败不阻塞聊天。
    } finally {
      _draftRestoreComplete = true;
      if (_textController.text.isNotEmpty) _scheduleDraftSave();
    }
  }

  void _scheduleDraftSave() {
    if (!_draftRestoreComplete) return;
    _draftSaveTimer?.cancel();
    final text = _textController.text;
    _draftSaveTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_persistTextDraft(text));
    });
  }

  Future<void> _persistTextDraft(String text) async {
    final accountId = _currentUserId;
    if (accountId == null || accountId.isEmpty) return;
    try {
      await _draftStorage.save(
        accountId: accountId,
        roomId: widget.roomId,
        text: text,
      );
    } catch (_) {
      // 草稿持久化失败不阻塞输入与发送。
    }
  }

  Future<void> _clearTextDraft() async {
    _draftSaveTimer?.cancel();
    final accountId = _currentUserId;
    if (accountId == null || accountId.isEmpty) return;
    try {
      await _draftStorage.clear(accountId: accountId, roomId: widget.roomId);
    } catch (_) {
      // 消息已发送成功时，草稿清理失败不得改变发送结果。
    }
  }

  void _sendTyping(bool isTyping) {
    if (isTyping && _isInputDisabled) return;
    if (isTyping && !_inputFocusNode.hasFocus) return;

    final now = DateTime.now();
    if (_lastSentTypingState == isTyping &&
        _lastSentTypingAt != null &&
        now.difference(_lastSentTypingAt!) < _typingThrottle) {
      return;
    }

    _lastSentTypingState = isTyping;
    _lastSentTypingAt = now;
    _webSocketService.setTyping(widget.roomId, isTyping);
  }

  void _stopTyping() {
    _typingIdleTimer?.cancel();
    _typingIdleTimer = null;
    _sendTyping(false);
  }

  void _hideMentionPanel() {
    if (!_showMentionPanel) return;
    setState(() {
      _showMentionPanel = false;
      _mentionStartIndex = -1;
      _mentionKeyword = '';
    });
  }

  bool _isEmailLikePrevChar(String ch) {
    if (ch.isEmpty) return false;
    final code = ch.codeUnitAt(0);
    final isAsciiAlphaNum =
        (code >= 48 && code <= 57) ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122);
    return isAsciiAlphaNum || ch == '_' || ch == '.' || ch == '+' || ch == '-';
  }

  void _updateMentionSuggestions() {
    if (widget.chatType != ChatType.group) {
      _hideMentionPanel();
      return;
    }
    if (_isInputDisabled) {
      _hideMentionPanel();
      return;
    }
    if (!_inputFocusNode.hasFocus) {
      _hideMentionPanel();
      return;
    }

    final text = _textController.text;
    final selection = _textController.selection;
    final cursor = selection.baseOffset;
    if (cursor < 0 || cursor > text.length) {
      _hideMentionPanel();
      return;
    }

    final atIndex = cursor == 0 ? -1 : text.lastIndexOf('@', cursor - 1);
    if (atIndex < 0) {
      _hideMentionPanel();
      return;
    }

    if (atIndex > 0 && _isEmailLikePrevChar(text[atIndex - 1])) {
      _hideMentionPanel();
      return;
    }

    final keyword = text.substring(atIndex + 1, cursor);
    if (keyword.contains(RegExp(r'\s'))) {
      _hideMentionPanel();
      return;
    }

    // 与后端 @ 解析规则保持一致：仅允许字母数字/下划线/短横线/常用中文字符
    final tokenPattern = RegExp(r'^[0-9A-Za-z_\-\u4e00-\u9fff]*$');
    if (!tokenPattern.hasMatch(keyword)) {
      _hideMentionPanel();
      return;
    }

    if (!_showMentionPanel ||
        _mentionStartIndex != atIndex ||
        _mentionKeyword != keyword) {
      setState(() {
        _showMentionPanel = true;
        _mentionStartIndex = atIndex;
        _mentionKeyword = keyword;
      });
    }

    if (!_mentionMembersLoading && _mentionMembers.isEmpty) {
      unawaited(_loadMentionMembers());
    }
  }

  Future<void> _loadMentionMembers() async {
    if (widget.chatType != ChatType.group) return;
    if (_mentionMembersLoading) return;

    if (mounted) {
      setState(() => _mentionMembersLoading = true);
    } else {
      _mentionMembersLoading = true;
    }

    try {
      final members = await _chatProvider.getRoomMembers(widget.roomId);
      if (!mounted) return;

      final parsed = <_MentionMember>[];
      for (final member in members) {
        final userIdValue =
            member['user_id'] ?? member['userId'] ?? member['id'];
        final userId = userIdValue is String
            ? userIdValue
            : userIdValue?.toString();
        if (userId == null || userId.trim().isEmpty) continue;
        if (_currentUserId != null && userId == _currentUserId) continue;

        final usernameValue = member['username'];
        final username = usernameValue is String
            ? usernameValue
            : usernameValue?.toString();
        if (username == null || username.trim().isEmpty) continue;

        final nicknameValue = member['nickname'];
        final nickname = nicknameValue is String
            ? nicknameValue
            : nicknameValue?.toString();
        final displayName = (nickname != null && nickname.trim().isNotEmpty)
            ? nickname.trim()
            : username.trim();

        final avatarValue =
            member['avatar_url'] ?? member['avatarUrl'] ?? member['avatar'];
        final avatarUrl = avatarValue is String
            ? avatarValue
            : avatarValue?.toString();

        parsed.add(
          _MentionMember(
            userId: userId,
            username: username.trim(),
            displayName: displayName,
            avatarUrl: avatarUrl,
          ),
        );
      }

      parsed.sort((a, b) => a.displayNameLower.compareTo(b.displayNameLower));
      setState(() => _mentionMembers = parsed);
    } catch (e) {
      debugPrint('[Mention] Failed to load members: $e');
    } finally {
      _mentionMembersLoading = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _insertMentionToken(String token) {
    final text = _textController.text;
    final selection = _textController.selection;
    final fallbackStart = selection.start.clamp(0, text.length).toInt();
    final replaceStart =
        (_mentionStartIndex >= 0 && _mentionStartIndex <= text.length)
        ? _mentionStartIndex
        : fallbackStart;
    final replaceEnd = selection.end.clamp(replaceStart, text.length).toInt();

    final replacement = '@$token ';
    final updated = text.replaceRange(replaceStart, replaceEnd, replacement);
    final newCursor = (replaceStart + replacement.length)
        .clamp(0, updated.length)
        .toInt();

    _textController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    _hideMentionPanel();
    FocusScope.of(context).requestFocus(_inputFocusNode);
  }

  Widget _buildMentionPanel(ThemeData theme) {
    final keyword = _mentionKeyword.trim().toLowerCase();
    final showAll =
        keyword.isEmpty ||
        'all'.startsWith(keyword) ||
        'everyone'.startsWith(keyword) ||
        'here'.startsWith(keyword) ||
        '全体'.contains(keyword) ||
        '全员'.contains(keyword) ||
        '所有人'.contains(keyword);

    final filtered = keyword.isEmpty
        ? _mentionMembers
        : _mentionMembers.where((m) {
            return m.usernameLower.contains(keyword) ||
                m.displayNameLower.contains(keyword);
          }).toList();

    final visible = filtered.take(12).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _mentionMembersLoading
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '正在加载群成员...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : (showAll || visible.isNotEmpty)
          ? ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: (showAll ? 1 : 0) + visible.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                thickness: 0.5,
                color: AppColors.divider,
              ),
              itemBuilder: (context, index) {
                var effectiveIndex = index;
                if (showAll) {
                  if (effectiveIndex == 0) {
                    return _MentionTile(
                      title: '全体成员',
                      subtitle: '@all',
                      avatarText: '@',
                      onTap: () => _insertMentionToken('all'),
                    );
                  }
                  effectiveIndex -= 1;
                }

                final member = visible[effectiveIndex];
                return _MentionTile(
                  title: member.displayName,
                  subtitle: '@${member.username}',
                  avatarText: member.displayNameAvatar,
                  avatarUrl: member.avatarUrl,
                  onTap: () => _insertMentionToken(member.username),
                );
              },
            )
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '未找到匹配的群成员',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
    );
  }

  void _handleTypingUpdate(TypingUpdateEvent event) {
    if (!mounted) return;
    if (_currentUserId != null && event.userId == _currentUserId) return;

    final userId = event.userId;
    _remoteTypingTimers[userId]?.cancel();
    _remoteTypingTimers.remove(userId);

    if (event.isTyping) {
      _remoteTypingUsers.add(userId);
      final ttl = event.expiresInMs > 0
          ? Duration(milliseconds: event.expiresInMs)
          : const Duration(milliseconds: 6000);
      _remoteTypingTimers[userId] = Timer(ttl, () {
        _remoteTypingTimers.remove(userId);
        _remoteTypingUsers.remove(userId);
        if (mounted) setState(() {});
      });
    } else {
      _remoteTypingUsers.remove(userId);
    }

    setState(() {});
  }

  String? get _typingIndicatorText {
    if (_remoteTypingUsers.isEmpty) return null;
    if (widget.chatType == ChatType.single) {
      return '对方正在输入...';
    }
    final count = _remoteTypingUsers.length;
    if (count == 1) return '有人正在输入...';
    return '$count人正在输入...';
  }

  Future<void> _initChat() async {
    // 创建Chat对象
    final chat = Chat(
      id: widget.roomId,
      roomId: widget.roomId,
      name: widget.chatName,
      avatar: widget.chatAvatar,
      type: widget.chatType,
      lastMessage: '',
      lastMessageTime: DateTime.now(),
    );

    // 进入聊天室（首次渲染完成后再加载历史，减少闪动）
    await _chatProvider.enterChatRoom(
      widget.roomId,
      chat,
      delayHistoryLoad: true,
    );

    if (!mounted) return;
    final hasCachedMessages = _chatProvider.messages.isNotEmpty;
    setState(() {
      _messageListOpacity = hasCachedMessages ? 1.0 : 0.0;
    });

    // 页面进入后自动滚动到底部（无动画）
    if (hasCachedMessages) {
      _scrollToBottom(animated: false);
    }

    if (widget.chatType == ChatType.group) {
      await _loadMemberCount();
      // 加载禁言状态（不使用 await，避免阻塞页面初始化）
      unawaited(_loadMuteStatus());
    }

    final initialMessageId = widget.initialMessageId?.trim();
    if (initialMessageId != null && initialMessageId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToMessage(initialMessageId);
      });
    }
  }

  /// 加载群禁言状态
  Future<void> _loadMuteStatus() async {
    if (widget.chatType != ChatType.group) return;

    try {
      // 获取当前用户 ID
      final session = await _tokenStorage.readSession();
      if (!mounted) return;
      _currentUserId = session?.user.id;

      // 加载群设置
      final settings = await _roomService.fetchGroupSettings(widget.roomId);
      if (!mounted) return;

      // 加载群成员列表以判断角色
      final members = await _chatProvider.getRoomMembers(widget.roomId);
      if (!mounted) return;

      final isOwnerOrAdmin = _computeGroupRole(
        members: members,
        currentUserId: _currentUserId,
      );

      // 检查个人禁言状态
      final isPersonalMuted = settings.myMute?.isMuted ?? false;

      setState(() {
        _isGlobalMuted = settings.globalMuteEnabled;
        _isPersonalMuted = isPersonalMuted;
        _isGroupOwnerOrAdmin = isOwnerOrAdmin;
      });
    } catch (e) {
      debugPrint('[禁言状态] 加载失败: $e');
    }
  }

  /// 计算当前用户是否是群主或管理员
  bool _computeGroupRole({
    required List<Map<String, dynamic>> members,
    String? currentUserId,
  }) {
    if (currentUserId == null || currentUserId.isEmpty) return false;

    for (final member in members) {
      final roleValue = member['role'] ?? member['member_role'];
      final role = roleValue is String
          ? roleValue.toLowerCase()
          : roleValue?.toString().toLowerCase();
      final memberIdValue =
          member['user_id'] ?? member['userId'] ?? member['id'];
      final memberId = memberIdValue is String
          ? memberIdValue
          : memberIdValue?.toString();

      if (memberId == currentUserId && (role == 'owner' || role == 'admin')) {
        return true;
      }
    }
    return false;
  }

  /// 输入框是否应该被禁用（全体禁言且非管理员，或个人被禁言）
  bool get _isInputDisabled {
    if (widget.chatType != ChatType.group) return false;
    // 个人被禁言时直接禁用
    if (_isPersonalMuted) return true;
    // 全体禁言时，管理员不受影响
    return _isGlobalMuted && !_isGroupOwnerOrAdmin;
  }

  String? get _inputDisabledHint {
    if (_isPersonalMuted) return '你已被管理员禁言';
    if (_isGlobalMuted && !_isGroupOwnerOrAdmin) return '当前群聊已开启全体禁言';
    return null;
  }

  @override
  void dispose() {
    _inputFocusNode.removeListener(_handleInputFocusChanged);
    _multiSelectMode = false;
    _selectedMessageIds.clear();
    _keyboardUpdateTimer?.cancel();
    _draftSaveTimer?.cancel();
    if (_draftRestoreComplete) {
      unawaited(_persistTextDraft(_textController.text));
    }
    _groupSettingsSubscription?.cancel();
    _groupMemberSubscription?.cancel();
    _typingSubscription?.cancel();
    _typingIdleTimer?.cancel();
    _webSocketService.setTyping(widget.roomId, false);
    _textController.removeListener(_handleLocalTextChanged);
    for (final timer in _remoteTypingTimers.values.toList()) {
      timer.cancel();
    }
    _remoteTypingTimers.clear();
    _remoteTypingUsers.clear();
    _scrollController.removeListener(_onScroll);
    _chatProvider.leaveChatRoom();
    if (_ownsProvider) {
      _chatProvider.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _handleInputFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final viewInset = view.viewInsets.bottom / view.devicePixelRatio;

    // 使用防抖机制，减少键盘动画期间的频繁 setState
    // 限制更新频率为每 16ms 一次（约 60fps），避免过度重建
    if ((viewInset - _keyboardInset).abs() > 0.5) {
      _keyboardUpdateTimer?.cancel();
      _keyboardUpdateTimer = Timer(const Duration(milliseconds: 16), () {
        if (!mounted) return;
        // 使用 scheduleMicrotask 确保在下一帧更新，避免阻塞当前帧
        scheduleMicrotask(() {
          if (!mounted) return;
          setState(() {
            _keyboardInset = viewInset;
          });
        });

        if (viewInset > _lastKeyboardInset) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _scrollToBottom(animated: false);
          });
        }
      });
    }
    _lastKeyboardInset = viewInset;
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    _dispatchSend(text: text);
  }

  Future<void> _dispatchSend({
    String? text,
    List<MessageAttachmentDraft> attachments = const [],
  }) async {
    if (_isInputDisabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_inputDisabledHint ?? '当前无法发送消息')),
        );
      }
      return;
    }

    final trimmed = text?.trim();
    if ((trimmed == null || trimmed.isEmpty) && attachments.isEmpty) {
      return;
    }

    final keepEmojiPanelVisible = _showEmojiPanel;

    try {
      _stopTyping();
      await _chatProvider.sendRichMessage(
        text: trimmed,
        attachments: attachments,
        quotedMessage: _quotedMessage,
      );
      _clearMultiSelect();
      if (!mounted) return;
      if (trimmed != null && trimmed.isNotEmpty) {
        _textController.clear();
        await _clearTextDraft();
      }
      if (_quotedMessage != null) {
        setState(() => _quotedMessage = null);
      }
      setState(() {
        _showEmojiPanel = keepEmojiPanelVisible;
        _showMorePanel = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!keepEmojiPanelVisible) {
          FocusScope.of(context).requestFocus(_inputFocusNode);
        }
        _scrollToBottom(animated: false);
      });
    } catch (error) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(SnackBar(content: Text('发送消息失败：$error')));
    }
  }

  void _scrollToBottom({int retry = 0, bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) {
        if (retry < 10) {
          _scrollToBottom(retry: retry + 1, animated: animated);
        }
        return;
      }

      final position = _scrollController.position;
      final target = position.maxScrollExtent;
      final shouldAnimate = animated && !_skipNextScrollAnimation;
      _skipNextScrollAnimation = false;

      if (shouldAnimate) {
        try {
          _scrollController
              .animateTo(
                target,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
              )
              .whenComplete(_settleToBottom);
        } catch (_) {
          if (retry < 5) {
            _scrollToBottom(retry: retry + 1, animated: animated);
          }
        }
      } else {
        if ((position.pixels - target).abs() > 0.5) {
          _scrollController.jumpTo(target);
        }
        _settleToBottom();
      }
    });
  }

  void _settleToBottom({int attempt = 0}) {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final remaining = position.maxScrollExtent - position.pixels;
    if (remaining <= 0.5) {
      return;
    }

    if (attempt >= 8) {
      final lastId = _lastMessageId;
      if (lastId != null) {
        final key = _messageItemKeys.keyFor(lastId);
        final targetContext = key.currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            duration: Duration.zero,
            alignment: 1.0,
          );
        }
      }
      return;
    }

    _scrollController.jumpTo(position.maxScrollExtent);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _settleToBottom(attempt: attempt + 1);
    });
  }

  Future<void> _loadMemberCount({bool forceRefresh = false}) async {
    if (widget.chatType != ChatType.group) return;
    if (_memberCountLoading && !forceRefresh) return;

    setState(() {
      _memberCountLoading = true;
      _memberCountLoadFailed = false;
    });

    try {
      await _chatProvider.getRoomMemberCount(
        widget.roomId,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _memberCountLoadFailed = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _memberCountLoadFailed = true;
      });
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(SnackBar(content: Text('加载群成员失败：$e')));
    } finally {
      if (mounted) {
        setState(() {
          _memberCountLoading = false;
        });
      } else {
        _memberCountLoading = false;
      }
    }
  }

  String _groupMemberSubtitle(ChatProvider provider) {
    final cachedCount = provider.cachedMemberCount(widget.roomId);
    if (cachedCount != null) {
      return '共$cachedCount人';
    }
    if (_memberCountLoadFailed) {
      return '成员加载失败，点击重试';
    }
    return '成员加载中...';
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = _keyboardInset > 0.0;

    if (keyboardVisible && !_wasKeyboardVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToBottom(animated: false);
      });
    }
    _wasKeyboardVisible = keyboardVisible;

    final double listBottomPadding = (_showEmojiPanel || _showMorePanel)
        ? 16.0
        : 12.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: ChangeNotifierProvider.value(
        value: _chatProvider,
        child: PopScope(
          canPop: !_inputFocusNode.hasFocus && _keyboardInset <= 0,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && (_inputFocusNode.hasFocus || _keyboardInset > 0)) {
              _dismissKeyboard();
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            resizeToAvoidBottomInset: true,
            body: SafeArea(
              top: true,
              bottom: false, // 禁用底部 SafeArea，减少键盘动画时的布局计算
              child: Column(
                children: [
                  _buildHeader(context),
                  if (_multiSelectMode) _buildMultiSelectBar(Theme.of(context)),
                  // 置顶消息 banner - 固定在导航栏下方，不跟随滚动
                  Consumer<ChatProvider>(
                    builder: (context, provider, child) {
                      final pinnedMessage = provider.pinnedMessage;
                      if (pinnedMessage == null ||
                          !provider.messages.contains(pinnedMessage)) {
                        return const SizedBox.shrink();
                      }
                      return RepaintBoundary(
                        key: ValueKey('pinned_banner_${pinnedMessage.id}'),
                        child: _PinnedMessageBanner(
                          message: pinnedMessage,
                          onTap: () => _scrollToMessage(pinnedMessage.id),
                          onUnpin: () =>
                              unawaited(_togglePinMessage(pinnedMessage)),
                          onIconTap: () => _showPinnedMessagesPanel(),
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        RepaintBoundary(
                          child: _buildMessageList(listBottomPadding),
                        ),
                        // 回到底部按钮
                        if (!_isAtBottom)
                          Positioned(
                            right: 16,
                            bottom: 16,
                            child: _ScrollToBottomButton(
                              onTap: () => _scrollToBottom(animated: true),
                            ),
                          ),
                      ],
                    ),
                  ),
                  RepaintBoundary(child: _buildInputArea()),
                  if (_showEmojiPanel)
                    _EmojiPanel(onEmojiSelected: _handleEmojiSelected),
                  if (_showMorePanel)
                    _MoreActionsPanel(onActionSelected: _handleMoreAction),
                  if (_showVoicePanel)
                    VoiceRecordingPanel(
                      onRecordingComplete: _handleVoiceRecordingComplete,
                      onCancel: _cancelVoiceRecording,
                      permissionService: widget.permissionService,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        final showUpdating = provider.isLoading && provider.messages.isEmpty;
        final statusStyle = theme.textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        );

        return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
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
          child: Row(
            children: [
              Semantics(
                button: true,
                label: '返回',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _handleBackNavigation,
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 标题
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chatName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.chatType == ChatType.group) ...[
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: _memberCountLoadFailed
                            ? () => _loadMemberCount(forceRefresh: true)
                            : null,
                        child: Text(
                          _groupMemberSubtitle(provider),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            decoration: _memberCountLoadFailed
                                ? TextDecoration.underline
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axis: Axis.horizontal,
                      child: child,
                    ),
                  );
                },
                child: showUpdating
                    ? Padding(
                        key: const ValueKey('header-updating'),
                        padding: const EdgeInsets.only(left: 8),
                        child: Text('(更新中...)', style: statusStyle),
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('header-updating-off'),
                      ),
              ),

              // 搜索按钮
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _openMessageSearch,
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.search_rounded,
                      size: 24,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),

              // 更多按钮
              Material(
                key: const ValueKey('chat-info-button'),
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _showChatInfo,
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.more_horiz,
                      size: 24,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openMessageSearch() async {
    final result = await Navigator.of(context).push<MessageSearchResult>(
      MaterialPageRoute(
        builder: (_) => MessageSearchPage(initialRoomId: widget.roomId),
      ),
    );
    if (!mounted || result == null) return;

    if (result.roomId == widget.roomId) {
      _scrollToMessage(result.id);
      return;
    }

    Chat? targetChat;
    try {
      targetChat = _chatProvider.chats.firstWhere(
        (c) => c.roomId == result.roomId,
      );
    } catch (_) {
      targetChat = null;
    }

    if (targetChat == null) {
      _showErrorSnack('未找到对应会话');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailPageV2(
          roomId: targetChat!.roomId,
          chatName: targetChat.name,
          chatAvatar: targetChat.avatar,
          chatType: targetChat.type,
          initialMessageId: result.id,
        ),
      ),
    );
  }

  void _handleBackNavigation() {
    if (_inputFocusNode.hasFocus || _keyboardInset > 0) {
      _dismissKeyboard();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _dismissKeyboard() {
    _inputFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _revealMessageList() {
    if (_messageListOpacity >= 1.0) return;
    setState(() => _messageListOpacity = 1.0);
  }

  Widget _buildMultiSelectBar(ThemeData theme) {
    final isRelayOnlyMode = _chatProvider.isRelayOnlyMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text(
            '已选 $_selectedCount 条',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (!isRelayOnlyMode) ...[
            TextButton(
              onPressed: _selectedCount == 0 ? null : _forwardSelectedMessages,
              child: const Text('转发'),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: _selectedCount == 0 ? null : _deleteSelectedMessages,
              child: const Text(
                '删除',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
            const SizedBox(width: 6),
          ],
          IconButton(
            onPressed: _clearMultiSelect,
            icon: const Icon(Icons.close),
            tooltip: '退出多选',
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final density = context.phoneDensity;
    final theme = Theme.of(context);
    final typingText = _typingIndicatorText;

    return Container(
      key: _inputAreaKey,
      padding: EdgeInsets.symmetric(
        horizontal: density.scale(12),
        vertical: density.scale(8),
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 优化 AnimatedSwitcher：使用更简单的动画，减少键盘动画期间的性能开销
            // 移除 ClipRect 以减少额外的裁剪计算
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              // 简化 transition，只使用 FadeTransition，移除 SizeTransition 以减少布局计算
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.bottomCenter,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              child: _quotedMessage == null
                  ? const SizedBox.shrink(key: ValueKey('empty'))
                  : _QuotePreviewBar(
                      key: ValueKey(_quotedMessage!.id),
                      message: _quotedMessage!,
                      onClose: _clearQuotedMessage,
                      onTap: () => _scrollToMessage(_quotedMessage!.id),
                    ),
            ),
            if (_quotedMessage != null) SizedBox(height: density.scale(8)),
            if (typingText != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: density.scale(10),
                    vertical: density.scale(4),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(density.scale(10)),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Text(
                    typingText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              SizedBox(height: density.scale(8)),
            ],
            if (_showMentionPanel) ...[
              _buildMentionPanel(theme),
              SizedBox(height: density.scale(8)),
            ],
            // 为输入区域添加高度过渡动画，减轻高度瞬间变化带来的突兀感
            AnimatedSize(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              alignment: Alignment.bottomCenter,
              child: ChatInputWidget(
                key: ValueKey(
                  _isInputDisabled
                      ? 'chat-input-disabled'
                      : 'chat-input-enabled',
                ),
                controller: _textController,
                focusNode: _inputFocusNode,
                onSendMessage: _sendMessage,
                onToggleVoice: _toggleVoice,
                onToggleEmoji: _toggleEmoji,
                onToggleMore: _toggleMore,
                showEmojiPanel: _showEmojiPanel,
                showMorePanel: _showMorePanel,
                isDisabled: _isInputDisabled,
                disabledHint: _inputDisabledHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleVoice() {
    setState(() {
      _showVoicePanel = !_showVoicePanel;
      _showEmojiPanel = false;
      _showMorePanel = false;
    });

    if (_showVoicePanel) {
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _handleVoiceRecordingComplete(VoiceRecording recording) async {
    setState(() {
      _showVoicePanel = false;
    });

    try {
      // 读取语音文件
      final voiceService = VoiceService();
      final fileBytes = await voiceService.readVoiceFile(recording.path);
      if (fileBytes == null) {
        _showErrorSnack('语音文件读取失败');
        return;
      }

      // 发送语音消息
      await _chatProvider.sendVoiceMessage(
        roomId: widget.roomId,
        fileBytes: fileBytes,
        duration: recording.duration,
        fileName: 'voice_${recording.id}.m4a',
      );

      _scrollToBottom();
    } catch (e) {
      debugPrint('发送语音消息失败: $e');
      _showErrorSnack('发送语音失败');
    }
  }

  void _cancelVoiceRecording() {
    setState(() {
      _showVoicePanel = false;
    });
  }

  void _toggleEmoji() {
    setState(() {
      _showEmojiPanel = !_showEmojiPanel;
      _showMorePanel = false;
      _showVoicePanel = false;
    });

    if (_showEmojiPanel) {
      FocusScope.of(context).unfocus();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottom(animated: false);
    });
  }

  void _toggleMore() {
    setState(() {
      _showMorePanel = !_showMorePanel;
      _showEmojiPanel = false;
      _showVoicePanel = false;
    });

    if (_showMorePanel) {
      FocusScope.of(context).unfocus();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottom(animated: false);
    });
  }

  void _clearQuotedMessage() {
    if (_quotedMessage == null) return;
    setState(() => _quotedMessage = null);
  }

  void _startMultiSelect(Message message) {
    if (_multiSelectMode) return;
    setState(() {
      _multiSelectMode = true;
      _selectedMessageIds
        ..clear()
        ..add(message.id);
    });
  }

  void _toggleMessageSelection(Message message) {
    if (!_multiSelectMode) return;
    setState(() {
      if (_selectedMessageIds.contains(message.id)) {
        _selectedMessageIds.remove(message.id);
      } else {
        _selectedMessageIds.add(message.id);
      }
    });
  }

  void _clearMultiSelect() {
    if (!_multiSelectMode && _selectedMessageIds.isEmpty) return;
    setState(() {
      _multiSelectMode = false;
      _selectedMessageIds.clear();
    });
  }

  int get _selectedCount => _selectedMessageIds.length;

  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;
    final messages = List<Message>.from(
      _chatProvider.messages,
    ).where((m) => _selectedMessageIds.contains(m.id)).toList();
    final nonSelf = messages.where((m) => !m.isSelf).toList();
    if (nonSelf.isNotEmpty) {
      _showErrorSnack('只能删除自己发送的消息');
      return;
    }
    for (final msg in messages) {
      try {
        await _chatProvider.deleteMessage(msg);
      } catch (e) {
        debugPrint('删除消息失败: $e');
        _showErrorSnack('删除消息失败');
        return;
      }
    }
    _clearMultiSelect();
  }

  Future<void> _forwardSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;
    final messages = List<Message>.from(
      _chatProvider.messages,
    ).where((m) => _selectedMessageIds.contains(m.id)).toList();

    final chats = List<Chat>.from(
      _chatProvider.chats.where((chat) => chat.roomId != widget.roomId),
    );
    if (chats.isEmpty) {
      _showErrorSnack('暂无可转发的会话');
      return;
    }

    final targetChats = await showModalBottomSheet<List<Chat>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MessageForwardSheet(
        chats: chats,
        previewText: _forwardPreview(messages.first),
        excludedRoomId: widget.roomId,
      ),
    );

    if (!mounted || targetChats == null || targetChats.isEmpty) return;

    final result = await forwardMessagesToTargets(
      messages: messages,
      targets: targetChats,
      forward: _chatProvider.forwardMessage,
    );
    if (!mounted) return;
    _showForwardResult(result);
    if (result.successCount > 0) {
      _clearMultiSelect();
    }
  }

  void _scrollToMessage(String messageId) {
    debugPrint('[跳转] _scrollToMessage 被调用，目标消息ID: $messageId');

    // 立即触发高亮（不等滚动完成）
    _highlightMessage(messageId);

    // 检查消息是否在当前列表中
    final messages = _chatProvider.messages;
    final targetIndex = messages.indexWhere((m) => m.id == messageId);
    debugPrint('[跳转] 消息在列表中的索引: $targetIndex (总数: ${messages.length})');

    if (targetIndex >= 0) {
      // 消息已在列表中，直接滚动
      _scrollToMessageAtIndex(messageId, targetIndex);
    } else {
      // 消息不在列表中，需要加载更多历史
      debugPrint('[跳转] 消息不在当前列表中，尝试加载历史');
      if (messages.isNotEmpty) {
        debugPrint('[跳转] 第一条消息ID: ${messages.first.id}');
        debugPrint('[跳转] 最后一条消息ID: ${messages.last.id}');
      }
      _loadAndScrollToMessage(messageId);
    }
  }

  void _scrollToMessageAtIndex(String messageId, int targetIndex) {
    debugPrint('[跳转] _scrollToMessageAtIndex: index=$targetIndex');

    // 计算是否有置顶消息 banner（会占用一个位置）
    final pinnedMessage = _chatProvider.pinnedMessage;
    final messages = _chatProvider.messages;
    final hasPinnedBanner =
        pinnedMessage != null && messages.contains(pinnedMessage);
    final effectiveIndex = hasPinnedBanner ? targetIndex + 1 : targetIndex;

    // 先尝试使用稳定复用的 GlobalKey（如果消息已渲染）
    final key = _messageItemKeys.keyFor(messageId);
    final targetContext = key.currentContext;

    if (targetContext != null) {
      debugPrint('[跳转] 消息已渲染，使用 ensureVisible');
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
      return;
    }

    // 消息未渲染（不在可视区域），需要先滚动到大概位置
    debugPrint('[跳转] 消息未渲染，使用估算位置滚动');

    if (!_scrollController.hasClients) {
      debugPrint('[跳转] ScrollController 没有 clients');
      return;
    }

    // 估算每条消息的平均高度（包含间距）
    // 根据实际布局，消息气泡高度约 60-120，时间戳约 30，间距 16
    const estimatedItemHeight = 100.0;

    // 计算目标位置
    final targetOffset = effectiveIndex * estimatedItemHeight;
    final maxOffset = _scrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxOffset);

    debugPrint('[跳转] 估算位置: $targetOffset, 最大: $maxOffset, 实际: $clampedOffset');

    // 使用动画滚动到估算位置
    _scrollController
        .animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        )
        .then((_) {
          if (!mounted) return;
          _finishScrollToMessage(messageId, 0);
        });
  }

  void _finishScrollToMessage(String messageId, int attempt) {
    if (attempt >= 5) {
      debugPrint('[跳转] 达到最大重试次数');
      return;
    }

    final key = _messageItemKeys.keyFor(messageId);
    final targetContext = key.currentContext;

    if (targetContext != null) {
      debugPrint('[跳转] 精确定位，attempt=$attempt');
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: 0.3,
      );
    } else {
      // 可能还没渲染，继续等待
      debugPrint('[跳转] 等待渲染，attempt=$attempt');
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _finishScrollToMessage(messageId, attempt + 1);
        }
      });
    }
  }

  Future<void> _loadAndScrollToMessage(String messageId) async {
    debugPrint('[跳转] _loadAndScrollToMessage 开始，目标消息ID: $messageId');

    // 显示加载提示
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('正在加载消息...'),
        duration: Duration(milliseconds: 1500),
      ),
    );

    // 尝试加载包含目标消息的历史记录
    debugPrint('[跳转] 调用 loadMessagesUntilFound...');
    final found = await _chatProvider.loadMessagesUntilFound(messageId);
    debugPrint('[跳转] loadMessagesUntilFound 返回: $found');

    if (!mounted) return;

    messenger?.hideCurrentSnackBar();

    if (found) {
      // 等待 widget 重建
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;

      // 找到消息的索引并滚动
      final messages = _chatProvider.messages;
      final targetIndex = messages.indexWhere((m) => m.id == messageId);
      debugPrint('[跳转] 消息找到，索引: $targetIndex');

      if (targetIndex >= 0) {
        _scrollToMessageAtIndex(messageId, targetIndex);
      } else {
        debugPrint('[跳转] 奇怪：found=true 但索引找不到');
        messenger?.showSnackBar(const SnackBar(content: Text('消息定位失败')));
      }
    } else {
      // 未找到消息
      debugPrint('[跳转] 消息未找到');
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            _chatProvider.currentMessageRuntime.messageLocateMissNotice,
          ),
        ),
      );
    }
  }

  void _highlightMessage(String messageId) {
    setState(() {
      _highlightedMessageId = messageId;
    });

    // 高亮效果持续 5 秒后自动消失（与动画时长一致）
    Future.delayed(const Duration(milliseconds: 5000), () {
      if (mounted && _highlightedMessageId == messageId) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }

  void _showErrorSnack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSnack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleEmojiSelected(String emoji) {
    // 判断是图片 URL 还是 emoji 字符
    final isImageUrl =
        emoji.startsWith('http://') || emoji.startsWith('https://');

    if (isImageUrl) {
      // 图片表情：下载图片并作为图片消息发送
      unawaited(_sendEmojiImage(emoji));
    } else {
      // Emoji 字符：插入到输入框
      final selection = _textController.selection;
      final text = _textController.text;

      int start = selection.start;
      int end = selection.end;
      if (!selection.isValid || start < 0 || end < 0) {
        start = text.length;
        end = text.length;
      }

      final newText = text.replaceRange(start, end, emoji);

      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + emoji.length),
      );
    }
  }

  Future<void> _sendEmojiImage(String imageUrl) async {
    try {
      // 下载表情图片
      final response = await http.get(Uri.parse(imageUrl));

      if (response.statusCode != 200) {
        throw Exception('下载表情图片失败: ${response.statusCode}');
      }

      // 获取 content type
      final contentType =
          response.headers['content-type'] ??
          response.headers['Content-Type'] ??
          'image/png';

      // 从 URL 推断文件扩展名
      String fileName = 'emoji.png';
      try {
        final uri = Uri.parse(imageUrl);
        final pathname = uri.path;
        final match = RegExp(
          r'\.(gif|jpg|jpeg|png|webp)$',
          caseSensitive: false,
        ).firstMatch(pathname);
        if (match != null) {
          fileName = 'emoji.${match.group(1)}';
        }
      } catch (e) {
        // 如果 URL 解析失败，使用默认文件名
      }

      // 保存到临时文件
      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File(p.join(tempDir.path, fileName));
      await tempFile.writeAsBytes(response.bodyBytes);

      // 读取图片尺寸
      final bytes = await tempFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final width = image.width;
      final height = image.height;
      image.dispose();
      codec.dispose();

      // 创建图片附件草稿
      final draft = MessageAttachmentDraft(
        type: MessagePartType.image,
        file: tempFile,
        displayName: fileName,
        mime: contentType.toLowerCase(),
        width: width,
        height: height,
      );

      // 发送消息
      final text = _textController.text.trim();
      await _dispatchSend(
        text: text.isNotEmpty ? text : null,
        attachments: [draft],
      );

      // 清理临时目录（延迟清理，确保文件已上传）
      Future.delayed(const Duration(seconds: 5), () {
        try {
          tempDir.delete(recursive: true);
        } catch (e) {
          // 忽略清理错误
        }
      });
    } catch (error) {
      if (!mounted) return;
      _showErrorSnack('发送表情失败：$error');
    }
  }

  void _handleMoreAction(String action) {
    switch (action) {
      case 'album':
        unawaited(_pickImage());
        break;
      case 'camera':
        unawaited(_takePhoto());
        break;
      case 'file':
        unawaited(_pickFile());
        break;
    }

    setState(() {
      _showMorePanel = false;
    });
  }

  Future<void> _showMessageActions(
    Offset tapPosition,
    Message message,
    bool isSelf,
  ) async {
    if (_multiSelectMode) return;
    if (mounted && (_showEmojiPanel || _showMorePanel)) {
      setState(() {
        _showEmojiPanel = false;
        _showMorePanel = false;
      });
    }
    double? bottomBoundary;
    if (_inputAreaKey.currentContext != null) {
      final inputBox =
          _inputAreaKey.currentContext!.findRenderObject() as RenderBox?;
      if (inputBox != null && inputBox.hasSize) {
        bottomBoundary = inputBox.localToGlobal(Offset.zero).dy - 12;
      }
    }
    final action = await showMessageActionMenu(
      context: context,
      anchor: tapPosition,
      isSelf: isSelf,
      isTextMessage: message.type == MessageType.text,
      isDeleted: message.isDeleted,
      isPinned: _chatProvider.isMessagePinned(message),
      isRelayOnlyMode: _chatProvider.isRelayOnlyMode,
      bottomBoundary: bottomBoundary,
    );

    if (action == null || !mounted) return;
    await _handleMessageAction(action, message);
  }

  Future<void> _handleMessageAction(
    MessageAction action,
    Message message,
  ) async {
    switch (action) {
      case MessageAction.copy:
        if (message.type == MessageType.text && !message.isDeleted) {
          await Clipboard.setData(ClipboardData(text: message.content));
        }
        break;
      case MessageAction.quote:
        if (message.isDeleted) {
          return;
        }
        setState(() => _quotedMessage = message);
        FocusScope.of(context).requestFocus(_inputFocusNode);
        break;
      case MessageAction.edit:
        if (!mounted) return;
        await _editMessage(message);
        break;
      case MessageAction.forward:
        if (!mounted) return;
        await _forwardMessage(message);
        break;
      case MessageAction.pin:
        if (!mounted) return;
        await _togglePinMessage(message);
        break;
      case MessageAction.delete:
        if (!mounted) return;
        await _confirmDeleteMessage(message);
        break;
      case MessageAction.reaction:
        if (!mounted) return;
        await _showReactionPicker(message);
        break;
    }
  }

  Future<void> _editMessage(Message message) async {
    final content = await showMessageEditorSheet(
      context: context,
      initialContent: message.content,
    );
    if (!mounted || content == null) return;

    try {
      await _chatProvider.editMessage(message, content);
      if (mounted) _showSnack('消息已编辑');
    } catch (_) {
      if (mounted) _showErrorSnack('编辑失败，请稍后重试');
    }
  }

  static const List<String> _allowedReactions = [
    '👍',
    '❤️',
    '😂',
    '🎉',
    '😮',
    '😢',
  ];

  Future<void> _showReactionPicker(Message message) async {
    final selectedReaction = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReactionPickerSheet(reactions: _allowedReactions),
    );

    if (!mounted || selectedReaction == null) return;

    try {
      await _chatProvider.toggleReaction(message, selectedReaction);
    } catch (e) {
      debugPrint('Reaction action failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('操作失败，请稍后重试')));
    }
  }

  Future<void> _handleReactionTagTap(
    Message message,
    String reactionKey,
  ) async {
    try {
      await _chatProvider.toggleReaction(message, reactionKey);
    } catch (e) {
      debugPrint('Reaction tag tap failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('操作失败，请稍后重试')));
    }
  }

  Future<void> _forwardMessage(Message message) async {
    final chats = List<Chat>.from(
      _chatProvider.chats.where((chat) => chat.roomId != widget.roomId),
    );
    if (chats.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无可转发的会话')));
      return;
    }

    final selectedChats = await showModalBottomSheet<List<Chat>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MessageForwardSheet(
        chats: chats,
        previewText: _forwardPreview(message),
        excludedRoomId: widget.roomId,
      ),
    );

    if (!mounted || selectedChats == null || selectedChats.isEmpty) return;

    final result = await forwardMessagesToTargets(
      messages: [message],
      targets: selectedChats,
      forward: _chatProvider.forwardMessage,
    );
    if (!mounted) return;
    _showForwardResult(result);
  }

  String _forwardPreview(Message message) {
    if (message.isDeleted) return '消息已删除';
    if (message.type == MessageType.text) return message.content;
    return switch (message.type) {
      MessageType.image => '[图片消息]',
      MessageType.audio => '[语音消息]',
      MessageType.video => '[视频消息]',
      MessageType.file => '[文件消息]',
      MessageType.system => '[系统消息]',
      MessageType.mixed => '[多媒体消息]',
      MessageType.text => message.content,
    };
  }

  void _showForwardResult(MessageForwardResult result) {
    if (result.isCompleteSuccess) {
      _showSnack('已转发到 ${result.targetCount} 个会话');
      return;
    }
    final failedNames = result.failedTargetNames.join('、');
    if (result.isCompleteFailure) {
      _showErrorSnack('转发失败：$failedNames');
      return;
    }
    _showErrorSnack(
      '部分转发成功，${result.successCount} 条成功，'
      '${result.failureCount} 条失败（$failedNames）',
    );
  }

  Future<void> _togglePinMessage(Message message) async {
    final isPinned = _chatProvider.isMessagePinned(message);
    try {
      if (isPinned) {
        await _chatProvider.unpinMessage(message);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已取消置顶')));
      } else {
        await _chatProvider.pinMessage(message);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('消息已置顶')));
      }
    } catch (e) {
      debugPrint('Pin message failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('操作失败，请稍后重试')));
    }
  }

  Future<void> _confirmDeleteMessage(Message message) async {
    if (!message.isSelf || message.isDeleted) return;
    const title = '删除消息';
    const contentText = '删除后会同步到当前会话中的其他成员，确认删除？';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(contentText),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await _chatProvider.deleteMessage(message);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('消息已删除')));
    } catch (e) {
      debugPrint('Delete message failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试')));
    }
  }

  Future<void> _showMessageReaders(Message message) async {
    final chat = _chatProvider.currentChat;
    if (chat == null || chat.type != ChatType.group) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MessageReadReceiptsSheet(
        message: message,
        loadReaders: ({required bool forceRefresh}) => _chatProvider
            .fetchMessageReaders(message, forceRefresh: forceRefresh),
        loadMembers: () => _chatProvider.getRoomMembers(message.roomId),
      ),
    );
  }

  Future<void> _pickImage() async {
    if (!await ensureAppPermission(
      context,
      AppPermission.photos,
      service: widget.permissionService,
    )) {
      return;
    }
    if (!mounted) return;
    final picker = ImagePicker();
    try {
      final files = await picker.pickMultiImage(
        imageQuality: 90,
        maxWidth: 4096,
        maxHeight: 4096,
      );
      if (files.isEmpty) {
        return;
      }

      final drafts = <MessageAttachmentDraft>[];
      for (final file in files) {
        drafts.add(await _createImageDraft(file));
      }

      final text = _textController.text.trim();
      await _dispatchSend(
        text: text.isNotEmpty ? text : null,
        attachments: drafts,
      );
    } on PlatformException catch (error) {
      _showErrorSnack('访问相册失败：${error.message ?? error.code}');
    } catch (error) {
      _showErrorSnack('处理图片失败：$error');
    }
  }

  Future<void> _takePhoto() async {
    if (!await ensureAppPermission(
      context,
      AppPermission.camera,
      service: widget.permissionService,
    )) {
      return;
    }
    if (!mounted) return;
    final picker = ImagePicker();
    try {
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 4096,
        maxHeight: 4096,
      );
      if (photo == null) {
        return;
      }

      final draft = await _createImageDraft(photo);
      final text = _textController.text.trim();
      await _dispatchSend(
        text: text.isNotEmpty ? text : null,
        attachments: [draft],
      );
    } on PlatformException catch (error) {
      _showErrorSnack('启动相机失败：${error.message ?? error.code}');
    } catch (error) {
      _showErrorSnack('处理照片失败：$error');
    }
  }

  Future<void> _pickFile() async {
    try {
      final files = await openFiles(
        acceptedTypeGroups: const [XTypeGroup(label: 'all-files')],
      );
      if (files.isEmpty) {
        return;
      }

      final drafts = <MessageAttachmentDraft>[];
      for (final file in files) {
        drafts.add(await _createFileDraft(file));
      }

      final text = _textController.text.trim();
      await _dispatchSend(
        text: text.isNotEmpty ? text : null,
        attachments: drafts,
      );
    } on PlatformException catch (error) {
      _showErrorSnack('访问文件失败：${error.message ?? error.code}');
    } catch (error) {
      _showErrorSnack('处理文件失败：$error');
    }
  }

  Future<MessageAttachmentDraft> _createImageDraft(XFile source) async {
    final file = await _materializeXFile(source);
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final width = image.width;
    final height = image.height;
    image.dispose();
    codec.dispose();

    final mimeType = (source.mimeType ?? lookupMimeType(file.path) ?? 'image/*')
        .toLowerCase();
    final policy = await UploadPolicyService.instance.getPolicy();
    if (!policy.isMimeAllowedForPartType('image', mimeType)) {
      throw StateError('暂不支持该图片格式 ($mimeType)');
    }

    return MessageAttachmentDraft(
      type: MessagePartType.image,
      file: file,
      displayName: p.basename(file.path),
      mime: mimeType,
      width: width,
      height: height,
    );
  }

  Future<MessageAttachmentDraft> _createFileDraft(XFile source) async {
    final file = await _materializeXFile(source);
    final mimeType =
        (source.mimeType ??
                lookupMimeType(file.path) ??
                'application/octet-stream')
            .toLowerCase();

    final policy = await UploadPolicyService.instance.getPolicy();
    final partType = resolveAttachmentDraftTypeForFileMime(mimeType, policy);
    if (partType == MessagePartType.image) {
      return _createImageDraft(source);
    }

    return MessageAttachmentDraft(
      type: partType,
      file: file,
      displayName: p.basename(file.path),
      mime: mimeType,
    );
  }

  Future<File> _materializeXFile(XFile source) async {
    if (source.path.isNotEmpty) {
      final file = File(source.path);
      if (await file.exists()) {
        return file;
      }
    }

    final tempDir = await getTemporaryDirectory();
    final target = File(p.join(tempDir.path, source.name));
    await target.writeAsBytes(await source.readAsBytes(), flush: true);
    return target;
  }

  void _showChatInfo() {
    final chat =
        _chatProvider.currentChat ??
        Chat(
          id: widget.roomId,
          roomId: widget.roomId,
          name: widget.chatName,
          avatar: widget.chatAvatar,
          type: widget.chatType,
          lastMessage: '',
          lastMessageTime: DateTime.now(),
        );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GroupSettingsPage(
          chat: chat,
          chatProvider: _chatProvider,
          groupMemberChanges: _chatProvider.groupMemberChanges,
          groupSettingsUpdates: _chatProvider.groupSettingsUpdates,
        ),
      ),
    );
  }

  void _showPinnedMessagesPanel() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PinnedMessagesPage(
          roomId: widget.roomId,
          chatProvider: _chatProvider,
        ),
      ),
    );
  }

  void _onScroll() {
    final isNearBottom = _isListNearBottom();
    if (isNearBottom != _isAtBottom) {
      setState(() => _isAtBottom = isNearBottom);
    }
  }

  void _processMessages(List<Message> messages) {
    final previousCount = _lastMessageCount;
    final previousLastId = _lastMessageId;
    final latestId = messages.isNotEmpty ? messages.last.id : null;
    final changed =
        latestId != _lastMessageId || messages.length != _lastMessageCount;

    if (!changed) return;

    final wasAtBottom = _isAtBottom;
    final isNearBottom = _isListNearBottom();
    _isAtBottom = isNearBottom;
    _lastMessageId = latestId;
    _lastMessageCount = messages.length;

    final appendedLatestMessage =
        previousCount > 0 &&
        messages.length > previousCount &&
        latestId != null &&
        latestId != previousLastId;

    final shouldAutoScroll =
        wasAtBottom || previousCount == 0 || (!_hasScrollableContent());

    if (appendedLatestMessage && (wasAtBottom || isNearBottom)) {
      final added = _rememberMessageEntryAnimation(latestId);
      if (added && mounted) {
        setState(() {});
      }
    }

    if (shouldAutoScroll) {
      _scrollToBottom(animated: appendedLatestMessage);
    }
  }

  bool _rememberMessageEntryAnimation(String messageId) {
    if (_messageEntryAnimationIds.contains(messageId)) {
      return false;
    }

    _messageEntryAnimationIds.add(messageId);
    while (_messageEntryAnimationIds.length >
        _messageEntryAnimationCacheLimit) {
      _messageEntryAnimationIds.remove(_messageEntryAnimationIds.first);
    }
    return true;
  }

  // 距离底部超过此阈值时显示"回到底部"按钮（与桌面端一致）
  static const double _scrollBottomThreshold = 160.0;

  bool _isListNearBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    if (!position.hasPixels) return true;
    final max = position.maxScrollExtent;
    if (max <= 0) return true;
    final offsetFromBottom = max - position.pixels;
    return offsetFromBottom <= _scrollBottomThreshold;
  }

  bool _hasScrollableContent() {
    if (!_scrollController.hasClients) return false;
    final position = _scrollController.position;
    return position.maxScrollExtent > 0;
  }
}

@visibleForTesting
MessagePartType resolveAttachmentDraftTypeForFileMime(
  String mimeType,
  UploadPolicy policy,
) {
  final normalizedMimeType = mimeType.trim().toLowerCase();
  if (policy.isMimeAllowedForPartType('image', normalizedMimeType)) {
    return MessagePartType.image;
  }
  if (policy.isMimeAllowedForPartType('video', normalizedMimeType)) {
    return MessagePartType.video;
  }
  if (policy.isMimeAllowedForPartType('audio', normalizedMimeType)) {
    return MessagePartType.audio;
  }
  if (policy.isMimeAllowedForPartType('file', normalizedMimeType)) {
    return MessagePartType.file;
  }
  throw StateError('暂不支持该文件类型 ($normalizedMimeType)');
}

class _PinnedMessageBanner extends StatelessWidget {
  const _PinnedMessageBanner({
    required this.message,
    required this.onTap,
    required this.onUnpin,
    required this.onIconTap,
  });

  final Message message;
  final VoidCallback onTap;
  final VoidCallback onUnpin;
  final VoidCallback onIconTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _buildPreviewText();
    // 固定高度，避免轮播切换时整体高度抖动
    const bannerHeight = 52.0;

    return Container(
      height: bannerHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFF0F0F0), width: 1),
          bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左侧指示器
              Container(
                padding: const EdgeInsets.only(left: 16),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.push_pin, size: 18, color: AppColors.primary),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            '置顶消息',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: message.isDeleted
                                ? AppColors.textTertiary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 右侧图标按钮
              SizedBox(
                width: 64,
                child: Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: const Icon(
                      Icons.keyboard_arrow_right,
                      size: 20,
                      color: AppColors.textQuaternary,
                    ),
                    splashRadius: 18,
                    onPressed: onIconTap,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildPreviewText() {
    if (message.isDeleted) {
      return '消息已删除';
    }
    switch (message.type) {
      case MessageType.text:
        return message.content;
      case MessageType.image:
        return '[图片消息]';
      case MessageType.audio:
        return '[语音消息]';
      case MessageType.video:
        return '[视频消息]';
      case MessageType.file:
        return '[文件消息]';
      case MessageType.system:
        return '[系统消息]';
      case MessageType.mixed:
        return '[多媒体消息]';
    }
  }
}
