import 'package:flutter/material.dart';

/// 头像颜色工具类
/// 用于生成一致的头像背景色，与桌面端 (TypeScript) 保持完全一致
class AvatarColorUtils {
  AvatarColorUtils._();

  /// 预设的柔和色调（与桌面端保持一致）
  static const List<Color> avatarColors = [
    Color(0xFF6366f1), // 靛蓝
    Color(0xFF8b5cf6), // 紫色
    Color(0xFFec4899), // 粉红
    Color(0xFFf43f5e), // 玫瑰
    Color(0xFFf59e0b), // 琥珀
    Color(0xFF10b981), // 翠绿
    Color(0xFF06b6d4), // 青色
    Color(0xFF3b82f6), // 蓝色
    Color(0xFF6366f1), // 靛蓝
    Color(0xFFa855f7), // 紫罗兰
  ];

  /// 字符串哈希函数
  ///
  /// 模拟 JavaScript 的 32 位有符号整数溢出行为，确保与桌面端计算结果一致
  static int _computeHashCode(String str) {
    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      int char = str.codeUnitAt(i);
      hash = ((hash << 5) - hash) + char;
      // 模拟 JavaScript 的 32 位有符号整数溢出
      // JavaScript 的位运算会将结果截断为 32 位有符号整数
      hash = (hash & 0xFFFFFFFF).toSigned(32);
    }
    return hash.abs();
  }

  /// 根据文本生成背景色
  ///
  /// 与桌面端 Avatar.vue 的 generateBackgroundColor 逻辑完全一致
  static Color generateBackgroundColor(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const Color(0xFFF0F0F0);

    final hash = _computeHashCode(trimmed);
    return avatarColors[hash % avatarColors.length];
  }

  /// 获取首字/首字母
  static String getInitial(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '?';

    final firstChar = trimmed[0];
    // 如果是英文字母，转大写
    if (RegExp(r'^[a-zA-Z]$').hasMatch(firstChar)) {
      return firstChar.toUpperCase();
    }
    // 其他字符（中文等）直接返回
    return firstChar;
  }
}
