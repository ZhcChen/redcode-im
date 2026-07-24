import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/room_service.dart';
import '../../core/utils/avatar_color_utils.dart';
import '../../core/widgets/sheet_header.dart';
import '../../core/widgets/tip_dialog.dart';

/// 禁言管理页面
class GroupMuteManagementPage extends StatefulWidget {
  const GroupMuteManagementPage({
    super.key,
    required this.roomId,
    required this.members,
  });

  final String roomId;
  final List<Map<String, dynamic>> members;

  @override
  State<GroupMuteManagementPage> createState() =>
      _GroupMuteManagementPageState();
}

class _GroupMuteManagementPageState extends State<GroupMuteManagementPage> {
  final RoomService _roomService = RoomService();
  List<GroupMute> _mutes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMutes();
  }

  Future<void> _loadMutes() async {
    setState(() => _isLoading = true);
    try {
      final mutes = await _roomService.listMutedUsers(widget.roomId);
      if (mounted) {
        setState(() {
          _mutes = mutes.where((m) => m.isActive).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载禁言列表失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('加载失败：$e');
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
    final mutedIds = _mutes.map((m) => m.userId).toSet();
    return widget.members.where((m) {
      final userId = m['user_id'] as String? ?? m['userId'] as String?;
      final role = (m['role'] as String? ?? m['member_role'] as String? ?? '')
          .toLowerCase();
      return userId != null && !mutedIds.contains(userId) && role == 'member';
    }).toList();
  }

  void _showMuteUserSheet() {
    final available = _availableMembers;
    if (available.isEmpty) {
      _showSnackBar('暂无可禁言的成员');
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
                title: '选择要禁言的成员',
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
                        _showMuteDurationDialog(userId, displayName);
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

  void _showMuteDurationDialog(String userId, String displayName) {
    int selectedDuration = 24; // 默认1天

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('禁言「$displayName」'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选择禁言时长：'),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: selectedDuration,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1小时')),
                  DropdownMenuItem(value: 6, child: Text('6小时')),
                  DropdownMenuItem(value: 12, child: Text('12小时')),
                  DropdownMenuItem(value: 24, child: Text('1天')),
                  DropdownMenuItem(value: 72, child: Text('3天')),
                  DropdownMenuItem(value: 168, child: Text('7天')),
                  DropdownMenuItem(value: 0, child: Text('永久')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedDuration = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _muteUser(userId, displayName, selectedDuration);
              },
              child: const Text('确认禁言'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _muteUser(
    String userId,
    String displayName,
    int durationHours,
  ) async {
    try {
      await _roomService.muteUser(
        roomId: widget.roomId,
        userId: userId,
        durationHours: durationHours,
      );
      _showSnackBar('已禁言「$displayName」');
      await _loadMutes();
    } catch (e) {
      _showSnackBar('禁言失败：$e');
    }
  }

  void _confirmUnmute(GroupMute mute) {
    final displayName = _getMemberName(mute.userId);
    TipDialog.showConfirm(
      context,
      title: '解除禁言',
      content: '确定要解除「$displayName」的禁言吗？',
      onConfirm: () async {
        try {
          await _roomService.unmuteUser(
            roomId: widget.roomId,
            userId: mute.userId,
          );
          _showSnackBar('已解除禁言');
          await _loadMutes();
          return true;
        } catch (e) {
          _showSnackBar('解除失败：$e');
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

  String _formatMuteInfo(GroupMute mute) {
    if (mute.muteUntil == null) {
      return '永久禁言';
    }
    final now = DateTime.now();
    if (mute.muteUntil!.isBefore(now)) {
      return '已过期';
    }
    final diff = mute.muteUntil!.difference(now);
    if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟后解禁';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}小时后解禁';
    }
    return '${diff.inDays}天后解禁';
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
        title: const Text('禁言管理'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showMuteUserSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mutes.isEmpty
          ? Center(
              child: Text(
                '暂无被禁言的成员',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14.sp,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _mutes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final mute = _mutes[index];
                final displayName = _getMemberName(mute.userId);
                final avatarUrl = _getMemberAvatar(mute.userId);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildAvatar(mute.userId, displayName, avatarUrl),
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
                            Row(
                              children: [
                                if (mute.reason != null &&
                                    mute.reason!.isNotEmpty)
                                  Flexible(
                                    child: Text(
                                      '原因：${mute.reason}',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: AppColors.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                if (mute.reason != null &&
                                    mute.reason!.isNotEmpty)
                                  const SizedBox(width: 8),
                                Text(
                                  _formatMuteInfo(mute),
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _confirmUnmute(mute),
                        child: Text(
                          '解除',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
