//
// 手工编写的 protobuf 定义，等价于 backend/proto/ws.proto
//

// ignore_for_file: annotate_overrides, camel_case_types, constant_identifier_names, library_prefixes, non_constant_identifier_names, prefer_final_fields, unused_import, deprecated_member_use

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessage;

// ============== Client 端事件 ==============

class ClientAuth extends $pb.GeneratedMessage {
  factory ClientAuth({$core.String? token}) {
    final $result = create();
    if (token != null) {
      $result.token = token;
    }
    return $result;
  }
  ClientAuth._() : super();
  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'ClientAuth',
          package: const $pb.PackageName('ws'),
          createEmptyInstance: create,
        )
        ..aOS(1, 'token')
        ..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientAuth create() => ClientAuth._();
  ClientAuth createEmptyInstance() => create();
  static $pb.PbList<ClientAuth> createRepeated() => $pb.PbList<ClientAuth>();
  @$core.pragma('dart2js:noInline')
  static ClientAuth getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientAuth>(create);
  static ClientAuth? _defaultInstance;

  @$core.override
  ClientAuth clone() => ClientAuth()..mergeFromMessage(this);

  @$core.override
  ClientAuth copyWith(void Function(ClientAuth) updates) =>
      super.copyWith((message) => updates(message as ClientAuth)) as ClientAuth;

  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => clearField(1);
}

class ClientJoin extends $pb.GeneratedMessage {
  factory ClientJoin({$core.String? roomId}) {
    final $result = create();
    if (roomId != null) {
      $result.roomId = roomId;
    }
    return $result;
  }
  ClientJoin._() : super();
  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'ClientJoin',
          package: const $pb.PackageName('ws'),
          createEmptyInstance: create,
        )
        ..aOS(1, 'roomId')
        ..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientJoin create() => ClientJoin._();
  ClientJoin createEmptyInstance() => create();
  static $pb.PbList<ClientJoin> createRepeated() => $pb.PbList<ClientJoin>();
  @$core.pragma('dart2js:noInline')
  static ClientJoin getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientJoin>(create);
  static ClientJoin? _defaultInstance;

  @$core.override
  ClientJoin clone() => ClientJoin()..mergeFromMessage(this);

  @$core.override
  ClientJoin copyWith(void Function(ClientJoin) updates) =>
      super.copyWith((message) => updates(message as ClientJoin)) as ClientJoin;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => clearField(1);
}

class ClientLeave extends $pb.GeneratedMessage {
  factory ClientLeave({$core.String? roomId}) {
    final $result = create();
    if (roomId != null) {
      $result.roomId = roomId;
    }
    return $result;
  }
  ClientLeave._() : super();
  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'ClientLeave',
          package: const $pb.PackageName('ws'),
          createEmptyInstance: create,
        )
        ..aOS(1, 'roomId')
        ..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientLeave create() => ClientLeave._();
  ClientLeave createEmptyInstance() => create();
  static $pb.PbList<ClientLeave> createRepeated() => $pb.PbList<ClientLeave>();
  @$core.pragma('dart2js:noInline')
  static ClientLeave getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientLeave>(create);
  static ClientLeave? _defaultInstance;

  @$core.override
  ClientLeave clone() => ClientLeave()..mergeFromMessage(this);

  @$core.override
  ClientLeave copyWith(void Function(ClientLeave) updates) =>
      super.copyWith((message) => updates(message as ClientLeave))
          as ClientLeave;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => clearField(1);
}

class ClientPing extends $pb.GeneratedMessage {
  factory ClientPing() => create();
  ClientPing._() : super();
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
    'ClientPing',
    package: const $pb.PackageName('ws'),
    createEmptyInstance: create,
  )..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientPing create() => ClientPing._();
  ClientPing createEmptyInstance() => create();
  static $pb.PbList<ClientPing> createRepeated() => $pb.PbList<ClientPing>();
  @$core.pragma('dart2js:noInline')
  static ClientPing getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientPing>(create);
  static ClientPing? _defaultInstance;

  @$core.override
  ClientPing clone() => ClientPing()..mergeFromMessage(this);

  @$core.override
  ClientPing copyWith(void Function(ClientPing) updates) =>
      super.copyWith((message) => updates(message as ClientPing)) as ClientPing;
}

enum ClientEvent_Payload { auth, join, leave, ping, notSet }

