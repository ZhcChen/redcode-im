// This is a generated file - do not edit.
//
// Generated from ws.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use pubSubPriorityDescriptor instead')
const PubSubPriority$json = {
  '1': 'PubSubPriority',
  '2': [
    {'1': 'PUBSUB_PRIORITY_UNKNOWN', '2': 0},
    {'1': 'PUBSUB_PRIORITY_CRITICAL', '2': 1},
    {'1': 'PUBSUB_PRIORITY_HIGH', '2': 2},
    {'1': 'PUBSUB_PRIORITY_NORMAL', '2': 3},
    {'1': 'PUBSUB_PRIORITY_LOW', '2': 4},
  ],
};

/// Descriptor for `PubSubPriority`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List pubSubPriorityDescriptor = $convert.base64Decode(
    'Cg5QdWJTdWJQcmlvcml0eRIbChdQVUJTVUJfUFJJT1JJVFlfVU5LTk9XThAAEhwKGFBVQlNVQl'
    '9QUklPUklUWV9DUklUSUNBTBABEhgKFFBVQlNVQl9QUklPUklUWV9ISUdIEAISGgoWUFVCU1VC'
    'X1BSSU9SSVRZX05PUk1BTBADEhcKE1BVQlNVQl9QUklPUklUWV9MT1cQBA==');

