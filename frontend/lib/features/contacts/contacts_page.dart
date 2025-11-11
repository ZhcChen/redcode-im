import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/friend_service.dart';
import '../../core/services/friend_store.dart';
import '../../core/services/user_avatar_service.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/services/websocket_service.dart';
import 'add_friend_page.dart';
import 'contact_detail_page.dart';
import 'models/friend_models.dart';

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
      _friends = cachedFriends;
      _friendMap
        ..clear()
        ..addEntries(
          cachedFriends.map((friend) => MapEntry(friend.user.id, friend)),
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

      _friendMap
        ..clear()
        ..addEntries(friends.map((friend) => MapEntry(friend.user.id, friend)));

      setState(() {
        _friends = friends;
        _pendingRequests = pending.length;
        _isLoading = false;
        _loadFailed = false;
        _hasLoadedCache = true;
        _updateSections();
      });
      // 同步到全局 Store，后续增量由 WS 维护（会自动保存到缓存）
      _friendStore.setFriends(friends);
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
      final displayName = friend.user.nickname?.isNotEmpty == true
          ? friend.user.nickname!
          : friend.user.username;
      final tag = _letterTag(displayName);
      grouped.putIfAbsent(tag, () => []);
      grouped[tag]!.add(
        ContactEntry.friend(
          id: friend.user.id,
          name: displayName,
          detail: friend.user.email?.isNotEmpty == true
              ? friend.user.email
              : '账号：${friend.user.username}',
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
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              AppAssets.loginLogo,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
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
    print('[ContactAvatar] ========== 初始化联系人头像 ==========');
    print('[ContactAvatar] userId: ${widget.entry.id}');
    print('[ContactAvatar] name: ${widget.entry.name}');
    print('[ContactAvatar] avatarObjectKey: ${widget.entry.avatarObjectKey}');
    print('[ContactAvatar] localAvatarPath: ${widget.entry.localAvatarPath}');
    print('[ContactAvatar] avatarUrl: ${widget.entry.avatarUrl}');
    
    // 验证本地缓存文件是否真的存在
    final localPath = widget.entry.localAvatarPath;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        print('[ContactAvatar] ✅ 使用本地缓存: $localPath');
        _cachedAvatarPath = localPath;
        // 不需要加载，直接返回
        return;
      } else {
        print('[ContactAvatar] ⚠️ 本地文件不存在: $localPath');
      }
    }
    
    // 如果没有有效的本地缓存，但有avatarObjectKey，异步加载
    if (widget.entry.avatarObjectKey != null &&
        widget.entry.avatarObjectKey!.isNotEmpty) {
      print('[ContactAvatar] ⚠️ 需要异步加载头像');
      _loadAvatar();
    } else {
      print('[ContactAvatar] ⚠️ 无avatarObjectKey，使用默认头像');
    }
  }

  @override
  void didUpdateWidget(_ContactAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果 localAvatarPath 变化，验证并更新
    if (widget.entry.localAvatarPath != oldWidget.entry.localAvatarPath) {
      final newPath = widget.entry.localAvatarPath;
      if (newPath != null && newPath.isNotEmpty) {
        final file = File(newPath);
        if (file.existsSync()) {
          // 文件存在，直接使用
          setState(() {
            _cachedAvatarPath = newPath;
            _isLoading = false;
          });
          return;
        }
      }
      // 文件不存在或路径为空，清除缓存
      _cachedAvatarPath = null;
    }
    
    // 如果avatarObjectKey变化，重新加载
    if (widget.entry.avatarObjectKey != oldWidget.entry.avatarObjectKey) {
      if (widget.entry.avatarObjectKey != null &&
          widget.entry.avatarObjectKey!.isNotEmpty &&
          _cachedAvatarPath == null &&
          !_isLoading) {
        _loadAvatar();
      }
    }
  }

  Future<void> _loadAvatar() async {
    print('[ContactAvatar] _loadAvatar 被调用');
    if (_isLoading) {
      print('[ContactAvatar] ⚠️ 正在加载中，跳过');
      return;
    }
    if (widget.entry.avatarObjectKey == null ||
        widget.entry.avatarObjectKey!.isEmpty) {
      print('[ContactAvatar] ⚠️ avatarObjectKey为空，跳过');
      return;
    }

    print('[ContactAvatar] 开始加载头像...');
    setState(() {
      _isLoading = true;
    });

    try {
      final cachedPath = await _avatarService.loadAndCacheAvatar(
        userId: widget.entry.id,
        avatarObjectKey: widget.entry.avatarObjectKey,
      );
      print('[ContactAvatar] 加载结果: $cachedPath');
      if (mounted) {
        setState(() {
          _cachedAvatarPath = cachedPath;
          _isLoading = false;
        });
        print('[ContactAvatar] ✅ 状态已更新');
      }
    } catch (e, stackTrace) {
      print('[ContactAvatar] ❌ 加载异常: $e');
      print('[ContactAvatar] 堆栈: $stackTrace');
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
      if (file.existsSync()) {
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
    if (_isLoading &&
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: const Icon(Icons.person_outline, color: AppColors.textQuaternary),
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
