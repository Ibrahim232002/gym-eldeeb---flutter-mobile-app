-- Gym ElDeeb RLS verification checklist.
-- Run these tests in Supabase SQL Editor with representative test accounts.
-- Do not paste service-role credentials into the app.
--
-- 1) Confirm RLS is enabled for business tables:
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'profiles','gyms','members','membership_plans',
    'memberships','payments','gym_invites'
  )
ORDER BY tablename;
--
-- 2) Inspect existing policies before changing anything:
SELECT schemaname, tablename, policyname, permissive, roles,
       cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'profiles','gyms','members','membership_plans',
    'memberships','payments','gym_invites'
  )
ORDER BY tablename, policyname;
--
-- 3) Functional tests to execute from two authenticated accounts:
--    A. User in Gym A can read/write only Gym A data.
--    B. User in Gym B cannot read/write Gym A members, memberships, plans or payments.
--    C. Coach cannot change profile.role or another user's gym_id.
--    D. Coach cannot change gym settings if owner-only policy is intended.
--    E. join-gym must be the only allowed path for assigning a gym/role.
--
-- These last tests must be performed through the client using real auth sessions;
-- SQL Editor runs with elevated privileges and is not a substitute for RLS testing.
