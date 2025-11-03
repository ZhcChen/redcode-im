import 'package:desktop_flutter/state/app_state.dart';
import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.user});

  final UserProfile? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              _initials,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user?.displayName ?? '未登录',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  user?.mobile ?? '请通过登录完成身份验证',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 280,
            child: TextField(
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: '搜索会话、联系人或功能',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _initials {
    final name = user?.displayName ?? '';
    if (name.isEmpty) return '访客';
    final runes = name.runes.take(2).toList();
    return String.fromCharCodes(runes);
  }
}
