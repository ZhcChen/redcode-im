import 'package:desktop_flutter/state/home_state.dart';
import 'package:flutter/material.dart';

typedef SectionCallback = void Function(HomeSection section);

class SideMenu extends StatelessWidget {
  const SideMenu({
    super.key,
    required this.currentSection,
    required this.onSectionSelected,
    required this.onLogout,
  });

  final HomeSection currentSection;
  final SectionCallback onSectionSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: Colors.white,
      child: Column(
        children: [
          const _SideMenuHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: HomeSection.values.map((section) {
                final isActive = section == currentSection;
                return _SideMenuItem(
                  section: section,
                  isActive: isActive,
                  onTap: () => onSectionSelected(section),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          _SideMenuAction(
            icon: Icons.logout_rounded,
            label: '退出登录',
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _SideMenuHeader extends StatelessWidget {
  const _SideMenuHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      alignment: Alignment.centerLeft,
      child: Text(
        'Redcode IM',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SideMenuItem extends StatelessWidget {
  const _SideMenuItem({
    required this.section,
    required this.isActive,
    required this.onTap,
  });

  final HomeSection section;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: isActive ? theme.colorScheme.primary.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  section.icon,
                  color: isActive ? theme.colorScheme.primary : Colors.grey[700],
                ),
                const SizedBox(width: 12),
                Text(
                  section.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isActive ? theme.colorScheme.primary : Colors.grey[800],
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SideMenuAction extends StatelessWidget {
  const _SideMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: Colors.redAccent),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.redAccent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
