import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/services/feedback_service.dart';
import 'package:app/core/storage/token_storage.dart';
import 'package:app/features/auth/models/auth_session.dart';
import 'package:app/features/auth/models/auth_user.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeTokenStorage extends TokenStorage {
  const _FakeTokenStorage(this._session);

  final AuthSession? _session;

  @override
  Future<AuthSession?> readSession() async => _session;
}

void main() {
  group('FeedbackService', () {
    test('throws when content is empty after trim', () async {
      final service = FeedbackService(
        tokenStorage: const _FakeTokenStorage(
          AuthSession(
            token: 'token-1',
            user: AuthUser(id: 'u-1', username: 'alice'),
          ),
        ),
      );

      await expectLater(
        service.submitFeedback(content: '   '),
        throwsA(
          isA<FeedbackServiceException>().having(
            (error) => error.message,
            'message',
            '反馈内容不能为空',
          ),
        ),
      );
    });

    test('throws when user session is missing', () async {
      final service = FeedbackService(
        tokenStorage: const _FakeTokenStorage(null),
      );

      await expectLater(
        service.submitFeedback(content: '需要改进体验'),
        throwsA(
          isA<FeedbackServiceException>().having(
            (error) => error.message,
            'message',
            '用户未登录',
          ),
        ),
      );
    });

    test('submitFeedback posts trimmed payload and returns on 200', () async {
      late http.Request captured;
      final service = FeedbackService(
        tokenStorage: const _FakeTokenStorage(
          AuthSession(
            token: 'token-2',
            user: AuthUser(id: 'u-2', username: 'bob'),
          ),
        ),
        client: MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        }),
      );

      await service.submitFeedback(
        content: '  语音播放有卡顿  ',
        contact: '  bob@example.com  ',
      );

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(captured.method, 'POST');
      expect(captured.url.path, '/feedbacks');
      expect(captured.headers['Authorization'], 'Bearer token-2');
      expect(body['content'], '语音播放有卡顿');
      expect(body['contact'], 'bob@example.com');
    });

    test('extracts backend message when non-200 response', () async {
      final service = FeedbackService(
        tokenStorage: const _FakeTokenStorage(
          AuthSession(
            token: 'token-3',
            user: AuthUser(id: 'u-3', username: 'charlie'),
          ),
        ),
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(jsonEncode({'message': '频率过高'})),
            429,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      await expectLater(
        service.submitFeedback(content: 'test'),
        throwsA(
          isA<FeedbackServiceException>().having(
            (error) => error.message,
            'message',
            '频率过高',
          ),
        ),
      );
    });

    test('uses fallback message when response body is not json', () async {
      final service = FeedbackService(
        tokenStorage: const _FakeTokenStorage(
          AuthSession(
            token: 'token-4',
            user: AuthUser(id: 'u-4', username: 'david'),
          ),
        ),
        client: MockClient((_) async => http.Response('bad gateway', 502)),
      );

      await expectLater(
        service.submitFeedback(content: 'test'),
        throwsA(
          isA<FeedbackServiceException>().having(
            (error) => error.message,
            'message',
            '反馈提交失败',
          ),
        ),
      );
    });
  });
}
