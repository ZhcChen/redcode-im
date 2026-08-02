import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/design_tokens.dart';
import 'app_badge.dart';

class ImTabItem {
  const ImTabItem({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final int badgeCount;
}

class ImTabBar extends StatelessWidget {
  const ImTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  }) : assert(items.length >= 2),
       assert(currentIndex >= 0 && currentIndex < items.length);

  final List<ImTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaledLabelHeight = MediaQuery.textScalerOf(context).scale(12);
    final barHeight =
        AppControlSize.bottomBar +
        (scaledLabelHeight - 12).clamp(0, double.infinity);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: barHeight,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = index == currentIndex;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: item.badgeCount > 0
                      ? '${item.label}，${item.badgeCount} 条未读'
                      : item.label,
                  child: InkWell(
                    onTap: () => onSelected(index),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: AppControlSize.minTapTarget,
                          minHeight: AppControlSize.minTapTarget,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xxs,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 44,
                                height: 30,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    AnimatedContainer(
                                      duration: AppMotion.resolve(
                                        context,
                                        AppMotion.fast,
                                      ),
                                      width: 36,
                                      height: 30,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? theme.colorScheme.primaryContainer
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.control,
                                        ),
                                      ),
                                      child: Icon(
                                        selected
                                            ? item.selectedIcon ?? item.icon
                                            : item.icon,
                                        size: AppControlSize.navigationIcon,
                                        color: selected
                                            ? theme.colorScheme.primary
                                            : theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                      ),
                                    ),
                                    if (item.badgeCount > 0)
                                      Positioned(
                                        right: -2,
                                        top: -4,
                                        child: AppBadge(
                                          count: item.badgeCount,
                                          size: 16,
                                          fontSize: 10,
                                          backgroundColor: AppColors.danger,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
