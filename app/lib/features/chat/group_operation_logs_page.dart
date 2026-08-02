import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/room_service.dart';
import '../../core/widgets/im_state_panel.dart';

/// 操作日志页面
class GroupOperationLogsPage extends StatefulWidget {
  const GroupOperationLogsPage({
    super.key,
    required this.roomId,
    required this.members,
    this.roomService,
  });

  final String roomId;
  final List<Map<String, dynamic>> members;
  final RoomService? roomService;

  @override
  State<GroupOperationLogsPage> createState() => _GroupOperationLogsPageState();
}

class _GroupOperationLogsPageState extends State<GroupOperationLogsPage> {
  late final RoomService _roomService;
  List<GroupOperationLog> _logs = [];
  bool _isLoading = false;
  bool _hasMore = false;
  String? _loadError;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _roomService = widget.roomService ?? RoomService();
    _loadLogs();
  }

  Future<void> _loadLogs({bool append = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      if (!append) _loadError = null;
    });
    try {
      final logs = await _roomService.listOperationLogs(
        roomId: widget.roomId,
        limit: _pageSize,
        offset: append ? _logs.length : 0,
      );
      if (mounted) {
        setState(() {
          if (append) {
            _logs.addAll(logs);
          } else {
            _logs = logs;
          }
          _hasMore = logs.length >= _pageSize;
          _isLoading = false;
          if (!append) _loadError = null;
        });
      }
    } catch (e) {
      debugPrint('加载操作日志失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (!append) _loadError = '无法加载操作日志';
        });
        if (append) _showSnackBar('加载更多失败，请重试');
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

  String _formatTime(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  static const Map<String, String> _operationTextMap = {
    // 管理员相关
    'appoint_admin': '任命',
    'remove_admin': '撤销了管理员',
    // 成员相关
    'add_members': '添加了成员',
    'remove_member': '移除了成员',
    // 禁言相关
    'enable_global_mute': '开启了全体禁言',
    'disable_global_mute': '关闭了全体禁言',
    'mute_user': '禁言了',
    'unmute_user': '解除了禁言',
    // 群规相关
    'create_rule': '创建了群规',
    'update_rule': '更新了群规',
    'delete_rule': '删除了群规',
    // 入群相关
    'create_invitations': '邀请成员入群',
    'respond_to_invitation': '响应了群邀请',
    'review_join_request': '审核了入群申请',
    // 设置相关
    'update_group_settings': '更新了群设置',
  };

  String _getOperationText(GroupOperationLog log) {
    final baseText = _operationTextMap[log.operationType] ?? log.operationType;

    // 特殊处理某些操作的详情
    if (log.operationType == 'appoint_admin' && log.operationData != null) {
      final role = log.operationData!['role'] as String?;
      return '任命为${role == 'admin' ? '管理员' : role ?? '管理员'}';
    }

    if (log.operationType == 'review_join_request' &&
        log.operationData != null) {
      final status = log.operationData!['status'] as String?;
      return status == 'approved' ? '通过了入群申请' : '拒绝了入群申请';
    }

    if (log.operationType == 'mute_user' && log.operationData != null) {
      final hours = log.operationData!['duration_hours'] as int?;
      if (hours == null || hours == 0) {
        return '永久禁言了';
      }
      return '禁言$hours小时';
    }

    return baseText;
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
        title: const Text('操作日志'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: _isLoading && _logs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null && _logs.isEmpty
          ? ImStatePanel(
              icon: Icons.cloud_off_outlined,
              title: _loadError!,
              message: '请检查网络后重试',
              actionLabel: '重新加载',
              onAction: _loadLogs,
            )
          : _logs.isEmpty
          ? Center(
              child: Text(
                '暂无操作日志',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14.sp,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _logs.length) {
                  // 加载更多按钮
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : TextButton(
                              onPressed: () => _loadLogs(append: true),
                              child: const Text('加载更多'),
                            ),
                    ),
                  );
                }

                final log = _logs[index];
                final operatorName = _getMemberName(log.operatorId);
                final targetName = log.targetUserId != null
                    ? _getMemberName(log.targetUserId!)
                    : null;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatTime(log.createdAt),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppColors.textPrimary,
                              ),
                              children: [
                                TextSpan(
                                  text: operatorName,
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                TextSpan(
                                  text: ' ${_getOperationText(log)}',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (targetName != null) ...[
                                  TextSpan(
                                    text: ' $targetName',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
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
}
