import 'package:flutter/material.dart';

class ContactSection extends StatelessWidget {
  const ContactSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('联系人', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: '搜索或添加联系人',
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 4 / 3,
              children: _contacts
                  .map(
                    (contact) => Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: theme.colorScheme.primaryContainer,
                              child: Text(contact.name.substring(0, 1)),
                            ),
                            const Spacer(),
                            Text(contact.name, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              contact.note,
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            FilledButton.tonal(
                              onPressed: () {},
                              child: const Text('开始会话'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard {
  const _ContactCard(this.name, this.note);
  final String name;
  final String note;
}

const _contacts = <_ContactCard>[
  _ContactCard('张三', '项目经理 · Redcode'),
  _ContactCard('李四', '后端开发 · 微服务'),
  _ContactCard('王五', '设计师 · 桌面端规范'),
  _ContactCard('赵六', '测试工程师 · 自动化'),
  _ContactCard('产品群', '需求讨论群组'),
  _ContactCard('桌面端专项', '跨平台 Flutter 迁移'),
];
