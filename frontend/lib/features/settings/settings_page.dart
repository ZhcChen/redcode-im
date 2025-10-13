import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: const [
          _SettingTile(title: '账号与安全', subtitle: '手机号、密码、设备管理'),
          _SettingTile(title: '通知管理', subtitle: '消息通知、提示音'),
          _SettingTile(title: '隐私与通用', subtitle: '朋友圈、好友可见设置'),
          _SettingTile(title: '关于应用', subtitle: '版本信息、帮助反馈'),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textTertiary,
        ),
        onTap: () {},
      ),
    );
  }
}
