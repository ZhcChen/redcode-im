import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class ImAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ImAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.centerTitle = true,
    this.dense = false,
    this.backgroundColor,
  });

  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final bool dense;
  final Color? backgroundColor;

  @override
  Size get preferredSize => Size.fromHeight(
    dense ? AppControlSize.denseAppBar : AppControlSize.appBar,
  );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: preferredSize.height,
      backgroundColor: backgroundColor,
      centerTitle: centerTitle,
      leading: leading,
      leadingWidth: AppControlSize.appBar,
      titleSpacing: AppSpacing.md,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: actions,
    );
  }
}
