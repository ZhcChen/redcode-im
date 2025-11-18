import 'dart:async';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_guard.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/debug/debug_logger.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/version_service.dart';
import '../../core/update/update_center.dart';
import '../auth/data/auth_repository.dart';
import '../auth/login_page.dart';
import '../home/home_shell_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final AuthRepository _authRepository = AuthRepository();
  final VersionService _versionService = VersionService();
  final SettingsService _settingsService = SettingsService();
  bool _navigated = false;
  String _appName = '';

  @override
  void initState() {
    super.initState();
    _loadAppName();
    _bootstrap();
  }

  Future<void> _loadAppName() async {
    try {
      final appName = await _settingsService.fetchAppName();
      if (mounted) {
        setState(() {
          _appName = appName;
        });
      }
    } catch (_) {
      // 静默失败，使用默认值
    }
  }

  Future<void> _bootstrap() async {
    Log.d('开始启动流程');

    final allowLaunch = await _ensureAppUpToDate();
    if (!allowLaunch || !mounted) {
      return;
    }

    try {
      final hotManager = await UpdateCenter.ensureHotUpdateManager();
      unawaited(hotManager.checkForUpdates());
    } catch (error) {
      Log.e('初始化热更新失败: $error');
    }

    final delay = Future<void>.delayed(const Duration(milliseconds: 800));
    const timeout = Duration(seconds: 10); // 设置10秒超时

    try {
      Log.d('尝试加载本地会话...');
      final session = await _authRepository.loadSession().timeout(timeout);

      if (session != null) {
        Log.d('找到本地会话，尝试验证...');
        try {
          final user = await _authRepository.refreshCurrentUser().timeout(
            timeout,
          );
          if (user != null) {
            Log.d('用户验证成功: ${user.username}');
            await delay;
            if (!mounted || _navigated) {
              return;
            }
            _goHome();
            return;
          }
        } on AuthException catch (e) {
          Log.e('用户验证失败: $e');
          await _authRepository.logout();
        } on TimeoutException {
          Log.e('验证用户超时');
          await _authRepository.logout();
        }
      } else {
        Log.d('没有找到本地会话');
      }
    } catch (e) {
      Log.e('启动流程出错: $e');
    }

    Log.d('跳转到登录页面');
    await delay;
    if (!mounted || _navigated) {
      return;
    }
    _goLogin();
  }

  void _goHome() {
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AuthGuard(child: const HomeShellPage()),
      ),
    );
  }

  void _goLogin() {
    _navigated = true;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => LoginPage(appName: _appName)));
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
        return WillPopScope(
          onWillPop: () async => !mandatory,
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
                  if (!mounted) {
                    Navigator.of(dialogContext).pop(false);
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
      backgroundColor: const Color(0xFFF7FFFE),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 应用 Logo
          Center(
            child: Image.asset(
              AppAssets.appLogo,
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            bottom: 64,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                _appName,
                style: const TextStyle(
                  fontSize: 18,
                  color: AppColors.textSecondary,
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
