// This is a generated file - do not edit.
//
// Generated from ws.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'ws.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'ws.pbenum.dart';

enum ClientEvent_Payload { auth, join, leave, ping, notSet }

class ClientEvent extends $pb.GeneratedMessage {
  factory ClientEvent({
    ClientAuth? auth,
    ClientJoin? join,
    ClientLeave? leave,
    ClientPing? ping,
  }) {
    final result = create();
    if (auth != null) result.auth = auth;
    if (join != null) result.join = join;
    if (leave != null) result.leave = leave;
    if (ping != null) result.ping = ping;
    return result;
  }

  ClientEvent._();

  factory ClientEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ClientEvent_Payload>
      _ClientEvent_PayloadByTag = {
    1: ClientEvent_Payload.auth,
    2: ClientEvent_Payload.join,
    3: ClientEvent_Payload.leave,
    4: ClientEvent_Payload.ping,
    0: ClientEvent_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4])
    ..aOM<ClientAuth>(1, _omitFieldNames ? '' : 'auth',
        subBuilder: ClientAuth.create)
    ..aOM<ClientJoin>(2, _omitFieldNames ? '' : 'join',
        subBuilder: ClientJoin.create)
    ..aOM<ClientLeave>(3, _omitFieldNames ? '' : 'leave',
        subBuilder: ClientLeave.create)
    ..aOM<ClientPing>(4, _omitFieldNames ? '' : 'ping',
        subBuilder: ClientPing.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientEvent copyWith(void Function(ClientEvent) updates) =>
      super.copyWith((message) => updates(message as ClientEvent))
          as ClientEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientEvent create() => ClientEvent._();
  @$core.override
  ClientEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientEvent>(create);
  static ClientEvent? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  ClientEvent_Payload whichPayload() =>
      _ClientEvent_PayloadByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  void clearPayload() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  ClientAuth get auth => $_getN(0);
  @$pb.TagNumber(1)
  set auth(ClientAuth value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAuth() => $_has(0);
  @$pb.TagNumber(1)
  void clearAuth() => $_clearField(1);
  @$pb.TagNumber(1)
  ClientAuth ensureAuth() => $_ensure(0);

  @$pb.TagNumber(2)
  ClientJoin get join => $_getN(1);
  @$pb.TagNumber(2)
  set join(ClientJoin value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasJoin() => $_has(1);
  @$pb.TagNumber(2)
  void clearJoin() => $_clearField(2);
  @$pb.TagNumber(2)
  ClientJoin ensureJoin() => $_ensure(1);

  @$pb.TagNumber(3)
  ClientLeave get leave => $_getN(2);
  @$pb.TagNumber(3)
  set leave(ClientLeave value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasLeave() => $_has(2);
  @$pb.TagNumber(3)
  void clearLeave() => $_clearField(3);
  @$pb.TagNumber(3)
  ClientLeave ensureLeave() => $_ensure(2);

  @$pb.TagNumber(4)
  ClientPing get ping => $_getN(3);
  @$pb.TagNumber(4)
  set ping(ClientPing value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasPing() => $_has(3);
  @$pb.TagNumber(4)
  void clearPing() => $_clearField(4);
  @$pb.TagNumber(4)
  ClientPing ensurePing() => $_ensure(3);
}

class ClientAuth extends $pb.GeneratedMessage {
  factory ClientAuth({
    $core.String? token,
  }) {
    final result = create();
    if (token != null) result.token = token;
    return result;
  }

  ClientAuth._();

  factory ClientAuth.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientAuth.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientAuth',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientAuth clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientAuth copyWith(void Function(ClientAuth) updates) =>
      super.copyWith((message) => updates(message as ClientAuth)) as ClientAuth;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientAuth create() => ClientAuth._();
  @$core.override
  ClientAuth createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientAuth getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientAuth>(create);
  static ClientAuth? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => $_clearField(1);
}

class ClientJoin extends $pb.GeneratedMessage {
  factory ClientJoin({
    $core.String? roomId,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    return result;
  }

  ClientJoin._();

  factory ClientJoin.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientJoin.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientJoin',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientJoin clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientJoin copyWith(void Function(ClientJoin) updates) =>
      super.copyWith((message) => updates(message as ClientJoin)) as ClientJoin;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientJoin create() => ClientJoin._();
  @$core.override
  ClientJoin createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientJoin getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientJoin>(create);
  static ClientJoin? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);
}

class ClientLeave extends $pb.GeneratedMessage {
  factory ClientLeave({
    $core.String? roomId,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    return result;
  }

  ClientLeave._();

  factory ClientLeave.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientLeave.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientLeave',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientLeave clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientLeave copyWith(void Function(ClientLeave) updates) =>
      super.copyWith((message) => updates(message as ClientLeave))
          as ClientLeave;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientLeave create() => ClientLeave._();
  @$core.override
  ClientLeave createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientLeave getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientLeave>(create);
  static ClientLeave? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);
}

class ClientPing extends $pb.GeneratedMessage {
  factory ClientPing() => create();

  ClientPing._();

  factory ClientPing.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientPing.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientPing',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientPing clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientPing copyWith(void Function(ClientPing) updates) =>
      super.copyWith((message) => updates(message as ClientPing)) as ClientPing;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientPing create() => ClientPing._();
  @$core.override
  ClientPing createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientPing getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientPing>(create);
  static ClientPing? _defaultInstance;
}

enum ServerEvent_Payload {
  authed,
  joined,
  left,
  message,
  messageRead,
  messageUpdate,
  pinUpdate,
  error,
  pong,
  friendRequestUpdate,
  roomCreated,
  userBanned,
  groupDissolved,
  groupOwnerTransferred,
  roomUpdated,
  groupSettingsUpdated,
  groupMemberChanged,
  friendProfileUpdated,
  notSet
}

class ServerEvent extends $pb.GeneratedMessage {
  factory ServerEvent({
    ServerAuthed? authed,
    ServerJoined? joined,
    ServerLeft? left,
    ServerMessage? message,
    ServerMessageRead? messageRead,
    ServerMessageUpdate? messageUpdate,
    ServerPinUpdate? pinUpdate,
    ServerError? error,
    ServerPong? pong,
    ServerFriendRequestUpdate? friendRequestUpdate,
    ServerRoomCreated? roomCreated,
    ServerBanned? userBanned,
    ServerGroupDissolved? groupDissolved,
    ServerGroupOwnerTransferred? groupOwnerTransferred,
    ServerRoomUpdated? roomUpdated,
    ServerGroupSettingsUpdated? groupSettingsUpdated,
    ServerGroupMemberChanged? groupMemberChanged,
    ServerFriendProfileUpdated? friendProfileUpdated,
  }) {
    final result = create();
    if (authed != null) result.authed = authed;
    if (joined != null) result.joined = joined;
    if (left != null) result.left = left;
    if (message != null) result.message = message;
    if (messageRead != null) result.messageRead = messageRead;
    if (messageUpdate != null) result.messageUpdate = messageUpdate;
    if (pinUpdate != null) result.pinUpdate = pinUpdate;
    if (error != null) result.error = error;
    if (pong != null) result.pong = pong;
    if (friendRequestUpdate != null)
      result.friendRequestUpdate = friendRequestUpdate;
    if (roomCreated != null) result.roomCreated = roomCreated;
    if (userBanned != null) result.userBanned = userBanned;
    if (groupDissolved != null) result.groupDissolved = groupDissolved;
    if (groupOwnerTransferred != null)
      result.groupOwnerTransferred = groupOwnerTransferred;
    if (roomUpdated != null) result.roomUpdated = roomUpdated;
    if (groupSettingsUpdated != null)
      result.groupSettingsUpdated = groupSettingsUpdated;
    if (groupMemberChanged != null)
      result.groupMemberChanged = groupMemberChanged;
    if (friendProfileUpdated != null)
      result.friendProfileUpdated = friendProfileUpdated;
    return result;
  }

  ServerEvent._();

  factory ServerEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ServerEvent_Payload>
      _ServerEvent_PayloadByTag = {
    1: ServerEvent_Payload.authed,
    2: ServerEvent_Payload.joined,
    3: ServerEvent_Payload.left,
    4: ServerEvent_Payload.message,
    5: ServerEvent_Payload.messageRead,
    6: ServerEvent_Payload.messageUpdate,
    7: ServerEvent_Payload.pinUpdate,
    8: ServerEvent_Payload.error,
    9: ServerEvent_Payload.pong,
    10: ServerEvent_Payload.friendRequestUpdate,
    11: ServerEvent_Payload.roomCreated,
    12: ServerEvent_Payload.userBanned,
    13: ServerEvent_Payload.groupDissolved,
    14: ServerEvent_Payload.groupOwnerTransferred,
    15: ServerEvent_Payload.roomUpdated,
    16: ServerEvent_Payload.groupSettingsUpdated,
    17: ServerEvent_Payload.groupMemberChanged,
    18: ServerEvent_Payload.friendProfileUpdated,
    0: ServerEvent_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18])
    ..aOM<ServerAuthed>(1, _omitFieldNames ? '' : 'authed',
        subBuilder: ServerAuthed.create)
    ..aOM<ServerJoined>(2, _omitFieldNames ? '' : 'joined',
        subBuilder: ServerJoined.create)
    ..aOM<ServerLeft>(3, _omitFieldNames ? '' : 'left',
        subBuilder: ServerLeft.create)
    ..aOM<ServerMessage>(4, _omitFieldNames ? '' : 'message',
        subBuilder: ServerMessage.create)
    ..aOM<ServerMessageRead>(5, _omitFieldNames ? '' : 'messageRead',
        subBuilder: ServerMessageRead.create)
    ..aOM<ServerMessageUpdate>(6, _omitFieldNames ? '' : 'messageUpdate',
        subBuilder: ServerMessageUpdate.create)
    ..aOM<ServerPinUpdate>(7, _omitFieldNames ? '' : 'pinUpdate',
        subBuilder: ServerPinUpdate.create)
    ..aOM<ServerError>(8, _omitFieldNames ? '' : 'error',
        subBuilder: ServerError.create)
    ..aOM<ServerPong>(9, _omitFieldNames ? '' : 'pong',
        subBuilder: ServerPong.create)
    ..aOM<ServerFriendRequestUpdate>(
        10, _omitFieldNames ? '' : 'friendRequestUpdate',
        subBuilder: ServerFriendRequestUpdate.create)
    ..aOM<ServerRoomCreated>(11, _omitFieldNames ? '' : 'roomCreated',
        subBuilder: ServerRoomCreated.create)
    ..aOM<ServerBanned>(12, _omitFieldNames ? '' : 'userBanned',
        subBuilder: ServerBanned.create)
    ..aOM<ServerGroupDissolved>(13, _omitFieldNames ? '' : 'groupDissolved',
        subBuilder: ServerGroupDissolved.create)
    ..aOM<ServerGroupOwnerTransferred>(
        14, _omitFieldNames ? '' : 'groupOwnerTransferred',
        subBuilder: ServerGroupOwnerTransferred.create)
    ..aOM<ServerRoomUpdated>(15, _omitFieldNames ? '' : 'roomUpdated',
        subBuilder: ServerRoomUpdated.create)
    ..aOM<ServerGroupSettingsUpdated>(
        16, _omitFieldNames ? '' : 'groupSettingsUpdated',
        subBuilder: ServerGroupSettingsUpdated.create)
    ..aOM<ServerGroupMemberChanged>(
        17, _omitFieldNames ? '' : 'groupMemberChanged',
        subBuilder: ServerGroupMemberChanged.create)
    ..aOM<ServerFriendProfileUpdated>(
        18, _omitFieldNames ? '' : 'friendProfileUpdated',
        subBuilder: ServerFriendProfileUpdated.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerEvent copyWith(void Function(ServerEvent) updates) =>
      super.copyWith((message) => updates(message as ServerEvent))
          as ServerEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerEvent create() => ServerEvent._();
  @$core.override
  ServerEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerEvent>(create);
  static ServerEvent? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  ServerEvent_Payload whichPayload() =>
      _ServerEvent_PayloadByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  void clearPayload() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  ServerAuthed get authed => $_getN(0);
  @$pb.TagNumber(1)
  set authed(ServerAuthed value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAuthed() => $_has(0);
  @$pb.TagNumber(1)
  void clearAuthed() => $_clearField(1);
  @$pb.TagNumber(1)
  ServerAuthed ensureAuthed() => $_ensure(0);

  @$pb.TagNumber(2)
  ServerJoined get joined => $_getN(1);
  @$pb.TagNumber(2)
  set joined(ServerJoined value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasJoined() => $_has(1);
  @$pb.TagNumber(2)
  void clearJoined() => $_clearField(2);
  @$pb.TagNumber(2)
  ServerJoined ensureJoined() => $_ensure(1);

  @$pb.TagNumber(3)
  ServerLeft get left => $_getN(2);
  @$pb.TagNumber(3)
  set left(ServerLeft value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasLeft() => $_has(2);
  @$pb.TagNumber(3)
  void clearLeft() => $_clearField(3);
  @$pb.TagNumber(3)
  ServerLeft ensureLeft() => $_ensure(2);

  @$pb.TagNumber(4)
  ServerMessage get message => $_getN(3);
  @$pb.TagNumber(4)
  set message(ServerMessage value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasMessage() => $_has(3);
  @$pb.TagNumber(4)
  void clearMessage() => $_clearField(4);
  @$pb.TagNumber(4)
  ServerMessage ensureMessage() => $_ensure(3);

  @$pb.TagNumber(5)
  ServerMessageRead get messageRead => $_getN(4);
  @$pb.TagNumber(5)
  set messageRead(ServerMessageRead value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasMessageRead() => $_has(4);
  @$pb.TagNumber(5)
  void clearMessageRead() => $_clearField(5);
  @$pb.TagNumber(5)
  ServerMessageRead ensureMessageRead() => $_ensure(4);

  @$pb.TagNumber(6)
  ServerMessageUpdate get messageUpdate => $_getN(5);
  @$pb.TagNumber(6)
  set messageUpdate(ServerMessageUpdate value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasMessageUpdate() => $_has(5);
  @$pb.TagNumber(6)
  void clearMessageUpdate() => $_clearField(6);
  @$pb.TagNumber(6)
  ServerMessageUpdate ensureMessageUpdate() => $_ensure(5);

  @$pb.TagNumber(7)
  ServerPinUpdate get pinUpdate => $_getN(6);
  @$pb.TagNumber(7)
  set pinUpdate(ServerPinUpdate value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasPinUpdate() => $_has(6);
  @$pb.TagNumber(7)
  void clearPinUpdate() => $_clearField(7);
  @$pb.TagNumber(7)
  ServerPinUpdate ensurePinUpdate() => $_ensure(6);

  @$pb.TagNumber(8)
  ServerError get error => $_getN(7);
  @$pb.TagNumber(8)
  set error(ServerError value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasError() => $_has(7);
  @$pb.TagNumber(8)
  void clearError() => $_clearField(8);
  @$pb.TagNumber(8)
  ServerError ensureError() => $_ensure(7);

  @$pb.TagNumber(9)
  ServerPong get pong => $_getN(8);
  @$pb.TagNumber(9)
  set pong(ServerPong value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasPong() => $_has(8);
  @$pb.TagNumber(9)
  void clearPong() => $_clearField(9);
  @$pb.TagNumber(9)
  ServerPong ensurePong() => $_ensure(8);

  @$pb.TagNumber(10)
  ServerFriendRequestUpdate get friendRequestUpdate => $_getN(9);
  @$pb.TagNumber(10)
  set friendRequestUpdate(ServerFriendRequestUpdate value) =>
      $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasFriendRequestUpdate() => $_has(9);
  @$pb.TagNumber(10)
  void clearFriendRequestUpdate() => $_clearField(10);
  @$pb.TagNumber(10)
  ServerFriendRequestUpdate ensureFriendRequestUpdate() => $_ensure(9);

  @$pb.TagNumber(11)
  ServerRoomCreated get roomCreated => $_getN(10);
  @$pb.TagNumber(11)
  set roomCreated(ServerRoomCreated value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasRoomCreated() => $_has(10);
  @$pb.TagNumber(11)
  void clearRoomCreated() => $_clearField(11);
  @$pb.TagNumber(11)
  ServerRoomCreated ensureRoomCreated() => $_ensure(10);

  @$pb.TagNumber(12)
  ServerBanned get userBanned => $_getN(11);
  @$pb.TagNumber(12)
  set userBanned(ServerBanned value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasUserBanned() => $_has(11);
  @$pb.TagNumber(12)
  void clearUserBanned() => $_clearField(12);
  @$pb.TagNumber(12)
  ServerBanned ensureUserBanned() => $_ensure(11);

  @$pb.TagNumber(13)
  ServerGroupDissolved get groupDissolved => $_getN(12);
  @$pb.TagNumber(13)
  set groupDissolved(ServerGroupDissolved value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasGroupDissolved() => $_has(12);
  @$pb.TagNumber(13)
  void clearGroupDissolved() => $_clearField(13);
  @$pb.TagNumber(13)
  ServerGroupDissolved ensureGroupDissolved() => $_ensure(12);

  @$pb.TagNumber(14)
  ServerGroupOwnerTransferred get groupOwnerTransferred => $_getN(13);
  @$pb.TagNumber(14)
  set groupOwnerTransferred(ServerGroupOwnerTransferred value) =>
      $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasGroupOwnerTransferred() => $_has(13);
  @$pb.TagNumber(14)
  void clearGroupOwnerTransferred() => $_clearField(14);
  @$pb.TagNumber(14)
  ServerGroupOwnerTransferred ensureGroupOwnerTransferred() => $_ensure(13);

  @$pb.TagNumber(15)
  ServerRoomUpdated get roomUpdated => $_getN(14);
  @$pb.TagNumber(15)
  set roomUpdated(ServerRoomUpdated value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasRoomUpdated() => $_has(14);
  @$pb.TagNumber(15)
  void clearRoomUpdated() => $_clearField(15);
  @$pb.TagNumber(15)
  ServerRoomUpdated ensureRoomUpdated() => $_ensure(14);

  @$pb.TagNumber(16)
  ServerGroupSettingsUpdated get groupSettingsUpdated => $_getN(15);
  @$pb.TagNumber(16)
  set groupSettingsUpdated(ServerGroupSettingsUpdated value) =>
      $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasGroupSettingsUpdated() => $_has(15);
  @$pb.TagNumber(16)
  void clearGroupSettingsUpdated() => $_clearField(16);
  @$pb.TagNumber(16)
  ServerGroupSettingsUpdated ensureGroupSettingsUpdated() => $_ensure(15);

  @$pb.TagNumber(17)
  ServerGroupMemberChanged get groupMemberChanged => $_getN(16);
  @$pb.TagNumber(17)
  set groupMemberChanged(ServerGroupMemberChanged value) =>
      $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasGroupMemberChanged() => $_has(16);
  @$pb.TagNumber(17)
  void clearGroupMemberChanged() => $_clearField(17);
  @$pb.TagNumber(17)
  ServerGroupMemberChanged ensureGroupMemberChanged() => $_ensure(16);

  @$pb.TagNumber(18)
  ServerFriendProfileUpdated get friendProfileUpdated => $_getN(17);
  @$pb.TagNumber(18)
  set friendProfileUpdated(ServerFriendProfileUpdated value) =>
      $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasFriendProfileUpdated() => $_has(17);
  @$pb.TagNumber(18)
  void clearFriendProfileUpdated() => $_clearField(18);
  @$pb.TagNumber(18)
  ServerFriendProfileUpdated ensureFriendProfileUpdated() => $_ensure(17);
}

class ServerAuthed extends $pb.GeneratedMessage {
  factory ServerAuthed({
    $core.String? userId,
    $core.String? connId,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (connId != null) result.connId = connId;
    return result;
  }

  ServerAuthed._();

  factory ServerAuthed.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerAuthed.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerAuthed',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'connId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerAuthed clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerAuthed copyWith(void Function(ServerAuthed) updates) =>
      super.copyWith((message) => updates(message as ServerAuthed))
          as ServerAuthed;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerAuthed create() => ServerAuthed._();
  @$core.override
  ServerAuthed createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerAuthed getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerAuthed>(create);
  static ServerAuthed? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get connId => $_getSZ(1);
  @$pb.TagNumber(2)
  set connId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConnId() => $_has(1);
  @$pb.TagNumber(2)
  void clearConnId() => $_clearField(2);
}

class ServerJoined extends $pb.GeneratedMessage {
  factory ServerJoined({
    $core.String? roomId,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    return result;
  }

  ServerJoined._();

  factory ServerJoined.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerJoined.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerJoined',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerJoined clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerJoined copyWith(void Function(ServerJoined) updates) =>
      super.copyWith((message) => updates(message as ServerJoined))
          as ServerJoined;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerJoined create() => ServerJoined._();
  @$core.override
  ServerJoined createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerJoined getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerJoined>(create);
  static ServerJoined? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);
}

class ServerLeft extends $pb.GeneratedMessage {
  factory ServerLeft({
    $core.String? roomId,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    return result;
  }

  ServerLeft._();

  factory ServerLeft.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerLeft.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerLeft',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerLeft clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerLeft copyWith(void Function(ServerLeft) updates) =>
      super.copyWith((message) => updates(message as ServerLeft)) as ServerLeft;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerLeft create() => ServerLeft._();
  @$core.override
  ServerLeft createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerLeft getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerLeft>(create);
  static ServerLeft? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);
}

class ServerMessage extends $pb.GeneratedMessage {
  factory ServerMessage({
    $core.String? id,
    $core.String? messageId,
    $core.String? roomId,
    $core.String? senderId,
    $core.String? senderUsername,
    $core.String? senderNickname,
    $core.String? senderAvatarUrl,
    $core.String? content,
    $core.String? messageType,
    $core.String? timestamp,
    QuotedMessage? quotedMessage,
    ForwardMessage? forwardMessage,
    $core.Iterable<MessagePart>? parts,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (messageId != null) result.messageId = messageId;
    if (roomId != null) result.roomId = roomId;
    if (senderId != null) result.senderId = senderId;
    if (senderUsername != null) result.senderUsername = senderUsername;
    if (senderNickname != null) result.senderNickname = senderNickname;
    if (senderAvatarUrl != null) result.senderAvatarUrl = senderAvatarUrl;
    if (content != null) result.content = content;
    if (messageType != null) result.messageType = messageType;
    if (timestamp != null) result.timestamp = timestamp;
    if (quotedMessage != null) result.quotedMessage = quotedMessage;
    if (forwardMessage != null) result.forwardMessage = forwardMessage;
    if (parts != null) result.parts.addAll(parts);
    return result;
  }

  ServerMessage._();

  factory ServerMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'messageId')
    ..aOS(3, _omitFieldNames ? '' : 'roomId')
    ..aOS(4, _omitFieldNames ? '' : 'senderId')
    ..aOS(5, _omitFieldNames ? '' : 'senderUsername')
    ..aOS(6, _omitFieldNames ? '' : 'senderNickname')
    ..aOS(7, _omitFieldNames ? '' : 'senderAvatarUrl')
    ..aOS(8, _omitFieldNames ? '' : 'content')
    ..aOS(9, _omitFieldNames ? '' : 'messageType')
    ..aOS(10, _omitFieldNames ? '' : 'timestamp')
    ..aOM<QuotedMessage>(11, _omitFieldNames ? '' : 'quotedMessage',
        subBuilder: QuotedMessage.create)
    ..aOM<ForwardMessage>(12, _omitFieldNames ? '' : 'forwardMessage',
        subBuilder: ForwardMessage.create)
    ..pPM<MessagePart>(13, _omitFieldNames ? '' : 'parts',
        subBuilder: MessagePart.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerMessage copyWith(void Function(ServerMessage) updates) =>
      super.copyWith((message) => updates(message as ServerMessage))
          as ServerMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerMessage create() => ServerMessage._();
  @$core.override
  ServerMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerMessage>(create);
  static ServerMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get messageId => $_getSZ(1);
  @$pb.TagNumber(2)
  set messageId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessageId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get roomId => $_getSZ(2);
  @$pb.TagNumber(3)
  set roomId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRoomId() => $_has(2);
  @$pb.TagNumber(3)
  void clearRoomId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get senderId => $_getSZ(3);
  @$pb.TagNumber(4)
  set senderId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSenderId() => $_has(3);
  @$pb.TagNumber(4)
  void clearSenderId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get senderUsername => $_getSZ(4);
  @$pb.TagNumber(5)
  set senderUsername($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSenderUsername() => $_has(4);
  @$pb.TagNumber(5)
  void clearSenderUsername() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get senderNickname => $_getSZ(5);
  @$pb.TagNumber(6)
  set senderNickname($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSenderNickname() => $_has(5);
  @$pb.TagNumber(6)
  void clearSenderNickname() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get senderAvatarUrl => $_getSZ(6);
  @$pb.TagNumber(7)
  set senderAvatarUrl($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSenderAvatarUrl() => $_has(6);
  @$pb.TagNumber(7)
  void clearSenderAvatarUrl() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get content => $_getSZ(7);
  @$pb.TagNumber(8)
  set content($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasContent() => $_has(7);
  @$pb.TagNumber(8)
  void clearContent() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get messageType => $_getSZ(8);
  @$pb.TagNumber(9)
  set messageType($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasMessageType() => $_has(8);
  @$pb.TagNumber(9)
  void clearMessageType() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get timestamp => $_getSZ(9);
  @$pb.TagNumber(10)
  set timestamp($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasTimestamp() => $_has(9);
  @$pb.TagNumber(10)
  void clearTimestamp() => $_clearField(10);

  @$pb.TagNumber(11)
  QuotedMessage get quotedMessage => $_getN(10);
  @$pb.TagNumber(11)
  set quotedMessage(QuotedMessage value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasQuotedMessage() => $_has(10);
  @$pb.TagNumber(11)
  void clearQuotedMessage() => $_clearField(11);
  @$pb.TagNumber(11)
  QuotedMessage ensureQuotedMessage() => $_ensure(10);

  @$pb.TagNumber(12)
  ForwardMessage get forwardMessage => $_getN(11);
  @$pb.TagNumber(12)
  set forwardMessage(ForwardMessage value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasForwardMessage() => $_has(11);
  @$pb.TagNumber(12)
  void clearForwardMessage() => $_clearField(12);
  @$pb.TagNumber(12)
  ForwardMessage ensureForwardMessage() => $_ensure(11);

  @$pb.TagNumber(13)
  $pb.PbList<MessagePart> get parts => $_getList(12);
}

class QuotedMessage extends $pb.GeneratedMessage {
  factory QuotedMessage({
    $core.String? id,
    $core.String? roomId,
    $core.String? senderId,
    $core.String? senderUsername,
    $core.String? senderNickname,
    $core.String? senderAvatarUrl,
    $core.String? content,
    $core.String? messageType,
    $core.String? createdAt,
    $core.bool? isDeleted,
    $core.Iterable<MessagePart>? parts,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (roomId != null) result.roomId = roomId;
    if (senderId != null) result.senderId = senderId;
    if (senderUsername != null) result.senderUsername = senderUsername;
    if (senderNickname != null) result.senderNickname = senderNickname;
    if (senderAvatarUrl != null) result.senderAvatarUrl = senderAvatarUrl;
    if (content != null) result.content = content;
    if (messageType != null) result.messageType = messageType;
    if (createdAt != null) result.createdAt = createdAt;
    if (isDeleted != null) result.isDeleted = isDeleted;
    if (parts != null) result.parts.addAll(parts);
    return result;
  }

  QuotedMessage._();

  factory QuotedMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory QuotedMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'QuotedMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'roomId')
    ..aOS(3, _omitFieldNames ? '' : 'senderId')
    ..aOS(4, _omitFieldNames ? '' : 'senderUsername')
    ..aOS(5, _omitFieldNames ? '' : 'senderNickname')
    ..aOS(6, _omitFieldNames ? '' : 'senderAvatarUrl')
    ..aOS(7, _omitFieldNames ? '' : 'content')
    ..aOS(8, _omitFieldNames ? '' : 'messageType')
    ..aOS(9, _omitFieldNames ? '' : 'createdAt')
    ..aOB(10, _omitFieldNames ? '' : 'isDeleted')
    ..pPM<MessagePart>(11, _omitFieldNames ? '' : 'parts',
        subBuilder: MessagePart.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuotedMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuotedMessage copyWith(void Function(QuotedMessage) updates) =>
      super.copyWith((message) => updates(message as QuotedMessage))
          as QuotedMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QuotedMessage create() => QuotedMessage._();
  @$core.override
  QuotedMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static QuotedMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<QuotedMessage>(create);
  static QuotedMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get roomId => $_getSZ(1);
  @$pb.TagNumber(2)
  set roomId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRoomId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoomId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get senderId => $_getSZ(2);
  @$pb.TagNumber(3)
  set senderId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSenderId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSenderId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get senderUsername => $_getSZ(3);
  @$pb.TagNumber(4)
  set senderUsername($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSenderUsername() => $_has(3);
  @$pb.TagNumber(4)
  void clearSenderUsername() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get senderNickname => $_getSZ(4);
  @$pb.TagNumber(5)
  set senderNickname($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSenderNickname() => $_has(4);
  @$pb.TagNumber(5)
  void clearSenderNickname() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get senderAvatarUrl => $_getSZ(5);
  @$pb.TagNumber(6)
  set senderAvatarUrl($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSenderAvatarUrl() => $_has(5);
  @$pb.TagNumber(6)
  void clearSenderAvatarUrl() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get content => $_getSZ(6);
  @$pb.TagNumber(7)
  set content($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasContent() => $_has(6);
  @$pb.TagNumber(7)
  void clearContent() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get messageType => $_getSZ(7);
  @$pb.TagNumber(8)
  set messageType($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasMessageType() => $_has(7);
  @$pb.TagNumber(8)
  void clearMessageType() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get createdAt => $_getSZ(8);
  @$pb.TagNumber(9)
  set createdAt($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasCreatedAt() => $_has(8);
  @$pb.TagNumber(9)
  void clearCreatedAt() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get isDeleted => $_getBF(9);
  @$pb.TagNumber(10)
  set isDeleted($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasIsDeleted() => $_has(9);
  @$pb.TagNumber(10)
  void clearIsDeleted() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<MessagePart> get parts => $_getList(10);
}

class ForwardMessage extends $pb.GeneratedMessage {
  factory ForwardMessage({
    $core.String? messageId,
    $core.String? roomId,
    $core.String? senderId,
    $core.String? senderUsername,
    $core.String? senderNickname,
  }) {
    final result = create();
    if (messageId != null) result.messageId = messageId;
    if (roomId != null) result.roomId = roomId;
    if (senderId != null) result.senderId = senderId;
    if (senderUsername != null) result.senderUsername = senderUsername;
    if (senderNickname != null) result.senderNickname = senderNickname;
    return result;
  }

  ForwardMessage._();

  factory ForwardMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ForwardMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ForwardMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'messageId')
    ..aOS(2, _omitFieldNames ? '' : 'roomId')
    ..aOS(3, _omitFieldNames ? '' : 'senderId')
    ..aOS(4, _omitFieldNames ? '' : 'senderUsername')
    ..aOS(5, _omitFieldNames ? '' : 'senderNickname')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ForwardMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ForwardMessage copyWith(void Function(ForwardMessage) updates) =>
      super.copyWith((message) => updates(message as ForwardMessage))
          as ForwardMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ForwardMessage create() => ForwardMessage._();
  @$core.override
  ForwardMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ForwardMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ForwardMessage>(create);
  static ForwardMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get roomId => $_getSZ(1);
  @$pb.TagNumber(2)
  set roomId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRoomId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoomId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get senderId => $_getSZ(2);
  @$pb.TagNumber(3)
  set senderId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSenderId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSenderId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get senderUsername => $_getSZ(3);
  @$pb.TagNumber(4)
  set senderUsername($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSenderUsername() => $_has(3);
  @$pb.TagNumber(4)
  void clearSenderUsername() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get senderNickname => $_getSZ(4);
  @$pb.TagNumber(5)
  set senderNickname($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSenderNickname() => $_has(4);
  @$pb.TagNumber(5)
  void clearSenderNickname() => $_clearField(5);
}

class MessageAttachment extends $pb.GeneratedMessage {
  factory MessageAttachment({
    $core.String? key,
    $core.String? name,
    $core.String? mime,
    $fixnum.Int64? size,
    $core.int? width,
    $core.int? height,
    $core.int? durationMs,
    $core.String? thumbnailKey,
  }) {
    final result = create();
    if (key != null) result.key = key;
    if (name != null) result.name = name;
    if (mime != null) result.mime = mime;
    if (size != null) result.size = size;
    if (width != null) result.width = width;
    if (height != null) result.height = height;
    if (durationMs != null) result.durationMs = durationMs;
    if (thumbnailKey != null) result.thumbnailKey = thumbnailKey;
    return result;
  }

  MessageAttachment._();

  factory MessageAttachment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MessageAttachment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MessageAttachment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'mime')
    ..aInt64(4, _omitFieldNames ? '' : 'size')
    ..aI(5, _omitFieldNames ? '' : 'width')
    ..aI(6, _omitFieldNames ? '' : 'height')
    ..aI(7, _omitFieldNames ? '' : 'durationMs')
    ..aOS(8, _omitFieldNames ? '' : 'thumbnailKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageAttachment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageAttachment copyWith(void Function(MessageAttachment) updates) =>
      super.copyWith((message) => updates(message as MessageAttachment))
          as MessageAttachment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MessageAttachment create() => MessageAttachment._();
  @$core.override
  MessageAttachment createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MessageAttachment getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MessageAttachment>(create);
  static MessageAttachment? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get mime => $_getSZ(2);
  @$pb.TagNumber(3)
  set mime($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMime() => $_has(2);
  @$pb.TagNumber(3)
  void clearMime() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get size => $_getI64(3);
  @$pb.TagNumber(4)
  set size($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSize() => $_has(3);
  @$pb.TagNumber(4)
  void clearSize() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get width => $_getIZ(4);
  @$pb.TagNumber(5)
  set width($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasWidth() => $_has(4);
  @$pb.TagNumber(5)
  void clearWidth() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get height => $_getIZ(5);
  @$pb.TagNumber(6)
  set height($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHeight() => $_has(5);
  @$pb.TagNumber(6)
  void clearHeight() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get durationMs => $_getIZ(6);
  @$pb.TagNumber(7)
  set durationMs($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDurationMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearDurationMs() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get thumbnailKey => $_getSZ(7);
  @$pb.TagNumber(8)
  set thumbnailKey($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasThumbnailKey() => $_has(7);
  @$pb.TagNumber(8)
  void clearThumbnailKey() => $_clearField(8);
}

class MessagePart extends $pb.GeneratedMessage {
  factory MessagePart({
    $core.int? position,
    $core.String? partType,
    $core.String? text,
    MessageAttachment? attachment,
  }) {
    final result = create();
    if (position != null) result.position = position;
    if (partType != null) result.partType = partType;
    if (text != null) result.text = text;
    if (attachment != null) result.attachment = attachment;
    return result;
  }

  MessagePart._();

  factory MessagePart.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MessagePart.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MessagePart',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'position')
    ..aOS(2, _omitFieldNames ? '' : 'partType')
    ..aOS(3, _omitFieldNames ? '' : 'text')
    ..aOM<MessageAttachment>(4, _omitFieldNames ? '' : 'attachment',
        subBuilder: MessageAttachment.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessagePart clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessagePart copyWith(void Function(MessagePart) updates) =>
      super.copyWith((message) => updates(message as MessagePart))
          as MessagePart;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MessagePart create() => MessagePart._();
  @$core.override
  MessagePart createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MessagePart getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MessagePart>(create);
  static MessagePart? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get position => $_getIZ(0);
  @$pb.TagNumber(1)
  set position($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPosition() => $_has(0);
  @$pb.TagNumber(1)
  void clearPosition() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get partType => $_getSZ(1);
  @$pb.TagNumber(2)
  set partType($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPartType() => $_has(1);
  @$pb.TagNumber(2)
  void clearPartType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get text => $_getSZ(2);
  @$pb.TagNumber(3)
  set text($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasText() => $_has(2);
  @$pb.TagNumber(3)
  void clearText() => $_clearField(3);

  @$pb.TagNumber(4)
  MessageAttachment get attachment => $_getN(3);
  @$pb.TagNumber(4)
  set attachment(MessageAttachment value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasAttachment() => $_has(3);
  @$pb.TagNumber(4)
  void clearAttachment() => $_clearField(4);
  @$pb.TagNumber(4)
  MessageAttachment ensureAttachment() => $_ensure(3);
}

class ServerMessageRead extends $pb.GeneratedMessage {
  factory ServerMessageRead({
    $core.String? roomId,
    $core.String? messageId,
    $core.String? readerId,
    $core.String? readAt,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    if (messageId != null) result.messageId = messageId;
    if (readerId != null) result.readerId = readerId;
    if (readAt != null) result.readAt = readAt;
    return result;
  }

  ServerMessageRead._();

  factory ServerMessageRead.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerMessageRead.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerMessageRead',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..aOS(2, _omitFieldNames ? '' : 'messageId')
    ..aOS(3, _omitFieldNames ? '' : 'readerId')
    ..aOS(4, _omitFieldNames ? '' : 'readAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerMessageRead clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerMessageRead copyWith(void Function(ServerMessageRead) updates) =>
      super.copyWith((message) => updates(message as ServerMessageRead))
          as ServerMessageRead;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerMessageRead create() => ServerMessageRead._();
  @$core.override
  ServerMessageRead createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerMessageRead getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerMessageRead>(create);
  static ServerMessageRead? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get messageId => $_getSZ(1);
  @$pb.TagNumber(2)
  set messageId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessageId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get readerId => $_getSZ(2);
  @$pb.TagNumber(3)
  set readerId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReaderId() => $_has(2);
  @$pb.TagNumber(3)
  void clearReaderId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get readAt => $_getSZ(3);
  @$pb.TagNumber(4)
  set readAt($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReadAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearReadAt() => $_clearField(4);
}

class ServerMessageUpdate extends $pb.GeneratedMessage {
  factory ServerMessageUpdate({
    $core.String? roomId,
    $core.String? messageId,
    $core.bool? isDeleted,
    $core.String? deletedAt,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    if (messageId != null) result.messageId = messageId;
    if (isDeleted != null) result.isDeleted = isDeleted;
    if (deletedAt != null) result.deletedAt = deletedAt;
    return result;
  }

  ServerMessageUpdate._();

  factory ServerMessageUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerMessageUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerMessageUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..aOS(2, _omitFieldNames ? '' : 'messageId')
    ..aOB(3, _omitFieldNames ? '' : 'isDeleted')
    ..aOS(4, _omitFieldNames ? '' : 'deletedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerMessageUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerMessageUpdate copyWith(void Function(ServerMessageUpdate) updates) =>
      super.copyWith((message) => updates(message as ServerMessageUpdate))
          as ServerMessageUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerMessageUpdate create() => ServerMessageUpdate._();
  @$core.override
  ServerMessageUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerMessageUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerMessageUpdate>(create);
  static ServerMessageUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get messageId => $_getSZ(1);
  @$pb.TagNumber(2)
  set messageId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessageId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isDeleted => $_getBF(2);
  @$pb.TagNumber(3)
  set isDeleted($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsDeleted() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsDeleted() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get deletedAt => $_getSZ(3);
  @$pb.TagNumber(4)
  set deletedAt($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDeletedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearDeletedAt() => $_clearField(4);
}

class ServerPinUpdate extends $pb.GeneratedMessage {
  factory ServerPinUpdate({
    $core.String? roomId,
    $core.String? messageId,
    $core.bool? isPinned,
    $core.String? pinnedAt,
    $core.String? pinnedBy,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    if (messageId != null) result.messageId = messageId;
    if (isPinned != null) result.isPinned = isPinned;
    if (pinnedAt != null) result.pinnedAt = pinnedAt;
    if (pinnedBy != null) result.pinnedBy = pinnedBy;
    return result;
  }

  ServerPinUpdate._();

  factory ServerPinUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerPinUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerPinUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..aOS(2, _omitFieldNames ? '' : 'messageId')
    ..aOB(3, _omitFieldNames ? '' : 'isPinned')
    ..aOS(4, _omitFieldNames ? '' : 'pinnedAt')
    ..aOS(5, _omitFieldNames ? '' : 'pinnedBy')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerPinUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerPinUpdate copyWith(void Function(ServerPinUpdate) updates) =>
      super.copyWith((message) => updates(message as ServerPinUpdate))
          as ServerPinUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerPinUpdate create() => ServerPinUpdate._();
  @$core.override
  ServerPinUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerPinUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerPinUpdate>(create);
  static ServerPinUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get messageId => $_getSZ(1);
  @$pb.TagNumber(2)
  set messageId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessageId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isPinned => $_getBF(2);
  @$pb.TagNumber(3)
  set isPinned($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsPinned() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsPinned() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get pinnedAt => $_getSZ(3);
  @$pb.TagNumber(4)
  set pinnedAt($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPinnedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearPinnedAt() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get pinnedBy => $_getSZ(4);
  @$pb.TagNumber(5)
  set pinnedBy($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPinnedBy() => $_has(4);
  @$pb.TagNumber(5)
  void clearPinnedBy() => $_clearField(5);
}

class ServerError extends $pb.GeneratedMessage {
  factory ServerError({
    $core.String? message,
  }) {
    final result = create();
    if (message != null) result.message = message;
    return result;
  }

  ServerError._();

  factory ServerError.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerError.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerError',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerError clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerError copyWith(void Function(ServerError) updates) =>
      super.copyWith((message) => updates(message as ServerError))
          as ServerError;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerError create() => ServerError._();
  @$core.override
  ServerError createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerError getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerError>(create);
  static ServerError? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get message => $_getSZ(0);
  @$pb.TagNumber(1)
  set message($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => $_clearField(1);
}

class ServerPong extends $pb.GeneratedMessage {
  factory ServerPong() => create();

  ServerPong._();

  factory ServerPong.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerPong.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerPong',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerPong clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerPong copyWith(void Function(ServerPong) updates) =>
      super.copyWith((message) => updates(message as ServerPong)) as ServerPong;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerPong create() => ServerPong._();
  @$core.override
  ServerPong createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerPong getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerPong>(create);
  static ServerPong? _defaultInstance;
}

class ServerFriendRequestUpdate extends $pb.GeneratedMessage {
  factory ServerFriendRequestUpdate({
    $core.int? pendingCount,
  }) {
    final result = create();
    if (pendingCount != null) result.pendingCount = pendingCount;
    return result;
  }

  ServerFriendRequestUpdate._();

  factory ServerFriendRequestUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerFriendRequestUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerFriendRequestUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'pendingCount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerFriendRequestUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerFriendRequestUpdate copyWith(
          void Function(ServerFriendRequestUpdate) updates) =>
      super.copyWith((message) => updates(message as ServerFriendRequestUpdate))
          as ServerFriendRequestUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerFriendRequestUpdate create() => ServerFriendRequestUpdate._();
  @$core.override
  ServerFriendRequestUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerFriendRequestUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerFriendRequestUpdate>(create);
  static ServerFriendRequestUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get pendingCount => $_getIZ(0);
  @$pb.TagNumber(1)
  set pendingCount($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPendingCount() => $_has(0);
  @$pb.TagNumber(1)
  void clearPendingCount() => $_clearField(1);
}

class ServerRoomCreated extends $pb.GeneratedMessage {
  factory ServerRoomCreated({
    $core.String? roomId,
    $core.String? roomName,
    $core.String? roomType,
    $core.String? initiatorId,
    $core.String? ownerId,
    $core.String? description,
    $core.String? avatarUrl,
    $core.String? createdAt,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    if (roomName != null) result.roomName = roomName;
    if (roomType != null) result.roomType = roomType;
    if (initiatorId != null) result.initiatorId = initiatorId;
    if (ownerId != null) result.ownerId = ownerId;
    if (description != null) result.description = description;
    if (avatarUrl != null) result.avatarUrl = avatarUrl;
    if (createdAt != null) result.createdAt = createdAt;
    return result;
  }

  ServerRoomCreated._();

  factory ServerRoomCreated.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerRoomCreated.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerRoomCreated',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..aOS(2, _omitFieldNames ? '' : 'roomName')
    ..aOS(3, _omitFieldNames ? '' : 'roomType')
    ..aOS(4, _omitFieldNames ? '' : 'initiatorId')
    ..aOS(5, _omitFieldNames ? '' : 'ownerId')
    ..aOS(6, _omitFieldNames ? '' : 'description')
    ..aOS(7, _omitFieldNames ? '' : 'avatarUrl')
    ..aOS(8, _omitFieldNames ? '' : 'createdAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerRoomCreated clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerRoomCreated copyWith(void Function(ServerRoomCreated) updates) =>
      super.copyWith((message) => updates(message as ServerRoomCreated))
          as ServerRoomCreated;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerRoomCreated create() => ServerRoomCreated._();
  @$core.override
  ServerRoomCreated createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerRoomCreated getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerRoomCreated>(create);
  static ServerRoomCreated? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get roomName => $_getSZ(1);
  @$pb.TagNumber(2)
  set roomName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRoomName() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoomName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get roomType => $_getSZ(2);
  @$pb.TagNumber(3)
  set roomType($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRoomType() => $_has(2);
  @$pb.TagNumber(3)
  void clearRoomType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get initiatorId => $_getSZ(3);
  @$pb.TagNumber(4)
  set initiatorId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasInitiatorId() => $_has(3);
  @$pb.TagNumber(4)
  void clearInitiatorId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get ownerId => $_getSZ(4);
  @$pb.TagNumber(5)
  set ownerId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasOwnerId() => $_has(4);
  @$pb.TagNumber(5)
  void clearOwnerId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get description => $_getSZ(5);
  @$pb.TagNumber(6)
  set description($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDescription() => $_has(5);
  @$pb.TagNumber(6)
  void clearDescription() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get avatarUrl => $_getSZ(6);
  @$pb.TagNumber(7)
  set avatarUrl($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAvatarUrl() => $_has(6);
  @$pb.TagNumber(7)
  void clearAvatarUrl() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get createdAt => $_getSZ(7);
  @$pb.TagNumber(8)
  set createdAt($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCreatedAt() => $_has(7);
  @$pb.TagNumber(8)
  void clearCreatedAt() => $_clearField(8);
}

class ServerBanned extends $pb.GeneratedMessage {
  factory ServerBanned({
    $core.String? userId,
    $core.String? reason,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (reason != null) result.reason = reason;
    return result;
  }

  ServerBanned._();

  factory ServerBanned.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerBanned.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerBanned',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerBanned clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerBanned copyWith(void Function(ServerBanned) updates) =>
      super.copyWith((message) => updates(message as ServerBanned))
          as ServerBanned;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerBanned create() => ServerBanned._();
  @$core.override
  ServerBanned createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerBanned getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerBanned>(create);
  static ServerBanned? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);
}

class ServerGroupDissolved extends $pb.GeneratedMessage {
  factory ServerGroupDissolved({
    $core.String? roomId,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    return result;
  }

  ServerGroupDissolved._();

  factory ServerGroupDissolved.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerGroupDissolved.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerGroupDissolved',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerGroupDissolved clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerGroupDissolved copyWith(void Function(ServerGroupDissolved) updates) =>
      super.copyWith((message) => updates(message as ServerGroupDissolved))
          as ServerGroupDissolved;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerGroupDissolved create() => ServerGroupDissolved._();
  @$core.override
  ServerGroupDissolved createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerGroupDissolved getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerGroupDissolved>(create);
  static ServerGroupDissolved? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);
}

class ServerGroupOwnerTransferred extends $pb.GeneratedMessage {
  factory ServerGroupOwnerTransferred({
    $core.String? roomId,
    $core.String? oldOwnerId,
    $core.String? newOwnerId,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    if (oldOwnerId != null) result.oldOwnerId = oldOwnerId;
    if (newOwnerId != null) result.newOwnerId = newOwnerId;
    return result;
  }

  ServerGroupOwnerTransferred._();

  factory ServerGroupOwnerTransferred.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerGroupOwnerTransferred.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerGroupOwnerTransferred',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..aOS(2, _omitFieldNames ? '' : 'oldOwnerId')
    ..aOS(3, _omitFieldNames ? '' : 'newOwnerId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerGroupOwnerTransferred clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerGroupOwnerTransferred copyWith(
          void Function(ServerGroupOwnerTransferred) updates) =>
      super.copyWith(
              (message) => updates(message as ServerGroupOwnerTransferred))
          as ServerGroupOwnerTransferred;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerGroupOwnerTransferred create() =>
      ServerGroupOwnerTransferred._();
  @$core.override
  ServerGroupOwnerTransferred createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerGroupOwnerTransferred getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerGroupOwnerTransferred>(create);
  static ServerGroupOwnerTransferred? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get oldOwnerId => $_getSZ(1);
  @$pb.TagNumber(2)
  set oldOwnerId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOldOwnerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearOldOwnerId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get newOwnerId => $_getSZ(2);
  @$pb.TagNumber(3)
  set newOwnerId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNewOwnerId() => $_has(2);
  @$pb.TagNumber(3)
  void clearNewOwnerId() => $_clearField(3);
}

class ServerGroupSettingsUpdated extends $pb.GeneratedMessage {
  factory ServerGroupSettingsUpdated({
    $core.String? roomId,
    $core.bool? globalMuteEnabled,
    $core.String? globalMuteReason,
    $core.String? globalMuteUntil,
    $core.String? globalMuteSetBy,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    if (globalMuteEnabled != null) result.globalMuteEnabled = globalMuteEnabled;
    if (globalMuteReason != null) result.globalMuteReason = globalMuteReason;
    if (globalMuteUntil != null) result.globalMuteUntil = globalMuteUntil;
    if (globalMuteSetBy != null) result.globalMuteSetBy = globalMuteSetBy;
    return result;
  }

  ServerGroupSettingsUpdated._();

  factory ServerGroupSettingsUpdated.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerGroupSettingsUpdated.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerGroupSettingsUpdated',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..aOB(2, _omitFieldNames ? '' : 'globalMuteEnabled')
    ..aOS(3, _omitFieldNames ? '' : 'globalMuteReason')
    ..aOS(4, _omitFieldNames ? '' : 'globalMuteUntil')
    ..aOS(5, _omitFieldNames ? '' : 'globalMuteSetBy')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerGroupSettingsUpdated clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerGroupSettingsUpdated copyWith(
          void Function(ServerGroupSettingsUpdated) updates) =>
      super.copyWith(
              (message) => updates(message as ServerGroupSettingsUpdated))
          as ServerGroupSettingsUpdated;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerGroupSettingsUpdated create() => ServerGroupSettingsUpdated._();
  @$core.override
  ServerGroupSettingsUpdated createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerGroupSettingsUpdated getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerGroupSettingsUpdated>(create);
  static ServerGroupSettingsUpdated? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get globalMuteEnabled => $_getBF(1);
  @$pb.TagNumber(2)
  set globalMuteEnabled($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGlobalMuteEnabled() => $_has(1);
  @$pb.TagNumber(2)
  void clearGlobalMuteEnabled() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get globalMuteReason => $_getSZ(2);
  @$pb.TagNumber(3)
  set globalMuteReason($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGlobalMuteReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearGlobalMuteReason() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get globalMuteUntil => $_getSZ(3);
  @$pb.TagNumber(4)
  set globalMuteUntil($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasGlobalMuteUntil() => $_has(3);
  @$pb.TagNumber(4)
  void clearGlobalMuteUntil() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get globalMuteSetBy => $_getSZ(4);
  @$pb.TagNumber(5)
  set globalMuteSetBy($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGlobalMuteSetBy() => $_has(4);
  @$pb.TagNumber(5)
  void clearGlobalMuteSetBy() => $_clearField(5);
}

class ServerRoomUpdated extends $pb.GeneratedMessage {
  factory ServerRoomUpdated({
    $core.String? roomId,
    $core.String? roomName,
    $core.String? roomType,
    $core.String? avatarUrl,
    $core.String? avatarObjectKey,
    $core.String? description,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    if (roomName != null) result.roomName = roomName;
    if (roomType != null) result.roomType = roomType;
    if (avatarUrl != null) result.avatarUrl = avatarUrl;
    if (avatarObjectKey != null) result.avatarObjectKey = avatarObjectKey;
    if (description != null) result.description = description;
    return result;
  }

  ServerRoomUpdated._();

  factory ServerRoomUpdated.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerRoomUpdated.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerRoomUpdated',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..aOS(2, _omitFieldNames ? '' : 'roomName')
    ..aOS(3, _omitFieldNames ? '' : 'roomType')
    ..aOS(4, _omitFieldNames ? '' : 'avatarUrl')
    ..aOS(5, _omitFieldNames ? '' : 'avatarObjectKey')
    ..aOS(6, _omitFieldNames ? '' : 'description')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerRoomUpdated clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerRoomUpdated copyWith(void Function(ServerRoomUpdated) updates) =>
      super.copyWith((message) => updates(message as ServerRoomUpdated))
          as ServerRoomUpdated;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerRoomUpdated create() => ServerRoomUpdated._();
  @$core.override
  ServerRoomUpdated createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerRoomUpdated getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerRoomUpdated>(create);
  static ServerRoomUpdated? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get roomName => $_getSZ(1);
  @$pb.TagNumber(2)
  set roomName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRoomName() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoomName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get roomType => $_getSZ(2);
  @$pb.TagNumber(3)
  set roomType($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRoomType() => $_has(2);
  @$pb.TagNumber(3)
  void clearRoomType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get avatarUrl => $_getSZ(3);
  @$pb.TagNumber(4)
  set avatarUrl($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAvatarUrl() => $_has(3);
  @$pb.TagNumber(4)
  void clearAvatarUrl() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get avatarObjectKey => $_getSZ(4);
  @$pb.TagNumber(5)
  set avatarObjectKey($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAvatarObjectKey() => $_has(4);
  @$pb.TagNumber(5)
  void clearAvatarObjectKey() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get description => $_getSZ(5);
  @$pb.TagNumber(6)
  set description($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDescription() => $_has(5);
  @$pb.TagNumber(6)
  void clearDescription() => $_clearField(6);
}

/// 群成员变更事件
/// change_type: "role_changed" | "muted" | "unmuted" | "kicked" | "joined" | "left"
/// new_role: "owner" | "admin" | "member" (仅 role_changed 时有效)
class ServerGroupMemberChanged extends $pb.GeneratedMessage {
  factory ServerGroupMemberChanged({
    $core.String? roomId,
    $core.String? memberId,
    $core.String? changeType,
    $core.String? newRole,
    $core.String? operatorId,
    $core.String? reason,
    $core.String? until,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    if (memberId != null) result.memberId = memberId;
    if (changeType != null) result.changeType = changeType;
    if (newRole != null) result.newRole = newRole;
    if (operatorId != null) result.operatorId = operatorId;
    if (reason != null) result.reason = reason;
    if (until != null) result.until = until;
    return result;
  }

  ServerGroupMemberChanged._();

  factory ServerGroupMemberChanged.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerGroupMemberChanged.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerGroupMemberChanged',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..aOS(2, _omitFieldNames ? '' : 'memberId')
    ..aOS(3, _omitFieldNames ? '' : 'changeType')
    ..aOS(4, _omitFieldNames ? '' : 'newRole')
    ..aOS(5, _omitFieldNames ? '' : 'operatorId')
    ..aOS(6, _omitFieldNames ? '' : 'reason')
    ..aOS(7, _omitFieldNames ? '' : 'until')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerGroupMemberChanged clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerGroupMemberChanged copyWith(
          void Function(ServerGroupMemberChanged) updates) =>
      super.copyWith((message) => updates(message as ServerGroupMemberChanged))
          as ServerGroupMemberChanged;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerGroupMemberChanged create() => ServerGroupMemberChanged._();
  @$core.override
  ServerGroupMemberChanged createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerGroupMemberChanged getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerGroupMemberChanged>(create);
  static ServerGroupMemberChanged? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get memberId => $_getSZ(1);
  @$pb.TagNumber(2)
  set memberId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMemberId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMemberId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get changeType => $_getSZ(2);
  @$pb.TagNumber(3)
  set changeType($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasChangeType() => $_has(2);
  @$pb.TagNumber(3)
  void clearChangeType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get newRole => $_getSZ(3);
  @$pb.TagNumber(4)
  set newRole($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNewRole() => $_has(3);
  @$pb.TagNumber(4)
  void clearNewRole() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get operatorId => $_getSZ(4);
  @$pb.TagNumber(5)
  set operatorId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasOperatorId() => $_has(4);
  @$pb.TagNumber(5)
  void clearOperatorId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get reason => $_getSZ(5);
  @$pb.TagNumber(6)
  set reason($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasReason() => $_has(5);
  @$pb.TagNumber(6)
  void clearReason() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get until => $_getSZ(6);
  @$pb.TagNumber(7)
  set until($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasUntil() => $_has(6);
  @$pb.TagNumber(7)
  void clearUntil() => $_clearField(7);
}

/// 好友资料更新事件（用于通知好友资料变化，如头像、昵称等）
class ServerFriendProfileUpdated extends $pb.GeneratedMessage {
  factory ServerFriendProfileUpdated({
    $core.String? userId,
    $core.String? username,
    $core.String? nickname,
    $core.String? avatarUrl,
    $core.String? avatarObjectKey,
  }) {
    final result = create();
    if (userId != null) result.userId = userId;
    if (username != null) result.username = username;
    if (nickname != null) result.nickname = nickname;
    if (avatarUrl != null) result.avatarUrl = avatarUrl;
    if (avatarObjectKey != null) result.avatarObjectKey = avatarObjectKey;
    return result;
  }

  ServerFriendProfileUpdated._();

  factory ServerFriendProfileUpdated.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ServerFriendProfileUpdated.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ServerFriendProfileUpdated',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'userId')
    ..aOS(2, _omitFieldNames ? '' : 'username')
    ..aOS(3, _omitFieldNames ? '' : 'nickname')
    ..aOS(4, _omitFieldNames ? '' : 'avatarUrl')
    ..aOS(5, _omitFieldNames ? '' : 'avatarObjectKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerFriendProfileUpdated clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ServerFriendProfileUpdated copyWith(
          void Function(ServerFriendProfileUpdated) updates) =>
      super.copyWith((message) => updates(message as ServerFriendProfileUpdated))
          as ServerFriendProfileUpdated;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerFriendProfileUpdated create() => ServerFriendProfileUpdated._();
  @$core.override
  ServerFriendProfileUpdated createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ServerFriendProfileUpdated getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerFriendProfileUpdated>(create);
  static ServerFriendProfileUpdated? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get username => $_getSZ(1);
  @$pb.TagNumber(2)
  set username($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUsername() => $_has(1);
  @$pb.TagNumber(2)
  void clearUsername() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get nickname => $_getSZ(2);
  @$pb.TagNumber(3)
  set nickname($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNickname() => $_has(2);
  @$pb.TagNumber(3)
  void clearNickname() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get avatarUrl => $_getSZ(3);
  @$pb.TagNumber(4)
  set avatarUrl($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAvatarUrl() => $_has(3);
  @$pb.TagNumber(4)
  void clearAvatarUrl() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get avatarObjectKey => $_getSZ(4);
  @$pb.TagNumber(5)
  set avatarObjectKey($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAvatarObjectKey() => $_has(4);
  @$pb.TagNumber(5)
  void clearAvatarObjectKey() => $_clearField(5);
}

class PubSubMessage extends $pb.GeneratedMessage {
  factory PubSubMessage({
    $core.String? id,
    $core.String? roomId,
    $core.String? senderId,
    $core.String? content,
    $core.String? messageType,
    PubSubPriority? priority,
    $core.String? timestamp,
    $core.String? sourceNode,
    $core.Iterable<$core.String>? targetNodes,
    $core.String? senderUsername,
    $core.String? senderNickname,
    $core.String? senderAvatarUrl,
    QuotedMessage? quotedMessage,
    ForwardMessage? forwardMessage,
    $core.Iterable<MessagePart>? parts,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (roomId != null) result.roomId = roomId;
    if (senderId != null) result.senderId = senderId;
    if (content != null) result.content = content;
    if (messageType != null) result.messageType = messageType;
    if (priority != null) result.priority = priority;
    if (timestamp != null) result.timestamp = timestamp;
    if (sourceNode != null) result.sourceNode = sourceNode;
    if (targetNodes != null) result.targetNodes.addAll(targetNodes);
    if (senderUsername != null) result.senderUsername = senderUsername;
    if (senderNickname != null) result.senderNickname = senderNickname;
    if (senderAvatarUrl != null) result.senderAvatarUrl = senderAvatarUrl;
    if (quotedMessage != null) result.quotedMessage = quotedMessage;
    if (forwardMessage != null) result.forwardMessage = forwardMessage;
    if (parts != null) result.parts.addAll(parts);
    return result;
  }

  PubSubMessage._();

  factory PubSubMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PubSubMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PubSubMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'roomId')
    ..aOS(3, _omitFieldNames ? '' : 'senderId')
    ..aOS(4, _omitFieldNames ? '' : 'content')
    ..aOS(5, _omitFieldNames ? '' : 'messageType')
    ..aE<PubSubPriority>(6, _omitFieldNames ? '' : 'priority',
        enumValues: PubSubPriority.values)
    ..aOS(7, _omitFieldNames ? '' : 'timestamp')
    ..aOS(8, _omitFieldNames ? '' : 'sourceNode')
    ..pPS(9, _omitFieldNames ? '' : 'targetNodes')
    ..aOS(10, _omitFieldNames ? '' : 'senderUsername')
    ..aOS(11, _omitFieldNames ? '' : 'senderNickname')
    ..aOS(12, _omitFieldNames ? '' : 'senderAvatarUrl')
    ..aOM<QuotedMessage>(13, _omitFieldNames ? '' : 'quotedMessage',
        subBuilder: QuotedMessage.create)
    ..aOM<ForwardMessage>(14, _omitFieldNames ? '' : 'forwardMessage',
        subBuilder: ForwardMessage.create)
    ..pPM<MessagePart>(15, _omitFieldNames ? '' : 'parts',
        subBuilder: MessagePart.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubSubMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubSubMessage copyWith(void Function(PubSubMessage) updates) =>
      super.copyWith((message) => updates(message as PubSubMessage))
          as PubSubMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PubSubMessage create() => PubSubMessage._();
  @$core.override
  PubSubMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PubSubMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PubSubMessage>(create);
  static PubSubMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get roomId => $_getSZ(1);
  @$pb.TagNumber(2)
  set roomId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRoomId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoomId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get senderId => $_getSZ(2);
  @$pb.TagNumber(3)
  set senderId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSenderId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSenderId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get content => $_getSZ(3);
  @$pb.TagNumber(4)
  set content($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasContent() => $_has(3);
  @$pb.TagNumber(4)
  void clearContent() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get messageType => $_getSZ(4);
  @$pb.TagNumber(5)
  set messageType($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMessageType() => $_has(4);
  @$pb.TagNumber(5)
  void clearMessageType() => $_clearField(5);

  @$pb.TagNumber(6)
  PubSubPriority get priority => $_getN(5);
  @$pb.TagNumber(6)
  set priority(PubSubPriority value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasPriority() => $_has(5);
  @$pb.TagNumber(6)
  void clearPriority() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get timestamp => $_getSZ(6);
  @$pb.TagNumber(7)
  set timestamp($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTimestamp() => $_has(6);
  @$pb.TagNumber(7)
  void clearTimestamp() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get sourceNode => $_getSZ(7);
  @$pb.TagNumber(8)
  set sourceNode($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSourceNode() => $_has(7);
  @$pb.TagNumber(8)
  void clearSourceNode() => $_clearField(8);

  @$pb.TagNumber(9)
  $pb.PbList<$core.String> get targetNodes => $_getList(8);

  @$pb.TagNumber(10)
  $core.String get senderUsername => $_getSZ(9);
  @$pb.TagNumber(10)
  set senderUsername($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasSenderUsername() => $_has(9);
  @$pb.TagNumber(10)
  void clearSenderUsername() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get senderNickname => $_getSZ(10);
  @$pb.TagNumber(11)
  set senderNickname($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasSenderNickname() => $_has(10);
  @$pb.TagNumber(11)
  void clearSenderNickname() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get senderAvatarUrl => $_getSZ(11);
  @$pb.TagNumber(12)
  set senderAvatarUrl($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasSenderAvatarUrl() => $_has(11);
  @$pb.TagNumber(12)
  void clearSenderAvatarUrl() => $_clearField(12);

  @$pb.TagNumber(13)
  QuotedMessage get quotedMessage => $_getN(12);
  @$pb.TagNumber(13)
  set quotedMessage(QuotedMessage value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasQuotedMessage() => $_has(12);
  @$pb.TagNumber(13)
  void clearQuotedMessage() => $_clearField(13);
  @$pb.TagNumber(13)
  QuotedMessage ensureQuotedMessage() => $_ensure(12);

  @$pb.TagNumber(14)
  ForwardMessage get forwardMessage => $_getN(13);
  @$pb.TagNumber(14)
  set forwardMessage(ForwardMessage value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasForwardMessage() => $_has(13);
  @$pb.TagNumber(14)
  void clearForwardMessage() => $_clearField(14);
  @$pb.TagNumber(14)
  ForwardMessage ensureForwardMessage() => $_ensure(13);

  @$pb.TagNumber(15)
  $pb.PbList<MessagePart> get parts => $_getList(14);
}

class PubSubReadReceipt extends $pb.GeneratedMessage {
  factory PubSubReadReceipt({
    $core.String? roomId,
    $core.String? readerId,
    $core.String? messageId,
    $core.String? readAt,
    $core.String? sourceNode,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    if (readerId != null) result.readerId = readerId;
    if (messageId != null) result.messageId = messageId;
    if (readAt != null) result.readAt = readAt;
    if (sourceNode != null) result.sourceNode = sourceNode;
    return result;
  }

  PubSubReadReceipt._();

  factory PubSubReadReceipt.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PubSubReadReceipt.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PubSubReadReceipt',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..aOS(2, _omitFieldNames ? '' : 'readerId')
    ..aOS(3, _omitFieldNames ? '' : 'messageId')
    ..aOS(4, _omitFieldNames ? '' : 'readAt')
    ..aOS(5, _omitFieldNames ? '' : 'sourceNode')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubSubReadReceipt clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubSubReadReceipt copyWith(void Function(PubSubReadReceipt) updates) =>
      super.copyWith((message) => updates(message as PubSubReadReceipt))
          as PubSubReadReceipt;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PubSubReadReceipt create() => PubSubReadReceipt._();
  @$core.override
  PubSubReadReceipt createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PubSubReadReceipt getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PubSubReadReceipt>(create);
  static PubSubReadReceipt? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get readerId => $_getSZ(1);
  @$pb.TagNumber(2)
  set readerId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReaderId() => $_has(1);
  @$pb.TagNumber(2)
  void clearReaderId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get messageId => $_getSZ(2);
  @$pb.TagNumber(3)
  set messageId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMessageId() => $_has(2);
  @$pb.TagNumber(3)
  void clearMessageId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get readAt => $_getSZ(3);
  @$pb.TagNumber(4)
  set readAt($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReadAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearReadAt() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get sourceNode => $_getSZ(4);
  @$pb.TagNumber(5)
  set sourceNode($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSourceNode() => $_has(4);
  @$pb.TagNumber(5)
  void clearSourceNode() => $_clearField(5);
}

class PubSubMessageUpdate extends $pb.GeneratedMessage {
  factory PubSubMessageUpdate({
    $core.String? roomId,
    $core.String? messageId,
    $core.bool? isDeleted,
    $core.String? deletedAt,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    if (messageId != null) result.messageId = messageId;
    if (isDeleted != null) result.isDeleted = isDeleted;
    if (deletedAt != null) result.deletedAt = deletedAt;
    return result;
  }

  PubSubMessageUpdate._();

  factory PubSubMessageUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PubSubMessageUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PubSubMessageUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..aOS(2, _omitFieldNames ? '' : 'messageId')
    ..aOB(3, _omitFieldNames ? '' : 'isDeleted')
    ..aOS(4, _omitFieldNames ? '' : 'deletedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubSubMessageUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubSubMessageUpdate copyWith(void Function(PubSubMessageUpdate) updates) =>
      super.copyWith((message) => updates(message as PubSubMessageUpdate))
          as PubSubMessageUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PubSubMessageUpdate create() => PubSubMessageUpdate._();
  @$core.override
  PubSubMessageUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PubSubMessageUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PubSubMessageUpdate>(create);
  static PubSubMessageUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get messageId => $_getSZ(1);
  @$pb.TagNumber(2)
  set messageId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessageId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isDeleted => $_getBF(2);
  @$pb.TagNumber(3)
  set isDeleted($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsDeleted() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsDeleted() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get deletedAt => $_getSZ(3);
  @$pb.TagNumber(4)
  set deletedAt($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDeletedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearDeletedAt() => $_clearField(4);
}

class PubSubPinUpdate extends $pb.GeneratedMessage {
  factory PubSubPinUpdate({
    $core.String? roomId,
    $core.String? messageId,
    $core.bool? isPinned,
    $core.String? pinnedAt,
    $core.String? pinnedBy,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    if (messageId != null) result.messageId = messageId;
    if (isPinned != null) result.isPinned = isPinned;
    if (pinnedAt != null) result.pinnedAt = pinnedAt;
    if (pinnedBy != null) result.pinnedBy = pinnedBy;
    return result;
  }

  PubSubPinUpdate._();

  factory PubSubPinUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PubSubPinUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PubSubPinUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..aOS(2, _omitFieldNames ? '' : 'messageId')
    ..aOB(3, _omitFieldNames ? '' : 'isPinned')
    ..aOS(4, _omitFieldNames ? '' : 'pinnedAt')
    ..aOS(5, _omitFieldNames ? '' : 'pinnedBy')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubSubPinUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubSubPinUpdate copyWith(void Function(PubSubPinUpdate) updates) =>
      super.copyWith((message) => updates(message as PubSubPinUpdate))
          as PubSubPinUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PubSubPinUpdate create() => PubSubPinUpdate._();
  @$core.override
  PubSubPinUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PubSubPinUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PubSubPinUpdate>(create);
  static PubSubPinUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get messageId => $_getSZ(1);
  @$pb.TagNumber(2)
  set messageId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessageId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isPinned => $_getBF(2);
  @$pb.TagNumber(3)
  set isPinned($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsPinned() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsPinned() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get pinnedAt => $_getSZ(3);
  @$pb.TagNumber(4)
  set pinnedAt($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPinnedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearPinnedAt() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get pinnedBy => $_getSZ(4);
  @$pb.TagNumber(5)
  set pinnedBy($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPinnedBy() => $_has(4);
  @$pb.TagNumber(5)
  void clearPinnedBy() => $_clearField(5);
}

class PubSubRoomUpdate extends $pb.GeneratedMessage {
  factory PubSubRoomUpdate({
    $core.String? roomId,
    $core.String? roomName,
    $core.String? roomType,
    $core.String? avatarUrl,
    $core.String? avatarObjectKey,
    $core.String? description,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    if (roomName != null) result.roomName = roomName;
    if (roomType != null) result.roomType = roomType;
    if (avatarUrl != null) result.avatarUrl = avatarUrl;
    if (avatarObjectKey != null) result.avatarObjectKey = avatarObjectKey;
    if (description != null) result.description = description;
    return result;
  }

  PubSubRoomUpdate._();

  factory PubSubRoomUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PubSubRoomUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PubSubRoomUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..aOS(2, _omitFieldNames ? '' : 'roomName')
    ..aOS(3, _omitFieldNames ? '' : 'roomType')
    ..aOS(4, _omitFieldNames ? '' : 'avatarUrl')
    ..aOS(5, _omitFieldNames ? '' : 'avatarObjectKey')
    ..aOS(6, _omitFieldNames ? '' : 'description')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubSubRoomUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubSubRoomUpdate copyWith(void Function(PubSubRoomUpdate) updates) =>
      super.copyWith((message) => updates(message as PubSubRoomUpdate))
          as PubSubRoomUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PubSubRoomUpdate create() => PubSubRoomUpdate._();
  @$core.override
  PubSubRoomUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PubSubRoomUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PubSubRoomUpdate>(create);
  static PubSubRoomUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get roomName => $_getSZ(1);
  @$pb.TagNumber(2)
  set roomName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRoomName() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoomName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get roomType => $_getSZ(2);
  @$pb.TagNumber(3)
  set roomType($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRoomType() => $_has(2);
  @$pb.TagNumber(3)
  void clearRoomType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get avatarUrl => $_getSZ(3);
  @$pb.TagNumber(4)
  set avatarUrl($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAvatarUrl() => $_has(3);
  @$pb.TagNumber(4)
  void clearAvatarUrl() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get avatarObjectKey => $_getSZ(4);
  @$pb.TagNumber(5)
  set avatarObjectKey($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAvatarObjectKey() => $_has(4);
  @$pb.TagNumber(5)
  void clearAvatarObjectKey() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get description => $_getSZ(5);
  @$pb.TagNumber(6)
  set description($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDescription() => $_has(5);
  @$pb.TagNumber(6)
  void clearDescription() => $_clearField(6);
}

class PubSubGroupSettingsUpdate extends $pb.GeneratedMessage {
  factory PubSubGroupSettingsUpdate({
    $core.String? roomId,
    $core.bool? globalMuteEnabled,
    $core.String? globalMuteReason,
    $core.String? globalMuteUntil,
    $core.String? globalMuteSetBy,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    if (globalMuteEnabled != null) result.globalMuteEnabled = globalMuteEnabled;
    if (globalMuteReason != null) result.globalMuteReason = globalMuteReason;
    if (globalMuteUntil != null) result.globalMuteUntil = globalMuteUntil;
    if (globalMuteSetBy != null) result.globalMuteSetBy = globalMuteSetBy;
    return result;
  }

  PubSubGroupSettingsUpdate._();

  factory PubSubGroupSettingsUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PubSubGroupSettingsUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PubSubGroupSettingsUpdate',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..aOB(2, _omitFieldNames ? '' : 'globalMuteEnabled')
    ..aOS(3, _omitFieldNames ? '' : 'globalMuteReason')
    ..aOS(4, _omitFieldNames ? '' : 'globalMuteUntil')
    ..aOS(5, _omitFieldNames ? '' : 'globalMuteSetBy')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubSubGroupSettingsUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubSubGroupSettingsUpdate copyWith(
          void Function(PubSubGroupSettingsUpdate) updates) =>
      super.copyWith((message) => updates(message as PubSubGroupSettingsUpdate))
          as PubSubGroupSettingsUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PubSubGroupSettingsUpdate create() => PubSubGroupSettingsUpdate._();
  @$core.override
  PubSubGroupSettingsUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PubSubGroupSettingsUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PubSubGroupSettingsUpdate>(create);
  static PubSubGroupSettingsUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get globalMuteEnabled => $_getBF(1);
  @$pb.TagNumber(2)
  set globalMuteEnabled($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGlobalMuteEnabled() => $_has(1);
  @$pb.TagNumber(2)
  void clearGlobalMuteEnabled() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get globalMuteReason => $_getSZ(2);
  @$pb.TagNumber(3)
  set globalMuteReason($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGlobalMuteReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearGlobalMuteReason() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get globalMuteUntil => $_getSZ(3);
  @$pb.TagNumber(4)
  set globalMuteUntil($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasGlobalMuteUntil() => $_has(3);
  @$pb.TagNumber(4)
  void clearGlobalMuteUntil() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get globalMuteSetBy => $_getSZ(4);
  @$pb.TagNumber(5)
  set globalMuteSetBy($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGlobalMuteSetBy() => $_has(4);
  @$pb.TagNumber(5)
  void clearGlobalMuteSetBy() => $_clearField(5);
}

/// 群成员变更事件（用于跨节点广播）
class PubSubGroupMemberChanged extends $pb.GeneratedMessage {
  factory PubSubGroupMemberChanged({
    $core.String? roomId,
    $core.String? memberId,
    $core.String? changeType,
    $core.String? newRole,
    $core.String? operatorId,
    $core.String? reason,
    $core.String? until,
  }) {
    final result = create();
    if (roomId != null) result.roomId = roomId;
    if (memberId != null) result.memberId = memberId;
    if (changeType != null) result.changeType = changeType;
    if (newRole != null) result.newRole = newRole;
    if (operatorId != null) result.operatorId = operatorId;
    if (reason != null) result.reason = reason;
    if (until != null) result.until = until;
    return result;
  }

  PubSubGroupMemberChanged._();

  factory PubSubGroupMemberChanged.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PubSubGroupMemberChanged.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PubSubGroupMemberChanged',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'roomId')
    ..aOS(2, _omitFieldNames ? '' : 'memberId')
    ..aOS(3, _omitFieldNames ? '' : 'changeType')
    ..aOS(4, _omitFieldNames ? '' : 'newRole')
    ..aOS(5, _omitFieldNames ? '' : 'operatorId')
    ..aOS(6, _omitFieldNames ? '' : 'reason')
    ..aOS(7, _omitFieldNames ? '' : 'until')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubSubGroupMemberChanged clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubSubGroupMemberChanged copyWith(
          void Function(PubSubGroupMemberChanged) updates) =>
      super.copyWith((message) => updates(message as PubSubGroupMemberChanged))
          as PubSubGroupMemberChanged;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PubSubGroupMemberChanged create() => PubSubGroupMemberChanged._();
  @$core.override
  PubSubGroupMemberChanged createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PubSubGroupMemberChanged getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PubSubGroupMemberChanged>(create);
  static PubSubGroupMemberChanged? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get memberId => $_getSZ(1);
  @$pb.TagNumber(2)
  set memberId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMemberId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMemberId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get changeType => $_getSZ(2);
  @$pb.TagNumber(3)
  set changeType($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasChangeType() => $_has(2);
  @$pb.TagNumber(3)
  void clearChangeType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get newRole => $_getSZ(3);
  @$pb.TagNumber(4)
  set newRole($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNewRole() => $_has(3);
  @$pb.TagNumber(4)
  void clearNewRole() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get operatorId => $_getSZ(4);
  @$pb.TagNumber(5)
  set operatorId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasOperatorId() => $_has(4);
  @$pb.TagNumber(5)
  void clearOperatorId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get reason => $_getSZ(5);
  @$pb.TagNumber(6)
  set reason($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasReason() => $_has(5);
  @$pb.TagNumber(6)
  void clearReason() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get until => $_getSZ(6);
  @$pb.TagNumber(7)
  set until($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasUntil() => $_has(6);
  @$pb.TagNumber(7)
  void clearUntil() => $_clearField(7);
}

enum PubSubEvent_Payload {
  message,
  readReceipt,
  messageUpdate,
  pinUpdate,
  roomUpdate,
  groupSettingsUpdate,
  groupMemberChanged,
  notSet
}

class PubSubEvent extends $pb.GeneratedMessage {
  factory PubSubEvent({
    PubSubMessage? message,
    PubSubReadReceipt? readReceipt,
    PubSubMessageUpdate? messageUpdate,
    PubSubPinUpdate? pinUpdate,
    PubSubRoomUpdate? roomUpdate,
    PubSubGroupSettingsUpdate? groupSettingsUpdate,
    PubSubGroupMemberChanged? groupMemberChanged,
  }) {
    final result = create();
    if (message != null) result.message = message;
    if (readReceipt != null) result.readReceipt = readReceipt;
    if (messageUpdate != null) result.messageUpdate = messageUpdate;
    if (pinUpdate != null) result.pinUpdate = pinUpdate;
    if (roomUpdate != null) result.roomUpdate = roomUpdate;
    if (groupSettingsUpdate != null)
      result.groupSettingsUpdate = groupSettingsUpdate;
    if (groupMemberChanged != null)
      result.groupMemberChanged = groupMemberChanged;
    return result;
  }

  PubSubEvent._();

  factory PubSubEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PubSubEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, PubSubEvent_Payload>
      _PubSubEvent_PayloadByTag = {
    1: PubSubEvent_Payload.message,
    2: PubSubEvent_Payload.readReceipt,
    3: PubSubEvent_Payload.messageUpdate,
    4: PubSubEvent_Payload.pinUpdate,
    5: PubSubEvent_Payload.roomUpdate,
    6: PubSubEvent_Payload.groupSettingsUpdate,
    7: PubSubEvent_Payload.groupMemberChanged,
    0: PubSubEvent_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PubSubEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ws'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7])
    ..aOM<PubSubMessage>(1, _omitFieldNames ? '' : 'message',
        subBuilder: PubSubMessage.create)
    ..aOM<PubSubReadReceipt>(2, _omitFieldNames ? '' : 'readReceipt',
        subBuilder: PubSubReadReceipt.create)
    ..aOM<PubSubMessageUpdate>(3, _omitFieldNames ? '' : 'messageUpdate',
        subBuilder: PubSubMessageUpdate.create)
    ..aOM<PubSubPinUpdate>(4, _omitFieldNames ? '' : 'pinUpdate',
        subBuilder: PubSubPinUpdate.create)
    ..aOM<PubSubRoomUpdate>(5, _omitFieldNames ? '' : 'roomUpdate',
        subBuilder: PubSubRoomUpdate.create)
    ..aOM<PubSubGroupSettingsUpdate>(
        6, _omitFieldNames ? '' : 'groupSettingsUpdate',
        subBuilder: PubSubGroupSettingsUpdate.create)
    ..aOM<PubSubGroupMemberChanged>(
        7, _omitFieldNames ? '' : 'groupMemberChanged',
        subBuilder: PubSubGroupMemberChanged.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubSubEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PubSubEvent copyWith(void Function(PubSubEvent) updates) =>
      super.copyWith((message) => updates(message as PubSubEvent))
          as PubSubEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PubSubEvent create() => PubSubEvent._();
  @$core.override
  PubSubEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PubSubEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PubSubEvent>(create);
  static PubSubEvent? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  PubSubEvent_Payload whichPayload() =>
      _PubSubEvent_PayloadByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  void clearPayload() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  PubSubMessage get message => $_getN(0);
  @$pb.TagNumber(1)
  set message(PubSubMessage value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => $_clearField(1);
  @$pb.TagNumber(1)
  PubSubMessage ensureMessage() => $_ensure(0);

  @$pb.TagNumber(2)
  PubSubReadReceipt get readReceipt => $_getN(1);
  @$pb.TagNumber(2)
  set readReceipt(PubSubReadReceipt value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasReadReceipt() => $_has(1);
  @$pb.TagNumber(2)
  void clearReadReceipt() => $_clearField(2);
  @$pb.TagNumber(2)
  PubSubReadReceipt ensureReadReceipt() => $_ensure(1);

  @$pb.TagNumber(3)
  PubSubMessageUpdate get messageUpdate => $_getN(2);
  @$pb.TagNumber(3)
  set messageUpdate(PubSubMessageUpdate value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasMessageUpdate() => $_has(2);
  @$pb.TagNumber(3)
  void clearMessageUpdate() => $_clearField(3);
  @$pb.TagNumber(3)
  PubSubMessageUpdate ensureMessageUpdate() => $_ensure(2);

  @$pb.TagNumber(4)
  PubSubPinUpdate get pinUpdate => $_getN(3);
  @$pb.TagNumber(4)
  set pinUpdate(PubSubPinUpdate value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasPinUpdate() => $_has(3);
  @$pb.TagNumber(4)
  void clearPinUpdate() => $_clearField(4);
  @$pb.TagNumber(4)
  PubSubPinUpdate ensurePinUpdate() => $_ensure(3);

  @$pb.TagNumber(5)
  PubSubRoomUpdate get roomUpdate => $_getN(4);
  @$pb.TagNumber(5)
  set roomUpdate(PubSubRoomUpdate value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasRoomUpdate() => $_has(4);
  @$pb.TagNumber(5)
  void clearRoomUpdate() => $_clearField(5);
  @$pb.TagNumber(5)
  PubSubRoomUpdate ensureRoomUpdate() => $_ensure(4);

  @$pb.TagNumber(6)
  PubSubGroupSettingsUpdate get groupSettingsUpdate => $_getN(5);
  @$pb.TagNumber(6)
  set groupSettingsUpdate(PubSubGroupSettingsUpdate value) =>
      $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasGroupSettingsUpdate() => $_has(5);
  @$pb.TagNumber(6)
  void clearGroupSettingsUpdate() => $_clearField(6);
  @$pb.TagNumber(6)
  PubSubGroupSettingsUpdate ensureGroupSettingsUpdate() => $_ensure(5);

  @$pb.TagNumber(7)
  PubSubGroupMemberChanged get groupMemberChanged => $_getN(6);
  @$pb.TagNumber(7)
  set groupMemberChanged(PubSubGroupMemberChanged value) =>
      $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasGroupMemberChanged() => $_has(6);
  @$pb.TagNumber(7)
  void clearGroupMemberChanged() => $_clearField(7);
  @$pb.TagNumber(7)
  PubSubGroupMemberChanged ensureGroupMemberChanged() => $_ensure(6);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
