import { defineConfig, devices } from '@playwright/test';

const port = 8020;
const baseURL = `http://127.0.0.1:${port}`;

export default defineConfig({
  testDir: './tests',
  timeout: 45_000,
  expect: { timeout: 8_000 },
  fullyParallel: false,
  retries: process.env.CI ? 1 : 0,
  reporter: [['list']],
  outputDir: 'test-results',
  use: {
    baseURL,
    headless: true,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  webServer: {
    command: `python3 -m http.server ${port} --bind 127.0.0.1`,
    url: baseURL,
    timeout: 30_000,
    reuseExistingServer: false,
  },
  projects: [
    { name: 'iphone-12-pro', use: { ...devices['Desktop Chrome'], channel: 'chrome', viewport: { width: 1440, height: 1100 } } },
    { name: 'iphone-16-pro-max', use: { ...devices['Desktop Chrome'], channel: 'chrome', viewport: { width: 1440, height: 1100 } } },
    { name: 'pixel-8-pro', use: { ...devices['Desktop Chrome'], channel: 'chrome', viewport: { width: 1440, height: 1100 } } },
  ],
});
