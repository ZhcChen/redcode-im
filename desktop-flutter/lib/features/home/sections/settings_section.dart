import 'package:flutter/material.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 260,
          color: Colors.white,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: const [
              _SettingsCategory(title: '通用设置', isActive: true),
              _SettingsCategory(title: '通知提醒'),
              _SettingsCategory(title: '音视频设备'),
              _SettingsCategory(title: '快捷键'),
              _SettingsCategory(title: '高级实验室'),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('通用设置', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 24),
                SwitchListTile.adaptive(
                  value: true,
                  onChanged: (_) {},
                  title: const Text('启动时自动登录'),
                  subtitle: const Text('打开应用时自动恢复上次登录状态。'),
                ),
                SwitchListTile.adaptive(
                  value: false,
                  onChanged: (_) {},
                  title: const Text('使用系统深色模式'),
                  subtitle: const Text('跟随系统深浅色切换，手动覆盖可在实验室设置。'),
                ),
                SwitchListTile.adaptive(
                  value: true,
                  onChanged: (_) {},
                  title: const Text('窗口关闭最小化至托盘'),
                  subtitle: const Text('关闭按钮仅最小化，完全退出请在托盘菜单中选择退出。'),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.refresh),
                  label: const Text('重置设置'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsCategory extends StatelessWidget {
  const _SettingsCategory({required this.title, this.isActive = false});

  final String title;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: isActive ? theme.colorScheme.primary.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: isActive ? theme.colorScheme.primary : Colors.grey[800],
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
