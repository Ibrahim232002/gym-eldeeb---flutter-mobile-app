# Implementation report — 9 November 2026

## Completion and live verification

Flutter changes are complete locally. Migration
`20261109001226_membership_lifecycle_cairo.sql` was successfully applied to
Supabase project `rpwcjfayhdwbsnecomnk` and verified in live migration history.
Application time: **02:12:26 Cairo, 9 November 2026** (00:12:26 UTC).
No mobile binary was published or installed, and no Git commit or push was made.

The initial processing expired one overdue membership and corrected 19 stored
active flags (two visible members without valid coverage, plus 17 already-deleted
members). Live result: **106 active, 2 inactive, zero lifecycle mismatches**.

| Data | Before | After | Verification |
|---|---:|---:|---|
| Members, including soft-deleted | 126 | 126 | Identity/business fields unchanged |
| Membership history | 138 | 138 | All fields except permitted status/sync/timestamps unchanged |
| Payments | 110 | 110 | Complete rows unchanged, including attribution and timestamps |
| Payment total | EGP 27,950 | EGP 27,950 | Unchanged |

Complete payment fingerprint remained `123a6928d4e1fce11a6e99e6a4a499fb`.
Member identity fingerprint remained `4ffb9a30b7a1b75011c8039b38e2f1dc`.
Membership history fingerprint remained `1117e2d0487507c34a5da438ac6a49b0`.
A second live reconciliation updated zero rows; another daily invocation skipped
the already-completed Cairo date. All nine existing public RLS policies compare
identically before and after. No new SECURITY DEFINER functions were introduced.

## Architecture and original causes

See `MEMBERSHIP_LIFECYCLE_AUDIT.md` for the pre-implementation architecture and
eight traced workflows. The existing Riverpod/GoRouter app keeps business CRUD,
SharedPreferences caches and offline queues in `DataSyncService`; dashboard tabs
and dialogs share that service. The implementation retains that architecture.

1. Upcoming expiration checked memberships but omitted the soft-deleted parent
   member. Both overview and expiration screen now use a single service getter
   requiring a present, nondeleted, same-gym member. Historical rows remain.
2. Member `is_active` was independent of membership dates, and no scheduled
   processor existed. It is now a derived database value: a nondeleted member,
   not manually deactivated, with at least one nondeleted active membership whose
   Cairo calendar interval includes today. The Flutter cache uses the same rule.
3. Renewal saved membership/payment atomically but never changed member state.
   An insert trigger now clears manual deactivation in that same transaction;
   failed payment rolls the entire change back. The RPC returns the committed
   member as well as membership/payment, so the UI updates immediately.
4. Full member updates carried stale activation snapshots. Profile payloads now
   omit lifecycle fields, and explicit manual changes use a revision-checked RPC.
   Superseded queued deactivations refresh the current server state. Queued renewal
   bundles do not activate or contribute revenue before server confirmation.
5. Payment cards displayed coach attribution without the member relationship.
   Member names now resolve from cached Payment → Membership → Member, including
   deleted historical records, with a safe unavailable-reference label. Coach
   names are persisted per gym for offline restart. Revenue calculation is intact.

Manual deactivation remains effective until a successful new current/future
renewal. Future-only coverage does not activate early. Historical renewal retries
cannot clear a later manual deactivation. An expired old membership cannot defeat
another valid one. End dates remain inclusive. Screens refresh at the next Cairo
date and when the application resumes.

## Changed local files

| File | Purpose |
|---|---|
| `lib/core/utils/gym_clock.dart` | IANA Cairo date and next-day boundary |
| `lib/data/models/member.dart` | Manual intent and activation revision metadata |
| `lib/data/models/membership.dart` | Shared eligibility/member projection and parent-aware expiry filtering |
| `lib/core/services/data_sync_service.dart` | Derived state, confirmed renewal acceptance, protected offline edits, history/name lookup |
| `lib/features/dashboard/dashboard_screen.dart` | Expiry/count consistency, manual-intent control, member/coach payment labels, midnight/resume refresh |
| `pubspec.yaml`, `pubspec.lock` | Only new dependency: pinned `timezone: 0.11.2`; no unrelated upgrades |
| `test/membership_lifecycle_test.dart` | 12 lifecycle, service, timezone and RTL payment regression tests |
| `test/widget_test.dart` | Updated stale text expectations and Cairo-relative expiry fixtures |
| `supabase/migrations/20261109001226_membership_lifecycle_cairo.sql` | Applied additive migration |
| `supabase/tests/lifecycle_test.mjs` | 16 isolated PostgreSQL checks |
| `supabase/tests/fixtures/audited_schema.sql` | Schema-only isolated fixture, no real rows |
| `supabase/tests/verify_membership_lifecycle.sql` | Read-only live verification queries |
| `supabase/tests/README.md` | Reproducible backend testing and migration-history notes |
| `.gitignore` | Ignore CLI temporary metadata |
| `docs/MEMBERSHIP_LIFECYCLE_AUDIT.md`, this report | Findings, decisions and verified outcome |

