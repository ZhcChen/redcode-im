import 'package:flutter/material.dart';

class PrivacySection extends StatelessWidget {
  const PrivacySection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('隐私与安全', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(
            '管理消息可见性、数据留存策略以及多设备登录提醒，保持账号安全。',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: const [
                _PrivacySettingCard(
                  title: '新设备登录提醒',
                  description: '当账号在新的桌面或移动设备登录时，通过应用内和短信发送提醒。',
                  enabled: true,
                ),
                _PrivacySettingCard(
                  title: '自动销毁敏感消息',
                  description: '针对私密会话开启阅后即焚，消息在 30 分钟后自动删除。',
                ),
                _PrivacySettingCard(
                  title: '好友验证',
                  description: '开启后添加好友需要验证问题或后台审核，减少骚扰信息。',
                  enabled: true,
                ),
                _PrivacySettingCard(
                  title: '数据导出',
                  description: '定期导出聊天记录与文件，方便备份归档。',
                  actionLabel: '立即导出',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacySettingCard extends StatelessWidget {
  const _PrivacySettingCard({
    required this.title,
    required this.description,
    this.enabled = false,
    this.actionLabel,
  });

  final String title;
  final String description;
  final bool enabled;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(width: 12),
                      if (enabled)
                        Chip(
                          label: const Text('已启用'),
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (actionLabel != null)
              FilledButton.tonal(
                onPressed: () {},
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}
