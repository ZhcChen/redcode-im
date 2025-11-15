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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFE5E6EB),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBlack,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // 内容区域（可滚动）
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Html(
                  data: htmlContent,
                  style: {
                    'body': Style(
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                      fontSize: const FontSize(14),
                      lineHeight: const LineHeight(1.6),
                      color: AppColors.textBlack,
                    ),
                    'p': Style(
                      margin: Margins.only(bottom: 12),
                    ),
                    'h1': Style(
                      fontSize: const FontSize(20),
                      fontWeight: FontWeight.w600,
                      margin: Margins.only(bottom: 16),
                    ),
                    'h2': Style(
                      fontSize: const FontSize(18),
                      fontWeight: FontWeight.w600,
                      margin: Margins.only(bottom: 14),
                    ),
                    'h3': Style(
                      fontSize: const FontSize(16),
                      fontWeight: FontWeight.w600,
                      margin: Margins.only(bottom: 12),
                    ),
                  },
                ),
              ),
            ),
            // 底部按钮
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Color(0xFFE5E6EB),
                    width: 1,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '我知道了',
                    style: TextStyle(
                      fontSize: 16,
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

