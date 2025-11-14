import 'hot_update_manager.dart';
import 'hot_update_service.dart';
import 'hot_update_storage.dart';

class UpdateCenter {
  const UpdateCenter._();

  static HotUpdateManager? _hotUpdateManager;

  static HotUpdateManager? get hotUpdateManager => _hotUpdateManager;

  static Future<HotUpdateManager> ensureHotUpdateManager() async {
    if (_hotUpdateManager != null) {
      return _hotUpdateManager!;
    }
    final storage = await HotUpdateStorage.create();
    final manager = HotUpdateManager(
      hotUpdateService: HotUpdateService(),
      hotUpdateStorage: storage,
    );
    await manager.initialize();
    _hotUpdateManager = manager;
    return manager;
  }
}
