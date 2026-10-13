# Full Responsive UI/UX QA Plan

## Objective

Audit every user-facing screen and meaningful nested state in the SMA web app on mobile and tablet, fix responsive defects, and leave repeatable automated coverage that prevents regressions.

This plan is the durable source of truth for the work. Do not rely on chat history for scope or progress. At the start of every work session, read this file together with `SCREEN_MATRIX.md`, `ISSUES.md`, and `CHECKPOINT.md`.

## Scope model

The app currently has:

- 40 primary user-facing surfaces in the initial product inventory.
- 53 Flutter widget classes explicitly named `*Screen`.
- Additional tabs, details, drawers, dialogs, forms, empty states, error states, and role-dependent variants.

The inventory is allowed to grow. Finding another user-facing state adds a row to the matrix; it does not silently expand an existing row.

### What counts as complete

A primary screen is complete only when:

1. It opens with deterministic data for every materially different permitted role.
2. It is checked at the standard mobile and tablet viewports.
3. It has no horizontal page overflow, clipped controls, or overlapping fixed elements.
4. Text, images, tables, forms, touch targets, drawers, dialogs, and popovers have been reviewed.
5. At least one stable visual baseline exists for each materially different layout.
6. Important interactions and responsive transformations are automated.
7. Findings and fixes are recorded in `ISSUES.md`.

A nested state is complete when it has the same checks appropriate to that state. Examples include a student profile, an admission form step, a table converted to cards, a dialog with validation errors, or an open navigation drawer.

## Device matrix

| Category | Viewport | Required use |
|---|---:|---|
| Compact mobile | 360 × 800 | Overflow and minimum-width stress checks |
| Standard mobile | 393 × 852 | Required browser visual baseline |
| Tablet portrait | 834 × 1194 | Required browser visual baseline |
| Tablet landscape | 1194 × 834 | Required for dense tables, forms, and split layouts |

Phone and tablet browser checks use Chromium first. Safari/WebKit and Firefox are a final compatibility pass after the primary responsive defects are fixed.

## Role matrix

Test only roles that can legitimately open a screen, but do not assume one role represents all layouts.

- Super Admin
- Super Account Manager
- Account Manager
- School Administrator / Headmaster
- Teacher
- Bursar
- Guardian

When the same screen changes materially by role, each variant receives its own matrix entry or explicit variant checklist.

## Test layers

### 1. Inventory and static inspection

- Confirm the screen exists in `SCREEN_MATRIX.md`.
- Record its entry route or navigation path, permitted roles, nested views, and API dependencies.
- Search for fixed widths/heights, desktop-only rows, wide tables, unbounded overlays, and undersized controls.

### 2. Flutter widget and interaction tests

- Use repository fakes for deeply nested screens and complex workflows.
- Test compact width and tablet width directly.
- Assert no Flutter overflow exceptions.
- Assert important responsive transformations, sorting, form validation, and dialog behavior.

### 3. Playwright browser checks

- Enter through the real app shell and real navigation whenever practical.
- Intercept APIs with deterministic fixtures; never depend on the live backend for visual baselines.
- Check horizontal overflow and rendered-content density.
- Disable animation and caret rendering before comparison.
- Use CSS-pixel screenshots and a maximum changed-pixel ratio of 0.1%.
- Save failure screenshots, diffs, and traces.

### 4. Human aesthetic review

For every approved baseline, review:

- Visual hierarchy and balance
- Spacing rhythm and alignment
- Type size, wrapping, and line height
- Color contrast and state clarity
- Density of cards, tables, and forms
- Empty/error/loading-state quality
- Touch target size and proximity
- Cropping, aspect ratio, and image quality

Playwright detects change; it does not decide whether a design looks good. A baseline is approved only after this review.

## Determinism rules

- Use fixed names, counts, statuses, dates, and identifiers.
- Mock all API calls used by a visual test.
- Record unexpected API requests and fail the test rather than silently showing an error state.
- Wait for Flutter, fonts, and required mocked responses before taking screenshots.
- Do not baseline transient skeletons unless the skeleton itself is the state under test.
- Keep test data realistic enough to exercise long names, statuses, wrapping, and dense content.

## Severity rules

| Severity | Definition |
|---|---|
| Critical | A screen or required action cannot be used on the target device. |
| High | Major content is hidden, overlapping, unreadable, or inaccessible. |
| Medium | The screen works but has a significant responsive or usability defect. |
| Low | Cosmetic inconsistency with limited usability impact. |

