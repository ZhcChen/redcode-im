import 'package:flutter/material.dart';

import '../../core/widgets/im_tab_bar.dart';

class MobileAppShell extends StatefulWidget {
  const MobileAppShell({
    super.key,
    required this.pages,
    this.initialIndex = 0,
    this.badgeCounts = const [0, 0, 0, 0],
    this.onSelected,
    this.onReselect,
  }) : assert(pages.length == 4),
       assert(badgeCounts.length == 4),
       assert(initialIndex >= 0 && initialIndex < 4);

  final List<Widget> pages;
  final int initialIndex;
  final List<int> badgeCounts;
  final ValueChanged<int>? onSelected;
  final ValueChanged<int>? onReselect;

  @override
  State<MobileAppShell> createState() => _MobileAppShellState();
}

class _MobileAppShellState extends State<MobileAppShell> {
  late int _index = widget.initialIndex;

  List<ImTabItem> get _items => [
    ImTabItem(
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
      label: '聊天',
      badgeCount: widget.badgeCounts[0],
    ),
    ImTabItem(
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      label: '联系人',
      badgeCount: widget.badgeCounts[1],
    ),
    ImTabItem(
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      label: '发现',
      badgeCount: widget.badgeCounts[2],
    ),
    ImTabItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: '我的',
      badgeCount: widget.badgeCounts[3],
    ),
  ];

  void _select(int index) {
    if (_index == index) {
      widget.onReselect?.call(index);
      return;
    }
    setState(() => _index = index);
    widget.onSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: widget.pages),
      bottomNavigationBar: ImTabBar(
        items: _items,
        currentIndex: _index,
        onSelected: _select,
      ),
    );
  }
}
