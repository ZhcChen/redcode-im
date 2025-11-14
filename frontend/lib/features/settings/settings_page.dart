import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/message_service.dart';
import '../../core/services/version_service.dart';
import '../../core/update/hot_update_manager.dart';
import '../../core/update/hot_update_models.dart';
import '../../core/update/update_center.dart';
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
  final VersionService _versionService = VersionService();
  HotUpdateManager? _hotUpdateManager;
  HotUpdateState _hotUpdateState = const HotUpdateState();
  AuthUser? _user;
  bool _loading = true;
  bool _deactivating = false;
  bool _updatingNickname = false;
  bool _clearingCache = false;
  bool _uploadingAvatar = false;
  bool _checkingVersion = false;
  bool _downloadInProgress = false;
  PackageInfo? _packageInfo;
  VersionCheckResult? _versionResult;
  String? _downloadedFilePath;
  int? _downloadedFileSize;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _initVersionInfo();
    _initHotUpdateManager();
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

  Future<void> _initVersionInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _packageInfo = info;
      });
      await _checkForUpdate(auto: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法获取应用版本信息：$error')));
    }
  }

  Future<void> _initHotUpdateManager() async {
    try {
      final manager = await UpdateCenter.ensureHotUpdateManager();
      if (!mounted) return;
      _hotUpdateManager = manager;
      _hotUpdateState = manager.state;
      manager.addListener(_handleHotUpdateChanged);
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('热更新服务初始化失败：$error')));
    }
  }

  void _handleHotUpdateChanged() {
    if (!mounted || _hotUpdateManager == null) return;
    setState(() {
      _hotUpdateState = _hotUpdateManager!.state;
    });
  }

  Future<void> _checkForUpdate({bool auto = false}) async {
    final currentVersion = _packageInfo?.version ?? '';
    if (currentVersion.isEmpty) {
      if (!auto && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('尚未获取当前版本信息')));
      }
      return;
    }
    setState(() {
      _checkingVersion = true;
    });
    try {
      final result = await _versionService.checkLatest(
        currentVersion: currentVersion,
      );
      if (!mounted) return;
      setState(() {
        _versionResult = result;
        _downloadedFilePath = null;
        _downloadedFileSize = null;
      });
      if (!auto) {
        final text = result.hasUpdate
            ? '检测到新版本 v${result.latest?.version ?? ''}'
            : '当前已是最新版本';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text)));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('检查更新失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _checkingVersion = false;
        });
      } else {
        _checkingVersion = false;
      }
    }
  }

  Future<void> _downloadUpdate() async {
    final latest = _versionResult?.latest;
    if (latest == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('没有可下载的版本')));
      }
      return;
    }
    setState(() {
      _downloadInProgress = true;
    });
    try {
      final result = await _versionService.downloadAndSave(version: latest);
      if (!mounted) return;
      setState(() {
        _downloadedFilePath = result.filePath;
        _downloadedFileSize = result.fileSize;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('安装包已保存至：${result.filePath}'),
          action: SnackBarAction(label: '打开', onPressed: _openDownloadedFile),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('下载更新失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _downloadInProgress = false;
        });
      } else {
        _downloadInProgress = false;
      }
    }
  }

  Future<void> _openDownloadedFile() async {
    final path = _downloadedFilePath;
    if (path == null || path.isEmpty) {
      return;
    }
    final uri = Uri.file(path);
    if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开已下载的文件')));
    }
  }

  bool get _hasUpdate => _versionResult?.hasUpdate ?? false;
  AppVersionInfo? get _latestVersion => _versionResult?.latest;

  @override
  void dispose() {
    _hotUpdateManager?.removeListener(_handleHotUpdateChanged);
    super.dispose();
  }

  String _formatFileSize(int? size) {
    if (size == null || size <= 0) return '-';
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (size >= gb) {
      return '${(size / gb).toStringAsFixed(2)} GB';
    }
    if (size >= mb) {
      return '${(size / mb).toStringAsFixed(2)} MB';
    }
    if (size >= kb) {
      return '${(size / kb).toStringAsFixed(1)} KB';
    }
    return '$size B';
  }

  String _hotStageLabel(HotUpdateStage stage) {
    switch (stage) {
      case HotUpdateStage.checking:
        return '检查中';
      case HotUpdateStage.available:
        return '可用';
      case HotUpdateStage.downloading:
        return '下载中';
      case HotUpdateStage.downloaded:
        return '已下载';
      case HotUpdateStage.applied:
        return '已应用';
      case HotUpdateStage.failed:
        return '失败';
      case HotUpdateStage.noUpdate:
        return '暂无补丁';
      case HotUpdateStage.applying:
        return '应用中';
      case HotUpdateStage.verifying:
        return '校验中';
      case HotUpdateStage.idle:
      default:
        return '待检测';
    }
  }

  Color _hotStageColor(HotUpdateStage stage) {
    switch (stage) {
      case HotUpdateStage.available:
        return AppColors.primary;
      case HotUpdateStage.downloading:
      case HotUpdateStage.verifying:
      case HotUpdateStage.applying:
        return Colors.orangeAccent;
      case HotUpdateStage.downloaded:
      case HotUpdateStage.applied:
        return Colors.green;
      case HotUpdateStage.failed:
        return Colors.redAccent;
      case HotUpdateStage.noUpdate:
        return AppColors.settingsTextMuted;
      case HotUpdateStage.checking:
        return Colors.blueAccent;
      case HotUpdateStage.idle:
      default:
        return AppColors.settingsTextMuted;
    }
  }

  Widget _buildVersionCard(String currentVersionLabel) {
    final latest = _latestVersion;
    final releaseNotes = latest?.releaseNotes;
    final downloadPath = _downloadedFilePath;
    final downloadSize = _formatFileSize(_downloadedFileSize);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '应用版本',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '当前：$currentVersionLabel',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.settingsTextMuted,
                        ),
                      ),
                      if (_hasUpdate && latest != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: latest.mandatory
                                      ? Colors.redAccent.withOpacity(0.1)
                                      : AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  latest.mandatory ? '强制更新' : '可更新',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: latest.mandatory
                                        ? Colors.redAccent
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '最新：v${latest.version}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    OutlinedButton(
                      onPressed: _checkingVersion
                          ? null
                          : () => _checkForUpdate(auto: false),
                      child: _checkingVersion
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('检查更新'),
                    ),
                    if (_hasUpdate && latest != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: FilledButton(
                          onPressed: _downloadInProgress
                              ? null
                              : _downloadUpdate,
                          child: _downloadInProgress
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('下载更新'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (releaseNotes != null && releaseNotes.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  releaseNotes,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.settingsTextMuted,
                    height: 1.4,
                  ),
                ),
              ),
            if (downloadPath != null && downloadPath.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: InkWell(
                  onTap: _openDownloadedFile,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.save_alt,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '已下载：$downloadPath ($downloadSize)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotUpdateCard() {
    final stage = _hotUpdateState.stage;
    final patch = _hotUpdateState.patch;
    final downloaded = _hotUpdateState.downloaded;
    final stageLabel = _hotStageLabel(stage);
    final badgeColor = _hotStageColor(stage);
    final checking = stage == HotUpdateStage.checking;
    final downloading = stage == HotUpdateStage.downloading;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '热更新',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    stageLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: badgeColor == Colors.transparent
                          ? AppColors.textPrimary
                          : badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (patch == null && stage == HotUpdateStage.noUpdate)
              const Text(
                '当前渠道暂无可用补丁，将在后台持续监测。',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.settingsTextMuted,
                ),
              ),
            if (patch != null) ...[
              Text(
                '补丁版本：${patch.patchVersion}（${patch.channel}）',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '强制更新：${patch.mandatory ? '是' : '否'} · 灰度比例：${patch.rolloutPercentage}%',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.settingsTextMuted,
                ),
              ),
              if (patch.description != null &&
                  patch.description!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    patch.description!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.settingsTextMuted,
                    ),
                  ),
                ),
            ],
            if (_hotUpdateState.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _hotUpdateState.errorMessage ?? '未知错误',
                  style: const TextStyle(fontSize: 13, color: Colors.redAccent),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: (_hotUpdateManager == null || checking)
                      ? null
                      : _handleManualHotUpdateCheck,
                  child: checking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('检查补丁'),
                ),
                const SizedBox(width: 12),
                if (patch != null)
                  FilledButton(
                    onPressed: downloading ? null : _handleDownloadHotPatch,
                    child: downloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(downloaded != null ? '重新下载' : '下载补丁'),
                  ),
              ],
            ),
            if (downloaded != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '已下载补丁：${downloaded.filePath}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.settingsTextMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _handleOpenHotPatchFile,
                          child: const Text('打开补丁文件'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _handleClearHotPatchFile,
                          child: const Text('清除'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
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
    final currentVersionLabel = _packageInfo != null
        ? 'v${_packageInfo!.version} (build ${_packageInfo!.buildNumber})'
        : '获取中…';
    final items = <_SettingItemData>[
      _SettingItemData(
        title: '账号与安全',
        onTap: () async => _openAccountSecurity(),
      ),
      _SettingItemData(title: '隐私政策', onTap: () async => _openPrivacyPolicy()),
      _SettingItemData(title: '意见反馈', onTap: _openFeedback),
      _SettingItemData(
        title: '清理缓存',
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
              : const SizedBox(
                  key: ValueKey('cache-arrow'),
                  width: 7,
                  height: 15,
                  child: Icon(
                    Icons.chevron_right,
                    size: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
        ),
      ),
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
                    _buildVersionCard(currentVersionLabel),
                    _buildHotUpdateCard(),
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

Future<void> _handleManualHotUpdateCheck() async {
  final manager = _hotUpdateManager;
  if (manager == null) return;
  await manager.checkForUpdates();
}

Future<void> _handleDownloadHotPatch() async {
  final manager = _hotUpdateManager;
  if (manager == null) return;
  try {
    final record = await manager.downloadAvailablePatch();
    if (!mounted || record == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('补丁已下载：${record.filePath}')));
  } catch (error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('下载补丁失败：$error')));
  }
}

Future<void> _handleOpenHotPatchFile() async {
  final record = _hotUpdateState.downloaded;
  if (record == null) return;
  final file = File(record.filePath);
  if (!await file.exists()) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('找不到已下载的补丁文件')));
    await _hotUpdateManager?.resetDownloadedState();
    return;
  }
  final result = await OpenFilex.open(file.path);
  if (!mounted) return;
  if (result.type != ResultType.done) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('无法打开补丁：${result.message}')));
  }
}

