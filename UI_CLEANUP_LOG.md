# UI Cleanup Log

Date: 2026-06-25

## Scope

Cleaned up and validated the Super Admin responsive web experience with Playwright coverage across mobile, mobile landscape, tablet, desktop, and desktop zoom. No backend APIs or core business flows were changed.

## Changes Made

- Added a test-only E2E mock mode behind `SMA_E2E_MOCKS=true` so responsive checks can run without live API timing or network failures. The normal app still uses the live backend by default.
- Added Playwright responsive coverage for login, dashboard, schools, needs attention, and account managers routes.
- Validated routes using the app's hash URL format (`/#/super-admin/...`) so tests match the real browser behavior.
- Fixed Super Admin route startup behavior by allowing browser deep links to be respected instead of always forcing the default dashboard on boot.
- Fixed a desktop Schools filter overflow by making dropdown values expand inside their available width and ellipsize long labels.
- Confirmed mobile layouts render without horizontal overflow for the primary Super Admin sections.

## Screenshots

- Mobile login after validation: `docs/ui-cleanup/screenshots/after-mobile-login.png`
- Mobile schools after validation: `docs/ui-cleanup/screenshots/after-mobile-schools.png`
- Mobile account managers after validation: `docs/ui-cleanup/screenshots/after-mobile-account-managers.png`
- Desktop dashboard after validation: `docs/ui-cleanup/screenshots/after-desktop-dashboard.png`
- Desktop schools after overflow fix: `docs/ui-cleanup/screenshots/after-desktop-schools.png`

## Validation

- `flutter analyze`: no issues found
- `flutter test`: all tests passed
- `npm run test:e2e`: 15 passed
  - Mobile: login, dashboard, primary routes
  - Mobile landscape: login, dashboard, primary routes
  - Tablet: login, dashboard, primary routes
  - Desktop: login, dashboard, primary routes
  - Desktop zoom/high-DPI style check: login, dashboard, primary routes

## Notes

- Flutter web paints much of the UI to canvas in this setup, so Playwright cannot reliably assert visible text with DOM selectors. The suite therefore combines route checks, rendered-pixel checks, screenshot capture, and horizontal overflow detection.
- The first mobile login load can be white while the Flutter development server finishes its cold startup. The test now performs one reload before failing, and still fails if the app remains blank.
- No critical UI issue remains open from this cleanup pass.
