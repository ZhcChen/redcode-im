import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/app_config_service.dart';
import 'package:frontend/core/services/settings_service.dart';
import 'package:frontend/core/storage/app_config_storage.dart';

class FakeAppConfigStorage extends AppConfigStorage {
  String? appName;
  int getAppNameCalls = 0;
  int saveAppNameCalls = 0;
  int clearAllCalls = 0;

  @override
  Future<String?> getAppName() async {
    getAppNameCalls += 1;
    return appName;
  }

  @override
  Future<void> saveAppName(String appName) async {
    saveAppNameCalls += 1;
    this.appName = appName;
  }

  @override
  Future<void> clearAll() async {
    clearAllCalls += 1;
    appName = null;
  }
}

class FakeSettingsService extends SettingsService {
  FakeSettingsService({required this.value, this.shouldThrow = false})
    : super();

  String value;
  bool shouldThrow;
  int fetchCalls = 0;

  @override
  Future<String> fetchAppName() async {
    fetchCalls += 1;
    if (shouldThrow) {
      throw Exception('api error');
    }
    return value;
  }
}

void main() {
  group('AppConfigService', () {
    test('getAppName prefers memory cache once loaded', () async {
      final storage = FakeAppConfigStorage();
      final settings = FakeSettingsService(value: 'Bear Chat');
      final service = AppConfigService(
        storage: storage,
        settingsService: settings,
      );

      final first = await service.getAppName();
      final getCallsAfterFirst = storage.getAppNameCalls;
      settings.value = 'Changed Name';

      final second = await service.getAppName();

      expect(first, 'Bear Chat');
      expect(second, 'Bear Chat');
      expect(settings.fetchCalls, 1);
      expect(storage.getAppNameCalls, getCallsAfterFirst);
      expect(storage.saveAppNameCalls, 1);
    });

    test('getAppName prefers storage value before requesting API', () async {
      final storage = FakeAppConfigStorage()..appName = 'Stored Name';
      final settings = FakeSettingsService(value: 'API Name');
      final service = AppConfigService(
        storage: storage,
        settingsService: settings,
      );

      final appName = await service.getAppName();

      expect(appName, 'Stored Name');
      expect(settings.fetchCalls, 0);
      expect(storage.getAppNameCalls, 1);
      expect(storage.saveAppNameCalls, 0);
    });

    test('refreshAppName falls back to storage when API throws', () async {
      final storage = FakeAppConfigStorage()..appName = 'Fallback Name';
      final settings = FakeSettingsService(
        value: 'API Name',
        shouldThrow: true,
      );
      final service = AppConfigService(
        storage: storage,
        settingsService: settings,
      );

      final appName = await service.refreshAppName();

      expect(appName, 'Fallback Name');
      expect(settings.fetchCalls, 1);
      expect(storage.getAppNameCalls, 1);
      expect(storage.saveAppNameCalls, 0);
    });

    test('clearCache resets cache and delegates to storage clearAll', () async {
      final storage = FakeAppConfigStorage();
      final settings = FakeSettingsService(value: 'Name A');
      final service = AppConfigService(
        storage: storage,
        settingsService: settings,
      );

      await service.getAppName();
      await service.clearCache();
      settings.value = 'Name B';

      final reloaded = await service.getAppName();

      expect(storage.clearAllCalls, 1);
      expect(settings.fetchCalls, 2);
      expect(reloaded, 'Name B');
    });
  });
}
