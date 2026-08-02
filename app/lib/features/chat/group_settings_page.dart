import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_config.dart';
import '../../core/network/direct_upload.dart';
import '../../core/services/friend_service.dart';
import '../../core/services/message_service.dart';
import '../../core/services/room_avatar_service.dart';
import '../../core/services/room_service.dart';
import '../../core/storage/avatar_cache.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/avatar_color_utils.dart';
import '../../core/widgets/bottom_picker.dart';
import '../../core/widgets/custom_switch.dart';
import '../../core/widgets/input_dialog.dart';
import '../../core/widgets/sheet_header.dart';
import '../../core/widgets/tip_dialog.dart';
import '../auth/models/auth_user.dart';
import '../contacts/contact_detail_page.dart';
import '../contacts/models/friend_models.dart';
import 'group_admin_management_page.dart';
import 'group_join_requests_page.dart';
import 'group_mute_management_page.dart';
import 'group_operation_logs_page.dart';
import 'group_rules_page.dart';
import 'models/chat_model.dart';
import 'providers/chat_provider.dart';
import 'widgets/friend_selection_sheet.dart';

class _GroupAvatar extends StatefulWidget {
  const _GroupAvatar({super.key, required this.chat});

  final Chat chat;

  @override
  State<_GroupAvatar> createState() => _GroupAvatarState();
}

class _GroupAvatarState extends State<_GroupAvatar> {
  String? _cachedAvatarPath;
  bool _isLoading = false;
  final _roomAvatarService = RoomAvatarService();

  @override
  void initState() {
    super.initState();
    _cachedAvatarPath = widget.chat.localAvatarPath;

    // 验证本地缓存文件是否真的存在
    bool needsLoad = false;
    if (_cachedAvatarPath != null && _cachedAvatarPath!.isNotEmpty) {
      final file = File(_cachedAvatarPath!);
      if (!file.existsSync()) {
        _cachedAvatarPath = null;
        needsLoad = true;
      }
    } else {
      needsLoad = true;
    }

    // 如果有avatarObjectKey但没有有效的本地缓存，异步加载
    if (needsLoad &&
        widget.chat.avatarObjectKey != null &&
        widget.chat.avatarObjectKey!.isNotEmpty) {
      _loadAvatar();
    }
  }

  @override
  void didUpdateWidget(_GroupAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果avatarObjectKey变化，重新加载头像
    if (widget.chat.avatarObjectKey != oldWidget.chat.avatarObjectKey) {
      // 清空旧的缓存路径，强制重新加载
      setState(() {
        _cachedAvatarPath = null;
        _isLoading = false;
      });

      // 如果有新的 avatarObjectKey，异步加载
      if (widget.chat.avatarObjectKey != null &&
          widget.chat.avatarObjectKey!.isNotEmpty) {
        _loadAvatar();
      }
    }
  }

