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
      await MessageService.instance.fetchChats();
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
      backgroundColor: const Color(0xFFF4F5F6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部标题区域
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: const Text(
                  '设置',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 用户卡片区域
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _UserCard(
                    user: _user,
                    onEditNickname: (_user != null && !_updatingNickname)
                        ? _editNickname
                        : null,
                    updatingNickname: _updatingNickname,
                  ),
                ),
              const SizedBox(height: 20),
              // 设置项列表卡片
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
              ),
              const SizedBox(height: 20),
              // 危险操作区域
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEECEB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _DangerZone(
                    onDeactivate: _deactivating ? null : _handleDeactivate,
                    onLogout: _logout,
                    deactivating: _deactivating,
                  ),
                ),
              ),
              const SizedBox(height: 32),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    AppAssets.loginLogo,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C2B3),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: SvgPicture.asset(
                      AppAssets.settingsEdit,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
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
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.2,
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
                            color: Color(0xFF00C2B3),
                          ),
                        )
                      else if (onEditNickname != null)
                        SvgPicture.asset(
                          AppAssets.settingsEditOutline,
                          width: 18,
                          colorFilter: const ColorFilter.mode(
                            AppColors.textSecondary,
                            BlendMode.srcIn,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '账号：$account',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F5F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    emailText,
                    style: const TextStyle(
                      fontSize: 13,
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
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(width: 24, height: 24, child: data.leading),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    data.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
                trailing,
              ],
            ),
            if (showDivider)
              Padding(
                padding: const EdgeInsets.only(top: 14, left: 38),
                child: Divider(
                  height: 1,
                  thickness: 0.5,
                  color: const Color(0xFFE9EBEF).withValues(alpha: 0.6),
                ),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onDeactivate == null
                  ? null
                  : () async => await onDeactivate!(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      AppAssets.settingsLogout,
                      width: 20,
                      height: 20,
                      colorFilter: const ColorFilter.mode(
                        AppColors.danger,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 8),
                    deactivating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.danger,
                            ),
                          )
                        : const Text(
                            '注销账号',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.danger,
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onLogout,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.danger.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      AppAssets.settingsLogout,
                      width: 20,
                      height: 20,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '退出登录',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
