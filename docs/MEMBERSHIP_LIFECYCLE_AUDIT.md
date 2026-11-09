# Membership lifecycle audit — 9 November 2026

## Architecture inspected before implementation

The Flutter app uses Riverpod (`authNotifierProvider`, `dataSyncServiceProvider`,
tab/filter providers), GoRouter, and Arabic/RTL Material screens. Most business
screens and dialogs live in `lib/features/dashboard/dashboard_screen.dart`.
`lib/core/services/data_sync_service.dart` is the existing repository, cache and
write queue, backed by gym-scoped SharedPreferences and Supabase. Domain models
are in `lib/data/models/`. Auth/profile caching is separate. The React preview in
`src/` is not the mobile application and is outside this change.

### Traced flows and root causes

| Flow | Existing path | Finding |
|---|---|---|
| Add member | `_AddMemberDialog` → `addMember` → member upsert/cache/queue | Defaults to active even without a membership. Name/phone uniqueness and photo handling already exist. |
| Create / renew | `_CreateMembershipDialog` → `createMembership` → `create_membership_with_initial_payment` | Transactional, idempotent membership/payment creation and overlap guards exist. Renewal uses the same path. Neither RPC nor client recalculates the member flag. Offline bundles stay pending until server confirmation. |
| Manual deactivation | `_EditMemberDialog` → `editMember` | Full-row writes include `is_active`. No separate manual intent exists, so a stale offline profile edit can overwrite a renewal's activation. |
| Delete member | details sheet → `deleteMember` | Soft delete through `deleted_at`; memberships and payments remain. Correct history preservation. |
| Record payment | initial payment in creation RPC; edit/delete through service | Payment links to membership, which links to member. Coach uses `recorded_by` and cached profile lookup. |
| Upcoming expiration | overview and `_ExpiringMembershipsTab` → `expiringMembershipsWithinDays` | Dates/status are checked, but the parent member is not. UI substitutes `عضو محذوف`. |
| Active/inactive | overview counts and members tab | Uses raw `Member.isActive`, independent of current membership validity. |
| Subscription status | membership model + subscriptions tab | Inclusive end date already modeled, but current day uses device timezone and one screen ignores explicit `expired` status. |
| Sync | `syncAll` → queue replay → four-table snapshot | Failed actions preserve local snapshot. Generic member updates send full stale rows. Coach names are not persisted for restart offline. |

## Live database (project rpwcjfayhdwbsnecomnk)

Inspected live columns, constraints, indexes, triggers, function definitions,
execution grants, RLS, Edge Function source, extensions/settings, migration
history, log errors, and security/performance/health advisors.

* Tables: gyms, profiles, members, membership_plans, memberships, payments,
  sync_metadata, gym_invites. RLS is enabled on all. Business-table policies
  restrict both USING and WITH CHECK to `current_user_gym_id()`.
* `memberships.member_id` → members and `payments.membership_id` → memberships
  use ON DELETE RESTRICT. No cascaded business-history deletion. Nullable actor
  references use ON DELETE SET NULL.
* Status is text constrained to active/expired/cancelled; dates are DATE, with
  `end_date >= start_date`. Existing GiST exclusion constraint and trigger
  prevent overlapping active periods. Member and end-date indexes already exist.
* Only update-timestamp and membership-overlap triggers exist. No lifecycle
  automation. `sync_version` is not incremented by the timestamp trigger.
* The live renewal RPC additionally validates authenticated gym/member and
  overwrites actor IDs using `auth.uid()`. These checks are missing from the
  local 20261004 migration and must be retained. Live unique-index names also
  differ from the 20261022 migration. Live migration history is empty: do not
  replay those old migrations blindly.
* `join-gym` is the only Edge Function. It validates the bearer token internally
  with `getUser`, then uses its server-side client to claim an invite. No lifecycle
  code; no changes planned to authentication or roles.
* Organization plan: free. PostgreSQL 17.11, pg_cron 1.6.4 available and preloaded,
  not installed; `cron.job` absent. No cron jobs exist. `cron.timezone=GMT` is a
  postmaster setting, so a session SET cannot change the scheduler timezone.

### Read-only data preflight

At Cairo date 2026-11-09: 126 members (18 soft-deleted), 138 memberships,
110 payments totaling EGP 27,950. One live active membership is past its end
date; two nondeleted members are active without valid coverage; zero inactive
members have valid coverage. One deleted member has an upcoming expiration.
One future membership exists. Cross-gym member/plan/payment links: zero.

Existing advisors: mutable search_path on three old functions, expected
authenticated access to the current-gym helper, no client policy on invite table,
disabled leaked-password protection, six unindexed foreign keys. No health
findings. Recent database errors are overlap/member-gym validation failures and
the absent migration-history table. These unrelated items are not being changed.

## Implementation decision

Database dates and nondeleted `active` memberships determine coverage, including
the entire end date, in Africa/Cairo. Keep manual deactivation separately; a new
successfully committed current/future renewal clears it. Future-only coverage
never activates early. Store a revision for manual intent so stale queued edits
cannot undo a renewal. Derive the same state from confirmed cached records
offline; never activate from an unconfirmed renewal bundle.

Add guarded lifecycle triggers and a private daily processor, retaining RLS and
the live RPC's authorization/attribution/idempotency behavior. Generic profile
edits omit lifecycle fields. A named hourly cron dispatcher processes once per
Cairo calendar day, normally at 00:00, with catch-up after downtime. On the DST
spring transition, midnight does not exist; process at the first real instant
of that day (01:00). No fixed UTC offset, paid service, or Edge Function needed.

Upcoming lists require a present, same-gym, nondeleted member. Payment names
resolve through the full cached payment → membership → member relationship,
including soft-deleted history, without copying names into payment rows.

Production changes will update only lifecycle flags/statuses and associated
revision/timestamps. They will not alter identities, gym associations, plans,
payment amounts, dates, or history. Migration application and test results are
recorded separately in the implementation report.
