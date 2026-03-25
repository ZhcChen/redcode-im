import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./smoke",
  timeout: 30_000,
  fullyParallel: false,
  retries: 0,
  workers: 1,
  webServer: {
    command: "bun run build && bunx vite preview --host 127.0.0.1 --port 4173 --strictPort",
    url: "http://127.0.0.1:4173",
    timeout: 120 * 1000,
    reuseExistingServer: !process.env.CI,
  },
  use: {
    baseURL: "http://127.0.0.1:4173",
    browserName: "chromium",
    channel: "chrome",
    headless: true,
  },
});
