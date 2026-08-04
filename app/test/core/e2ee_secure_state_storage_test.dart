import 'package:app/core/e2ee/secure_state_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('E2eeSecureStateStorage', () {
    late _MemoryWrappingKeys keys;
    late _MemoryEncryptedStates states;
    late E2eeSecureStateStorage storage;

    setUp(() {
      keys = _MemoryWrappingKeys();
      states = _MemoryEncryptedStates();
      storage = E2eeSecureStateStorage(
        wrappingKeys: keys,
        encryptedStates: states,
      );
    });

    test('encrypts and restores account-scoped protocol state', () async {
      await storage.write('account-a', [1, 2, 3, 4, 255]);

      expect(await storage.read('account-a'), [1, 2, 3, 4, 255]);
      expect(await storage.read('account-b'), isNull);
      expect(
        states.values.values.single,
        isNot(containsAllInOrder([1, 2, 3, 4, 255])),
      );
    });

    test('fails closed after ciphertext tampering', () async {
      await storage.write('account-a', [1, 2, 3]);
      final encrypted = states.values.values.single;
      encrypted[encrypted.length - 1] ^= 0xff;

      await expectLater(
        storage.read('account-a'),
        throwsA(isA<E2eeStateCorruptedException>()),
      );
    });

    test('fails closed when wrapping key is missing', () async {
      await storage.write('account-a', [1, 2, 3]);
      keys.values.clear();

      await expectLater(
        storage.read('account-a'),
        throwsA(isA<E2eeStateCorruptedException>()),
      );
    });

    test('deletes ciphertext and wrapping key for one account', () async {
      await storage.write('account-a', [1]);
      await storage.write('account-b', [2]);

      await storage.delete('account-a');

      expect(await storage.read('account-a'), isNull);
      expect(await storage.read('account-b'), [2]);
      expect(keys.values, hasLength(1));
      expect(states.values, hasLength(1));
    });
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
