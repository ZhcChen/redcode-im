import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class QuietIconButton extends StatelessWidget {
  const QuietIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.iconSize = 22,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: AppControlSize.minTapTarget,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: iconSize),
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppControlSize.minTapTarget),
          maximumSize: const Size.square(AppControlSize.minTapTarget),
          padding: EdgeInsets.zero,
          foregroundColor: selected ? colors.primary : colors.onSurface,
          backgroundColor: selected
              ? colors.primaryContainer
              : Colors.transparent,
          disabledForegroundColor: colors.onSurface.withValues(alpha: 0.38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),
    );
  }
}
