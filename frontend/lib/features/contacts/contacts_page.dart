import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final ScrollController _scrollController = ScrollController();
  final _listViewKey = GlobalKey();
  late final List<ContactSection> _sections;
  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, double> _sectionOffsets = {};

  int _activeIndex = 0;
  final int _newFriendBadge = 3;

  @override
  void initState() {
    super.initState();
    _sections = _buildMockSections();
    for (final section in _sections) {
      _sectionKeys[section.tag] = GlobalKey();
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateSectionOffsets(),
    );
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateSectionOffsets(),
    );

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
              child: Stack(
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
                        padding: const EdgeInsets.only(bottom: 32),
                        itemCount: _sections.length,
                        itemBuilder: (context, index) {
                          final section = _sections[index];
                          return _ContactSectionWidget(
                            key: _sectionKeys[section.tag],
                            section: section,
                            newFriendBadge: index == 0 ? _newFriendBadge : 0,
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
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('添加联系人功能（mock）')));
            },
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
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 10),
            const Text(
              '搜索',
              style: TextStyle(fontSize: 15, color: AppColors.textTertiary),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('搜索功能暂未接入（mock）')));
              },
              child: const Text('前往'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndexBar() {
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
    final message = switch (entry.type) {
      ContactEntryType.special => '打开 ${entry.name} 功能（mock）',
      ContactEntryType.friend => '查看 ${entry.name} 的个人资料（mock）',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  List<ContactSection> _buildMockSections() {
    return [
      ContactSection(
        tag: '🔍',
        showHeader: false,
        entries: [
          ContactEntry.special(
            id: 'new_friends',
            name: '新的朋友',
            assetIcon: AppAssets.contactsNewFriend,
          ),
          ContactEntry.special(
            id: 'groups',
            name: '群聊',
            assetIcon: AppAssets.contactsGroup,
          ),
        ],
      ),
      ContactSection(
        tag: 'A',
        entries: [
          ContactEntry.friend(
            id: 'alice-chen',
            name: 'Alice Chen',
            detail: '最后在线：15:21',
            avatarAsset: AppAssets.defaultAvatar,
          ),
          ContactEntry.friend(
            id: 'andrew-song',
            name: '安德鲁',
            detail: '最后在线：昨天',
          ),
        ],
      ),
      ContactSection(
        tag: 'C',
        entries: [
          ContactEntry.friend(
            id: 'cici-lin',
            name: 'Cici Lin',
            detail: '最后在线：10:05',
          ),
          ContactEntry.friend(
            id: 'cloud-lab',
            name: 'Cloud Lab 团队',
            detail: '最后在线：周二',
          ),
        ],
      ),
      ContactSection(
        tag: 'J',
        entries: [
          ContactEntry.friend(
            id: 'joy-design',
            name: 'Joy（设计）',
            detail: '最后在线：刚刚',
          ),
        ],
      ),
      ContactSection(
        tag: 'L',
        entries: [
          ContactEntry.friend(id: 'linus', name: '林森', detail: '最后在线：1 天前'),
        ],
      ),
      ContactSection(
        tag: 'Z',
        entries: [
          ContactEntry.friend(id: 'zhc-chen', name: '陈晨', detail: '最后在线：09:12'),
        ],
      ),
    ];
  }
}

class _ContactSectionWidget extends StatelessWidget {
  const _ContactSectionWidget({
    super.key,
    required this.section,
    required this.newFriendBadge,
    required this.onTapEntry,
  });

  final ContactSection section;
  final int newFriendBadge;
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
            final badge = entry.id == 'new_friends'
                ? newFriendBadge
                : entry.badgeCount;
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
            _ContactAvatar(entry: entry),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge! > 99 ? '99+' : badge.toString(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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

class _ContactAvatar extends StatelessWidget {
  const _ContactAvatar({required this.entry});

  final ContactEntry entry;

  @override
  Widget build(BuildContext context) {
    final isSpecial = entry.type == ContactEntryType.special;
    final size = isSpecial ? 44.0 : 48.0;
    if (isSpecial) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: entry.assetIcon != null
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: SvgPicture.asset(entry.assetIcon!),
              )
            : const Icon(Icons.group_outlined, color: AppColors.primary),
      );
    }

    if (entry.avatarAsset != null && entry.avatarAsset!.endsWith('.svg')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(8),
        child: SvgPicture.asset(entry.avatarAsset!),
      );
    }

    if (entry.avatarAsset != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          entry.avatarAsset!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    if (entry.avatarUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          entry.avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
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
  }) : this._(
         id: id,
         name: name,
         type: ContactEntryType.friend,
         detail: detail,
         avatarAsset: avatarAsset,
         avatarUrl: avatarUrl,
       );

  final String id;
  final String name;
  final ContactEntryType type;
  final String? detail;
  final String? assetIcon;
  final String? avatarAsset;
  final String? avatarUrl;
  final int? badgeCount;
}
