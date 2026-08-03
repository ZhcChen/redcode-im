import 'dart:async';

import 'package:app/core/services/websocket_service.dart';
import 'package:app/core/storage/token_storage.dart';
import 'package:app/features/auth/models/auth_session.dart';
import 'package:app/features/auth/models/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

class _DelayedTokenStorage extends TokenStorage {
  _DelayedTokenStorage(this.session);

  final Completer<AuthSession?> session;
  int reads = 0;

  @override
  Future<AuthSession?> readSession() {
    reads += 1;
    return session.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('主动断连会阻止等待 token 的旧连接继续建立', () async {
    final session = Completer<AuthSession?>();
    final tokenStorage = _DelayedTokenStorage(session);
    final service = WebSocketService(
      tokenStorage: tokenStorage,
    );

    final connecting = service.connect();
    await service.connect();
    expect(service.status, ConnectionStatus.connecting);
    expect(tokenStorage.reads, 1);

    await service.disconnect();
    session.complete(
      const AuthSession(
        token: 'token',
        user: AuthUser(id: 'user-1', username: 'alice'),
      ),
    );
    await connecting;

    expect(service.status, ConnectionStatus.disconnected);
    expect(service.isConnected, isFalse);
    service.dispose();
  });
}