Regression testing also fixed initially selected dashboard tabs not mounting and
made the existing expiration-screen action sheet scroll on short screens. No new
messaging functionality was added.

## Live database objects

* New member columns: `manually_deactivated`, `activation_revision`.
* New public RPC: `set_member_activation(uuid, boolean, integer)`.
* Updated `create_membership_with_initial_payment(jsonb,jsonb)`: retained live
  authenticated gym/actor checks, returns member state, rejects deleted parents,
  and allows unchanged request retries after automatic expiration.
* New private functions: `cairo_today`, `member_has_valid_membership`,
  `derive_member_activation`, `guard_membership_lifecycle`,
  `sync_member_after_membership`, `guard_payment_membership_gym`,
  `reconcile_membership_lifecycle`, `run_membership_lifecycle`.
* New triggers: `members_derive_activation`, `memberships_lifecycle_guard`,
  `memberships_sync_member`, `payments_membership_gym_guard`.
* New private checkpoint table: `gym_private.membership_lifecycle_runs`, with RLS
  enabled and no client grants/policies (intentional deny-all).
* Enabled existing available extension `pg_cron` 1.6.4; one named cron job added.

The migration contains no DROP, TRUNCATE or DELETE statements. Existing foreign
keys, overlapping-period constraint, RLS policies, roles, ownership and Edge
Functions were retained. Trigger checks additionally reject mismatched gym links
and new subscriptions to disabled/deleted plans. New functions use fixed empty
search paths and SECURITY INVOKER. Client roles cannot run either processor.

## Schedule and Cairo daylight saving

**Job:** `gym-membership-lifecycle-cairo` (job ID 1, active, owner postgres).
**Exact cron expression:** `0 * * * *`.
**Command:** `SELECT gym_private.run_membership_lifecycle();`.

The existing scheduler's `cron.timezone` is GMT and requires a restart to change.
Instead of changing global configuration or hardcoding a UTC offset, the hourly
dispatcher compares `(statement_timestamp() AT TIME ZONE 'Africa/Cairo')::date`
against a locked checkpoint. Processing occurs once at the first hour of each
new Cairo day: normally **00:00 Cairo** (22:00 UTC in winter, 21:00 UTC in summer).
On the spring DST transition, 00:00 does not exist; the first real time is 01:00.
The repeated autumn hour does not cause duplicate daily processing. An outage
is caught up at the next hourly invocation. Each record is matched by member AND
gym. This uses the verified Free Plan's database capabilities, with no paid
infrastructure, Edge Function invocation, or external server.

The job configuration and direct live processor execution are verified. At the
end of verification, its first natural hourly cron execution had not yet occurred;
`cron.job_run_details` had zero entries. A scheduled midnight run has not been
claimed as observed. The read-only verification script includes its run history.

## Tests and limits

* `flutter pub get`: passed; only the timezone dependency was added.
* `flutter analyze`: passed with **no issues** after fixing three test-only lints.
* `flutter test`: **60 passed**, including inclusive boundaries, invalid/future
  coverage, successful/manual reactivation, failed renewal, restart/offline
  behavior, stale queued edits, deleted-member expiry/history, missing references,
  unchanged monthly totals, both names and a 320-pixel Arabic RTL layout.
* Isolated PostgreSQL suite: **16 checks passed**. Covers date transitions,
  multiple memberships, transaction rollback, retry/idempotence, history retention,
  two authenticated gym roles, processor grants, and winter/summer/DST boundaries.
* Live read-only pre/postflight, no-op second reconciliation, cron configuration,
  grants, unchanged RLS and full historical fingerprints: passed.
* `git diff --check`: passed.

The SQL fixture models authenticated roles in an isolated database; no real coach
login was used for a production end-to-end UI transaction. No synthetic records
were inserted into the production database. Multi-connection stress testing was
not performed by the single-connection local test runtime.

Existing unrelated security/performance advisories remain documented in the audit.
The new private checkpoint table produces an informational “RLS enabled, no
policy” notice intentionally: only the database job owner should access it.
Health advisors remain empty. Relevant explanations:
[private deny-all RLS](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy),
[existing mutable search paths](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable).

## Remaining release steps

Build/distribute the updated Flutter app through the normal release process.
Older apps can keep reading the existing tables and creating renewals, but the
manual activation control must use the updated app: direct `is_active` writes
are now recalculated, preventing stale clients from undoing lifecycle state.
An offline device learns another device's changes after it reconnects; it still
expires its confirmed cached memberships at the correct Cairo date.

Do not blindly replay the two old repository migrations: their objects already
existed live without migration-history records, and the live RPC contained extra
authorization checks. The new migration is recorded and its filename matches the
live version. There are no remaining backend application steps for this change.

References verified during implementation:
[Supabase Cron](https://supabase.com/docs/guides/cron),
[job scheduling](https://supabase.com/docs/guides/cron/quickstart),
[pg_cron scheduler timezone](https://github.com/citusdata/pg_cron),
[Dart IANA timezone package](https://pub.dev/packages/timezone).
