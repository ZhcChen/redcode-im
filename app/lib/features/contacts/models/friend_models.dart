import 'package:app/features/auth/models/auth_user.dart';

enum FriendRequestStatus { pending, accepted, declined }

FriendRequestStatus friendRequestStatusFromString(String value) {
  switch (value.toLowerCase()) {
    case 'accepted':
      return FriendRequestStatus.accepted;
    case 'declined':
      return FriendRequestStatus.declined;
    case 'pending':
    default:
      return FriendRequestStatus.pending;
  }
}

String friendRequestStatusToString(FriendRequestStatus status) {
  switch (status) {
    case FriendRequestStatus.accepted:
      return 'accepted';
    case FriendRequestStatus.declined:
      return 'declined';
    case FriendRequestStatus.pending:
      return 'pending';
  }
}

enum FriendRequestAction { accept, decline }

class FriendInfo {
  const FriendInfo({
    required this.id,
    required this.user,
    required this.createdAt,
    this.remark,
  });

  final String id;
  final AuthUser user;
  final DateTime createdAt;
  final String? remark;

  String get displayName {
    final normalizedRemark = remark?.trim();
    return normalizedRemark?.isNotEmpty == true
        ? normalizedRemark!
        : user.displayName;
  }

  FriendInfo copyWith({String? remark, bool clearRemark = false}) {
    return FriendInfo(
      id: id,
      user: user,
      createdAt: createdAt,
      remark: clearRemark ? null : (remark ?? this.remark),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user': user.toJson(),
    'created_at': createdAt.toIso8601String(),
    'friend_remark': remark,
  };

  factory FriendInfo.fromJson(Map<String, dynamic> json) {
    return FriendInfo(
      id: json['id'] as String? ?? '',
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String),
      remark: json['friend_remark'] as String?,
    );
  }
}

class EnsureChatResult {
  const EnsureChatResult({
    required this.roomId,
    required this.roomName,
    required this.roomType,
    required this.friendId,
    required this.friendName,
    this.friendAvatar,
  });

  final String roomId;
  final String roomName;
  final String roomType;
  final String friendId;
  final String friendName;
  final String? friendAvatar;

  factory EnsureChatResult.fromJson(Map<String, dynamic> json) {
    return EnsureChatResult(
      roomId: json['room_id'] as String? ?? '',
      roomName: json['room_name'] as String? ?? '',
      roomType: json['room_type'] as String? ?? 'private',
      friendId: json['friend_id'] as String? ?? '',
      friendName: json['friend_name'] as String? ?? '',
      friendAvatar: json['friend_avatar'] as String?,
    );
  }
}

class FriendRequestInfo {
  const FriendRequestInfo({
    required this.id,
    required this.requester,
    required this.addressee,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.message,
    this.isIncoming = false,
  });

  final String id;
  final AuthUser requester;
  final AuthUser addressee;
  final FriendRequestStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? message;
  final bool isIncoming;

  AuthUser get counterparty => isIncoming ? requester : addressee;

  factory FriendRequestInfo.fromJson(Map<String, dynamic> json) {
    return FriendRequestInfo(
      id: json['id'] as String? ?? '',
      requester: AuthUser.fromJson(json['requester'] as Map<String, dynamic>),
      addressee: AuthUser.fromJson(json['addressee'] as Map<String, dynamic>),
      status: friendRequestStatusFromString(
        json['status'] as String? ?? 'pending',
      ),
      message: json['message'] as String?,
      isIncoming: json['is_incoming'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      respondedAt: json['responded_at'] != null
          ? DateTime.tryParse(json['responded_at'] as String)
          : null,
    );
  }
}
