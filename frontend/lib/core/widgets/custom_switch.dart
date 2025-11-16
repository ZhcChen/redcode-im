import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// 自定义开关控件
///
/// 样式：
/// - 整体胶囊容器：宽50，高22
/// - 开关圆点：上下居中，左右间距4，宽高14，白色背景
/// - 开：胶囊背景色为主色调，圆点在右侧
/// - 关：背景色为#D0D1DB，圆点在左侧
/// - 开关时圆点移动有过渡动画
class CustomSwitch extends StatelessWidget {
  const CustomSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 50,
        height: 22,
        decoration: BoxDecoration(
          color: value ? AppColors.primary : const Color(0xFFD0D1DB),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              left: value ? 50 - 14 - 4 : 4, // 右侧：总宽度 - 圆点宽度 - 右边距，左侧：左边距
              top: (22 - 14) / 2, // 上下居中
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
