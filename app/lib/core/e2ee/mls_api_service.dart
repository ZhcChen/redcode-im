import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:redcode_e2ee_core/redcode_e2ee_session.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_config.dart';
import '../storage/token_storage.dart';

class E2eeMlsApiException implements Exception {
  const E2eeMlsApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  bool get isRuntimeConflict => statusCode == 409;

  @override
  String toString() => message;
}

class E2eeDeviceRegistrationMaterial {
  const E2eeDeviceRegistrationMaterial({
    required this.state,
    required this.keyPackage,
    required this.rootPublicKey,
    required this.rootFingerprint,
    required this.credential,
    required this.credentialFingerprint,
    required this.approvalPublicKey,
  });

  factory E2eeDeviceRegistrationMaterial.fromCommand(E2eeCommandResult result) {
    if (result.fields.length != 7) {
      throw const E2eeCommandException('E2EE 初始化响应字段数量无效');
    }
    return E2eeDeviceRegistrationMaterial(
      state: result.field(0),
      keyPackage: result.field(1),
      rootPublicKey: result.field(2),
      rootFingerprint: result.field(3),
      credential: result.field(4),
      credentialFingerprint: result.field(5),
      approvalPublicKey: result.field(6),
    );
  }

  final Uint8List state;
  final Uint8List keyPackage;
  final Uint8List rootPublicKey;
  final Uint8List rootFingerprint;
  final Uint8List credential;
  final Uint8List credentialFingerprint;
  final Uint8List approvalPublicKey;
}

class E2eeRoomEpoch {
  const E2eeRoomEpoch({
    required this.membershipRevision,
    required this.activeEpoch,
    required this.status,
  });

  final int membershipRevision;
  final int activeEpoch;
  final String status;
}

class E2eeClaimedKeyPackage {
  const E2eeClaimedKeyPackage({
    required this.id,
    required this.deviceId,
    required this.keyPackage,
  });

  final String id;
  final String deviceId;
  final Uint8List keyPackage;
}

class E2eeControlMessage {
  const E2eeControlMessage({
    required this.id,
    required this.epoch,
    required this.contentType,
    required this.envelope,
    required this.sequenceNo,
  });

  final String id;
  final int epoch;
  final String contentType;
  final Uint8List envelope;
  final int sequenceNo;
}

class E2eeMlsApiService {
  E2eeMlsApiService({TokenStorage? tokenStorage, http.Client? client})
    : _tokenStorage = tokenStorage ?? const TokenStorage(),
      _client = client ?? http.Client();

  final TokenStorage _tokenStorage;
  final http.Client _client;

  Future<Map<String, dynamic>> registerDevice({
    required String deviceId,
    required String deviceLabel,
    required E2eeDeviceRegistrationMaterial material,
  }) => _request(
    'POST',
    '/e2ee/mls/devices',
    body: {
      'device_id': deviceId,
      'device_label': deviceLabel,
      'root_public_key': base64Encode(material.rootPublicKey),
      'root_fingerprint': base64Encode(material.rootFingerprint),
      'credential': base64Encode(material.credential),
      'credential_fingerprint': base64Encode(material.credentialFingerprint),
      'approval_public_key': base64Encode(material.approvalPublicKey),
      'protocol_version': 1,
    },
  );

  Future<void> publishKeyPackage({
    required String deviceId,
    required Uint8List keyPackage,
    DateTime? expiresAt,
  }) async {
    final packageRef = sha256.convert(keyPackage).bytes;
    await _request(
      'POST',
      '/e2ee/mls/devices/$deviceId/key-packages',
      body: {
        'packages': [
          {
            'id': const Uuid().v4(),
            'package_ref': base64Encode(packageRef),
            'key_package': base64Encode(keyPackage),
            'protocol_version': 1,
            'expires_at':
                (expiresAt ??
                        DateTime.now().toUtc().add(const Duration(days: 7)))
                    .toUtc()
                    .toIso8601String(),
          },
        ],
      },
    );
  }

