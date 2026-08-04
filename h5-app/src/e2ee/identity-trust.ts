const REGISTRY_VERSION = 1;
const SECURITY_CODE_DOMAIN = 'redcode-im/e2ee/security-code/v1\0';

export interface E2eeRootIdentity {
  userId: string;
  publicKey: Uint8Array;
  fingerprint: Uint8Array;
  protocolVersion: number;
}

export interface E2eeIdentityTrustRecord {
  trusted: E2eeRootIdentity;
  trustedAt: string;
  pending?: E2eeRootIdentity;
  changedAt?: string;
}

export type E2eeIdentityTrustDecision = 'first-use-trusted' | 'trusted' | 'identity-changed';

export class E2eeIdentityNotTrustedError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'E2eeIdentityNotTrustedError';
  }
}

export interface E2eeIdentityTrustStore {
  readRecords(accountId: string): Promise<Record<string, E2eeIdentityTrustRecord>>;
  writeRecords(accountId: string, records: Record<string, E2eeIdentityTrustRecord>): Promise<void>;
  deleteRecords(accountId: string): Promise<void>;
}

export class E2eeIdentityTrustManager {
  constructor(
    private readonly store: E2eeIdentityTrustStore,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async observe(accountId: string, identity: E2eeRootIdentity): Promise<E2eeIdentityTrustDecision> {
    validateIdentity(identity);
    const records = await this.store.readRecords(accountId);
    const existing = records[identity.userId];
    if (!existing) {
      records[identity.userId] = { trusted: identity, trustedAt: this.now().toISOString() };
      await this.store.writeRecords(accountId, records);
      return 'first-use-trusted';
    }
    if (sameIdentity(existing.trusted, identity)) return 'trusted';
    records[identity.userId] = {
      trusted: existing.trusted,
      trustedAt: existing.trustedAt,
      pending: identity,
      changedAt: existing.changedAt ?? this.now().toISOString(),
    };
    await this.store.writeRecords(accountId, records);
    return 'identity-changed';
  }

  async record(accountId: string, targetUserId: string): Promise<E2eeIdentityTrustRecord | undefined> {
    return (await this.store.readRecords(accountId))[targetUserId];
  }

  async requireTrusted(accountId: string, targetUserId: string): Promise<E2eeIdentityTrustRecord> {
    const existing = await this.record(accountId, targetUserId);
    if (!existing) throw new E2eeIdentityNotTrustedError('联系人 E2EE 身份尚未验证');
    if (existing.pending) {
      throw new E2eeIdentityNotTrustedError('联系人 E2EE 身份已变化，核验安全码后才能发送');
    }
    return existing;
  }

  async retrust(accountId: string, targetUserId: string): Promise<E2eeIdentityTrustRecord> {
    const records = await this.store.readRecords(accountId);
    const existing = records[targetUserId];
    if (!existing?.pending) throw new Error('没有待确认的 E2EE 身份变化');
    const accepted = { trusted: existing.pending, trustedAt: this.now().toISOString() };
    records[targetUserId] = accepted;
    await this.store.writeRecords(accountId, records);
    return accepted;
  }

  static encodeRegistry(records: Record<string, E2eeIdentityTrustRecord>): Uint8Array {
    const serialized = Object.fromEntries(
      Object.keys(records).sort().map((key) => [key, serializeRecord(records[key]!)]),
    );
    return new TextEncoder().encode(JSON.stringify({ version: REGISTRY_VERSION, records: serialized }));
  }

  static decodeRegistry(data: Uint8Array): Record<string, E2eeIdentityTrustRecord> {
    const decoded = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(data)) as {
      version?: unknown;
      records?: unknown;
    };
    if (decoded.version !== REGISTRY_VERSION || !isRecord(decoded.records)) {
      throw new Error('E2EE 信任记录格式无效');
    }
    return Object.fromEntries(
      Object.entries(decoded.records).map(([key, value]) => [key, parseRecord(value)]),
    );
  }

