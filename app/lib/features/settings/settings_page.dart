import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/user_avatar_service.dart';
import '../../core/utils/avatar_color_utils.dart';
import '../../core/widgets/input_dialog.dart';
import '../auth/data/auth_repository.dart';
import '../auth/login_page.dart';
import '../auth/models/auth_user.dart';
import 'about_page.dart';
import 'account_security_page.dart';
import 'chat_settings_page.dart';
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
  bool _uploadingAvatar = false;

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
    final result = await InputDialog.show(
      context,
      title: '修改昵称',
      hintText: '请输入新的昵称',
      initialValue: initialName,
      maxLength: 20,
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (trimmed.isEmpty) {
          return '昵称不能为空';
        }
        return null;
      },
    );

    if (result == null || !mounted) {
      return;
    }
    final newName = result.trim();
    if (newName.isEmpty || newName == initialName) {
      return;
    }

    // 等待对话框完全关闭后再执行更新操作
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) {
      return;
    }

    if (!mounted) return;
    setState(() => _updatingNickname = true);

    try {
      final updated = await _authRepository.updateProfile(nickname: newName);
      if (!mounted) {
        return;
      }
      // 使用 SchedulerBinding 确保在下一帧更新 UI
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _user = updated;
          _updatingNickname = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('昵称已更新')));
        }
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _updatingNickname = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      });
    } catch (e) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _updatingNickname = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('昵称更新失败：${e.toString()}')));
      });
    }
  }

  Future<void> _handleEditAvatar() async {
    if (_uploadingAvatar) return;

    final picker = ImagePicker();
    XFile? pickedFile;
    try {
      pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('打开相册失败: $error')));
      return;
    }

    if (pickedFile == null) {
      return;
    }

    final file = File(pickedFile.path);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未找到所选文件')));
      return;
    }

    setState(() => _uploadingAvatar = true);
    try {
      final updatedUser = await _authRepository.uploadAvatar(file);
      if (!mounted) return;
      setState(() => _user = updatedUser);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('头像已更新')));
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('头像更新失败: $error')));
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
      } else {
        _uploadingAvatar = false;
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
      message: '请输入 "注销" 以确认注销账号。',
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
    ).push(MaterialPageRoute(builder: (_) => const AccountSecurityPage()));
  }

  void _openPrivacyPolicy() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()));
  }

  void _openChatSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChatSettingsPage()));
  }

  Future<void> _openAbout() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AboutPage()));
  }

  @override
  Widget build(BuildContext context) {
    final items = <_SettingItemData>[
      _SettingItemData(
        title: '账号与安全',
        onTap: () async => _openAccountSecurity(),
      ),
      _SettingItemData(title: '隐私协议', onTap: () async => _openPrivacyPolicy()),
      _SettingItemData(title: '聊天', onTap: () async => _openChatSettings()),
      _SettingItemData(title: '关于Chatly', onTap: _openAbout),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 导航栏
            Container(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              color: AppColors.background,
              child: const Center(
                child: Text(
                  '设置',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textBlack,
                    letterSpacing: 0,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            // 主内容区域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // 用户信息区域
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      _UserInfoSection(
                        user: _user,
                        onEditNickname: (_user != null && !_updatingNickname)
                            ? _editNickname
                            : null,
                        updatingNickname: _updatingNickname,
                        onEditAvatar: (_user != null && !_uploadingAvatar)
                            ? _handleEditAvatar
                            : null,
                        uploadingAvatar: _uploadingAvatar,
                      ),
                    const SizedBox(height: 32),
                    // 设置卡片
                    _SettingsCard(items: items),
                    const SizedBox(height: 24),
                    // 注销账号按钮
                    _DeactivateButton(
                      onTap: _deactivating ? null : _handleDeactivate,
                      deactivating: _deactivating,
                    ),
                    const SizedBox(height: 12),
                    // 退出登录按钮
                    _LogoutButton(onTap: _logout),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserInfoSection extends StatefulWidget {
  const _UserInfoSection({
    this.user,
    this.onEditNickname,
    this.updatingNickname = false,
    this.onEditAvatar,
    this.uploadingAvatar = false,
  });

  final AuthUser? user;
  final VoidCallback? onEditNickname;
  final bool updatingNickname;
  final VoidCallback? onEditAvatar;
  final bool uploadingAvatar;

  @override
  State<_UserInfoSection> createState() => _UserInfoSectionState();
}

class _UserInfoSectionState extends State<_UserInfoSection> {
  String? _cachedAvatarPath;
  bool _isLoadingAvatar = false;
  final _userAvatarService = UserAvatarService();

  @override
  void initState() {
    super.initState();
    _initAvatar();
  }

  @override
  void didUpdateWidget(_UserInfoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果用户信息变化，重新初始化头像
    if (widget.user?.id != oldWidget.user?.id ||
        widget.user?.avatarObjectKey != oldWidget.user?.avatarObjectKey) {
      _initAvatar();
    }
  }

  void _initAvatar() {
    _cachedAvatarPath = widget.user?.localAvatarPath;

    // 验证本地缓存文件是否存在
    bool needsLoad = false;
    if (_cachedAvatarPath != null && _cachedAvatarPath!.isNotEmpty) {
      final file = File(_cachedAvatarPath!);
      if (!file.existsSync()) {
        _cachedAvatarPath = null;
        needsLoad = true;
      }
    } else {
      needsLoad = true;
    }

    // 如果有avatarObjectKey但没有有效的本地缓存，异步加载
    if (needsLoad &&
        widget.user?.avatarObjectKey != null &&
        widget.user!.avatarObjectKey!.isNotEmpty) {
      _loadAvatar();
    }
  }

  Future<void> _loadAvatar() async {
    if (_isLoadingAvatar) return;
    final user = widget.user;
    if (user == null ||
        user.avatarObjectKey == null ||
        user.avatarObjectKey!.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingAvatar = true;
    });

    try {
      final cachedPath = await _userAvatarService.loadAndCacheAvatar(
        userId: user.id,
        avatarObjectKey: user.avatarObjectKey,
      );

      if (mounted) {
        setState(() {
          _cachedAvatarPath = cachedPath;
          _isLoadingAvatar = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAvatar = false;
        });
      }
    }
  }

  Widget _buildAvatarContent(String displayName) {
    // 优先使用本地缓存路径
    if (_cachedAvatarPath != null && _cachedAvatarPath!.isNotEmpty) {
      final file = File(_cachedAvatarPath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _DefaultAvatar(displayName: displayName);
          },
        );
      }
    }

    // 如果正在加载头像，显示加载指示器
    if (_isLoadingAvatar &&
        widget.user?.avatarObjectKey != null &&
        widget.user!.avatarObjectKey!.isNotEmpty) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // 默认头像
    return _DefaultAvatar(displayName: displayName, colorSeed: widget.user?.id);
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.user?.displayName ?? '未命名用户';
    final username = widget.user?.username ?? '';
    // 直接显示完整的用户 ID
    final phoneText = username.isNotEmpty ? username : '未绑定';

    Widget avatarContent = _buildAvatarContent(displayName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        GestureDetector(
          onTap: (widget.onEditAvatar != null && !widget.uploadingAvatar)
              ? widget.onEditAvatar
              : null,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipOval(child: avatarContent),
              ),
              if (widget.uploadingAvatar)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color.fromRGBO(0, 0, 0, 0.45),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                right: 0,
                child: Opacity(
                  opacity: widget.onEditAvatar != null ? 1.0 : 0.4,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
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
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 用户昵称
        GestureDetector(
          onTap: widget.updatingNickname ? null : widget.onEditNickname,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              if (widget.updatingNickname)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              else if (widget.onEditNickname != null)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: SvgPicture.asset(
                    AppAssets.settingsEditOutline,
                    width: 16,
                    height: 16,
                    colorFilter: const ColorFilter.mode(
                      AppColors.textPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 手机号
        Text(
          '手机号：$phoneText',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.settingsTextMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  const _DefaultAvatar({required this.displayName, this.colorSeed});

  final String displayName;
  final String? colorSeed;

  @override
  Widget build(BuildContext context) {
    final name = displayName.trim();
    final initial = AvatarColorUtils.getInitial(name);
    final backgroundColor = AvatarColorUtils.generateBackgroundColor(
      (colorSeed != null && colorSeed!.trim().isNotEmpty) ? colorSeed! : name,
    );

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 40,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.items});

  final List<_SettingItemData> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 170),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _SettingItem(data: items[i], showDivider: i != items.length - 1),
        ],
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  const _SettingItem({required this.data, required this.showDivider});

  final _SettingItemData data;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    const trailing = SizedBox(
      width: 7,
      height: 15,
      child: Icon(
        Icons.chevron_right,
        size: 15,
        color: AppColors.textPrimary,
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: data.onTap == null
            ? null
            : () async {
                await data.onTap!.call();
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          constraints: const BoxConstraints(minHeight: 56),
          decoration: showDivider
              ? const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.settingsDivider,
                      width: 1,
                    ),
                  ),
                )
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _DeactivateButton extends StatelessWidget {
  const _DeactivateButton({required this.onTap, required this.deactivating});

  final Future<void> Function()? onTap;
  final bool deactivating;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: Material(
        color: AppColors.settingsDeactivateBg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap == null
              ? null
              : () async {
                  await onTap!();
                },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: SvgPicture.asset(
                    AppAssets.settingsLogout,
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                deactivating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '注销账号',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: Material(
        color: AppColors.settingsLogoutBg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: SvgPicture.asset(
                    AppAssets.settingsLogout,
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      AppColors.danger,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '退出登录',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.danger,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingItemData {
  const _SettingItemData({
    required this.title,
    this.onTap,
  });

  final String title;
  final Future<void> Function()? onTap;
}
