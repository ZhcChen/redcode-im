import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../constants/app_config.dart';
import '../storage/token_storage.dart';
import 'identity_trust.dart';

class E2eeIdentityServiceException implements Exception {
  const E2eeIdentityServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class E2eeIdentityService {
  E2eeIdentityService({TokenStorage? tokenStorage, http.Client? client})
    : _tokenStorage = tokenStorage ?? const TokenStorage(),
      _client = client ?? http.Client();

  final TokenStorage _tokenStorage;
  final http.Client _client;

  Future<E2eeRootIdentity> fetchRootIdentity(String userId) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      throw const E2eeIdentityServiceException('E2EE 用户标识不能为空');
    }
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw const E2eeIdentityServiceException('用户未登录');
    }
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/e2ee/mls/identities/$normalized'),
      headers: {'Authorization': 'Bearer ${session.token}'},
    );
    if (response.statusCode != 200) {
      throw E2eeIdentityServiceException(
        response.statusCode == 404 ? '联系人尚未初始化端到端加密' : '获取联系人 E2EE 身份失败',
      );
    }
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final identity = E2eeRootIdentity(
        userId: json['user_id'] as String,
        publicKey: Uint8List.fromList(
          base64Decode(json['root_public_key'] as String),
        ),
        fingerprint: Uint8List.fromList(
          base64Decode(json['root_fingerprint'] as String),
        ),
        protocolVersion: json['protocol_version'] as int,
      );
      if (identity.userId != normalized) {
        throw const FormatException('E2EE 身份账号不匹配');
      }
      return identity;
    } on Object {
      throw const E2eeIdentityServiceException('联系人 E2EE 身份格式无效');
    }
  }

  void dispose() => _client.close();
}
