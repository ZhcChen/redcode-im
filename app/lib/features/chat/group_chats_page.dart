import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/room_avatar_service.dart';
import '../../core/theme/phone_density.dart';
import '../../core/utils/avatar_color_utils.dart';
import 'chat_detail_page_v2.dart';
import 'create_group_page.dart';
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
      final extra = chat.extra;
      final candidateFields = <String?>[
        extra?['description'] as String?,
        extra?['group_description'] as String?,
        extra?['groupDescription'] as String?,
      ];
      for (final field in candidateFields) {
        if (field != null && field.toLowerCase().contains(keyword)) {
          return true;
        }
      }
      return false;
    }).toList();
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
                                  itemCount: groupChats.length,
                                  itemBuilder: (context, index) {
                                    final chat = groupChats[index];
                                    return ChatListItem(
                                      chat: chat,
                                      avatarBuilder: (_) =>
                                          _GroupChatAvatar(chat: chat),
                                      onTap: () => _openChat(chat),
                                      showBottomDivider:
                                          index < groupChats.length - 1,
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
