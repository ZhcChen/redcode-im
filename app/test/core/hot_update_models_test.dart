import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/update/hot_patch_manifest.dart';
import 'package:app/core/update/hot_update_models.dart';

void main() {
  group('hot update models', () {
    test('HotPatchInfo fromJson/toJson keeps key fields', () {
      final info = HotPatchInfo.fromJson({
        'id': 'patch-1',
        'platform': 'android',
        'app_version_id': 'app-1',
        'patch_version': '1.0.1',
        'channel': 'stable',
        'download_key': 'patches/1.0.1.zip',
        'mandatory': true,
        'is_active': true,
        'rollout_percentage': 100,
        'created_at': '2026-03-01T00:00:00Z',
        'updated_at': '2026-03-01T00:00:00Z',
      });

      final json = info.toJson();
      expect(json['id'], 'patch-1');
      expect(json['mandatory'], isTrue);
      expect(json['patch_version'], '1.0.1');
    });

    test('HotUpdateState copyWith updates state and hasError', () {
      const initial = HotUpdateState();
      final failed = initial.copyWith(
        stage: HotUpdateStage.failed,
        errorMessage: 'checksum mismatch',
      );

      expect(failed.stage, HotUpdateStage.failed);
      expect(failed.hasError, isTrue);
    });

    test('HotPatchManifest extracts assets root from payloads', () {
      final manifest = HotPatchManifest.fromJson({
        'schema': 1,
        'base_version': '1.0.0',
        'patch_version': '1.0.1',
        'payloads': {
          'assets': {
            'root': 'patch-assets',
          }
        }
      });

      expect(manifest.assetsRoot, 'patch-assets');
      expect(manifest.patchVersion, '1.0.1');
    });
  });
}
