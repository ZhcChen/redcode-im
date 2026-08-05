const PENDING_OPERATION_VERSION = 1;

export type E2eePendingOperationKind = 'bootstrap' | 'application' | 'inbound' | 'rekey';

export interface E2eePendingControl {
  id: string;
  epoch: number;
  membershipRevision: number;
  contentType: 'commit' | 'welcome';
  envelope: Uint8Array;
  recipientDeviceId?: string;
  sequenceNo?: number;
}

export interface E2eePendingOperation {
  kind: E2eePendingOperationKind;
  roomId: string;
  nextState: Uint8Array;
  senderDeviceId: string;
  idempotencyKey: string;
  controls: E2eePendingControl[];
  ciphertext?: Uint8Array;
  epoch?: number;
  controlMessageId?: string;
  previousState?: Uint8Array;
}

export const encodePendingOperation = (operation: E2eePendingOperation) => new TextEncoder().encode(JSON.stringify({
  version: PENDING_OPERATION_VERSION,
  kind: operation.kind,
  room_id: operation.roomId,
  next_state: bytesToBase64(operation.nextState),
  sender_device_id: operation.senderDeviceId,
  idempotency_key: operation.idempotencyKey,
  controls: operation.controls.map((control) => ({
    id: control.id,
    epoch: control.epoch,
    membership_revision: control.membershipRevision,
    content_type: control.contentType,
    envelope: bytesToBase64(control.envelope),
    recipient_device_id: control.recipientDeviceId ?? null,
    sequence_no: control.sequenceNo ?? null,
  })),
  ciphertext: operation.ciphertext ? bytesToBase64(operation.ciphertext) : null,
  epoch: operation.epoch ?? null,
  control_message_id: operation.controlMessageId ?? null,
  previous_state: operation.previousState ? bytesToBase64(operation.previousState) : null,
}));

export const decodePendingOperation = (value: Uint8Array): E2eePendingOperation => {
  const data = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(value)) as Record<string, unknown>;
  if (data.version !== PENDING_OPERATION_VERSION
    || (data.kind !== 'bootstrap' && data.kind !== 'application' && data.kind !== 'inbound' && data.kind !== 'rekey')
    || typeof data.room_id !== 'string' || !data.room_id.trim()
    || typeof data.next_state !== 'string'
    || typeof data.sender_device_id !== 'string' || !data.sender_device_id.trim()
    || typeof data.idempotency_key !== 'string' || !data.idempotency_key.trim()
    || !Array.isArray(data.controls)
    || (data.ciphertext != null && typeof data.ciphertext !== 'string')
    || (data.epoch != null && !Number.isSafeInteger(data.epoch))
    || (data.control_message_id != null && typeof data.control_message_id !== 'string')
    || (data.previous_state != null && typeof data.previous_state !== 'string')) {
    throw new Error('E2EE 待处理操作格式无效');
  }
  const controls = data.controls.map(parseControl);
  const operation: E2eePendingOperation = {
    kind: data.kind,
    roomId: data.room_id,
    nextState: base64ToBytes(data.next_state),
    senderDeviceId: data.sender_device_id,
    idempotencyKey: data.idempotency_key,
    controls,
    ciphertext: data.ciphertext == null ? undefined : base64ToBytes(data.ciphertext),
    epoch: data.epoch == null ? undefined : Number(data.epoch),
    controlMessageId: data.control_message_id == null ? undefined : String(data.control_message_id),
    previousState: data.previous_state == null ? undefined : base64ToBytes(data.previous_state),
  };
  validateShape(operation);
  return operation;
};

const parseControl = (value: unknown): E2eePendingControl => {
  if (!isRecord(value)
    || typeof value.id !== 'string' || !value.id.trim()
    || !Number.isSafeInteger(value.epoch) || Number(value.epoch) <= 0
    || !Number.isSafeInteger(value.membership_revision) || Number(value.membership_revision) <= 0
    || (value.content_type !== 'commit' && value.content_type !== 'welcome')
    || typeof value.envelope !== 'string'
    || (value.recipient_device_id != null && typeof value.recipient_device_id !== 'string')
    || (value.sequence_no != null && (!Number.isSafeInteger(value.sequence_no) || Number(value.sequence_no) <= 0))) {
    throw new Error('E2EE 待处理控制消息格式无效');
  }
  return {
    id: value.id,
    epoch: Number(value.epoch),
    membershipRevision: Number(value.membership_revision),
    contentType: value.content_type,
    envelope: base64ToBytes(value.envelope),
    recipientDeviceId: value.recipient_device_id ?? undefined,
    sequenceNo: value.sequence_no == null ? undefined : Number(value.sequence_no),
  };
};

const validateShape = (operation: E2eePendingOperation) => {
  if (!operation.nextState.length
    || (operation.kind === 'bootstrap' && (!operation.controls.length || operation.ciphertext || operation.epoch != null))
    || (operation.kind === 'rekey' && (!operation.controls.length || operation.ciphertext || operation.epoch != null || !operation.previousState?.length))
    || (operation.kind === 'application' && (operation.controls.length || !operation.ciphertext?.length || operation.epoch == null || !operation.controlMessageId))
    || (operation.kind === 'inbound' && (!operation.controls.length || operation.controls.some((item) => item.sequenceNo == null) || operation.ciphertext || operation.epoch != null || operation.controlMessageId))) {
    throw new Error('E2EE 待处理操作字段组合无效');
  }
};

const bytesToBase64 = (value: Uint8Array) => {
  let binary = '';
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary);
};
const base64ToBytes = (value: string) => Uint8Array.from(atob(value), (char) => char.charCodeAt(0));
const isRecord = (value: unknown): value is Record<string, unknown> => Boolean(value && typeof value === 'object' && !Array.isArray(value));
