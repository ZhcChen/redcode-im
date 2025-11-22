import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/app_config_service.dart';
import '../../core/services/version_service.dart';
import '../../core/update/hot_update_manager.dart';
import '../../core/update/hot_update_models.dart';
import '../../core/update/update_center.dart';
import 'feedback_page.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final VersionService _versionService = VersionService();
  final AppConfigService _appConfigService = AppConfigService.instance;
  HotUpdateManager? _hotUpdateManager;
  HotUpdateState _hotUpdateState = const HotUpdateState();
  bool _checkingVersion = false;
  bool _downloadInProgress = false;
  PackageInfo? _packageInfo;
  VersionCheckResult? _versionResult;
  String? _downloadedFilePath;
  int? _downloadedFileSize;
  String _appName = '';

  @override
  void initState() {
    super.initState();
    _loadAppName();
    _initVersionInfo();
    _initHotUpdateManager();
  }

  Future<void> _loadAppName() async {
    try {
      final appName = await _appConfigService.getAppName();
      if (mounted) {
        setState(() {
          _appName = appName;
        });
      }
    } catch (_) {
      // 静默失败，使用默认值
    }
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
                      Text(
                        '检查更新',
                        style: TextStyle(
                          fontSize: 16.0.sp,
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
                          child: const Text('删除下载包'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (_hotUpdateManager?.installedPatch != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '已应用补丁：${_hotUpdateManager?.installedPatch?.patchVersion ?? ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.settingsTextMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: _handleClearInstalledPatch,
                      child: const Text('移除补丁'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
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

  Future<void> _handleClearInstalledPatch() async {
    final manager = _hotUpdateManager;
    if (manager == null) return;
    try {
      await manager.rollbackActivePatch(reason: '用户主动清除补丁');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已移除已应用补丁')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('移除补丁失败：$error')));
    }
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

  Widget _buildFeedbackCard() {
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '意见反馈',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '我们非常重视您的体验，欢迎留下任何问题或建议。',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.settingsTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: _openFeedback,
                  child: const Text('反馈'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentVersionLabel = _packageInfo != null
        ? 'v${_packageInfo!.version} (build ${_packageInfo!.buildNumber})'
        : '获取中…';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textBlack),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _appName.isNotEmpty ? '关于$_appName' : '关于',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: AppColors.textBlack,
            letterSpacing: 0,
            height: 1.2,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              _buildVersionCard(currentVersionLabel),
              _buildHotUpdateCard(),
              _buildFeedbackCard(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
