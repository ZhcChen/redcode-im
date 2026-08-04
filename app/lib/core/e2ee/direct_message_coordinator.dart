import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:redcode_e2ee_core/redcode_e2ee_session.dart';
import 'package:uuid/uuid.dart';

import 'device_lifecycle.dart';
import 'device_profile.dart';
import 'identity_service.dart';
import 'identity_trust.dart';
import 'mls_api_service.dart';
import 'pending_operation.dart';
import 'secure_state_storage.dart';

class E2eeDirectMessageException implements Exception {
  const E2eeDirectMessageException(this.message);
  final String message;

  @override
  String toString() => message;
}

class E2eeDirectMessageCoordinator {
  factory E2eeDirectMessageCoordinator({
    E2eeSecureStateStorage? storage,
    E2eeDeviceLifecycle? lifecycle,
    E2eeIdentityService? identityService,
    E2eeMlsApiService? api,
    RedcodeE2eeSession? core,
    String Function()? newId,
  }) {
    final resolvedStorage = storage ?? E2eeSecureStateStorage();
    return E2eeDirectMessageCoordinator._(
      storage: resolvedStorage,
      lifecycle: lifecycle ?? E2eeDeviceLifecycle(storage: resolvedStorage),
      identityService: identityService ?? E2eeIdentityService(),
      api: api ?? E2eeMlsApiService(),
      core: core ?? const RedcodeE2eeSession(),
      newId: newId ?? const Uuid().v4,
      trust: E2eeIdentityTrustManager(store: resolvedStorage),
    );
  }

  E2eeDirectMessageCoordinator._({
    required E2eeSecureStateStorage storage,
    required E2eeDeviceLifecycle lifecycle,
    required E2eeIdentityService identityService,
    required E2eeMlsApiService api,
    required RedcodeE2eeSession core,
    required String Function() newId,
    required E2eeIdentityTrustManager trust,
  }) : _storage = storage,
       _lifecycle = lifecycle,
       _identityService = identityService,
       _api = api,
       _core = core,
       _newId = newId,
       _trust = trust;

  final E2eeSecureStateStorage _storage;
  final E2eeDeviceLifecycle _lifecycle;
  final E2eeIdentityService _identityService;
  final E2eeMlsApiService _api;
  final RedcodeE2eeSession _core;
  final E2eeIdentityTrustManager _trust;
  final String Function() _newId;
  Future<void> _tail = Future.value();

  Future<Map<String, dynamic>> sendText({
    required String accountId,
    required String deviceLabel,
    required String roomId,
    required String peerUserId,
    required String text,
  }) => _exclusive(() async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw const E2eeDirectMessageException('加密消息内容不能为空');
    }
    await _resumePending(accountId);
    await _lifecycle.ensureReady(
      accountId: accountId,
      deviceLabel: deviceLabel,
    );
    var context = await _storedContext(accountId);
    final identity = await _identityService.fetchRootIdentity(peerUserId);
    await _trust.observe(accountId, identity);
    await _trust.requireTrusted(accountId, peerUserId);

    var epoch = await _api.getRoomEpoch(roomId);
    if (epoch.activeEpoch == 0) {
      await _bootstrapRoom(
        accountId: accountId,
        roomId: roomId,
        peerUserId: peerUserId,
        context: context,
        membershipRevision: epoch.membershipRevision,
      );
      context = E2eeDeviceContext(
        profile: (await _storage.readDeviceProfile(accountId))!,
        state: (await _storage.read(accountId))!,
      );
      epoch = await _api.getRoomEpoch(roomId);
    }
    if (epoch.status != 'active') {
      throw const E2eeDirectMessageException('房间 E2EE 状态尚未就绪');
    }
    final controlMessageId = context.profile.lastCommitMessageIds[roomId];
    if (controlMessageId == null) {
      throw const E2eeDirectMessageException('房间缺少当前 E2EE Commit 索引');
    }