## Work phases

### Phase 0 — Foundation and inventory

- [x] Create the responsive feature branch.
- [x] Add initial responsive browser smoke coverage.
- [x] Add initial mobile/tablet visual-regression infrastructure.
- [x] Create a durable QA plan, screen matrix, issue log, and checkpoint.
- [ ] Finish nested-state discovery for every primary surface.
- [x] Make unexpected mocked API calls visible and actionable.

### Phase 1 — Public access and platform administration

- [x] Login visual baseline.
- [x] Platform overview, Schools, Account Managers, and open drawer baselines.
- [x] Account activation initial confirmation state.
- [x] Username recovery initial state.
- [x] Password reset initial state.
- [ ] Platform onboarding list and resume flow.
- [ ] Needs Attention visual states.
- [ ] School creation and school detail.
- [ ] Account manager detail.
- [ ] Platform Audit & Activity.
- [ ] Complete all three platform-role variants.

### Phase 2 — School Admin shell and direct navigation

- [ ] Make all 24 primary School Admin destinations reliably reachable in browser tests.
- [ ] Validate the accordion navigation, header, drawer, role visibility, and back behavior.
- [ ] Add mobile/tablet smoke checks for every destination before deeper visuals.

### Phase 3 — People workflows

- [ ] Admissions and admission flow.
- [ ] Students and student profile.
- [ ] Student and staff attendance.
- [ ] Households and guardians.
- [ ] Staff list, onboarding, profile tabs, and authorisations.
- [ ] Personal and management leave.

### Phase 4 — Academic workflows

- [ ] Classes, grade, stream, subject configuration, and teacher classes.
- [ ] Assessments, evaluation management, and evaluation workflow.
- [ ] Final reports.
- [ ] Term review and teacher/headmaster/bursar closure variants.

### Phase 5 — Finance and operations

- [ ] Payroll.
- [ ] All Fees & Requirements tabs and detail workflows.
- [ ] All School Shop pages and reconciliation states.
- [ ] Expenses, petty cash, requisitions, approvals, reports, and ledger details.

### Phase 6 — Oversight, settings, and guardian

- [ ] Incidents.
- [ ] Reports library.
- [ ] School Audit & Activity.
- [ ] Settings hub and all settings destinations.
- [ ] Calendar and event dialogs.
- [ ] Guardian portal and child/detail states.

### Phase 7 — Cross-cutting verification

- [ ] Compact-mobile stress pass.
- [ ] Tablet-landscape pass for high-density screens.
- [ ] Keyboard-only and screen-reader semantics checks.
- [ ] Text scaling and browser zoom checks.
- [ ] Slow-loading, empty, error, and long-content states.
- [ ] WebKit and Firefox compatibility pass.

### Phase 8 — Final audit report

- [ ] Update every matrix row to complete or document an explicit blocker.
- [ ] Publish the requested screen/device issue table.
- [ ] Publish Critical-to-Low priorities and suggested fixes.
- [ ] List ship-ready screens.
- [ ] Run the full Flutter suite, analysis, responsive browser suite, and visual suite.

## Phase delivery protocol

Every phase or bounded product area ends with:

1. Updated `SCREEN_MATRIX.md` statuses.
2. Updated `ISSUES.md` entries.
3. Updated `CHECKPOINT.md` with the exact next action.
4. Relevant source fixes and tests.
5. Visual baselines reviewed manually.
6. `flutter analyze` and proportionate Flutter tests.
7. Playwright comparison run without snapshot-update mode.
8. One focused Git commit with a descriptive message.

## Commands

```sh
flutter analyze
flutter test
npm run test:e2e
npm run test:e2e:visual
npm run test:e2e:visual:update
```

Snapshot update mode records an intentional visual change; it is never evidence that the comparison passed. Always follow it with `npm run test:e2e:visual`.

## Final exit criteria

- 100% of primary matrix rows pass mobile and tablet layout checks.
- All discovered nested states are either tested or explicitly documented with a reason.
- No unresolved Critical or High responsive defects.
- Stable primary layouts have approved visual baselines.
- Required forms, tables, dialogs, drawers, and role variants have interaction coverage.
- The full audit report uses the requested format and accurately distinguishes automated coverage from human review.
