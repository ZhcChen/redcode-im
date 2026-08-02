import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/avatar_color_utils.dart';
import '../../core/widgets/im_list_row.dart';
import '../../core/widgets/im_state_panel.dart';
import '../../core/widgets/im_surface.dart';
import '../auth/data/auth_repository.dart';
import '../auth/models/auth_user.dart';
import '../settings/about_page.dart';
import '../settings/account_security_page.dart';
import '../settings/privacy_policy_page.dart';
import '../settings/settings_page.dart';
import 'profile_page.dart';

typedef MineUserLoader = Future<AuthUser?> Function();

class MinePage extends StatefulWidget {
  const MinePage({super.key, this.loadUser});

  final MineUserLoader? loadUser;

  static Future<AuthUser?> _loadCurrentUser() async {
    final repository = AuthRepository();
    final cached = (await repository.loadSession())?.user;
    try {
      return await repository.refreshCurrentUser() ?? cached;
    } catch (_) {
      return cached;
    }
  }

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  AuthUser? _user;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await (widget.loadUser ?? MinePage._loadCurrentUser)();
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
        if (user == null) _error = const FormatException('未找到登录信息');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(
              height: AppControlSize.appBar,
              child: Center(
                child: Text(
                  '我的',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _user == null) {
      return ImStatePanel(
        icon: Icons.person_off_outlined,
        title: '无法加载个人信息',
        message: '请检查网络后重试',
        actionLabel: '重新加载',
        onAction: _load,
      );
    }

    final user = _user!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          ImSurface(
            padding: EdgeInsets.zero,
            child: ImListRow(
              key: const Key('mine-profile-entry'),
              contentPadding: const EdgeInsets.all(AppSpacing.md),
              leading: _MineAvatar(user: user),
              title: Text(
                user.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('@${user.username}'),
              trailing: const Icon(Icons.chevron_right),
              semanticLabel: '查看个人资料',
              onTap: () => _open(ProfilePage(user: user)),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _MineGroup(
            children: [
              _MineEntry(
                icon: Icons.security_outlined,
                title: '账号与安全',
                subtitle: '密码与账号状态',
                onTap: () => _open(const AccountSecurityPage()),
              ),
              _MineEntry(
                key: const Key('mine-settings-entry'),
                icon: Icons.settings_outlined,
                title: '设置',
                subtitle: '聊天、隐私与偏好',
                onTap: () => _open(const SettingsPage()),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _MineGroup(
            children: [
              _MineEntry(
                icon: Icons.shield_outlined,
                title: '隐私协议',
                subtitle: '协议与数据使用说明',
                onTap: () => _open(const PrivacyPolicyPage()),
              ),
              _MineEntry(
                icon: Icons.info_outline,
                title: '关于 RedCode IM',
                subtitle: '版本与反馈',
                onTap: () => _open(const AboutPage()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MineGroup extends StatelessWidget {
  const _MineGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ImSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _MineEntry extends StatelessWidget {
  const _MineEntry({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ImListRow(
      leading: SizedBox.square(
        dimension: 28,
        child: Icon(
          icon,
          size: 22,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
      semanticLabel: title,
    );
  }
}

class _MineAvatar extends StatelessWidget {
  const _MineAvatar({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    final localPath = user.localAvatarPath;
    Widget? image;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        image = Image.file(file, width: size, height: size, fit: BoxFit.cover);
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.control),
      child:
          image ??
          Container(
            width: size,
            height: size,
            color: AvatarColorUtils.generateBackgroundColor(user.id),
            alignment: Alignment.center,
            child: Text(
              AvatarColorUtils.getInitial(user.displayName),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
    );
  }
}
