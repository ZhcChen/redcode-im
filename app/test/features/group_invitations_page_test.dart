import 'dart:convert';

import 'package:app/core/services/room_service.dart';
import 'package:app/core/storage/token_storage.dart';
import 'package:app/features/auth/models/auth_session.dart';
import 'package:app/features/auth/models/auth_user.dart';
import 'package:app/features/chat/group_invitations_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeTokenStorage extends TokenStorage {
  const _FakeTokenStorage();

  @override
  Future<AuthSession?> readSession() async => const AuthSession(
    token: 'token-room',
    user: AuthUser(id: 'u-1', username: 'alice'),
  );
}

void main() {
  testWidgets('accepts pending group invitation and refreshes its status', (
    tester,
  ) async {
    var accepted = false;
    final service = RoomService(
      tokenStorage: const _FakeTokenStorage(),
      client: MockClient((request) async {
        if (request.method == 'PATCH') {
          expect(
            request.url.path,
            '/rooms/room-1/invitations/invitation-1/respond',
          );
          expect(jsonDecode(request.body), {'status': 'accepted'});
          accepted = true;
          return http.Response('', 204);
        }
        return http.Response(
          jsonEncode({
            'invitations': [
              {
                'id': 'invitation-1',
                'room_id': 'room-1',
                'room_name': '产品讨论群',
                'room_avatar_url': null,
                'inviter_id': 'u-2',
                'inviter_name': 'Bob',
                'invitee_id': 'u-1',
                'message': '一起讨论下一版规划',
                'status': accepted ? 1 : 0,
                'invited_at': '2026-08-02T10:00:00Z',
                'responded_at': accepted ? '2026-08-02T10:01:00Z' : null,
                'expires_at': '2026-08-09T10:00:00Z',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(home: GroupInvitationsPage(roomService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('产品讨论群'), findsOneWidget);
    expect(find.text('Bob 邀请你加入群聊'), findsOneWidget);
    expect(find.text('接受'), findsOneWidget);

    await tester.tap(find.text('接受'));
    await tester.pumpAndSettle();

    expect(accepted, isTrue);
    expect(find.text('已接受'), findsOneWidget);
    expect(find.text('已加入群聊'), findsOneWidget);
  });
}
