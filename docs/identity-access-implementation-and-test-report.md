# Identity, Invitation, and Account Access Implementation Report

**Completed:** 21 August 2026
**Frontend:** `school_management_app` (new Flutter frontend only)
**Backend:** `spring-server-generated`
**Source of truth:** `identity-invitation-account-access-specification.md`

## Outcome

The invitation, account-discovery, account-separation, guardian portability, guardian merge, username recovery, and password-reset system is implemented across the frontend, backend, security layer, and database model.

The old school-driven identity-link API and UI were removed. The implementation does not preserve backward compatibility with that unfinished design.

## Temporary verification channel and production blocker

The current development and internal-testing release deliberately delivers verification codes through the existing **email notification path**. This keeps the complete invitation and recovery workflow testable before the SMS provider is integrated. The UI and API describe the actual delivery channel and show only a masked destination.

This bridge is not production-grade proof of phone ownership. Internally, the fresh test accounts retain the normalized phone needed for later account discovery, with the explicit source `PRE_PRODUCTION_EMAIL_CODE_FOR_PHONE`. Before production, SMA must switch `IDENTITY_VERIFICATION_DELIVERY_CHANNEL` to SMS, verify real Ghanaian and international delivery, and remove the temporary assumption that an emailed code proves control of the supplied phone. `IDENTITY_TESTING_EXPOSE_OTP` must be false outside local automated testing.

## Implemented user journeys

### Invitation and activation

1. An authorized school or platform administrator creates a restricted staff or guardian invitation.
2. During internal testing SMA sends the code through existing email delivery. Production must send it by SMS.
3. The recipient confirms the code, first name, and last name. Email and date of birth are requested only when the school supplied them.
4. Only after successful verification does SMA discover possible existing accounts.
5. The user explicitly chooses to:
   - authenticate and connect an existing account;
   - decide later and create separate access where the business rules permit it; or
   - state that the suggested accounts are not theirs.
6. The user creates a globally unique username and password when new access is required.
7. The account receives only the intended school membership and roles.

### Account boundaries

- Guardian access is portable across schools.
- One staff account belongs to exactly one school.
- Multiple staff roles at one school are added to the same staff account.
- Staff access at another school uses a separate account.
- Staff and guardian access remain separate even when they belong to the same real person.
- Proven accounts may reference the same internal `PersonIdentity`, but they retain separate credentials, sessions, permissions, and school records.

### Guardian merge

- Only the signed-in guardian initiates a merge.
- The user must authenticate both the current and source guardian accounts.
- Memberships and guardian access references move to the canonical account.
- Duplicate same-school household records are reconciled without violating uniqueness.
- The former username is retained as an alias to the canonical account.
- School finance, admission, medical, academic, and household data are not collapsed into one cross-school record.

### Recovery

- **Forgot username:** verified phone + first and last name + any recorded optional evidence. Every account is matched independently; recovery never merges accounts.
- **Forgot password:** exact global username + verified phone challenge + recorded evidence. Only that username's password changes.
- Unknown phone numbers and usernames return neutral responses and do not send a verification message.
- Recovery proof is time-limited and scoped to its purpose.

## Public and protected endpoints

Base route: `/api/account-access`

| Method | Route | Purpose | Access |
|---|---|---|---|
| POST | `/schools/{schoolId}/invitations` | Create restricted invitation | Authorized platform/school management |
| GET | `/invitations/{token}` | Read masked invitation summary | Public token |
| POST | `/invitations/{token}/resend-code` | Resend verification code through the configured channel | Public token, rate limited |
| POST | `/invitations/{token}/not-me` | Dispute an invitation | Public token |
| POST | `/invitations/{token}/verify` | Verify OTP and personal evidence | Public token |
| POST | `/invitations/{token}/activate` | Complete explicit account decision | Verified activation session |
| GET | `/usernames/{username}/available` | Check global username availability | Public |
| POST | `/recovery/usernames/start` | Start forgot-username flow | Public, neutral response |
| POST | `/recovery/password/start` | Start password reset | Public, neutral response |
| POST | `/recovery/{id}/verify` | Verify recovery OTP/evidence | Public challenge |
| POST | `/recovery/{id}/reset-password` | Reset one exact account | Verified recovery proof |
| POST | `/guardian/merge` | Merge proven guardian access accounts | Authenticated guardian |

## Data model and fresh-schema initialization

This implementation intentionally does not preserve the legacy database schema. On a new installation, Hibernate creates the schema from the current entities. The backend then loads one canonical lookup seed from `src/main/resources/db/seed/lookup.sql`.

