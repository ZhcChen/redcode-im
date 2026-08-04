import 'dart:typed_data';

import 'package:app/core/e2ee/device_lifecycle.dart';
import 'package:app/core/e2ee/device_profile.dart';
import 'package:app/core/e2ee/direct_message_coordinator.dart';
import 'package:app/core/e2ee/identity_service.dart';
import 'package:app/core/e2ee/identity_trust.dart';
import 'package:app/core/e2ee/mls_api_service.dart';
import 'package:app/core/e2ee/secure_state_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redcode_e2ee_core/redcode_e2ee_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'replays interrupted bootstrap before encrypting without plaintext API fields',
    () async {
      const core = RedcodeE2eeSession();
      final sender = core.initialize('account-a/device-a');
      final peer = core.initialize('account-b/device-b');
      final storage = E2eeSecureStateStorage(
        wrappingKeys: _MemoryWrappingKeys(),
        encryptedStates: _MemoryEncryptedStates(),
      );
      const profile = E2eeDeviceProfile(
        deviceId: 'device-a',
        deviceLabel: 'Alice iPhone',
        registered: true,
        keyPackagePublished: true,
      );
      await storage.write('account-a', sender.field(0));
      await storage.writeDeviceProfile('account-a', profile);
      final api = _FakeApi(peer.field(1));
      final ids = <String>['commit-a', 'welcome-a', 'bootstrap-a', 'message-a'];
      final coordinator = E2eeDirectMessageCoordinator(
        storage: storage,
        lifecycle: _FakeLifecycle(
          E2eeDeviceContext(profile: profile, state: sender.field(0)),
        ),
        identityService: _FakeIdentityService(),
        api: api,
        core: core,
        newId: () => ids.removeAt(0),
      );

      await expectLater(
        coordinator.sendText(
          accountId: 'account-a',
          deviceLabel: 'ignored',
          roomId: 'room-a',
          peerUserId: 'account-b',
          text: 'first attempt',
        ),
        throwsA(isA<E2eeMlsApiException>()),
      );
      expect(await storage.readPendingOperation('account-a'), isNotNull);

      final response = await coordinator.sendText(
        accountId: 'account-a',
        deviceLabel: 'ignored',
        roomId: 'room-a',
        peerUserId: 'account-b',
        text: 'secret text',
      );

      expect(response['message'], {'id': 'server-message'});
      expect(api.controlIds, [
        'commit-a',
        'welcome-a',
        'commit-a',
        'welcome-a',
      ]);
      expect(api.claimCalls, 1);
      expect(api.sentCiphertext, isNotEmpty);
      expect(await storage.readPendingOperation('account-a'), isNull);
      final restoredProfile = await storage.readDeviceProfile('account-a');
      expect(restoredProfile!.lastCommitMessageIds['room-a'], 'commit-a');
    },
  );
}

class _FakeLifecycle extends E2eeDeviceLifecycle {
  _FakeLifecycle(this.context);
  final E2eeDeviceContext context;

  @override
  Future<E2eeDeviceContext> ensureReady({
    required String accountId,
    required String deviceLabel,
  }) async => context;
}

class _FakeIdentityService extends E2eeIdentityService {
  @override
  Future<E2eeRootIdentity> fetchRootIdentity(String userId) async =>
      E2eeRootIdentity(
        userId: userId,
        publicKey: Uint8List(32)..fillRange(0, 32, 3),
        fingerprint: Uint8List(32)..fillRange(0, 32, 4),
        protocolVersion: 1,
      );
}

class _FakeApi extends E2eeMlsApiService {
  _FakeApi(this.peerKeyPackage);
  final Uint8List peerKeyPackage;
  final controlIds = <String>[];
  var claimCalls = 0;
  var activeEpoch = 0;
  var failWelcomeOnce = true;
  Uint8List sentCiphertext = Uint8List(0);

  @override
  Future<E2eeRoomEpoch> getRoomEpoch(String roomId) async => E2eeRoomEpoch(
    membershipRevision: 1,
    activeEpoch: activeEpoch,
    status: activeEpoch == 0 ? 'pending' : 'active',
  );

  @override
  Future<List<E2eePeerDevice>> listPeerDevices(String userId) async => [
    E2eePeerDevice(
      id: 'device-b',
      protocolVersion: 1,
      credentialFingerprint: Uint8List(32),
    ),
  ];

  @override
  Future<E2eeClaimedKeyPackage> claimKeyPackage({
    required String roomId,
    required String consumerDeviceId,
    required String targetDeviceId,
  }) async {
    claimCalls++;
    return E2eeClaimedKeyPackage(
      id: 'package-b',
      deviceId: targetDeviceId,
      keyPackage: peerKeyPackage,
    );
  }

  @override
  Future<Map<String, dynamic>> submitControlMessage({
    required String roomId,
    required String messageId,
    required int epoch,
    required int membershipRevision,
    required String senderDeviceId,
    required String contentType,
    required Uint8List envelope,
    String? recipientDeviceId,
    String? idempotencyKey,
  }) async {
    controlIds.add(messageId);
    if (contentType == 'commit') activeEpoch = epoch;
    if (contentType == 'welcome' && failWelcomeOnce) {
      failWelcomeOnce = false;
      throw const E2eeMlsApiException('temporary');
    }
    return {'id': messageId};
  }

  @override
  Future<Map<String, dynamic>> sendEncryptedMessage({
    required String roomId,
    required String senderDeviceId,
    required int epoch,
    required Uint8List ciphertext,
    required String idempotencyKey,
    String? controlMessageId,
  }) async {
    sentCiphertext = ciphertext;
    return {
      'message': {'id': 'server-message'},
    };
  }
}

class _MemoryWrappingKeys implements E2eeWrappingKeyStore {
  final values = <String, List<int>>{};

  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<List<int>?> read(String key) async => values[key]?.toList();
  @override
  Future<void> write(String key, List<int> value) async =>
      values[key] = value.toList();
}

class _MemoryEncryptedStates implements E2eeEncryptedStateStore {
  final values = <String, List<int>>{};

  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<List<int>?> read(String key) async => values[key]?.toList();
  @override
  Future<void> write(String key, List<int> value) async =>
      values[key] = value.toList();
}
