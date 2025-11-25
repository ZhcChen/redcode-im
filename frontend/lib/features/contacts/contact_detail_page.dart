import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/friend_service.dart';
import '../../core/utils/avatar_color_utils.dart';
import '../auth/models/auth_user.dart';
import '../chat/chat_detail_page_v2.dart';
import '../chat/models/chat_model.dart';
import 'models/friend_models.dart';

class ContactDetailPage extends StatefulWidget {
  const ContactDetailPage({super.key, required this.friend});

  final FriendInfo friend;

  @override
  State<ContactDetailPage> createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends State<ContactDetailPage> {
  final FriendService _friendService = FriendService();
  bool _creatingChat = false;

  Future<void> _handleSendMessage() async {
    if (_creatingChat) return;

    setState(() => _creatingChat = true);
    try {
      final result = await _friendService.ensurePrivateChat(
        widget.friend.user.id,
      );
      if (!mounted) return;

      final chatType = result.roomType.toLowerCase() == 'group'
          ? ChatType.group
          : ChatType.single;
      final chatName = result.roomName.isNotEmpty
          ? result.roomName
          : widget.friend.user.displayName;

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

  @override
  Widget build(BuildContext context) {
    final user = widget.friend.user;
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
          _InfoSection(friend: widget.friend),
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
                          _buildDefaultAvatar(displayName),
                    )
                  : _buildDefaultAvatar(displayName),
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

  Widget _buildDefaultAvatar(String displayName) {
    final name = displayName.trim();
    final initial = AvatarColorUtils.getInitial(name);
    final backgroundColor = AvatarColorUtils.generateBackgroundColor(name);

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
  const _InfoSection({required this.friend});

  final FriendInfo friend;

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
