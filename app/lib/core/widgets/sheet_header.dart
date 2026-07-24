import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// 统一的弹层标题栏，确保标题在有右侧关闭按钮时仍保持几何中心。
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.title,
    this.titleStyle,
    this.onClose,
  });

  static const double _actionExtent = 40;

  final String title;
  final TextStyle? titleStyle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final effectiveTitleStyle =
        titleStyle ??
        const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        );

    return SizedBox(
      height: _actionExtent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: onClose == null ? 0 : _actionExtent + 8,
              right: onClose == null ? 0 : _actionExtent + 8,
            ),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: effectiveTitleStyle,
              textAlign: TextAlign.center,
            ),
          ),
          if (onClose != null)
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: _actionExtent,
                height: _actionExtent,
                child: IconButton(
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: _actionExtent,
                    height: _actionExtent,
                  ),
                  icon: const Icon(
                    Icons.close,
                    size: 24,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
