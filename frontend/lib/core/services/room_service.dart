import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/app_config.dart';
import '../storage/token_storage.dart';

class RoomServiceException implements Exception {
  RoomServiceException(this.message);

  final String message;

  @override
  String toString() => 'RoomServiceException: $message';
}

class CreatedRoom {
  const CreatedRoom({
    required this.id,
    required this.name,
    required this.roomType,
    this.description,
    this.avatarUrl,
    this.ownerId,
  });

  final String id;
  final String name;
  final String roomType;
  final String? description;
  final String? avatarUrl;
  final String? ownerId;

  factory CreatedRoom.fromJson(Map<String, dynamic> json) {
    return CreatedRoom(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      roomType: json['room_type'] as String? ?? 'group',
      description: json['description'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      ownerId: json['owner_id'] as String?,
    );
  }
}

class RoomService {
  RoomService({TokenStorage? tokenStorage})
    : _tokenStorage = tokenStorage ?? const TokenStorage();

  final TokenStorage _tokenStorage;

  Future<Map<String, String>> _authHeaders() async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      throw RoomServiceException('用户未登录');
    }

    return {
      'Authorization': 'Bearer ${session.token}',
      'Content-Type': 'application/json',
    };
  }

  Future<CreatedRoom> createGroup({
    required String name,
    String? description,
    List<String> memberIds = const [],
  }) async {
    if (name.trim().isEmpty) {
      throw RoomServiceException('群聊名称不能为空');
    }
    if (memberIds.isEmpty) {
      throw RoomServiceException('请至少选择一位好友');
    }

    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rooms');
    final payload = <String, dynamic>{
      'name': name.trim(),
      'room_type': 'group',
      'member_ids': memberIds,
    };
    if (description != null && description.trim().isNotEmpty) {
      payload['description'] = description.trim();
    }

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final roomData = data['room'];
        if (roomData is Map<String, dynamic>) {
          return CreatedRoom.fromJson(roomData);
        }
      }
      throw RoomServiceException('创建群聊返回数据格式异常');
    }

    throw RoomServiceException(_extractErrorMessage(response.body) ?? '创建群聊失败');
  }

  String? _extractErrorMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
        final error = data['error'];
        if (error is String && error.isNotEmpty) {
          return error;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
