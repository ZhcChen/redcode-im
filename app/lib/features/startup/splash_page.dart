import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_assets.dart';
import '../../core/debug/debug_logger.dart';
import '../../core/routing/app_route.dart';
import '../../core/routing/app_router.dart';
import '../../core/services/app_config_service.dart';
import '../../core/services/version_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/update/update_center.dart';
import '../../core/widgets/im_state_panel.dart';
import '../auth/data/auth_repository.dart';
import '../auth/login_page.dart';
import 'startup_session_resolver.dart';

typedef StartupSessionCallback = Future<StartupSessionResult> Function();
typedef StartupGateCallback = Future<bool> Function();
typedef StartupTaskCallback = Future<void> Function();
typedef StartupAppNameCallback = Future<String> Function();

class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    this.sessionResolver,
    this.versionGate,
    this.hotUpdateInitializer,
    this.appNameLoader,
    this.minimumDisplayDuration = const Duration(milliseconds: 800),
  });

  final StartupSessionCallback? sessionResolver;
  final StartupGateCallback? versionGate;
  final StartupTaskCallback? hotUpdateInitializer;
  final StartupAppNameCallback? appNameLoader;
  final Duration minimumDisplayDuration;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final AuthRepository _authRepository = AuthRepository();
  final VersionService _versionService = VersionService();
  final AppConfigService _appConfigService = AppConfigService.instance;

  bool _navigated = false;
  bool _bootstrapping = false;
  bool _launchGatePassed = false;
  bool _hotUpdateInitialized = false;
  bool _showRetry = false;
  String _appName = '';

  @override
  void initState() {
    super.initState();
    _loadAppName();
    _bootstrap();
  }

  Future<void> _loadAppName() async {
    try {
      final appName =
          await (widget.appNameLoader?.call() ??
              _appConfigService.getAppName());
      if (mounted) {
        setState(() => _appName = appName);
      }
      if (widget.appNameLoader != null) {
        return;
      }
      _appConfigService.refreshAppName().then((refreshedName) {
        if (mounted && refreshedName.isNotEmpty && refreshedName != _appName) {
          setState(() => _appName = refreshedName);
        }
      });
    } catch (_) {
      // The product name is optional startup decoration and never blocks auth.
    }
  }

  Future<void> _bootstrap() async {
    if (_bootstrapping || _navigated) {
      return;
    }
    _bootstrapping = true;
    if (_showRetry && mounted) {
      setState(() => _showRetry = false);
    }
    Log.d('开始启动流程');

    try {
      if (!_launchGatePassed) {
        final allowLaunch =
            await (widget.versionGate?.call() ?? _ensureAppUpToDate());
        if (!allowLaunch || !mounted) {
          return;
        }
        _launchGatePassed = true;
      }

      if (!_hotUpdateInitialized) {
        _hotUpdateInitialized = true;
        try {
          await (widget.hotUpdateInitializer?.call() ??
              _initializeHotUpdates());
        } catch (error) {
          Log.e('初始化热更新失败: $error');
        }
      }

      final result =
          await (widget.sessionResolver?.call() ?? _resolveStartupSession());
      await Future<void>.delayed(widget.minimumDisplayDuration);
      if (!mounted || _navigated) {
        return;
      }

      switch (result) {
        case StartupSessionResult.home:
          _goHome();
        case StartupSessionResult.login:
          _goLogin();
        case StartupSessionResult.retry:
          setState(() => _showRetry = true);
      }
    } finally {
      _bootstrapping = false;
    }
  }

  Future<void> _initializeHotUpdates() async {
    final hotManager = await UpdateCenter.ensureHotUpdateManager();
    unawaited(hotManager.checkForUpdates());
  }

  Future<StartupSessionResult> _resolveStartupSession() {
    const timeout = Duration(seconds: 10);
    return StartupSessionResolver.resolve(
      hasLocalSession: () async {
        Log.d('尝试加载本地会话...');
        return await _authRepository.loadSession().timeout(timeout) != null;
      },
      refreshSession: () async {
        Log.d('找到本地会话，尝试验证...');
        final user = await _authRepository.refreshCurrentUser().timeout(
          timeout,
        );
        if (user == null) {
          throw const StartupSessionRejected();
        }
        Log.d('用户验证成功: ${user.username}');
        return true;
      },
      clearInvalidSession: _authRepository.logout,
    );
  }

  void _retry() {
    unawaited(_bootstrap());
  }

  void _goHome() {
    if (_navigated) {
      return;
    }
    _navigated = true;
    AppRouter.open<void>(
      context,
      const AppRouteRequest(path: AppRoutePath.home),
      replace: true,
    );
  }

  void _goLogin() {
    if (_navigated) {
      return;
    }
    _navigated = true;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  Future<bool> _ensureAppUpToDate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final result = await _versionService.checkLatest(
        currentVersion: packageInfo.version,
      );
      if (!result.hasUpdate || result.latest == null) {
        return true;
      }
      return await _showUpdateDialog(result.latest!);
    } catch (error, stackTrace) {
      Log.e('整包检查失败: $error\n$stackTrace');
      return true;
    }
  }

  Future<bool> _showUpdateDialog(AppVersionInfo latest) async {
    if (!mounted) return true;
    final mandatory = latest.mandatory;
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: !mandatory,
      builder: (dialogContext) {
        return PopScope(
          canPop: !mandatory,
          child: AlertDialog(
            title: Text(mandatory ? '必须更新至最新版本' : '发现新版本 v${latest.version}'),
            content: Text(
              mandatory
                  ? '检测到强制更新，版本号 ${latest.version}（渠道 ${latest.channel}）。请立即更新以继续使用。'
                  : '检测到新版本 ${latest.version}，是否立即下载更新？',
            ),
            actions: [
              if (!mandatory)
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('稍后再说'),
                ),
              FilledButton(
                onPressed: () async {
                  await _launchVersionDownload(latest);
                  if (!dialogContext.mounted) {
                    return;
                  }
                  if (mandatory) {
                    Navigator.of(dialogContext).pop(false);
                    await _showForceUpdateReminder();
                  } else {
                    Navigator.of(dialogContext).pop(true);
                  }
                },
                child: const Text('立即更新'),
              ),
            ],
          ),
        );
      },
    );

    return proceed ?? !mandatory;
  }

  Future<void> _launchVersionDownload(AppVersionInfo latest) async {
    try {
      final url = await _versionService.fetchDownloadUrl(id: latest.id);
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('无法打开下载链接');
      }
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('下载失败'),
          content: Text('$error'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('好的'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showForceUpdateReminder() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('请完成更新'),
        content: const Text('请在完成最新版本的安装后重新打开应用。'),
        actions: [
          TextButton(
            onPressed: () {
              if (Platform.isAndroid) {
                SystemNavigator.pop();
              } else {
                exit(0);
              }
            },
            child: const Text('退出应用'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: AnimatedSwitcher(
              duration: AppMotion.resolve(context, AppMotion.standard),
              child: _showRetry
                  ? ImStatePanel(
                      key: const ValueKey('startup-retry'),
                      icon: Icons.cloud_off_outlined,
                      title: '暂时无法连接服务器',
                      message: '已保留登录状态，请检查网络后重试。',
                      actionLabel: '重新连接',
                      onAction: _retry,
                    )
                  : Center(
                      key: const ValueKey('startup-loading'),
                      child: Image.asset(
                        AppAssets.appLogo,
                        width: 104,
                        height: 104,
                        fit: BoxFit.contain,
                      ),
                    ),
            ),
          ),
          if (!_showRetry)
            Positioned(
              bottom: AppSpacing.xl,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: SafeArea(
                top: false,
                child: Text(
                  _appName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