Future<void> _handleClearHotPatchFile() async {
  final record = _hotUpdateState.downloaded;
  if (record == null) return;
  final file = File(record.filePath);
  if (await file.exists()) {
    await file.delete();
  }
  await _hotUpdateManager?.resetDownloadedState();
  if (!mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('已清除补丁文件')));
}

class _UserInfoSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final displayName = user?.displayName ?? '未命名用户';
    final username = user?.username ?? '';
    // 如果 username 是 11 位数字（手机号格式），则格式化显示
    final phoneText =
        username.isNotEmpty && RegExp(r'^\d{11}$').hasMatch(username)
        ? '${username.substring(0, 3)}****${username.substring(username.length - 4)}'
        : username.isNotEmpty
        ? username
        : '未绑定';

    final avatarPath = user?.localAvatarPath;
    final avatarUrl = user?.avatarUrl;

    Widget avatarContent;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      avatarContent = Image.file(
        File(avatarPath),
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _DefaultAvatar(displayName: displayName),
      );
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarContent = Image.network(
        avatarUrl,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _DefaultAvatar(displayName: displayName),
      );
    } else {
      avatarContent = _DefaultAvatar(displayName: displayName);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        GestureDetector(
          onTap: (onEditAvatar != null && !uploadingAvatar)
              ? onEditAvatar
              : null,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.settingsAvatarBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipOval(child: avatarContent),
              ),
              if (uploadingAvatar)
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
                  opacity: onEditAvatar != null ? 1.0 : 0.4,
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
          onTap: updatingNickname ? null : onEditNickname,
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
          'ID：$phoneText',
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
  const _DefaultAvatar({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final name = displayName.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: 100,
      height: 100,
      decoration: const BoxDecoration(
        color: AppColors.settingsAvatarBg,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 40,
            color: AppColors.settingsTextMuted,
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
    final trailing =
        data.trailingBuilder?.call(context) ??
        const SizedBox(
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
    this.trailingBuilder,
  });

  final String title;
  final Future<void> Function()? onTap;
  final Widget Function(BuildContext context)? trailingBuilder;
}
