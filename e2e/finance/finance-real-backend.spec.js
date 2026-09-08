const { test, expect } = require('@playwright/test');

const username = process.env.SMA_FINANCE_E2E_USERNAME;
const password = process.env.SMA_FINANCE_E2E_PASSWORD;
const mutationsEnabled = process.env.SMA_FINANCE_E2E_MUTATIONS === 'true';

test.skip(!username || !password, 'Set the finance E2E credentials to run live-backend tests.');

async function enableFlutterAccessibility(page) {
  await page.waitForSelector('flt-semantics-placeholder');
  await page.locator('flt-semantics-placeholder').evaluate((element) => element.click());
}

async function login(page) {
  await page.goto('/#/login');
  await enableFlutterAccessibility(page);
  await page.waitForTimeout(300);
  const usernameField = page.getByRole('textbox').nth(0);
  const passwordField = page.getByRole('textbox').nth(1);
  await usernameField.click();
  await usernameField.press('ControlOrMeta+A');
  await usernameField.pressSequentially(username);
  await passwordField.click();
  await passwordField.press('ControlOrMeta+A');
  await passwordField.pressSequentially(password);
  await page.getByText('Sign In', { exact: true }).click();
  await expect(page.locator('body')).toContainText(/Good (morning|afternoon|evening),/);
}

async function openFinance(page) {
  for (
    let attempt = 0;
    attempt < 12 &&
    (await page.getByText('Expenses & Petty Cash', { exact: true }).count()) === 0;
    attempt += 1
  ) {
    await page.mouse.move(100, 850);
    await page.mouse.wheel(0, 600);
    await page.waitForTimeout(100);
  }
  await page.getByText('Expenses & Petty Cash', { exact: true }).click();
  await expect(page.getByText('Overview', { exact: true })).toBeVisible();
}

test.beforeEach(async ({ page }) => {
  await login(page);
  await openFinance(page);
});

test('loads every finance workspace from the live backend', async ({ page }) => {
  await expect(page.locator('body')).toContainText('FLOAT BALANCE');
  await expect(page.locator('body')).not.toContainText('Unable to load expenses and petty cash');

  await page.getByText('Requisitions', { exact: true }).click();
  await expect(page.locator('body')).toContainText('REQUESTED / APPROVED');
  await expect(page.locator('body')).toContainText('FUNDING');

  await page.getByText('School Expenses', { exact: true }).click();
  await expect(page.locator('body')).toContainText('FUNDING / CHANNEL');

  await page.getByText('Petty Cash', { exact: true }).click();
  await expect(page.getByText('Float & expenses', { exact: true })).toBeVisible();
  await expect(page.getByText('Reconciliations', { exact: true })).toBeVisible();
  await expect(page.getByText('Financial follow-ups', { exact: true })).toBeVisible();

  await page.getByText('Approvals', { exact: true }).click();
  await expect(page.getByText(/approval/i).first()).toBeVisible();
});

test('requester can create and cancel a top-up with an audit note', async ({ page }) => {
  test.skip(!mutationsEnabled, 'Set SMA_FINANCE_E2E_MUTATIONS=true on disposable finance data.');

  await page.getByText('Petty Cash', { exact: true }).click();
  await page.getByText('Request top-up', { exact: true }).click();
  await page.getByRole('textbox').nth(0).fill('1');
  await page.getByRole('textbox').nth(1).fill('Automated UI cancellation verification');

  await page.getByRole('button', { name: 'Approver' }).click({ force: true });
  await page.keyboard.press('ArrowDown');
  await page.keyboard.press('Enter');
  await page.waitForTimeout(500);
  await page.getByText('Review request', { exact: true }).click();
  await page.getByText('Submit request', { exact: true }).click();

  await expect(page.getByText('Request top-up', { exact: true })).toBeVisible();
  await page.getByText('View all', { exact: true }).first().click({ force: true });
  const pendingRequest = page.getByRole('row').filter({ hasText: 'Pending' });
  await expect(pendingRequest).toHaveCount(1);
  await pendingRequest.getByRole('button').click({ force: true });
  await expect(page.getByText('Cancel request', { exact: true })).toBeVisible();

  await page.getByText('Cancel request', { exact: true }).click();
  await page.getByRole('textbox').fill('Cancelled by the automated UI verification');
  await page.getByText('Cancel request', { exact: true }).last().click();

  await expect(page.locator('body')).toContainText('Status Cancelled');
  await expect(page.locator('body')).toContainText(
    'Cancelled by the automated UI verification',
  );
});
