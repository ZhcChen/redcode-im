import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/im_app_bar.dart';
import '../../core/widgets/im_list_row.dart';
import '../../core/widgets/im_surface.dart';
import '../auth/models/auth_user.dart';
import 'profile_edit_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.user});

  final AuthUser user;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late AuthUser _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<AuthUser>(
      MaterialPageRoute(builder: (_) => ProfileEditPage(user: _user)),
    );
    if (updated != null && mounted) setState(() => _user = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ImAppBar(
        title: '个人资料',
        dense: true,
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          TextButton(
            key: const Key('profile-edit-entry'),
            onPressed: _edit,
            child: const Text('编辑'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            ImSurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _ProfileRow(label: '昵称', value: _user.displayName),
                  const Divider(height: 1, indent: AppSpacing.md),
                  _ProfileRow(label: '用户名', value: _user.username),
                  const Divider(height: 1, indent: AppSpacing.md),
                  _ProfileRow(label: '邮箱', value: _user.email ?? '未绑定'),
                  const Divider(height: 1, indent: AppSpacing.md),
                  _ProfileRow(
                    label: '账号状态',
                    value: _user.status == 'active'
                        ? '正常'
                        : (_user.status ?? '未知'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ImListRow(
      title: Text(label),
      trailing: Flexible(
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
