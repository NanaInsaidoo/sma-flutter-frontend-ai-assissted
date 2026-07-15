const { expect, test } = require('@playwright/test');
const { PNG } = require('pngjs');

const baseSession = {
  accessToken: 'e2e-token',
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

function routeUrl(path) {
  return `/#${path}`;
}

function sessionForRole(role) {
  if (role === 'SUPER_ACCOUNT_MANAGER') {
    return {
      ...baseSession,
      firstName: 'Super',
      lastName: 'Manager',
      userName: 'super.manager@sma.test',
      role,
      userId: 2,
    };
  }

  if (role === 'ACCOUNT_MANAGER') {
    return {
      ...baseSession,
      firstName: 'Account',
      lastName: 'Manager',
      userName: 'manager@sma.test',
      role,
      userId: 3,
    };
  }

  return baseSession;
}

async function seedSession(page, role = 'SUPER_ADMIN') {
  await page.addInitScript((value) => {
    window.localStorage.setItem('sma.auth.session', JSON.stringify(value));
  }, sessionForRole(role));
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
  await page.waitForTimeout(1600);
}

async function renderedPixelStats(page) {
  const image = PNG.sync.read(await page.screenshot());
  let nonWhite = 0;
  let saturated = 0;

  for (let index = 0; index < image.data.length; index += 4) {
    const r = image.data[index];
    const g = image.data[index + 1];
    const b = image.data[index + 2];
    const a = image.data[index + 3];
    if (a === 0) continue;
    if (r < 245 || g < 245 || b < 245) nonWhite++;
    if (Math.max(r, g, b) - Math.min(r, g, b) > 35) saturated++;
  }

  return {
    width: image.width,
    height: image.height,
    nonWhiteRatio: nonWhite / (image.width * image.height),
    saturatedRatio: saturated / (image.width * image.height),
  };
}

async function expectRenderedContent(page, minNonWhiteRatio = 0.03) {
  await waitForFlutter(page);
  const stats = await renderedPixelStats(page);
  expect(stats.nonWhiteRatio, JSON.stringify(stats, null, 2)).toBeGreaterThan(
    minNonWhiteRatio,
  );
}

async function expectNoHorizontalOverflow(page) {
  await page.waitForTimeout(400);
  const overflow = await page.evaluate(() => {
    const doc = document.documentElement;
    const body = document.body;
    const widthDelta = Math.max(
      0,
      doc.scrollWidth - doc.clientWidth,
      body.scrollWidth - window.innerWidth,
    );
    const offenders = Array.from(document.querySelectorAll('body *'))
      .filter((element) => {
        const rect = element.getBoundingClientRect();
        return rect.width > 1 && (rect.left < -2 || rect.right > window.innerWidth + 2);
      })
      .slice(0, 8)
      .map((element) => ({
        tag: element.tagName,
        left: Math.round(element.getBoundingClientRect().left),
        right: Math.round(element.getBoundingClientRect().right),
      }));
    return { widthDelta, offenders };
  });
  expect(overflow, JSON.stringify(overflow, null, 2)).toEqual({
    widthDelta: 0,
    offenders: [],
  });
}

async function openRoute(page, path, minNonWhiteRatio, role = 'SUPER_ADMIN') {
  await seedSession(page, role);
  await page.goto(routeUrl(path));
  await expect(page).toHaveURL(
    new RegExp(routeUrl(path).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')),
  );
  await expectRenderedContent(page, minNonWhiteRatio);
  await expectNoHorizontalOverflow(page);
}

const roleSuites = [
  {
    label: 'Super Admin',
    slug: 'super-admin',
    role: 'SUPER_ADMIN',
    basePath: '/super-admin',
    routes: [
      ['schools', '/super-admin/schools', 0.05],
      ['attention', '/super-admin/attention', 0.04],
      ['account-managers', '/super-admin/account-managers', 0.05],
    ],
  },
  {
    label: 'Super Account Manager',
    slug: 'super-account-manager',
    role: 'SUPER_ACCOUNT_MANAGER',
    basePath: '/super-account-manager',
    routes: [
      ['schools', '/super-account-manager/schools', 0.05],
      ['attention', '/super-account-manager/attention', 0.04],
      ['account-managers', '/super-account-manager/account-managers', 0.05],
    ],
  },
  {
    label: 'Account Manager',
    slug: 'account-manager',
    role: 'ACCOUNT_MANAGER',
    basePath: '/account-manager',
    routes: [
      ['schools', '/account-manager/schools', 0.05],
      ['attention', '/account-manager/attention', 0.04],
    ],
  },
];

test.describe('Platform responsive shell', () => {
  test('login screen renders without horizontal overflow', async ({ page }, testInfo) => {
    await page.goto(routeUrl('/login'));
    await expectRenderedContent(page, 0.08);
    await expectNoHorizontalOverflow(page);
    await page.screenshot({
      path: `e2e/screenshots/${testInfo.project.name}-login.png`,
      fullPage: true,
    });
  });

  for (const suite of roleSuites) {
    test(`${suite.label} dashboard renders without horizontal overflow`, async ({ page }, testInfo) => {
      await openRoute(page, suite.basePath, 0.08, suite.role);
      await page.screenshot({
        path: `e2e/screenshots/${testInfo.project.name}-${suite.slug}-dashboard.png`,
        fullPage: true,
      });
    });

    for (const [name, path, minNonWhiteRatio] of suite.routes) {
      test(`${suite.label} ${name} route renders cleanly`, async ({ page }, testInfo) => {
        await openRoute(page, path, minNonWhiteRatio, suite.role);
        await page.screenshot({
          path: `e2e/screenshots/${testInfo.project.name}-${suite.slug}-${name}.png`,
          fullPage: true,
        });
      });
    }
  }

  test('Account Manager direct account-managers route redirects away', async ({ page }) => {
    await seedSession(page, 'ACCOUNT_MANAGER');
    await page.goto(routeUrl('/account-manager/account-managers'));
    await waitForFlutter(page);
    await expect(page).toHaveURL(/#\/account-manager$/);
    await expectRenderedContent(page, 0.08);
    await expectNoHorizontalOverflow(page);
  });
});
