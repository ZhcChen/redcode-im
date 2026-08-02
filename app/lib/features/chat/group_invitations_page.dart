import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/room_service.dart';

class GroupInvitationsPage extends StatefulWidget {
  const GroupInvitationsPage({super.key, this.roomService});

  final RoomService? roomService;

  @override
  State<GroupInvitationsPage> createState() => _GroupInvitationsPageState();
}

class _GroupInvitationsPageState extends State<GroupInvitationsPage> {
  late final RoomService _roomService;
  List<GroupInvitation> _invitations = const [];
  final Set<String> _respondingIds = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _roomService = widget.roomService ?? RoomService();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final invitations = await _roomService.listReceivedInvitations(
        status: 'all',
      );
      if (!mounted) return;
      setState(() {
        _invitations = invitations;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '群通知加载失败';
      });
    }
  }

  Future<void> _respond(GroupInvitation invitation, String status) async {
    if (_respondingIds.contains(invitation.id)) return;
    setState(() => _respondingIds.add(invitation.id));
    try {
      await _roomService.respondToInvitation(
        roomId: invitation.roomId,
        invitationId: invitation.id,
        status: status,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status == 'accepted' ? '已加入群聊' : '已拒绝邀请')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('操作失败，请稍后重试')));
    } finally {
      if (mounted) {
        setState(() => _respondingIds.remove(invitation.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('群通知'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _invitations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _invitations.isEmpty) {
      return _CenteredState(
        icon: Icons.cloud_off_outlined,
        title: _error!,
        actionLabel: '重新加载',
        onAction: _load,
      );
    }
    if (_invitations.isEmpty) {
      return const _CenteredState(
        icon: Icons.mark_email_read_outlined,
        title: '暂无群通知',
        subtitle: '收到的群聊邀请会显示在这里',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: _invitations.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _InvitationItem(
          invitation: _invitations[index],
          responding: _respondingIds.contains(_invitations[index].id),
          onAccept: () => _respond(_invitations[index], 'accepted'),
          onDecline: () => _respond(_invitations[index], 'declined'),
        ),
      ),
    );
  }
}

class _InvitationItem extends StatelessWidget {
  const _InvitationItem({
    required this.invitation,
    required this.responding,
    required this.onAccept,
    required this.onDecline,
  });

  final GroupInvitation invitation;
  final bool responding;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  String get _roomName => invitation.roomName?.trim().isNotEmpty == true
      ? invitation.roomName!.trim()
      : '群聊邀请';

  @override
  Widget build(BuildContext context) {
    final pending = invitation.status == 'pending';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage: invitation.roomAvatarUrl?.isNotEmpty == true
                ? NetworkImage(invitation.roomAvatarUrl!)
                : null,
            child: invitation.roomAvatarUrl?.isNotEmpty == true
                ? null
                : const Icon(Icons.group_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _roomName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${invitation.inviterName ?? '群成员'} 邀请你加入群聊',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (invitation.message?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    invitation.message!.trim(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (pending)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: responding ? null : onDecline,
                        child: const Text('拒绝'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: responding ? null : onAccept,
                        child: responding
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('接受'),
                      ),
                    ],
                  )
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      switch (invitation.status) {
                        'accepted' => '已接受',
                        'declined' => '已拒绝',
                        _ => '已过期',
                      },
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: AppColors.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
