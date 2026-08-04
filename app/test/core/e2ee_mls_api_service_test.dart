import 'dart:convert';
import 'dart:typed_data';

import 'package:app/core/e2ee/mls_api_service.dart';
import 'package:app/core/storage/token_storage.dart';
import 'package:app/features/auth/models/auth_session.dart';
import 'package:app/features/auth/models/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStorage tokenStorage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tokenStorage = const TokenStorage();
    await tokenStorage.saveSession(
      const AuthSession(
        token: 'token-a',
        user: AuthUser(id: 'account-a', username: 'alice'),
      ),
    );
  });

  test('registers only public device material with protocol version', () async {
    late Map<String, dynamic> payload;
    final service = E2eeMlsApiService(
      tokenStorage: tokenStorage,
      client: MockClient((request) async {
        expect(request.url.path, '/e2ee/mls/devices');
        expect(request.headers['authorization'], 'Bearer token-a');
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"status":"active"}', 200);
      }),
    );
    final material = E2eeDeviceRegistrationMaterial(
      state: Uint8List.fromList([99]),
      keyPackage: Uint8List.fromList([1]),
      rootPublicKey: Uint8List(32)..fillRange(0, 32, 2),
      rootFingerprint: Uint8List(32)..fillRange(0, 32, 3),
      credential: Uint8List.fromList([4]),
      credentialFingerprint: Uint8List(32)..fillRange(0, 32, 5),
      approvalPublicKey: Uint8List(32)..fillRange(0, 32, 6),
    );

    await service.registerDevice(
      deviceId: 'device-a',
      deviceLabel: 'Alice iPhone',
      material: material,
    );

    expect(payload['protocol_version'], 1);
    expect(payload['root_public_key'], base64Encode(material.rootPublicKey));
    expect(payload.containsKey('state'), isFalse);
    expect(payload.containsKey('key_package'), isFalse);
  });

  test('sends RCML ciphertext without plaintext summary', () async {
    late Map<String, dynamic> payload;
    final service = E2eeMlsApiService(
      tokenStorage: tokenStorage,
      client: MockClient((request) async {
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"message":{"id":"message-a"}}', 200);
      }),
    );

    await service.sendEncryptedMessage(
      roomId: 'room-a',
      senderDeviceId: 'device-a',
      epoch: 2,
      ciphertext: Uint8List.fromList([82, 67, 77, 76]),
      idempotencyKey: 'request-a',
      controlMessageId: 'control-a',
    );

    expect(payload.containsKey('content'), isFalse);
    expect(payload.containsKey('content_summary'), isFalse);
    expect(payload['encryption_metadata'], {
      'protocol': 'mls',
      'version': 1,
      'epoch': 2,
      'sender_device_id': 'device-a',
      'content_type': 'application',
      'control_message_id': 'control-a',
    });
  });

  test('preserves runtime conflicts for fail-closed handling', () async {
    final service = E2eeMlsApiService(
      tokenStorage: tokenStorage,
      client: MockClient((_) async => http.Response('{"code":40902}', 409)),
    );

    await expectLater(
      service.getRoomEpoch('room-a'),
      throwsA(
        isA<E2eeMlsApiException>().having(
          (error) => error.isRuntimeConflict,
          'isRuntimeConflict',
          isTrue,
        ),
      ),
    );
  });

  test(
    'lists control messages in sequence and acknowledges consumption',
    () async {
      final requests = <http.Request>[];
      final service = E2eeMlsApiService(
        tokenStorage: tokenStorage,
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return http.Response(
              '[{"id":"control-a","epoch":2,"content_type":"commit",'
              '"envelope":"UkNNTA==","sequence_no":7}]',
              200,
            );
          }
          return http.Response('{"consumed":true}', 200);
        }),
      );

      final controls = await service.listControlMessages(
        roomId: 'room-a',
        deviceId: 'device-a',
        afterSequence: 6,
      );
      await service.consumeControlMessage(
        roomId: 'room-a',
        messageId: controls.single.id,
        deviceId: 'device-a',
      );

      expect(controls.single.sequenceNo, 7);
      expect(requests.first.url.queryParameters['after_sequence'], '6');
      expect(requests.last.url.path, endsWith('/control-a/consume'));
    },
  );
}
