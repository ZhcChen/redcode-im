import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/message_service.dart';
import '../auth/data/auth_repository.dart';
import '../auth/login_page.dart';
import '../auth/models/auth_user.dart';
import 'account_security_page.dart';
import 'feedback_page.dart';
import 'privacy_policy_page.dart';
import 'widgets/confirm_action_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthRepository _authRepository = AuthRepository();
  AuthUser? _user;
  bool _loading = true;
  bool _deactivating = false;
  bool _updatingNickname = false;
  bool _clearingCache = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _editNickname() async {
    if (_user == null || _updatingNickname) {
      return;
    }

    final initialName = _user!.displayName;
    final controller = TextEditingController(text: initialName);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('修改昵称'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              maxLength: 20,
              decoration: const InputDecoration(
                hintText: '请输入新的昵称',
                counterText: '',
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return '昵称不能为空';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) {
                  return;
                }
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null) {
      return;
    }
    final newName = result.trim();
    if (newName.isEmpty || newName == initialName) {
      return;
    }

    setState(() => _updatingNickname = true);
    try {
      final updated = await _authRepository.updateProfile(nickname: newName);
      if (!mounted) {
        return;
      }
      setState(() => _user = updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('昵称已更新')));
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('昵称更新失败，请稍后重试')));
    } finally {
      if (mounted) {
        setState(() => _updatingNickname = false);
      } else {
        _updatingNickname = false;
      }
    }
  }

  Future<void> _loadUser() async {
    final cached = await _authRepository.loadSession();
    if (mounted) {
      setState(() {
        _user = cached?.user;
        _loading = false;
      });
    }

    try {
      final refreshed = await _authRepository.refreshCurrentUser();
      if (!mounted || refreshed == null) {
        return;
      }
      setState(() => _user = refreshed);
    } catch (_) {}
  }

  Future<void> _logout() async {
    await _authRepository.logout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _handleDeactivate() async {
    if (_deactivating) return;

    final firstConfirm = await showConfirmActionDialog(
      context,
      title: '确认注销账号',
      message: '账号注销后将无法恢复，好友与聊天数据将被清空，确定继续吗？',
      confirmLabel: '继续',
    );
    if (!mounted) return;
    if (firstConfirm != true) return;

    final secondConfirm = await showConfirmActionDialog(
      context,
      title: '最终确认',
      message: '请输入 “注销” 以确认注销账号。',
      confirmLabel: '确认注销',
      confirmationKeyword: '注销',
    );
    if (!mounted) return;
    if (secondConfirm != true) return;

    setState(() => _deactivating = true);
    try {
      await _authRepository.deactivateAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('账号已注销')));
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _deactivating = false);
      } else {
        _deactivating = false;
      }
    }
  }

  void _openAccountSecurity() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AccountSecurityPage(user: _user)));
  }

  void _openPrivacyPolicy() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()));
  }

  Future<void> _openFeedback() async {
    final submitted = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const FeedbackPage()));
    if (submitted == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('反馈已提交，我们会尽快处理')));
    }
  }

  Future<void> _clearLocalCache() async {
    if (_clearingCache) return;

    final confirm = await showConfirmActionDialog(
      context,
      title: '清除缓存',
      message: '将删除本地聊天记录缓存数据，确认继续？',
      confirmLabel: '清除',
    );
    if (!mounted || confirm != true) {
      return;
    }

    setState(() => _clearingCache = true);
    try {
      await MessageService.instance.clearAll();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('缓存已清除')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('清除缓存失败：$error')));
    } finally {
      if (mounted) {
        setState(() => _clearingCache = false);
      } else {
        _clearingCache = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = <_SettingItemData>[
      _SettingItemData(
        title: '账号与安全',
        leading: Image.asset(
          AppAssets.settingsAccountSafe,
          width: 24,
          height: 24,
        ),
        onTap: () async => _openAccountSecurity(),
      ),
      _SettingItemData(
        title: '隐私政策',
        leading: Image.asset(AppAssets.settingsPrivacy, width: 24, height: 24),
        onTap: () async => _openPrivacyPolicy(),
      ),
      _SettingItemData(
        title: '意见反馈',
        leading: Image.asset(AppAssets.settingsFeedback, width: 24, height: 24),
        onTap: _openFeedback,
      ),
      _SettingItemData(
        title: '清除聊天缓存',
        leading: const Icon(
          Icons.cleaning_services_outlined,
          size: 24,
          color: AppColors.textPrimary,
        ),
        onTap: _clearingCache ? null : _clearLocalCache,
        trailingBuilder: (_) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            );
          },
          child: _clearingCache
              ? SizedBox(
                  key: const ValueKey('clearing-cache'),
                  width: 18,
                  height: 18,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : const Icon(
                  Icons.chevron_right,
                  key: ValueKey('cache-chevron'),
                  color: AppColors.textQuaternary,
                ),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '设置',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                _UserCard(
                  user: _user,
                  onEditNickname: (_user != null && !_updatingNickname)
                      ? _editNickname
                      : null,
                  updatingNickname: _updatingNickname,
                ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      _SettingListTile(
                        data: items[i],
                        showDivider: i != items.length - 1,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _DangerZone(
                onDeactivate: _deactivating ? null : _handleDeactivate,
                onLogout: _logout,
                deactivating: _deactivating,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    this.user,
    this.onEditNickname,
    this.updatingNickname = false,
  });

  final AuthUser? user;
  final VoidCallback? onEditNickname;
  final bool updatingNickname;

  @override
  Widget build(BuildContext context) {
    final displayName = user?.displayName ?? '未命名用户';
    final username = user?.username ?? '';
    final account = username.isNotEmpty ? username : '未绑定';
    final emailText = user?.email != null && user!.email!.isNotEmpty
        ? '邮箱：${user!.email}'
        : '邮箱：未绑定';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  AppAssets.loginLogo,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: SvgPicture.asset(AppAssets.settingsEdit),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: updatingNickname ? null : onEditNickname,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (updatingNickname)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      else if (onEditNickname != null)
                        SvgPicture.asset(
                          AppAssets.settingsEditOutline,
                          width: 16,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '账号：$account',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    emailText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingListTile extends StatelessWidget {
  const _SettingListTile({required this.data, required this.showDivider});

  final _SettingItemData data;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final trailing =
        data.trailingBuilder?.call(context) ??
        const Icon(Icons.chevron_right, color: AppColors.textQuaternary);

    return InkWell(
      onTap: data.onTap == null ? null : () async => await data.onTap!.call(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(width: 24, height: 24, child: data.leading),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    data.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                trailing,
              ],
            ),
            if (showDivider)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Divider(height: 1, color: Color(0xFFE9EBEF)),
              ),
          ],
        ),
      ),
    );
  }
}

