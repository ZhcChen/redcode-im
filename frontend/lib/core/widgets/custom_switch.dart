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
  const CustomSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.loading = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isInteractive = onChanged != null && !loading;
    return GestureDetector(
      onTap: isInteractive ? () => onChanged?.call(!value) : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isInteractive ? 1 : 0.6,
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
                left: value ? 50 - 14 - 4 : 4,
                top: (22 - 14) / 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              if (loading)
                Positioned.fill(
                  child: Container(
                    alignment: Alignment.center,
                    color: Colors.black.withOpacity(0.05),
                    child: const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
