import 'dart:typed_data';

import 'package:app/core/e2ee/identity_trust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final clock = DateTime.utc(2026, 8, 4, 12);

  test('TOFU trusts first use and keeps matching identity trusted', () async {
    final store = _MemoryTrustStore();
    final manager = E2eeIdentityTrustManager(store: store, now: () => clock);
    final identity = _identity('bob', 1);

    expect(
      await manager.observe('alice', identity),
      E2eeIdentityTrustDecision.firstUseTrusted,
    );
    expect(
      await manager.observe('alice', identity),
      E2eeIdentityTrustDecision.trusted,
    );
    expect((await manager.record('alice', 'bob'))!.isChanged, isFalse);
  });

  test('identity change blocks until explicitly retrusted', () async {
    final store = _MemoryTrustStore();
    final manager = E2eeIdentityTrustManager(store: store, now: () => clock);
    await manager.observe('alice', _identity('bob', 1));

    expect(
      await manager.observe('alice', _identity('bob', 2)),
      E2eeIdentityTrustDecision.identityChanged,
    );
    final changed = await manager.record('alice', 'bob');
    expect(changed!.isChanged, isTrue);
    expect(changed.trusted.fingerprint.first, 1);
    expect(changed.pending!.fingerprint.first, 2);
    await expectLater(
      manager.requireTrusted('alice', 'bob'),
      throwsA(isA<E2eeIdentityNotTrustedException>()),
    );

    final accepted = await manager.retrust('alice', 'bob');
    expect(accepted.isChanged, isFalse);
    expect(accepted.trusted.fingerprint.first, 2);
    expect((await manager.requireTrusted('alice', 'bob')).isChanged, isFalse);
  });

  test('trust registries stay account scoped and round trip', () async {
    final store = _MemoryTrustStore();
    final manager = E2eeIdentityTrustManager(store: store, now: () => clock);
    await manager.observe('alice', _identity('bob', 1));

    expect(await manager.record('carol', 'bob'), isNull);
    final encoded = E2eeIdentityTrustManager.encodeRegistry(
      await store.readRecords('alice'),
    );
    final decoded = E2eeIdentityTrustManager.decodeRegistry(encoded);
    expect(decoded['bob']!.trusted.fingerprint.first, 1);
  });

  test('security code is symmetric and has a stable cross-client vector', () {
    final alice = _identity('alice', 1);
    final bob = _identity('bob', 2);

    final first = E2eeIdentityTrustManager.securityCode(alice, bob);
    expect(E2eeIdentityTrustManager.securityCode(bob, alice), first);
    expect(
      first,
      'C05E 7601 822E A6B9 CEC2 FF90 D63C 6F35 '
      '47D9 29F4 DC88 678A 9605 AF94 4A1A EEF4',
    );
  });
}

E2eeRootIdentity _identity(String userId, int marker) => E2eeRootIdentity(
  userId: userId,
  publicKey: Uint8List(32)..fillRange(0, 32, marker + 10),
  fingerprint: Uint8List(32)..fillRange(0, 32, marker),
  protocolVersion: 1,
);

class _MemoryTrustStore implements E2eeIdentityTrustStore {
  final values = <String, Map<String, E2eeIdentityTrustRecord>>{};

  @override
  Future<void> deleteRecords(String accountId) async =>
      values.remove(accountId);

  @override
  Future<Map<String, E2eeIdentityTrustRecord>> readRecords(
    String accountId,
  ) async => Map.of(values[accountId] ?? const {});

  @override
  Future<void> writeRecords(
    String accountId,
    Map<String, E2eeIdentityTrustRecord> records,
  ) async => values[accountId] = Map.of(records);
}
