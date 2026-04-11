import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/settings_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('SettingsService', () {
    test(
      'fetchGeneralSettings parses message runtime and falls back safely',
      () async {
        final okService = SettingsService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'app_name': 'Bear Chat',
                'message_runtime': {
                  'server_storage_mode': 'relay_only',
                  'content_audit_mode': 'e2ee',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final fallbackService = SettingsService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode(['invalid']),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final okSettings = await okService.fetchGeneralSettings();
        expect(okSettings.appName, 'Bear Chat');
        expect(okSettings.messageRuntime.serverStorageMode, 'relay_only');
        expect(okSettings.messageRuntime.contentAuditMode, 'e2ee');

        final fallbackSettings = await fallbackService.fetchGeneralSettings();
        expect(fallbackSettings.appName, '');
        expect(fallbackSettings.messageRuntime.serverStorageMode, 'persist');
        expect(fallbackSettings.messageRuntime.contentAuditMode, 'plaintext');
      },
    );

    test(
      'fetchAppName returns app_name on success and empty on non-200',
      () async {
        final successService = SettingsService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({'app_name': 'Bear Chat'}),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final failService = SettingsService(
          client: MockClient((_) async => http.Response('oops', 500)),
        );

        expect(await successService.fetchAppName(), 'Bear Chat');
        expect(await failService.fetchAppName(), '');
      },
    );

    test(
      'fetchAppName falls back to legacy app-name endpoint when general settings is empty',
      () async {
        final service = SettingsService(
          client: MockClient((request) async {
            if (request.url.path.endsWith('/settings/general')) {
              return http.Response(
                jsonEncode({
                  'app_name': '',
                  'message_runtime': {
                    'server_storage_mode': 'persist',
                    'content_audit_mode': 'plaintext',
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }

            if (request.url.path.endsWith('/settings/app-name')) {
              return http.Response(
                jsonEncode({'app_name': 'Legacy Name'}),
                200,
                headers: {'content-type': 'application/json'},
              );
            }

            return http.Response('not found', 404);
          }),
        );

        expect(await service.fetchAppName(), 'Legacy Name');
      },
    );

    test('message runtime exposes audit mode notice copy', () {
      const plaintextRelay = MessageRuntimeSettings(
        serverStorageMode: 'relay_only',
        contentAuditMode: 'plaintext',
      );
      const e2eePersist = MessageRuntimeSettings(
        serverStorageMode: 'persist',
        contentAuditMode: 'e2ee',
      );

      expect(plaintextRelay.runtimeNoticeTitle, '当前配置目标：明文可审计');
      expect(
        plaintextRelay.runtimeNoticeDescription,
        '服务器仅做实时转发且不保存聊天记录，消息内容仍可被服务端审计。',
      );
      expect(e2eePersist.runtimeNoticeTitle, '当前配置目标：端到端加密');
      expect(
        e2eePersist.runtimeNoticeDescription,
        '消息会保存在服务器，按当前配置目标不应被服务端审计。',
      );
    });

    test(
      'fetchPrivacyPolicy parses payload and throws on invalid format',
      () async {
        final okService = SettingsService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'title': '隐私协议',
                'content': 'content body',
                'updated_at': '2026-03-05T00:00:00Z',
              }),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final invalidService = SettingsService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode(['invalid']),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final doc = await okService.fetchPrivacyPolicy();
        expect(doc.title, '隐私协议');
        expect(doc.content, 'content body');
        expect(doc.updatedAt, isNotNull);

        await expectLater(
          invalidService.fetchPrivacyPolicy(),
          throwsA(isA<SettingsServiceException>()),
        );
      },
    );

    test(
      'fetchRequireCaptchaForLogin defaults to false on malformed payload',
      () async {
        final service = SettingsService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({'unexpected': true}),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        final requireCaptcha = await service.fetchRequireCaptchaForLogin();
        expect(requireCaptcha, isFalse);
      },
    );
  });
}