The seed combines the former lookup files, contains reference data only, and may also be executed manually after the schema exists. It is repeatable: rerunning it updates or ignores rows by stable natural keys instead of creating duplicates.

Principal records:

- `person_identities` — internal same-person association only;
- `account_invitations` and `account_invitation_roles` — restricted invitations and intended roles;
- `account_security_challenges` — OTP, evidence verification, and recovery proof lifecycle;
- `account_username_aliases` — former guardian usernames after merge;
- `account_access_audits` — invitation, verification, decision, recovery, and merge audit events;
- `users.person_identity_id` and `users.merged_into_account_id` — identity and canonical-account references;
- guardian/staff uniqueness boundaries updated for portable guardians and school-isolated staff.

The current entity model does not impose the former legacy assumptions that email, guardian user ID, or staff user ID alone must be globally unique.

## Security controls verified

- Global username-only authentication; no school selector.
- New username validation and global uniqueness.
- Password strength enforcement.
- BCrypt password and OTP/proof hashing.
- OTP expiry and five-attempt lockout.
- Personal-information mismatch lockout after three attempts.
- Invitation resend cooldown and maximum send count.
- Invitation expiry, cancellation, dispute, replacement, and single-use activation.
- Neutral recovery responses for unknown identifiers.
- Verified-phone-only password recovery.
- Exact existing username/password proof before connection or merge.
- Tenant-scoped invitation creation and school membership grants.
- Membership-specific guardian blocking; blocking one school/household does not disable the portable guardian account elsewhere.
- Security-sensitive actions are audited.
- Invitation and recovery rows use optimistic/pessimistic locking at their mutation boundaries.
- Concurrent activation of the same invitation is idempotent.
- Password reset and guardian merge invalidate previous access and refresh sessions.
- Every authenticated request reloads account status, authorization version, and current database roles.
- CORS allows local development origins by default and requires an explicit production/custom-domain allowlist.

## Automated verification

### Backend

The complete Maven test suite passes: **202 tests, 0 failures, 0 errors**. Dedicated account-access coverage includes:

- restricted invitation creation without premature account creation;
- required and optional evidence rules;
- portable guardian creation and cross-school reuse;
- SMS not falsely verifying a school-supplied email;
- staff separation across schools while preserving same-person proof;
- same-school staff role addition without duplicate accounts;
- explicit candidate decisions and `not mine` handling;
- weak password and unavailable username rejection;
- invitation expiry, OTP lockout, information lockout, resend cooldown, and resend maximum;
- disputed/activated invitation reuse rejection;
- replacement of an older invitation for the same school record;
- neutral unknown-phone and unknown-username recovery;
- independent forgot-username matching;
- guardian merge, aliases, membership movement, and duplicate-household reconciliation;
- school-isolated guardian blocking and portable-school selection.

### Frontend

Flutter analysis and the complete Flutter test suite pass: **155 tests with no failures and no analyzer issues**. Coverage includes request payload boundaries, account decisions, channel-aware recovery copy, recovery identifiers, username-only login, routing, permissions, and existing application regressions.

## Live browser and API scenarios

The reusable `scripts/identity-fresh-schema-e2e.sh` journey was exercised against the real Spring service and a fresh MySQL schema. It completed **31 checks**:

1. New guardian invitation, verification, activation, and login.
2. The same guardian account connected to two schools.
3. Same-school staff account gained a second staff role without a second account.
4. A staff member at a second school received separate credentials but retained confirmed same-person association.
5. A staff member also received separate guardian access associated with the same person identity.
6. Forgot username returned three independently qualified accounts: two school-specific staff accounts and one guardian account.
7. Password reset changed only the selected guardian username; its old password failed and its new password succeeded.
8. The same activation response was retried safely without a duplicate account.
9. A school administrator was denied invitation and school-data access for another tenant.
10. A second guardian account was kept separate and merged later by the guardian.
11. The merged source access token and refresh token were terminated.
12. The former username alias authenticated the canonical account.
13. Password reset invalidated pre-reset access and refresh tokens and allowed immediate sign-in with the new password.
14. Forgot username returned only independently eligible proven accounts.
15. Equivalent Ghana local and `+233` phone formats resolved to the same normalized identity signal.
16. Two simultaneous activations of the same invitation both returned the same account ID.

The live browser then verified the current, uncached Flutter web build at a 1728 × 1000 viewport:

- the activation screen names **email** as the current delivery channel and masks the destination;
- incorrect optional evidence produces a clear mismatch error without activation;
- correct evidence advances to explicit global-username account setup;
- blank/weak password submission is stopped with visible validation;
- password recovery asks for a global username and accurately explains that the code goes to the registered contact.

