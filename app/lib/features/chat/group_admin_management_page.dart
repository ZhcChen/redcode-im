import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/room_service.dart';
import '../../core/utils/avatar_color_utils.dart';
import '../../core/widgets/sheet_header.dart';
import '../../core/widgets/im_state_panel.dart';
import '../../core/widgets/tip_dialog.dart';

/// 群管理员管理页面
class GroupAdminManagementPage extends StatefulWidget {
  const GroupAdminManagementPage({
    super.key,
    required this.roomId,
    required this.members,
    this.roomService,
  });

  final String roomId;
  final List<Map<String, dynamic>> members;
  final RoomService? roomService;

  @override
  State<GroupAdminManagementPage> createState() =>
      _GroupAdminManagementPageState();
}

class _GroupAdminManagementPageState extends State<GroupAdminManagementPage> {
  late final RoomService _roomService;
  List<GroupAdmin> _admins = [];
  bool _isLoading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _roomService = widget.roomService ?? RoomService();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final admins = await _roomService.listAdmins(widget.roomId);
      if (mounted) {
        setState(() {
          _admins = admins;
          _isLoading = false;
          _loadError = null;
        });
      }
    } catch (e) {
      debugPrint('加载管理员列表失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = '无法加载管理员列表';
        });
      }
    }
  }

  String _getMemberName(String userId) {
    final member = widget.members.firstWhere(
      (m) => m['user_id'] == userId || m['userId'] == userId,
      orElse: () => <String, dynamic>{},
    );
    return member['nickname'] as String? ??
        member['username'] as String? ??
        '未知用户';
  }

  String? _getMemberAvatar(String userId) {
    final member = widget.members.firstWhere(
      (m) => m['user_id'] == userId || m['userId'] == userId,
      orElse: () => <String, dynamic>{},
    );
    return member['avatar_url'] as String?;
  }

  List<Map<String, dynamic>> get _availableMembers {
    final adminIds = _admins.map((a) => a.adminId).toSet();
    return widget.members.where((m) {
      final userId = m['user_id'] as String? ?? m['userId'] as String?;
      final role = (m['role'] as String? ?? m['member_role'] as String? ?? '')
          .toLowerCase();
      return userId != null &&
          !adminIds.contains(userId) &&
          role != 'owner' &&
          role != 'admin';
    }).toList();
  }

  void _showAddAdminSheet() {
    final available = _availableMembers;
    if (available.isEmpty) {
      _showSnackBar('暂无可添加的成员');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                title: '选择要添加的管理员',
                titleStyle: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                onClose: () => Navigator.pop(sheetContext),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: available.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final member = available[index];
                    final userId =
                        member['user_id'] as String? ??
                        member['userId'] as String? ??
                        '';
                    final displayName =
                        member['nickname'] as String? ??
                        member['username'] as String? ??
                        '成员';
                    final avatarUrl = member['avatar_url'] as String?;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _buildAvatar(userId, displayName, avatarUrl),
                      title: Text(displayName),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _confirmAppointAdmin(userId, displayName);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmAppointAdmin(String userId, String displayName) {
    TipDialog.showConfirm(
      context,
      title: '任命管理员',
      content: '确定要将「$displayName」设为管理员吗？',
      onConfirm: () async {
        try {
          await _roomService.appointAdmin(
            roomId: widget.roomId,
            userId: userId,
          );
          _showSnackBar('已任命「$displayName」为管理员');
          await _loadAdmins();
          return true;
        } catch (e) {
          _showSnackBar('任命失败：$e');
          return false;
        }
      },
    );
  }

  void _confirmRemoveAdmin(GroupAdmin admin) {
    final displayName = _getMemberName(admin.adminId);
    TipDialog.showConfirm(
      context,
      title: '移除管理员',
      content: '确定要移除「$displayName」的管理员身份吗？',
      confirmDanger: true,
      onConfirm: () async {
        try {
          await _roomService.removeAdmin(
            roomId: widget.roomId,
            userId: admin.adminId,
          );
          _showSnackBar('已移除「$displayName」的管理员身份');
          await _loadAdmins();
          return true;
        } catch (e) {
          _showSnackBar('移除失败：$e');
          return false;
        }
      },
    );
  }

  Widget _buildAvatar(String seed, String name, String? avatarUrl) {
    final initial = AvatarColorUtils.getInitial(name);
    final backgroundColor = AvatarColorUtils.generateBackgroundColor(seed);

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(
          avatarUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _buildDefaultAvatar(initial, backgroundColor),
        ),
      );
    }
    return _buildDefaultAvatar(initial, backgroundColor);
  }

  Widget _buildDefaultAvatar(String initial, Color backgroundColor) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
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

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('管理员设置'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddAdminSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? ImStatePanel(
              icon: Icons.cloud_off_outlined,
              title: _loadError!,
              message: '请检查网络后重试',
              actionLabel: '重新加载',
              onAction: _loadAdmins,
            )
          : _admins.isEmpty
          ? Center(
              child: Text(
                '暂无管理员',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14.sp,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _admins.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final admin = _admins[index];
                final displayName = _getMemberName(admin.adminId);
                final avatarUrl = _getMemberAvatar(admin.adminId);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildAvatar(admin.adminId, displayName, avatarUrl),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '任命于 ${_formatDate(admin.appointedAt)}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _confirmRemoveAdmin(admin),
                        child: Text(
                          '移除',
                          style: TextStyle(color: Colors.red, fontSize: 13.sp),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}