@$core.Deprecated('Use clientEventDescriptor instead')
const ClientEvent$json = {
  '1': 'ClientEvent',
  '2': [
    {
      '1': 'auth',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.ws.ClientAuth',
      '9': 0,
      '10': 'auth'
    },
    {
      '1': 'join',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.ws.ClientJoin',
      '9': 0,
      '10': 'join'
    },
    {
      '1': 'leave',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.ws.ClientLeave',
      '9': 0,
      '10': 'leave'
    },
    {
      '1': 'ping',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.ws.ClientPing',
      '9': 0,
      '10': 'ping'
    },
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `ClientEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clientEventDescriptor = $convert.base64Decode(
    'CgtDbGllbnRFdmVudBIkCgRhdXRoGAEgASgLMg4ud3MuQ2xpZW50QXV0aEgAUgRhdXRoEiQKBG'
    'pvaW4YAiABKAsyDi53cy5DbGllbnRKb2luSABSBGpvaW4SJwoFbGVhdmUYAyABKAsyDy53cy5D'
    'bGllbnRMZWF2ZUgAUgVsZWF2ZRIkCgRwaW5nGAQgASgLMg4ud3MuQ2xpZW50UGluZ0gAUgRwaW'
    '5nQgkKB3BheWxvYWQ=');

@$core.Deprecated('Use clientAuthDescriptor instead')
const ClientAuth$json = {
  '1': 'ClientAuth',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
  ],
};

/// Descriptor for `ClientAuth`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clientAuthDescriptor =
    $convert.base64Decode('CgpDbGllbnRBdXRoEhQKBXRva2VuGAEgASgJUgV0b2tlbg==');

@$core.Deprecated('Use clientJoinDescriptor instead')
const ClientJoin$json = {
  '1': 'ClientJoin',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
  ],
};

/// Descriptor for `ClientJoin`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clientJoinDescriptor = $convert
    .base64Decode('CgpDbGllbnRKb2luEhcKB3Jvb21faWQYASABKAlSBnJvb21JZA==');

@$core.Deprecated('Use clientLeaveDescriptor instead')
const ClientLeave$json = {
  '1': 'ClientLeave',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
  ],
};

/// Descriptor for `ClientLeave`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clientLeaveDescriptor = $convert
    .base64Decode('CgtDbGllbnRMZWF2ZRIXCgdyb29tX2lkGAEgASgJUgZyb29tSWQ=');

@$core.Deprecated('Use clientPingDescriptor instead')
const ClientPing$json = {
  '1': 'ClientPing',
};

/// Descriptor for `ClientPing`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clientPingDescriptor =
    $convert.base64Decode('CgpDbGllbnRQaW5n');

@$core.Deprecated('Use serverEventDescriptor instead')
const ServerEvent$json = {
  '1': 'ServerEvent',
  '2': [
    {
      '1': 'authed',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.ws.ServerAuthed',
      '9': 0,
      '10': 'authed'
    },
    {
      '1': 'joined',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.ws.ServerJoined',
      '9': 0,
      '10': 'joined'
    },
    {
      '1': 'left',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.ws.ServerLeft',
      '9': 0,
      '10': 'left'
    },
    {
      '1': 'message',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.ws.ServerMessage',
      '9': 0,
      '10': 'message'
    },
    {
      '1': 'message_read',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.ws.ServerMessageRead',
      '9': 0,
      '10': 'messageRead'
    },
    {
      '1': 'message_update',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.ws.ServerMessageUpdate',
      '9': 0,
      '10': 'messageUpdate'
    },
    {
      '1': 'pin_update',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.ws.ServerPinUpdate',
      '9': 0,
      '10': 'pinUpdate'
    },
    {
      '1': 'error',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.ws.ServerError',
      '9': 0,
      '10': 'error'
    },
    {
      '1': 'pong',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.ws.ServerPong',
      '9': 0,
      '10': 'pong'
    },
    {
      '1': 'friend_request_update',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.ws.ServerFriendRequestUpdate',
      '9': 0,
      '10': 'friendRequestUpdate'
    },
    {
      '1': 'room_created',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.ws.ServerRoomCreated',
      '9': 0,
      '10': 'roomCreated'
    },
    {
      '1': 'user_banned',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.ws.ServerBanned',
      '9': 0,
      '10': 'userBanned'
    },
    {
      '1': 'group_dissolved',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.ws.ServerGroupDissolved',
      '9': 0,
      '10': 'groupDissolved'
    },
    {
      '1': 'group_owner_transferred',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.ws.ServerGroupOwnerTransferred',
      '9': 0,
      '10': 'groupOwnerTransferred'
    },
    {
      '1': 'room_updated',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.ws.ServerRoomUpdated',
      '9': 0,
      '10': 'roomUpdated'
    },
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `ServerEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverEventDescriptor = $convert.base64Decode(
    'CgtTZXJ2ZXJFdmVudBIqCgZhdXRoZWQYASABKAsyEC53cy5TZXJ2ZXJBdXRoZWRIAFIGYXV0aG'
    'VkEioKBmpvaW5lZBgCIAEoCzIQLndzLlNlcnZlckpvaW5lZEgAUgZqb2luZWQSJAoEbGVmdBgD'
    'IAEoCzIOLndzLlNlcnZlckxlZnRIAFIEbGVmdBItCgdtZXNzYWdlGAQgASgLMhEud3MuU2Vydm'
    'VyTWVzc2FnZUgAUgdtZXNzYWdlEjoKDG1lc3NhZ2VfcmVhZBgFIAEoCzIVLndzLlNlcnZlck1l'
    'c3NhZ2VSZWFkSABSC21lc3NhZ2VSZWFkEkAKDm1lc3NhZ2VfdXBkYXRlGAYgASgLMhcud3MuU2'
    'VydmVyTWVzc2FnZVVwZGF0ZUgAUg1tZXNzYWdlVXBkYXRlEjQKCnBpbl91cGRhdGUYByABKAsy'
    'Ey53cy5TZXJ2ZXJQaW5VcGRhdGVIAFIJcGluVXBkYXRlEicKBWVycm9yGAggASgLMg8ud3MuU2'
    'VydmVyRXJyb3JIAFIFZXJyb3ISJAoEcG9uZxgJIAEoCzIOLndzLlNlcnZlclBvbmdIAFIEcG9u'
    'ZxJTChVmcmllbmRfcmVxdWVzdF91cGRhdGUYCiABKAsyHS53cy5TZXJ2ZXJGcmllbmRSZXF1ZX'
    'N0VXBkYXRlSABSE2ZyaWVuZFJlcXVlc3RVcGRhdGUSOgoMcm9vbV9jcmVhdGVkGAsgASgLMhUu'
    'd3MuU2VydmVyUm9vbUNyZWF0ZWRIAFILcm9vbUNyZWF0ZWQSMwoLdXNlcl9iYW5uZWQYDCABKA'
    'syEC53cy5TZXJ2ZXJCYW5uZWRIAFIKdXNlckJhbm5lZBJDCg9ncm91cF9kaXNzb2x2ZWQYDSAB'
    'KAsyGC53cy5TZXJ2ZXJHcm91cERpc3NvbHZlZEgAUg5ncm91cERpc3NvbHZlZBJZChdncm91cF'
    '9vd25lcl90cmFuc2ZlcnJlZBgOIAEoCzIfLndzLlNlcnZlckdyb3VwT3duZXJUcmFuc2ZlcnJl'
    'ZEgAUhVncm91cE93bmVyVHJhbnNmZXJyZWQSOgoMcm9vbV91cGRhdGVkGA8gASgLMhUud3MuU2'
    'VydmVyUm9vbVVwZGF0ZWRIAFILcm9vbVVwZGF0ZWRCCQoHcGF5bG9hZA==');

@$core.Deprecated('Use serverAuthedDescriptor instead')
const ServerAuthed$json = {
  '1': 'ServerAuthed',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'conn_id', '3': 2, '4': 1, '5': 9, '10': 'connId'},
  ],
};

/// Descriptor for `ServerAuthed`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverAuthedDescriptor = $convert.base64Decode(
    'CgxTZXJ2ZXJBdXRoZWQSFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEhcKB2Nvbm5faWQYAiABKA'
    'lSBmNvbm5JZA==');

@$core.Deprecated('Use serverJoinedDescriptor instead')
const ServerJoined$json = {
  '1': 'ServerJoined',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
  ],
};

/// Descriptor for `ServerJoined`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverJoinedDescriptor = $convert
    .base64Decode('CgxTZXJ2ZXJKb2luZWQSFwoHcm9vbV9pZBgBIAEoCVIGcm9vbUlk');

@$core.Deprecated('Use serverLeftDescriptor instead')
const ServerLeft$json = {
  '1': 'ServerLeft',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
  ],
};

