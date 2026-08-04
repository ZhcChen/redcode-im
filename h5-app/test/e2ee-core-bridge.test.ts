import { describe, expect, it, vi } from 'vitest';

import {
  E2eeCoreBridge,
  E2eeCoreUnavailableError,
  type E2eeCoreModule,
} from '@/e2ee/core-bridge';

const emptyState = new Uint8Array([
  0x52, 0x43, 0x53, 0x54,
  0x00, 0x01,
  0x00, 0x00, 0x00, 0x00,
]);

const createCore = (overrides: Partial<E2eeCoreModule> = {}): E2eeCoreModule => ({
  initialize: vi.fn(async () => {}),
  protocolVersion: () => 1,
  newProtocolState: () => emptyState.slice(),
  validateProtocolState: (state) => state[0] === 0x52,
  ...overrides,
});

describe('E2eeCoreBridge', () => {
  it('initializes once and returns state validated by the shared core', async () => {
    const core = createCore();
    const bridge = new E2eeCoreBridge(core);

    expect(await bridge.newProtocolState()).toEqual(emptyState);
    expect(await bridge.validateProtocolState(emptyState)).toBe(true);
    expect(core.initialize).toHaveBeenCalledOnce();
  });

  it('fails closed for an unsupported protocol version', async () => {
    const bridge = new E2eeCoreBridge(createCore({ protocolVersion: () => 2 }));

    await expect(bridge.initialize()).rejects.toBeInstanceOf(E2eeCoreUnavailableError);
  });

  it('does not expose state rejected by the shared core', async () => {
    const bridge = new E2eeCoreBridge(createCore({ validateProtocolState: () => false }));

    await expect(bridge.newProtocolState()).rejects.toBeInstanceOf(E2eeCoreUnavailableError);
  });
});
