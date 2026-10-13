const { expect, test } = require('@playwright/test');
const { PNG } = require('pngjs');
const { installPlatformApiMocks } = require('./support/platform-api-mocks');
const { publicScreens } = require('./support/screen-catalog');

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
  await page.waitForTimeout(1600);
}

async function renderedPixelRatio(page) {
  const image = PNG.sync.read(await page.screenshot());
  let pixels = 0;
  for (let index = 0; index < image.data.length; index += 4) {
    if (
      image.data[index + 3] !== 0 &&
      (image.data[index] < 245 ||
        image.data[index + 1] < 245 ||
        image.data[index + 2] < 245)
    ) {
      pixels += 1;
    }
  }
  return pixels / (image.width * image.height);
}

test.describe('Public account responsive catalogue', () => {
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
    mocks = await installPlatformApiMocks(page);
  });

  for (const screen of publicScreens) {
    test(`${screen.id} ${screen.name} fits the viewport`, async ({ page }) => {
      await page.goto(`/#${screen.path}`);
      await waitForFlutter(page);
      const overflow = await page.evaluate(() =>
        Math.max(
          0,
          document.documentElement.scrollWidth -
            document.documentElement.clientWidth,
          document.body.scrollWidth - window.innerWidth,
        ),
      );
      expect(overflow).toBe(0);
      expect(await renderedPixelRatio(page)).toBeGreaterThan(0.025);
      expect(flutterErrors, flutterErrors.join('\n')).toEqual([]);
      await page.evaluate(() => {
        document.querySelector('flt-semantics-placeholder')?.click();
      });
      await expect(
        page.getByText(
          /Unable to load|Something went wrong|An unexpected error occurred/i,
        ),
      ).toHaveCount(0);
    });
  }

  test.afterEach(() => {
    expect([...new Set(mocks.unexpectedRequests)]).toEqual([]);
  });
});
