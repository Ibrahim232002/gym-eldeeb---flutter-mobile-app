-- Read-only production verification; use a database administrator connection.
SELECT count(*) AS inconsistent_member_states
FROM public.members m
WHERE m.is_active IS DISTINCT FROM (
  m.deleted_at IS NULL AND NOT m.manually_deactivated
  AND gym_private.member_has_valid_membership(m.id, m.gym_id)
);

SELECT count(*) AS overdue_active_memberships
FROM public.memberships
WHERE status = 'active' AND deleted_at IS NULL
  AND end_date < gym_private.cairo_today();

SELECT jobid, jobname, schedule, command, username, active
FROM cron.job WHERE jobname = 'gym-membership-lifecycle-cairo';

SELECT * FROM gym_private.membership_lifecycle_runs;

SELECT status, start_time, end_time, return_message
FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job
  WHERE jobname = 'gym-membership-lifecycle-cairo')
ORDER BY start_time DESC LIMIT 10;

SELECT
  has_function_privilege('authenticated',
    'gym_private.run_membership_lifecycle()', 'EXECUTE') AS client_processor_access,
  has_function_privilege('anon',
    'public.set_member_activation(uuid,boolean,integer)', 'EXECUTE') AS anon_activation_access;

SELECT count(*) AS payments, sum(amount) AS total_amount,
  md5(string_agg(to_jsonb(p)::text, ',' ORDER BY id)) AS complete_payment_fingerprint
FROM public.payments p;
