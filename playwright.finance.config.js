const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './e2e/finance',
  timeout: 45_000,
  expect: { timeout: 12_000 },
  fullyParallel: false,
  workers: 1,
  reporter: 'list',
  use: {
    baseURL: process.env.SMA_E2E_BASE_URL || 'http://127.0.0.1:4173',
    viewport: { width: 1600, height: 1000 },
    actionTimeout: 12_000,
    navigationTimeout: 30_000,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { browserName: 'chromium' } }],
});
