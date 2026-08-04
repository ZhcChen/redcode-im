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
});
