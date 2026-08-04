import { expect, test } from '@playwright/test';

test('shared E2EE WASM core initializes and validates protocol state', async ({ page }) => {
  await page.goto('/login');

  const result = await page.evaluate(async () => {
    const modulePath = '/src/e2ee/core-bridge.ts';
    const module = await import(/* @vite-ignore */ modulePath) as {
      createNewE2eeProtocolState(): Promise<Uint8Array>;
      validateE2eeProtocolState(state: Uint8Array): Promise<boolean>;
    };
    const state = await module.createNewE2eeProtocolState();
    const valid = await module.validateE2eeProtocolState(state);
    state[0] = 0;
    const damaged = await module.validateE2eeProtocolState(state);
    return {
      valid,
      damaged,
      magic: Array.from(state.slice(1, 4)),
    };
  });

  expect(result.valid).toBe(true);
  expect(result.damaged).toBe(false);
  expect(result.magic).toEqual([0x43, 0x53, 0x54]);
});
