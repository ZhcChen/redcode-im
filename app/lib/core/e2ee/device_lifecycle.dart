import 'dart:typed_data';

import 'package:redcode_e2ee_core/redcode_e2ee_session.dart';
import 'package:uuid/uuid.dart';

import 'device_profile.dart';
import 'identity_service.dart';
import 'mls_api_service.dart';
import 'secure_state_storage.dart';

class E2eeDeviceNotReadyException implements Exception {
  const E2eeDeviceNotReadyException(this.message);
  final String message;

  @override
  String toString() => message;
}

class E2eeDeviceContext {
  const E2eeDeviceContext({required this.profile, required this.state});

  final E2eeDeviceProfile profile;
  final Uint8List state;
}

class E2eeDeviceLifecycle {
  E2eeDeviceLifecycle({
    E2eeSecureStateStorage? storage,
    E2eeIdentityService? identityService,
    E2eeMlsApiService? api,
    RedcodeE2eeSession? core,
    String Function()? newDeviceId,
  }) : _storage = storage ?? E2eeSecureStateStorage(),
       _identityService = identityService ?? E2eeIdentityService(),
       _api = api ?? E2eeMlsApiService(),
       _core = core ?? const RedcodeE2eeSession(),
       _newDeviceId = newDeviceId ?? const Uuid().v4;

  final E2eeSecureStateStorage _storage;
  final E2eeIdentityService _identityService;
  final E2eeMlsApiService _api;
  final RedcodeE2eeSession _core;
  final String Function() _newDeviceId;

  Future<E2eeDeviceContext> ensureReady({
    required String accountId,
    required String deviceLabel,
  }) async {
    var state = await _storage.read(accountId);
    var profile = await _storage.readDeviceProfile(accountId);
    if (state != null && profile == null) {
      throw const E2eeDeviceNotReadyException('E2EE 设备状态不完整，拒绝重新生成身份');
    }
    if (state == null && profile?.registered == true) {
      throw const E2eeDeviceNotReadyException('E2EE 已注册设备状态缺失，拒绝重新生成身份');
    }

    E2eeDeviceRegistrationMaterial material;
    if (state == null) {
      Uint8List? rootPublicKey;
      try {
        rootPublicKey = (await _identityService.fetchRootIdentity(
          accountId,
        )).publicKey;
      } on E2eeIdentityServiceException catch (error) {
        if (error.statusCode != 404) rethrow;
      }
      profile ??= E2eeDeviceProfile(
        deviceId: _newDeviceId(),
        deviceLabel: deviceLabel,
        registered: false,
        keyPackagePublished: false,
        lastCommitMessageIds: const {},
      );
      await _storage.writeDeviceProfile(accountId, profile);
      final initialized = _core.initialize(
        '$accountId/${profile.deviceId}',
        rootPublicKey: rootPublicKey,
      );
      material = E2eeDeviceRegistrationMaterial.fromCommand(initialized);
      state = material.state;
      await _storage.write(accountId, state);
    } else {
      material = _materialFromRestoredState(state);
    }

    if (!profile!.registered) {
      await _api.registerDevice(
        deviceId: profile.deviceId,
        deviceLabel: profile.deviceLabel,
        material: material,
      );
      profile = profile.copyWith(registered: true);
      await _storage.writeDeviceProfile(accountId, profile);
    }

    if (!profile.keyPackagePublished) {
      final generated = _core.execute(E2eeCommandOperation.generateKeyPackage, [
        state,
      ]);
      state = generated.field(0);
      await _storage.write(accountId, state);
      await _api.publishKeyPackage(
        deviceId: profile.deviceId,
        keyPackage: generated.field(1),
      );
      profile = profile.copyWith(keyPackagePublished: true);
      await _storage.writeDeviceProfile(accountId, profile);
    }

    return E2eeDeviceContext(profile: profile, state: state);
  }

  E2eeDeviceRegistrationMaterial _materialFromRestoredState(Uint8List state) {
    final restored = _core.publicMaterial(state);
    if (restored.fields.length != 6) {
      throw const E2eeCommandException('E2EE 公开材料响应字段数量无效');
    }
    return E2eeDeviceRegistrationMaterial(
      state: restored.field(0),
      keyPackage: Uint8List(0),
      rootPublicKey: restored.field(1),
      rootFingerprint: restored.field(2),
      credential: restored.field(3),
      credentialFingerprint: restored.field(4),
      approvalPublicKey: restored.field(5),
    );
  }
}