After the destructive final verification, the local database contains one predictable school, `SMA Demonstration Academy` (`SMA-DEMO-001`), and the four fixed demonstration accounts documented in `docs/local-demo-uat.md`. Timestamped `IT` schools and legacy records are no longer present.

## Problems found and corrected during verification

- The activation screen retained state when navigating directly between invitation tokens. The route is now keyed by token and stale asynchronous responses are ignored.
- Guardian blocking initially risked disabling a portable account across every school. Blocking is now scoped to the relevant guardian school/household record.
- Username recovery for an unknown phone could create unnecessary challenge state. It now returns a neutral response without sending an SMS or persisting a challenge.
- SMS verification could incorrectly imply that an invitation email was verified. Email remains unverified unless separately proven.
- Password recovery could fall back to an unverified raw phone. Only verified phone contact methods are accepted.
- Same-school guardian merge could violate the household uniqueness boundary. Duplicate household access records are now reconciled.
- Staff invitation roles could be represented by an immutable set and fail during persistence. Roles are now mutable.
- A fresh schema was required because the legacy database contained uniqueness assumptions that conflicted with portable guardian accounts and school-isolated staff accounts. The fresh entity-generated schema now applies the intended boundaries directly.
- The backend previously mixed Jackson 2.18.3 databind with Jackson 2.17.2 core components, causing fresh invitation activation to fail at runtime. The explicit override was removed so every Jackson component resolves to 2.17.2.
- Multiple lookup scripts contained overlapping subject catalogues and could drift apart. They were consolidated into one canonical seed; a clean database and repeated execution both produced 212 unique districts, 108 unique subjects, 8 fee types, 20 expense categories, 4 education levels, and 9 blood groups.
- Platform account managers were missing from the invitation endpoint's authorization expression. Their tenant-scoped permission is now included.
- Fresh account activation failed because the temporary verification-source label exceeded the database column. The fresh-schema column is now 64 characters and the real activation journey succeeds.
- A former guardian username alias resolved to the canonical account but authentication still checked the disabled source username. Login now authenticates the resolved canonical username.
- Password-recovery text incorrectly described the forgot-username phone lookup. Each recovery screen now describes its own identifier and delivery behavior.
- Previously used development origins could serve a cached Flutter service worker. Live verification was moved to a fresh single origin to ensure the newly built assets were actually under test.
- Multi-role login failed at runtime because JJWT attempted service discovery only when serializing collection claims. JWT JSON serialization/deserialization is now configured explicitly, duplicate dependency declarations were removed, and an Administrator/Bursar login was repeated successfully through the live UI.
- A fixed demo school code without three hyphen-separated parts caused guardian/admission ID generation to fail. The stable demo now uses the valid code `SMA-DEMO-001`.
- Guardian personal-info onboarding created the household, admission, and guardian correctly but omitted their identifiers from its response. The response now includes `householdId`, `admissionId`, and `customGuardianId`.
- Resuming platform onboarding trusted abbreviated school-list progress and reopened an earlier wizard page after documents were saved. The detailed onboarding record is now authoritative.
- Re-saving the term during platform onboarding created a duplicate academic-term row, which detached already-published fee structures from readiness. Onboarding now updates the existing current term in place and preserves its identifier and financial references.

## External integrations not claimed as completed

- A real SMS provider delivery was not exercised. Per the current product decision, local tests used existing email delivery plus testing OTP exposure while still invoking the notification-service boundary.
- Production deployment and production secrets were not changed.
- HTTPS/custom-domain routing and multiple live application instances require a staging environment and were not claimed from a single-machine run.
- User notification for every audit event is a separate future feature; audit records exist now.

These are environment or future-integration limits, not incomplete identity business rules.

## Operational release checklist

1. Provision a new empty database; do not point this fresh-schema release at a legacy production database.
2. Start the backend so the current entities create the schema and the canonical `db/seed/lookup.sql` reference data is applied.
3. Validate the expected lookup counts and confirm a second seed run does not change them.
4. Replace the pre-production email bridge with the SMS provider, test delivery/retry/outage behavior, and disable `identity.testing.expose-otp` outside local testing.
5. Deploy backend and new frontend together.
6. Verify one guardian invitation, one same-school staff-role addition, one cross-school staff invitation, forgot username, and password reset in staging.
7. Confirm audit retention, support access, and invitation-expiry monitoring.
8. Do not re-enable the removed school-driven identity-link endpoints.
