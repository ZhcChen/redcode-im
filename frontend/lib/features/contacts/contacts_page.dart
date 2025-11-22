import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/friend_service.dart';
import '../../core/services/friend_store.dart';
import '../../core/services/user_avatar_service.dart';
import '../../core/storage/avatar_cache.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/services/websocket_service.dart';
import 'add_friend_page.dart';
import 'contact_detail_page.dart';
import 'models/friend_models.dart';

// 字符串哈希函数（与桌面端保持一致）
int _hashCode(String str) {
  int hash = 0;
  for (int i = 0; i < str.length; i++) {
    int char = str.codeUnitAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash;
  }
  return hash.abs();
}

// 预设色调（与桌面端保持一致）
List<Color> _getAvatarColors() {
  return [
    const Color(0xFF6366f1), // 靛蓝
    const Color(0xFF8b5cf6), // 紫色
    const Color(0xFFec4899), // 粉红
    const Color(0xFFf43f5e), // 玫瑰
    const Color(0xFFf59e0b), // 琥珀
    const Color(0xFF10b981), // 翠绿
    const Color(0xFF06b6d4), // 青色
    const Color(0xFF3b82f6), // 蓝色
    const Color(0xFF6366f1), // 靛蓝
    const Color(0xFFa855f7), // 紫罗兰
  ];
}

// 根据文本生成背景色（与桌面端保持一致）
Color _generateBackgroundColor(String text) {
  if (!text.isEmpty) {
    final colors = _getAvatarColors();
    final hash = _hashCode(text);
    return colors[hash % colors.length];
  }
  return _getAvatarColors().first;
}

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => ContactsPageState();
}

class ContactsPageState extends State<ContactsPage> {
  final ScrollController _scrollController = ScrollController();
  final _listViewKey = GlobalKey();
  List<ContactSection> _sections = const [];
  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, double> _sectionOffsets = {};
  final Map<String, FriendInfo> _friendMap = {};
  List<FriendInfo> _friends = [];
  final FriendService _friendService = FriendService();
  late final WebSocketService _webSocketService;
  late final FriendStore _friendStore;

  int _activeIndex = 0;
  int _pendingRequests = 0;
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _hasLoadedCache = false;