/// Descriptor for `ServerLeft`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverLeftDescriptor = $convert
    .base64Decode('CgpTZXJ2ZXJMZWZ0EhcKB3Jvb21faWQYASABKAlSBnJvb21JZA==');

@$core.Deprecated('Use serverMessageDescriptor instead')
const ServerMessage$json = {
  '1': 'ServerMessage',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'message_id', '3': 2, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'room_id', '3': 3, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'sender_id', '3': 4, '4': 1, '5': 9, '10': 'senderId'},
    {'1': 'sender_username', '3': 5, '4': 1, '5': 9, '10': 'senderUsername'},
    {'1': 'sender_nickname', '3': 6, '4': 1, '5': 9, '10': 'senderNickname'},
    {'1': 'sender_avatar_url', '3': 7, '4': 1, '5': 9, '10': 'senderAvatarUrl'},
    {'1': 'content', '3': 8, '4': 1, '5': 9, '10': 'content'},
    {'1': 'message_type', '3': 9, '4': 1, '5': 9, '10': 'messageType'},
    {'1': 'timestamp', '3': 10, '4': 1, '5': 9, '10': 'timestamp'},
    {
      '1': 'quoted_message',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.ws.QuotedMessage',
      '10': 'quotedMessage'
    },
    {
      '1': 'forward_message',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.ws.ForwardMessage',
      '10': 'forwardMessage'
    },
    {
      '1': 'parts',
      '3': 13,
      '4': 3,
      '5': 11,
      '6': '.ws.MessagePart',
      '10': 'parts'
    },
  ],
};

/// Descriptor for `ServerMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverMessageDescriptor = $convert.base64Decode(
    'Cg1TZXJ2ZXJNZXNzYWdlEg4KAmlkGAEgASgJUgJpZBIdCgptZXNzYWdlX2lkGAIgASgJUgltZX'
    'NzYWdlSWQSFwoHcm9vbV9pZBgDIAEoCVIGcm9vbUlkEhsKCXNlbmRlcl9pZBgEIAEoCVIIc2Vu'
    'ZGVySWQSJwoPc2VuZGVyX3VzZXJuYW1lGAUgASgJUg5zZW5kZXJVc2VybmFtZRInCg9zZW5kZX'
    'Jfbmlja25hbWUYBiABKAlSDnNlbmRlck5pY2tuYW1lEioKEXNlbmRlcl9hdmF0YXJfdXJsGAcg'
    'ASgJUg9zZW5kZXJBdmF0YXJVcmwSGAoHY29udGVudBgIIAEoCVIHY29udGVudBIhCgxtZXNzYW'
    'dlX3R5cGUYCSABKAlSC21lc3NhZ2VUeXBlEhwKCXRpbWVzdGFtcBgKIAEoCVIJdGltZXN0YW1w'
    'EjgKDnF1b3RlZF9tZXNzYWdlGAsgASgLMhEud3MuUXVvdGVkTWVzc2FnZVINcXVvdGVkTWVzc2'
    'FnZRI7Cg9mb3J3YXJkX21lc3NhZ2UYDCABKAsyEi53cy5Gb3J3YXJkTWVzc2FnZVIOZm9yd2Fy'
    'ZE1lc3NhZ2USJQoFcGFydHMYDSADKAsyDy53cy5NZXNzYWdlUGFydFIFcGFydHM=');

@$core.Deprecated('Use quotedMessageDescriptor instead')
const QuotedMessage$json = {
  '1': 'QuotedMessage',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'room_id', '3': 2, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'sender_id', '3': 3, '4': 1, '5': 9, '10': 'senderId'},
    {'1': 'sender_username', '3': 4, '4': 1, '5': 9, '10': 'senderUsername'},
    {'1': 'sender_nickname', '3': 5, '4': 1, '5': 9, '10': 'senderNickname'},
    {'1': 'sender_avatar_url', '3': 6, '4': 1, '5': 9, '10': 'senderAvatarUrl'},
    {'1': 'content', '3': 7, '4': 1, '5': 9, '10': 'content'},
    {'1': 'message_type', '3': 8, '4': 1, '5': 9, '10': 'messageType'},
    {'1': 'created_at', '3': 9, '4': 1, '5': 9, '10': 'createdAt'},
    {'1': 'is_deleted', '3': 10, '4': 1, '5': 8, '10': 'isDeleted'},
    {
      '1': 'parts',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.ws.MessagePart',
      '10': 'parts'
    },
  ],
};

