import 'dart:convert';
import 'dart:io';

import 'package:app/core/services/report_service.dart';
import 'package:app/core/storage/token_storage.dart';
import 'package:app/features/auth/models/auth_session.dart';
import 'package:app/features/auth/models/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeTokenStorage extends TokenStorage {
  const _FakeTokenStorage();

  @override
  Future<AuthSession?> readSession() async => const AuthSession(
    token: 'test-token',
    user: AuthUser(id: 'self-1', username: 'tester'),
  );
}

void main() {
  test('submitReport uploads, commits and creates report in order', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'report-service-test',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final screenshot = File('${tempDir.path}/evidence.png');
    await screenshot.writeAsBytes([1, 2, 3]);
    final calls = <String>[];

    final service = ReportService(
      tokenStorage: const _FakeTokenStorage(),
      client: MockClient((request) async {
        calls.add('${request.method} ${request.url}');
        if (request.url.path.endsWith('/reports/attachments/signature')) {
          expect(jsonDecode(request.body), {
            'filename': 'evidence.png',
            'content_type': 'image/png',
            'file_size': 3,
          });
          return http.Response(
            jsonEncode({
              'success': true,
              'key': 'reports/self-1/evidence.png',
              'signature': {
                'url': 'https://storage.test/evidence.png',
                'method': 'PUT',
                'headers': {'x-test': 'signed'},
              },
            }),
            200,
          );
        }
        if (request.url.host == 'storage.test') {
          expect(request.bodyBytes, [1, 2, 3]);
          expect(request.headers['x-test'], 'signed');
          return http.Response('', 200);
        }
        if (request.url.path.endsWith('/reports/attachments/commit')) {
          expect(jsonDecode(request.body), {
            'key': 'reports/self-1/evidence.png',
            'file_size': 3,
          });
          return http.Response(jsonEncode({'success': true}), 200);
        }
        if (request.url.path.endsWith('/reports')) {
          expect(jsonDecode(request.body), {
            'target_type': 'user',
            'target_id': 'user-2',
            'content': '骚扰信息',
            'attachment_keys': ['reports/self-1/evidence.png'],
          });
          return http.Response(jsonEncode({'success': true}), 200);
        }
        return http.Response('not found', 404);
      }),
    );

    await service.submitReport(
      targetType: 'user',
      targetId: 'user-2',
      content: '  骚扰信息  ',
      attachments: [screenshot],
    );

    expect(calls, [
      'POST http://127.0.0.1:8010/reports/attachments/signature',
      'PUT https://storage.test/evidence.png',
      'POST http://127.0.0.1:8010/reports/attachments/commit',
      'POST http://127.0.0.1:8010/reports',
    ]);
  });

  test(
    'submitReport rejects empty content and attachments before network',
    () async {
      final service = ReportService(
        tokenStorage: const _FakeTokenStorage(),
        client: MockClient((_) async => fail('不应发起网络请求')),
      );

      expect(
        () => service.submitReport(
          targetType: 'user',
          targetId: 'user-2',
          content: ' ',
          attachments: const [],
        ),
        throwsA(
          isA<ReportServiceException>().having(
            (error) => error.message,
            'message',
            '请输入举报内容',
          ),
        ),
      );
    },
  );
}
