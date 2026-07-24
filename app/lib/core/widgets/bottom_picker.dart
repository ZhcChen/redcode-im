import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../constants/app_colors.dart';
import 'sheet_header.dart';

/// 底部选择弹窗选项
class BottomPickerOption {
  const BottomPickerOption({
    required this.label,
    this.icon,
    this.onTap,
    this.textColor,
    this.iconColor,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? textColor;
  final Color? iconColor;
}

/// 通用底部选择弹窗
class BottomPicker {
  /// 显示底部选择弹窗
  static void show({
    required BuildContext context,
    required String title,
    required List<BottomPickerOption> options,
    String? cancelText,
    VoidCallback? onCancel,
    bool enableCancel = true,
    bool isDestructive = false,
    int? cancelTextColor,
  }) {
    final textColor = isDestructive ? AppColors.danger : AppColors.textPrimary;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              SheetHeader(
                title: title,
                titleStyle: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                onClose: enableCancel
                    ? () {
                        Navigator.pop(sheetContext);
                        onCancel?.call();
                      }
                    : null,
              ),
              const SizedBox(height: 16),
              // 选项列表
              Column(
                children: options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  final isLast = index == options.length - 1;
                  final isDestructiveItem =
                      isDestructive && index == options.length - 1;

                  return Container(
                    margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(sheetContext);
                          option.onTap?.call();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: isDestructiveItem
                                ? AppColors.danger.withValues(alpha: 0.08)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                if (option.icon != null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Icon(
                                      option.icon,
                                      size: 20,
                                      color:
                                          option.iconColor ??
                                          (isDestructiveItem
                                              ? AppColors.danger
                                              : AppColors.textSecondary),
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    option.label,
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w400,
                                      color:
                                          option.textColor ??
                                          (isDestructiveItem
                                              ? AppColors.danger
                                              : textColor),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (enableCancel) ...[
                const SizedBox(height: 8),
                // 取消按钮
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      onCancel?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      cancelText ?? '取消',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