/// Descriptor for `QuotedMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List quotedMessageDescriptor = $convert.base64Decode(
    'Cg1RdW90ZWRNZXNzYWdlEg4KAmlkGAEgASgJUgJpZBIXCgdyb29tX2lkGAIgASgJUgZyb29tSW'
    'QSGwoJc2VuZGVyX2lkGAMgASgJUghzZW5kZXJJZBInCg9zZW5kZXJfdXNlcm5hbWUYBCABKAlS'
    'DnNlbmRlclVzZXJuYW1lEicKD3NlbmRlcl9uaWNrbmFtZRgFIAEoCVIOc2VuZGVyTmlja25hbW'
    'USKgoRc2VuZGVyX2F2YXRhcl91cmwYBiABKAlSD3NlbmRlckF2YXRhclVybBIYCgdjb250ZW50'
    'GAcgASgJUgdjb250ZW50EiEKDG1lc3NhZ2VfdHlwZRgIIAEoCVILbWVzc2FnZVR5cGUSHQoKY3'
    'JlYXRlZF9hdBgJIAEoCVIJY3JlYXRlZEF0Eh0KCmlzX2RlbGV0ZWQYCiABKAhSCWlzRGVsZXRl'
    'ZBIlCgVwYXJ0cxgLIAMoCzIPLndzLk1lc3NhZ2VQYXJ0UgVwYXJ0cw==');

@$core.Deprecated('Use forwardMessageDescriptor instead')
const ForwardMessage$json = {
  '1': 'ForwardMessage',
  '2': [
    {'1': 'message_id', '3': 1, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'room_id', '3': 2, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'sender_id', '3': 3, '4': 1, '5': 9, '10': 'senderId'},
    {'1': 'sender_username', '3': 4, '4': 1, '5': 9, '10': 'senderUsername'},
    {'1': 'sender_nickname', '3': 5, '4': 1, '5': 9, '10': 'senderNickname'},
  ],
};

/// Descriptor for `ForwardMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List forwardMessageDescriptor = $convert.base64Decode(
    'Cg5Gb3J3YXJkTWVzc2FnZRIdCgptZXNzYWdlX2lkGAEgASgJUgltZXNzYWdlSWQSFwoHcm9vbV'
    '9pZBgCIAEoCVIGcm9vbUlkEhsKCXNlbmRlcl9pZBgDIAEoCVIIc2VuZGVySWQSJwoPc2VuZGVy'
    'X3VzZXJuYW1lGAQgASgJUg5zZW5kZXJVc2VybmFtZRInCg9zZW5kZXJfbmlja25hbWUYBSABKA'
    'lSDnNlbmRlck5pY2tuYW1l');

@$core.Deprecated('Use messageAttachmentDescriptor instead')
const MessageAttachment$json = {
  '1': 'MessageAttachment',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'mime', '3': 3, '4': 1, '5': 9, '10': 'mime'},
    {'1': 'size', '3': 4, '4': 1, '5': 3, '10': 'size'},
    {'1': 'width', '3': 5, '4': 1, '5': 5, '10': 'width'},
    {'1': 'height', '3': 6, '4': 1, '5': 5, '10': 'height'},
    {'1': 'duration_ms', '3': 7, '4': 1, '5': 5, '10': 'durationMs'},
    {'1': 'thumbnail_key', '3': 8, '4': 1, '5': 9, '10': 'thumbnailKey'},
  ],
};

/// Descriptor for `MessageAttachment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageAttachmentDescriptor = $convert.base64Decode(
    'ChFNZXNzYWdlQXR0YWNobWVudBIQCgNrZXkYASABKAlSA2tleRISCgRuYW1lGAIgASgJUgRuYW'
    '1lEhIKBG1pbWUYAyABKAlSBG1pbWUSEgoEc2l6ZRgEIAEoA1IEc2l6ZRIUCgV3aWR0aBgFIAEo'
    'BVIFd2lkdGgSFgoGaGVpZ2h0GAYgASgFUgZoZWlnaHQSHwoLZHVyYXRpb25fbXMYByABKAVSCm'
    'R1cmF0aW9uTXMSIwoNdGh1bWJuYWlsX2tleRgIIAEoCVIMdGh1bWJuYWlsS2V5');

@$core.Deprecated('Use messagePartDescriptor instead')
const MessagePart$json = {
  '1': 'MessagePart',
  '2': [
    {'1': 'position', '3': 1, '4': 1, '5': 5, '10': 'position'},
    {'1': 'part_type', '3': 2, '4': 1, '5': 9, '10': 'partType'},
    {'1': 'text', '3': 3, '4': 1, '5': 9, '10': 'text'},
    {
      '1': 'attachment',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.ws.MessageAttachment',
      '10': 'attachment'
    },
  ],
};

/// Descriptor for `MessagePart`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messagePartDescriptor = $convert.base64Decode(
    'CgtNZXNzYWdlUGFydBIaCghwb3NpdGlvbhgBIAEoBVIIcG9zaXRpb24SGwoJcGFydF90eXBlGA'
    'IgASgJUghwYXJ0VHlwZRISCgR0ZXh0GAMgASgJUgR0ZXh0EjUKCmF0dGFjaG1lbnQYBCABKAsy'
    'FS53cy5NZXNzYWdlQXR0YWNobWVudFIKYXR0YWNobWVudA==');

@$core.Deprecated('Use serverMessageReadDescriptor instead')
const ServerMessageRead$json = {
  '1': 'ServerMessageRead',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'message_id', '3': 2, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'reader_id', '3': 3, '4': 1, '5': 9, '10': 'readerId'},
    {'1': 'read_at', '3': 4, '4': 1, '5': 9, '10': 'readAt'},
  ],
};