class ClientEvent extends $pb.GeneratedMessage {
  factory ClientEvent({
    ClientAuth? auth,
    ClientJoin? join,
    ClientLeave? leave,
    ClientPing? ping,
  }) {
    final $result = create();
    if (auth != null) {
      $result.auth = auth;
    }
    if (join != null) {
      $result.join = join;
    }
    if (leave != null) {
      $result.leave = leave;
    }
    if (ping != null) {
      $result.ping = ping;
    }
    return $result;
  }
  ClientEvent._() : super();
  static const $core.Map<$core.int, ClientEvent_Payload>
  _ClientEvent_PayloadByTag = {
    1: ClientEvent_Payload.auth,
    2: ClientEvent_Payload.join,
    3: ClientEvent_Payload.leave,
    4: ClientEvent_Payload.ping,
    0: ClientEvent_Payload.notSet,
  };
  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'ClientEvent',
          package: const $pb.PackageName('ws'),
          createEmptyInstance: create,
        )
        ..oo(0, [1, 2, 3, 4])
        ..aOM<ClientAuth>(1, 'auth', subBuilder: ClientAuth.create)
        ..aOM<ClientJoin>(2, 'join', subBuilder: ClientJoin.create)
        ..aOM<ClientLeave>(3, 'leave', subBuilder: ClientLeave.create)
        ..aOM<ClientPing>(4, 'ping', subBuilder: ClientPing.create)
        ..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  ClientEvent_Payload whichPayload() =>
      _ClientEvent_PayloadByTag[$_whichOneof(0)]!;
  void clearPayload() => clearField($_whichOneof(0));

  @$core.pragma('dart2js:noInline')
  static ClientEvent create() => ClientEvent._();
  ClientEvent createEmptyInstance() => create();
  static $pb.PbList<ClientEvent> createRepeated() => $pb.PbList<ClientEvent>();
  @$core.pragma('dart2js:noInline')
  static ClientEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientEvent>(create);
  static ClientEvent? _defaultInstance;

  @$core.override
  ClientEvent clone() => ClientEvent()..mergeFromMessage(this);

  @$core.override
  ClientEvent copyWith(void Function(ClientEvent) updates) =>
      super.copyWith((message) => updates(message as ClientEvent))
          as ClientEvent;

  @$pb.TagNumber(1)
  ClientAuth get auth => $_getN(0);
  @$pb.TagNumber(1)
  set auth(ClientAuth v) {
    setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasAuth() => $_has(0);
  @$pb.TagNumber(1)
  void clearAuth() => clearField(1);
  @$pb.TagNumber(1)
  ClientAuth ensureAuth() => $_ensure(0);

  @$pb.TagNumber(2)
  ClientJoin get join => $_getN(1);
  @$pb.TagNumber(2)
  set join(ClientJoin v) {
    setField(2, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasJoin() => $_has(1);
  @$pb.TagNumber(2)
  void clearJoin() => clearField(2);
  @$pb.TagNumber(2)
  ClientJoin ensureJoin() => $_ensure(1);

  @$pb.TagNumber(3)
  ClientLeave get leave => $_getN(2);
  @$pb.TagNumber(3)
  set leave(ClientLeave v) {
    setField(3, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasLeave() => $_has(2);
  @$pb.TagNumber(3)
  void clearLeave() => clearField(3);
  @$pb.TagNumber(3)
  ClientLeave ensureLeave() => $_ensure(2);

  @$pb.TagNumber(4)
  ClientPing get ping => $_getN(3);
  @$pb.TagNumber(4)
  set ping(ClientPing v) {
    setField(4, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasPing() => $_has(3);
  @$pb.TagNumber(4)
  void clearPing() => clearField(4);
  @$pb.TagNumber(4)
  ClientPing ensurePing() => $_ensure(3);
}

// ============== Server 端事件 ==============

class ServerAuthed extends $pb.GeneratedMessage {
  factory ServerAuthed({$core.String? userId, $core.String? connId}) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (connId != null) {
      $result.connId = connId;
    }
    return $result;
  }
  ServerAuthed._() : super();
  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'ServerAuthed',
          package: const $pb.PackageName('ws'),
          createEmptyInstance: create,
        )
        ..aOS(1, 'userId')
        ..aOS(2, 'connId')
        ..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerAuthed create() => ServerAuthed._();
  ServerAuthed createEmptyInstance() => create();
  static $pb.PbList<ServerAuthed> createRepeated() =>
      $pb.PbList<ServerAuthed>();
  @$core.pragma('dart2js:noInline')
  static ServerAuthed getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerAuthed>(create);
  static ServerAuthed? _defaultInstance;

  @$core.override
  ServerAuthed clone() => ServerAuthed()..mergeFromMessage(this);

  @$core.override
  ServerAuthed copyWith(void Function(ServerAuthed) updates) =>
      super.copyWith((message) => updates(message as ServerAuthed))
          as ServerAuthed;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get connId => $_getSZ(1);
  @$pb.TagNumber(2)
  set connId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasConnId() => $_has(1);
  @$pb.TagNumber(2)
  void clearConnId() => clearField(2);
}

class ServerJoined extends $pb.GeneratedMessage {
  factory ServerJoined({$core.String? roomId}) {
    final $result = create();
    if (roomId != null) {
      $result.roomId = roomId;
    }
    return $result;
  }
  ServerJoined._() : super();
  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'ServerJoined',
          package: const $pb.PackageName('ws'),
          createEmptyInstance: create,
        )
        ..aOS(1, 'roomId')
        ..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerJoined create() => ServerJoined._();
  ServerJoined createEmptyInstance() => create();
  static $pb.PbList<ServerJoined> createRepeated() =>
      $pb.PbList<ServerJoined>();
  @$core.pragma('dart2js:noInline')
  static ServerJoined getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerJoined>(create);
  static ServerJoined? _defaultInstance;

  @$core.override
  ServerJoined clone() => ServerJoined()..mergeFromMessage(this);

  @$core.override
  ServerJoined copyWith(void Function(ServerJoined) updates) =>
      super.copyWith((message) => updates(message as ServerJoined))
          as ServerJoined;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => clearField(1);
}

class ServerLeft extends $pb.GeneratedMessage {
  factory ServerLeft({$core.String? roomId}) {
    final $result = create();
    if (roomId != null) {
      $result.roomId = roomId;
    }
    return $result;
  }
  ServerLeft._() : super();
  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'ServerLeft',
          package: const $pb.PackageName('ws'),
          createEmptyInstance: create,
        )
        ..aOS(1, 'roomId')
        ..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerLeft create() => ServerLeft._();
  ServerLeft createEmptyInstance() => create();
  static $pb.PbList<ServerLeft> createRepeated() => $pb.PbList<ServerLeft>();
  @$core.pragma('dart2js:noInline')
  static ServerLeft getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerLeft>(create);
  static ServerLeft? _defaultInstance;

  @$core.override
  ServerLeft clone() => ServerLeft()..mergeFromMessage(this);

  @$core.override
  ServerLeft copyWith(void Function(ServerLeft) updates) =>
      super.copyWith((message) => updates(message as ServerLeft)) as ServerLeft;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => clearField(1);
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
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (roomId != null) {
      $result.roomId = roomId;
    }
    if (senderId != null) {
      $result.senderId = senderId;
    }
    if (senderUsername != null) {
      $result.senderUsername = senderUsername;
    }
    if (senderNickname != null) {
      $result.senderNickname = senderNickname;
    }
    if (senderAvatarUrl != null) {
      $result.senderAvatarUrl = senderAvatarUrl;
    }
    if (content != null) {
      $result.content = content;
    }
    if (messageType != null) {
      $result.messageType = messageType;
    }
    if (createdAt != null) {
      $result.createdAt = createdAt;
    }
    if (isDeleted != null) {
      $result.isDeleted = isDeleted;
    }
    return $result;
  }
  QuotedMessage._() : super();
  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'QuotedMessage',
          package: const $pb.PackageName('ws'),
          createEmptyInstance: create,
        )
        ..aOS(1, 'id')
        ..aOS(2, 'roomId')
        ..aOS(3, 'senderId')
        ..aOS(4, 'senderUsername')
        ..aOS(5, 'senderNickname')
        ..aOS(6, 'senderAvatarUrl')
        ..aOS(7, 'content')
        ..aOS(8, 'messageType')
        ..aOS(9, 'createdAt')
        ..aOB(10, 'isDeleted')
        ..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QuotedMessage create() => QuotedMessage._();
  QuotedMessage createEmptyInstance() => create();
  static $pb.PbList<QuotedMessage> createRepeated() =>
      $pb.PbList<QuotedMessage>();
  @$core.pragma('dart2js:noInline')
  static QuotedMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<QuotedMessage>(create);
  static QuotedMessage? _defaultInstance;

  @$core.override
  QuotedMessage clone() => QuotedMessage()..mergeFromMessage(this);

  @$core.override
  QuotedMessage copyWith(void Function(QuotedMessage) updates) =>
      super.copyWith((message) => updates(message as QuotedMessage))
          as QuotedMessage;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get roomId => $_getSZ(1);
  @$pb.TagNumber(2)
  set roomId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasRoomId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoomId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get senderId => $_getSZ(2);
  @$pb.TagNumber(3)
  set senderId($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasSenderId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSenderId() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get senderUsername => $_getSZ(3);
  @$pb.TagNumber(4)
  set senderUsername($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasSenderUsername() => $_has(3);
  @$pb.TagNumber(4)
  void clearSenderUsername() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get senderNickname => $_getSZ(4);
  @$pb.TagNumber(5)
  set senderNickname($core.String v) {
    $_setString(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasSenderNickname() => $_has(4);
  @$pb.TagNumber(5)
  void clearSenderNickname() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get senderAvatarUrl => $_getSZ(5);
  @$pb.TagNumber(6)
  set senderAvatarUrl($core.String v) {
    $_setString(5, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasSenderAvatarUrl() => $_has(5);
  @$pb.TagNumber(6)
  void clearSenderAvatarUrl() => clearField(6);

  @$pb.TagNumber(7)
  $core.String get content => $_getSZ(6);
  @$pb.TagNumber(7)
  set content($core.String v) {
    $_setString(6, v);
  }

  @$pb.TagNumber(7)
  $core.bool hasContent() => $_has(6);
  @$pb.TagNumber(7)
  void clearContent() => clearField(7);

  @$pb.TagNumber(8)
  $core.String get messageType => $_getSZ(7);
  @$pb.TagNumber(8)
  set messageType($core.String v) {
    $_setString(7, v);
  }

  @$pb.TagNumber(8)
  $core.bool hasMessageType() => $_has(7);
  @$pb.TagNumber(8)
  void clearMessageType() => clearField(8);

  @$pb.TagNumber(9)
  $core.String get createdAt => $_getSZ(8);
  @$pb.TagNumber(9)
  set createdAt($core.String v) {
    $_setString(8, v);
  }

  @$pb.TagNumber(9)
  $core.bool hasCreatedAt() => $_has(8);
  @$pb.TagNumber(9)
  void clearCreatedAt() => clearField(9);

  @$pb.TagNumber(10)
  $core.bool get isDeleted => $_getBF(9);
  @$pb.TagNumber(10)
  set isDeleted($core.bool v) {
    $_setBool(9, v);
  }

  @$pb.TagNumber(10)
  $core.bool hasIsDeleted() => $_has(9);
  @$pb.TagNumber(10)
  void clearIsDeleted() => clearField(10);
}

class ForwardMessage extends $pb.GeneratedMessage {
  factory ForwardMessage({
    $core.String? messageId,
    $core.String? roomId,
    $core.String? senderId,
    $core.String? senderUsername,
    $core.String? senderNickname,
  }) {
    final $result = create();
    if (messageId != null) {
      $result.messageId = messageId;
    }
    if (roomId != null) {
      $result.roomId = roomId;
    }
    if (senderId != null) {
      $result.senderId = senderId;
    }
    if (senderUsername != null) {
      $result.senderUsername = senderUsername;
    }
    if (senderNickname != null) {
      $result.senderNickname = senderNickname;
    }
    return $result;
  }
  ForwardMessage._() : super();
  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'ForwardMessage',
          package: const $pb.PackageName('ws'),
          createEmptyInstance: create,
        )
        ..aOS(1, 'messageId')
        ..aOS(2, 'roomId')
        ..aOS(3, 'senderId')
        ..aOS(4, 'senderUsername')
        ..aOS(5, 'senderNickname')
        ..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ForwardMessage create() => ForwardMessage._();
  ForwardMessage createEmptyInstance() => create();
  static $pb.PbList<ForwardMessage> createRepeated() =>
      $pb.PbList<ForwardMessage>();
  @$core.pragma('dart2js:noInline')
  static ForwardMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ForwardMessage>(create);
  static ForwardMessage? _defaultInstance;

  @$core.override
  ForwardMessage clone() => ForwardMessage()..mergeFromMessage(this);

  @$core.override
  ForwardMessage copyWith(void Function(ForwardMessage) updates) =>
      super.copyWith((message) => updates(message as ForwardMessage))
          as ForwardMessage;

  @$pb.TagNumber(1)
  $core.String get messageId => $_getSZ(0);
  @$pb.TagNumber(1)
  set messageId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasMessageId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessageId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get roomId => $_getSZ(1);
  @$pb.TagNumber(2)
  set roomId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasRoomId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoomId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get senderId => $_getSZ(2);
  @$pb.TagNumber(3)
  set senderId($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasSenderId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSenderId() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get senderUsername => $_getSZ(3);
  @$pb.TagNumber(4)
  set senderUsername($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasSenderUsername() => $_has(3);
  @$pb.TagNumber(4)
  void clearSenderUsername() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get senderNickname => $_getSZ(4);
  @$pb.TagNumber(5)
  set senderNickname($core.String v) {
    $_setString(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasSenderNickname() => $_has(4);
  @$pb.TagNumber(5)
  void clearSenderNickname() => clearField(5);
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
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (messageId != null) {
      $result.messageId = messageId;
    }
    if (roomId != null) {
      $result.roomId = roomId;
    }
    if (senderId != null) {
      $result.senderId = senderId;
    }
    if (senderUsername != null) {
      $result.senderUsername = senderUsername;
    }
    if (senderNickname != null) {
      $result.senderNickname = senderNickname;
    }
    if (senderAvatarUrl != null) {
      $result.senderAvatarUrl = senderAvatarUrl;
    }
    if (content != null) {
      $result.content = content;
    }
    if (messageType != null) {
      $result.messageType = messageType;
    }
    if (timestamp != null) {
      $result.timestamp = timestamp;
    }
    if (quotedMessage != null) {
      $result.quotedMessage = quotedMessage;
    }
    if (forwardMessage != null) {
      $result.forwardMessage = forwardMessage;
    }
    return $result;
  }
  ServerMessage._() : super();
  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'ServerMessage',
          package: const $pb.PackageName('ws'),
          createEmptyInstance: create,
        )
        ..aOS(1, 'id')
        ..aOS(2, 'messageId')
        ..aOS(3, 'roomId')
        ..aOS(4, 'senderId')
        ..aOS(5, 'senderUsername')
        ..aOS(6, 'senderNickname')
        ..aOS(7, 'senderAvatarUrl')
        ..aOS(8, 'content')
        ..aOS(9, 'messageType')
        ..aOS(10, 'timestamp')
        ..aOM<QuotedMessage>(
          11,
          'quotedMessage',
          subBuilder: QuotedMessage.create,
        )
        ..aOM<ForwardMessage>(
          12,
          'forwardMessage',
          subBuilder: ForwardMessage.create,
        )
        ..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerMessage create() => ServerMessage._();
  ServerMessage createEmptyInstance() => create();
  static $pb.PbList<ServerMessage> createRepeated() =>
      $pb.PbList<ServerMessage>();
  @$core.pragma('dart2js:noInline')
  static ServerMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerMessage>(create);
  static ServerMessage? _defaultInstance;

  @$core.override
  ServerMessage clone() => ServerMessage()..mergeFromMessage(this);

  @$core.override
  ServerMessage copyWith(void Function(ServerMessage) updates) =>
      super.copyWith((message) => updates(message as ServerMessage))
          as ServerMessage;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get messageId => $_getSZ(1);
  @$pb.TagNumber(2)
  set messageId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasMessageId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get roomId => $_getSZ(2);
  @$pb.TagNumber(3)
  set roomId($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasRoomId() => $_has(2);
  @$pb.TagNumber(3)
  void clearRoomId() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get senderId => $_getSZ(3);
  @$pb.TagNumber(4)
  set senderId($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasSenderId() => $_has(3);
  @$pb.TagNumber(4)
  void clearSenderId() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get senderUsername => $_getSZ(4);
  @$pb.TagNumber(5)
  set senderUsername($core.String v) {
    $_setString(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasSenderUsername() => $_has(4);
  @$pb.TagNumber(5)
  void clearSenderUsername() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get senderNickname => $_getSZ(5);
  @$pb.TagNumber(6)
  set senderNickname($core.String v) {
    $_setString(5, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasSenderNickname() => $_has(5);
  @$pb.TagNumber(6)
  void clearSenderNickname() => clearField(6);

  @$pb.TagNumber(7)
  $core.String get senderAvatarUrl => $_getSZ(6);
  @$pb.TagNumber(7)
  set senderAvatarUrl($core.String v) {
    $_setString(6, v);
  }

  @$pb.TagNumber(7)
  $core.bool hasSenderAvatarUrl() => $_has(6);
  @$pb.TagNumber(7)
  void clearSenderAvatarUrl() => clearField(7);

  @$pb.TagNumber(8)
  $core.String get content => $_getSZ(7);
  @$pb.TagNumber(8)
  set content($core.String v) {
    $_setString(7, v);
  }

  @$pb.TagNumber(8)
  $core.bool hasContent() => $_has(7);
  @$pb.TagNumber(8)
  void clearContent() => clearField(8);

  @$pb.TagNumber(9)
  $core.String get messageType => $_getSZ(8);
  @$pb.TagNumber(9)
  set messageType($core.String v) {
    $_setString(8, v);
  }

  @$pb.TagNumber(9)
  $core.bool hasMessageType() => $_has(8);
  @$pb.TagNumber(9)
  void clearMessageType() => clearField(9);

  @$pb.TagNumber(10)
  $core.String get timestamp => $_getSZ(9);
  @$pb.TagNumber(10)
  set timestamp($core.String v) {
    $_setString(9, v);
  }

  @$pb.TagNumber(10)
  $core.bool hasTimestamp() => $_has(9);
  @$pb.TagNumber(10)
  void clearTimestamp() => clearField(10);

  @$pb.TagNumber(11)
  QuotedMessage get quotedMessage => $_getN(10);
  @$pb.TagNumber(11)
  set quotedMessage(QuotedMessage v) {
    setField(11, v);
  }

  @$pb.TagNumber(11)
  $core.bool hasQuotedMessage() => $_has(10);
  @$pb.TagNumber(11)
  void clearQuotedMessage() => clearField(11);
  @$pb.TagNumber(11)
  QuotedMessage ensureQuotedMessage() => $_ensure(10);

  @$pb.TagNumber(12)
  ForwardMessage get forwardMessage => $_getN(11);
  @$pb.TagNumber(12)
  set forwardMessage(ForwardMessage v) {
    setField(12, v);
  }

  @$pb.TagNumber(12)
  $core.bool hasForwardMessage() => $_has(11);
  @$pb.TagNumber(12)
  void clearForwardMessage() => clearField(12);
  @$pb.TagNumber(12)
  ForwardMessage ensureForwardMessage() => $_ensure(11);
}

class ServerMessageRead extends $pb.GeneratedMessage {
  factory ServerMessageRead({
    $core.String? roomId,
    $core.String? messageId,
    $core.String? readerId,
    $core.String? readAt,
  }) {
    final $result = create();
    if (roomId != null) {
      $result.roomId = roomId;
    }
    if (messageId != null) {
      $result.messageId = messageId;
    }
    if (readerId != null) {
      $result.readerId = readerId;
    }
    if (readAt != null) {
      $result.readAt = readAt;
    }
    return $result;
  }
  ServerMessageRead._() : super();
  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'ServerMessageRead',
          package: const $pb.PackageName('ws'),
          createEmptyInstance: create,
        )
        ..aOS(1, 'roomId')
        ..aOS(2, 'messageId')
        ..aOS(3, 'readerId')
        ..aOS(4, 'readAt')
        ..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerMessageRead create() => ServerMessageRead._();
  ServerMessageRead createEmptyInstance() => create();
  static $pb.PbList<ServerMessageRead> createRepeated() =>
      $pb.PbList<ServerMessageRead>();
  @$core.pragma('dart2js:noInline')
  static ServerMessageRead getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerMessageRead>(create);
  static ServerMessageRead? _defaultInstance;

  @$core.override
  ServerMessageRead clone() => ServerMessageRead()..mergeFromMessage(this);

  @$core.override
  ServerMessageRead copyWith(void Function(ServerMessageRead) updates) =>
      super.copyWith((message) => updates(message as ServerMessageRead))
          as ServerMessageRead;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get messageId => $_getSZ(1);
  @$pb.TagNumber(2)
  set messageId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasMessageId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get readerId => $_getSZ(2);
  @$pb.TagNumber(3)
  set readerId($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasReaderId() => $_has(2);
  @$pb.TagNumber(3)
  void clearReaderId() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get readAt => $_getSZ(3);
  @$pb.TagNumber(4)
  set readAt($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasReadAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearReadAt() => clearField(4);
}

class ServerMessageUpdate extends $pb.GeneratedMessage {
  factory ServerMessageUpdate({
    $core.String? roomId,
    $core.String? messageId,
    $core.bool? isDeleted,
    $core.String? deletedAt,
  }) {
    final $result = create();
    if (roomId != null) {
      $result.roomId = roomId;
    }
    if (messageId != null) {
      $result.messageId = messageId;
    }
    if (isDeleted != null) {
      $result.isDeleted = isDeleted;
    }
    if (deletedAt != null) {
      $result.deletedAt = deletedAt;
    }
    return $result;
  }
  ServerMessageUpdate._() : super();
  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'ServerMessageUpdate',
          package: const $pb.PackageName('ws'),
          createEmptyInstance: create,
        )
        ..aOS(1, 'roomId')
        ..aOS(2, 'messageId')
        ..aOB(3, 'isDeleted')
        ..aOS(4, 'deletedAt')
        ..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerMessageUpdate create() => ServerMessageUpdate._();
  ServerMessageUpdate createEmptyInstance() => create();
  static $pb.PbList<ServerMessageUpdate> createRepeated() =>
      $pb.PbList<ServerMessageUpdate>();
  @$core.pragma('dart2js:noInline')
  static ServerMessageUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerMessageUpdate>(create);
  static ServerMessageUpdate? _defaultInstance;

  @$core.override
  ServerMessageUpdate clone() => ServerMessageUpdate()..mergeFromMessage(this);

  @$core.override
  ServerMessageUpdate copyWith(void Function(ServerMessageUpdate) updates) =>
      super.copyWith((message) => updates(message as ServerMessageUpdate))
          as ServerMessageUpdate;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get messageId => $_getSZ(1);
  @$pb.TagNumber(2)
  set messageId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasMessageId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageId() => clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isDeleted => $_getBF(2);
  @$pb.TagNumber(3)
  set isDeleted($core.bool v) {
    $_setBool(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasIsDeleted() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsDeleted() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get deletedAt => $_getSZ(3);
  @$pb.TagNumber(4)
  set deletedAt($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasDeletedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearDeletedAt() => clearField(4);
}

class ServerPinUpdate extends $pb.GeneratedMessage {
  factory ServerPinUpdate({
    $core.String? roomId,
    $core.String? messageId,
    $core.bool? isPinned,
    $core.String? pinnedAt,
    $core.String? pinnedBy,
  }) {
    final $result = create();
    if (roomId != null) {
      $result.roomId = roomId;
    }
    if (messageId != null) {
      $result.messageId = messageId;
    }
    if (isPinned != null) {
      $result.isPinned = isPinned;
    }
    if (pinnedAt != null) {
      $result.pinnedAt = pinnedAt;
    }
    if (pinnedBy != null) {
      $result.pinnedBy = pinnedBy;
    }
    return $result;
  }
  ServerPinUpdate._() : super();
  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'ServerPinUpdate',
          package: const $pb.PackageName('ws'),
          createEmptyInstance: create,
        )
        ..aOS(1, 'roomId')
        ..aOS(2, 'messageId')
        ..aOB(3, 'isPinned')
        ..aOS(4, 'pinnedAt')
        ..aOS(5, 'pinnedBy')
        ..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerPinUpdate create() => ServerPinUpdate._();
  ServerPinUpdate createEmptyInstance() => create();
  static $pb.PbList<ServerPinUpdate> createRepeated() =>
      $pb.PbList<ServerPinUpdate>();
  @$core.pragma('dart2js:noInline')
  static ServerPinUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerPinUpdate>(create);
  static ServerPinUpdate? _defaultInstance;

  @$core.override
  ServerPinUpdate clone() => ServerPinUpdate()..mergeFromMessage(this);

  @$core.override
  ServerPinUpdate copyWith(void Function(ServerPinUpdate) updates) =>
      super.copyWith((message) => updates(message as ServerPinUpdate))
          as ServerPinUpdate;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get messageId => $_getSZ(1);
  @$pb.TagNumber(2)
  set messageId($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasMessageId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageId() => clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isPinned => $_getBF(2);
  @$pb.TagNumber(3)
  set isPinned($core.bool v) {
    $_setBool(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasIsPinned() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsPinned() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get pinnedAt => $_getSZ(3);
  @$pb.TagNumber(4)
  set pinnedAt($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasPinnedAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearPinnedAt() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get pinnedBy => $_getSZ(4);
  @$pb.TagNumber(5)
  set pinnedBy($core.String v) {
    $_setString(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasPinnedBy() => $_has(4);
  @$pb.TagNumber(5)
  void clearPinnedBy() => clearField(5);
}

class ServerError extends $pb.GeneratedMessage {
  factory ServerError({$core.String? message}) {
    final $result = create();
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  ServerError._() : super();
  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'ServerError',
          package: const $pb.PackageName('ws'),
          createEmptyInstance: create,
        )
        ..aOS(1, 'message')
        ..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerError create() => ServerError._();
  ServerError createEmptyInstance() => create();
  static $pb.PbList<ServerError> createRepeated() => $pb.PbList<ServerError>();
  @$core.pragma('dart2js:noInline')
  static ServerError getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerError>(create);
  static ServerError? _defaultInstance;

  @$core.override
  ServerError clone() => ServerError()..mergeFromMessage(this);

  @$core.override
  ServerError copyWith(void Function(ServerError) updates) =>
      super.copyWith((message) => updates(message as ServerError))
          as ServerError;

  @$pb.TagNumber(1)
  $core.String get message => $_getSZ(0);
  @$pb.TagNumber(1)
  set message($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => clearField(1);
}

class ServerPong extends $pb.GeneratedMessage {
  factory ServerPong() => create();
  ServerPong._() : super();
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
    'ServerPong',
    package: const $pb.PackageName('ws'),
    createEmptyInstance: create,
  )..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerPong create() => ServerPong._();
  ServerPong createEmptyInstance() => create();
  static $pb.PbList<ServerPong> createRepeated() => $pb.PbList<ServerPong>();
  @$core.pragma('dart2js:noInline')
  static ServerPong getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerPong>(create);
  static ServerPong? _defaultInstance;

  @$core.override
  ServerPong clone() => ServerPong()..mergeFromMessage(this);

  @$core.override
  ServerPong copyWith(void Function(ServerPong) updates) =>
      super.copyWith((message) => updates(message as ServerPong)) as ServerPong;
}

class ServerFriendRequestUpdate extends $pb.GeneratedMessage {
  factory ServerFriendRequestUpdate({$core.int? pendingCount}) {
    final $result = create();
    if (pendingCount != null) {
      $result.pendingCount = pendingCount;
    }
    return $result;
  }
  ServerFriendRequestUpdate._() : super();
  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'ServerFriendRequestUpdate',
          package: const $pb.PackageName('ws'),
          createEmptyInstance: create,
        )
        ..a<$core.int>(1, 'pendingCount', $pb.PbFieldType.O3)
        ..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerFriendRequestUpdate create() => ServerFriendRequestUpdate._();
  ServerFriendRequestUpdate createEmptyInstance() => create();
  static $pb.PbList<ServerFriendRequestUpdate> createRepeated() =>
      $pb.PbList<ServerFriendRequestUpdate>();
  @$core.pragma('dart2js:noInline')
  static ServerFriendRequestUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerFriendRequestUpdate>(create);
  static ServerFriendRequestUpdate? _defaultInstance;

  @$core.override
  ServerFriendRequestUpdate clone() =>
      ServerFriendRequestUpdate()..mergeFromMessage(this);

  @$core.override
  ServerFriendRequestUpdate copyWith(
    void Function(ServerFriendRequestUpdate) updates,
  ) =>
      super.copyWith((message) => updates(message as ServerFriendRequestUpdate))
          as ServerFriendRequestUpdate;

  @$pb.TagNumber(1)
  $core.int get pendingCount => $_getIZ(0);
  @$pb.TagNumber(1)
  set pendingCount($core.int v) {
    $_setSignedInt32(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasPendingCount() => $_has(0);
  @$pb.TagNumber(1)
  void clearPendingCount() => clearField(1);
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
    final $result = create();
    if (roomId != null) {
      $result.roomId = roomId;
    }
    if (roomName != null) {
      $result.roomName = roomName;
    }
    if (roomType != null) {
      $result.roomType = roomType;
    }
    if (initiatorId != null) {
      $result.initiatorId = initiatorId;
    }
    if (ownerId != null) {
      $result.ownerId = ownerId;
    }
    if (description != null) {
      $result.description = description;
    }
    if (avatarUrl != null) {
      $result.avatarUrl = avatarUrl;
    }
    if (createdAt != null) {
      $result.createdAt = createdAt;
    }
    return $result;
  }
  ServerRoomCreated._() : super();
  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'ServerRoomCreated',
          package: const $pb.PackageName('ws'),
          createEmptyInstance: create,
        )
        ..aOS(1, 'roomId')
        ..aOS(2, 'roomName')
        ..aOS(3, 'roomType')
        ..aOS(4, 'initiatorId')
        ..aOS(5, 'ownerId')
        ..aOS(6, 'description')
        ..aOS(7, 'avatarUrl')
        ..aOS(8, 'createdAt')
        ..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerRoomCreated create() => ServerRoomCreated._();
  ServerRoomCreated createEmptyInstance() => create();
  static $pb.PbList<ServerRoomCreated> createRepeated() =>
      $pb.PbList<ServerRoomCreated>();
  @$core.pragma('dart2js:noInline')
  static ServerRoomCreated getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerRoomCreated>(create);
  static ServerRoomCreated? _defaultInstance;

  @$core.override
  ServerRoomCreated clone() => ServerRoomCreated()..mergeFromMessage(this);

  @$core.override
  ServerRoomCreated copyWith(void Function(ServerRoomCreated) updates) =>
      super.copyWith((message) => updates(message as ServerRoomCreated))
          as ServerRoomCreated;

  @$pb.TagNumber(1)
  $core.String get roomId => $_getSZ(0);
  @$pb.TagNumber(1)
  set roomId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasRoomId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRoomId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get roomName => $_getSZ(1);
  @$pb.TagNumber(2)
  set roomName($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasRoomName() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoomName() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get roomType => $_getSZ(2);
  @$pb.TagNumber(3)
  set roomType($core.String v) {
    $_setString(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasRoomType() => $_has(2);
  @$pb.TagNumber(3)
  void clearRoomType() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get initiatorId => $_getSZ(3);
  @$pb.TagNumber(4)
  set initiatorId($core.String v) {
    $_setString(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasInitiatorId() => $_has(3);
  @$pb.TagNumber(4)
  void clearInitiatorId() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get ownerId => $_getSZ(4);
  @$pb.TagNumber(5)
  set ownerId($core.String v) {
    $_setString(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasOwnerId() => $_has(4);
  @$pb.TagNumber(5)
  void clearOwnerId() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get description => $_getSZ(5);
  @$pb.TagNumber(6)
  set description($core.String v) {
    $_setString(5, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasDescription() => $_has(5);
  @$pb.TagNumber(6)
  void clearDescription() => clearField(6);

  @$pb.TagNumber(7)
  $core.String get avatarUrl => $_getSZ(6);
  @$pb.TagNumber(7)
  set avatarUrl($core.String v) {
    $_setString(6, v);
  }

  @$pb.TagNumber(7)
  $core.bool hasAvatarUrl() => $_has(6);
  @$pb.TagNumber(7)
  void clearAvatarUrl() => clearField(7);

  @$pb.TagNumber(8)
  $core.String get createdAt => $_getSZ(7);
  @$pb.TagNumber(8)
  set createdAt($core.String v) {
    $_setString(7, v);
  }

  @$pb.TagNumber(8)
  $core.bool hasCreatedAt() => $_has(7);
  @$pb.TagNumber(8)
  void clearCreatedAt() => clearField(8);
}

class ServerBanned extends $pb.GeneratedMessage {
  factory ServerBanned({
    $core.String? userId,
    $core.String? reason,
  }) {
    final $result = create();
    if (userId != null) {
      $result.userId = userId;
    }
    if (reason != null) {
      $result.reason = reason;
    }
    return $result;
  }
  ServerBanned._() : super();
  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'ServerBanned',
          package: const $pb.PackageName('ws'),
          createEmptyInstance: create,
        )
        ..aOS(1, 'userId')
        ..aOS(2, 'reason')
        ..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerBanned create() => ServerBanned._();
  ServerBanned createEmptyInstance() => create();
  static $pb.PbList<ServerBanned> createRepeated() =>
      $pb.PbList<ServerBanned>();
  @$core.pragma('dart2js:noInline')
  static ServerBanned getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerBanned>(create);
  static ServerBanned? _defaultInstance;

  @$core.override
  ServerBanned clone() => ServerBanned()..mergeFromMessage(this);

  @$core.override
  ServerBanned copyWith(void Function(ServerBanned) updates) =>
      super.copyWith((message) => updates(message as ServerBanned))
          as ServerBanned;

  @$pb.TagNumber(1)
  $core.String get userId => $_getSZ(0);
  @$pb.TagNumber(1)
  set userId($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasUserId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUserId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => clearField(2);
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
  notSet,
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
  }) {
    final $result = create();
    if (authed != null) {
      $result.authed = authed;
    }
    if (joined != null) {
      $result.joined = joined;
    }
    if (left != null) {
      $result.left = left;
    }
    if (message != null) {
      $result.message = message;
    }
    if (messageRead != null) {
      $result.messageRead = messageRead;
    }
    if (messageUpdate != null) {
      $result.messageUpdate = messageUpdate;
    }
    if (pinUpdate != null) {
      $result.pinUpdate = pinUpdate;
    }
    if (error != null) {
      $result.error = error;
    }
    if (pong != null) {
      $result.pong = pong;
    }
    if (friendRequestUpdate != null) {
      $result.friendRequestUpdate = friendRequestUpdate;
    }
    if (roomCreated != null) {
      $result.roomCreated = roomCreated;
    }
    if (userBanned != null) {
      $result.userBanned = userBanned;
    }
    return $result;
  }
  ServerEvent._() : super();
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
    0: ServerEvent_Payload.notSet,
  };
  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo(
          'ServerEvent',
          package: const $pb.PackageName('ws'),
          createEmptyInstance: create,
        )
        ..oo(0, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
        ..aOM<ServerAuthed>(1, 'authed', subBuilder: ServerAuthed.create)
        ..aOM<ServerJoined>(2, 'joined', subBuilder: ServerJoined.create)
        ..aOM<ServerLeft>(3, 'left', subBuilder: ServerLeft.create)
        ..aOM<ServerMessage>(4, 'message', subBuilder: ServerMessage.create)
        ..aOM<ServerMessageRead>(
          5,
          'messageRead',
          subBuilder: ServerMessageRead.create,
        )
        ..aOM<ServerMessageUpdate>(
          6,
          'messageUpdate',
          subBuilder: ServerMessageUpdate.create,
        )
        ..aOM<ServerPinUpdate>(
          7,
          'pinUpdate',
          subBuilder: ServerPinUpdate.create,
        )
        ..aOM<ServerError>(8, 'error', subBuilder: ServerError.create)
        ..aOM<ServerPong>(9, 'pong', subBuilder: ServerPong.create)
        ..aOM<ServerFriendRequestUpdate>(
          10,
          'friendRequestUpdate',
          subBuilder: ServerFriendRequestUpdate.create,
        )
        ..aOM<ServerRoomCreated>(
          11,
          'roomCreated',
          subBuilder: ServerRoomCreated.create,
        )
        ..aOM<ServerBanned>(
          12,
          'userBanned',
          subBuilder: ServerBanned.create,
        )
        ..hasRequiredFields = false;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  ServerEvent_Payload whichPayload() =>
      _ServerEvent_PayloadByTag[$_whichOneof(0)]!;
  void clearPayload() => clearField($_whichOneof(0));

  @$core.pragma('dart2js:noInline')
  static ServerEvent create() => ServerEvent._();
  ServerEvent createEmptyInstance() => create();
  static $pb.PbList<ServerEvent> createRepeated() => $pb.PbList<ServerEvent>();
  @$core.pragma('dart2js:noInline')
  static ServerEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ServerEvent>(create);
  static ServerEvent? _defaultInstance;

  @$core.override
  ServerEvent clone() => ServerEvent()..mergeFromMessage(this);

  @$core.override
  ServerEvent copyWith(void Function(ServerEvent) updates) =>
      super.copyWith((message) => updates(message as ServerEvent))
          as ServerEvent;

  @$pb.TagNumber(1)
  ServerAuthed get authed => $_getN(0);
  @$pb.TagNumber(1)
  set authed(ServerAuthed v) {
    setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasAuthed() => $_has(0);
  @$pb.TagNumber(1)
  void clearAuthed() => clearField(1);
  @$pb.TagNumber(1)
  ServerAuthed ensureAuthed() => $_ensure(0);

  @$pb.TagNumber(2)
  ServerJoined get joined => $_getN(1);
  @$pb.TagNumber(2)
  set joined(ServerJoined v) {
    setField(2, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasJoined() => $_has(1);
  @$pb.TagNumber(2)
  void clearJoined() => clearField(2);
  @$pb.TagNumber(2)
  ServerJoined ensureJoined() => $_ensure(1);

  @$pb.TagNumber(3)
  ServerLeft get left => $_getN(2);
  @$pb.TagNumber(3)
  set left(ServerLeft v) {
    setField(3, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasLeft() => $_has(2);
  @$pb.TagNumber(3)
  void clearLeft() => clearField(3);
  @$pb.TagNumber(3)
  ServerLeft ensureLeft() => $_ensure(2);

  @$pb.TagNumber(4)
  ServerMessage get message => $_getN(3);
  @$pb.TagNumber(4)
  set message(ServerMessage v) {
    setField(4, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasMessage() => $_has(3);
  @$pb.TagNumber(4)
  void clearMessage() => clearField(4);
  @$pb.TagNumber(4)
  ServerMessage ensureMessage() => $_ensure(3);

  @$pb.TagNumber(5)
  ServerMessageRead get messageRead => $_getN(4);
  @$pb.TagNumber(5)
  set messageRead(ServerMessageRead v) {
    setField(5, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasMessageRead() => $_has(4);
  @$pb.TagNumber(5)
  void clearMessageRead() => clearField(5);
  @$pb.TagNumber(5)
  ServerMessageRead ensureMessageRead() => $_ensure(4);

  @$pb.TagNumber(6)
  ServerMessageUpdate get messageUpdate => $_getN(5);
  @$pb.TagNumber(6)
  set messageUpdate(ServerMessageUpdate v) {
    setField(6, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasMessageUpdate() => $_has(5);
  @$pb.TagNumber(6)
  void clearMessageUpdate() => clearField(6);
  @$pb.TagNumber(6)
  ServerMessageUpdate ensureMessageUpdate() => $_ensure(5);

  @$pb.TagNumber(7)
  ServerPinUpdate get pinUpdate => $_getN(6);
  @$pb.TagNumber(7)
  set pinUpdate(ServerPinUpdate v) {
    setField(7, v);
  }

  @$pb.TagNumber(7)
  $core.bool hasPinUpdate() => $_has(6);
  @$pb.TagNumber(7)
  void clearPinUpdate() => clearField(7);
  @$pb.TagNumber(7)
  ServerPinUpdate ensurePinUpdate() => $_ensure(6);

  @$pb.TagNumber(8)
  ServerError get error => $_getN(7);
  @$pb.TagNumber(8)
  set error(ServerError v) {
    setField(8, v);
  }

  @$pb.TagNumber(8)
  $core.bool hasError() => $_has(7);
  @$pb.TagNumber(8)
  void clearError() => clearField(8);
  @$pb.TagNumber(8)
  ServerError ensureError() => $_ensure(7);

  @$pb.TagNumber(9)
  ServerPong get pong => $_getN(8);
  @$pb.TagNumber(9)
  set pong(ServerPong v) {
    setField(9, v);
  }

  @$pb.TagNumber(9)
  $core.bool hasPong() => $_has(8);
  @$pb.TagNumber(9)
  void clearPong() => clearField(9);
  @$pb.TagNumber(9)
  ServerPong ensurePong() => $_ensure(8);

  @$pb.TagNumber(10)
  ServerFriendRequestUpdate get friendRequestUpdate => $_getN(9);
  @$pb.TagNumber(10)
  set friendRequestUpdate(ServerFriendRequestUpdate v) {
    setField(10, v);
  }

  @$pb.TagNumber(10)
  $core.bool hasFriendRequestUpdate() => $_has(9);
  @$pb.TagNumber(10)
  void clearFriendRequestUpdate() => clearField(10);
  @$pb.TagNumber(10)
  ServerFriendRequestUpdate ensureFriendRequestUpdate() => $_ensure(9);

  @$pb.TagNumber(11)
  ServerRoomCreated get roomCreated => $_getN(10);
  @$pb.TagNumber(11)
  set roomCreated(ServerRoomCreated v) {
    setField(11, v);
  }

  @$pb.TagNumber(11)
  $core.bool hasRoomCreated() => $_has(10);
  @$pb.TagNumber(11)
  void clearRoomCreated() => clearField(11);
  @$pb.TagNumber(11)
  ServerRoomCreated ensureRoomCreated() => $_ensure(10);

  @$pb.TagNumber(12)
  ServerBanned get userBanned => $_getN(11);
  @$pb.TagNumber(12)
  set userBanned(ServerBanned v) {
    setField(12, v);
  }

  @$pb.TagNumber(12)
  $core.bool hasUserBanned() => $_has(11);
  @$pb.TagNumber(12)
  void clearUserBanned() => clearField(12);
  @$pb.TagNumber(12)
  ServerBanned ensureUserBanned() => $_ensure(11);
}
