import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
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
  bool _isMuted = false;
  bool _isPinned = false;
  bool _isForbidden = false;

  // 群成员列表
  List<Map<String, dynamic>> _members = [];
  bool _isLoadingMembers = false;

  @override
  void initState() {
    super.initState();
    _ownsProvider = widget.chatProvider == null;
    _chatProvider = widget.chatProvider ?? ChatProvider();
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
    // TODO: 从后端加载设置
  }

  Future<void> _loadMembers() async {
    if (widget.chat.type != ChatType.group) return;

    setState(() => _isLoadingMembers = true);

    try {
      final members = await _chatProvider.getRoomMembers(widget.chat.roomId);
      setState(() {
        _members = members;
        _isLoadingMembers = false;
      });
    } catch (e) {
      debugPrint('加载群成员失败: $e');
      setState(() => _isLoadingMembers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGroupOwner =
        widget.chat.extra?['is_owner'] == true ||
        widget.chat.extra?['isOwner'] == true;
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
                    style: const TextStyle(
                      fontSize: 16,
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
              onChanged: (value) {
                setState(() => _isForbidden = value);
                debugPrint('Toggle forbidden: $value');
              },
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
              child: const Text(
                '清空聊天记录',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
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
      onConfirm: () async {
        debugPrint('Dissolve group confirmed');
        return true;
      },
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
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

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
                    fontSize: 15,
                  ),
                ),
              ),
              CustomSwitch(value: value, onChanged: onChanged),
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
                      fontSize: 15,
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
                          fontSize: 14,
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
                        fontSize: 14,
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
