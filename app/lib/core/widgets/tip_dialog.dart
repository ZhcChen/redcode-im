import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// 通用提示弹窗组件
/// 迁移自 bear-chat-uniapp 的弹窗样式，支持确认/取消按钮
class TipDialog extends StatelessWidget {
  /// 弹窗标题
  final String? title;

  /// 弹窗内容（文本）
  final String? content;

  /// 弹窗内容（Widget，优先级高于 content）
  final Widget? contentWidget;

  /// 确认按钮文本，默认为"确定"
  final String confirmText;

  /// 取消按钮文本，如果为 null 则不显示取消按钮
  final String? cancelText;

  /// 确认按钮回调，返回 true 表示确认，false 表示取消
  final Future<bool> Function()? onConfirm;

  /// 取消按钮回调
  final VoidCallback? onCancel;

  /// 确认按钮是否为危险操作（红色）
  final bool confirmDanger;

  /// 是否允许点击外部关闭
  final bool barrierDismissible;

  const TipDialog({
    super.key,
    this.title,
    this.content,
    this.contentWidget,
    this.confirmText = '确定',
    this.cancelText,
    this.onConfirm,
    this.onCancel,
    this.confirmDanger = false,
    this.barrierDismissible = true,
  }) : assert(
         content != null || contentWidget != null,
         'content 或 contentWidget 必须提供一个',
       );

  /// 显示确认对话框（只有确认按钮）
  static Future<void> show(
    BuildContext context, {
    String? title,
    String? content,
    Widget? contentWidget,
    String confirmText = '我知道了',
    VoidCallback? onConfirm,
    bool barrierDismissible = true,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => TipDialog(
        title: title,
        content: content,
        contentWidget: contentWidget,
        confirmText: confirmText,
        cancelText: null,
        onConfirm: onConfirm != null
            ? () async {
                onConfirm();
                return true;
              }
            : null,
        barrierDismissible: barrierDismissible,
      ),
    );
  }

  /// 显示确认/取消对话框
  static Future<bool?> showConfirm(
    BuildContext context, {
    String? title,
    String? content,
    Widget? contentWidget,
    String confirmText = '确定',
    String cancelText = '取消',
    Future<bool> Function()? onConfirm,
    VoidCallback? onCancel,
    bool confirmDanger = false,
    bool barrierDismissible = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => TipDialog(
        title: title,
        content: content,
        contentWidget: contentWidget,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
        onCancel: onCancel,
        confirmDanger: confirmDanger,
        barrierDismissible: barrierDismissible,
      ),
    );
  }

  /// 显示确认/取消对话框，支持返回自定义值
  static Future<T?> showConfirmWithResult<T>(
    BuildContext context, {
    String? title,
    String? content,
    Widget? contentWidget,
    String confirmText = '确定',
    String cancelText = '取消',
    Future<T?> Function()? onConfirm,
    VoidCallback? onCancel,
    bool confirmDanger = false,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => _TipDialogWithResult<T>(
        title: title,
        content: content,
        contentWidget: contentWidget,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
        onCancel: onCancel,
        confirmDanger: confirmDanger,
        barrierDismissible: barrierDismissible,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xFFE7FFF7), Colors.white],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            if (title != null) ...[
              Text(
                title!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textBlack,
                ),
              ),
              const SizedBox(height: 20),
            ],
            // 内容
            if (contentWidget != null)
              contentWidget!
            else if (content != null)
              Text(
                content!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textBlack,
                  height: 1.5,
                ),
              ),
            const SizedBox(height: 16),
            // 按钮区域
            if (cancelText != null)
              Row(
                children: [
                  Expanded(child: _buildCancelButton(context)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildConfirmButton(context)),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildConfirmButton(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelButton(BuildContext context) {
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: () {
          if (onCancel != null) {
            onCancel!();
          }
          Navigator.of(context).pop(false);
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textBlack,
          side: const BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          cancelText ?? '取消',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    return SizedBox(
      width: cancelText == null ? double.infinity : null,
      height: 40,
      child: ElevatedButton(
        onPressed: () async {
          if (onConfirm != null) {
            final result = await onConfirm!();
            if (context.mounted && result) {
              Navigator.of(context).pop(true);
            }
          } else {
            Navigator.of(context).pop(true);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: confirmDanger ? Colors.red : AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
        child: Text(
          confirmText,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

/// 支持返回自定义值的 TipDialog
class _TipDialogWithResult<T> extends StatelessWidget {
  final String? title;
  final String? content;
  final Widget? contentWidget;
  final String confirmText;
  final String? cancelText;
  final Future<T?> Function()? onConfirm;
  final VoidCallback? onCancel;
  final bool confirmDanger;
  final bool barrierDismissible;

  const _TipDialogWithResult({
    this.title,
    this.content,
    this.contentWidget,
    this.confirmText = '确定',
    this.cancelText,
    this.onConfirm,
    this.onCancel,
    this.confirmDanger = false,
    this.barrierDismissible = true,
  }) : assert(
         content != null || contentWidget != null,
         'content 或 contentWidget 必须提供一个',
       );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xFFE7FFF7), Colors.white],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textBlack,
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (contentWidget != null)
              contentWidget!
            else if (content != null)
              Text(
                content!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textBlack,
                  height: 1.5,
                ),
              ),
            const SizedBox(height: 16),
            if (cancelText != null)
              Row(
                children: [
                  Expanded(child: _buildCancelButton(context)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildConfirmButton(context)),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildConfirmButton(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelButton(BuildContext context) {
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: () {
          if (onCancel != null) {
            onCancel!();
          }
          Navigator.of(context).pop(null);
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textBlack,
          side: const BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          cancelText ?? '取消',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    return SizedBox(
      width: cancelText == null ? double.infinity : null,
      height: 40,
      child: ElevatedButton(
        onPressed: () async {
          if (onConfirm != null) {
            final result = await onConfirm!();
            if (context.mounted) {
              Navigator.of(context).pop(result);
            }
          } else {
            Navigator.of(context).pop(null);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: confirmDanger ? Colors.red : AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
        child: Text(
          confirmText,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
