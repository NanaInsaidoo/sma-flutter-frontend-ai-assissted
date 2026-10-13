const { defineConfig, devices } = require('@playwright/test');
const base = require('./playwright.config');

module.exports = defineConfig({
  ...base,
  projects: [
    {
      name: 'mobile-firefox',
      use: {
        ...devices['Desktop Firefox'],
        browserName: 'firefox',
        viewport: { width: 393, height: 852 },
      },
    },
    {
      name: 'tablet-firefox',
      use: {
        ...devices['Desktop Firefox'],
        browserName: 'firefox',
        viewport: { width: 834, height: 1194 },
      },
    },
    {
      name: 'mobile-webkit',
      use: {
        ...devices['Desktop Safari'],
        browserName: 'webkit',
        viewport: { width: 393, height: 852 },
      },
    },
    {
      name: 'tablet-webkit',
      use: {
        ...devices['Desktop Safari'],
        browserName: 'webkit',
        viewport: { width: 834, height: 1194 },
      },
    },
  ],
});
