import { webcrypto } from 'node:crypto';

import { beforeEach, describe, expect, it, vi } from 'vitest';

import { E2eeCommandResult } from '@/e2ee/session';
import {
  e2eeMlsApiService,
  registrationMaterialFromCommand,
} from '@/services/e2ee-mls-api-service';

describe('e2eeMlsApiService', () => {
  beforeEach(() => {
    window.localStorage.setItem('redcode-h5-session', JSON.stringify({
      token: 'token-a',
      user: { id: 'account-a', username: 'alice' },
    }));
  });

  it('registers only public material returned by the shared core', async () => {
    const fetchMock = vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
      expect(body.protocol_version).toBe(1);
      expect(body).not.toHaveProperty('state');
      expect(body).not.toHaveProperty('key_package');
      return new Response('{"status":"active"}', { status: 200 });
    });
    vi.stubGlobal('fetch', fetchMock);
    const material = registrationMaterialFromCommand(new E2eeCommandResult([
      new Uint8Array([99]),
      new Uint8Array([1]),
      new Uint8Array(32).fill(2),
      new Uint8Array(32).fill(3),
      new Uint8Array([4]),
      new Uint8Array(32).fill(5),
      new Uint8Array(32).fill(6),
    ]));

    await e2eeMlsApiService.registerDevice('device-a', 'Browser', material);

    expect(fetchMock).toHaveBeenCalledOnce();
  });

  it('derives package_ref with SHA-256 before publishing', async () => {
    let payload: Record<string, unknown> = {};
    vi.stubGlobal('fetch', vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      payload = JSON.parse(String(init?.body)) as Record<string, unknown>;
      return new Response('{"inserted":1}', { status: 200 });
    }));

    await e2eeMlsApiService.publishKeyPackage(
      'device-a',
      new Uint8Array([1, 2, 3]),
      new Date('2026-08-11T00:00:00.000Z'),
      webcrypto as unknown as Crypto,
    );

    const packages = payload.packages as Record<string, unknown>[];
    expect(packages[0]?.package_ref).toBe('A5BYxvLAy0ksUzsKTRTvd8wPeKvMztUofYShogEc+4E=');
  });

  it('publishes a key package batch and returns inserted count', async () => {
    let payload: Record<string, unknown> = {};
    vi.stubGlobal('fetch', vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      payload = JSON.parse(String(init?.body)) as Record<string, unknown>;
      return new Response('{"inserted":2}', { status: 200 });
    }));

    const result = await e2eeMlsApiService.publishKeyPackages(
      'device-a',
      [new Uint8Array([1]), new Uint8Array([2])],
      new Date('2026-08-11T00:00:00.000Z'),
      webcrypto as unknown as Crypto,
    );

    expect(result.inserted).toBe(2);
    expect((payload.packages as Record<string, unknown>[]).length).toBe(2);
    expect(payload.packages).toSatisfy(
      (packages: Record<string, unknown>[]) => packages.every((item) => (
        typeof item.id === 'string'
        && typeof item.package_ref === 'string'
        && typeof item.key_package === 'string'
        && item.protocol_version === 1
      )),
    );
  });

  it('rejects empty or oversized key package batches', async () => {
    await expect(e2eeMlsApiService.publishKeyPackages(
      'device-a',
      [],
      undefined,
      webcrypto as unknown as Crypto,
    )).rejects.toThrow('批次不能为空');
    await expect(e2eeMlsApiService.publishKeyPackages(
      'device-a',
      new Array(101).fill(new Uint8Array([1])),
      undefined,
      webcrypto as unknown as Crypto,
    )).rejects.toThrow('最多 100 个');
  });

  it('fetches key package inventory with numeric bounds', async () => {
    let url = '';
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL) => {
      url = String(input);
      return new Response('{"available":3,"max_available":500}', { status: 200 });
    }));

    const inventory = await e2eeMlsApiService.fetchKeyPackageInventory('device-a');

    expect(url).toContain('/e2ee/mls/devices/device-a/key-packages');
    expect(inventory).toEqual({ available: 3, maxAvailable: 500 });
  });

  it('fails closed on malformed inventory response', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response('{"available":"x"}', { status: 200 })));

    await expect(e2eeMlsApiService.fetchKeyPackageInventory('device-a'))
      .rejects.toThrow('库存响应格式无效');
  });

  it('never sends plaintext fields to the encrypted endpoint', async () => {
    let payload: Record<string, unknown> = {};
    vi.stubGlobal('fetch', vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      payload = JSON.parse(String(init?.body)) as Record<string, unknown>;
      return new Response('{"message":{"id":"message-a"}}', { status: 200 });
    }));

    await e2eeMlsApiService.sendEncryptedMessage({
      roomId: 'room-a',
      senderDeviceId: 'device-a',
      epoch: 2,
      ciphertext: new Uint8Array([82, 67, 77, 76]),
      idempotencyKey: 'request-a',
      controlMessageId: 'control-a',
    });

    expect(payload).not.toHaveProperty('content');
    expect(payload).not.toHaveProperty('content_summary');
    expect(payload.encryption_metadata).toEqual({
      protocol: 'mls',
      version: 1,
      epoch: 2,
      sender_device_id: 'device-a',
      content_type: 'application',
      control_message_id: 'control-a',
    });
  });

  it('discovers only validated peer device material', async () => {
    const fetchMock = vi.fn(async (_input: RequestInfo | URL) => new Response(JSON.stringify([{
      id: 'device-b',
      protocol_version: 1,
      credential_fingerprint: btoa(String.fromCharCode(...new Uint8Array(32).fill(7))),
    }]), { status: 200 }));
    vi.stubGlobal('fetch', fetchMock);

    const devices = await e2eeMlsApiService.listPeerDevices('account-b');

    expect(devices[0]?.id).toBe('device-b');
    expect(devices[0]?.credentialFingerprint).toEqual(new Uint8Array(32).fill(7));
    expect(String(fetchMock.mock.calls[0]?.[0])).toContain('/identities/account-b/devices');
  });

  it('lists and consumes offline control messages in sequence', async () => {
    const fetchMock = vi.fn(async (input: RequestInfo | URL) => {
      if (String(input).includes('/consume')) {
        return new Response('{"consumed":true}', { status: 200 });
      }
      return new Response(
        '[{"id":"control-a","epoch":2,"membership_revision":1,"content_type":"commit",'
        + '"envelope":"UkNNTA==","sequence_no":7}]',
        { status: 200 },
      );
    });
    vi.stubGlobal('fetch', fetchMock);

    const controls = await e2eeMlsApiService.listControlMessages('room-a', 'device-a', 6);
    await e2eeMlsApiService.consumeControlMessage('room-a', controls[0]!.id, 'device-a');

    expect(controls[0]?.sequenceNo).toBe(7);
    expect(String(fetchMock.mock.calls[0]?.[0])).toContain('after_sequence=6');
    expect(String(fetchMock.mock.calls[1]?.[0])).toContain('/control-a/consume');
  });

  it('lists, approves and revokes devices with status validation', async () => {
    const fetchMock = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      const method = init?.method ?? 'GET';
      if (url.endsWith('/approve')) {
        return new Response(JSON.stringify(deviceRow('device-b', 'active')), { status: 200 });
      }
      if (method === 'DELETE') {
        return new Response(JSON.stringify(deviceRow('device-b', 'revoked')), { status: 200 });
      }
      return new Response(JSON.stringify([
        deviceRow('device-a', 'active'),
        deviceRow('device-b', 'pending_approval'),
      ]), { status: 200 });
    });
    vi.stubGlobal('fetch', fetchMock);

    const devices = await e2eeMlsApiService.listDevices();
    const approved = await e2eeMlsApiService.approveDevice('device-b', {
      approverDeviceId: 'device-a',
      signature: btoa(String.fromCharCode(...new Uint8Array(64))),
    });
    const revoked = await e2eeMlsApiService.revokeDevice('device-b');

    expect(devices.map((device) => device.status)).toEqual(['active', 'pending_approval']);
    expect(approved.status).toBe('active');
    expect(revoked.status).toBe('revoked');
    expect(String(fetchMock.mock.calls[1]?.[0])).toContain('/device-b/approve');
    expect(String(fetchMock.mock.calls[2]?.[0])).toContain('/e2ee/mls/devices/device-b');
  });

  it('fails closed on malformed device status', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify([
      { id: 'device-a', status: 'weird' },
    ]), { status: 200 })));

    await expect(e2eeMlsApiService.listDevices()).rejects.toThrow('设备响应格式无效');
  });
});

const deviceRow = (id: string, status: string) => ({
  id,
  device_label: 'Browser',
  protocol_version: 1,
  credential_fingerprint: btoa(String.fromCharCode(...new Uint8Array(32).fill(7))),
  status,
  approved_by_device_id: null,
  approved_at: null,
  revoked_at: null,
  created_at: '2026-08-04T00:00:00.000Z',
});
