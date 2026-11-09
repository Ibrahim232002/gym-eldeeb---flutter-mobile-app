# Membership lifecycle verification

The fixture is an audited schema snapshot with **no production rows**. Do not
apply `fixtures/audited_schema.sql` to Supabase. It creates an isolated test
schema, test roles and minimal auth helpers.

The test runner uses real PostgreSQL via PGlite in memory. It applies the lifecycle
migration's functions/triggers, retains the existing exclusion constraint and RLS,
and exercises synthetic data under both `authenticated` gym identities. Only the
pg_cron installation section is omitted: hosted extension availability, job
configuration, permissions and processor invocation were verified on Supabase.

Run from the repository root (PowerShell):

```powershell
npm install --prefix "$env:TEMP\gym-lifecycle-pg-test" --no-audit --no-fund @electric-sql/pglite@0.3.14
node supabase/tests/lifecycle_test.mjs "$env:TEMP\gym-lifecycle-pg-test\node_modules\@electric-sql\pglite"
flutter pub get
flutter analyze
flutter test
```

The runtime is a temporary test dependency; it adds no product dependencies,
external server or paid infrastructure. The SQL tests use a deterministic local
clock; the production Cairo clock function is never replaced for testing.

`verify_membership_lifecycle.sql` contains read-only production checks. A healthy
deployment has zero inconsistent member states and overdue active memberships,
one active named cron job, and no client execute privilege on the processors.

The two older repository migrations were not recorded in live migration history,
although their objects already existed with some differences. Do not run a blind
`db push` of those files. The new migration filename matches the verified live
version `20261109001226`; it was generated with the CLI and aligned with the
version assigned by the migration API after application.
