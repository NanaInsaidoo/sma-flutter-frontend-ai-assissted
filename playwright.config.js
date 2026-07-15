const { defineConfig, devices } = require('@playwright/test');

const port = process.env.SMA_E2E_PORT || '4184';
const baseURL = process.env.SMA_E2E_BASE_URL || `http://127.0.0.1:${port}`;

module.exports = defineConfig({
  testDir: './e2e',
  timeout: 70_000,
  expect: {
    timeout: 10_000,
  },
  fullyParallel: false,
  workers: 1,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL,
    actionTimeout: 10_000,
    navigationTimeout: 30_000,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  webServer: {
    command: [
      'flutter',
      'run',
      '-d',
      'web-server',
      '--web-hostname',
      '127.0.0.1',
      '--web-port',
      port,
      '--dart-define',
      'SMA_E2E_MOCKS=true',
    ].join(' '),
    url: baseURL,
    timeout: 120_000,
    reuseExistingServer: process.env.SMA_E2E_REUSE_SERVER === 'true',
  },
  projects: [
    {
      name: 'mobile',
      use: {
        ...devices['Pixel 7'],
        browserName: 'chromium',
        viewport: { width: 393, height: 852 },
        deviceScaleFactor: 2.75,
      },
    },
    {
      name: 'mobile-landscape',
      use: {
        ...devices['Pixel 7 landscape'],
        browserName: 'chromium',
        viewport: { width: 852, height: 393 },
        deviceScaleFactor: 2.75,
      },
    },
    {
      name: 'tablet',
      use: {
        ...devices['iPad Pro 11'],
        browserName: 'chromium',
        viewport: { width: 834, height: 1194 },
      },
    },
    {
      name: 'desktop',
      use: {
        viewport: { width: 1440, height: 960 },
        deviceScaleFactor: 1,
      },
    },
    {
      name: 'desktop-zoom',
      use: {
        viewport: { width: 1280, height: 720 },
        deviceScaleFactor: 1.25,
      },
    },
  ],
});
