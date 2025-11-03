import 'package:desktop_flutter/state/app_state.dart';
import 'package:desktop_flutter/state/home_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

typedef SectionCallback = void Function(HomeSection section);

class SideMenu extends StatelessWidget {
  const SideMenu({
    super.key,
    required this.currentSection,
    required this.onSectionSelected,
    required this.onOpenSettings,
    required this.onLogout,
    this.user,
  });

  final HomeSection currentSection;
  final SectionCallback onSectionSelected;
  final VoidCallback onOpenSettings;
  final VoidCallback onLogout;
  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 100,
      color: const Color(0xFFF5F4F5),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 10),
            child: GestureDetector(
              onTap: onOpenSettings,
              child: CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  _initials,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                _SideMenuItem(
                  label: HomeSection.chat.label,
                  iconPath: 'assets/images/menu/icon-chat.svg',
                  activeIconPath: 'assets/images/menu/icon-chat-selected.svg',
                  isActive: currentSection == HomeSection.chat,
                  onTap: () => onSectionSelected(HomeSection.chat),
                ),
                _SideMenuItem(
                  label: HomeSection.contact.label,
                  iconPath: 'assets/images/menu/icon-contract.svg',
                  activeIconPath: 'assets/images/menu/icon-contract-selected.svg',
                  isActive: currentSection == HomeSection.contact,
                  onTap: () => onSectionSelected(HomeSection.contact),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: PopupMenuButton<_MoreMenuAction>(
              tooltip: '更多',
              position: PopupMenuPosition.over,
              offset: const Offset(0, -10),
              child: const _MoreMenuTrigger(),
              onSelected: (action) {
                switch (action) {
                  case _MoreMenuAction.settings:
                    onOpenSettings();
                    break;
                  case _MoreMenuAction.logout:
                    onLogout();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _MoreMenuAction.settings,
                  child: Row(
                    children: [
                      SvgPicture.asset('assets/images/icon-setting.svg', width: 20, height: 20),
                      const SizedBox(width: 8),
                      const Text('设置'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _MoreMenuAction.logout,
                  child: Row(
                    children: [
                      SvgPicture.asset('assets/images/icon-logout.svg', width: 20, height: 20),
                      const SizedBox(width: 8),
                      const Text('退出登录'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _initials {
    final display = user?.displayName ?? '用户';
    final runes = display.runes.take(1).toList();
    return String.fromCharCodes(runes);
  }
}

class _SideMenuItem extends StatelessWidget {
  const _SideMenuItem({
    required this.label,
    required this.iconPath,
    required this.activeIconPath,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final String iconPath;
  final String activeIconPath;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                isActive ? activeIconPath : iconPath,
                width: 24,
                height: 24,
              ),
              const SizedBox(height: 11),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isActive ? const Color(0xFF4ECDC4) : const Color(0xFF9B9BB0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreMenuTrigger extends StatelessWidget {
  const _MoreMenuTrigger();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset('assets/images/icon-menu.svg', width: 24, height: 24),
        const SizedBox(height: 11),
        Text(
          '更多',
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, color: const Color(0xFF9B9BB0)),
        ),
      ],
    );
  }
}

enum _MoreMenuAction { settings, logout }
