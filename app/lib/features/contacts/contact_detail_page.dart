import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/friend_service.dart';
import '../../core/services/report_service.dart';
import '../../core/widgets/input_dialog.dart';
import '../../core/widgets/tip_dialog.dart';
import '../../core/utils/avatar_color_utils.dart';
import '../auth/models/auth_user.dart';
import '../chat/chat_detail_page_v2.dart';
import '../chat/models/chat_model.dart';
import '../report/report_dialog.dart';
import 'models/friend_models.dart';

class ContactDetailPage extends StatefulWidget {
  const ContactDetailPage({
    super.key,
    required this.friend,
    this.friendService,
    this.reportService,
  });

  final FriendInfo friend;
  final FriendService? friendService;
  final ReportService? reportService;

  @override
  State<ContactDetailPage> createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends State<ContactDetailPage> {
  late final FriendService _friendService;
  late FriendInfo _friend;
  bool _creatingChat = false;
  bool _deletingFriend = false;
  bool _updatingRemark = false;

  @override
  void initState() {
    super.initState();
    _friendService = widget.friendService ?? FriendService();
    _friend = widget.friend;
  }

  Future<void> _handleSendMessage() async {
    if (_creatingChat) return;

    setState(() => _creatingChat = true);
    try {
      final result = await _friendService.ensurePrivateChat(_friend.user.id);
      if (!mounted) return;

      final chatType = result.roomType.toLowerCase() == 'group'
          ? ChatType.group
          : ChatType.single;
      final chatName = result.roomName.isNotEmpty
          ? result.roomName
          : _friend.user.displayName;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatDetailPageV2(
            roomId: result.roomId,
            chatName: chatName,
            chatAvatar: result.friendAvatar,
            chatType: chatType,
          ),
        ),
      );
    } on FriendServiceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('开启会话失败，请稍后再试')));
    } finally {
      if (mounted) {
        setState(() => _creatingChat = false);
      } else {
        _creatingChat = false;
      }
    }
  }

  Future<void> _handleDeleteFriend() async {
    if (_deletingFriend) return;

    final confirmed = await TipDialog.showConfirm(
      context,
      title: '删除好友',
      content:
          '确定要删除好友「${_friend.user.displayName}」吗？删除后双方将不再出现在彼此的联系人列表中，此操作不可撤销。',
      confirmText: '删除',
      cancelText: '取消',
      confirmDanger: true,
    );

    if (confirmed != true) return;

    setState(() => _deletingFriend = true);
    try {
      await _friendService.deleteFriend(_friend.user.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FriendServiceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除好友失败，请稍后再试')));
    } finally {
      if (mounted) {
        setState(() => _deletingFriend = false);
      } else {
        _deletingFriend = false;
      }
    }
  }

  Future<void> _handleEditRemark() async {
    if (_updatingRemark) return;

    await InputDialog.show(
      context,
      title: '设置备注',
      hintText: '输入好友备注，留空可清除',
      initialValue: _friend.remark,
      maxLength: 32,
      onConfirm: (value) async {
        setState(() => _updatingRemark = true);
        try {
          final remark = await _friendService.updateFriendRemark(
            _friend.user.id,
            value,
          );
          if (!mounted) return null;
          setState(() {
            _friend = _friend.copyWith(
              remark: remark,
              clearRemark: remark == null,
            );
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(remark == null ? '备注已清除' : '备注已更新')),
          );
          return remark ?? '';
        } on FriendServiceException catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(error.message)));
          }
          return null;
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('更新备注失败，请稍后再试')));
          }
          return null;
        } finally {
          if (mounted) setState(() => _updatingRemark = false);
        }
      },
    );
  }

  Future<void> _handleReport() async {
    await ReportDialog.show(
      context,
      targetType: 'user',
      targetId: _friend.user.id,
      reportService: widget.reportService,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _friend.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('联系人名片'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          _ProfileHeader(user: user),
          const SizedBox(height: 20),
          _InfoSection(
            friend: _friend,
            updatingRemark: _updatingRemark,
            onEditRemark: _handleEditRemark,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _creatingChat ? null : _handleSendMessage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: _creatingChat
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.chat_bubble_outline_rounded),
              label: Text(_creatingChat ? '正在创建聊天…' : '发送消息'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _handleReport,
              icon: const Icon(Icons.report_outlined),
              label: const Text('举报该用户'),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _deletingFriend ? null : _handleDeleteFriend,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: _deletingFriend
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.red,
                      ),
                    )
                  : const Icon(Icons.person_remove_alt_1_outlined),
              label: Text(_deletingFriend ? '正在删除…' : '删除好友'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final displayName = user.displayName;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFCCE5FF), Color(0xFFF3F7FF)],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: Colors.white,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(44),
              child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? Image.network(
                      user.avatarUrl!,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildDefaultAvatar(displayName, userId: user.id),
                    )
                  : _buildDefaultAvatar(displayName, userId: user.id),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '账号：${user.username}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          if (user.status != null && user.status!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '状态：${_statusLabel(user.status!)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return '正常';
      case 'inactive':
        return '未激活';
      case 'banned':
        return '已禁用';
      default:
        return status;
    }
  }

  Widget _buildDefaultAvatar(String displayName, {String? userId}) {
    final name = displayName.trim();
    final initial = AvatarColorUtils.getInitial(name);
    // 使用稳定种子（用户ID）计算背景色，与 Desktop 端保持一致
    final seed = userId ?? name;
    final backgroundColor = AvatarColorUtils.generateBackgroundColor(seed);

    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 35,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.friend,
    required this.updatingRemark,
    required this.onEditRemark,
  });

  final FriendInfo friend;
  final bool updatingRemark;
  final VoidCallback onEditRemark;

  @override
  Widget build(BuildContext context) {
    final List<_InfoItem> items = [
      _InfoItem(
        label: '邮箱',
        value: friend.user.email?.isNotEmpty == true
            ? friend.user.email!
            : '未绑定',
      ),
      _InfoItem(
        label: '成为好友',
        value:
            '${friend.createdAt.year}年${friend.createdAt.month}月${friend.createdAt.day}日',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '基本信息',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: '编辑好友备注',
            child: InkWell(
              key: const Key('contact-detail-remark'),
              onTap: updatingRemark ? null : onEditRemark,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 72,
                      child: Text(
                        '备注',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        friend.remark ?? '未设置',
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (updatingRemark)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textTertiary,
                      ),
                  ],
                ),
              ),
            ),
          ),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.value,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem {
  const _InfoItem({required this.label, required this.value});

  final String label;
  final String value;
}
