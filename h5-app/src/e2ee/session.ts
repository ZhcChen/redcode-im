import { e2eeCoreBridge, type E2eeCoreBridge } from '@/e2ee/core-bridge';

export type E2eeCommandOperation =
  | 'initialize'
  | 'generate-key-package'
  | 'create-group'
  | 'add-member'
  | 'join-group'
  | 'encrypt'
  | 'decrypt'
  | 'public-material'
  | 'process-commit'
  | 'remove-member'
  | 'sign-device-approval'
  | 'list-members';

const OPERATION: Record<E2eeCommandOperation, number> = {
  initialize: 1,
  'generate-key-package': 2,
  'create-group': 3,
  'add-member': 4,
  'join-group': 5,
  encrypt: 6,
  decrypt: 7,
  'public-material': 8,
  'process-commit': 9,
  'remove-member': 10,
  'sign-device-approval': 11,
  'list-members': 12,
};

export class E2eeCommandError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'E2eeCommandError';
  }
}

export class E2eeCommandResult {
  constructor(readonly fields: Uint8Array[]) {}

  field(index: number): Uint8Array {
    const value = this.fields[index];
    if (!value) throw new E2eeCommandError('E2EE 核心响应字段缺失');
    return value;
  }

  epoch(index: number): bigint {
    const value = this.field(index);
    if (value.length !== 8) throw new E2eeCommandError('E2EE 核心 epoch 格式无效');
    return new DataView(value.buffer, value.byteOffset, value.byteLength).getBigUint64(0, false);
  }
}

export class E2eeSession {
  constructor(private readonly core: Pick<E2eeCoreBridge, 'executeCommand'> = e2eeCoreBridge) {}

  async execute(operation: E2eeCommandOperation, fields: Uint8Array[]): Promise<E2eeCommandResult> {
    if (fields.length > 8) throw new E2eeCommandError('E2EE 核心命令字段过多');
    const size = 8 + fields.reduce((total, field) => total + 4 + field.length, 0);
    const request = new Uint8Array(size);
    request.set(new TextEncoder().encode('RCCQ'));
    request.set([0, 1, OPERATION[operation], fields.length], 4);
    const view = new DataView(request.buffer);
    let offset = 8;
    for (const field of fields) {
      view.setUint32(offset, field.length, false);
      offset += 4;
      request.set(field, offset);
      offset += field.length;
    }
    return E2eeSession.decodeResponse(await this.core.executeCommand(request));
  }

  initialize(deviceIdentity: string) {
    return this.execute('initialize', [new TextEncoder().encode(deviceIdentity)]);
  }

  initializeWithRoot(deviceIdentity: string, rootPublicKey?: Uint8Array) {
    return this.execute('initialize', [
      new TextEncoder().encode(deviceIdentity),
      ...(rootPublicKey ? [rootPublicKey] : []),
    ]);
  }

  generateKeyPackage(state: Uint8Array) {
    return this.execute('generate-key-package', [state]);
  }

  createGroup(state: Uint8Array, roomId: string) {
    return this.execute('create-group', [state, new TextEncoder().encode(roomId)]);
  }

  addMember(state: Uint8Array, roomId: string, keyPackage: Uint8Array) {
    return this.execute('add-member', [state, new TextEncoder().encode(roomId), keyPackage]);
  }

  joinGroup(state: Uint8Array, welcome: Uint8Array) {
    return this.execute('join-group', [state, welcome]);
  }

  encrypt(state: Uint8Array, roomId: string, plaintext: Uint8Array) {
    return this.execute('encrypt', [state, new TextEncoder().encode(roomId), plaintext]);
  }

  decrypt(state: Uint8Array, roomId: string, ciphertext: Uint8Array) {
    return this.execute('decrypt', [state, new TextEncoder().encode(roomId), ciphertext]);
  }

  publicMaterial(state: Uint8Array) {
    return this.execute('public-material', [state]);
  }

  processCommit(state: Uint8Array, roomId: string, commit: Uint8Array) {
    return this.execute('process-commit', [state, new TextEncoder().encode(roomId), commit]);
  }

  removeMember(state: Uint8Array, roomId: string, identity: string) {
    return this.execute('remove-member', [
      state,
      new TextEncoder().encode(roomId),
      new TextEncoder().encode(identity),
    ]);
  }

  signDeviceApproval(state: Uint8Array, payload: Uint8Array) {
    return this.execute('sign-device-approval', [state, payload]);
  }

  listMembers(state: Uint8Array, roomId: string) {
    return this.execute('list-members', [state, new TextEncoder().encode(roomId)]);
  }

  static decodeResponse(response: Uint8Array): E2eeCommandResult {
    if (response.length < 8 || new TextDecoder().decode(response.subarray(0, 4)) !== 'RCCR') {
      throw new E2eeCommandError('E2EE 核心响应头无效');
    }
    if (response[4] !== 0 || response[5] !== 1) {
      throw new E2eeCommandError('E2EE 核心响应版本不支持');
    }
    const view = new DataView(response.buffer, response.byteOffset, response.byteLength);
    let offset = 8;
    const fields: Uint8Array[] = [];
    for (let index = 0; index < response[7]!; index += 1) {
      if (offset + 4 > response.length) throw new E2eeCommandError('E2EE 核心响应已截断');
      const length = view.getUint32(offset, false);
      offset += 4;
      if (offset + length > response.length) throw new E2eeCommandError('E2EE 核心响应已截断');
      fields.push(response.slice(offset, offset + length));
      offset += length;
    }
    if (offset !== response.length) throw new E2eeCommandError('E2EE 核心响应包含多余数据');
    if (response[6] !== 0) {
      throw new E2eeCommandError(fields[0] ? new TextDecoder().decode(fields[0]) : 'E2EE 核心命令失败');
    }
    return new E2eeCommandResult(fields);
  }
}

export const e2eeSession = new E2eeSession();
