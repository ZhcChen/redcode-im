import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/services/app_config_service.dart';
import 'package:app/core/services/settings_service.dart';
import 'package:app/core/storage/app_config_storage.dart';

class FakeAppConfigStorage extends AppConfigStorage {
  String? appName;
  String? serverStorageMode;
  String? contentAuditMode;
  int getAppNameCalls = 0;
  int saveAppNameCalls = 0;
  int getMessageRuntimeCalls = 0;
  int saveMessageRuntimeCalls = 0;
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
  Future<MessageRuntimeSettings?> getMessageRuntime() async {
    getMessageRuntimeCalls += 1;
    if (serverStorageMode == null && contentAuditMode == null) {
      return null;
    }
    return MessageRuntimeSettings(
      serverStorageMode: serverStorageMode ?? 'persist',
      contentAuditMode: contentAuditMode ?? 'plaintext',
    );
  }

  @override
  Future<void> saveMessageRuntime(MessageRuntimeSettings runtime) async {
    saveMessageRuntimeCalls += 1;
    serverStorageMode = runtime.serverStorageMode;
    contentAuditMode = runtime.contentAuditMode;
  }

  @override
  Future<void> clearAll() async {
    clearAllCalls += 1;
    appName = null;
    serverStorageMode = null;
    contentAuditMode = null;
  }
}

class FakeSettingsService extends SettingsService {
  FakeSettingsService({
    required this.value,
    this.generalSettings,
    this.shouldThrow = false,
  }) : super();

  String value;
  GeneralSettings? generalSettings;
  bool shouldThrow;
  int fetchCalls = 0;
  int fetchGeneralSettingsCalls = 0;

  @override
  Future<String> fetchAppName() async {
    fetchCalls += 1;
    if (shouldThrow) {
      throw Exception('api error');
    }
    return value;
  }

  @override
  Future<GeneralSettings> fetchGeneralSettings() async {
    fetchGeneralSettingsCalls += 1;
    if (shouldThrow) {
      throw Exception('api error');
    }
    return generalSettings ??
        GeneralSettings(
          appName: value,
          messageRuntime: const MessageRuntimeSettings(
            serverStorageMode: 'persist',
            contentAuditMode: 'plaintext',
          ),
        );
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
      expect(settings.fetchGeneralSettingsCalls, 1);
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
      expect(settings.fetchGeneralSettingsCalls, 1);
      expect(storage.getAppNameCalls, 1);
      expect(storage.saveAppNameCalls, 0);
    });

    test(
      'getMessageRuntime prefers storage value before requesting API',
      () async {
        final storage = FakeAppConfigStorage()
          ..serverStorageMode = 'relay_only'
          ..contentAuditMode = 'e2ee';
        final settings = FakeSettingsService(
          value: 'API Name',
          generalSettings: const GeneralSettings(
            appName: 'API Name',
            messageRuntime: MessageRuntimeSettings(
              serverStorageMode: 'persist',
              contentAuditMode: 'plaintext',
            ),
          ),
        );
        final service = AppConfigService(
          storage: storage,
          settingsService: settings,
        );

        final runtime = await service.getMessageRuntime();

        expect(runtime.serverStorageMode, 'relay_only');
        expect(runtime.contentAuditMode, 'e2ee');
        expect(settings.fetchGeneralSettingsCalls, 0);
        expect(storage.getMessageRuntimeCalls, 1);
      },
    );

    test(
      'refreshAppName keeps legacy app-name fallback when general settings appName is empty',
      () async {
        final storage = FakeAppConfigStorage();
        final settings = FakeSettingsService(
          value: 'Legacy Name',
          generalSettings: const GeneralSettings(
            appName: '',
            messageRuntime: MessageRuntimeSettings(
              serverStorageMode: 'relay_only',
              contentAuditMode: 'plaintext',
            ),
          ),
        );
        final service = AppConfigService(
          storage: storage,
          settingsService: settings,
        );

        final appName = await service.refreshAppName();

        expect(appName, 'Legacy Name');
        expect(service.currentMessageRuntime.serverStorageMode, 'relay_only');
        expect(storage.appName, 'Legacy Name');
        expect(storage.serverStorageMode, 'relay_only');
      },
    );

    test(
      'refreshMessageRuntime updates cache and storage from general settings',
      () async {
        final storage = FakeAppConfigStorage();
        final settings = FakeSettingsService(
          value: 'Bear Chat',
          generalSettings: const GeneralSettings(
            appName: 'Bear Chat',
            messageRuntime: MessageRuntimeSettings(
              serverStorageMode: 'relay_only',
              contentAuditMode: 'e2ee',
            ),
          ),
        );
        final service = AppConfigService(
          storage: storage,
          settingsService: settings,
        );

        final runtime = await service.refreshMessageRuntime();

        expect(runtime.serverStorageMode, 'relay_only');
        expect(runtime.contentAuditMode, 'e2ee');
        expect(service.currentMessageRuntime.serverStorageMode, 'relay_only');
        expect(service.currentMessageRuntime.contentAuditMode, 'e2ee');
        expect(storage.saveMessageRuntimeCalls, 1);
        expect(storage.serverStorageMode, 'relay_only');
        expect(storage.contentAuditMode, 'e2ee');
      },
    );

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
      expect(settings.fetchGeneralSettingsCalls, 2);
      expect(reloaded, 'Name B');
    });
  });
}
