import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../debug/debug_logger.dart';
import 'hot_patch_manifest.dart';
import 'hot_update_models.dart';
import 'hot_update_runtime.dart';

class LocalHotUpdateRuntime implements HotUpdateRuntime {
  LocalHotUpdateRuntime._(this._rootDir);

  final Directory _rootDir;

  static const _runtimeStateFile = 'runtime_state.json';

  static Future<LocalHotUpdateRuntime> create() async {
    final support = await getApplicationSupportDirectory();
    final runtimeDir = Directory(p.join(support.path, 'hot_runtime'));
    if (!await runtimeDir.exists()) {
      await runtimeDir.create(recursive: true);
    }
    return LocalHotUpdateRuntime._(runtimeDir);
  }

  @override
  Future<RuntimeState> loadState() async {
    final file = File(p.join(_rootDir.path, _runtimeStateFile));
    if (!await file.exists()) {
      return const RuntimeState();
    }
    try {
      final content = await file.readAsString();
      final Map<String, dynamic> json =
          jsonDecode(content) as Map<String, dynamic>;
      return RuntimeState(
        patchVersion: json['patch_version'] as String?,
        assetsDir: json['assets_dir'] as String?,
      );
    } catch (error) {
      Log.e('读取运行时状态失败: $error');
      return const RuntimeState();
    }
  }

  @override
  Future<RuntimeApplyResult> applyPatch({
    required HotPatchInfo patch,
    required HotUpdateDownloadRecord record,
  }) async {
    final tempDir = await Directory(
      p.join(_rootDir.path, 'tmp', patch.patchVersion),
    ).create(recursive: true);
    try {
      await _unzip(File(record.filePath), tempDir);
      final manifestFile = File(p.join(tempDir.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        throw StateError('补丁缺少 manifest.json');
      }
      final manifestJson =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      final manifest = HotPatchManifest.fromJson(manifestJson);
      if (manifest.baseVersion != record.baseVersion) {
        throw StateError(
          '补丁基线版本不匹配: ${manifest.baseVersion} vs ${record.baseVersion}',
        );
      }
      if (manifest.patchVersion != patch.patchVersion) {
        throw StateError('补丁版本不匹配: manifest=${manifest.patchVersion}');
      }

      final patchesDir = Directory(
        p.join(_rootDir.path, 'patches', patch.patchVersion),
      );
      if (await patchesDir.exists()) {
        await patchesDir.delete(recursive: true);
      }
      await patchesDir.parent.create(recursive: true);
      await tempDir.rename(patchesDir.path);

      final assetsDirName = manifest.assetsRoot ?? 'assets';
      final assetsDir = Directory(p.join(patchesDir.path, assetsDirName));
      final runtimeState = RuntimeState(
        patchVersion: patch.patchVersion,
        assetsDir: await assetsDir.exists() ? assetsDir.path : null,
      );
      await _writeRuntimeState(runtimeState);
      return RuntimeApplyResult(
        patchVersion: patch.patchVersion,
        assetsDir: runtimeState.assetsDir,
      );
    } catch (error) {
      Log.e('本地运行时应用补丁失败: $error');
      rethrow;
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  @override
  Future<void> rollbackActivePatch() async {
    final state = await loadState();
    if (state.patchVersion != null && state.patchVersion!.isNotEmpty) {
      final dir = Directory(
        p.join(_rootDir.path, 'patches', state.patchVersion!),
      );
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
    final file = File(p.join(_rootDir.path, _runtimeStateFile));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _unzip(File file, Directory target) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    for (final entry in archive) {
      final entryPath = p.join(target.path, entry.name);
      if (entry.isFile) {
        final outFile = File(entryPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(entry.content as List<int>);
      } else {
        await Directory(entryPath).create(recursive: true);
      }
    }
  }

  Future<void> _writeRuntimeState(RuntimeState state) async {
    final file = File(p.join(_rootDir.path, _runtimeStateFile));
    final data = <String, dynamic>{
      'patch_version': state.patchVersion,
      'assets_dir': state.assetsDir,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data));
  }
}