/// Descriptor for `ServerMessageRead`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverMessageReadDescriptor = $convert.base64Decode(
    'ChFTZXJ2ZXJNZXNzYWdlUmVhZBIXCgdyb29tX2lkGAEgASgJUgZyb29tSWQSHQoKbWVzc2FnZV'
    '9pZBgCIAEoCVIJbWVzc2FnZUlkEhsKCXJlYWRlcl9pZBgDIAEoCVIIcmVhZGVySWQSFwoHcmVh'
    'ZF9hdBgEIAEoCVIGcmVhZEF0');

@$core.Deprecated('Use serverMessageUpdateDescriptor instead')
const ServerMessageUpdate$json = {
  '1': 'ServerMessageUpdate',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'message_id', '3': 2, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'is_deleted', '3': 3, '4': 1, '5': 8, '10': 'isDeleted'},
    {'1': 'deleted_at', '3': 4, '4': 1, '5': 9, '10': 'deletedAt'},
  ],
};

/// Descriptor for `ServerMessageUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverMessageUpdateDescriptor = $convert.base64Decode(
    'ChNTZXJ2ZXJNZXNzYWdlVXBkYXRlEhcKB3Jvb21faWQYASABKAlSBnJvb21JZBIdCgptZXNzYW'
    'dlX2lkGAIgASgJUgltZXNzYWdlSWQSHQoKaXNfZGVsZXRlZBgDIAEoCFIJaXNEZWxldGVkEh0K'
    'CmRlbGV0ZWRfYXQYBCABKAlSCWRlbGV0ZWRBdA==');

@$core.Deprecated('Use serverPinUpdateDescriptor instead')
const ServerPinUpdate$json = {
  '1': 'ServerPinUpdate',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'message_id', '3': 2, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'is_pinned', '3': 3, '4': 1, '5': 8, '10': 'isPinned'},
    {'1': 'pinned_at', '3': 4, '4': 1, '5': 9, '10': 'pinnedAt'},
    {'1': 'pinned_by', '3': 5, '4': 1, '5': 9, '10': 'pinnedBy'},
  ],
};

/// Descriptor for `ServerPinUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverPinUpdateDescriptor = $convert.base64Decode(
    'Cg9TZXJ2ZXJQaW5VcGRhdGUSFwoHcm9vbV9pZBgBIAEoCVIGcm9vbUlkEh0KCm1lc3NhZ2VfaW'
    'QYAiABKAlSCW1lc3NhZ2VJZBIbCglpc19waW5uZWQYAyABKAhSCGlzUGlubmVkEhsKCXBpbm5l'
    'ZF9hdBgEIAEoCVIIcGlubmVkQXQSGwoJcGlubmVkX2J5GAUgASgJUghwaW5uZWRCeQ==');

@$core.Deprecated('Use serverErrorDescriptor instead')
const ServerError$json = {
  '1': 'ServerError',
  '2': [
    {'1': 'message', '3': 1, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `ServerError`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverErrorDescriptor = $convert
    .base64Decode('CgtTZXJ2ZXJFcnJvchIYCgdtZXNzYWdlGAEgASgJUgdtZXNzYWdl');

@$core.Deprecated('Use serverPongDescriptor instead')
const ServerPong$json = {
  '1': 'ServerPong',
};

/// Descriptor for `ServerPong`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverPongDescriptor =
    $convert.base64Decode('CgpTZXJ2ZXJQb25n');

@$core.Deprecated('Use serverFriendRequestUpdateDescriptor instead')
const ServerFriendRequestUpdate$json = {
  '1': 'ServerFriendRequestUpdate',
  '2': [
    {'1': 'pending_count', '3': 1, '4': 1, '5': 5, '10': 'pendingCount'},
  ],
};

/// Descriptor for `ServerFriendRequestUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverFriendRequestUpdateDescriptor =
    $convert.base64Decode(
        'ChlTZXJ2ZXJGcmllbmRSZXF1ZXN0VXBkYXRlEiMKDXBlbmRpbmdfY291bnQYASABKAVSDHBlbm'
        'RpbmdDb3VudA==');

@$core.Deprecated('Use serverRoomCreatedDescriptor instead')
const ServerRoomCreated$json = {
  '1': 'ServerRoomCreated',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'room_name', '3': 2, '4': 1, '5': 9, '10': 'roomName'},
    {'1': 'room_type', '3': 3, '4': 1, '5': 9, '10': 'roomType'},
    {'1': 'initiator_id', '3': 4, '4': 1, '5': 9, '10': 'initiatorId'},
    {'1': 'owner_id', '3': 5, '4': 1, '5': 9, '10': 'ownerId'},
    {'1': 'description', '3': 6, '4': 1, '5': 9, '10': 'description'},
    {'1': 'avatar_url', '3': 7, '4': 1, '5': 9, '10': 'avatarUrl'},
    {'1': 'created_at', '3': 8, '4': 1, '5': 9, '10': 'createdAt'},
  ],
};

/// Descriptor for `ServerRoomCreated`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverRoomCreatedDescriptor = $convert.base64Decode(
    'ChFTZXJ2ZXJSb29tQ3JlYXRlZBIXCgdyb29tX2lkGAEgASgJUgZyb29tSWQSGwoJcm9vbV9uYW'
    '1lGAIgASgJUghyb29tTmFtZRIbCglyb29tX3R5cGUYAyABKAlSCHJvb21UeXBlEiEKDGluaXRp'
    'YXRvcl9pZBgEIAEoCVILaW5pdGlhdG9ySWQSGQoIb3duZXJfaWQYBSABKAlSB293bmVySWQSIA'
    'oLZGVzY3JpcHRpb24YBiABKAlSC2Rlc2NyaXB0aW9uEh0KCmF2YXRhcl91cmwYByABKAlSCWF2'
    'YXRhclVybBIdCgpjcmVhdGVkX2F0GAggASgJUgljcmVhdGVkQXQ=');

