import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../constants/app_colors.dart';

/// 协议内容弹窗组件
/// 用于显示用户协议和隐私协议的详细内容（HTML格式）
class AgreementContentDialog extends StatelessWidget {
  /// 弹窗标题
  final String title;

  /// HTML 格式的协议内容
  final String htmlContent;

  const AgreementContentDialog({
    super.key,
    required this.title,
    required this.htmlContent,
  });

  /// 显示协议内容弹窗的静态方法
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String htmlContent,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AgreementContentDialog(
        title: title,
        htmlContent: htmlContent,
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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
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
            // 内容区域（可滚动）
            Flexible(
              child: SingleChildScrollView(
                child: Html(
                  data: htmlContent,
                  style: {
                    'body': Style(
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                      fontSize: FontSize(13),
                      lineHeight: LineHeight(1.5),
                      color: AppColors.textBlack,
                    ),
                    'p': Style(
                      margin: Margins.only(bottom: 12),
                    ),
                    'h1': Style(
                      fontSize: FontSize(16),
                      fontWeight: FontWeight.w600,
                      margin: Margins.only(bottom: 12),
                    ),
                    'h2': Style(
                      fontSize: FontSize(15),
                      fontWeight: FontWeight.w600,
                      margin: Margins.only(bottom: 10),
                    ),
                    'h3': Style(
                      fontSize: FontSize(14),
                      fontWeight: FontWeight.w600,
                      margin: Margins.only(bottom: 8),
                    ),
                  },
                ),
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
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    '我知道了',
                    style: TextStyle(
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

