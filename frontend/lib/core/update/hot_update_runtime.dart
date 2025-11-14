import 'hot_update_models.dart';

class RuntimeState {
  const RuntimeState({this.patchVersion, this.assetsDir});

  final String? patchVersion;
  final String? assetsDir;
}

class RuntimeApplyResult {
  const RuntimeApplyResult({required this.patchVersion, this.assetsDir});

  final String patchVersion;
  final String? assetsDir;
}

abstract class HotUpdateRuntime {
  Future<RuntimeState> loadState();

  Future<RuntimeApplyResult> applyPatch({
    required HotPatchInfo patch,
    required HotUpdateDownloadRecord record,
  });

  Future<void> rollbackActivePatch();
}
