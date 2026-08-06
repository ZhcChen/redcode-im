import { describe, expect, it, vi } from 'vitest';

import { E2eeRuntimeBootstrap } from '@/e2ee/runtime-bootstrap';

const createSubject = (mode: string) => {
  const settings = {
    fetchGeneralSettings: vi.fn().mockResolvedValue({
      messageRuntime: { contentAuditMode: mode },
    }),
  };
  const lifecycle = {
    ensureReady: vi.fn().mockResolvedValue({}),
    topUpKeyPackages: vi.fn().mockResolvedValue({ replenished: 0 }),
  };
  return { subject: new E2eeRuntimeBootstrap(settings, lifecycle), settings, lifecycle };
};

describe('E2eeRuntimeBootstrap', () => {
  it('does not initialize MLS in plaintext runtime', async () => {
    const { subject, lifecycle } = createSubject('plaintext');

    await expect(subject.ensureReady('account-1')).resolves.toBe(false);
    expect(lifecycle.ensureReady).not.toHaveBeenCalled();
    expect(lifecycle.topUpKeyPackages).not.toHaveBeenCalled();
  });

  it('initializes the device and replenishes KeyPackages in e2ee runtime', async () => {
    const { subject, lifecycle } = createSubject('e2ee');

    await expect(subject.ensureReady('account-1')).resolves.toBe(true);
    expect(lifecycle.ensureReady).toHaveBeenCalledWith('account-1', 'RedCode H5');
    expect(lifecycle.topUpKeyPackages).toHaveBeenCalledWith('account-1');
  });

  it('deduplicates concurrent initialization for the same account', async () => {
    let release!: () => void;
    const blocked = new Promise<void>((resolve) => { release = resolve; });
    const { subject, settings, lifecycle } = createSubject('e2ee');
    lifecycle.ensureReady.mockImplementation(() => blocked);

    const first = subject.ensureReady('account-1');
    const second = subject.ensureReady('account-1');
    release();

    await expect(Promise.all([first, second])).resolves.toEqual([true, true]);
    expect(settings.fetchGeneralSettings).toHaveBeenCalledTimes(1);
    expect(lifecycle.ensureReady).toHaveBeenCalledTimes(1);
  });

  it('fails closed when production device initialization fails', async () => {
    const { subject, lifecycle } = createSubject('e2ee');
    lifecycle.ensureReady.mockRejectedValue(new Error('state corrupted'));

    await expect(subject.ensureReady('account-1')).rejects.toThrow('state corrupted');
    expect(lifecycle.topUpKeyPackages).not.toHaveBeenCalled();
  });

  it('does not block Home when settings refresh fails', async () => {
    const { subject, settings, lifecycle } = createSubject('e2ee');
    settings.fetchGeneralSettings.mockRejectedValue(new Error('temporary settings failure'));

    await expect(subject.ensureReady('account-1')).resolves.toBe(false);
    expect(lifecycle.ensureReady).not.toHaveBeenCalled();
  });

  it('does not block a ready device when background KeyPackage replenishment fails', async () => {
    const { subject, lifecycle } = createSubject('e2ee');
    lifecycle.topUpKeyPackages.mockRejectedValue(new Error('temporary inventory failure'));

    await expect(subject.ensureReady('account-1')).resolves.toBe(true);
    expect(lifecycle.ensureReady).toHaveBeenCalledTimes(1);
    expect(lifecycle.topUpKeyPackages).toHaveBeenCalledTimes(1);
  });
});
