import { beforeEach, describe, expect, it, vi } from 'vitest';

import type { E2eeDeviceProfile } from '@/e2ee/device-profile';
import { deviceApprovalPayload, E2eeDeviceManager } from '@/e2ee/device-manager';
import { E2eeCommandResult } from '@/e2ee/session';

const profile: E2eeDeviceProfile = {
  deviceId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  deviceLabel: 'Browser',
  registered: true,
  keyPackagePublished: true,
  deviceStatus: 'active',
  lastControlSequences: {},
  lastCommitMessageIds: {},
};

const targetDevice = {
  id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  deviceLabel: 'New Browser',
  protocolVersion: 1,
  credentialFingerprint: btoa(String.fromCharCode(...new Uint8Array(32).fill(7))),
  status: 'pending_approval' as const,
  approvedByDeviceId: null,
  approvedAt: null,
  revokedAt: null,
  createdAt: '2026-08-04T00:00:00.000Z',
};

describe('E2EE device manager', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('signs the Rust-compatible approval payload and calls approve API', async () => {
    const storage = {
      read: vi.fn(async () => new Uint8Array([1])),
      readDeviceProfile: vi.fn(async () => structuredClone(profile)),
    };
    const core = {
      signDeviceApproval: vi.fn(async () => new E2eeCommandResult([new Uint8Array(64).fill(9)])),
    };
    const api = {
      listDevices: vi.fn(),
      approveDevice: vi.fn(async () => ({ ...targetDevice, status: 'active' as const })),
      revokeDevice: vi.fn(),
    };
    const manager = new E2eeDeviceManager(storage, core, api);

    const approved = await manager.approveDevice('cccccccc-cccc-cccc-cccc-cccccccccccc', targetDevice);

    expect(core.signDeviceApproval).toHaveBeenCalledOnce();
    const [state, payload] = core.signDeviceApproval.mock.calls[0] as unknown as [Uint8Array, Uint8Array];
    expect(Array.from(state)).toEqual([1]);
    expect(Array.from(payload.slice(0, DEVICE_APPROVAL_DOMAIN.length))).toEqual(
      Array.from(new TextEncoder().encode(DEVICE_APPROVAL_DOMAIN)),
    );
    expect(api.approveDevice).toHaveBeenCalledWith('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', {
      approverDeviceId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      signature: expect.any(String),
    });
    expect(approved.status).toBe('active');
  });

  it('refuses to approve from a pending device', async () => {
    const storage = {
      read: vi.fn(),
      readDeviceProfile: vi.fn(async () => structuredClone({
        ...profile,
        deviceStatus: 'pending_approval' as const,
      })),
    };
    const api = {
      listDevices: vi.fn(),
      approveDevice: vi.fn(),
      revokeDevice: vi.fn(),
    };
    const manager = new E2eeDeviceManager(storage, {
      signDeviceApproval: vi.fn(),
    }, api);

    await expect(manager.approveDevice('cccccccc-cccc-cccc-cccc-cccccccccccc', targetDevice)).rejects.toThrow(
      '待批准设备不能批准其他设备',
    );
    expect(api.approveDevice).not.toHaveBeenCalled();
  });

  it('delegates list and revoke to the MLS API', async () => {
    const api = {
      listDevices: vi.fn(async () => [targetDevice]),
      approveDevice: vi.fn(),
      revokeDevice: vi.fn(async () => ({ ...targetDevice, status: 'revoked' as const })),
    };
    const manager = new E2eeDeviceManager({
      read: vi.fn(),
      readDeviceProfile: vi.fn(),
    }, { signDeviceApproval: vi.fn() }, api);

    await expect(manager.listDevices()).resolves.toEqual([targetDevice]);
    await expect(manager.revokeDevice('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')).resolves.toMatchObject({
      id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      status: 'revoked',
    });
    expect(api.revokeDevice).toHaveBeenCalledWith('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
  });

  it('builds the approval payload byte-for-byte with the Rust contract', () => {
    const payload = deviceApprovalPayload(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      'cccccccc-cccc-cccc-cccc-cccccccccccc',
      1,
      new Uint8Array([1, 2, 3]),
    );
    const expected = concatBytes(
      new TextEncoder().encode(DEVICE_APPROVAL_DOMAIN),
      hexBytes('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'),
      hexBytes('bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'),
      hexBytes('cccccccccccccccccccccccccccccccc'),
      new Uint8Array([0, 1]),
      new Uint8Array([0, 3]),
      new Uint8Array([1, 2, 3]),
    );
    expect(Array.from(payload)).toEqual(Array.from(expected));
  });
});

const DEVICE_APPROVAL_DOMAIN = 'redcode-im/e2ee/device-approval/v1\0';

const concatBytes = (...parts: Uint8Array[]) => {
  const output = new Uint8Array(parts.reduce((total, part) => total + part.length, 0));
  let offset = 0;
  for (const part of parts) {
    output.set(part, offset);
    offset += part.length;
  }
  return output;
};

const hexBytes = (hex: string) => {
  const bytes = new Uint8Array(hex.length / 2);
  for (let index = 0; index < bytes.length; index += 1) {
    bytes[index] = Number.parseInt(hex.slice(index * 2, index * 2 + 2), 16);
  }
  return bytes;
};
