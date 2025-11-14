import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'hot_update_manager.dart';

class HotPatchAssetBundle extends CachingAssetBundle {
  HotPatchAssetBundle({required this.hotUpdateManager, required this.fallback});

  final HotUpdateManager hotUpdateManager;
  final AssetBundle fallback;

  @override
  Future<ByteData> load(String key) async {
    final file = await hotUpdateManager.resolvePatchedAsset(key);
    if (file != null) {
      final bytes = await file.readAsBytes();
      return ByteData.view(bytes.buffer);
    }
    return fallback.load(key);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final file = await hotUpdateManager.resolvePatchedAsset(key);
    if (file != null) {
      return file.readAsString();
    }
    return fallback.loadString(key, cache: cache);
  }
}