class _DangerZone extends StatelessWidget {
  const _DangerZone({
    required this.onDeactivate,
    required this.onLogout,
    required this.deactivating,
  });

  final Future<void> Function()? onDeactivate;
  final VoidCallback onLogout;
  final bool deactivating;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      OutlinedButton.icon(
        onPressed: onDeactivate == null
            ? null
            : () async => await onDeactivate!(),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: const BorderSide(color: AppColors.danger),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: Colors.white,
        ),
        icon: SvgPicture.asset(
          AppAssets.settingsLogout,
          width: 20,
          height: 20,
          colorFilter: const ColorFilter.mode(
            AppColors.danger,
            BlendMode.srcIn,
          ),
        ),
        label: deactivating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.danger,
                ),
              )
            : const Text(
                '注销账号',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
      OutlinedButton.icon(
        onPressed: onLogout,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: const BorderSide(color: AppColors.danger),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: Colors.white,
        ),
        icon: SvgPicture.asset(
          AppAssets.settingsLogout,
          width: 20,
          height: 20,
          colorFilter: const ColorFilter.mode(
            AppColors.danger,
            BlendMode.srcIn,
          ),
        ),
        label: const Text(
          '退出登录',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    ];

    return Column(
      children: List.generate(actions.length, (index) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == actions.length - 1 ? 0 : 12,
          ),
          child: actions[index],
        );
      }),
    );
  }
}

class _SettingItemData {
  const _SettingItemData({
    required this.title,
    required this.leading,
    this.onTap,
    this.trailingBuilder,
  });

  final String title;
  final Widget leading;
  final Future<void> Function()? onTap;
  final Widget Function(BuildContext context)? trailingBuilder;
}
