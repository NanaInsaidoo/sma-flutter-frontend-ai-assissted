# Responsive QA Checkpoint

Update this file at the end of every bounded work session. It is the first file to read when resuming the audit.

## Current branch

`feature/responsive-mobile-tablet-fixes`

## Completed commits

- `e344f0f` — responsive navigation and mobile/tablet layout fixes
- `b93f9d5` — initial Playwright mobile/tablet visual regression coverage

## Verified state

- Flutter analysis: clean.
- Flutter test suite: 607 passed.
- Initial responsive Playwright suite: 26 passed across mobile/tablet categories.
- Initial visual-regression suite: 10 passed across 5 states and 2 devices.
- Git working tree was clean before the durable QA planning files were added.

## Coverage summary

- Primary surfaces in matrix: 40.
- Fully approved visual states: Login and Platform open-drawer state.
- Partially covered Platform surfaces: Overview, Schools, Needs Attention, and Account Managers.
- School Admin, Guardian, and remaining public flows: pending browser audit.

## Current phase

Phase 0 — Foundation and inventory.

## Exact next action

Complete Phase 1 in this order:

1. Username recovery and password reset.
2. Account activation states.
3. Platform Needs Attention populated visuals.
4. Platform onboarding list and resume flow.
5. School creation, school detail, account manager detail, and platform audit.

After Phase 1, update this checkpoint before starting School Admin navigation coverage.

## Known implementation notes

- Playwright runs Flutter web on port 4184 with `SMA_E2E_MOCKS=true`.
- API responses are currently intercepted in `e2e/support/platform-api-mocks.js`.
- Visual snapshots use CSS-pixel scale, animations disabled, hidden carets, and a 0.1% changed-pixel limit.
- Snapshot baselines currently use Playwright's macOS (`darwin`) naming. CI must either run the same baseline environment or intentionally add its own reviewed baselines.
- Flutter accessibility semantics can be enabled by invoking the hidden `flt-semantics-placeholder`, but reliable menu navigation still needs a reusable helper or explicit test hooks.
