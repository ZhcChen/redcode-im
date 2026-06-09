import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/services/upload_policy_service.dart';
import 'package:app/core/storage/token_storage.dart';
import 'package:app/features/auth/models/auth_session.dart';
import 'package:app/features/auth/models/auth_user.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTokenStorage extends TokenStorage {
  const _FakeTokenStorage(this._session);

  final AuthSession? _session;

  @override
  Future<AuthSession?> readSession() async => _session;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UploadPolicy', () {
    test('builtinV1 provides sorted whitelist and sane limits', () {
      final policy = UploadPolicy.builtinV1();

      expect(policy.version, 'builtin-v1');
      expect(policy.maxTotalSizeMb, greaterThan(0));
      expect(policy.maxAttachmentsPerMessage, greaterThan(0));
      expect(policy.mimeWhitelist, isNotEmpty);
      expect(policy.mimeWhitelist, equals([...policy.mimeWhitelist]..sort()));
      expect(policy.maxTotalBytes(), policy.maxTotalSizeMb * 1024 * 1024);
    });

    test('fromJson normalizes mime lists and falls back on invalid fields', () {
      final policy = UploadPolicy.fromJson({
        'version': 'custom-v2',
        'max_total_size_mb': 256,
        'max_attachments_per_message': 5,
        'max_size_mb_by_part_type': {
          'image': 9.0,
          'video': 200,
          'audio': 'invalid',
        },
        'mime_by_part_type': {
          'image': ['IMAGE/PNG', ' image/png ', 'image/jpeg'],
          'audio': ['audio/mp4', 123],
        },
        'mime_whitelist': ['IMAGE/PNG', 'image/png', 'audio/mp4', ''],
        'audio_only': {
          'enabled': false,
          'force_single_attachment': false,
          'allow_text': true,
        },
      });

      expect(policy.version, 'custom-v2');
      expect(policy.maxTotalSizeMb, 256);
      expect(policy.maxAttachmentsPerMessage, 5);
      expect(policy.maxSizeMbByPartType['image'], 9);
      expect(policy.maxSizeMbByPartType['video'], 200);
      expect(
        policy.maxSizeMbByPartType['audio'],
        UploadPolicy.builtinV1().maxSizeMbByPartType['audio'],
      );
      expect(policy.mimeByPartType['image'], ['image/jpeg', 'image/png']);
      expect(policy.mimeByPartType['audio'], ['audio/mp4']);
      expect(policy.mimeWhitelist, ['audio/mp4', 'image/png']);
      expect(policy.audioOnly.enabled, isFalse);
      expect(policy.audioOnly.allowText, isTrue);
    });

    test('helper methods validate part-size and mime matching', () {
      final policy = UploadPolicy.fromJson({
        'max_size_mb_by_part_type': {'image': 6},
        'mime_by_part_type': {
          'image': ['image/png'],
        },
        'mime_whitelist': ['image/png'],
      });

      expect(policy.maxSizeBytesForPartType('image'), 6 * 1024 * 1024);
      expect(policy.maxSizeBytesForPartType('unknown'), isNull);
      expect(policy.isMimeAllowedForPartType('image', ' IMAGE/PNG '), isTrue);
      expect(policy.isMimeAllowedForPartType('image', 'image/jpeg'), isFalse);
    });
  });

  group('UploadPolicyService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns builtin policy when session is missing', () async {
      final service = UploadPolicyService(
        tokenStorage: const _FakeTokenStorage(null),
        client: MockClient(
          (_) async => throw StateError('client should not be called'),
        ),
      );

      final policy = await service.getPolicy();

      expect(policy.version, UploadPolicy.builtinV1().version);
      expect(policy.audioOnly.enabled, isTrue);
    });

    test(
      'loads policy from API when logged in and response is valid',
      () async {
        late Uri capturedUri;
        late Map<String, String> capturedHeaders;
        final service = UploadPolicyService(
          tokenStorage: const _FakeTokenStorage(
            AuthSession(
              token: 'token-policy',
              user: AuthUser(id: 'u-1', username: 'alice'),
            ),
          ),
          client: MockClient((request) async {
            capturedUri = request.url;
            capturedHeaders = request.headers;
            return http.Response(
              '''
            {
              "version": "remote-v1",
              "max_total_size_mb": 120,
              "max_attachments_per_message": 8,
              "max_size_mb_by_part_type": {"image": 8, "video": 80, "audio": 16, "file": 32},
              "mime_by_part_type": {"image": ["image/png"], "video": ["video/mp4"], "audio": ["audio/mp4"], "file": ["application/pdf"]},
              "mime_whitelist": ["image/png", "video/mp4", "audio/mp4", "application/pdf"],
              "audio_only": {"enabled": true, "force_single_attachment": false, "allow_text": true}
            }
            ''',
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        final policy = await service.getPolicy(forceRefresh: true);

        expect(capturedUri.path, '/system/upload-policy');
        expect(capturedHeaders['Authorization'], 'Bearer token-policy');
        expect(policy.version, 'remote-v1');
        expect(policy.maxTotalSizeMb, 120);
        expect(policy.maxSizeMbByPartType['image'], 8);
        expect(policy.audioOnly.forceSingleAttachment, isFalse);
        expect(policy.audioOnly.allowText, isTrue);
      },
    );
  });
}
