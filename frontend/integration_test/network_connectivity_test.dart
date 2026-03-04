import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/environment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'frontend integration network: backend healthz reachable via API_BASE_URL',
    (tester) async {
      final uri = Uri.parse('${EnvironmentConfig.apiBaseUrl}/healthz');
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);

      try {
        final request =
            await client.getUrl(uri).timeout(const Duration(seconds: 10));
        final response =
            await request.close().timeout(const Duration(seconds: 10));
        final body = await response.transform(utf8.decoder).join();

        expect(response.statusCode, 200);
        expect(body.trim(), 'ok');
      } finally {
        client.close(force: true);
      }
    },
  );

  testWidgets(
    'frontend integration network: websocket handshake reachable via WS_URL',
    (tester) async {
      final socket = await WebSocket.connect(EnvironmentConfig.wsUrl)
          .timeout(const Duration(seconds: 10));

      try {
        expect(socket.readyState, WebSocket.open);
      } finally {
        await socket.close();
      }
    },
  );
}