    final plaintext = Uint8List.fromList(
      utf8.encode(
        jsonEncode({'version': 1, 'type': 'text', 'text': normalizedText}),
      ),
    );
    final encrypted = _core.encrypt(context.state, roomId, plaintext);
    final encryptedEpoch = encrypted.epoch(2);
    if (encryptedEpoch != epoch.activeEpoch) {
      throw const E2eeDirectMessageException('本地 E2EE epoch 已过期');
    }
    final operation = E2eePendingOperation(
      kind: E2eePendingOperationKind.application,
      roomId: roomId,
      nextState: encrypted.field(0),
      senderDeviceId: context.profile.deviceId,
      idempotencyKey: _newId(),
      ciphertext: encrypted.field(1),
      epoch: encryptedEpoch,
      controlMessageId: controlMessageId,
    );
    await _storage.writePendingOperation(accountId, operation);
    return (await _resumePending(accountId))!;
  });

  Future<void> _bootstrapRoom({
    required String accountId,
    required String roomId,
    required String peerUserId,
    required E2eeDeviceContext context,
    required int membershipRevision,
  }) async {
    final devices = await _api.listPeerDevices(peerUserId);
    if (devices.isEmpty) {
      throw const E2eeDirectMessageException('联系人没有可用的 E2EE 设备');
    }
    var state = _core.createGroup(context.state, roomId).field(0);
    final controls = <E2eePendingControl>[];
    for (final device in devices) {
      final package = await _api.claimKeyPackage(
        roomId: roomId,
        consumerDeviceId: context.profile.deviceId,
        targetDeviceId: device.id,
      );
      final added = _core.addMember(state, roomId, package.keyPackage);
      state = added.field(0);
      final epoch = added.epoch(3);
      controls.addAll([
        E2eePendingControl(
          id: _newId(),
          epoch: epoch,
          membershipRevision: membershipRevision,
          contentType: 'commit',
          envelope: added.field(1),
        ),
        E2eePendingControl(
          id: _newId(),
          epoch: epoch,
          membershipRevision: membershipRevision,
          contentType: 'welcome',
          envelope: added.field(2),
          recipientDeviceId: device.id,
        ),
      ]);
    }
    await _storage.writePendingOperation(
      accountId,
      E2eePendingOperation(
        kind: E2eePendingOperationKind.bootstrap,
        roomId: roomId,
        nextState: state,
        senderDeviceId: context.profile.deviceId,
        idempotencyKey: _newId(),
        controls: controls,
      ),
    );
    await _resumePending(accountId);
  }

  Future<Map<String, dynamic>?> _resumePending(String accountId) async {
    final operation = await _storage.readPendingOperation(accountId);
    if (operation == null) return null;
    if (operation.kind == E2eePendingOperationKind.bootstrap) {
      for (final control in operation.controls) {
        await _api.submitControlMessage(
          roomId: operation.roomId,
          messageId: control.id,
          epoch: control.epoch,
          membershipRevision: control.membershipRevision,
          senderDeviceId: operation.senderDeviceId,
          contentType: control.contentType,
          envelope: control.envelope,
          recipientDeviceId: control.recipientDeviceId,
          idempotencyKey: control.id,
        );
      }
      final profile = await _requiredProfile(accountId);
      final lastCommitId = operation.controls
          .where((control) => control.contentType == 'commit')
          .last
          .id;
      await _storage.write(accountId, operation.nextState);
      await _storage.writeDeviceProfile(
        accountId,
        profile.copyWith(
          lastCommitMessageIds: {
            ...profile.lastCommitMessageIds,
            operation.roomId: lastCommitId,
          },
        ),
      );
      await _storage.deletePendingOperation(accountId);
      return null;
    }
    final response = await _api.sendEncryptedMessage(
      roomId: operation.roomId,
      senderDeviceId: operation.senderDeviceId,
      epoch: operation.epoch!,
      ciphertext: operation.ciphertext!,
      idempotencyKey: operation.idempotencyKey,
      controlMessageId: operation.controlMessageId,
    );
    await _storage.write(accountId, operation.nextState);
    await _storage.deletePendingOperation(accountId);
    return response;
  }

  Future<E2eeDeviceProfile> _requiredProfile(String accountId) async {
    final profile = await _storage.readDeviceProfile(accountId);
    if (profile == null) {
      throw const E2eeDirectMessageException('E2EE 设备档案缺失');
    }
    return profile;
  }

  Future<E2eeDeviceContext> _storedContext(String accountId) async {
    final profile = await _requiredProfile(accountId);
    final state = await _storage.read(accountId);
    if (state == null) {
      throw const E2eeDirectMessageException('E2EE 协议状态缺失');
    }
    return E2eeDeviceContext(profile: profile, state: state);
  }

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final previous = _tail;
    final completer = Completer<T>();
    _tail = completer.future.then<void>((_) {}, onError: (_) {});
    previous.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
