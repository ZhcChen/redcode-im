import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../debug/debug_logger.dart';
import 'hot_update_models.dart';
import 'hot_update_service.dart';
import 'hot_update_storage.dart';

class HotUpdateManager extends ChangeNotifier {
  HotUpdateManager({
    required this.hotUpdateService,
    required this.hotUpdateStorage,
  });

  final HotUpdateService hotUpdateService;
  final HotUpdateStorage hotUpdateStorage;

  HotUpdateState _state = const HotUpdateState();
  InstalledHotPatchInfo? _installedPatch;
  PackageInfo? _packageInfo;

  HotUpdateState get state => _state;
  InstalledHotPatchInfo? get installedPatch => _installedPatch;

  Future<void> initialize() async {
    _installedPatch = hotUpdateStorage.loadInstalledPatch();
    final downloaded = hotUpdateStorage.loadDownloadedPatch();
    _packageInfo = await PackageInfo.fromPlatform();

    if (downloaded != null) {
      _setState(
        _state.copyWith(
          stage: HotUpdateStage.downloaded,
          downloaded: downloaded,
          patch: _state.patch,
        ),
      );
    }
  }

  Future<void> checkForUpdates({String channel = 'stable'}) async {
    final packageInfo = _packageInfo ?? await PackageInfo.fromPlatform();
    _packageInfo = packageInfo;
    final currentVersion = packageInfo.version;
    if (currentVersion.isEmpty) {
      return;
    }
    _setState(
      _state.copyWith(stage: HotUpdateStage.checking, errorMessage: null),
    );
    try {
      final currentPatchVersion = _installedPatch?.patchVersion;
      final clientId = await hotUpdateStorage.ensureClientId();
      final platform = Platform.isIOS ? 'ios' : 'android';
      final result = await hotUpdateService.checkLatest(
        platform: platform,
        currentVersion: currentVersion,
        channel: channel,
        currentPatchVersion: currentPatchVersion,
        clientId: clientId,
      );
      if (!result.hasUpdate || result.patch == null) {
        _setState(
          _state.copyWith(
            stage: HotUpdateStage.noUpdate,
            patch: null,
            downloaded: null,
          ),
        );
        return;
      }

      _setState(
        _state.copyWith(
          stage: HotUpdateStage.available,
          patch: result.patch,
          downloaded: hotUpdateStorage.loadDownloadedPatch(),
        ),
      );
    } catch (error, stackTrace) {
      Log.e('热更新检查失败: $error\n$stackTrace');
      _setState(
        _state.copyWith(stage: HotUpdateStage.failed, errorMessage: '$error'),
      );
    }
  }

  Future<HotUpdateDownloadRecord?> downloadAvailablePatch() async {
    final targetPatch = _state.patch;
    if (targetPatch == null) return null;
    final packageInfo = _packageInfo ?? await PackageInfo.fromPlatform();
    final baseVersion = packageInfo.version;
    _setState(
      _state.copyWith(
        stage: HotUpdateStage.downloading,
        errorMessage: null,
        progress: 0,
      ),
    );
    try {
      final record = await hotUpdateService.downloadPatch(
        patch: targetPatch,
        baseVersion: baseVersion,
      );
      await hotUpdateStorage.saveDownloadedPatch(record);
      _setState(
        _state.copyWith(
          stage: HotUpdateStage.downloaded,
          downloaded: record,
          progress: 1,
        ),
      );
      return record;
    } catch (error, stackTrace) {
      Log.e('下载热更新失败: $error\n$stackTrace');
      _setState(
        _state.copyWith(
          stage: HotUpdateStage.failed,
          errorMessage: '$error',
          progress: 0,
        ),
      );
      rethrow;
    }
  }

  Future<void> markPatchApplied({
    required String patchVersion,
    required String baseVersion,
    bool success = true,
  }) async {
    if (!success) {
      _setState(_state.copyWith(stage: HotUpdateStage.failed));
      return;
    }

    final info = InstalledHotPatchInfo(
      patchVersion: patchVersion,
      baseVersion: baseVersion,
      appliedAt: DateTime.now(),
    );
    await hotUpdateStorage.saveInstalledPatch(info);
    await hotUpdateStorage.clearDownloadedPatch();
    _installedPatch = info;
    _setState(
      _state.copyWith(
        stage: HotUpdateStage.applied,
        downloaded: null,
        errorMessage: null,
      ),
    );
  }

  Future<void> resetDownloadedState() async {
    await hotUpdateStorage.clearDownloadedPatch();
    _setState(
      _state.copyWith(
        downloaded: null,
        stage: HotUpdateStage.noUpdate,
        errorMessage: null,
      ),
    );
  }

  void _setState(HotUpdateState newState) {
    _state = newState;
    notifyListeners();
  }
}
