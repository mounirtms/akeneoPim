const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  testMatch: '*.spec.js',
  timeout: 60000,
  fullyParallel: false,
  workers: 1,
  use: {
    baseURL: 'https://pim.technostationery.com',
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
    headless: true,
    ignoreHTTPSErrors: true,
    viewport: { width: 1920, height: 1080 },
  },
  projects: [
    {
      name: 'chromium',
      use: { browserName: 'chromium' },
    },
  ],
  reporter: [
    ['list'],
    ['json', { outputFile: 'test-results/report.json' }],
  ],
});
