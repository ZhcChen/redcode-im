import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/room_service.dart';
import '../../core/storage/token_storage.dart';
import '../../core/widgets/custom_switch.dart';
import '../../core/widgets/tip_dialog.dart';
import 'models/chat_model.dart';
import 'providers/chat_provider.dart';

class GroupSettingsPage extends StatefulWidget {
  const GroupSettingsPage({super.key, required this.chat, this.chatProvider});

  final Chat chat;
  final ChatProvider? chatProvider;

  @override
  State<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends State<GroupSettingsPage> {
  late ChatProvider _chatProvider;
  late final bool _ownsProvider;
  late final RoomService _roomService;
  final TokenStorage _tokenStorage = const TokenStorage();
  bool _isMuted = false;
  bool _isPinned = false;
  bool _isForbidden = false;
  bool _isLoadingMembers = false;
  bool _isLoadingSettings = false;
  String? _currentUserId;
  bool _isGroupOwner = false;

  // 群成员列表
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _ownsProvider = widget.chatProvider == null;
    _chatProvider = widget.chatProvider ?? ChatProvider();
    _roomService = RoomService();
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
      debugPrint('加载群设置失败: $e');
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
      });
    } catch (e) {
      debugPrint('加载群成员失败: $e');
      if (mounted) {
        setState(() => _isLoadingMembers = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGroupOwner = _isGroupOwner;
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
            _buildSettingsSection(context, isGroupOwner),
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
            thumbVisibility: MaterialStateProperty.all(false),
            trackVisibility: MaterialStateProperty.all(false),
            thickness: MaterialStateProperty.all(0),
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
          itemCount: _members.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildActionMember(
                context,
                Icons.person_add,
                '添加',
                () => debugPrint('Add member'),
              );
            }
            if (index == 1) {
              return _buildActionMember(
                context,
                Icons.person_remove,
                '移除',
                () => debugPrint('Remove member'),
              );
            }
            final member = _members[index - 2];
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
        ? displayName.substring(0, 1)
        : '?';

    return GestureDetector(
      onTap: () => debugPrint('Member tapped: $displayName'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.surfaceMuted,
            backgroundImage: avatarUrl?.isNotEmpty == true
                ? NetworkImage(avatarUrl!)
                : null,
            child: avatarUrl?.isNotEmpty != true
                ? Text(
                    firstLetter,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  )
                : null,
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
    IconData icon,
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
            decoration: const BoxDecoration(
              color: AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: AppColors.textSecondary),
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
            value: widget.chat.name,
            showValueOnRight: true,
            onTap: () {
              debugPrint('Edit group name');
            },
          ),
          _SettingTile(
            label: '群头像',
            trailing: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.surfaceMuted,
              backgroundImage: widget.chat.avatar != null
                  ? AssetImage(widget.chat.avatar!)
                  : null,
              child: widget.chat.avatar == null
                  ? const Icon(Icons.group, size: 20)
                  : null,
            ),
            onTap: () {
              _showPickGroupAvatarDialog(context);
            },
          ),
          _SettingTile(
            label: '群公告',
            value: widget.chat.extra?['notice'] as String? ?? '无',
            showValueOnRight: true,
            onTap: () {
              debugPrint('Edit group notice');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, bool isGroupOwner) {
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
          if (widget.chat.type == ChatType.group && isGroupOwner)
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
              setState(() => _isMuted = value);
              debugPrint('Toggle mute: $value');
            },
          ),
          _SwitchTile(
            label: '置顶聊天',
            value: _isPinned,
            onChanged: (value) {
              setState(() => _isPinned = value);
              debugPrint('Toggle pin: $value');
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
        debugPrint('Clear messages confirmed');
        return true;
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 32),
                      Text(
                        '选择新群主',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(sheetContext),
                        child: const Icon(
                          Icons.close,
                          size: 24,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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
                                    _transferOwnership(memberId, displayName);
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

  void _showReportDialog(BuildContext context) {
    final controller = TextEditingController();
    TipDialog.showConfirm(
      context,
      title: '确定要举报他吗？',
      contentWidget: TextField(
        controller: controller,
        maxLines: 4,
        maxLength: 500,
        decoration: const InputDecoration(
          hintText: '请输入举报内容',
          border: OutlineInputBorder(),
        ),
      ),
      confirmText: '确定',
      cancelText: '再想想',
      confirmDanger: true,
      onConfirm: () async {
        debugPrint('Report submitted: ${controller.text}');
        return true;
      },
    );
  }

  void _showPickGroupAvatarDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置群头像'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _selectGroupAvatarFromCamera(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(context);
                _selectGroupAvatarFromGallery(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _selectGroupAvatarFromCamera(BuildContext context) async {
    // TODO: 实现相机选择功能
    debugPrint('Select group avatar from camera');
  }

  void _selectGroupAvatarFromGallery(BuildContext context) async {
    debugPrint('Select group avatar from gallery');
    // TODO: 实现从相册选择功能
    // 这里可以使用 image_picker 等插件
    // 然后调用 _chatProvider.uploadGroupAvatar 上传头像
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

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
