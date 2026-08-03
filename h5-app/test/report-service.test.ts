import { beforeEach, describe, expect, it, vi } from 'vitest';
import { appEnv } from '@/config/env';
import { reportService } from '@/services/report-service';

describe('report service', () => {
  beforeEach(() => {
    appEnv.apiBaseUrl = 'http://127.0.0.1:8010';
    window.localStorage.setItem('redcode-h5-session', JSON.stringify({ token: 'token-1', user: { id: 'u1' } }));
  });

  it('uploads evidence before creating a user report', async () => {
    const calls: string[] = [];
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input); calls.push(url);
      if (url.endsWith('/reports/attachments/signature')) return new Response(JSON.stringify({ key: 'reports/u1/evidence.png', signature: { url: 'http://storage/report' } }), { status: 200 });
      if (url === 'http://storage/report') return new Response('', { status: 200 });
      if (url.endsWith('/reports')) return new Response(JSON.stringify({ report_id: 'report-1' }), { status: 200 });
      return new Response(JSON.stringify({ success: true }), { status: 200 });
    }));

    const id = await reportService.reportUser('u2', '骚扰信息', new File(['png'], 'evidence.png', { type: 'image/png' }));

    expect(id).toBe('report-1');
    expect(calls).toEqual([
      'http://127.0.0.1:8010/reports/attachments/signature', 'http://storage/report',
      'http://127.0.0.1:8010/reports/attachments/commit', 'http://127.0.0.1:8010/reports',
    ]);
  });
});
