import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/avatar_color_utils.dart';
import '../models/message_model.dart';
import '../models/message_reader.dart';

typedef MessageReadersLoader =
    Future<List<MessageReader>> Function({required bool forceRefresh});
typedef RoomMembersLoader = Future<List<Map<String, dynamic>>> Function();

class MessageReadReceiptsSheet extends StatefulWidget {
  const MessageReadReceiptsSheet({
    super.key,
    required this.message,
    required this.loadReaders,
    required this.loadMembers,
  });

  final Message message;
  final MessageReadersLoader loadReaders;
  final RoomMembersLoader loadMembers;

  @override
  State<MessageReadReceiptsSheet> createState() =>
      _MessageReadReceiptsSheetState();
}

class _MessageReadReceiptsSheetState extends State<MessageReadReceiptsSheet> {
  List<MessageReader> _readers = const [];
  List<_ReceiptMember> _members = const [];
  bool _showUnread = false;
  bool _isLoading = true;
  String? _error;

  List<MessageReader> get _eligibleReaders => _readers
      .where((reader) => reader.userId != widget.message.senderId)
      .toList(growable: false);

  List<_ReceiptMember> get _eligibleMembers => _members
      .where((member) => member.userId != widget.message.senderId)
      .toList(growable: false);

  List<_ReceiptMember> get _unreadMembers {
    final readIds = _eligibleReaders.map((reader) => reader.userId).toSet();
    return _eligibleMembers
        .where((member) => !readIds.contains(member.userId))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        widget.loadReaders(forceRefresh: forceRefresh),
        widget.loadMembers(),
      ]);
      if (!mounted) return;
      setState(() {
        _readers = results[0] as List<MessageReader>;
        _members = (results[1] as List<Map<String, dynamic>>)
            .map(_ReceiptMember.fromJson)
            .where((member) => member.userId.isNotEmpty)
            .toList(growable: false);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.58,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, controller) {
        return Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                _buildHeader(context),
                if (!_isLoading && _error == null) _buildTabs(context),
                Expanded(child: _buildBody(context, controller)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text('已读详情', style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(
            tooltip: '刷新阅读状态',
            onPressed: _isLoading ? null : () => _load(forceRefresh: true),
            icon: const Icon(Icons.refresh, size: 20),
          ),
          IconButton(
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    final readCount = _eligibleReaders.length;
    final unreadCount = _unreadMembers.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SegmentedButton<bool>(
        segments: [
          ButtonSegment(value: false, label: Text('已读 $readCount')),
          ButtonSegment(value: true, label: Text('未读 $unreadCount')),
        ],
        selected: {_showUnread},
        showSelectedIcon: false,
        onSelectionChanged: (selection) {
          setState(() => _showUnread = selection.single);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, ScrollController controller) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _StatePanel(
        title: '阅读状态获取失败',
        detail: _error!,
        actionLabel: '重试',
        onAction: () => _load(forceRefresh: true),
      );
    }

    final rows = _showUnread
        ? _unreadMembers.map(_ReceiptRow.unread).toList(growable: false)
        : _eligibleReaders.map(_ReceiptRow.read).toList(growable: false);
    if (rows.isEmpty) {
      return _StatePanel(
        title: _showUnread ? '没有未读成员' : '没有已读成员',
        detail: '成员阅读状态会在这里更新',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: ListView.separated(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: rows.length,
        itemBuilder: (context, index) => _ReceiptMemberTile(row: rows[index]),
        separatorBuilder: (_, __) => const Divider(height: 1),
      ),
    );
  }
}

class _ReceiptMember {
  const _ReceiptMember({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;

  factory _ReceiptMember.fromJson(Map<String, dynamic> json) {
    final username = '${json['username'] ?? ''}';
    final nickname = '${json['nickname'] ?? ''}'.trim();
    return _ReceiptMember(
      userId: '${json['user_id'] ?? ''}',
      username: username,
      displayName: nickname.isNotEmpty ? nickname : username,
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}

class _ReceiptRow {
  const _ReceiptRow({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.subtitle,
    this.avatarUrl,
  });

  final String userId;
  final String username;
  final String displayName;
  final String subtitle;
  final String? avatarUrl;

  factory _ReceiptRow.read(MessageReader reader) => _ReceiptRow(
    userId: reader.userId,
    username: reader.username,
    displayName: reader.displayName,
    subtitle: _formatReadTime(reader.readAt),
    avatarUrl: reader.avatarUrl,
  );

  factory _ReceiptRow.unread(_ReceiptMember member) => _ReceiptRow(
    userId: member.userId,
    username: member.username,
    displayName: member.displayName,
    subtitle: '尚未阅读',
    avatarUrl: member.avatarUrl,
  );
}

class _ReceiptMemberTile extends StatelessWidget {
  const _ReceiptMemberTile({required this.row});

  final _ReceiptRow row;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildAvatar(),
      title: Text(
        row.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        row.subtitle,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
      ),
    );
  }

  Widget _buildAvatar() {
    final avatar = row.avatarUrl;
    if (avatar != null && avatar.isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(avatar));
    }
    final initial = row.displayName.isEmpty
        ? '?'
        : AvatarColorUtils.getInitial(row.displayName);
    return CircleAvatar(
      backgroundColor: AvatarColorUtils.generateBackgroundColor(row.userId),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.title,
    required this.detail,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatReadTime(DateTime time) {
  final now = DateTime.now();
  final sameDay =
      now.year == time.year && now.month == time.month && now.day == time.day;
  final hh = time.hour.toString().padLeft(2, '0');
  final mm = time.minute.toString().padLeft(2, '0');
  if (sameDay) return '今天 $hh:$mm';
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  return '$month-$day $hh:$mm';
}