@$core.Deprecated('Use serverBannedDescriptor instead')
const ServerBanned$json = {
  '1': 'ServerBanned',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `ServerBanned`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverBannedDescriptor = $convert.base64Decode(
    'CgxTZXJ2ZXJCYW5uZWQSFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEhYKBnJlYXNvbhgCIAEoCV'
    'IGcmVhc29u');

@$core.Deprecated('Use serverGroupDissolvedDescriptor instead')
const ServerGroupDissolved$json = {
  '1': 'ServerGroupDissolved',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
  ],
};

/// Descriptor for `ServerGroupDissolved`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverGroupDissolvedDescriptor =
    $convert.base64Decode(
        'ChRTZXJ2ZXJHcm91cERpc3NvbHZlZBIXCgdyb29tX2lkGAEgASgJUgZyb29tSWQ=');

@$core.Deprecated('Use serverGroupOwnerTransferredDescriptor instead')
const ServerGroupOwnerTransferred$json = {
  '1': 'ServerGroupOwnerTransferred',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'old_owner_id', '3': 2, '4': 1, '5': 9, '10': 'oldOwnerId'},
    {'1': 'new_owner_id', '3': 3, '4': 1, '5': 9, '10': 'newOwnerId'},
  ],
};

/// Descriptor for `ServerGroupOwnerTransferred`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverGroupOwnerTransferredDescriptor =
    $convert.base64Decode(
        'ChtTZXJ2ZXJHcm91cE93bmVyVHJhbnNmZXJyZWQSFwoHcm9vbV9pZBgBIAEoCVIGcm9vbUlkEi'
        'AKDG9sZF9vd25lcl9pZBgCIAEoCVIKb2xkT3duZXJJZBIgCgxuZXdfb3duZXJfaWQYAyABKAlS'
        'Cm5ld093bmVySWQ=');

@$core.Deprecated('Use serverRoomUpdatedDescriptor instead')
const ServerRoomUpdated$json = {
  '1': 'ServerRoomUpdated',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'room_name', '3': 2, '4': 1, '5': 9, '10': 'roomName'},
    {'1': 'room_type', '3': 3, '4': 1, '5': 9, '10': 'roomType'},
    {'1': 'avatar_url', '3': 4, '4': 1, '5': 9, '10': 'avatarUrl'},
    {'1': 'avatar_object_key', '3': 5, '4': 1, '5': 9, '10': 'avatarObjectKey'},
    {'1': 'description', '3': 6, '4': 1, '5': 9, '10': 'description'},
  ],
};

/// Descriptor for `ServerRoomUpdated`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverRoomUpdatedDescriptor = $convert.base64Decode(
    'ChFTZXJ2ZXJSb29tVXBkYXRlZBIXCgdyb29tX2lkGAEgASgJUgZyb29tSWQSGwoJcm9vbV9uYW'
    '1lGAIgASgJUghyb29tTmFtZRIbCglyb29tX3R5cGUYAyABKAlSCHJvb21UeXBlEh0KCmF2YXRh'
    'cl91cmwYBCABKAlSCWF2YXRhclVybBIqChFhdmF0YXJfb2JqZWN0X2tleRgFIAEoCVIPYXZhdG'
    'FyT2JqZWN0S2V5EiAKC2Rlc2NyaXB0aW9uGAYgASgJUgtkZXNjcmlwdGlvbg==');

