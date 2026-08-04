import 'package:app/core/e2ee/secure_state_storage.dart';
import 'package:app/core/storage/token_storage.dart';
import 'package:app/features/auth/data/auth_repository.dart';
import 'package:app/features/auth/models/auth_session.dart';
import 'package:app/features/auth/models/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('logout destroys E2EE state for the authenticated account', () async {
    SharedPreferences.setMockInitialValues({});
    const tokenStorage = TokenStorage();
    final wrappingKeys = _MemoryWrappingKeys();
    final encryptedStates = _MemoryEncryptedStates();
    final e2eeStorage = E2eeSecureStateStorage(
      wrappingKeys: wrappingKeys,
      encryptedStates: encryptedStates,
    );
    const session = AuthSession(
      token: 'token-a',
      user: AuthUser(id: 'account-a', username: 'alice'),
    );
    await tokenStorage.saveSession(session);
    await e2eeStorage.write('account-a', [1, 2, 3]);

    final repository = AuthRepository(
      storage: tokenStorage,
      e2eeStateStorage: e2eeStorage,
      clearRuntimeData: () async {},
    );
    await repository.logout();

    expect(await tokenStorage.readSession(), isNull);
    expect(await e2eeStorage.read('account-a'), isNull);
    expect(wrappingKeys.values, isEmpty);
    expect(encryptedStates.values, isEmpty);
  });
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
