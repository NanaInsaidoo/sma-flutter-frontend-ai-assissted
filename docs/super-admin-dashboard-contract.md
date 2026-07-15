# Super Admin Dashboard Contract

This note documents what the Super Admin dashboard shows, which APIs feed it, and how the "Needs your attention" flow should behave.

## Dashboard APIs

When a Super Admin or Super Account Manager opens the dashboard, the frontend loads:

1. `GET /api/super-admin/dashboard`
   - Provides top-level stats.
   - Used for cards such as total schools, active schools, account managers, and pending approvals.

2. `GET /api/super-admin/dashboard/schools?page=0&size=100`
   - Provides the dashboard school cache.
   - Used for school previews, local click matching, and dashboard school counts when needed.

3. `GET /api/account-managers/?page=0&size=100`
   - Used as a fallback/source for account manager count and pending account manager approval count.

4. `GET /api/super-admin/needs-attention/summary`
   - Provides grouped attention counts.
   - Used for the Needs Attention card count, sidebar badge, and the "Needs your attention" dashboard panel.

5. `GET /api/super-admin/needs-attention?category=SCHOOL_APPROVALS&page=0&size=5`
   - Provides the first few individual schools pending approval.
   - Used by the "Schools pending approval" dashboard panel.

## Needs Your Attention Logic

The dashboard "Needs your attention" panel is a grouped summary, not a full activity feed.

It displays up to 3 grouped categories from `GET /api/super-admin/needs-attention/summary`.

Only categories with `count > 0` should be displayed. If every category is zero, show `No attention items right now.`

Do not show a `+X more` footer in this dashboard panel. The panel shows grouped categories only, so `+X more` can be confused with hidden schools or hidden action items.

Clicking a specific grouped category on the dashboard, for example `2 school approvals`, should open the full Needs Attention page with that category already selected.

Expected categories:

1. `ACCOUNT_MANAGER_APPROVALS`
   - Account manager registrations waiting for approval.
   - Click behavior: opens the account manager approvals list, then selected manager detail.

2. `SCHOOL_APPROVALS`
   - Schools submitted and waiting for review.
   - Click behavior: opens school profile/review using `customSchoolId`.

3. `ONBOARDING_STALLED`
   - Schools that have not moved to the next onboarding step after 5 days.
   - Click behavior: opens the school onboarding form at the current step.

4. `COMPLIANCE_MISSING`
   - Schools missing registration/compliance data, such as GES registration or business registration.
   - Click behavior: opens school profile, ideally focused on registration/compliance.

## Needs Attention Summary Shape

Preferred response:

```json
{
  "total": 2,
  "categories": [
    {
      "category": "SCHOOL_APPROVALS",
      "label": "School approvals",
      "count": 2,
      "priority": "HIGH"
    }
  ]
}
```

## Needs Attention Item Shape

Each individual attention item must include enough information for the frontend to open the correct record.

For school items, `entityId` must be the `customSchoolId`.

Preferred response:

```json
{
  "id": "school-MAR-XXX-C71789-approval",
  "category": "SCHOOL_APPROVALS",
  "type": "SCHOOL_APPROVAL",
  "priority": "HIGH",
  "title": "Mars ray School",
  "description": "MAR-XXX-C71789 · Greater Accra · Accra",
  "entityType": "SCHOOL",
  "entityId": "MAR-XXX-C71789",
  "status": "PENDING_APPROVAL",
  "ageInDays": 22,
  "createdAt": "2026-06-20T19:00:03",
  "actionTarget": "SCHOOL_REVIEW"
}
```

## Click Behavior

School rows should open by `customSchoolId`.

For example:

```http
GET /api/schools/MAR-XXX-C71789
```

The frontend should not depend on searching by school name before opening a school. Search may still be used as a fallback, but the reliable path is always `customSchoolId`.

## Role Differences

Super Admin and Super Account Manager:

- Can see all Needs Attention categories.
- Can manage account manager approvals.
- Can view all schools.

Account Manager:

- Should only see assigned-school attention items.
- Should not see `ACCOUNT_MANAGER_APPROVALS`.
- Should not see `SCHOOL_APPROVALS` if approval is reserved for Super Admin/Super Account Manager.
