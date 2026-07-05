import { defineConfig, devices } from '@playwright/test';

const port = Number(process.env.H5_APP_E2E_PORT ?? 8016);
const baseURL = process.env.H5_APP_BASE_URL ?? `http://127.0.0.1:${port}`;
const apiBaseURL = process.env.H5_APP_API_BASE_URL ?? process.env.VITE_API_BASE_URL ?? 'http://127.0.0.1:8010';
const wsURL = process.env.H5_APP_WS_URL ?? process.env.VITE_WS_URL ?? 'ws://127.0.0.1:8010/ws';
const browserChannel = process.env.PLAYWRIGHT_BROWSER_CHANNEL ?? 'chrome';

export default defineConfig({
  testDir: './test/e2e',
  timeout: 60_000,
  expect: {
    timeout: 10_000,
  },
  fullyParallel: false,
  retries: process.env.CI ? 2 : 0,
  reporter: [['list']],
  use: {
    baseURL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  webServer: {
    command: `VITE_API_BASE_URL="${apiBaseURL}" VITE_WS_URL="${wsURL}" bun run dev -- --host 127.0.0.1 --port ${port}`,
    url: baseURL,
    timeout: 120_000,
    reuseExistingServer: !process.env.CI,
  },
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        ...(browserChannel ? { channel: browserChannel } : {}),
      },
    },
  ],
});
