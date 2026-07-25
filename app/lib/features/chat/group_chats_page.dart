import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/room_avatar_service.dart';
import '../../core/theme/phone_density.dart';
import '../../core/utils/avatar_color_utils.dart';
import '../../core/widgets/tip_dialog.dart';
import 'chat_detail_page_v2.dart';
import 'create_group_page.dart';
import 'group_settings_page.dart';
import 'models/chat_model.dart';
import 'providers/chat_provider.dart';
import 'widgets/chat_list_item.dart';

class GroupChatsPage extends StatefulWidget {
  const GroupChatsPage({super.key, this.chatProvider});

  final ChatProvider? chatProvider;

  @override
  State<GroupChatsPage> createState() => _GroupChatsPageState();
}

class _GroupChatsPageState extends State<GroupChatsPage> {
  late final ChatProvider _chatProvider;
  late final bool _ownsChatProvider;

  @override
  void initState() {
    super.initState();
    _ownsChatProvider = widget.chatProvider == null;
    _chatProvider = widget.chatProvider ?? ChatProvider();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChats();
    });
  }

  @override
  void dispose() {
    if (_ownsChatProvider) {
      _chatProvider.dispose();
    }
    super.dispose();
  }

  Future<void> _loadChats({bool refresh = false}) async {
    await _chatProvider.loadChats(refresh: refresh);
  }

  Future<void> _openCreateGroup() async {
    final navigator = Navigator.of(context);
    final roomId = await navigator.push<String>(
      MaterialPageRoute(builder: (_) => const CreateGroupPage()),
    );

    if (!mounted || roomId == null || roomId.isEmpty) {
      return;
    }

    await _loadChats(refresh: true);

    Chat? matched;
    for (final chat in _chatProvider.chats) {
      if (chat.roomId == roomId && chat.type == ChatType.group) {
        matched = chat;
        break;
      }
    }

    if (!mounted || matched == null) {
      return;
    }

    await _openChat(matched);
  }

  Future<void> _openChat(Chat chat) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailPageV2(
          roomId: chat.roomId,
          chatName: chat.name,
          chatAvatar: chat.avatar,
          chatType: chat.type,
          chatProvider: _chatProvider,
        ),
      ),
    );
  }

  Future<void> _openGroupSettings(Chat chat) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            GroupSettingsPage(chat: chat, chatProvider: _chatProvider),
      ),
    );
  }

  String? _groupDescription(Chat chat) {
    final extra = chat.extra;
    final candidates = <String?>[
      extra?['description'] as String?,
      extra?['group_description'] as String?,
      extra?['groupDescription'] as String?,
    ];
    for (final value in candidates) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  int? _memberCountForChat(Chat chat) {
    final extra = chat.extra;
    final raw = extra?['member_count'] ?? extra?['memberCount'];
    if (raw is int) {
      return raw;
    }
    return _chatProvider.cachedMemberCount(chat.roomId);
  }

  List<Chat> _filterGroupChats(ChatProvider provider) {
    final groupChats = provider.chats
        .where((chat) => chat.type == ChatType.group)
        .toList();
    final keyword = provider.searchKeyword.trim().toLowerCase();
    if (keyword.isEmpty) {
      return groupChats;
    }

    return groupChats.where((chat) {
      if (chat.name.toLowerCase().contains(keyword)) {
        return true;
      }
      if (chat.lastMessage.toLowerCase().contains(keyword)) {
        return true;
      }
      final description = _groupDescription(chat);
      if (description != null && description.toLowerCase().contains(keyword)) {
        return true;
      }
      return false;
    }).toList();
  }

  List<_GroupSectionData> _buildSections(List<Chat> groupChats) {
    final pinned = <Chat>[];
    final recent = <Chat>[];
    for (final chat in groupChats) {
      if (chat.isPinned) {
        pinned.add(chat);
      } else {
        recent.add(chat);
      }
    }

    final sections = <_GroupSectionData>[];
    if (pinned.isNotEmpty) {
      sections.add(
        _GroupSectionData(
          title: '置顶群聊',
          subtitle: '${pinned.length} 个',
          chats: pinned,
        ),
      );
    }
    if (recent.isNotEmpty) {
      sections.add(
        _GroupSectionData(title: '最近活跃', subtitle: '按最近消息排序', chats: recent),
      );
    }
    return sections;
  }

  Future<void> _showChatActions(Chat chat) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _GroupChatActionSheet(
        chat: chat,
        onViewGroupSettings: () => _openGroupSettings(chat),
        onTogglePinned: () => _togglePinned(chat),
        onToggleMuted: () => _toggleMuted(chat),
        onDelete: () => _deleteChat(chat),
      ),
    );
  }

  Future<void> _togglePinned(Chat chat) async {
    try {
      await _chatProvider.pinChat(chat.id, !chat.isPinned);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(chat.isPinned ? '已取消置顶' : '已置顶群聊')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('操作失败，请稍后重试')));
    }
  }

  Future<void> _toggleMuted(Chat chat) async {
    try {
      await _chatProvider.muteChat(chat.id, !chat.isMuted);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(chat.isMuted ? '已恢复消息提醒' : '已设为免打扰')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('操作失败，请稍后重试')));
    }
  }

  Future<void> _deleteChat(Chat chat) async {
    final confirmed = await TipDialog.showConfirm(
      context,
      title: '删除会话',
      content: '确定要删除群聊「${chat.name}」的会话吗？\n聊天记录将被清空。',
      confirmText: '删除',
      cancelText: '取消',
      confirmDanger: true,
    );
    if (confirmed != true) {
      return;
    }

    try {
      await _chatProvider.deleteChat(chat.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('会话已删除')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ChatProvider>.value(
      value: _chatProvider,
      child: Consumer<ChatProvider>(
        builder: (context, provider, _) {
          final groupChats = _filterGroupChats(provider);
          final totalGroupCount = provider.chats
              .where((chat) => chat.type == ChatType.group)
              .length;
          final sections = _buildSections(groupChats);

          return Scaffold(
            backgroundColor: AppColors.background,
            body: Column(
              children: [
                _GroupChatsHeader(
                  searchKeyword: provider.searchKeyword,
                  totalGroupCount: totalGroupCount,
                  onSearchChanged: provider.setSearchKeyword,
                  onSearchCleared: provider.clearSearch,
                  onCreateGroup: _openCreateGroup,
                ),
                Expanded(
                  child: provider.isChatsLoading && groupChats.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: () => _loadChats(refresh: true),
                          child: groupChats.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    96,
                                    24,
                                    24,
                                  ),
                                  children: [
                                    _EmptyGroupChatsState(
                                      isEmptySearch: provider.searchKeyword
                                          .trim()
                                          .isNotEmpty,
                                      onCreateGroup: _openCreateGroup,
                                      onClearSearch: provider.clearSearch,
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    bottom: 24,
                                  ),
                                  itemCount: sections.length,
                                  itemBuilder: (context, index) {
                                    final section = sections[index];
                                    return _GroupChatSection(
                                      title: section.title,
                                      subtitle: section.subtitle,
                                      children: List<Widget>.generate(
                                        section.chats.length,
                                        (chatIndex) {
                                          final chat = section.chats[chatIndex];
                                          return ChatListItem(
                                            chat: chat,
                                            avatarBuilder: (_) =>
                                                _GroupChatAvatar(chat: chat),
                                            onTap: () => _openChat(chat),
                                            onLongPress: () =>
                                                _showChatActions(chat),
                                            footer: _GroupChatFooter(
                                              chat: chat,
                                              description: _groupDescription(
                                                chat,
                                              ),
                                              memberCount: _memberCountForChat(
                                                chat,
                                              ),
                                              onTap: () =>
                                                  _openGroupSettings(chat),
                                            ),
                                            showBottomDivider:
                                                chatIndex <
                                                section.chats.length - 1,
                                          );
                                        },
                                      ),
                                    );
                                  },
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

class _GroupSectionData {
  const _GroupSectionData({
    required this.title,
    required this.subtitle,
    required this.chats,
  });

  final String title;
  final String subtitle;
  final List<Chat> chats;
}

class _GroupChatsHeader extends StatefulWidget {
  const _GroupChatsHeader({
    required this.searchKeyword,
    required this.totalGroupCount,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onCreateGroup,
  });

  final String searchKeyword;
  final int totalGroupCount;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onCreateGroup;

  @override
  State<_GroupChatsHeader> createState() => _GroupChatsHeaderState();
}

class _GroupChatsHeaderState extends State<_GroupChatsHeader> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchKeyword);
  }

  @override
  void didUpdateWidget(_GroupChatsHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchKeyword != widget.searchKeyword) {
      _searchController.text = widget.searchKeyword;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final density = context.phoneDensity;
    final outerHorizontalPadding = density.scale(16);
    final outerVerticalPadding = density.scale(12);
    final titleGap = density.scale(14);
    final searchBarHeight = density.scale(46);
    final searchBarRadius = density.scale(24);
    final searchBarHorizontalPadding = density.scale(14);
    final searchIconSize = density.scale(20);
    final clearIconSize = density.scale(18);
    final searchVerticalPadding = density.scale(13);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            outerHorizontalPadding,
            outerVerticalPadding,
            outerHorizontalPadding,
            outerVerticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '群聊',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onCreateGroup,
                    child: const Text(
                      '创建',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: titleGap),
              Container(
                height: searchBarHeight,
                padding: EdgeInsets.symmetric(
                  horizontal: searchBarHorizontalPadding,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(searchBarRadius),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search,
                      size: searchIconSize,
                      color: AppColors.textTertiary,
                    ),
                    SizedBox(width: density.scale(8)),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: widget.onSearchChanged,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: '搜索群聊',
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: searchVerticalPadding,
                          ),
                        ),
                      ),
                    ),
                    if (widget.searchKeyword.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          widget.onSearchCleared();
                        },
                        child: Icon(
                          Icons.clear,
                          size: clearIconSize,
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: density.scale(10)),
              Text(
                '共 ${widget.totalGroupCount} 个群聊',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupChatSection extends StatelessWidget {
  const _GroupChatSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final density = context.phoneDensity;
    return Padding(
      padding: EdgeInsets.only(bottom: density.scale(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              density.scale(16),
              density.scale(12),
              density.scale(16),
              density.scale(8),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(width: density.scale(8)),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _GroupChatFooter extends StatelessWidget {
  const _GroupChatFooter({
    required this.chat,
    required this.description,
    required this.memberCount,
    required this.onTap,
  });

  final Chat chat;
  final String? description;
  final int? memberCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final density = context.phoneDensity;
    final rowHorizontalPadding = density.scale(16);
    final avatarBoxSize = density.scale(56);
    final avatarGap = density.scale(16);
    final leftInset = rowHorizontalPadding + avatarBoxSize + avatarGap;
    final chips = <Widget>[
      if (memberCount != null)
        _GroupMetaChip(icon: Icons.group_outlined, label: '$memberCount 人'),
      if (chat.isPinned)
        const _GroupMetaChip(icon: Icons.push_pin_outlined, label: '已置顶'),
      if (chat.isMuted)
        const _GroupMetaChip(
          icon: Icons.notifications_off_outlined,
          label: '免打扰',
        ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        leftInset,
        0,
        rowHorizontalPadding,
        density.scale(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(density.scale(16)),
          child: Ink(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: density.scale(12),
              vertical: density.scale(10),
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(density.scale(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description ?? '暂无群简介',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (chips.isNotEmpty) ...[
                  SizedBox(height: density.scale(8)),
                  Wrap(
                    spacing: density.scale(8),
                    runSpacing: density.scale(8),
                    children: chips,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupMetaChip extends StatelessWidget {
  const _GroupMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final density = context.phoneDensity;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: density.scale(8),
        vertical: density.scale(4),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(density.scale(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: density.scale(13), color: AppColors.textTertiary),
          SizedBox(width: density.scale(4)),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _EmptyGroupChatsState extends StatelessWidget {
  const _EmptyGroupChatsState({
    required this.isEmptySearch,
    required this.onCreateGroup,
    required this.onClearSearch,
  });

  final bool isEmptySearch;
  final VoidCallback onCreateGroup;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final density = context.phoneDensity;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isEmptySearch ? Icons.search_off : Icons.group_outlined,
            size: density.scale(72),
            color: AppColors.textTertiary,
          ),
          SizedBox(height: density.scale(16)),
          Text(
            isEmptySearch ? '未找到相关群聊' : '还没有加入任何群聊',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: density.scale(8)),
          Text(
            isEmptySearch ? '试试其他关键词' : '你可以先进入创建页，或等待其他人邀请你加入群聊',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textTertiary),
          ),
          SizedBox(height: density.scale(24)),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isEmptySearch ? onClearSearch : onCreateGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor: isEmptySearch
                    ? AppColors.surfaceMuted
                    : AppColors.primary,
                foregroundColor: isEmptySearch
                    ? AppColors.textPrimary
                    : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(isEmptySearch ? '清空搜索' : '创建群聊'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupChatActionSheet extends StatelessWidget {
  const _GroupChatActionSheet({
    required this.chat,
    required this.onViewGroupSettings,
    required this.onTogglePinned,
    required this.onToggleMuted,
    required this.onDelete,
  });

  final Chat chat;
  final Future<void> Function() onViewGroupSettings;
  final Future<void> Function() onTogglePinned;
  final Future<void> Function() onToggleMuted;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final density = context.phoneDensity;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        density.scale(20),
        density.scale(16),
        density.scale(20),
        density.scale(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chat.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: density.scale(6)),
          const Text(
            '长按操作',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          SizedBox(height: density.scale(16)),
          _GroupChatActionTile(
            icon: Icons.info_outline,
            label: '查看群资料',
            onTap: () async {
              Navigator.of(context).pop();
              await onViewGroupSettings();
            },
          ),
          _GroupChatActionTile(
            icon: chat.isPinned
                ? Icons.push_pin_outlined
                : Icons.push_pin_rounded,
            label: chat.isPinned ? '取消置顶' : '置顶群聊',
            onTap: () async {
              Navigator.of(context).pop();
              await onTogglePinned();
            },
          ),
          _GroupChatActionTile(
            icon: chat.isMuted
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            label: chat.isMuted ? '取消免打扰' : '设为免打扰',
            onTap: () async {
              Navigator.of(context).pop();
              await onToggleMuted();
            },
          ),
          _GroupChatActionTile(
            icon: Icons.delete_outline,
            label: '删除会话',
            danger: true,
            onTap: () async {
              Navigator.of(context).pop();
              await onDelete();
            },
          ),
        ],
      ),
    );
  }
}

class _GroupChatActionTile extends StatelessWidget {
  const _GroupChatActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final density = context.phoneDensity;
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(density.scale(16)),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: density.scale(4),
            vertical: density.scale(14),
          ),
          child: Row(
            children: [
              Icon(icon, size: density.scale(20), color: color),
              SizedBox(width: density.scale(12)),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupChatAvatar extends StatefulWidget {
  const _GroupChatAvatar({required this.chat});

  final Chat chat;

  @override
  State<_GroupChatAvatar> createState() => _GroupChatAvatarState();
}

class _GroupChatAvatarState extends State<_GroupChatAvatar> {
  final RoomAvatarService _roomAvatarService = RoomAvatarService();

  String? _cachedAvatarPath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cachedAvatarPath = widget.chat.localAvatarPath;

    var needsLoad = false;
    if (_cachedAvatarPath != null && _cachedAvatarPath!.isNotEmpty) {
      final file = File(_cachedAvatarPath!);
      if (!file.existsSync()) {
        _cachedAvatarPath = null;
        needsLoad = true;
      }
    } else {
      needsLoad = true;
    }

    if (needsLoad &&
        widget.chat.avatarObjectKey != null &&
        widget.chat.avatarObjectKey!.isNotEmpty) {
      _loadAvatar();
    }
  }

  @override
  void didUpdateWidget(_GroupChatAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.chat.avatarObjectKey != oldWidget.chat.avatarObjectKey) {
      _cachedAvatarPath = widget.chat.localAvatarPath;
      if (widget.chat.avatarObjectKey != null &&
          widget.chat.avatarObjectKey!.isNotEmpty &&
          _cachedAvatarPath == null) {
        _loadAvatar();
      }
    }
  }

  Future<void> _loadAvatar() async {
    if (_isLoading) return;
    final avatarObjectKey = widget.chat.avatarObjectKey;
    if (avatarObjectKey == null || avatarObjectKey.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final cachedPath = await _roomAvatarService.loadAndCacheAvatar(
        roomId: widget.chat.roomId,
        avatarObjectKey: avatarObjectKey,
      );
      if (!mounted) return;
      setState(() {
        _cachedAvatarPath = cachedPath;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final density = context.phoneDensity;
    final avatarSize = density.scale(48);
    final loadingIndicatorSize = density.scale(16);

    if (_cachedAvatarPath != null && _cachedAvatarPath!.isNotEmpty) {
      final file = File(_cachedAvatarPath!);
      if (file.existsSync()) {
        return SizedBox(
          width: avatarSize,
          height: avatarSize,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(avatarSize / 2),
            child: Image.file(
              file,
              width: avatarSize,
              height: avatarSize,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildDefaultAvatar(context),
            ),
          ),
        );
      }
    }

    if (_isLoading &&
        widget.chat.avatarObjectKey != null &&
        widget.chat.avatarObjectKey!.isNotEmpty) {
      return Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(avatarSize / 2),
        ),
        child: Center(
          child: SizedBox(
            width: loadingIndicatorSize,
            height: loadingIndicatorSize,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final avatar = widget.chat.avatar;
    if (avatar != null && avatar.isNotEmpty) {
      if (avatar.endsWith('.svg')) {
        return SvgPicture.asset(avatar, width: avatarSize, height: avatarSize);
      }
      if (!avatar.startsWith('http://') && !avatar.startsWith('https://')) {
        return SizedBox(
          width: avatarSize,
          height: avatarSize,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(avatarSize / 2),
            child: Image.asset(
              avatar,
              width: avatarSize,
              height: avatarSize,
              fit: BoxFit.cover,
            ),
          ),
        );
      }
    }

    return _buildDefaultAvatar(context);
  }

  Widget _buildDefaultAvatar(BuildContext context) {
    final density = context.phoneDensity;
    final avatarSize = density.scale(48);
    final initial = AvatarColorUtils.getInitial(widget.chat.name.trim());
    final backgroundColor = AvatarColorUtils.generateBackgroundColor(
      widget.chat.roomId,
    );

    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(avatarSize / 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: density.scale(19),
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
