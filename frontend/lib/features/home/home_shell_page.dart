import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../chat/chat_list_page.dart';
import '../contacts/contacts_page.dart';
import '../settings/settings_page.dart';

class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key});

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  int _index = 0;

  static const _items = [
    _NavItem(
      label: '聊天',
      icon: AppAssets.chatTab,
      activeIcon: AppAssets.chatTabSelected,
    ),
    _NavItem(
      label: '联系人',
      icon: AppAssets.contactTab,
      activeIcon: AppAssets.contactTabSelected,
    ),
    _NavItem(
      label: '设置',
      icon: AppAssets.settingsTab,
      activeIcon: AppAssets.settingsTabSelected,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _index,
        children: const [ChatListPage(), ContactsPage(), SettingsPage()],
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, -4),
            color: Color.fromRGBO(0, 0, 0, 0.06),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final selected = _index == i;
              return _NavButton(
                item: item,
                selected: selected,
                onTap: () => setState(() => _index = i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final String icon;
  final String activeIcon;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 28,
            width: 28,
            child: Image.asset(selected ? item.activeIcon : item.icon),
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: selected ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
