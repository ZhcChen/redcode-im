import 'dart:typed_data';

import 'package:app/core/e2ee/secure_state_storage.dart';
import 'package:app/core/e2ee/core_bridge.dart';
import 'package:app/core/e2ee/device_profile.dart';
import 'package:app/core/e2ee/identity_trust.dart';
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
        protocolCore: _TestProtocolCore(),
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

    test('rejects invalid protocol state before persistence', () async {
      await expectLater(
        storage.write('account-a', const []),
        throwsA(isA<E2eeStateCorruptedException>()),
      );
      expect(keys.values, isEmpty);
      expect(states.values, isEmpty);
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

    test(
      'encrypts identity trust records outside ordinary app storage',
      () async {
        final record = E2eeIdentityTrustRecord(
          trusted: E2eeRootIdentity(
            userId: 'account-b',
            publicKey: Uint8List(32)..fillRange(0, 32, 7),
            fingerprint: Uint8List(32)..fillRange(0, 32, 9),
            protocolVersion: 1,
          ),
          trustedAt: DateTime.utc(2026, 8, 4),
        );

        await storage.writeRecords('account-a', {'account-b': record});

        expect(
          (await storage.readRecords(
            'account-a',
          ))['account-b']!.trusted.fingerprint,
          record.trusted.fingerprint,
        );
        expect(states.values.keys.single, endsWith('.identity-trust'));
        expect(
          String.fromCharCodes(states.values.values.single),
          isNot(contains('account-b')),
        );
      },
    );

    test('fails closed after identity trust ciphertext tampering', () async {
      final record = E2eeIdentityTrustRecord(
        trusted: E2eeRootIdentity(
          userId: 'account-b',
          publicKey: Uint8List(32)..fillRange(0, 32, 7),
          fingerprint: Uint8List(32)..fillRange(0, 32, 9),
          protocolVersion: 1,
        ),
        trustedAt: DateTime.utc(2026, 8, 4),
      );
      await storage.writeRecords('account-a', {'account-b': record});
      final encrypted = states.values.entries
          .singleWhere((entry) => entry.key.endsWith('.identity-trust'))
          .value;
      encrypted[encrypted.length - 1] ^= 0xff;

      await expectLater(
        storage.readRecords('account-a'),
        throwsA(isA<E2eeStateCorruptedException>()),
      );
    });

    test('encrypts device profile and removes it on account cleanup', () async {
      const profile = E2eeDeviceProfile(
        deviceId: 'device-a',
        deviceLabel: 'Alice iPhone',
        registered: true,
        keyPackagePublished: true,
        lastControlSequences: {'room-a': 7},
      );
      await storage.writeDeviceProfile('account-a', profile);

      expect(
        (await storage.readDeviceProfile('account-a'))!.lastControlSequences,
        {'room-a': 7},
      );
      expect(states.values.keys.single, endsWith('.device-profile'));
      expect(
        String.fromCharCodes(states.values.values.single),
        isNot(contains('device-a')),
      );

      await storage.delete('account-a');
      expect(await storage.readDeviceProfile('account-a'), isNull);
      expect(keys.values, isEmpty);
      expect(states.values, isEmpty);
    });
  });
}

class _TestProtocolCore implements E2eeProtocolCore {
  @override
  Uint8List newProtocolState() => Uint8List.fromList([1]);

  @override
  bool validateProtocolState(List<int> state) => state.isNotEmpty;
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
