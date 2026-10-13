const { expect, test } = require('@playwright/test');
const { PNG } = require('pngjs');
const { installSchoolApiMocks, schoolId } = require('./support/school-api-mocks');
const { schoolAdminScreens } = require('./support/screen-catalog');
const layoutOnly = process.env.SMA_E2E_LAYOUT_ONLY === 'true';

const session = {
  accessToken: 'school-admin-e2e-token',
  refreshToken: 'preview',
  firstName: 'Nana',
  lastName: 'Mensah',
  userName: 'nana.mensah@sma.test',
  mustChangePassword: false,
  requiresDateOfBirth: false,
  isAccountManager: false,
  role: 'ADMINISTRATOR',
  roles: ['ADMINISTRATOR', 'HEADMASTER', 'BURSAR'],
  accountStatus: 'ACTIVE',
  userStatus: 'ACTIVE',
  customSchoolId: schoolId,
  schoolName: 'SMA Quality Academy',
  userId: 501,
  schoolMemberships: [],
};

const pageSlugs = {
  'ADM-001': 'dashboard',
  'ADM-002': 'approvals',
  'ADM-003': 'calendar',
  'ADM-004': 'my-leave',
  'ADM-005': 'admissions',
  'ADM-006': 'students',
  'ADM-007': 'student-attendance',
  'ADM-008': 'staff-attendance',
  'ADM-009': 'households',
  'ADM-010': 'staff',
  'ADM-011': 'leave-management',
  'ADM-012': 'classes',
  'ADM-013': 'assessments',
  'ADM-014': 'evaluations',
  'ADM-015': 'final-reports',
  'ADM-016': 'term-closure',
  'ADM-017': 'payroll',
  'ADM-018': 'fees',
  'ADM-019': 'shop',
  'ADM-020': 'expenses',
  'ADM-021': 'audit',
  'ADM-022': 'incidents',
  'ADM-023': 'reports',
  'ADM-024': 'settings',
};

async function seedSession(page) {
  await page.addInitScript((value) => {
    window.localStorage.setItem('sma.auth.session', JSON.stringify(value));
  }, session);
}

async function waitForFlutter(page) {
  const hostReady = () =>
    document.querySelector('flutter-view') ||
    document.querySelector('flt-glass-pane') ||
    document.querySelector('flt-semantics-placeholder');
  for (let attempt = 0; attempt < 2; attempt += 1) {
    try {
      await page.waitForFunction(hostReady, null, { timeout: 30_000 });
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

async function renderedPixelStats(page) {
  const image = PNG.sync.read(await page.screenshot());
  let nonWhite = 0;
  for (let index = 0; index < image.data.length; index += 4) {
    const r = image.data[index];
    const g = image.data[index + 1];
    const b = image.data[index + 2];
    const a = image.data[index + 3];
    if (a !== 0 && (r < 245 || g < 245 || b < 245)) nonWhite += 1;
  }
  return { ratio: nonWhite / (image.width * image.height) };
}

async function expectNoHorizontalOverflow(page) {
  const result = await page.evaluate(() => {
    const doc = document.documentElement;
    const body = document.body;
    return Math.max(
      0,
      doc.scrollWidth - doc.clientWidth,
      body.scrollWidth - window.innerWidth,
    );
  });
  expect(result).toBe(0);
}

async function expectNoRenderedErrorState(page) {
  await page.evaluate(() => {
    document.querySelector('flt-semantics-placeholder')?.click();
  });
  const knownErrors = page.getByText(
    /Unable to load|Something went wrong|An unexpected error occurred|Try again later/i,
  );
  await expect(knownErrors).toHaveCount(0);
}

test.describe('School Admin responsive catalogue', () => {
  let mocks;
  let flutterErrors;

  test.beforeEach(async ({ page }) => {
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
    mocks = await installSchoolApiMocks(page);
    await seedSession(page);
  });

  for (const screen of schoolAdminScreens) {
    test(`${screen.id} ${screen.name} fits the viewport`, async ({ page }) => {
      const slug = pageSlugs[screen.id];
      await page.goto(`/#/school-admin?page=${slug}`);
      await waitForFlutter(page);
      await expect(page).toHaveURL(new RegExp(`school-admin\\?page=${slug}`));
      await expectNoHorizontalOverflow(page);
      await expectNoRenderedErrorState(page);
      const stats = await renderedPixelStats(page);
      expect(stats.ratio).toBeGreaterThan(0.025);
      expect(flutterErrors, flutterErrors.join('\n')).toEqual([]);
      if (!layoutOnly) {
        await expect(page).toHaveScreenshot(`${screen.id.toLowerCase()}-${slug}.png`, {
          animations: 'disabled',
          caret: 'hide',
          fullPage: false,
          scale: 'css',
          maxDiffPixelRatio: 0.001,
        });
      }
    });
  }

  test('long navigation drawer remains usable from top to bottom', async ({ page }) => {
    await page.goto('/#/school-admin?page=dashboard');
    await waitForFlutter(page);
    await page.mouse.click(28, 24);
    await page.waitForTimeout(450);
    await expectNoHorizontalOverflow(page);
    expect(flutterErrors, flutterErrors.join('\n')).toEqual([]);
    if (!layoutOnly) {
      await expect(page).toHaveScreenshot('adm-navigation-drawer-top.png', {
        animations: 'disabled',
        caret: 'hide',
        fullPage: false,
        scale: 'css',
        maxDiffPixelRatio: 0.001,
      });
    }

    await page.mouse.move(150, 700);
    await page.mouse.wheel(0, 4000);
    await page.waitForTimeout(350);
    await expectNoHorizontalOverflow(page);
    expect(flutterErrors, flutterErrors.join('\n')).toEqual([]);
    if (!layoutOnly) {
      await expect(page).toHaveScreenshot('adm-navigation-drawer-bottom.png', {
        animations: 'disabled',
        caret: 'hide',
        fullPage: false,
        scale: 'css',
        maxDiffPixelRatio: 0.001,
      });
    }
  });

  test.afterEach(async ({}, testInfo) => {
    if (mocks.fallbackRequests.length > 0) {
      await testInfo.attach('fixture-fallback-requests', {
        body: Buffer.from([...new Set(mocks.fallbackRequests)].join('\n')),
        contentType: 'text/plain',
      });
    }
    expect(
      [...new Set(mocks.fallbackRequests)],
      'Every screen must use an explicit deterministic API fixture.',
    ).toEqual([]);
  });
});
