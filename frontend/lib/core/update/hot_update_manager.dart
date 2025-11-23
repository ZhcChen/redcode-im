import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:package_info_plus/package_info_plus.dart';

import '../debug/debug_logger.dart';
import 'hot_update_models.dart';
import 'hot_update_reporter.dart';
import 'hot_update_runtime.dart';
import 'hot_update_service.dart';
import 'hot_update_storage.dart';

class HotUpdateManager extends ChangeNotifier {
  HotUpdateManager({
    required this.hotUpdateService,
    required this.hotUpdateStorage,
    required this.runtime,
    required this.reporter,
  });

  final HotUpdateService hotUpdateService;
  final HotUpdateStorage hotUpdateStorage;
  final HotUpdateRuntime runtime;
  final HotUpdateReporter reporter;

  HotUpdateState _state = const HotUpdateState();
  InstalledHotPatchInfo? _installedPatch;
  PackageInfo? _packageInfo;
  String? _activeAssetsDir;

  HotUpdateState get state => _state;
  InstalledHotPatchInfo? get installedPatch => _installedPatch;
  String? get activeAssetsDir => _activeAssetsDir;

  Future<void> initialize() async {
    _installedPatch = hotUpdateStorage.loadInstalledPatch();
    final downloaded = hotUpdateStorage.loadDownloadedPatch();
    _packageInfo = await PackageInfo.fromPlatform();

    final runtimeState = await runtime.loadState();
    _activeAssetsDir = runtimeState.assetsDir;

    if (downloaded != null) {
      _setState(
        _state.copyWith(
          stage: HotUpdateStage.downloaded,
          downloaded: downloaded,
          patch: _state.patch,
        ),
      );
    } else if (_installedPatch != null && _activeAssetsDir != null) {
      _setState(_state.copyWith(stage: HotUpdateStage.applied));
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
      await _reportEvent(
        eventType: 'download_success',
        baseVersion: record.baseVersion,
        patchVersion: targetPatch.patchVersion,
        channel: targetPatch.channel,
      );
      _setState(
        _state.copyWith(
          stage: HotUpdateStage.downloaded,
          downloaded: record,
          progress: 1,
        ),
      );
      await _applyDownloadedPatch(targetPatch, record);
      return record;
    } catch (error, stackTrace) {
      Log.e('下载热更新失败: $error\n$stackTrace');
      if (targetPatch != null) {
        await _reportEvent(
          eventType: 'download_failed',
          baseVersion: baseVersion,
          patchVersion: targetPatch.patchVersion,
          channel: targetPatch.channel,
          message: '$error',
        );
      }
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

  Future<File?> resolvePatchedAsset(String assetKey) async {
    final assetsDir = _activeAssetsDir;
    if (assetsDir == null || assetKey.isEmpty) {
      return null;
    }
    final normalizedKey = assetKey.replaceAll('\\', '/');
    final fullPath = p.join(assetsDir, normalizedKey);
    final file = File(fullPath);
    return await file.exists() ? file : null;
  }

  Future<void> rollbackActivePatch({String? reason}) async {
    try {
      await runtime.rollbackActivePatch();
    } catch (error, stackTrace) {
      Log.e('回滚热更新失败: $error\n$stackTrace');
    }
    final previousPatch = _installedPatch;
    await hotUpdateStorage.clearInstalledPatch();
    await hotUpdateStorage.clearDownloadedPatch();
    _installedPatch = null;
    _activeAssetsDir = null;
    final rollbackBase = previousPatch?.baseVersion;
    final rollbackPatch =
        previousPatch?.patchVersion ?? _state.patch?.patchVersion;
    final rollbackChannel = _state.patch?.channel;
    if (rollbackBase != null && rollbackPatch != null) {
      await _reportEvent(
        eventType: 'rollback',
        baseVersion: rollbackBase,
        patchVersion: rollbackPatch,
        channel: rollbackChannel,
        message: reason,
      );
    }
    _setState(
      _state.copyWith(
        stage: HotUpdateStage.noUpdate,
        downloaded: null,
        errorMessage: reason,
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

  Future<void> _applyDownloadedPatch(
    HotPatchInfo patch,
    HotUpdateDownloadRecord record,
  ) async {
    _setState(
      _state.copyWith(
        stage: HotUpdateStage.applying,
        downloaded: record,
        errorMessage: null,
        patch: patch,
      ),
    );

    try {
      final runtimeResult = await runtime.applyPatch(
        patch: patch,
        record: record,
      );
      final info = InstalledHotPatchInfo(
        patchVersion: patch.patchVersion,
        baseVersion: record.baseVersion,
        appliedAt: DateTime.now(),
      );
      await hotUpdateStorage.saveInstalledPatch(info);
      await hotUpdateStorage.clearDownloadedPatch();
      _installedPatch = info;
      _activeAssetsDir = runtimeResult.assetsDir;
      await _reportEvent(
        eventType: 'apply_success',
        baseVersion: record.baseVersion,
        patchVersion: patch.patchVersion,
        channel: patch.channel,
      );
      _setState(
        _state.copyWith(
          stage: HotUpdateStage.applied,
          downloaded: null,
          errorMessage: null,
          patch: patch,
        ),
      );
    } catch (error, stackTrace) {
      Log.e('应用热更新失败: $error\n$stackTrace');
      await runtime.rollbackActivePatch();
      await hotUpdateStorage.clearInstalledPatch();
      _activeAssetsDir = null;
      _installedPatch = null;
      await _reportEvent(
        eventType: 'apply_failed',
        baseVersion: record.baseVersion,
        patchVersion: patch.patchVersion,
        channel: patch.channel,
        message: '$error',
      );
      _setState(
        _state.copyWith(
          stage: HotUpdateStage.failed,
          errorMessage: '$error',
          patch: patch,
        ),
      );
      rethrow;
    }
  }

  void _setState(HotUpdateState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> _reportEvent({
    required String eventType,
    required String baseVersion,
    required String patchVersion,
    String? channel,
    String? message,
  }) async {
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      final clientId = await hotUpdateStorage.ensureClientId();
      await reporter.reportEvent(
        platform: platform,
        baseVersion: baseVersion,
        patchVersion: patchVersion,
        eventType: eventType,
        channel: channel,
        clientId: clientId,
        message: message,
      );
    } catch (_) {
      // 静默失败
    }
  }
}