  Future<void> _loadAvatar() async {
    if (_isLoading) return;
    if (widget.chat.avatarObjectKey == null ||
        widget.chat.avatarObjectKey!.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final cachedPath = await _roomAvatarService.loadAndCacheAvatar(
        roomId: widget.chat.roomId,
        avatarObjectKey: widget.chat.avatarObjectKey!,
      );

      if (mounted) {
        setState(() {
          _cachedAvatarPath = cachedPath;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 优先使用本地缓存路径
    if (_cachedAvatarPath != null && _cachedAvatarPath!.isNotEmpty) {
      final file = File(_cachedAvatarPath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(48),
          child: Image.file(
            file,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
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
        width: 36,
        height: 36,
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
        return SvgPicture.asset(avatar, width: 36, height: 36);
      }
      // asset头像
      if (!avatar.startsWith('http://') && !avatar.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(48),
          child: Image.asset(avatar, width: 36, height: 36, fit: BoxFit.cover),
        );
      }
    }

    // 默认头像
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    final name = widget.chat.name.trim();
    final initial = AvatarColorUtils.getInitial(name);
    // 使用稳定种子（roomId）计算背景色，与 Desktop 端保持一致
    final seed = widget.chat.roomId;
    final backgroundColor = AvatarColorUtils.generateBackgroundColor(seed);

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(48),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class GroupSettingsPage extends StatefulWidget {
  const GroupSettingsPage({
    super.key,
    required this.chat,
    this.chatProvider,
    this.roomService,
    this.tokenStorage,
  });

  final Chat chat;
  final ChatProvider? chatProvider;
  final RoomService? roomService;
  final TokenStorage? tokenStorage;

  @override
  State<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends State<GroupSettingsPage> {
  late ChatProvider _chatProvider;
  late final bool _ownsProvider;
  late final RoomService _roomService;
  final FriendService _friendService = FriendService();
  late final TokenStorage _tokenStorage;
  late String _chatName;
  bool _isMuted = false;
  bool _isPinned = false;
  bool _isForbidden = false;
  bool _isLoadingMembers = false;
  bool _isLoadingSettings = false;
  bool _isUploadingAvatar = false;
  String? _currentUserId;
  bool _isGroupOwner = false;
  bool _isAdmin = false; // 是否为管理员
  String? _avatarObjectKey; // 用于跟踪最新的头像 key

  // 群成员列表
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _ownsProvider = widget.chatProvider == null;
    _chatProvider = widget.chatProvider ?? ChatProvider();
    _roomService = widget.roomService ?? RoomService();
    _tokenStorage = widget.tokenStorage ?? const TokenStorage();
    _chatName = widget.chat.name;
    _avatarObjectKey = widget.chat.avatarObjectKey; // 初始化头像 key
    _isMuted = widget.chat.isMuted;
    _isPinned = widget.chat.isPinned;
    _loadCurrentUser();
    _loadSettings();
    _loadMembers(); // 加载群成员
  }

  @override
  void dispose() {
    if (_ownsProvider) {
      _chatProvider.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (widget.chat.type != ChatType.group) return;
    setState(() => _isLoadingSettings = true);
    try {
      final settings = await _roomService.fetchGroupSettings(
        widget.chat.roomId,
      );
      if (!mounted) return;
      setState(() {
        _isForbidden = settings.globalMuteEnabled;
        _isLoadingSettings = false;
      });
    } catch (e) {
      // 群设置加载失败不影响核心功能，仅记录日志
      debugPrint('[群设置] 加载失败（不影响功能）: $e');
      if (mounted) {
        setState(() => _isLoadingSettings = false);
      }
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final session = await _tokenStorage.readSession();
      if (!mounted) return;
      final userId = session?.user.id;
      setState(() {
        _currentUserId = userId;
        _isGroupOwner = _computeOwnership(currentUserId: userId);
        _isAdmin = _computeIsAdmin(currentUserId: userId);
      });
    } catch (e) {
      debugPrint('加载当前用户失败: $e');
    }
  }

  Future<void> _loadMembers() async {
    if (widget.chat.type != ChatType.group) return;

    setState(() => _isLoadingMembers = true);

    try {
      final members = await _chatProvider.getRoomMembers(widget.chat.roomId);
      if (!mounted) return;
      setState(() {
        _members = members;
        _isLoadingMembers = false;
        _isGroupOwner = _computeOwnership(membersOverride: members);
        _isAdmin = _computeIsAdmin(membersOverride: members);
      });
    } catch (e) {
      debugPrint('加载群成员失败: $e');
      if (mounted) {
        setState(() => _isLoadingMembers = false);
      }
    }
  }

  /// 判断当前用户是否为管理员
  bool _computeIsAdmin({
    String? currentUserId,
    List<Map<String, dynamic>>? membersOverride,
  }) {
    if (widget.chat.type != ChatType.group) return false;
    final userId = currentUserId ?? _currentUserId;
    if (userId == null || userId.isEmpty) return false;

    final members = membersOverride ?? _members;
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
      if (role == 'admin' && memberId == userId) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isGroupOwner = _isGroupOwner;
    final canManageGroup = _isGroupOwner || _isAdmin;
    final memberCount = _chatProvider.cachedMemberCount(widget.chat.roomId);
    final navbarTitle = widget.chat.type == ChatType.group
        ? '聊天信息${memberCount != null ? "($memberCount)" : ""}'
        : '聊天详情';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(navbarTitle),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (widget.chat.type == ChatType.group) ...[
              _buildMemberSection(context),
              const SizedBox(height: 16),
              _buildGroupInfoSection(context),
              const SizedBox(height: 16),
            ],
            _buildSettingsSection(context, canManageGroup),
            // 群聊管理入口（仅群主/管理员可见）
            if (widget.chat.type == ChatType.group && canManageGroup)
              _buildManagementSection(context),
            if (widget.chat.type == ChatType.group) ...[
              const SizedBox(height: 24),
              _buildBottomActions(context, isGroupOwner),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMemberSection(BuildContext context) {
    final canManageMembers = _isGroupOwner || _isAdmin;
    final actionCount = canManageMembers ? 2 : 0;

    if (_isLoadingMembers) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_members.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            '暂无群成员',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      // 限制高度以便在需要时滚动
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4, // 限制最大高度为屏幕高度的40%
      ),
      child: Theme(
        // 创建一个没有滚动条的主题
        data: Theme.of(context).copyWith(
          scrollbarTheme: ScrollbarThemeData(
            thumbVisibility: WidgetStateProperty.all(false),
            trackVisibility: WidgetStateProperty.all(false),
            thickness: WidgetStateProperty.all(0),
            crossAxisMargin: 0,
            minThumbLength: 0,
          ),
        ),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(), // 允许滚动但不显示滚动条
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 12,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
          ),
          itemCount: _members.length + actionCount,
          itemBuilder: (context, index) {
            if (canManageMembers && index == 0) {
              return _buildActionMember(context, true, '添加', () {
                _handleAddMembers();
              });
            }
            if (canManageMembers && index == 1) {
              return _buildActionMember(context, false, '移除', () {
                _handleRemoveMembers();
              });
            }
            final member = _members[index - actionCount];
            return _buildMemberItem(context, member);
          },
        ),
      ),
    );
  }

  Widget _buildMemberItem(BuildContext context, Map<String, dynamic> member) {
    // 从后端数据中获取用户信息
    final username =
        member['username'] as String? ?? member['name'] as String? ?? '未知用户';
    final nickname = member['nickname'] as String?;
    final avatarUrl = member['avatar_url'] as String?;
    final displayName = nickname?.isNotEmpty == true ? nickname! : username;
    final firstLetter = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : '?';

    // 判断是否是群主
    final roleValue = member['role'] ?? member['member_role'];
    final role = roleValue is String
        ? roleValue.toLowerCase()
        : roleValue?.toString();
    final isOwner = role == 'owner';

    // 使用哈希背景色（与聊天列表一致），用 userId 作为稳定种子
    final userId = member['user_id'] as String? ?? member['userId'] as String?;
    final backgroundColor = AvatarColorUtils.generateBackgroundColor(
      userId ?? displayName,
    );

    return GestureDetector(
      onTap: () => _navigateToContactDetail(context, member),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              // 头像
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(48),
                ),
                child: avatarUrl?.isNotEmpty == true
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(48),
                        child: Image.network(
                          avatarUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                firstLetter,
                                style: const TextStyle(
                                  fontSize: 19,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Text(
                          firstLetter,
                          style: const TextStyle(
                            fontSize: 19,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
              // 群主标识
              if (isOwner)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB800),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.star,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildActionMember(
    BuildContext context,
    bool isAdd,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
            ),
            child: CustomPaint(
              size: const Size(24, 24),
              painter: _ActionIconPainter(isAdd: isAdd),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupInfoSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _SettingTile(
            label: '群聊名称',
            value: _chatName,
            showValueOnRight: true,
            onTap: _isGroupOwner || _isAdmin
                ? () {
                    _handleRenameGroup();
                  }
                : null,
          ),
          _SettingTile(
            label: '群头像',
            trailing: _isUploadingAvatar
                ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : _GroupAvatar(
                    key: ValueKey(_avatarObjectKey),
                    chat: widget.chat.copyWith(
                      name: _chatName,
                      avatarObjectKey: _avatarObjectKey,
                    ),
                  ),
            onTap: _isUploadingAvatar
                ? null
                : (_isGroupOwner || _isAdmin
                      ? () {
                          _showPickGroupAvatarDialog(context);
                        }
                      : null),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, bool canManageGroup) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        16,
        widget.chat.type == ChatType.group ? 0 : 16, // 单聊时添加顶部间距
        16,
        0,
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (widget.chat.type == ChatType.group && canManageGroup)
            _SwitchTile(
              label: '禁止发送消息',
              value: _isForbidden,
              loading: _isLoadingSettings,
              onChanged: _handleGlobalMuteToggle,
            ),
          _SwitchTile(
            label: '消息免打扰',
            value: _isMuted,
            onChanged: (value) {
              _handleMuteToggle(value);
            },
          ),
          _SwitchTile(
            label: '置顶聊天',
            value: _isPinned,
            onChanged: (value) {
              _handlePinToggle(value);
            },
          ),
          _SettingTile(
            label: '立即投诉举报',
            onTap: () {
              _showReportDialog(context);
            },
          ),
        ],
      ),
    );
  }

  /// 群聊管理入口区块（仅群主/管理员可见）
  Widget _buildManagementSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (_isGroupOwner)
            _SettingTile(
              label: '管理员设置',
              onTap: () => _navigateToAdminManagement(context),
            ),
          _SettingTile(
            label: '入群审核',
            onTap: () => _navigateToJoinRequests(context),
          ),
          _SettingTile(
            label: '禁言管理',
            onTap: () => _navigateToMuteManagement(context),
          ),
          _SettingTile(
            label: '群规',
            onTap: () => _navigateToGroupRules(context),
          ),
          _SettingTile(
            label: '操作日志',
            onTap: () => _navigateToOperationLogs(context),
          ),
        ],
      ),
    );
  }

  void _navigateToAdminManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupAdminManagementPage(
          roomId: widget.chat.roomId,
          members: _members,
        ),
      ),
    );
  }

  void _navigateToJoinRequests(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupJoinRequestsPage(roomId: widget.chat.roomId),
      ),
    );
  }

  void _navigateToMuteManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupMuteManagementPage(
          roomId: widget.chat.roomId,
          members: _members,
        ),
      ),
    );
  }

  void _navigateToGroupRules(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupRulesPage(
          roomId: widget.chat.roomId,
          canManage: _isGroupOwner || _isAdmin,
        ),
      ),
    );
  }

  void _navigateToOperationLogs(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupOperationLogsPage(
          roomId: widget.chat.roomId,
          members: _members,
        ),
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, bool isGroupOwner) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (isGroupOwner) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => _showTransferOwnerDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '转让群主',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                _showClearMessagesDialog(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBC6847),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                '清空聊天记录',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                if (isGroupOwner) {
                  _showDissolveGroupDialog(context);
                } else {
                  _showQuitGroupDialog(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.settingsDeactivateBg,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isGroupOwner ? '解散群组' : '退出群聊',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearMessagesDialog(BuildContext context) {
    TipDialog.showConfirm(
      context,
      title: '清空聊天记录',
      content: '确认要清空聊天记录吗？',
      onConfirm: () async {
        try {
          final session = await _tokenStorage.readSession();
          if (session == null) {
            _showSnackBar('请先登录');
            return false;
          }

          final response = await http.delete(
            Uri.parse(
              '${AppConfig.apiBaseUrl}/rooms/${widget.chat.roomId}/messages',
            ),
            headers: {'Authorization': 'Bearer ${session.token}'},
          );

          if (response.statusCode == 200) {
            // 后端清空成功后，再清理本地缓存，保持与 Desktop 端一致
            await _chatProvider.clearChatMessages(widget.chat.roomId);
            _showSnackBar('聊天记录已清空');
            return true;
          } else {
            debugPrint(
              'Clear messages failed: ${response.statusCode} ${response.body}',
            );
            _showSnackBar('清空聊天记录失败，请稍后重试');
            return false;
          }
        } catch (e) {
          debugPrint('Clear messages exception: $e');
          _showSnackBar('清空聊天记录失败，请稍后重试');
          return false;
        }
      },
    );
  }

  void _showQuitGroupDialog(BuildContext context) {
    TipDialog.showConfirm(
      context,
      title: '退出群聊',
      content: '确认要退出群聊吗？',
      onConfirm: () async {
        debugPrint('Quit group confirmed');
        return true;
      },
    );
  }

  void _showDissolveGroupDialog(BuildContext context) {
    TipDialog.showConfirm(
      context,
      title: '解散群组',
      content: '确认要解散群聊吗？',
      confirmDanger: true,
      onConfirm: _handleDissolveGroup,
    );
  }

  void _showTransferOwnerDialog(BuildContext context) {
    if (_members.isEmpty) {
      _showSnackBar('暂无可转让的成员');
      return;
    }

    final candidates = _members
        .where((member) => member['user_id'] != _currentUserId)
        .toList();

    if (candidates.isEmpty) {
      _showSnackBar('暂无可转让的成员');
      return;
    }

    final searchController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final searchText = searchController.text.toLowerCase();
          final filteredCandidates = searchText.isEmpty
              ? candidates
              : candidates.where((member) {
                  final nickname = (member['nickname'] as String? ?? '')
                      .toLowerCase();
                  final username = (member['username'] as String? ?? '')
                      .toLowerCase();
                  return nickname.contains(searchText) ||
                      username.contains(searchText);
                }).toList();

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题栏
                  SheetHeader(
                    title: '选择新群主',
                    titleStyle: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    onClose: () => Navigator.pop(sheetContext),
                  ),
                  const SizedBox(height: 16),
                  // 搜索框
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: '搜索成员',
                      hintStyle: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 14.sp,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 12),
                  // 成员列表
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: filteredCandidates.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              '没有找到匹配的成员',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14.sp,
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filteredCandidates.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final member = filteredCandidates[index];
                              final displayName =
                                  member['nickname'] as String? ??
                                  member['username'] as String? ??
                                  '成员';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(displayName),
                                subtitle: Text(
                                  member['username'] as String? ?? '',
                                ),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  final memberId = member['user_id'] as String?;
                                  if (memberId != null) {
                                    _showTransferConfirmDialog(
                                      context,
                                      memberId,
                                      displayName,
                                    );
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTransferConfirmDialog(
    BuildContext context,
    String memberId,
    String displayName,
  ) {
    TipDialog.showConfirm(
      context,
      title: '转让群主',
      content: '确认将群主转让给「$displayName」吗？转让后你将成为普通成员。',
      onConfirm: () async {
        await _transferOwnership(memberId, displayName);
        return true;
      },
    );
  }

  void _showReportDialog(BuildContext context) {
    final controller = TextEditingController();
    final picker = ImagePicker();
    final maxAttachments = 3;

    final attachments = <XFile>[];
    bool submitting = false;
    StateSetter? setDialogState;

    final isGroup = widget.chat.type == ChatType.group;

    TipDialog.showConfirm(
      context,
      title: isGroup ? '确定要举报该群聊吗？' : '确定要举报该用户吗？',
      contentWidget: StatefulBuilder(
        builder: (context, setState) {
          setDialogState = setState;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '恶意举报将受到处罚，请谨慎操作',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                maxLength: 500,
                enabled: !submitting,
                decoration: const InputDecoration(
                  hintText: '请输入举报内容（必填）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          submitting || attachments.length >= maxAttachments
                          ? null
                          : () async {
                              try {
                                final files = await picker.pickMultiImage(
                                  imageQuality: 85,
                                );
                                if (files.isEmpty) return;
                                setState(() {
                                  final remaining =
                                      maxAttachments - attachments.length;
                                  attachments.addAll(files.take(remaining));
                                });
                              } catch (error) {
                                if (!mounted) return;
                                _showSnackBar('打开相册失败: $error');
                              }
                            },
                      icon: const Icon(Icons.photo_library),
                      label: const Text('选择截图'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          submitting || attachments.length >= maxAttachments
                          ? null
                          : () async {
                              try {
                                final picked = await picker.pickImage(
                                  source: ImageSource.camera,
                                  imageQuality: 85,
                                );
                                if (picked == null) return;
                                setState(() {
                                  if (attachments.length < maxAttachments) {
                                    attachments.add(picked);
                                  }
                                });
                              } catch (error) {
                                if (!mounted) return;
                                _showSnackBar('打开相机失败: $error');
                              }
                            },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('拍照'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '已选择 ${attachments.length}/$maxAttachments 张（必填）',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              if (attachments.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: attachments.asMap().entries.map((entry) {
                    final index = entry.key;
                    final file = entry.value;
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(file.path),
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 24,
                              minHeight: 24,
                            ),
                            icon: const Icon(
                              Icons.cancel,
                              size: 18,
                              color: Colors.red,
                            ),
                            onPressed: submitting
                                ? null
                                : () {
                                    setState(() {
                                      attachments.removeAt(index);
                                    });
                                  },
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
              if (submitting) ...[
                const SizedBox(height: 12),
                Row(
                  children: const [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '提交中...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
      confirmText: '提交举报',
      cancelText: '再想想',
      confirmDanger: true,
      barrierDismissible: !submitting,
      onConfirm: () async {
        if (submitting) {
          return false;
        }

        final content = controller.text.trim();
        if (content.isEmpty) {
          _showSnackBar('请输入举报内容');
          return false;
        }

        if (attachments.isEmpty) {
          _showSnackBar('请至少上传 1 张截图');
          return false;
        }

        setDialogState?.call(() => submitting = true);
        try {
          await _submitReport(content: content, attachments: attachments);
          if (!mounted) return false;
          _showSnackBar('举报已提交，感谢你的反馈');
          return true;
        } catch (error) {
          if (!mounted) return false;
          _showSnackBar('举报失败: $error');
          return false;
        } finally {
          setDialogState?.call(() => submitting = false);
        }
      },
    );
  }

  String? _extractReportTargetUserId() {
    if (widget.chat.type != ChatType.single) return null;
    final extra = widget.chat.extra ?? const <String, dynamic>{};

    final candidates = [
      extra['friend_id'],
      extra['friendId'],
      extra['friend_user_id'],
      extra['friendUserId'],
      extra['target_user_id'],
      extra['targetUserId'],
      extra['peer_user_id'],
      extra['peerUserId'],
      extra['user_id'],
      extra['userId'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  Future<String> _uploadReportAttachment({
    required String token,
    required File file,
  }) async {
    if (!await file.exists()) {
      throw Exception('未找到截图文件');
    }

    final contentType = lookupMimeType(file.path) ?? 'application/octet-stream';
    final fileSize = await file.length();
    final filename = p.basename(file.path);

    // 1) 获取直传签名
    final directUri = Uri.parse(
      '${AppConfig.apiBaseUrl}/reports/attachments/signature',
    );
    final directResponse = await http.post(
      directUri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'filename': filename,
        'content_type': contentType,
        'file_size': fileSize,
      }),
    );

    if (directResponse.statusCode != 200) {
      throw Exception(
        '获取上传签名失败 (HTTP ${directResponse.statusCode}): ${directResponse.body}',
      );
    }

    final directPayload =
        jsonDecode(directResponse.body) as Map<String, dynamic>;
    final directSuccess = directPayload['success'] as bool? ?? false;
    if (!directSuccess) {
      throw Exception(directPayload['message'] as String? ?? '获取上传签名失败');
    }

    final key = directPayload['key'] as String?;
    final signatureMap =
        directPayload['signature'] as Map<String, dynamic>? ?? {};
    if (key == null || signatureMap.isEmpty) {
      throw Exception('上传签名响应不完整');
    }

    // 2) 直传到对象存储
    final signature = DirectUploadSignature.fromJson(signatureMap);
    final uploadRequest = http.Request(
      signature.method,
      Uri.parse(signature.url),
    );
    signature.applyHeaders(uploadRequest, defaultContentType: contentType);
    uploadRequest.bodyBytes = await file.readAsBytes();

    final uploadResponse = await uploadRequest.send();
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      final body = await uploadResponse.stream.bytesToString();
      throw Exception(
        body.isNotEmpty
            ? '上传失败: $body'
            : '上传失败，状态码 ${uploadResponse.statusCode}',
      );
    }

    // 3) commit
    final commitUri = Uri.parse(
      '${AppConfig.apiBaseUrl}/reports/attachments/commit',
    );
    final commitResponse = await http.post(
      commitUri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'key': key, 'file_size': fileSize}),
    );

    if (commitResponse.statusCode != 200) {
      throw Exception('提交截图信息失败: ${commitResponse.body}');
    }

    final commitPayload =
        jsonDecode(commitResponse.body) as Map<String, dynamic>;
    final commitSuccess = commitPayload['success'] as bool? ?? false;
    if (!commitSuccess) {
      throw Exception(commitPayload['message'] as String? ?? '提交截图信息失败');
    }

    return key;
  }

  Future<void> _submitReport({
    required String content,
    required List<XFile> attachments,
  }) async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw Exception('请先登录');
    }

    final targetType = widget.chat.type == ChatType.group ? 'room' : 'user';
    final targetId = targetType == 'room'
        ? widget.chat.roomId
        : _extractReportTargetUserId();
    if (targetId == null || targetId.isEmpty) {
      throw Exception('无法获取被举报对象 ID');
    }

    final keys = <String>[];
    for (final item in attachments) {
      final file = File(item.path);
      final key = await _uploadReportAttachment(
        token: session.token,
        file: file,
      );
      keys.add(key);
    }

    if (keys.isEmpty) {
      throw Exception('截图上传失败');
    }

    final reportUri = Uri.parse('${AppConfig.apiBaseUrl}/reports');
    final reportResponse = await http.post(
      reportUri,
      headers: {
        'Authorization': 'Bearer ${session.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'target_type': targetType,
        'target_id': targetId,
        'content': content,
        'attachment_keys': keys,
      }),
    );

    if (reportResponse.statusCode != 200) {
      throw Exception('提交举报失败: ${reportResponse.body}');
    }

    final reportPayload =
        jsonDecode(reportResponse.body) as Map<String, dynamic>;
    final reportSuccess = reportPayload['success'] as bool? ?? false;
    if (!reportSuccess) {
      throw Exception(reportPayload['message'] as String? ?? '提交举报失败');
    }
  }

  void _showPickGroupAvatarDialog(BuildContext context) {
    BottomPicker.show(
      context: context,
      title: '设置群头像',
      options: [
        BottomPickerOption(
          label: '拍照',
          icon: Icons.camera_alt,
          onTap: () => _selectGroupAvatarFromCamera(context),
        ),
        BottomPickerOption(
          label: '从相册选择',
          icon: Icons.photo_library,
          onTap: () => _selectGroupAvatarFromGallery(context),
        ),
      ],
    );
  }

  Future<void> _selectGroupAvatarFromCamera(BuildContext context) async {
    // BottomPicker 会自动关闭弹窗，不需要手动 pop
    if (_isUploadingAvatar) return;

    final picker = ImagePicker();
    XFile? pickedFile;
    try {
      pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('打开相机失败: $error');
      return;
    }

    if (pickedFile == null) return;
    await _handleGroupAvatarUpload(pickedFile);
  }

  Future<void> _selectGroupAvatarFromGallery(BuildContext context) async {
    // BottomPicker 会自动关闭弹窗，不需要手动 pop
    if (_isUploadingAvatar) return;

    final picker = ImagePicker();
    XFile? pickedFile;
    try {
      pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('打开相册失败: $error');
      return;
    }

    if (pickedFile == null) return;
    await _handleGroupAvatarUpload(pickedFile);
  }

  Future<void> _handleGroupAvatarUpload(XFile pickedFile) async {
    final file = File(pickedFile.path);
    if (!await file.exists()) {
      if (!mounted) return;
      _showSnackBar('未找到所选文件');
      return;
    }

    if (!mounted) return;
    setState(() => _isUploadingAvatar = true);
    try {
      // 1. 获取上传签名
      final session = await _tokenStorage.readSession();
      if (session == null) {
        throw Exception('用户未登录');
      }

      final contentType =
          lookupMimeType(file.path) ?? 'application/octet-stream';
      final fileSize = await file.length();
      final filename = p.basename(file.path);
      final directUri = Uri.parse(
        '${AppConfig.apiBaseUrl}/rooms/${widget.chat.roomId}/avatar/direct-upload',
      );

      final requestBody = {
        'filename': filename,
        'content_type': contentType,
        'file_size': fileSize,
      };
      debugPrint(
        '请求群头像上传签名: roomId=${widget.chat.roomId}, filename=$filename, contentType=$contentType, fileSize=$fileSize',
      );

      final directResponse = await http.post(
        directUri,
        headers: {
          'Authorization': 'Bearer ${session.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (!mounted) return;

      if (directResponse.statusCode != 200) {
        debugPrint(
          '获取上传签名失败: 状态码=${directResponse.statusCode}, 响应=${directResponse.body}',
        );
        throw Exception(
          '获取上传签名失败 (HTTP ${directResponse.statusCode}): ${directResponse.body}',
        );
      }

      final directPayload =
          jsonDecode(directResponse.body) as Map<String, dynamic>;
      debugPrint('直传签名响应: $directPayload');

      final directSuccess = directPayload['success'] as bool? ?? false;
      if (!directSuccess) {
        final message = directPayload['message'] as String?;
        debugPrint('获取上传签名失败: success=false, message=$message');
        throw Exception(message ?? '获取上传签名失败');
      }

      final key = directPayload['key'] as String?;
      final signatureMap =
          directPayload['signature'] as Map<String, dynamic>? ?? {};
      if (key == null || signatureMap.isEmpty) {
        throw Exception('上传签名响应不完整');
      }

      // 2. 上传文件到 OSS
      final signature = DirectUploadSignature.fromJson(signatureMap);
      final uploadRequest = http.Request(
        signature.method,
        Uri.parse(signature.url),
      );
      signature.applyHeaders(uploadRequest, defaultContentType: contentType);
      uploadRequest.bodyBytes = await file.readAsBytes();

      final uploadResponse = await uploadRequest.send();
      if (!mounted) return;

      if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
        final body = await uploadResponse.stream.bytesToString();
        throw Exception(
          body.isNotEmpty
              ? '上传失败: $body'
              : '上传失败，状态码 ${uploadResponse.statusCode}',
        );
      }

      // 3. 提交上传信息
      final commitUri = Uri.parse(
        '${AppConfig.apiBaseUrl}/rooms/${widget.chat.roomId}/avatar/commit',
      );
      final commitResponse = await http.post(
        commitUri,
        headers: {
          'Authorization': 'Bearer ${session.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'key': key, 'delete_previous': true}),
      );

      if (!mounted) return;

      if (commitResponse.statusCode != 200) {
        throw Exception('提交头像信息失败: ${commitResponse.body}');
      }

      final commitPayload =
          jsonDecode(commitResponse.body) as Map<String, dynamic>;
      final commitSuccess = commitPayload['success'] as bool? ?? false;
      if (!commitSuccess) {
        final message = commitPayload['message'] as String?;
        throw Exception(message ?? '提交头像信息失败');
      }

      // 4. 保存到本地缓存
      final localPath = await AvatarCache.instance.saveRoomAvatar(
        roomId: widget.chat.roomId,
        objectKey: key,
        source: file,
      );

      if (!mounted) return;

      // 5. 更新本地状态并刷新 UI
      if (mounted) {
        setState(() {
          // 更新头像 key，触发 _GroupAvatar 通过新的 key 重新构建
          _avatarObjectKey = key;
        });

        // 6. 更新聊天列表中的头像
        await MessageService.instance.updateRoomAvatar(
          roomId: widget.chat.roomId,
          avatarObjectKey: key,
          localAvatarPath: localPath,
        );

        _showSnackBar('群头像已更新');
      }
    } catch (error) {
      if (!mounted) return;
      String errorMessage = '头像更新失败';

      // 解析错误信息，提供友好提示
      final errorStr = error.toString();
      if (errorStr.contains('Forbidden') ||
          errorStr.contains('Only room owner') ||
          errorStr.contains('权限')) {
        errorMessage = '只有群主或管理员可以修改群头像';
      } else if (errorStr.contains('Only image files')) {
        errorMessage = '只支持图片格式文件';
      } else if (errorStr.contains('文件大小超出限制')) {
        errorMessage = '图片文件过大，请选择较小的图片';
      } else if (errorStr.contains('HTTP 403')) {
        errorMessage = '权限不足，只有群主或管理员可以修改群头像';
      } else if (errorStr.contains('HTTP 400')) {
        errorMessage = '上传参数错误，请重试';
      } else if (errorStr.contains('HTTP 401')) {
        errorMessage = '登录状态已过期，请重新登录';
      } else {
        errorMessage = '头像更新失败: $error';
      }

      _showSnackBar(errorMessage);
      debugPrint('群头像上传失败: $error');
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _transferOwnership(String newOwnerId, String displayName) async {
    try {
      await _roomService.transferRoomOwner(
        roomId: widget.chat.roomId,
        newOwnerId: newOwnerId,
      );
      if (mounted) {
        setState(() => _isGroupOwner = false);
      }
      _showSnackBar('已成功转让给 $displayName');
      await _loadMembers();
      await _loadSettings();
    } catch (e) {
      _showSnackBar('转让失败：$e');
    }
  }

  Future<bool> _handleDissolveGroup() async {
    try {
      await _roomService.dissolveGroup(widget.chat.roomId);
      if (mounted) {
        _showSnackBar('群聊已解散');
        Navigator.of(context).pop();
      }
      return true;
    } catch (e) {
      _showSnackBar('解散失败：$e');
      return false;
    }
  }

  Future<void> _handleGlobalMuteToggle(bool value) async {
    if (widget.chat.type != ChatType.group) return;
    if (!mounted) return;
    setState(() {
      _isForbidden = value;
      _isLoadingSettings = true;
    });
    try {
      await _roomService.updateGlobalMute(
        roomId: widget.chat.roomId,
        enabled: value,
      );
      _showSnackBar(value ? '已开启全体禁言' : '已关闭全体禁言');
    } catch (e) {
      if (mounted) {
        setState(() => _isForbidden = !value);
      }
      _showSnackBar('更新失败：$e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingSettings = false);
      }
    }
  }

  Future<void> _handleRenameGroup() async {
    if (widget.chat.type != ChatType.group) return;

    final result = await InputDialog.show(
      context,
      title: '修改群聊名称',
      hintText: '请输入新的群聊名称',
      initialValue: _chatName,
      maxLength: 50,
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (trimmed.isEmpty) {
          return '群聊名称不能为空';
        }
        return null;
      },
    );

    if (result == null || !mounted) {
      return;
    }

    final nextName = result.trim();
    if (nextName.isEmpty || nextName == _chatName) {
      return;
    }

    try {
      final updatedRoom = await _roomService.updateRoom(
        roomId: widget.chat.roomId,
        name: nextName,
      );
      if (!mounted) return;

      setState(() => _chatName = updatedRoom.name);
      await MessageService.instance.updateChatInfo(
        widget.chat.roomId,
        widget.chat.type,
      );
      _showSnackBar('群聊名称已更新');
    } catch (e) {
      _showSnackBar('更新群聊名称失败：$e');
    }
  }

  Future<void> _handleAddMembers() async {
    if (widget.chat.type != ChatType.group) return;

    try {
      final friends = await _friendService.fetchFriends();
      if (!mounted) return;

      final existingMemberIds = _members
          .map((member) => _memberUserId(member))
          .whereType<String>()
          .toSet();
      final candidates = friends
          .where((friend) => !existingMemberIds.contains(friend.user.id))
          .toList();

      if (candidates.isEmpty) {
        _showSnackBar('暂无可添加的好友');
        return;
      }

      final selectedIds = await FriendSelectionSheet.show(
        context,
        friends: candidates,
        initialSelected: const {},
        title: '添加群成员',
        confirmTextBuilder: (count) => '添加（$count）',
      );

      if (!mounted || selectedIds == null || selectedIds.isEmpty) {
        return;
      }

      final result = await _roomService.addMembers(
        roomId: widget.chat.roomId,
        userIds: selectedIds.toList(),
      );

      await _refreshMembersAndCount();

      if (!mounted) return;
      final addedCount = result.addedUserIds.length;
      final skippedCount = result.skippedUserIds.length;
      if (addedCount > 0 && skippedCount > 0) {
        _showSnackBar('已添加 $addedCount 人，跳过 $skippedCount 人');
      } else if (addedCount > 0) {
        _showSnackBar('已添加 $addedCount 名成员');
      } else {
        _showSnackBar('所选成员已在群聊中');
      }
    } catch (e) {
      _showSnackBar('添加成员失败：$e');
    }
  }

  Future<void> _handleRemoveMembers() async {
    if (widget.chat.type != ChatType.group) return;

    final candidates = _buildRemovableMembers();
    if (candidates.isEmpty) {
      _showSnackBar('暂无可移除的成员');
      return;
    }

    final selectedIds = await FriendSelectionSheet.show(
      context,
      friends: candidates,
      initialSelected: const {},
      title: '移除群成员',
      confirmTextBuilder: (count) => '移除（$count）',
    );

    if (!mounted || selectedIds == null || selectedIds.isEmpty) {
      return;
    }

    final confirmed = await TipDialog.showConfirm(
      context,
      title: '确认移除成员',
      content: '确定要移除选中的 ${selectedIds.length} 名成员吗？',
      confirmText: '移除',
      cancelText: '取消',
      confirmDanger: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }

    var removedCount = 0;
    final failedIds = <String>[];
    for (final userId in selectedIds) {
      try {
        await _roomService.removeMember(
          roomId: widget.chat.roomId,
          userId: userId,
        );
        removedCount += 1;
      } catch (_) {
        failedIds.add(userId);
      }
    }

    await _refreshMembersAndCount();

    if (!mounted) return;
    if (failedIds.isEmpty) {
      _showSnackBar('已移除 $removedCount 名成员');
      return;
    }
    if (removedCount > 0) {
      _showSnackBar('已移除 $removedCount 名成员，${failedIds.length} 名移除失败');
      return;
    }
    _showSnackBar('移除成员失败，请稍后重试');
  }

  Future<void> _handleMuteToggle(bool value) async {
    final previousValue = _isMuted;
    setState(() => _isMuted = value);

    try {
      await _ensureProviderHasChat();
      await _chatProvider.muteChat(widget.chat.id, value);
      _showSnackBar(value ? '已开启消息免打扰' : '已关闭消息免打扰');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isMuted = previousValue);
      _showSnackBar('更新消息免打扰失败：$e');
    }
  }

  Future<void> _handlePinToggle(bool value) async {
    final previousValue = _isPinned;
    setState(() => _isPinned = value);

    try {
      await _ensureProviderHasChat();
      await _chatProvider.pinChat(widget.chat.id, value);
      _showSnackBar(value ? '已置顶聊天' : '已取消置顶');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPinned = previousValue);
      _showSnackBar('更新置顶状态失败：$e');
    }
  }

  Future<void> _ensureProviderHasChat() async {
    final hasChat = _chatProvider.chats.any(
      (chat) => chat.id == widget.chat.id || chat.roomId == widget.chat.roomId,
    );
    if (hasChat) {
      return;
    }
    await _chatProvider.loadChats(refresh: true);
  }

  Future<void> _refreshMembersAndCount() async {
    await _loadMembers();
    await _chatProvider.getRoomMemberCount(
      widget.chat.roomId,
      forceRefresh: true,
    );
    if (mounted) {
      setState(() {});
    }
  }

  List<FriendInfo> _buildRemovableMembers() {
    return _members
        .where((member) {
          final userId = _memberUserId(member);
          if (userId == null || userId.isEmpty || userId == _currentUserId) {
            return false;
          }

          final role = _memberRole(member);
          if (!_isGroupOwner && role == 'owner') {
            return false;
          }
          return true;
        })
        .map(_memberToFriendInfo)
        .toList();
  }

  FriendInfo _memberToFriendInfo(Map<String, dynamic> member) {
    final userId = _memberUserId(member) ?? '';
    final username = member['username'] as String? ?? '未知用户';
    final nickname = member['nickname'] as String?;
    final avatarUrl = member['avatar_url'] as String?;
    final avatarObjectKey = member['avatar_object_key'] as String?;

    return FriendInfo(
      id: userId,
      user: AuthUser(
        id: userId,
        username: username,
        nickname: nickname,
        avatarUrl: avatarUrl,
        avatarObjectKey: avatarObjectKey,
      ),
      createdAt: DateTime.now(),
    );
  }

  String? _memberUserId(Map<String, dynamic> member) {
    final value = member['user_id'] ?? member['userId'] ?? member['id'];
    return value is String ? value : value?.toString();
  }

  String? _memberRole(Map<String, dynamic> member) {
    final roleValue = member['role'] ?? member['member_role'];
    return roleValue is String
        ? roleValue.toLowerCase()
        : roleValue?.toString().toLowerCase();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _navigateToContactDetail(
    BuildContext context,
    Map<String, dynamic> member,
  ) {
    // 从 member 数据构造 FriendInfo
    final userId = member['user_id'] as String?;
    final username = member['username'] as String? ?? '未知用户';
    final nickname = member['nickname'] as String?;
    final avatarUrl = member['avatar_url'] as String?;
    final avatarObjectKey = member['avatar_object_key'] as String?;

    if (userId == null || userId.isEmpty) {
      _showSnackBar('无法获取用户信息');
      return;
    }

    final authUser = AuthUser(
      id: userId,
      username: username,
      nickname: nickname,
      avatarUrl: avatarUrl,
      avatarObjectKey: avatarObjectKey,
    );

    final friendInfo = FriendInfo(
      id: userId, // 使用 user_id 作为 friend id
      user: authUser,
      createdAt: DateTime.now(), // 使用当前时间作为占位
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactDetailPage(friend: friendInfo),
      ),
    );
  }

  bool _computeOwnership({
    String? currentUserId,
    List<Map<String, dynamic>>? membersOverride,
  }) {
    if (widget.chat.type != ChatType.group) return false;
    final userId = currentUserId ?? _currentUserId;
    if (userId == null || userId.isEmpty) {
      return false;
    }

    final extra = widget.chat.extra;
    if (extra?['is_owner'] == true || extra?['isOwner'] == true) {
      return true;
    }

    final ownerCandidates = <dynamic>[extra?['owner_id'], extra?['ownerId']];
    for (final candidate in ownerCandidates) {
      final ownerId = candidate is String ? candidate : candidate?.toString();
      if (ownerId != null && ownerId.isNotEmpty && ownerId == userId) {
        return true;
      }
    }

    final members = membersOverride ?? _members;
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
      if (role == 'owner' && memberId == userId) {
        return true;
      }
    }
    return false;
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    required this.value,
    this.onChanged,
    this.loading = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        height: 46,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 15.sp,
                  ),
                ),
              ),
              CustomSwitch(
                value: value,
                onChanged: onChanged,
                loading: loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.label,
    this.value,
    this.trailing,
    this.showValueOnRight = false,
    this.onTap,
  });

  final String label;
  final String? value;
  final Widget? trailing;
  final bool showValueOnRight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 15.sp,
                    ),
                  ),
                ),
                // 如果有 trailing，先显示 trailing
                if (trailing != null) trailing!,
                // 如果有 value 且 showValueOnRight，使用 Expanded 占据剩余空间并右对齐
                if (value != null && showValueOnRight)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        value!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ),
                // 如果有 value 且 !showValueOnRight，显示在 trailing 之后
                if (value != null && !showValueOnRight)
                  Flexible(
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 自定义绘制 + 和 - 图标
class _ActionIconPainter extends CustomPainter {
  final bool isAdd;

  _ActionIconPainter({required this.isAdd});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCCCCCC)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final lineLength = size.width * 0.5;

    // 画横线 (-)
    canvas.drawLine(
      Offset(centerX - lineLength / 2, centerY),
      Offset(centerX + lineLength / 2, centerY),
      paint,
    );

    // 如果是添加按钮，画竖线 (+)
    if (isAdd) {
      canvas.drawLine(
        Offset(centerX, centerY - lineLength / 2),
        Offset(centerX, centerY + lineLength / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
