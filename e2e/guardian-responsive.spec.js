const { expect, test } = require('@playwright/test');
const { PNG } = require('pngjs');
const { guardianScreens } = require('./support/screen-catalog');
const { installGuardianApiMocks } = require('./support/guardian-api-mocks');
const layoutOnly = process.env.SMA_E2E_LAYOUT_ONLY === 'true';

const supportedProjects = new Set([
  'compact-mobile',
  'mobile',
  'tablet',
  'tablet-landscape',
  'mobile-firefox',
  'tablet-firefox',
  'mobile-webkit',
  'tablet-webkit',
  'desktop-200-percent-reflow',
]);
const session = {
  accessToken: 'guardian-e2e-token',
  refreshToken: 'preview',
  firstName: 'Akosua',
  lastName: 'Mensah',
  userName: 'akosua.mensah@sma.test',
  mustChangePassword: false,
  requiresDateOfBirth: false,
  isAccountManager: false,
  role: 'GUARDIAN',
  roles: ['GUARDIAN'],
  accountStatus: 'ACTIVE',
  userStatus: 'ACTIVE',
  customSchoolId: 'SMA-QA-001',
  schoolName: 'SMA Quality Academy',
  userId: 701,
  schoolMemberships: [
    {
      schoolId: 'SMA-QA-001',
      schoolName: 'SMA Quality Academy',
      membershipType: 'GUARDIAN',
      roles: ['GUARDIAN'],
    },
  ],
};

async function waitForFlutter(page) {
  const ready = () =>
    document.querySelector('flutter-view') ||
    document.querySelector('flt-glass-pane') ||
    document.querySelector('flt-semantics-placeholder');
  for (let attempt = 0; attempt < 2; attempt += 1) {
    try {
      await page.waitForFunction(ready, null, { timeout: 30_000 });
      break;
    } catch (error) {
      if (attempt === 1) throw error;
      await page.reload({ waitUntil: 'domcontentloaded' });
    }
  }
  await page.evaluate(async () => {
    if (document.fonts) await document.fonts.ready;
  });
  await page.waitForTimeout(1800);
}

async function nonWhiteRatio(page) {
  const image = PNG.sync.read(await page.screenshot());
  let pixels = 0;
  for (let index = 0; index < image.data.length; index += 4) {
    if (
      image.data[index + 3] !== 0 &&
      (image.data[index] < 245 || image.data[index + 1] < 245 || image.data[index + 2] < 245)
    ) pixels += 1;
  }
  return pixels / (image.width * image.height);
}

test.describe('Guardian responsive catalogue', () => {
  let mocks;
  let flutterErrors;

  test.beforeEach(async ({ page }, testInfo) => {
    test.skip(!supportedProjects.has(testInfo.project.name), 'Guardian baselines cover phone and tablet.');
    await page.emulateMedia({ reducedMotion: 'reduce' });
    flutterErrors = [];
    page.on('console', (message) => {
      const text = message.text();
      if (
        text.includes('A RenderFlex overflowed') ||
        text.includes('Another exception was thrown') ||
        text.includes('TypeError:') ||
        text.includes('EXCEPTION CAUGHT BY')
      ) {
        flutterErrors.push(text);
      }
    });
    page.on('pageerror', (error) => {
      if (!error.message.includes('web_entrypoint.dart')) {
        flutterErrors.push(`Page error: ${error.message}`);
      }
    });
    mocks = await installGuardianApiMocks(page);
    await page.addInitScript((value) => {
      window.localStorage.setItem('sma.auth.session', JSON.stringify(value));
    }, session);
  });

  for (const screen of guardianScreens) {
    test(`${screen.id} ${screen.name} fits the viewport`, async ({ page }) => {
      await page.goto(`/#${screen.path}`);
      await waitForFlutter(page);
      const overflow = await page.evaluate(() => Math.max(
        0,
        document.documentElement.scrollWidth - document.documentElement.clientWidth,
        document.body.scrollWidth - window.innerWidth,
      ));
      expect(overflow).toBe(0);
      await page.evaluate(() => {
        document.querySelector('flt-semantics-placeholder')?.click();
      });
      await expect(
        page.getByText(/Unable to load|Something went wrong|An unexpected error occurred/i),
      ).toHaveCount(0);
      expect(await nonWhiteRatio(page)).toBeGreaterThan(0.025);
      expect(flutterErrors, flutterErrors.join('\n')).toEqual([]);
      if (!layoutOnly) {
        await expect(page).toHaveScreenshot(`${screen.id.toLowerCase()}.png`, {
          animations: 'disabled',
          caret: 'hide',
          fullPage: false,
          scale: 'css',
          maxDiffPixelRatio: 0.001,
        });
      }
    });
  }

  test.afterEach(() => {
    expect([...new Set(mocks.unexpectedRequests)]).toEqual([]);
  });
});
