import 'package:flutter/foundation.dart';

import '../storage/app_config_storage.dart';
import 'settings_service.dart';

/// 应用配置服务（统一管理应用配置，包括从 API 获取和从 SQLite 读取）
class AppConfigService extends ChangeNotifier {
  AppConfigService({
    AppConfigStorage? storage,
    SettingsService? settingsService,
  }) : _storage = storage ?? const AppConfigStorage(),
       _settingsService = settingsService ?? SettingsService();

  final AppConfigStorage _storage;
  final SettingsService _settingsService;

  static final AppConfigService _instance = AppConfigService();
  static AppConfigService get instance => _instance;

  String? _cachedAppName;
  MessageRuntimeSettings _cachedMessageRuntime =
      MessageRuntimeSettings.defaults;
  bool _hasCachedMessageRuntime = false;

  MessageRuntimeSettings get currentMessageRuntime => _cachedMessageRuntime;

  /// 获取应用名称（优先从内存缓存，其次从 SQLite，最后从 API）
  Future<String> getAppName() async {
    // 1. 从内存缓存获取
    if (_cachedAppName != null && _cachedAppName!.isNotEmpty) {
      return _cachedAppName!;
    }

    // 2. 从 SQLite 获取
    final storedAppName = await _storage.getAppName();
    final storedRuntime = await _storage.getMessageRuntime();
    if (storedRuntime != null) {
      _cacheMessageRuntime(storedRuntime);
    }
    if (storedAppName != null && storedAppName.isNotEmpty) {
      _cachedAppName = storedAppName;
      return storedAppName;
    }

    // 3. 从 API 获取并缓存
    return refreshAppName();
  }

  /// 获取消息运行模式（优先内存缓存，其次 SQLite，最后 API）
  Future<MessageRuntimeSettings> getMessageRuntime() async {
    if (_hasCachedMessageRuntime) {
      return _cachedMessageRuntime;
    }

    final storedRuntime = await _storage.getMessageRuntime();
    if (storedRuntime != null) {
      _cacheMessageRuntime(storedRuntime);
      return storedRuntime;
    }

    return refreshMessageRuntime();
  }

  /// 从 API 刷新应用名称并保存到 SQLite
  Future<String> refreshAppName() async {
    try {
      final general = await _settingsService.fetchGeneralSettings();
      var appName = general.appName;

      if (appName.isEmpty) {
        appName = await _settingsService.fetchAppName();
      }

      await _cacheGeneralSettings(general, appNameOverride: appName);
      return appName;
    } catch (e) {
      // API 获取失败，返回缓存或空字符串
      final storedRuntime = await _storage.getMessageRuntime();
      if (storedRuntime != null) {
        _cacheMessageRuntime(storedRuntime);
      }
      final storedAppName = await _storage.getAppName();
      return storedAppName ?? '';
    }
  }

  /// 从 API 刷新消息运行模式并保存到 SQLite
  Future<MessageRuntimeSettings> refreshMessageRuntime() async {
    try {
      final general = await _settingsService.fetchGeneralSettings();
      await _cacheGeneralSettings(general);
      return general.messageRuntime;
    } catch (e) {
      final storedRuntime = await _storage.getMessageRuntime();
      if (storedRuntime != null) {
        _cacheMessageRuntime(storedRuntime);
        return storedRuntime;
      }
      return currentMessageRuntime;
    }
  }

  /// 清空缓存
  Future<void> clearCache() async {
    _cachedAppName = null;
    _cachedMessageRuntime = MessageRuntimeSettings.defaults;
    _hasCachedMessageRuntime = false;
    await _storage.clearAll();
  }

  Future<void> _cacheGeneralSettings(
    GeneralSettings settings, {
    String? appNameOverride,
  }) async {
    final appName = appNameOverride ?? settings.appName;

    _cachedAppName = appName;
    _cacheMessageRuntime(settings.messageRuntime);

    if (appName.isNotEmpty) {
      await _storage.saveAppName(appName);
    }
    await _storage.saveMessageRuntime(settings.messageRuntime);
  }

  void _cacheMessageRuntime(MessageRuntimeSettings runtime) {
    final previous = _cachedMessageRuntime;
    final hadCachedRuntime = _hasCachedMessageRuntime;

    _cachedMessageRuntime = runtime;
    _hasCachedMessageRuntime = true;

    if (!hadCachedRuntime ||
        previous.serverStorageMode != runtime.serverStorageMode ||
        previous.contentAuditMode != runtime.contentAuditMode) {
      notifyListeners();
    }
  }
}
