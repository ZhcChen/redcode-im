import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/version_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('VersionService', () {
    test(
      'checkLatest builds query params and parses version payload',
      () async {
        late Uri capturedUri;
        final client = MockClient((request) async {
          capturedUri = request.url;
          return http.Response(
            jsonEncode({
              'has_update': true,
              'current_version': '1.0.0',
              'version': {
                'id': 'ver-1',
                'platform': 'android',
                'version': '1.1.0',
                'build_number': 11,
                'channel': 'stable',
                'download_key': 'app/releases/1.1.0.apk',
                'mandatory': false,
                'is_active': true,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = VersionService(client: client);
        final result = await service.checkLatest(
          currentVersion: '1.0.0',
          channel: 'stable',
        );

        final expectedPlatform = Platform.isIOS ? 'ios' : 'android';
        expect(capturedUri.path, '/versions/latest');
        expect(capturedUri.queryParameters['platform'], expectedPlatform);
        expect(capturedUri.queryParameters['channel'], 'stable');
        expect(capturedUri.queryParameters['current_version'], '1.0.0');
        expect(result.hasUpdate, isTrue);
        expect(result.latest, isNotNull);
        expect(result.latest!.id, 'ver-1');
        expect(result.latest!.version, '1.1.0');
      },
    );

    test(
      'checkLatest returns hasUpdate=false when version payload is missing',
      () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({'has_update': true, 'current_version': '1.0.0'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = VersionService(client: client);
        final result = await service.checkLatest(currentVersion: '1.0.0');

        expect(result.hasUpdate, isFalse);
        expect(result.latest, isNull);
      },
    );

    test('checkLatest throws HttpException for non-200 responses', () async {
      final service = VersionService(
        client: MockClient((request) async => http.Response('oops', 502)),
      );

      expect(
        () => service.checkLatest(currentVersion: '1.0.0'),
        throwsA(isA<HttpException>()),
      );
    });

    test('fetchDownloadUrl returns signed url when payload is valid', () async {
      final service = VersionService(
        client: MockClient((request) async {
          expect(request.url.path, '/versions/download');
          expect(request.url.queryParameters['id'], 'ver-1');
          expect(request.url.queryParameters['expires_in_seconds'], '720');
          return http.Response(
            jsonEncode({
              'success': true,
              'download_url': 'https://example.com/ver-1.apk?sign=ok',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final url = await service.fetchDownloadUrl(
        id: 'ver-1',
        expiresInSeconds: 720,
      );

      expect(url, 'https://example.com/ver-1.apk?sign=ok');
    });

    test('fetchDownloadUrl throws StateError when success=false', () async {
      final service = VersionService(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({'success': false, 'message': 'sign expired'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      expect(
        () => service.fetchDownloadUrl(id: 'ver-2'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('sign expired'),
          ),
        ),
      );
    });
  });
}