  @override
  void initState() {
    super.initState();
    _webSocketService = WebSocketService.instance;
    _friendStore = FriendStore.instance;
    _webSocketService.addListener(_onWebSocketEvent);
    _friendStore.addListener(_onFriendStoreChanged);
    _pendingRequests = _friendStore.pendingIncoming;
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initContacts();
    });
  }

  /// 初始化联系人：先加载缓存，然后静默更新
  Future<void> _initContacts() async {
    // 先加载缓存数据
    final cachedFriends = await _friendStore.loadCachedFriends();
    if (cachedFriends.isNotEmpty && mounted) {
      _hasLoadedCache = true;
      // 为缓存的好友填充 localAvatarPath
      final friendsWithAvatar = await Future.wait(
        cachedFriends.map((friend) async {
          if (friend.user.avatarObjectKey != null &&
              friend.user.avatarObjectKey!.isNotEmpty &&
              (friend.user.localAvatarPath == null ||
                  friend.user.localAvatarPath!.isEmpty)) {
            try {
              final cachedPath = await AvatarCache.instance.resolveLocalPath(
                userId: friend.user.id,
                objectKey: friend.user.avatarObjectKey!,
              );
              if (cachedPath != null) {
                return FriendInfo(
                  id: friend.id,
                  user: friend.user.copyWith(localAvatarPath: cachedPath),
                  createdAt: friend.createdAt,
                );
              }
            } catch (e) {
              // 填充缓存头像失败，忽略错误
            }
          }
          return friend;
        }),
      );
      _friends = friendsWithAvatar;
      _friendMap
        ..clear()
        ..addEntries(
          friendsWithAvatar.map((friend) => MapEntry(friend.user.id, friend)),
        );
      _updateSections();
      setState(() {
        _isLoading = false;
      });
    }

    // 静默更新（后台请求最新数据，不显示 loading）
    _loadContacts(silent: true);
  }

  Future<void> refreshContacts({bool force = false}) async {
    if (_isLoading && !force) return;
    // 如果已有缓存数据且不是强制刷新，则静默更新
    final silent = _hasLoadedCache && !force;
    await _loadContacts(silent: silent);
  }

  @override
  void dispose() {
    _webSocketService.removeListener(_onWebSocketEvent);
    _friendStore.removeListener(_onFriendStoreChanged);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts({bool silent = false}) async {
    // 静默更新时不显示 loading，除非是首次加载或强制刷新
    if (!silent || !_hasLoadedCache) {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
      });
    }

    try {
      final friends = await _friendService.fetchFriends();
      final pending = await _friendService.fetchFriendRequests(
        direction: 'incoming',
        status: 'pending',
      );

      if (!mounted) return;

      // 为每个好友填充 localAvatarPath
      final friendsWithAvatar = await Future.wait(
        friends.map((friend) async {
          if (friend.user.avatarObjectKey != null &&
              friend.user.avatarObjectKey!.isNotEmpty &&
              (friend.user.localAvatarPath == null ||
                  friend.user.localAvatarPath!.isEmpty)) {
            try {
              final cachedPath = await AvatarCache.instance.resolveLocalPath(
                userId: friend.user.id,
                objectKey: friend.user.avatarObjectKey!,
              );
              if (cachedPath != null) {
                // 创建新的 FriendInfo，更新 user 的 localAvatarPath
                return FriendInfo(
                  id: friend.id,
                  user: friend.user.copyWith(localAvatarPath: cachedPath),
                  createdAt: friend.createdAt,
                );
              }
            } catch (e) {
              // 填充头像缓存失败，忽略错误
            }
          }
          return friend;
        }),
      );

      _friendMap
        ..clear()
        ..addEntries(
          friendsWithAvatar.map((friend) => MapEntry(friend.user.id, friend)),
        );

      setState(() {
        _friends = friendsWithAvatar;
        _pendingRequests = pending.length;
        _isLoading = false;
        _loadFailed = false;
        _hasLoadedCache = true;
        _updateSections();
      });
      // 同步到全局 Store，后续增量由 WS 维护（会自动保存到缓存）
      _friendStore.setFriends(friendsWithAvatar);
      _friendStore.setPendingIncoming(pending.length);
    } catch (error) {
      if (!mounted) return;
      // 静默更新失败时不显示错误提示，保留缓存数据
      if (!silent) {
        setState(() {
          _friends = [];
          _pendingRequests = 0;
          _isLoading = false;
          _loadFailed = true;
          _friendMap.clear();
          _updateSections();
        });
        _friendStore.setPendingIncoming(0);
        _showSnack('加载联系人失败');
      } else {
        // 静默更新失败时，只更新 loading 状态
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onFriendStoreChanged() {
    if (!mounted) return;
    setState(() {
      _friends = _friendStore.friends;
      _pendingRequests = _friendStore.pendingIncoming;
      _friendMap
        ..clear()
        ..addEntries(_friends.map((f) => MapEntry(f.user.id, f)));
      _updateSections();
    });
  }

  void _updateSections() {
    final sections = _buildSections();
    _sections = sections;
    _sectionKeys
      ..clear()
      ..addEntries(
        sections.map((section) => MapEntry(section.tag, GlobalKey())),
      );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateSectionOffsets(),
    );
  }

  List<ContactSection> _buildSections() {
    final sections = <ContactSection>[
      ContactSection(
        tag: '🔍',
        showHeader: false,
        entries: [
          ContactEntry.special(
            id: 'new_friends',
            name: '新的朋友',
            assetIcon: AppAssets.contactsNewFriend,
            badgeCount: _pendingRequests > 0 ? _pendingRequests : null,
          ),
          ContactEntry.special(
            id: 'groups',
            name: '群聊',
            assetIcon: AppAssets.contactsGroup,
          ),
        ],
      ),
    ];

    if (_friends.isEmpty) {
      return sections;
    }

    final Map<String, List<ContactEntry>> grouped = {};
    for (final friend in _friends) {
      // 标题显示昵称（如果有备注，备注优先显示）
      final displayName = friend.user.nickname?.isNotEmpty == true
          ? friend.user.nickname!
          : friend.user.username;
      // 副标题显示手机号
      final phoneNumber = friend.user.username;
      final tag = _letterTag(displayName);
      grouped.putIfAbsent(tag, () => []);
      grouped[tag]!.add(
        ContactEntry.friend(
          id: friend.user.id,
          name: displayName,
          detail: '手机号：$phoneNumber',
          avatarUrl: friend.user.avatarUrl,
          avatarObjectKey: friend.user.avatarObjectKey,
          localAvatarPath: friend.user.localAvatarPath,
        ),
      );
    }

    final sortedTags = grouped.keys.toList()..sort();
    for (final tag in sortedTags) {
      final entries = grouped[tag]!..sort((a, b) => a.name.compareTo(b.name));
      sections.add(ContactSection(tag: tag, entries: entries));
    }

    return sections;
  }

  String _letterTag(String name) {
    if (name.trim().isEmpty) {
      return '#';
    }
    final firstChar = name.trim()[0].toUpperCase();
    final isLetter = RegExp(r'[A-Z]').hasMatch(firstChar);
    return isLetter ? firstChar : '#';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAddFriend({bool showRequestsFirst = false}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddFriendPage(
          existingFriendIds: _friendMap.keys.toSet(),
          showRequestsFirst: showRequestsFirst,
        ),
      ),
    );

    if (changed == true && mounted) {
      await _loadContacts();
    }
  }

  void _onWebSocketEvent() {
    if (!mounted) return;
    // WebSocketService 仍可能更新 pending 计数，这里保持兼容
    final count = _webSocketService.pendingFriendRequestCount;
    if (count != _pendingRequests) {
      _friendStore.setPendingIncoming(count);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            _buildSearchBar(context),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _sections.isEmpty
                  ? _loadFailed
                        ? _ErrorPlaceholder(onRetry: _loadContacts)
                        : const _EmptyContactsPlaceholder()
                  : Stack(
                      children: [
                        NotificationListener<SizeChangedLayoutNotification>(
                          onNotification: (_) {
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => _updateSectionOffsets(),
                            );
                            return true;
                          },
                          child: SizeChangedLayoutNotifier(
                            child: ListView.builder(
                              key: _listViewKey,
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 32),
                              itemCount: _sections.length,
                              itemBuilder: (context, index) {
                                final section = _sections[index];
                                return _ContactSectionWidget(
                                  key: _sectionKeys[section.tag],
                                  section: section,
                                  onTapEntry: _handleEntryTap,
                                );
                              },
                            ),
                          ),
                        ),
                        _buildIndexBar(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '联系人',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: _openAddFriend,
            icon: const Icon(Icons.add_circle_outline),
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: _openAddFriend,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.search,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '搜索添加好友',
                  style: TextStyle(fontSize: 15, color: AppColors.textTertiary),
                ),
              ),
              TextButton(onPressed: _openAddFriend, child: const Text('去添加')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndexBar() {
    if (_sections.length <= 1) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_sections.length, (index) {
            final tag = _sections[index].tag;
            final isActive = index == _activeIndex;
            return GestureDetector(
              onTap: () => _scrollToSection(index),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.textQuaternary,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  void _handleEntryTap(ContactEntry entry) {
    if (entry.id == 'new_friends') {
      _openAddFriend(showRequestsFirst: true);
      return;
    }

    if (entry.type == ContactEntryType.special) {
      _showSnack('功能即将上线，敬请期待');
      return;
    }

    final friend = _friendMap[entry.id];
    if (friend != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ContactDetailPage(friend: friend)),
      );
    } else {
      _showSnack('未找到联系人详情，请稍后重试');
    }
  }

  void _handleScroll() {
    if (_sectionOffsets.isEmpty) return;
    final offset = _scrollController.offset + 8;
    var currentIndex = 0;
    for (var i = 0; i < _sections.length; i++) {
      final sectionOffset = _sectionOffsets[_sections[i].tag];
      if (sectionOffset == null) continue;
      if (offset >= sectionOffset) {
        currentIndex = i;
      } else {
        break;
      }
    }
    if (currentIndex != _activeIndex) {
      setState(() => _activeIndex = currentIndex);
    }
  }

  void _scrollToSection(int index) {
    final tag = _sections[index].tag;
    final targetOffset = _sectionOffsets[tag];
    if (targetOffset == null) return;
    final maxOffset = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      math.min(targetOffset, maxOffset),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
    setState(() => _activeIndex = index);
  }

  void _updateSectionOffsets() {
    final listContext = _listViewKey.currentContext;
    if (listContext == null) return;
    final listBox = listContext.findRenderObject() as RenderBox?;
    if (listBox == null) return;
    final listTop = listBox.localToGlobal(Offset.zero).dy;
    final scrollOffset = _scrollController.positions.isEmpty
        ? 0
        : _scrollController.position.pixels;

    for (final section in _sections) {
      final key = _sectionKeys[section.tag];
      final context = key?.currentContext;
      if (context == null) continue;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final offset = box.localToGlobal(Offset.zero).dy;
      _sectionOffsets[section.tag] =
          offset - listTop + scrollOffset - (section.showHeader ? 12 : 0);
    }
  }
}

class _ContactSectionWidget extends StatelessWidget {
  const _ContactSectionWidget({
    super.key,
    required this.section,
    required this.onTapEntry,
  });

  final ContactSection section;
  final ValueChanged<ContactEntry> onTapEntry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.showHeader)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                section.tag,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 8),
          ...section.entries.map((entry) {
            final badge = entry.badgeCount;
            return _ContactListTile(
              entry: entry,
              badge: badge,
              onTap: () => onTapEntry(entry),
            );
          }),
        ],
      ),
    );
  }
}

