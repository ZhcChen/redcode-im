import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// 通用角标组件
/// - 可自定义尺寸、字体、背景色/文字色
/// - 当为一位数字（<10）时保证为正圆
/// - 支持 `count`（自动处理 99+）或直接传入 `text`
class AppBadge extends StatelessWidget {
  AppBadge({
    super.key,
    this.count,
    this.text,
    this.size = 18,
    this.fontSize = 11,
    // 默认使用主题色；仅底部 Tab 角标使用红色（在调用处覆盖）
    this.backgroundColor = AppColors.primary,
    this.textColor = Colors.white,
    this.padding,
    this.bold = true,
  }) : assert(count != null || text != null, 'count 与 text 至少提供一个');

  /// 数值角标（>99 显示 99+）
  final int? count;

  /// 自定义文本角标（优先级低于 count）
  final String? text;

  /// 基础尺寸（高度），一位数时宽度==高度，保证圆形
  final double size;

  /// 字体大小
  final double fontSize;

  /// 背景色
  final Color backgroundColor;

  /// 文字颜色
  final Color textColor;

  /// 多位数时的水平内边距（不传则使用默认 6）
  final EdgeInsets? padding;

  /// 是否加粗
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final label = _label;
    final isSingleChar = label.length == 1;

    final resolvedPadding = isSingleChar
        ? EdgeInsets.zero
        : (padding ?? const EdgeInsets.symmetric(horizontal: 6));

    final minWidth = size;
    final height = size;

    return Container(
      constraints: BoxConstraints(minWidth: minWidth, minHeight: height),
      height: height,
      padding: resolvedPadding,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          color: textColor,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          height: 1.0,
        ),
      ),
    );
  }

  String get _label {
    if (count != null) {
      if (count! > 99) return '99+';
      return count!.toString();
    }
    return text!;
  }
}
