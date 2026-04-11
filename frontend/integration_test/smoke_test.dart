import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:frontend/core/auth/auth_state.dart';
import 'package:frontend/core/storage/attachment_url_cache.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('frontend integration smoke: auth bus can emit state', (tester) async {
    final completer = Completer<AuthState>();
    final sub = AuthStateBus.stream.listen((state) {
      if (!completer.isCompleted) {
        completer.complete(state);
      }
    });

    AuthStateBus.emit(AuthState.authenticated);

    final received = await completer.future;
    expect(received, AuthState.authenticated);
    await sub.cancel();
  });

  testWidgets('frontend integration smoke: attachment cache in async flow', (tester) async {
    final cache = AttachmentUrlCache.instance;
    cache.clear();

    cache.set('chat-attachment-1', '/tmp/chat-attachment-1');

    await tester.pump(const Duration(milliseconds: 1));

    expect(cache.get('chat-attachment-1'), '/tmp/chat-attachment-1');
  });
}
