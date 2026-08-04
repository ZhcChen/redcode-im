import 'dart:convert';

import 'package:app/core/e2ee/device_lifecycle.dart';
import 'package:app/core/e2ee/identity_service.dart';
import 'package:app/core/e2ee/mls_api_service.dart';
import 'package:app/core/e2ee/secure_state_storage.dart';
import 'package:app/core/storage/token_storage.dart';
import 'package:app/features/auth/models/auth_session.dart';
import 'package:app/features/auth/models/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'retries interrupted provisioning without replacing device identity',
    () async {
      SharedPreferences.setMockInitialValues({});
      const tokenStorage = TokenStorage();
      await tokenStorage.saveSession(
        const AuthSession(
          token: 'token-a',
          user: AuthUser(id: 'account-a', username: 'alice'),
        ),
      );
      var registerCalls = 0;
      var publishCalls = 0;
      final registeredDeviceIds = <String>[];
      final client = MockClient((request) async {
        if (request.url.path == '/e2ee/mls/identities/account-a') {
          return http.Response('{"message":"missing"}', 404);
        }
        if (request.url.path == '/e2ee/mls/devices') {
          registerCalls++;
          registeredDeviceIds.add(
            (jsonDecode(request.body) as Map<String, dynamic>)['device_id']
                as String,
          );
          return http.Response('{"status":"active"}', 200);
        }
        if (request.url.path.endsWith('/key-packages')) {
          publishCalls++;
          if (publishCalls == 1) {
            return http.Response('{"message":"temporary"}', 503);
          }
          return http.Response('{"inserted":1}', 200);
        }
        return http.Response('{"message":"unexpected"}', 500);
      });
      final storage = E2eeSecureStateStorage(
        wrappingKeys: _MemoryWrappingKeys(),
        encryptedStates: _MemoryEncryptedStates(),
      );
      final lifecycle = E2eeDeviceLifecycle(
        storage: storage,
        identityService: E2eeIdentityService(
          tokenStorage: tokenStorage,
          client: client,
        ),
        api: E2eeMlsApiService(tokenStorage: tokenStorage, client: client),
        newDeviceId: () => '018f5be3-3277-7d45-a6f3-bd2ebc89f321',
      );

      await expectLater(
        lifecycle.ensureReady(
          accountId: 'account-a',
          deviceLabel: 'Alice iPhone',
        ),
        throwsA(isA<E2eeMlsApiException>()),
      );
      final stateAfterFailure = await storage.read('account-a');
      final profileAfterFailure = await storage.readDeviceProfile('account-a');
      expect(profileAfterFailure!.registered, isTrue);
      expect(profileAfterFailure.keyPackagePublished, isFalse);

      final ready = await lifecycle.ensureReady(
        accountId: 'account-a',
        deviceLabel: 'ignored replacement label',
      );

      expect(ready.profile.deviceId, '018f5be3-3277-7d45-a6f3-bd2ebc89f321');
      expect(ready.profile.deviceLabel, 'Alice iPhone');
      expect(ready.profile.keyPackagePublished, isTrue);
      expect(registerCalls, 1);
      expect(publishCalls, 2);
      expect(registeredDeviceIds, ['018f5be3-3277-7d45-a6f3-bd2ebc89f321']);
      expect(ready.state, isNot(equals(stateAfterFailure)));
    },
  );
}

class _MemoryWrappingKeys implements E2eeWrappingKeyStore {
  final values = <String, List<int>>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<List<int>?> read(String key) async => values[key]?.toList();

  @override
  Future<void> write(String key, List<int> value) async {
    values[key] = value.toList();
  }
}

class _MemoryEncryptedStates implements E2eeEncryptedStateStore {
  final values = <String, List<int>>{};

  @override
  Future<void> delete(String accountNamespace) async =>
      values.remove(accountNamespace);

  @override
  Future<List<int>?> read(String accountNamespace) async =>
      values[accountNamespace]?.toList();

  @override
  Future<void> write(String accountNamespace, List<int> value) async {
    values[accountNamespace] = value.toList();
  }
}
