import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/room_service.dart';
import '../../core/utils/avatar_color_utils.dart';
import '../../core/widgets/tip_dialog.dart';

/// 入群审核页面
class GroupJoinRequestsPage extends StatefulWidget {
  const GroupJoinRequestsPage({
    super.key,
    required this.roomId,
  });

  final String roomId;

  @override
  State<GroupJoinRequestsPage> createState() => _GroupJoinRequestsPageState();
}

class _GroupJoinRequestsPageState extends State<GroupJoinRequestsPage> {
  final RoomService _roomService = RoomService();
  List<JoinRequest> _requests = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _roomService.listJoinRequests(widget.roomId);
      if (mounted) {
        // 按时间倒序，pending 的排在前面
        requests.sort((a, b) {
          if (a.status == 'pending' && b.status != 'pending') return -1;
          if (a.status != 'pending' && b.status == 'pending') return 1;
          return b.createdAt.compareTo(a.createdAt);
        });
        setState(() {
          _requests = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载入群申请失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('加载失败：$e');
      }
    }
  }

  void _handleApprove(JoinRequest request) {
    TipDialog.showConfirm(
      context,
      title: '通过入群申请',
      content: '确定要通过该用户的入群申请吗？',
      onConfirm: () async {
        try {
          await _roomService.reviewJoinRequest(
            roomId: widget.roomId,
            requestId: request.id,
            status: 'approved',
          );
          _showSnackBar('已通过入群申请');
          await _loadRequests();
          return true;
        } catch (e) {
          _showSnackBar('操作失败：$e');
          return false;
        }
      },
    );
  }

  void _handleReject(JoinRequest request) {
    TipDialog.showConfirm(
      context,
      title: '拒绝入群申请',
      content: '确定要拒绝该用户的入群申请吗？',
      confirmDanger: true,
      onConfirm: () async {
        try {
          await _roomService.reviewJoinRequest(
            roomId: widget.roomId,
            requestId: request.id,
            status: 'rejected',
          );
          _showSnackBar('已拒绝入群申请');
          await _loadRequests();
          return true;
        } catch (e) {
          _showSnackBar('操作失败：$e');
          return false;
        }
      },
    );
  }

  Widget _buildAvatar(String seed, String name) {
    final initial = AvatarColorUtils.getInitial(name);
    final backgroundColor = AvatarColorUtils.generateBackgroundColor(seed);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${date.month}/${date.day}';
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('入群审核'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? Center(
                  child: Text(
                    '暂无入群申请',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.sp,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    final displayName = '用户 ${request.applicantId.substring(0, 8)}...';

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAvatar(request.applicantId, displayName),
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
                                if (request.message != null &&
                                    request.message!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '申请理由：${request.message}',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(request.createdAt),
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (request.status == 'pending')
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _handleApprove(request),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF52C41A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  child: const Text('通过'),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => _handleReject(request),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textSecondary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  child: const Text('拒绝'),
                                ),
                              ],
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: request.status == 'approved'
                                    ? const Color(0xFFE6F7FF)
                                    : const Color(0xFFFFF1F0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                request.status == 'approved' ? '已通过' : '已拒绝',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: request.status == 'approved'
                                      ? const Color(0xFF1890FF)
                                      : const Color(0xFFFF4D4F),
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