class _ContactListTile extends StatelessWidget {
  const _ContactListTile({
    required this.entry,
    required this.badge,
    required this.onTap,
  });

  final ContactEntry entry;
  final int? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSpecial = entry.type == ContactEntryType.special;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _ContactAvatar(key: ValueKey(entry.id), entry: entry),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (entry.detail != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        entry.detail!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (badge != null && badge! > 0)
              AppBadge(
                count: badge!,
                size: 18,
                fontSize: 11,
                backgroundColor: AppColors.primary,
              ),
            if (isSpecial)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.chevron_right,
                  color: AppColors.textQuaternary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContactAvatar extends StatefulWidget {
  const _ContactAvatar({super.key, required this.entry});

  final ContactEntry entry;

  @override
  State<_ContactAvatar> createState() => _ContactAvatarState();
}

class _ContactAvatarState extends State<_ContactAvatar> {
  String? _cachedAvatarPath;
  bool _isLoading = false;
  final _avatarService = UserAvatarService();

  @override
  void initState() {
    super.initState();
    _cachedAvatarPath = widget.entry.localAvatarPath;

    // 验证本地缓存文件是否真的存在
    bool needsLoad = false;
    if (_cachedAvatarPath != null && _cachedAvatarPath!.isNotEmpty) {
      final file = File(_cachedAvatarPath!);
      final exists = file.existsSync();
      if (!exists) {
        _cachedAvatarPath = null;
        needsLoad = true;
      } else {
        needsLoad = false;
      }
    } else {
      needsLoad = true;
    }

    // 如果没有有效的本地缓存，但有avatarObjectKey，先尝试快速检查缓存
    if (needsLoad &&
        widget.entry.avatarObjectKey != null &&
        widget.entry.avatarObjectKey!.isNotEmpty) {
      // 使用 microtask 立即检查缓存，尽可能在第一次 build 之前完成
      Future.microtask(() async {
        if (!mounted) return;
        try {
          final cachedPath = await AvatarCache.instance.resolveLocalPath(
            userId: widget.entry.id,
            objectKey: widget.entry.avatarObjectKey!,
          );
          if (cachedPath != null && mounted && _cachedAvatarPath == null) {
            setState(() {
              _cachedAvatarPath = cachedPath;
            });
            return; // 找到缓存，不需要加载
          }
        } catch (e) {
          // 快速检查缓存异常，忽略
        }
        // 如果没找到缓存，再调用异步加载
        if (mounted && _cachedAvatarPath == null) {
          _loadAvatar();
        }
      });
    }
  }

  @override
  void didUpdateWidget(_ContactAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 如果 localAvatarPath 变化，更新缓存路径
    if (widget.entry.localAvatarPath != oldWidget.entry.localAvatarPath) {
      _cachedAvatarPath = widget.entry.localAvatarPath;
    }

    // 如果avatarObjectKey变化，重新加载
    if (widget.entry.avatarObjectKey != oldWidget.entry.avatarObjectKey) {
      if (widget.entry.avatarObjectKey != null &&
          widget.entry.avatarObjectKey!.isNotEmpty &&
          _cachedAvatarPath == null) {
        _loadAvatar();
      }
    }
  }

  Future<void> _loadAvatar() async {
    if (_isLoading) return;
    if (widget.entry.avatarObjectKey == null ||
        widget.entry.avatarObjectKey!.isEmpty) {
      return;
    }

    // 先快速检查缓存，如果找到了就不显示加载指示器
    try {
      final cachedPath = await AvatarCache.instance.resolveLocalPath(
        userId: widget.entry.id,
        objectKey: widget.entry.avatarObjectKey!,
      );
      if (cachedPath != null && mounted) {
        setState(() {
          _cachedAvatarPath = cachedPath;
        });
        return;
      }
    } catch (e) {
      // 快速检查缓存异常，忽略
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final cachedPath = await _avatarService.loadAndCacheAvatar(
        userId: widget.entry.id,
        avatarObjectKey: widget.entry.avatarObjectKey,
      );
      if (mounted) {
        setState(() {
          _cachedAvatarPath = cachedPath;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSpecial = widget.entry.type == ContactEntryType.special;
    final size = isSpecial ? 44.0 : 48.0;
    if (isSpecial) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(size / 2),
        ),
        child: widget.entry.assetIcon != null
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: SvgPicture.asset(widget.entry.assetIcon!),
              )
            : const Icon(Icons.group_outlined, color: AppColors.primary),
      );
    }

    // 优先使用本地缓存路径（与聊天列表保持一致，避免闪烁）
    if (_cachedAvatarPath != null && _cachedAvatarPath!.isNotEmpty) {
      final file = File(_cachedAvatarPath!);
      final exists = file.existsSync();
      if (exists) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // 如果文件读取失败，显示默认头像
              return _buildDefaultAvatar(size);
            },
          ),
        );
      }
    }

    // 处理其他类型的头像（asset、svg等）
    if (widget.entry.avatarAsset != null &&
        widget.entry.avatarAsset!.endsWith('.svg')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(size / 2),
        ),
        padding: const EdgeInsets.all(8),
        child: SvgPicture.asset(widget.entry.avatarAsset!),
      );
    }

    if (widget.entry.avatarAsset != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.asset(
          widget.entry.avatarAsset!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    // 如果有avatarObjectKey但还在加载中，显示加载指示器
    // 或者如果有avatarObjectKey但_cachedAvatarPath为空，也显示加载指示器（避免闪烁）
    if ((_isLoading ||
            (_cachedAvatarPath == null &&
                widget.entry.avatarObjectKey != null &&
                widget.entry.avatarObjectKey!.isNotEmpty)) &&
        widget.entry.avatarObjectKey != null &&
        widget.entry.avatarObjectKey!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(size / 2),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // 注意：不再直接使用avatarUrl，因为COS是私有读
    // 如果后端返回了临时下载地址（avatarUrl），可以考虑使用
    // 但根据文档，应该优先使用avatarObjectKey获取临时下载地址

    return _buildDefaultAvatar(size);
  }

  Widget _buildDefaultAvatar(double size) {
    final name = widget.entry.name.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final backgroundColor = _generateBackgroundColor(name);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.4,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

enum ContactEntryType { special, friend }

class ContactSection {
  const ContactSection({
    required this.tag,
    required this.entries,
    this.showHeader = true,
  });

  final String tag;
  final List<ContactEntry> entries;
  final bool showHeader;
}

class ContactEntry {
  const ContactEntry._({
    required this.id,
    required this.name,
    required this.type,
    this.detail,
    this.assetIcon,
    this.avatarAsset,
    this.avatarUrl,
    this.avatarObjectKey,
    this.localAvatarPath,
    this.badgeCount,
  });

  const ContactEntry.special({
    required String id,
    required String name,
    String? assetIcon,
    int? badgeCount,
  }) : this._(
         id: id,
         name: name,
         type: ContactEntryType.special,
         assetIcon: assetIcon,
         badgeCount: badgeCount,
       );

  const ContactEntry.friend({
    required String id,
    required String name,
    String? detail,
    String? avatarAsset,
    String? avatarUrl,
    String? avatarObjectKey,
    String? localAvatarPath,
  }) : this._(
         id: id,
         name: name,
         type: ContactEntryType.friend,
         detail: detail,
         avatarAsset: avatarAsset,
         avatarUrl: avatarUrl,
         avatarObjectKey: avatarObjectKey,
         localAvatarPath: localAvatarPath,
       );

  final String id;
  final String name;
  final ContactEntryType type;
  final String? detail;
  final String? assetIcon;
  final String? avatarAsset;
  final String? avatarUrl;
  final String? avatarObjectKey;
  final String? localAvatarPath;
  final int? badgeCount;
}

class _EmptyContactsPlaceholder extends StatelessWidget {
  const _EmptyContactsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.group_outlined, size: 72, color: AppColors.textTertiary),
          SizedBox(height: 16),
          Text(
            '还没有好友',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '点击右上角添加好友，开始聊天吧',
            style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  const _ErrorPlaceholder({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_tethering_error_rounded,
            size: 72,
            color: AppColors.danger,
          ),
          const SizedBox(height: 16),
          const Text(
            '联系人加载失败',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: () => onRetry(), child: const Text('重新加载')),
        ],
      ),
    );
  }
}
