import { describe, expect, it } from 'vitest';

import { E2eeCommandError, E2eeSession } from '@/e2ee/session';

describe('E2eeSession', () => {
  it('encodes a command and decodes typed response fields', async () => {
    let captured: Uint8Array<ArrayBufferLike> = new Uint8Array();
    const session = new E2eeSession({
      async executeCommand(command) {
        captured = command;
        return response(0, [new Uint8Array([1, 2]), new Uint8Array(8).fill(3)]);
      },
    });

    const result = await session.encrypt(
      new Uint8Array([9]),
      'room-1',
      new TextEncoder().encode('hello'),
    );

    expect(new TextDecoder().decode(captured.subarray(0, 4))).toBe('RCCQ');
    expect(captured[6]).toBe(6);
    expect(captured[7]).toBe(3);
    expect(result.field(0)).toEqual(new Uint8Array([1, 2]));
    expect(result.epoch(1)).toBe(0x0303030303030303n);
  });

  it('propagates fail-closed core errors', async () => {
    const session = new E2eeSession({
      async executeCommand() {
        return response(1, [new TextEncoder().encode('duplicate message')]);
      },
    });

    await expect(session.decrypt(new Uint8Array([1]), 'room-1', new Uint8Array([2])))
      .rejects.toThrow('duplicate message');
  });

  it('rejects truncated responses', () => {
    expect(() => E2eeSession.decodeResponse(new Uint8Array([82, 67, 67, 82])))
      .toThrow(E2eeCommandError);
  });

  it('encodes remove-member and sign-device-approval operations', async () => {
    const operations: number[] = [];
    const session = new E2eeSession({
      async executeCommand(command) {
        operations.push(command[6]);
        if (command[6] === 10) {
          return response(0, [new Uint8Array([1]), new Uint8Array([2]), new Uint8Array(8).fill(0)]);
        }
        return response(0, [new Uint8Array(64).fill(9)]);
      },
    });

    const removed = await session.removeMember(
      new Uint8Array([0]),
      'room-1',
      'account-a/device-b',
    );
    const signed = await session.signDeviceApproval(
      new Uint8Array([0]),
      new TextEncoder().encode('payload'),
    );

    expect(operations).toEqual([10, 11]);
    expect(removed.field(1)).toEqual(new Uint8Array([2]));
    expect(signed.field(0).length).toBe(64);
  });
});

const response = (status: number, fields: Uint8Array[]) => {
  const output = new Uint8Array(8 + fields.reduce((sum, field) => sum + 4 + field.length, 0));
  output.set(new TextEncoder().encode('RCCR'));
  output.set([0, 1, status, fields.length], 4);
  const view = new DataView(output.buffer);
  let offset = 8;
  for (const field of fields) {
    view.setUint32(offset, field.length, false);
    offset += 4;
    output.set(field, offset);
    offset += field.length;
  }
  return output;
};
