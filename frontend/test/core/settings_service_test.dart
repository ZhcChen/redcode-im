import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/settings_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('SettingsService', () {
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