  Future<E2eeClaimedKeyPackage> claimKeyPackage({
    required String roomId,
    required String consumerDeviceId,
    required String targetDeviceId,
  }) async {
    final data = await _request(
      'POST',
      '/e2ee/mls/devices/$targetDeviceId/key-packages/claim',
      body: {'room_id': roomId, 'consumer_device_id': consumerDeviceId},
    );
    return E2eeClaimedKeyPackage(
      id: data['id'] as String,
      deviceId: data['device_id'] as String,
      keyPackage: Uint8List.fromList(
        base64Decode(data['key_package'] as String),
      ),
    );
  }

  Future<E2eeRoomEpoch> getRoomEpoch(String roomId) async {
    final data = await _request('GET', '/rooms/$roomId/e2ee/epoch');
    return E2eeRoomEpoch(
      membershipRevision: data['membership_revision'] as int,
      activeEpoch: data['active_epoch'] as int,
      status: data['status'] as String,
    );
  }

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
  }) => _request(
    'POST',
    '/rooms/$roomId/e2ee/control-messages',
    body: {
      'id': messageId,
      'epoch': epoch,
      'membership_revision': membershipRevision,
      'sender_device_id': senderDeviceId,
      'recipient_device_id': recipientDeviceId,
      'content_type': contentType,
      'envelope': base64Encode(envelope),
      'idempotency_key': idempotencyKey ?? messageId,
    },
  );

  Future<List<E2eeControlMessage>> listControlMessages({
    required String roomId,
    required String deviceId,
    int afterSequence = 0,
    int limit = 50,
  }) async {
    final query = Uri(
      queryParameters: {
        'device_id': deviceId,
        'after_sequence': '$afterSequence',
        'limit': '$limit',
      },
    ).query;
    final data = await _request(
      'GET',
      '/rooms/$roomId/e2ee/control-messages?$query',
    );
    final rows = data['items'];
    if (rows is! List) {
      throw const E2eeMlsApiException('E2EE 控制消息响应格式无效');
    }
    return rows
        .map((row) {
          if (row is! Map<String, dynamic>) {
            throw const E2eeMlsApiException('E2EE 控制消息响应格式无效');
          }
          return E2eeControlMessage(
            id: row['id'] as String,
            epoch: row['epoch'] as int,
            contentType: row['content_type'] as String,
            envelope: Uint8List.fromList(
              base64Decode(row['envelope'] as String),
            ),
            sequenceNo: row['sequence_no'] as int,
          );
        })
        .toList(growable: false);
  }

  Future<void> consumeControlMessage({
    required String roomId,
    required String messageId,
    required String deviceId,
  }) async {
    await _request(
      'POST',
      '/rooms/$roomId/e2ee/control-messages/$messageId/consume',
      body: {'device_id': deviceId},
    );
  }

  Future<Map<String, dynamic>> sendEncryptedMessage({
    required String roomId,
    required String senderDeviceId,
    required int epoch,
    required Uint8List ciphertext,
    required String idempotencyKey,
    String? controlMessageId,
  }) => _request(
    'POST',
    '/rooms/$roomId/messages/encrypted',
    body: {
      'encrypted_content': base64Encode(ciphertext),
      'encryption_metadata': {
        'protocol': 'mls',
        'version': 1,
        'epoch': epoch,
        'sender_device_id': senderDeviceId,
        'content_type': 'application',
        'control_message_id': controlMessageId,
      },
      'idempotency_key': idempotencyKey,
    },
  );

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final session = await _tokenStorage.readSession();
    if (session == null) throw const E2eeMlsApiException('用户未登录');
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final headers = {
      'Authorization': 'Bearer ${session.token}',
      'Content-Type': 'application/json',
    };
    final response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      ),
      _ => throw ArgumentError.value(method, 'method'),
    };
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw E2eeMlsApiException(
        'E2EE API 请求失败: ${response.body}',
        statusCode: response.statusCode,
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List) return {'items': decoded};
      throw const FormatException();
    } on FormatException {
      throw const E2eeMlsApiException('E2EE API 响应格式无效');
    }
  }

  void dispose() => _client.close();
}