  static async securityCode(
    first: E2eeRootIdentity,
    second: E2eeRootIdentity,
    cryptoProvider: Crypto = globalThis.crypto,
  ): Promise<string> {
    validateIdentity(first);
    validateIdentity(second);
    if (!cryptoProvider?.subtle) throw new Error('WebCrypto 不可用');
    const identities = [first, second].sort((left, right) => (
      left.userId < right.userId ? -1 : left.userId > right.userId ? 1 : 0
    ));
    const parts: Uint8Array[] = [new TextEncoder().encode(SECURITY_CODE_DOMAIN)];
    for (const identity of identities) {
      parts.push(lengthPrefixed(new TextEncoder().encode(identity.userId)));
      parts.push(lengthPrefixed(identity.fingerprint));
    }
    const digest = new Uint8Array(await cryptoProvider.subtle.digest('SHA-256', concat(parts)));
    const hex = Array.from(digest, (byte) => byte.toString(16).padStart(2, '0')).join('').toUpperCase();
    return hex.match(/.{4}/g)!.join(' ');
  }
}

const serializeIdentity = (identity: E2eeRootIdentity) => ({
  user_id: identity.userId,
  public_key: bytesToBase64(identity.publicKey),
  fingerprint: bytesToBase64(identity.fingerprint),
  protocol_version: identity.protocolVersion,
});

const parseIdentity = (value: unknown): E2eeRootIdentity => {
  if (!isRecord(value)) throw new Error('E2EE 根身份格式无效');
  const identity = {
    userId: String(value.user_id ?? ''),
    publicKey: base64ToBytes(String(value.public_key ?? '')),
    fingerprint: base64ToBytes(String(value.fingerprint ?? '')),
    protocolVersion: Number(value.protocol_version),
  };
  validateIdentity(identity);
  return identity;
};

const serializeRecord = (record: E2eeIdentityTrustRecord) => ({
  trusted: serializeIdentity(record.trusted),
  trusted_at: record.trustedAt,
  pending: record.pending ? serializeIdentity(record.pending) : null,
  changed_at: record.changedAt ?? null,
});

const parseRecord = (value: unknown): E2eeIdentityTrustRecord => {
  if (!isRecord(value) || typeof value.trusted_at !== 'string') {
    throw new Error('E2EE 信任记录格式无效');
  }
  return {
    trusted: parseIdentity(value.trusted),
    trustedAt: value.trusted_at,
    pending: value.pending == null ? undefined : parseIdentity(value.pending),
    changedAt: typeof value.changed_at === 'string' ? value.changed_at : undefined,
  };
};

const validateIdentity = (identity: E2eeRootIdentity) => {
  if (!identity.userId.trim() || !identity.publicKey.length || identity.fingerprint.length < 16 || identity.protocolVersion !== 1) {
    throw new Error('E2EE 根身份无效');
  }
};

const sameIdentity = (left: E2eeRootIdentity, right: E2eeRootIdentity) =>
  left.userId === right.userId
  && left.protocolVersion === right.protocolVersion
  && bytesEqual(left.publicKey, right.publicKey)
  && bytesEqual(left.fingerprint, right.fingerprint);

const bytesEqual = (left: Uint8Array, right: Uint8Array) => {
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) difference |= left[index]! ^ right[index]!;
  return difference === 0;
};

const lengthPrefixed = (value: Uint8Array) => {
  if (value.length > 0xffff) throw new Error('安全码字段过长');
  return concat([new Uint8Array([value.length >> 8, value.length & 0xff]), value]);
};

const concat = (parts: Uint8Array[]) => {
  const output = new Uint8Array(parts.reduce((sum, item) => sum + item.length, 0));
  let offset = 0;
  for (const part of parts) {
    output.set(part, offset);
    offset += part.length;
  }
  return output;
};

const bytesToBase64 = (value: Uint8Array) => btoa(String.fromCharCode(...value));
const base64ToBytes = (value: string) => Uint8Array.from(atob(value), (char) => char.charCodeAt(0));
const isRecord = (value: unknown): value is Record<string, unknown> => Boolean(value && typeof value === 'object' && !Array.isArray(value));
