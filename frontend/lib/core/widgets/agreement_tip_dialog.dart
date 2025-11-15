import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// 协议提示弹窗组件
/// 迁移自 bear-chat-uniapp 的弹窗样式
class AgreementTipDialog extends StatelessWidget {
  /// 弹窗标题，默认为"提示"
  final String title;

  /// 弹窗内容文本
  final String content;

  /// 确认按钮文本，默认为"我知道了"
  final String confirmText;

  /// 确认按钮回调
  final VoidCallback? onConfirm;

  const AgreementTipDialog({
    super.key,
    this.title = '提示',
    required this.content,
    this.confirmText = '我知道了',
    this.onConfirm,
  });

  /// 显示弹窗的静态方法
  static Future<void> show(
    BuildContext context, {
    String title = '提示',
    required String content,
    String confirmText = '我知道了',
    VoidCallback? onConfirm,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AgreementTipDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        onConfirm: onConfirm ?? () => Navigator.of(context).pop(),
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
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textBlack,
              ),
            ),
            const SizedBox(height: 20),
            // 内容
            Text(
              content,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textBlack,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            // 确认按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton(
                  onPressed: onConfirm ?? () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    confirmText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
