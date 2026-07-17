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

---

Date: 2026-07-15

## Scope

Expanded the responsive validation from Super Admin only to the three platform admin experiences: Super Admin, Super Account Manager, and Account Manager. The pass covered phone, phone landscape, tablet, desktop, and zoomed desktop routes.

## Changes Made

- Added role-aware Playwright coverage for Super Admin, Super Account Manager, and Account Manager dashboards.
- Added route coverage for the role-specific Schools, Needs Attention, and Account Managers sections where applicable.
- Changed the Playwright test server port to `4184` and disabled silent reuse by default so tests do not accidentally validate another app already running on the old port.
- Fixed the mobile Account Managers status filters by wrapping the chips instead of clipping them horizontally.
- Shortened the Super Account Manager mobile page title from "Account manager operations" to "Manager operations" to avoid header truncation on narrow screens.

## Validation

- `flutter analyze`: no issues found
- `npm run test:e2e`: 60 passed
  - Super Admin: dashboard, schools, needs attention, account managers
  - Super Account Manager: dashboard, schools, needs attention, account managers
  - Account Manager: dashboard, schools, needs attention
  - Breakpoints: mobile, mobile landscape, tablet, desktop, desktop zoom

## Notes

- Visual spot checks confirmed the Account Managers mobile filters now display all states without cutting off "Pending approval".
- No core functionality or backend API contracts were changed.

---

Date: 2026-07-17

## Scope

Reviewed the School Administrator admissions list and applicant review flow for routing clarity, responsive behavior, filters, and section-level editing. Live API data was used for the interaction pass.

## Changes Made

- Pending-approval applications now open the applicant review page; Draft, Approved, Rejected, and Active records open their household dashboard.
- Replaced placeholder admission filters with a working application search and class filter. Status remains controlled by the existing status tabs and the screen remains scoped to the current term.
- Added an Edit action to every displayed student application section and connected each action to the relevant step of the existing multi-step form.
- Corrected asynchronous refresh callbacks that could raise a Flutter runtime error after returning from an applicant or household screen.
- Kept filters stacked on narrow screens and inline on tablet/desktop without introducing page-level horizontal overflow.

## Validation

- `flutter analyze`: no issues found
- `flutter test --reporter compact`: 32 passed
- Live browser interaction checks passed for:
  - Pending approval to applicant review routing
  - Draft to household routing
  - Direct Medical and Student Information edit-step entry
  - Search and class filtering
  - Returning from details and refreshing the application list
- Responsive visual checks passed at 390x844, 844x390, 726px mobile/tablet, 1024x768, and 1440x1000.
- No page-level horizontal overflow was detected at the tested viewports.
- Browser console inspection showed no new application errors after the refresh fix. Flutter's development-only `dart:developer` warning remains unrelated to application behavior.

## Notes

- The standalone `npm run test:e2e` rerun was blocked before startup because the local automation approval service reached its usage limit. No test failure occurred. The changed flows were instead exercised in the live in-app browser using the same viewport sizes and overflow checks.
- The admissions endpoint rejects `ACTIVE` when it is added to the existing multi-status query. Active/enrolled students therefore remain a separate backend integration concern and were not forced through this request.
- No backend endpoint was changed.

---

Date: 2026-07-17

## Scope

Added the first desktop frontend version of physical class requirements within Fee Management. This version intentionally uses an isolated mock repository while the backend contract is designed.

## Changes Made

- Added a Class Requirements tab beside Fee Structure.
- Added a class-first setup flow: the administrator creates/selects one class, opens it, and then adds its requirements.
- Kept draft review, publishing, and guardian notification scoped to one class at a time so publishing one class cannot publish another class's changes.
- Added desktop class summary cards, class requirement cards, completion indicators, and per-class draft/published states.
- Added class item creation with common-item shortcuts, quantity, unit, estimated price per unit, calculated cash-equivalent guidance, category, due date, instructions, and optional status.
- Replaced the manual "new this term" state with an automatic "Updated" marker for items changed after a class was published. Publishing that class clears its markers and establishes the new baseline; initial items in a never-published class are not marked as updates.
- Replaced the stacked class checklist with a compact table so long requirement lists can be scanned by item, category, required quantity, due date, unit estimate, per-student total, and publication status.
- Added Edit and Delete actions to each checklist row. Edits and confirmed deletions remain class-scoped draft changes until publication; deleting an item also removes its stale mock student-progress entries.
- Added student progress tracking with received quantities, increased or reduced quantities, partial/full waivers, due-date extensions, cash-equivalent payment references, and administrative notes.
- Added student-only custom requirements.
- Added a per-class publish review that supports each guardian's default preference or explicit WhatsApp, email, SMS, phone-call, and physical-letter methods.
- Kept the mock data behind `ClassRequirementsRepository` so a live API repository can replace it without redesigning the screens.

## Validation

- `flutter analyze`: no issues found
- Focused repository and widget tests cover class creation, estimated prices, per-class publishing, waivers, receipt tracking, and class tracker navigation.
- Live desktop visual checks passed at 1280px for the overview, selected-class checklist, per-class publish action, and item form.

## Notes

- Class requirements are mock-backed in this pass by design. Existing Fee Management data remains live and unchanged.
- Publishing currently updates local mock state and records the class notification plan; it does not send messages or write to the backend yet.
- Tablet and mobile refinement is deliberately deferred until the desktop workflow is approved.
