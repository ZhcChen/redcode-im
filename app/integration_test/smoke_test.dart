import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:app/core/auth/auth_state.dart';
import 'package:app/core/storage/attachment_url_cache.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('flutter app integration smoke: auth bus preserves state order', (
    tester,
  ) async {
    final completer = Completer<List<AuthState>>();
    final received = <AuthState>[];
    final sub = AuthStateBus.stream.listen((state) {
      received.add(state);
      if (received.length == 2 && !completer.isCompleted) {
        completer.complete(List<AuthState>.unmodifiable(received));
      }
    });

    AuthStateBus.emit(AuthState.unauthenticated);
    AuthStateBus.emit(AuthState.authenticated);

    expect(await completer.future, const [
      AuthState.unauthenticated,
      AuthState.authenticated,
    ]);
    await sub.cancel();
  });

  testWidgets('flutter app integration smoke: attachment cache in async flow', (
    tester,
  ) async {
    final cache = AttachmentUrlCache.instance;
    cache.clear();

    cache.set('chat-attachment-1', '/tmp/chat-attachment-1');

    await tester.pump(const Duration(milliseconds: 1));

    expect(cache.get('chat-attachment-1'), '/tmp/chat-attachment-1');
  });
}