@$core.Deprecated('Use pubSubMessageDescriptor instead')
const PubSubMessage$json = {
  '1': 'PubSubMessage',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'room_id', '3': 2, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'sender_id', '3': 3, '4': 1, '5': 9, '10': 'senderId'},
    {'1': 'content', '3': 4, '4': 1, '5': 9, '10': 'content'},
    {'1': 'message_type', '3': 5, '4': 1, '5': 9, '10': 'messageType'},
    {
      '1': 'priority',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.ws.PubSubPriority',
      '10': 'priority'
    },
    {'1': 'timestamp', '3': 7, '4': 1, '5': 9, '10': 'timestamp'},
    {'1': 'source_node', '3': 8, '4': 1, '5': 9, '10': 'sourceNode'},
    {'1': 'target_nodes', '3': 9, '4': 3, '5': 9, '10': 'targetNodes'},
    {'1': 'sender_username', '3': 10, '4': 1, '5': 9, '10': 'senderUsername'},
    {'1': 'sender_nickname', '3': 11, '4': 1, '5': 9, '10': 'senderNickname'},
    {
      '1': 'sender_avatar_url',
      '3': 12,
      '4': 1,
      '5': 9,
      '10': 'senderAvatarUrl'
    },
    {
      '1': 'quoted_message',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.ws.QuotedMessage',
      '10': 'quotedMessage'
    },
    {
      '1': 'forward_message',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.ws.ForwardMessage',
      '10': 'forwardMessage'
    },
    {
      '1': 'parts',
      '3': 15,
      '4': 3,
      '5': 11,
      '6': '.ws.MessagePart',
      '10': 'parts'
    },
  ],
};

/// Descriptor for `PubSubMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pubSubMessageDescriptor = $convert.base64Decode(
    'Cg1QdWJTdWJNZXNzYWdlEg4KAmlkGAEgASgJUgJpZBIXCgdyb29tX2lkGAIgASgJUgZyb29tSW'
    'QSGwoJc2VuZGVyX2lkGAMgASgJUghzZW5kZXJJZBIYCgdjb250ZW50GAQgASgJUgdjb250ZW50'
    'EiEKDG1lc3NhZ2VfdHlwZRgFIAEoCVILbWVzc2FnZVR5cGUSLgoIcHJpb3JpdHkYBiABKA4yEi'
    '53cy5QdWJTdWJQcmlvcml0eVIIcHJpb3JpdHkSHAoJdGltZXN0YW1wGAcgASgJUgl0aW1lc3Rh'
    'bXASHwoLc291cmNlX25vZGUYCCABKAlSCnNvdXJjZU5vZGUSIQoMdGFyZ2V0X25vZGVzGAkgAy'
    'gJUgt0YXJnZXROb2RlcxInCg9zZW5kZXJfdXNlcm5hbWUYCiABKAlSDnNlbmRlclVzZXJuYW1l'
    'EicKD3NlbmRlcl9uaWNrbmFtZRgLIAEoCVIOc2VuZGVyTmlja25hbWUSKgoRc2VuZGVyX2F2YX'
    'Rhcl91cmwYDCABKAlSD3NlbmRlckF2YXRhclVybBI4Cg5xdW90ZWRfbWVzc2FnZRgNIAEoCzIR'
    'LndzLlF1b3RlZE1lc3NhZ2VSDXF1b3RlZE1lc3NhZ2USOwoPZm9yd2FyZF9tZXNzYWdlGA4gAS'
    'gLMhIud3MuRm9yd2FyZE1lc3NhZ2VSDmZvcndhcmRNZXNzYWdlEiUKBXBhcnRzGA8gAygLMg8u'
    'd3MuTWVzc2FnZVBhcnRSBXBhcnRz');

@$core.Deprecated('Use pubSubReadReceiptDescriptor instead')
const PubSubReadReceipt$json = {
  '1': 'PubSubReadReceipt',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'reader_id', '3': 2, '4': 1, '5': 9, '10': 'readerId'},
    {'1': 'message_id', '3': 3, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'read_at', '3': 4, '4': 1, '5': 9, '10': 'readAt'},
    {'1': 'source_node', '3': 5, '4': 1, '5': 9, '10': 'sourceNode'},
  ],
};

/// Descriptor for `PubSubReadReceipt`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pubSubReadReceiptDescriptor = $convert.base64Decode(
    'ChFQdWJTdWJSZWFkUmVjZWlwdBIXCgdyb29tX2lkGAEgASgJUgZyb29tSWQSGwoJcmVhZGVyX2'
    'lkGAIgASgJUghyZWFkZXJJZBIdCgptZXNzYWdlX2lkGAMgASgJUgltZXNzYWdlSWQSFwoHcmVh'
    'ZF9hdBgEIAEoCVIGcmVhZEF0Eh8KC3NvdXJjZV9ub2RlGAUgASgJUgpzb3VyY2VOb2Rl');

@$core.Deprecated('Use pubSubMessageUpdateDescriptor instead')
const PubSubMessageUpdate$json = {
  '1': 'PubSubMessageUpdate',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'message_id', '3': 2, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'is_deleted', '3': 3, '4': 1, '5': 8, '10': 'isDeleted'},
    {'1': 'deleted_at', '3': 4, '4': 1, '5': 9, '10': 'deletedAt'},
  ],
};

/// Descriptor for `PubSubMessageUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pubSubMessageUpdateDescriptor = $convert.base64Decode(
    'ChNQdWJTdWJNZXNzYWdlVXBkYXRlEhcKB3Jvb21faWQYASABKAlSBnJvb21JZBIdCgptZXNzYW'
    'dlX2lkGAIgASgJUgltZXNzYWdlSWQSHQoKaXNfZGVsZXRlZBgDIAEoCFIJaXNEZWxldGVkEh0K'
    'CmRlbGV0ZWRfYXQYBCABKAlSCWRlbGV0ZWRBdA==');

