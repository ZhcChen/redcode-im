import 'package:flutter/material.dart';

class DesktopAppShell extends StatefulWidget {
  const DesktopAppShell({super.key, required this.pages, this.initialIndex = 0})
    : assert(pages.length == 4),
      assert(initialIndex >= 0 && initialIndex < 4);

  final List<Widget> pages;
  final int initialIndex;

  @override
  State<DesktopAppShell> createState() => _DesktopAppShellState();
}

class _DesktopAppShellState extends State<DesktopAppShell> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            labelType: NavigationRailLabelType.all,
            backgroundColor: colors.surface,
            onDestinationSelected: (index) => setState(() => _index = index),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: Text('聊天'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('联系人'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: Text('发现'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: Text('我的'),
              ),
            ],
          ),
          VerticalDivider(width: 1, color: colors.outlineVariant),
          Expanded(
            child: IndexedStack(index: _index, children: widget.pages),
          ),
        ],
      ),
    );
  }
}
