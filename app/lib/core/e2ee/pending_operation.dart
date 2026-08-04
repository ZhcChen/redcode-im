import 'dart:convert';
import 'dart:typed_data';

const _pendingOperationVersion = 1;

enum E2eePendingOperationKind { bootstrap, application }

class E2eePendingControl {
  const E2eePendingControl({
    required this.id,
    required this.epoch,
    required this.membershipRevision,
    required this.contentType,
    required this.envelope,
    this.recipientDeviceId,
  });

  final String id;
  final int epoch;
  final int membershipRevision;
  final String contentType;
  final Uint8List envelope;
  final String? recipientDeviceId;

  Map<String, Object?> toJson() => {
    'id': id,
    'epoch': epoch,
    'membership_revision': membershipRevision,
    'content_type': contentType,
    'envelope': base64Encode(envelope),
    'recipient_device_id': recipientDeviceId,
  };
}

class E2eePendingOperation {
  const E2eePendingOperation({
    required this.kind,
    required this.roomId,
    required this.nextState,
    required this.senderDeviceId,
    required this.idempotencyKey,
    this.controls = const [],
    this.ciphertext,
    this.epoch,
    this.controlMessageId,
  });

  final E2eePendingOperationKind kind;
  final String roomId;
  final Uint8List nextState;
  final String senderDeviceId;
  final String idempotencyKey;
  final List<E2eePendingControl> controls;
  final Uint8List? ciphertext;
  final int? epoch;
  final String? controlMessageId;

  Uint8List encode() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'version': _pendingOperationVersion,
        'kind': kind.name,
        'room_id': roomId,
        'next_state': base64Encode(nextState),
        'sender_device_id': senderDeviceId,
        'idempotency_key': idempotencyKey,
        'controls': controls
            .map((item) => item.toJson())
            .toList(growable: false),
        'ciphertext': ciphertext == null ? null : base64Encode(ciphertext!),
        'epoch': epoch,
        'control_message_id': controlMessageId,
      }),
    ),
  );

  static E2eePendingOperation decode(List<int> value) {
    final data = jsonDecode(utf8.decode(value));
    if (data is! Map<String, dynamic> ||
        data['version'] != _pendingOperationVersion ||
        data['kind'] is! String ||
        data['room_id'] is! String ||
        (data['room_id'] as String).trim().isEmpty ||
        data['next_state'] is! String ||
        data['sender_device_id'] is! String ||
        (data['sender_device_id'] as String).trim().isEmpty ||
        data['idempotency_key'] is! String ||
        (data['idempotency_key'] as String).trim().isEmpty ||
        data['controls'] is! List) {
      throw const FormatException('E2EE 待处理操作格式无效');
    }
    final kind = E2eePendingOperationKind.values
        .where((item) => item.name == data['kind'])
        .firstOrNull;
    if (kind == null) throw const FormatException('E2EE 待处理操作类型无效');
    final controls = (data['controls'] as List)
        .map((raw) {
          if (raw is! Map ||
              raw['id'] is! String ||
              (raw['id'] as String).trim().isEmpty ||
              raw['epoch'] is! int ||
              (raw['epoch'] as int) <= 0 ||
              raw['membership_revision'] is! int ||
              (raw['membership_revision'] as int) <= 0 ||
              raw['content_type'] is! String ||
              (raw['content_type'] != 'commit' &&
                  raw['content_type'] != 'welcome') ||
              raw['envelope'] is! String ||
              (raw['recipient_device_id'] != null &&
                  raw['recipient_device_id'] is! String)) {
            throw const FormatException('E2EE 待处理控制消息格式无效');
          }
          return E2eePendingControl(
            id: raw['id'] as String,
            epoch: raw['epoch'] as int,
            membershipRevision: raw['membership_revision'] as int,
            contentType: raw['content_type'] as String,
            envelope: base64Decode(raw['envelope'] as String),
            recipientDeviceId: raw['recipient_device_id'] as String?,
          );
        })
        .toList(growable: false);
    final ciphertext = data['ciphertext'];
    if (ciphertext != null && ciphertext is! String ||
        data['epoch'] != null && data['epoch'] is! int ||
        data['control_message_id'] != null &&
            data['control_message_id'] is! String) {
      throw const FormatException('E2EE 待处理操作字段格式无效');
    }
    final operation = E2eePendingOperation(
      kind: kind,
      roomId: data['room_id'] as String,
      nextState: base64Decode(data['next_state'] as String),
      senderDeviceId: data['sender_device_id'] as String,
      idempotencyKey: data['idempotency_key'] as String,
      controls: controls,
      ciphertext: ciphertext == null
          ? null
          : base64Decode(ciphertext as String),
      epoch: data['epoch'] as int?,
      controlMessageId: data['control_message_id'] as String?,
    );
    operation._validateShape();
    return operation;
  }

  void _validateShape() {
    if (nextState.isEmpty ||
        (kind == E2eePendingOperationKind.bootstrap &&
            (controls.isEmpty || ciphertext != null || epoch != null)) ||
        (kind == E2eePendingOperationKind.application &&
            (controls.isNotEmpty ||
                ciphertext == null ||
                ciphertext!.isEmpty ||
                epoch == null ||
                controlMessageId == null))) {
      throw const FormatException('E2EE 待处理操作字段组合无效');
    }
  }
}