@$core.Deprecated('Use pubSubPinUpdateDescriptor instead')
const PubSubPinUpdate$json = {
  '1': 'PubSubPinUpdate',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'message_id', '3': 2, '4': 1, '5': 9, '10': 'messageId'},
    {'1': 'is_pinned', '3': 3, '4': 1, '5': 8, '10': 'isPinned'},
    {'1': 'pinned_at', '3': 4, '4': 1, '5': 9, '10': 'pinnedAt'},
    {'1': 'pinned_by', '3': 5, '4': 1, '5': 9, '10': 'pinnedBy'},
  ],
};

/// Descriptor for `PubSubPinUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pubSubPinUpdateDescriptor = $convert.base64Decode(
    'Cg9QdWJTdWJQaW5VcGRhdGUSFwoHcm9vbV9pZBgBIAEoCVIGcm9vbUlkEh0KCm1lc3NhZ2VfaW'
    'QYAiABKAlSCW1lc3NhZ2VJZBIbCglpc19waW5uZWQYAyABKAhSCGlzUGlubmVkEhsKCXBpbm5l'
    'ZF9hdBgEIAEoCVIIcGlubmVkQXQSGwoJcGlubmVkX2J5GAUgASgJUghwaW5uZWRCeQ==');

@$core.Deprecated('Use pubSubRoomUpdateDescriptor instead')
const PubSubRoomUpdate$json = {
  '1': 'PubSubRoomUpdate',
  '2': [
    {'1': 'room_id', '3': 1, '4': 1, '5': 9, '10': 'roomId'},
    {'1': 'room_name', '3': 2, '4': 1, '5': 9, '10': 'roomName'},
    {'1': 'room_type', '3': 3, '4': 1, '5': 9, '10': 'roomType'},
    {'1': 'avatar_url', '3': 4, '4': 1, '5': 9, '10': 'avatarUrl'},
    {'1': 'avatar_object_key', '3': 5, '4': 1, '5': 9, '10': 'avatarObjectKey'},
    {'1': 'description', '3': 6, '4': 1, '5': 9, '10': 'description'},
  ],
};

/// Descriptor for `PubSubRoomUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pubSubRoomUpdateDescriptor = $convert.base64Decode(
    'ChBQdWJTdWJSb29tVXBkYXRlEhcKB3Jvb21faWQYASABKAlSBnJvb21JZBIbCglyb29tX25hbW'
    'UYAiABKAlSCHJvb21OYW1lEhsKCXJvb21fdHlwZRgDIAEoCVIIcm9vbVR5cGUSHQoKYXZhdGFy'
    'X3VybBgEIAEoCVIJYXZhdGFyVXJsEioKEWF2YXRhcl9vYmplY3Rfa2V5GAUgASgJUg9hdmF0YX'
    'JPYmplY3RLZXkSIAoLZGVzY3JpcHRpb24YBiABKAlSC2Rlc2NyaXB0aW9u');

@$core.Deprecated('Use pubSubEventDescriptor instead')
const PubSubEvent$json = {
  '1': 'PubSubEvent',
  '2': [
    {
      '1': 'message',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.ws.PubSubMessage',
      '9': 0,
      '10': 'message'
    },
    {
      '1': 'read_receipt',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.ws.PubSubReadReceipt',
      '9': 0,
      '10': 'readReceipt'
    },
    {
      '1': 'message_update',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.ws.PubSubMessageUpdate',
      '9': 0,
      '10': 'messageUpdate'
    },
    {
      '1': 'pin_update',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.ws.PubSubPinUpdate',
      '9': 0,
      '10': 'pinUpdate'
    },
    {
      '1': 'room_update',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.ws.PubSubRoomUpdate',
      '9': 0,
      '10': 'roomUpdate'
    },
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `PubSubEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pubSubEventDescriptor = $convert.base64Decode(
    'CgtQdWJTdWJFdmVudBItCgdtZXNzYWdlGAEgASgLMhEud3MuUHViU3ViTWVzc2FnZUgAUgdtZX'
    'NzYWdlEjoKDHJlYWRfcmVjZWlwdBgCIAEoCzIVLndzLlB1YlN1YlJlYWRSZWNlaXB0SABSC3Jl'
    'YWRSZWNlaXB0EkAKDm1lc3NhZ2VfdXBkYXRlGAMgASgLMhcud3MuUHViU3ViTWVzc2FnZVVwZG'
    'F0ZUgAUg1tZXNzYWdlVXBkYXRlEjQKCnBpbl91cGRhdGUYBCABKAsyEy53cy5QdWJTdWJQaW5V'
    'cGRhdGVIAFIJcGluVXBkYXRlEjcKC3Jvb21fdXBkYXRlGAUgASgLMhQud3MuUHViU3ViUm9vbV'
    'VwZGF0ZUgAUgpyb29tVXBkYXRlQgkKB3BheWxvYWQ=');
