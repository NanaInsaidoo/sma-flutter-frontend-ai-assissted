# Jira Story: Configurable Staff Roles, Authorisations, and Access Restrictions

## Jira fields

- **Issue type:** Story
- **Jira issue:** [SMA-21](https://narella.atlassian.net/browse/SMA-21)
- **Suggested summary:** School-configurable staff job titles, authority roles, scoped permissions, and individual access exceptions
- **Priority:** High
- **Components:** Staff Management, Identity & Access, School Settings, Approvals, Audit
- **Suggested labels:** `staff`, `rbac`, `permissions`, `authorisation`, `security`, `school-settings`

## User story

As a school administrator, I want to assign staff a human-readable job title, a safe authority role, an operational scope, and carefully controlled individual exceptions so that each person can do their job without seeing or changing information that is not their business.

## Business outcome

Schools can use familiar titles such as Headmistress, Principal, Accountant, Cook, or Pastor without creating a new technical permission model for every title. Staff receive predictable permissions from an authority template, while authorized administrators can grant or block a specific permission for one person without changing the access of other staff with the same role.

## Background and current state

The application already has:

- built-in role permission defaults;
- multiple roles per user, with the resulting permissions combined;
- backend permission checks by module and action;
- temporary, additive individual permission grants with a reason and expiry date;
- automatic expiry and manual revocation of individual grants;
- audit support;
- a planned **School Settings -> Role & Permission Settings** entry.

The application does not yet have:

- school-configurable job titles;
- a working Roles & Authorisations settings interface;
- job-title-to-authority mapping;
- user-specific permission blocks that remove an inherited permission;
- sufficiently granular permissions for every staff and finance operation;
- a complete effective-access preview explaining why access is allowed or blocked.

Current individual permission overrides are additive only. A Bursar inherits the Bursar defaults, but an administrator cannot currently block only `Edit petty-cash top-ups` for that one Bursar. This story must add that capability safely.

## Terminology and required separation

The system must treat these as separate concepts:

1. **Job title** — what the staff member is called, for example Principal or Accountant.
2. **Authority role** — the reusable permission template, for example School Leader or Finance.
3. **Assignment/scope** — where and for whom the authority applies, for example Basic 2, Mathematics, a campus, or a financial account.
4. **Individual authorisation** — an exceptional permission granted directly to one person.
5. **Individual restriction** — a permission inherited from a role but explicitly blocked for one person.
6. **Approval assignment** — a specific request assigned to an eligible approver; eligibility must not expose every request.

A job title must never silently confer unrestricted system access.

## Standard staff job titles

Provide the following school-visible titles by default. Schools may add, rename, deactivate, and reorder additional titles without changing the built-in authority templates.

### School leadership

- Headmaster
- Headmistress
- Principal
- Assistant Headmaster
- Assistant Headmistress
- Assistant Principal
- Head Teacher
- Assistant Head Teacher

### Administration and ownership

- Administrator
- Office Administrator
- Secretary
- Proprietor
- Proprietress

### Teaching

- Teacher

Do not present Class Teacher and Subject Teacher as separate staff job titles. Class and subject responsibilities are assignments within one Teacher workspace. Internal legacy codes may remain as implementation details, but users must see `Teacher`, not `CLASS_TEACHER` or `SUBJECT_TEACHER`.

### Finance

- Bursar
- Accountant

### Support and pastoral staff

- Cook
- Security
- Pastor
- Staff

Schools must be able to create other titles and select **Same authority as...** during creation.

## Built-in authority templates

Provide locked, versioned built-in templates:

- School Owner
- Administrator
- School Leader
- Assistant School Leader
- Teacher
- Finance
- Front Office
- Staff Only

Suggested defaults:

| Job title | Suggested authority template |
|---|---|
| Headmaster, Headmistress, Principal, Head Teacher | School Leader |
| Assistant Headmaster, Assistant Headmistress, Assistant Principal, Assistant Head Teacher | Assistant School Leader |
| Teacher | Teacher |
| Bursar, Accountant | Finance |
| Secretary | Front Office |
| Cook, Security, Pastor, Staff | Staff Only |
| Office Administrator | Front Office by default; Administrator only by explicit selection |
| Proprietor, Proprietress | Must be explicitly selected during setup; do not silently grant School Owner access based on the title alone |

Built-in templates cannot be edited in place. A school may create a reusable custom authority by cloning a built-in template, for example `Bursar - Read Only`, and then changing the clone. Changes must be versioned and show the affected users before saving.

## Permission model

Permissions must be granular and expressed as:

`module + resource + action + scope`

Examples:

- `Finance / Petty-cash top-ups / View / All school accounts`
- `Finance / Petty-cash top-ups / Edit draft / Assigned account`
- `Assessments / Marks / Enter / Assigned classes and subjects`
- `Staff HR / Leave / Approve / Assigned requests`
- `Reports / Term reports / Publish / Whole school`

At minimum, support actions such as View, Create, Edit Draft, Submit, Approve, Reject, Reverse/Void, Export, Publish, Manage Access, Suspend, Reactivate, and Deactivate where relevant.

Do not provide hard-delete permission for posted financial transactions. Recorded transactions must be voided or reversed with a reason and immutable audit history. Drafts may be edited or cancelled according to permission.

## Effective-access calculation

Access must be evaluated in the following order:

1. Inactive or deactivated account -> deny all access and revoke active sessions.
2. Wrong school/tenant -> deny.
3. Explicit individual restriction matching the permission and scope -> deny.
4. No required assignment or out-of-scope resource -> deny.
5. Any active authority role or active individual authorisation matching the permission and scope -> allow.
6. Otherwise -> deny by default.

Multiple roles are additive, but an explicit individual restriction wins over every role for the matching permission and scope.

The effective-access response and UI must explain the source, for example:

- `Allowed - inherited from Finance`;
- `Allowed until 30 Nov 2026 - temporary individual authorisation`;
- `Blocked - individual restriction`;
- `Blocked - no assigned class`;
- `Blocked - not granted`.

## Individual grants and restrictions

An authorized administrator must be able to:

- grant one staff member an additional permission;
- block one inherited permission for one staff member without affecting other users with the same role;
- select a resource scope;
- enter a mandatory reason;
- choose permanent or time-limited access/restriction;
- see the before-and-after effective access;
- revoke the grant or restriction;
- review its complete audit history.

Example:

All Bursars inherit `View petty-cash top-ups` and `Edit draft petty-cash top-ups`. If Ama is a Bursar and receives an individual restriction on `Edit draft petty-cash top-ups`, Ama can still view top-ups but cannot edit them. Every other Bursar retains the inherited edit permission.

If several staff require the same permanent variation, administrators should create and assign a reusable custom authority such as `Bursar - Read Only` instead of maintaining repeated individual exceptions.

## Safety requirements

- Default deny.
- School/tenant isolation must be enforced on every API operation.
- A user cannot grant, block, approve, or revoke their own access.
- A grantor cannot grant a permission or scope they do not possess.
- Only users with the dedicated `Manage Authorisations` capability may change access.
- Sensitive access changes require recent authentication and explicit confirmation.
- High-risk permissions require a second authorized approver. These include payroll, payment approval, payment release, reversals, report publication, user/access management, and assignment of School Owner or Administrator authority.
- Enforce separation of duties for financial workflows: the same person should not prepare, approve, release, and reverse the same transaction.
- Record the actor, affected user, old value, new value, reason, scope, timestamp, approval, and expiry in an immutable audit log.
- Notify the affected staff member and designated administrators when sensitive access is granted, blocked, changed, revoked, or expires.
- Automatically revoke expired authorisations and restrictions.
- Deactivation must immediately revoke sessions and prevent all access.
- Never expose raw permission codes or role names containing underscores in the UI.

## Approval privacy and eligibility

Permission to approve makes a person eligible to be selected as an approver. It must not automatically expose all pending requests.

- Requesters see their own requests.
- An approver sees a request only when it is explicitly assigned to them or an approved queue rule assigns it to their role and scope.
- Staff must not see unrelated approvals.
- Only the requester may withdraw their request unless a separate, audited administrative cancellation permission exists.
- Approval rules must support role, scope, threshold, and separation-of-duties constraints.

## Teaching access rules

- Present one Teacher workspace.
- Class and subject responsibilities are assignments, not separate visible job titles.
- A Teacher with no active class or subject assignments must not see or open Assessments or Evaluations.
- Assigned teachers may access only their assigned classes, subjects, students, and relevant terms.
- Leadership authority may provide broader oversight, but the active workspace and effective-access preview must make that broader authority clear.

## User experience

### School Settings -> Roles & Authorisations

Provide four sections:

1. **Job Titles** — standard and custom school titles, status, order, and mapped authority.
2. **Authority Roles** — built-in templates, custom clones, permission matrix, version history, and affected users.
3. **Individual Authorisations** — active grants and restrictions, reasons, scopes, expiries, and revocation.
4. **Approval Rules & Audit** — eligible approvers, assignment rules, thresholds, separation of duties, and audit log.

### Staff profile -> Access

Show:

- job title;
- primary and additional authority roles;
- class, subject, campus, and financial scopes;
- inherited permissions;
- active individual grants;
- active individual restrictions;
- pending access changes;
- effective access with source explanations;
- complete access-change history.

### Staff onboarding

- Select a human-readable job title.
- Show the suggested authority and require an explicit review before saving elevated access.
- Allow a different authority to be selected only by a user who can manage authorisations.
- Use one visible Teacher title; manage class and subject responsibilities later in Classes & Sections.
- Employment status must not be required merely to establish staff login/access.
- References are optional.
- Invitation confirmation must not ask the staff member to re-enter the email address already stored by the school.

## API and data requirements

Add school-scoped entities or equivalent models for:

- `staff_job_title` — name, display order, active state, suggested authority template;
- `authority_template` — built-in/custom flag, version, permissions, active state;
- `staff_authority_assignment` — user, authority, scope, start/end dates, assigned by;
- `permission_exception` — user, allow/deny effect, module, resource, action, scope, reason, start/end dates, status, approver;
- `approval_rule` — workflow, eligible authority, scope, threshold, assignment policy, separation rule;
- immutable access audit events.

Required API capabilities:

- list/create/update/deactivate/reorder job titles;
- list built-in and custom authority templates;
- clone and version a custom authority template;
- preview affected users before template changes;
- assign and revoke authority roles with scopes;
- grant and block individual permissions;
- approve sensitive access changes;
- get effective access with explanations;
- list expiring access and audit events.

All write endpoints require tenant validation, server-side authorization, concurrency protection, audit logging, and validation that the grantor cannot exceed their own effective access.

## Acceptance criteria

1. An administrator can create `Accountant` as a job title and map it to the Finance authority without introducing a new technical role code.
2. Staff lists, selectors, profiles, notifications, exports, and reports display human-readable titles and never show underscores.
3. A Bursar automatically receives the current Finance defaults.
4. An authorized administrator can block `Edit draft petty-cash top-ups` for one Bursar; that user retains View access and other Bursars are unaffected.
5. The block has a mandatory reason, optional expiry, complete audit record, and visible source explanation.
6. An authorized administrator can grant a temporary additional permission with a reason, scope, and future expiry.
7. Expired grants and restrictions are automatically deactivated and no longer affect access.
8. A user cannot change their own access or grant authority beyond their own.
9. High-risk access changes cannot activate until a second authorized person approves them.
10. A Teacher without active assignments cannot see or open Assessments or Evaluations.
11. A Teacher with assignments can access only the assigned classes and subjects.
12. Approval-eligible staff see only their own requests and requests explicitly assigned by an approved rule.
13. Posted financial transactions cannot be deleted; authorized users may reverse or void them with a reason and audit trail.
14. Deactivating a staff account immediately blocks API and UI access and invalidates active sessions.
15. Effective-access preview matches backend enforcement for every tested module, action, and scope.
16. Existing standard roles and staff accounts migrate without gaining additional access.

## Required testing

- Unit tests for role union, explicit-deny precedence, scope matching, expiry, self-grant prevention, grantor ceiling, and default deny.
- API authorization tests for every new read and write endpoint.
- Tenant-isolation tests using staff from different schools.
- UI tests for title creation, same-authority mapping, custom template cloning, individual grant, individual restriction, expiry, revocation, and effective-access explanations.
- End-to-end tests with Administrator, School Leader, Teacher, Bursar, Secretary, Staff Only, and deactivated accounts.
- Financial separation-of-duties tests.
- Approval privacy tests proving unrelated requests are not visible.
- Regression tests for staff onboarding, invitations, class/subject assignments, attendance, leave, notifications, editing, and deactivation.
- Accessibility and responsive-layout checks for settings, dialogs, tables, and staff profiles.

## Migration and compatibility

- Preserve all existing staff accounts, job data, class/subject assignments, and unrelated school data.
- Map existing visible Class Teacher and Subject Teacher labels to Teacher while preserving internal assignment behavior.
- Map existing supported roles to the nearest built-in authority without broadening access.
- Treat legacy Headmaster and Owner codes carefully; require an explicit migration mapping and verify effective permissions before activation.
- Do not modify a built-in template in a way that silently increases access for existing users.

## Definition of done

- Frontend and backend implementation completed.
- Database migrations are reversible and preserve existing data.
- All acceptance criteria pass through the UI and API.
- Security and tenant-isolation tests pass.
- Effective-access explanations match enforced backend results.
- Audit events are produced for every access change.
- Documentation and administrator guidance are updated.
- The one-port application is rebuilt, smoke-tested, and left running.
