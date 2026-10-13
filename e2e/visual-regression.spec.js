const { expect, test } = require('@playwright/test');
const { installPlatformApiMocks } = require('./support/platform-api-mocks');

const supportedProjects = new Set(['mobile', 'tablet']);

const superAdminSession = {
  accessToken: 'visual-regression-token',
  refreshToken: 'preview',
  firstName: 'System',
  lastName: 'Administrator',
  userName: 'admin@sma.test',
  mustChangePassword: false,
  requiresDateOfBirth: false,
  isAccountManager: true,
  role: 'SUPER_ADMIN',
  customSchoolId: '',
  schoolName: '',
  userId: 1,
};

const screenshotOptions = {
  animations: 'disabled',
  caret: 'hide',
  fullPage: true,
  scale: 'css',
  maxDiffPixelRatio: 0.001,
};

function routeUrl(path) {
  return `/#${path}`;
}

async function seedSession(page) {
  await page.addInitScript((session) => {
    window.localStorage.setItem('sma.auth.session', JSON.stringify(session));
  }, superAdminSession);
}

async function waitForFlutter(page) {
  const hasFlutterHost = () =>
    document.querySelector('flutter-view') ||
    document.querySelector('flt-glass-pane') ||
    document.querySelector('flt-semantics-placeholder');

  for (let attempt = 0; attempt < 2; attempt += 1) {
    try {
      await page.waitForFunction(hasFlutterHost, null, { timeout: 25_000 });
      break;
    } catch (error) {
      if (attempt === 1) throw error;
      await page.reload({ waitUntil: 'domcontentloaded' });
    }
  }

  await page.evaluate(async () => {
    if (document.fonts) await document.fonts.ready;
  });
  await page.waitForTimeout(1600);
}

async function openPlatformRoute(page, path) {
  await seedSession(page);
  await page.goto(routeUrl(path));
  await expect(page).toHaveURL(
    new RegExp(routeUrl(path).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')),
  );
  await waitForFlutter(page);
}

test.describe('mobile and tablet visual regression', () => {
  let apiMocks;

  test.beforeEach(async ({ page }, testInfo) => {
    test.skip(
      !supportedProjects.has(testInfo.project.name),
      'Visual baselines are intentionally scoped to mobile and tablet.',
    );
    await page.emulateMedia({ reducedMotion: 'reduce' });
    apiMocks = await installPlatformApiMocks(page);
  });

  test.afterEach(() => {
    expect(apiMocks.unexpectedRequests).toEqual([]);
  });

  test('login screen', async ({ page }) => {
    await page.goto(routeUrl('/login'));
    await waitForFlutter(page);
    await expect(page).toHaveScreenshot('login.png', screenshotOptions);
  });

  test('username recovery screen', async ({ page }) => {
    await page.goto(routeUrl('/recover-username'));
    await waitForFlutter(page);
    await expect(page).toHaveScreenshot(
      'username-recovery.png',
      screenshotOptions,
    );
  });

  test('password reset screen', async ({ page }) => {
    await page.goto(routeUrl('/reset-password'));
    await waitForFlutter(page);
    await expect(page).toHaveScreenshot(
      'password-reset.png',
      screenshotOptions,
    );
  });

  test('account activation confirmation screen', async ({ page }) => {
    await page.goto(routeUrl('/activate/e2e-token'));
    await waitForFlutter(page);
    await expect(page).toHaveScreenshot(
      'account-activation-confirmation.png',
      screenshotOptions,
    );
  });

  test('populated super admin dashboard', async ({ page }) => {
    await openPlatformRoute(page, '/super-admin');
    await expect(page).toHaveScreenshot(
      'super-admin-dashboard.png',
      screenshotOptions,
    );
  });

  test('populated schools list', async ({ page }) => {
    await openPlatformRoute(page, '/super-admin/schools');
    await expect(page).toHaveScreenshot(
      'super-admin-schools.png',
      screenshotOptions,
    );
  });

  test('populated account managers list', async ({ page }) => {
    await openPlatformRoute(page, '/super-admin/account-managers');
    await expect(page).toHaveScreenshot(
      'super-admin-account-managers.png',
      screenshotOptions,
    );
  });

  test('navigation drawer open state', async ({ page }) => {
    await openPlatformRoute(page, '/super-admin');
    await page.mouse.click(48, 32);
    await page.waitForTimeout(450);
    await expect(page).toHaveScreenshot(
      'super-admin-navigation-drawer.png',
      screenshotOptions,
    );
  });
});
