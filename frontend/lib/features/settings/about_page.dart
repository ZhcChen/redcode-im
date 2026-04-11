import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/app_config_service.dart';
import '../../core/services/version_service.dart';
import 'feedback_page.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final VersionService _versionService = VersionService();
  final AppConfigService _appConfigService = AppConfigService.instance;
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

  Widget _buildHeaderSection() {
    final currentVersionLabel = _packageInfo != null
        ? 'Version: ${_packageInfo!.version}'
        : 'Version: 获取中…';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          // Logo
          Image.asset(
            'assets/images/login/app_logo.png',
            width: 80,
            height: 80,
          ),
          const SizedBox(height: 16),
          // 应用名
          Text(
            _appName.isNotEmpty ? _appName : '加载中…',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          // 版本号
          Text(
            currentVersionLabel,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.settingsTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionCard(String currentVersionLabel) {
    final latest = _latestVersion;
    final releaseNotes = latest?.releaseNotes;
    final downloadPath = _downloadedFilePath;
    final downloadSize = _formatFileSize(_downloadedFileSize);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '检查新版本',
                        style: TextStyle(
                          fontSize: 16.0.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (_hasUpdate && latest != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: latest.mandatory
                                      ? Colors.redAccent.withValues(alpha: 0.1)
                                      : AppColors.primary.withValues(alpha: 0.1),
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
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        minimumSize: const Size(0, 28),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _checkingVersion
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('检查'),
                    ),
                    if (_hasUpdate && latest != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: FilledButton(
                          onPressed: _downloadInProgress
                              ? null
                              : _downloadUpdate,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 2,
                            ),
                            minimumSize: const Size(0, 28),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _downloadInProgress
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('下载'),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Text(
                    '意见反馈',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: _openFeedback,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    minimumSize: const Size(0, 28),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
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
              _buildHeaderSection(),
              _buildVersionCard(currentVersionLabel),
              _buildFeedbackCard(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
