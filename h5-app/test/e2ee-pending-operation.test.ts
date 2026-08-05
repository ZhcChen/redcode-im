import { describe, expect, it } from 'vitest';

import {
  decodePendingOperation,
  encodePendingOperation,
  type E2eePendingOperation,
} from '@/e2ee/pending-operation';

describe('E2EE pending operation codec', () => {
  it('round-trips a rekey operation with previous state', () => {
    const operation: E2eePendingOperation = {
      kind: 'rekey',
      roomId: 'room-a',
      nextState: new Uint8Array([2]),
      senderDeviceId: 'device-a',
      idempotencyKey: 'rekey-1',
      controls: [{
        id: 'commit-3',
        epoch: 3,
        membershipRevision: 2,
        contentType: 'commit',
        envelope: new Uint8Array([9]),
      }],
      previousState: new Uint8Array([1]),
    };

    const decoded = decodePendingOperation(encodePendingOperation(operation));

    expect(decoded.kind).toBe('rekey');
    expect(Array.from(decoded.nextState)).toEqual([2]);
    expect(Array.from(decoded.previousState ?? [])).toEqual([1]);
    expect(decoded.controls[0]).toMatchObject({
      id: 'commit-3',
      epoch: 3,
      membershipRevision: 2,
      contentType: 'commit',
    });
  });

  it('rejects rekey operations without previous state', () => {
    const operation: E2eePendingOperation = {
      kind: 'rekey',
      roomId: 'room-a',
      nextState: new Uint8Array([2]),
      senderDeviceId: 'device-a',
      idempotencyKey: 'rekey-1',
      controls: [{
        id: 'commit-3',
        epoch: 3,
        membershipRevision: 2,
        contentType: 'commit',
        envelope: new Uint8Array([9]),
      }],
    };

    expect(() => decodePendingOperation(encodePendingOperation(operation))).toThrow(
      '待处理操作字段组合无效',
    );
  });
});
