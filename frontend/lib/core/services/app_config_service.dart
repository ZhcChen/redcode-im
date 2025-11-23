import '../storage/app_config_storage.dart';
import 'settings_service.dart';

/// 应用配置服务（统一管理应用配置，包括从 API 获取和从 SQLite 读取）
class AppConfigService {
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

  /// 获取应用名称（优先从内存缓存，其次从 SQLite，最后从 API）
  Future<String> getAppName() async {
    // 1. 从内存缓存获取
    if (_cachedAppName != null && _cachedAppName!.isNotEmpty) {
      return _cachedAppName!;
    }

    // 2. 从 SQLite 获取
    final storedAppName = await _storage.getAppName();
    if (storedAppName != null && storedAppName.isNotEmpty) {
      _cachedAppName = storedAppName;
      return storedAppName;
    }

    // 3. 从 API 获取并缓存
    return await refreshAppName();
  }

  /// 从 API 刷新应用名称并保存到 SQLite
  Future<String> refreshAppName() async {
    try {
      final appName = await _settingsService.fetchAppName();
      if (appName.isNotEmpty) {
        _cachedAppName = appName;
        await _storage.saveAppName(appName);
      }
      return appName;
    } catch (e) {
      // API 获取失败，返回缓存或空字符串
      final storedAppName = await _storage.getAppName();
      return storedAppName ?? '';
    }
  }

  /// 清空缓存
  Future<void> clearCache() async {
    _cachedAppName = null;
    await _storage.clearAll();
  }
}
