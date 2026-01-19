import { defineConfig } from '@playwright/test';

const baseURL = process.env.ADMIN_BASE_URL || 'http://localhost:8011';
const isCI = !!process.env.CI;

export default defineConfig({
  testDir: './playwright-tests/specs',
  timeout: 60_000,
  expect: {
    timeout: 10_000,
  },
  retries: isCI ? 1 : 0,
  reporter: [
    ['list'],
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
  ],
  outputDir: 'test-results',
  use: {
    baseURL,
    headless: true,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
});
