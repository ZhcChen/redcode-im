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

class AddMembersResult {
  const AddMembersResult({
    required this.addedUserIds,
    required this.skippedUserIds,
  });

  final List<String> addedUserIds;
  final List<String> skippedUserIds;

  factory AddMembersResult.fromJson(Map<String, dynamic> json) {
    return AddMembersResult(
      addedUserIds: (json['added_user_ids'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      skippedUserIds: (json['skipped_user_ids'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

/// 当前用户的个人禁言信息
class MyMuteInfo {
  MyMuteInfo({
    required this.isMuted,
    this.reason,
    this.mutedAt,
    this.muteUntil,
  });

  final bool isMuted;
  final String? reason;
  final DateTime? mutedAt;
  final DateTime? muteUntil;

  factory MyMuteInfo.fromJson(Map<String, dynamic> json) {
    DateTime? mutedAt;
    final mutedAtStr = json['muted_at'];
    if (mutedAtStr is String && mutedAtStr.isNotEmpty) {
      mutedAt = DateTime.tryParse(mutedAtStr);
    }

    DateTime? muteUntil;
    final muteUntilStr = json['mute_until'];
    if (muteUntilStr is String && muteUntilStr.isNotEmpty) {
      muteUntil = DateTime.tryParse(muteUntilStr);
    }

    return MyMuteInfo(
      isMuted: json['is_muted'] as bool? ?? false,
      reason: json['reason'] as String?,
      mutedAt: mutedAt,
      muteUntil: muteUntil,
    );
  }
}

class GroupSettingsInfo {
  GroupSettingsInfo({
    required this.roomId,
    required this.globalMuteEnabled,
    this.globalMuteReason,
    this.globalMuteUntil,
    this.joinApprovalRequired,
    this.memberCanInvite,
    this.maxMembers,
    this.myMute,
  });

  final String roomId;
  final bool globalMuteEnabled;
  final String? globalMuteReason;
  final DateTime? globalMuteUntil;
  final bool? joinApprovalRequired;
  final bool? memberCanInvite;
  final int? maxMembers;
  final MyMuteInfo? myMute;

  factory GroupSettingsInfo.fromJson(Map<String, dynamic> json) {
    DateTime? muteUntil;
    final until = json['global_mute_until'];
    if (until is String && until.isNotEmpty) {
      muteUntil = DateTime.tryParse(until);
    }

    MyMuteInfo? myMute;
    final myMuteJson = json['my_mute'];
    if (myMuteJson is Map<String, dynamic>) {
      myMute = MyMuteInfo.fromJson(myMuteJson);
    }

    return GroupSettingsInfo(
      roomId: json['room_id'] as String? ?? '',
      globalMuteEnabled: json['global_mute_enabled'] as bool? ?? false,
      globalMuteReason: json['global_mute_reason'] as String?,
      globalMuteUntil: muteUntil,
      joinApprovalRequired: json['join_approval_required'] as bool?,
      memberCanInvite: json['member_can_invite'] as bool?,
      maxMembers: json['max_members'] as int?,
      myMute: myMute,
    );
  }
}

// ===== 群管理相关模型 =====

/// 群管理员
class GroupAdmin {
  GroupAdmin({
    required this.id,
    required this.roomId,
    required this.adminId,
    required this.appointedBy,
    required this.role,
    this.permissions,
    required this.appointedAt,
  });

  final String id;
  final String roomId;
  final String adminId;
  final String appointedBy;
  final String role;
  final List<String>? permissions;
  final DateTime appointedAt;

  factory GroupAdmin.fromJson(Map<String, dynamic> json) {
    return GroupAdmin(
      id: json['id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      adminId: json['admin_id'] as String? ?? '',
      appointedBy: json['appointed_by'] as String? ?? '',
      role: json['role'] as String? ?? 'admin',
      permissions: (json['permissions'] as List?)?.cast<String>(),
      appointedAt:
          DateTime.tryParse(json['appointed_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// 入群申请
class JoinRequest {
  JoinRequest({
    required this.id,
    required this.roomId,
    required this.applicantId,
    this.message,
    required this.status,
    this.reviewerId,
    this.reviewMessage,
    required this.createdAt,
    this.reviewedAt,
  });

  final String id;
  final String roomId;
  final String applicantId;
  final String? message;
  final String status; // 'pending', 'approved', 'rejected'
  final String? reviewerId;
  final String? reviewMessage;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    final statusRaw = json['status'];
    String status = 'pending';
    if (statusRaw is int) {
      status = statusRaw == 1
          ? 'approved'
          : (statusRaw == 2 ? 'rejected' : 'pending');
    } else if (statusRaw is String) {
      status = statusRaw;
    }

    return JoinRequest(
      id: json['id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      applicantId: json['applicant_id'] as String? ?? '',
      message: json['message'] as String?,
      status: status,
      reviewerId: json['reviewer_id'] as String?,
      reviewMessage: json['review_message'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'] as String)
          : null,
    );
  }
}

/// 群聊邀请
class GroupInvitation {
  GroupInvitation({
    required this.id,
    required this.roomId,
    required this.inviterId,
    required this.inviteeId,
    this.message,
    required this.status,
    required this.invitedAt,
    this.respondedAt,
    required this.expiresAt,
  });

  final String id;
  final String roomId;
  final String inviterId;
  final String inviteeId;
  final String? message;
  final String status;
  final DateTime invitedAt;
  final DateTime? respondedAt;
  final DateTime expiresAt;

  factory GroupInvitation.fromJson(Map<String, dynamic> json) {
    const numericStatuses = <int, String>{
      0: 'pending',
      1: 'accepted',
      2: 'declined',
      3: 'expired',
    };
    final rawStatus = json['status'];
    final status = rawStatus is int
        ? numericStatuses[rawStatus] ?? 'pending'
        : rawStatus?.toString().toLowerCase() ?? 'pending';

    return GroupInvitation(
      id: json['id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      inviterId: json['inviter_id'] as String? ?? '',
      inviteeId: json['invitee_id'] as String? ?? '',
      message: json['message'] as String?,
      status: status,
      invitedAt:
          DateTime.tryParse(json['invited_at'] as String? ?? '') ??
          DateTime.now(),
      respondedAt: json['responded_at'] is String
          ? DateTime.tryParse(json['responded_at'] as String)
          : null,
      expiresAt:
          DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// 群禁言记录
class GroupMute {
  GroupMute({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.mutedBy,
    this.reason,
    required this.muteDurationHours,
    required this.mutedAt,
    this.unmutedAt,
    required this.isActive,
    this.muteUntil,
  });

  final String id;
  final String roomId;
  final String userId;
  final String mutedBy;
  final String? reason;
  final int muteDurationHours;
  final DateTime mutedAt;
  final DateTime? unmutedAt;
  final bool isActive;
  final DateTime? muteUntil;

  factory GroupMute.fromJson(Map<String, dynamic> json) {
    final mutedAt =
        DateTime.tryParse(json['muted_at'] as String? ?? '') ?? DateTime.now();
    final durationHours = json['mute_duration_hours'] as int? ?? 0;
    DateTime? muteUntil;
    if (durationHours > 0) {
      muteUntil = mutedAt.add(Duration(hours: durationHours));
    }

    return GroupMute(
      id: json['id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      mutedBy: json['muted_by'] as String? ?? '',
      reason: json['reason'] as String?,
      muteDurationHours: durationHours,
      mutedAt: mutedAt,
      unmutedAt: json['unmuted_at'] != null
          ? DateTime.tryParse(json['unmuted_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      muteUntil: muteUntil,
    );
  }
}

/// 群规
class GroupRule {
  GroupRule({
    required this.id,
    required this.roomId,
    required this.title,
    required this.content,
    required this.creatorId,
    required this.orderIndex,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String roomId;
  final String title;
  final String content;
  final String creatorId;
  final int orderIndex;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory GroupRule.fromJson(Map<String, dynamic> json) {
    return GroupRule(
      id: json['id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      creatorId: json['creator_id'] as String? ?? '',
      orderIndex: json['order_index'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// 操作日志
class GroupOperationLog {
  GroupOperationLog({
    required this.id,
    required this.roomId,
    required this.operatorId,
    this.targetUserId,
    required this.operationType,
    this.operationData,
    required this.createdAt,
  });

  final String id;
  final String roomId;
  final String operatorId;
  final String? targetUserId;
  final String operationType;
  final Map<String, dynamic>? operationData;
  final DateTime createdAt;

  factory GroupOperationLog.fromJson(Map<String, dynamic> json) {
    return GroupOperationLog(
      id: json['id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? '',
      operatorId: json['operator_id'] as String? ?? '',
      targetUserId: json['target_user_id'] as String?,
      operationType: json['operation_type'] as String? ?? '',
      operationData: json['operation_data'] as Map<String, dynamic>?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class RoomService {
  RoomService({TokenStorage? tokenStorage, http.Client? client})
    : _tokenStorage = tokenStorage ?? const TokenStorage(),
      _client = client ?? http.Client();

  final TokenStorage _tokenStorage;
  final http.Client _client;

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

    final response = await _client.post(
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

  bool _isSuccessStatus(int statusCode) =>
      statusCode == 200 || statusCode == 204;

  Future<GroupSettingsInfo> fetchGroupSettings(String roomId) async {
    if (roomId.isEmpty) {
      throw RoomServiceException('无效的群组 ID');
    }
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId/settings');
    final response = await _client.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final settings = decoded['settings'];
        if (settings is Map<String, dynamic>) {
          final payload = Map<String, dynamic>.from(settings);
          if (decoded.containsKey('my_mute')) {
            payload['my_mute'] = decoded['my_mute'];
          }
          return GroupSettingsInfo.fromJson(payload);
        }
      }
      throw RoomServiceException('群设置返回数据异常');
    }

    throw RoomServiceException(
      _extractErrorMessage(response.body) ?? '加载群设置失败',
    );
  }

  Future<void> updateGlobalMute({
    required String roomId,
    required bool enabled,
    String? reason,
    int? durationMinutes,
  }) async {
    if (roomId.isEmpty) {
      throw RoomServiceException('无效的群组 ID');
    }
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId/mutes/global');
    final payload = <String, dynamic>{'enabled': enabled};
    if (reason != null && reason.trim().isNotEmpty) {
      payload['reason'] = reason.trim();
    }
    if (durationMinutes != null) {
      payload['duration_minutes'] = durationMinutes;
    }

    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (!_isSuccessStatus(response.statusCode)) {
      throw RoomServiceException(
        _extractErrorMessage(response.body) ?? '更新群禁言状态失败',
      );
    }
  }

  Future<void> dissolveGroup(String roomId) async {
    if (roomId.isEmpty) {
      throw RoomServiceException('无效的群组 ID');
    }
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId');
    final response = await _client.delete(uri, headers: headers);

    if (!_isSuccessStatus(response.statusCode)) {
      throw RoomServiceException(
        _extractErrorMessage(response.body) ?? '解散群聊失败',
      );
    }
  }

  Future<void> transferRoomOwner({
    required String roomId,
    required String newOwnerId,
  }) async {
    if (roomId.isEmpty || newOwnerId.trim().isEmpty) {
      throw RoomServiceException('请先选择新的群主');
    }
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId/transfer');
    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode({'new_owner_id': newOwnerId.trim()}),
    );

    if (!_isSuccessStatus(response.statusCode)) {
      throw RoomServiceException(
        _extractErrorMessage(response.body) ?? '转让群主失败',
      );
    }
  }

  /// 获取群详情信息
  Future<Map<String, dynamic>?> fetchRoomDetail(String roomId) async {
    if (roomId.isEmpty) {
      throw RoomServiceException('无效的群组 ID');
    }

    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId');
      final response = await _client.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded['room'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      // 静默失败，返回 null
    }
    return null;
  }

  // ===== 群管理员相关 =====

  /// 获取群管理员列表
  Future<List<GroupAdmin>> listAdmins(String roomId) async {
    if (roomId.isEmpty) {
      throw RoomServiceException('无效的群组 ID');
    }
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId/admins');
    final response = await _client.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final admins = decoded['admins'];
        if (admins is List) {
          return admins
              .whereType<Map<String, dynamic>>()
              .map((e) => GroupAdmin.fromJson(e))
              .toList();
        }
      }
      return [];
    }
    throw RoomServiceException(
      _extractErrorMessage(response.body) ?? '获取管理员列表失败',
    );
  }

  /// 任命管理员
  Future<void> appointAdmin({
    required String roomId,
    required String userId,
    String role = 'admin',
    List<String>? permissions,
  }) async {
    if (roomId.isEmpty || userId.isEmpty) {
      throw RoomServiceException('参数不完整');
    }
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId/admins');
    final payload = <String, dynamic>{'user_id': userId, 'role': role};
    if (permissions != null && permissions.isNotEmpty) {
      payload['permissions'] = permissions;
    }

    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (!_isSuccessStatus(response.statusCode)) {
      throw RoomServiceException(
        _extractErrorMessage(response.body) ?? '任命管理员失败',
      );
    }
  }

  /// 移除管理员
  Future<void> removeAdmin({
    required String roomId,
    required String userId,
  }) async {
    if (roomId.isEmpty || userId.isEmpty) {
      throw RoomServiceException('参数不完整');
    }
    final headers = await _authHeaders();
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/admins/$userId',
    );
    final response = await _client.delete(uri, headers: headers);

    if (!_isSuccessStatus(response.statusCode)) {
      throw RoomServiceException(
        _extractErrorMessage(response.body) ?? '移除管理员失败',
      );
    }
  }

  // ===== 入群申请相关 =====

  /// 获取入群申请列表
  Future<List<JoinRequest>> listJoinRequests(String roomId) async {
    if (roomId.isEmpty) {
      throw RoomServiceException('无效的群组 ID');
    }
    final headers = await _authHeaders();
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/join-requests',
    );
    final response = await _client.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final requests = decoded['requests'];
        if (requests is List) {
          return requests
              .whereType<Map<String, dynamic>>()
              .map((e) => JoinRequest.fromJson(e))
              .toList();
        }
      }
      return [];
    }
    throw RoomServiceException(
      _extractErrorMessage(response.body) ?? '获取入群申请失败',
    );
  }

  /// 审核入群申请
  Future<void> reviewJoinRequest({
    required String roomId,
    required String requestId,
    required String status, // 'approved' | 'rejected'
    String? reviewMessage,
  }) async {
    if (roomId.isEmpty || requestId.isEmpty) {
      throw RoomServiceException('参数不完整');
    }
    final headers = await _authHeaders();
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/join-requests/$requestId/review',
    );
    final payload = <String, dynamic>{'status': status};
    if (reviewMessage != null && reviewMessage.trim().isNotEmpty) {
      payload['review_message'] = reviewMessage.trim();
    }

    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (!_isSuccessStatus(response.statusCode)) {
      throw RoomServiceException(
        _extractErrorMessage(response.body) ?? '审核入群申请失败',
      );
    }
  }

  // ===== 群邀请相关 =====

  /// 创建群邀请
  Future<List<GroupInvitation>> createInvitations({
    required String roomId,
    required List<String> userIds,
    String? message,
  }) async {
    final normalizedUserIds = userIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    if (roomId.isEmpty || normalizedUserIds.isEmpty) {
      throw RoomServiceException('请至少选择一位邀请对象');
    }

    final headers = await _authHeaders();
    final payload = <String, dynamic>{'user_ids': normalizedUserIds};
    if (message != null && message.trim().isNotEmpty) {
      payload['message'] = message.trim();
    }
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId/invitations'),
      headers: headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw RoomServiceException(
        _extractErrorMessage(response.body) ?? '创建群邀请失败',
      );
    }

    final decoded = jsonDecode(response.body);
    final invitations = decoded is Map<String, dynamic>
        ? decoded['invitations']
        : null;
    if (invitations is! List) {
      throw RoomServiceException('创建群邀请返回数据异常');
    }
    return invitations
        .whereType<Map<String, dynamic>>()
        .map(GroupInvitation.fromJson)
        .toList();
  }

  /// 接受或拒绝群邀请
  Future<void> respondToInvitation({
    required String roomId,
    required String invitationId,
    required String status,
  }) async {
    if (roomId.isEmpty || invitationId.isEmpty) {
      throw RoomServiceException('参数不完整');
    }
    if (status != 'accepted' && status != 'declined') {
      throw RoomServiceException('无效的邀请响应状态');
    }

    final headers = await _authHeaders();
    final response = await _client.patch(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/rooms/$roomId/invitations/$invitationId/respond',
      ),
      headers: headers,
      body: jsonEncode({'status': status}),
    );
    if (!_isSuccessStatus(response.statusCode)) {
      throw RoomServiceException(
        _extractErrorMessage(response.body) ?? '响应群邀请失败',
      );
    }
  }

  // ===== 禁言管理相关 =====

  /// 获取被禁言成员列表
  Future<List<GroupMute>> listMutedUsers(String roomId) async {
    if (roomId.isEmpty) {
      throw RoomServiceException('无效的群组 ID');
    }
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId/mutes');
    final response = await _client.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final mutes = decoded['mutes'];
        if (mutes is List) {
          return mutes
              .whereType<Map<String, dynamic>>()
              .map((e) => GroupMute.fromJson(e))
              .toList();
        }
      }
      return [];
    }
    throw RoomServiceException(
      _extractErrorMessage(response.body) ?? '获取禁言列表失败',
    );
  }

  /// 禁言成员
  Future<void> muteUser({
    required String roomId,
    required String userId,
    required int durationHours,
    String? reason,
  }) async {
    if (roomId.isEmpty || userId.isEmpty) {
      throw RoomServiceException('参数不完整');
    }
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId/mutes');
    final payload = <String, dynamic>{
      'user_id': userId,
      'duration_hours': durationHours,
    };
    if (reason != null && reason.trim().isNotEmpty) {
      payload['reason'] = reason.trim();
    }

    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (!_isSuccessStatus(response.statusCode)) {
      throw RoomServiceException(_extractErrorMessage(response.body) ?? '禁言失败');
    }
  }

  /// 解除禁言
  Future<void> unmuteUser({
    required String roomId,
    required String userId,
  }) async {
    if (roomId.isEmpty || userId.isEmpty) {
      throw RoomServiceException('参数不完整');
    }
    final headers = await _authHeaders();
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/mutes/$userId',
    );
    final response = await _client.delete(uri, headers: headers);

    if (!_isSuccessStatus(response.statusCode)) {
      throw RoomServiceException(
        _extractErrorMessage(response.body) ?? '解除禁言失败',
      );
    }
  }

  // ===== 群规相关 =====

  /// 获取群规列表
  Future<List<GroupRule>> listRules(String roomId) async {
    if (roomId.isEmpty) {
      throw RoomServiceException('无效的群组 ID');
    }
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId/rules');
    final response = await _client.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final rules = decoded['rules'];
        if (rules is List) {
          return rules
              .whereType<Map<String, dynamic>>()
              .map((e) => GroupRule.fromJson(e))
              .toList();
        }
      }
      return [];
    }
    throw RoomServiceException(_extractErrorMessage(response.body) ?? '获取群规失败');
  }

  /// 创建群规
  Future<GroupRule> createRule({
    required String roomId,
    required String title,
    required String content,
    int orderIndex = 0,
  }) async {
    if (roomId.isEmpty || title.trim().isEmpty || content.trim().isEmpty) {
      throw RoomServiceException('参数不完整');
    }
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId/rules');
    final payload = <String, dynamic>{
      'title': title.trim(),
      'content': content.trim(),
      'order_index': orderIndex,
    };

    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final rule = decoded['rule'];
        if (rule is Map<String, dynamic>) {
          return GroupRule.fromJson(rule);
        }
      }
      throw RoomServiceException('创建群规返回数据异常');
    }
    throw RoomServiceException(_extractErrorMessage(response.body) ?? '创建群规失败');
  }

  /// 更新群规
  Future<void> updateRule({
    required String roomId,
    required String ruleId,
    String? title,
    String? content,
    int? orderIndex,
    bool? isActive,
  }) async {
    if (roomId.isEmpty || ruleId.isEmpty) {
      throw RoomServiceException('参数不完整');
    }
    final headers = await _authHeaders();
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/rules/$ruleId',
    );
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title.trim();
    if (content != null) payload['content'] = content.trim();
    if (orderIndex != null) payload['order_index'] = orderIndex;
    if (isActive != null) payload['is_active'] = isActive;

    final response = await _client.patch(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (!_isSuccessStatus(response.statusCode)) {
      throw RoomServiceException(
        _extractErrorMessage(response.body) ?? '更新群规失败',
      );
    }
  }

  /// 删除群规
  Future<void> deleteRule({
    required String roomId,
    required String ruleId,
  }) async {
    if (roomId.isEmpty || ruleId.isEmpty) {
      throw RoomServiceException('参数不完整');
    }
    final headers = await _authHeaders();
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/rules/$ruleId',
    );
    final response = await _client.delete(uri, headers: headers);

    if (!_isSuccessStatus(response.statusCode)) {
      throw RoomServiceException(
        _extractErrorMessage(response.body) ?? '删除群规失败',
      );
    }
  }

  // ===== 操作日志相关 =====

  /// 获取操作日志
  Future<List<GroupOperationLog>> listOperationLogs({
    required String roomId,
    int limit = 20,
    int offset = 0,
  }) async {
    if (roomId.isEmpty) {
      throw RoomServiceException('无效的群组 ID');
    }
    final headers = await _authHeaders();
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/operation-logs?limit=$limit&offset=$offset',
    );
    final response = await _client.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final logs = decoded['logs'];
        if (logs is List) {
          return logs
              .whereType<Map<String, dynamic>>()
              .map((e) => GroupOperationLog.fromJson(e))
              .toList();
        }
      }
      return [];
    }
    throw RoomServiceException(
      _extractErrorMessage(response.body) ?? '获取操作日志失败',
    );
  }

  // ===== 群设置相关 =====

  /// 更新群设置
  Future<void> updateGroupSettings({
    required String roomId,
    bool? joinApprovalRequired,
    bool? memberCanInvite,
    int? maxMembers,
  }) async {
    if (roomId.isEmpty) {
      throw RoomServiceException('无效的群组 ID');
    }
    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId/settings');
    final payload = <String, dynamic>{};
    if (joinApprovalRequired != null) {
      payload['join_approval_required'] = joinApprovalRequired;
    }
    if (memberCanInvite != null) {
      payload['member_can_invite'] = memberCanInvite;
    }
    if (maxMembers != null) {
      payload['max_members'] = maxMembers;
    }

    final response = await _client.patch(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (!_isSuccessStatus(response.statusCode)) {
      throw RoomServiceException(
        _extractErrorMessage(response.body) ?? '更新群设置失败',
      );
    }
  }

  Future<CreatedRoom> updateRoom({
    required String roomId,
    String? name,
    String? description,
  }) async {
    if (roomId.isEmpty) {
      throw RoomServiceException('无效的群组 ID');
    }

    final payload = <String, dynamic>{};
    if (name != null) {
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) {
        throw RoomServiceException('群聊名称不能为空');
      }
      payload['name'] = trimmedName;
    }
    if (description != null) {
      payload['description'] = description.trim();
    }
    if (payload.isEmpty) {
      throw RoomServiceException('没有可更新的群信息');
    }

    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId');
    final response = await _client.patch(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final room = decoded['room'];
        if (room is Map<String, dynamic>) {
          return CreatedRoom.fromJson(room);
        }
      }
      throw RoomServiceException('更新群信息返回数据异常');
    }

    throw RoomServiceException(
      _extractErrorMessage(response.body) ?? '更新群信息失败',
    );
  }

  Future<AddMembersResult> addMembers({
    required String roomId,
    required List<String> userIds,
  }) async {
    if (roomId.isEmpty) {
      throw RoomServiceException('无效的群组 ID');
    }

    final normalizedUserIds = userIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (normalizedUserIds.isEmpty) {
      throw RoomServiceException('请至少选择一位成员');
    }

    final headers = await _authHeaders();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/rooms/$roomId/members/add');
    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode({'user_ids': normalizedUserIds}),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return AddMembersResult.fromJson(decoded);
      }
      throw RoomServiceException('添加成员返回数据异常');
    }

    throw RoomServiceException(_extractErrorMessage(response.body) ?? '添加成员失败');
  }

  Future<void> removeMember({
    required String roomId,
    required String userId,
  }) async {
    if (roomId.isEmpty || userId.trim().isEmpty) {
      throw RoomServiceException('参数不完整');
    }

    final headers = await _authHeaders();
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/rooms/$roomId/members/${userId.trim()}',
    );
    final response = await _client.delete(uri, headers: headers);

    if (!_isSuccessStatus(response.statusCode)) {
      throw RoomServiceException(
        _extractErrorMessage(response.body) ?? '移除成员失败',
      );
    }
  }
}
