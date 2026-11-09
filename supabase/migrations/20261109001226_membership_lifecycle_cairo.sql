-- Additive lifecycle migration based on the audited live schema.
-- No member/membership/payment history is deleted. Existing RLS is retained.
SET lock_timeout = '10s';

ALTER TABLE public.members
  ADD COLUMN manually_deactivated boolean NOT NULL DEFAULT false,
  ADD COLUMN activation_revision integer NOT NULL DEFAULT 0;

-- Preserve existing manual intent. Legacy false cannot identify its reason;
-- renewal clears this marker in the same transaction as the new membership.
UPDATE public.members SET manually_deactivated = true
WHERE NOT is_active AND deleted_at IS NULL;

CREATE SCHEMA IF NOT EXISTS gym_private;
REVOKE ALL ON SCHEMA gym_private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA gym_private TO authenticated;

CREATE FUNCTION gym_private.cairo_today()
RETURNS date LANGUAGE sql STABLE
SET search_path = ''
AS $$ SELECT (statement_timestamp() AT TIME ZONE 'Africa/Cairo')::date $$;

CREATE FUNCTION gym_private.member_has_valid_membership(p_member_id uuid, p_gym_id uuid)
RETURNS boolean LANGUAGE sql VOLATILE SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.memberships s
    WHERE s.member_id = p_member_id AND s.gym_id = p_gym_id
      AND s.deleted_at IS NULL AND s.status = 'active'
      AND s.start_date <= gym_private.cairo_today()
      AND s.end_date >= gym_private.cairo_today()
  )
$$;

CREATE FUNCTION gym_private.derive_member_activation()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  NEW.is_active := NEW.deleted_at IS NULL AND NOT NEW.manually_deactivated
    AND gym_private.member_has_valid_membership(NEW.id, NEW.gym_id);
  IF TG_OP = 'UPDATE' THEN
    IF NEW.manually_deactivated IS DISTINCT FROM OLD.manually_deactivated
       AND NEW.activation_revision = OLD.activation_revision THEN
      NEW.activation_revision := OLD.activation_revision + 1;
    END IF;
    IF NEW.is_active IS DISTINCT FROM OLD.is_active
       OR NEW.manually_deactivated IS DISTINCT FROM OLD.manually_deactivated
       OR NEW.activation_revision IS DISTINCT FROM OLD.activation_revision THEN
      NEW.sync_version := OLD.sync_version + 1;
    END IF;
  END IF;
  RETURN NEW;
END
$$;

CREATE TRIGGER members_derive_activation
BEFORE INSERT OR UPDATE ON public.members
FOR EACH ROW EXECUTE FUNCTION gym_private.derive_member_activation();

-- Check relationships on every membership mutation, including direct REST
-- writes and old queued writes. RLS still authorizes the caller's actual gym.
CREATE FUNCTION gym_private.guard_membership_lifecycle()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE v_member public.members;
BEGIN
  IF TG_OP = 'UPDATE' AND
     (NEW.member_id IS DISTINCT FROM OLD.member_id OR NEW.gym_id IS DISTINCT FROM OLD.gym_id) THEN
    RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'MEMBERSHIP_PARENT_IMMUTABLE';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(NEW.member_id::text, 0));
  SELECT * INTO v_member FROM public.members
  WHERE id = NEW.member_id AND gym_id = NEW.gym_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'MEMBERSHIP_MEMBER_GYM_MISMATCH';
  END IF;
  IF TG_OP = 'INSERT' AND v_member.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'MEMBERSHIP_MEMBER_DELETED';
  END IF;
  IF NEW.plan_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.membership_plans p WHERE p.id = NEW.plan_id AND p.gym_id = NEW.gym_id
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'MEMBERSHIP_PLAN_GYM_MISMATCH';
  END IF;
  IF TG_OP = 'INSERT' AND NEW.plan_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.membership_plans p WHERE p.id = NEW.plan_id
      AND p.gym_id = NEW.gym_id AND p.is_active AND p.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'MEMBERSHIP_PLAN_UNAVAILABLE';
  END IF;
  IF NEW.status = 'active' AND NEW.end_date < gym_private.cairo_today() THEN
    NEW.status := 'expired';
  END IF;
  IF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
    NEW.sync_version := OLD.sync_version + 1;
  END IF;
  RETURN NEW;
END
$$;

CREATE TRIGGER memberships_lifecycle_guard
BEFORE INSERT OR UPDATE ON public.memberships
FOR EACH ROW EXECUTE FUNCTION gym_private.guard_membership_lifecycle();

CREATE FUNCTION gym_private.sync_member_after_membership()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE v_renewal boolean;
BEGIN
  -- Only a new, usable renewal overrides a manual deactivation.
  -- Replaying an existing UUID and editing old history do not clear it.
  v_renewal := TG_OP = 'INSERT' AND NEW.deleted_at IS NULL AND NEW.status = 'active'
    AND NEW.end_date >= gym_private.cairo_today();
  UPDATE public.members m SET
    manually_deactivated = CASE WHEN v_renewal THEN false ELSE m.manually_deactivated END,
    activation_revision = m.activation_revision + CASE WHEN v_renewal THEN 1 ELSE 0 END,
    is_active = gym_private.member_has_valid_membership(m.id, m.gym_id)
  WHERE m.id = NEW.member_id AND m.gym_id = NEW.gym_id
    AND (v_renewal OR m.is_active IS DISTINCT FROM (
      m.deleted_at IS NULL AND NOT m.manually_deactivated
      AND gym_private.member_has_valid_membership(m.id, m.gym_id)));
  RETURN NEW;
END
$$;

CREATE TRIGGER memberships_sync_member
AFTER INSERT OR UPDATE ON public.memberships
FOR EACH ROW EXECUTE FUNCTION gym_private.sync_member_after_membership();

CREATE FUNCTION gym_private.guard_payment_membership_gym()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.memberships s
      WHERE s.id = NEW.membership_id AND s.gym_id = NEW.gym_id) THEN
    RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'PAYMENT_MEMBERSHIP_GYM_MISMATCH';
  END IF;
  RETURN NEW;
END
$$;

CREATE TRIGGER payments_membership_gym_guard
BEFORE INSERT OR UPDATE OF membership_id, gym_id ON public.payments
FOR EACH ROW EXECUTE FUNCTION gym_private.guard_payment_membership_gym();

CREATE FUNCTION public.set_member_activation(
  p_member_id uuid, p_is_active boolean, p_expected_revision integer
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE v_member public.members;
BEGIN
  IF auth.uid() IS NULL OR p_is_active IS NULL OR p_expected_revision IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'MEMBER_ACTIVATION_NOT_AUTHORIZED';
  END IF;
  SELECT * INTO v_member FROM public.members
  WHERE id = p_member_id AND gym_id = public.current_user_gym_id()
    AND deleted_at IS NULL FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'MEMBER_ACTIVATION_NOT_AUTHORIZED';
  END IF;
  -- Lost-response retry: the desired manual state is already in place.
  IF v_member.manually_deactivated = NOT p_is_active THEN
    RETURN to_jsonb(v_member);
  END IF;
  IF v_member.activation_revision <> p_expected_revision THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'MEMBER_ACTIVATION_CHANGED_REFRESH_REQUIRED';
  END IF;
  UPDATE public.members SET manually_deactivated = NOT p_is_active
  WHERE id = v_member.id RETURNING * INTO v_member;
  RETURN to_jsonb(v_member);
END
$$;

REVOKE ALL ON FUNCTION public.set_member_activation(uuid, boolean, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_member_activation(uuid, boolean, integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.create_membership_with_initial_payment(p_membership jsonb, p_payment jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$

DECLARE

  v_membership public.memberships;

  v_payment public.payments;

  v_existing_membership public.memberships;

  v_existing_payment public.payments;

  v_membership_input public.memberships;

  v_payment_input public.payments;

BEGIN

  IF p_membership IS NULL THEN

    RAISE EXCEPTION USING

      ERRCODE = '22023',

      MESSAGE = 'MEMBERSHIP_ID_AND_MEMBER_ID_REQUIRED';

  END IF;

  v_membership_input := jsonb_populate_record(

    NULL::public.memberships,

    p_membership

  );

    IF v_membership_input.id IS NULL

      OR v_membership_input.gym_id IS NULL

      OR v_membership_input.member_id IS NULL

      OR v_membership_input.start_date IS NULL

      OR v_membership_input.end_date IS NULL THEN

    RAISE EXCEPTION USING

      ERRCODE = '22023',

      MESSAGE = 'MEMBERSHIP_ID_AND_MEMBER_ID_REQUIRED';

  END IF;

  IF auth.uid() IS NULL
     OR public.current_user_gym_id() IS NULL
     OR v_membership_input.gym_id IS DISTINCT FROM public.current_user_gym_id() THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501',
      MESSAGE = 'NOT_AUTHORIZED_FOR_MEMBERSHIP_GYM';
  END IF;

  -- Ensure the selected member belongs to the caller's gym.
  IF NOT EXISTS (
    SELECT 1
    FROM public.members AS m
    WHERE m.id = v_membership_input.member_id
      AND m.gym_id = v_membership_input.gym_id
      AND m.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = '23503',
      MESSAGE = 'MEMBERSHIP_MEMBER_GYM_MISMATCH';
  END IF;

  -- Never trust actor IDs supplied in client JSON.
  v_membership_input.created_by := auth.uid();

  IF v_membership_input.status::text IS DISTINCT FROM 'active'

     OR v_membership_input.deleted_at IS NOT NULL THEN

    RAISE EXCEPTION USING

      ERRCODE = '22023',

      MESSAGE = 'NEW_MEMBERSHIP_MUST_BE_ACTIVE';

  END IF;

  PERFORM pg_advisory_xact_lock(

    hashtextextended(v_membership_input.member_id::text, 0)

  );

  -- Reuse the client-generated ID for idempotent retry after a lost response.

  SELECT existing.*

    INTO v_existing_membership

  FROM public.memberships AS existing

  WHERE existing.id = v_membership_input.id;

  IF FOUND THEN

    IF v_existing_membership.member_id IS DISTINCT FROM

         v_membership_input.member_id

       OR v_existing_membership.gym_id IS DISTINCT FROM

         v_membership_input.gym_id

       OR v_existing_membership.plan_id IS DISTINCT FROM

         v_membership_input.plan_id

       OR v_existing_membership.start_date::date IS DISTINCT FROM

         v_membership_input.start_date::date

       OR v_existing_membership.end_date::date IS DISTINCT FROM

         v_membership_input.end_date::date

       OR v_existing_membership.price IS DISTINCT FROM

         v_membership_input.price

       OR (v_existing_membership.status IS DISTINCT FROM v_membership_input.status
           AND NOT (v_existing_membership.status = 'expired'
                    AND v_membership_input.status = 'active'
                    AND v_existing_membership.end_date < gym_private.cairo_today()))

       OR v_existing_membership.created_by IS DISTINCT FROM

         v_membership_input.created_by THEN

      RAISE EXCEPTION USING

        ERRCODE = '22023',

        MESSAGE = 'MEMBERSHIP_IDEMPOTENCY_KEY_REUSED';

    END IF;

    v_membership := v_existing_membership;

  ELSE

    INSERT INTO public.memberships (

      id, gym_id, member_id, plan_id, start_date, end_date, price, status,

      created_by, created_at, updated_at, deleted_at, sync_version

    ) VALUES (

      v_membership_input.id,

      v_membership_input.gym_id,

      v_membership_input.member_id,

      v_membership_input.plan_id,

      v_membership_input.start_date,

      v_membership_input.end_date,

      v_membership_input.price,

      v_membership_input.status,

      v_membership_input.created_by,

      COALESCE(v_membership_input.created_at, now()),

      COALESCE(v_membership_input.updated_at, now()),

      v_membership_input.deleted_at,

      COALESCE(v_membership_input.sync_version, 1)

    )

    RETURNING * INTO v_membership;

  END IF;

  IF p_payment IS NOT NULL THEN

     v_payment_input := jsonb_populate_record(NULL::public.payments, p_payment);
     v_payment_input.recorded_by := auth.uid();

     IF v_payment_input.id IS NULL

       OR v_payment_input.membership_id IS DISTINCT FROM v_membership.id

       OR v_payment_input.gym_id IS DISTINCT FROM v_membership.gym_id THEN

      RAISE EXCEPTION USING

        ERRCODE = '22023',

        MESSAGE = 'INITIAL_PAYMENT_ID_OR_MEMBERSHIP_MISMATCH';

    END IF;

    SELECT existing.*

      INTO v_existing_payment

    FROM public.payments AS existing

    WHERE existing.id = v_payment_input.id;

    IF FOUND THEN

      IF v_existing_payment.membership_id IS DISTINCT FROM

           v_membership.id

         OR v_existing_payment.gym_id IS DISTINCT FROM

           v_payment_input.gym_id

         OR v_existing_payment.amount IS DISTINCT FROM

           v_payment_input.amount

         OR v_existing_payment.payment_method IS DISTINCT FROM

           v_payment_input.payment_method

         OR v_existing_payment.paid_at IS DISTINCT FROM

           v_payment_input.paid_at

         OR v_existing_payment.recorded_by IS DISTINCT FROM

           v_payment_input.recorded_by

         OR v_existing_payment.notes IS DISTINCT FROM

           v_payment_input.notes THEN

        RAISE EXCEPTION USING

          ERRCODE = '22023',

          MESSAGE = 'PAYMENT_IDEMPOTENCY_KEY_REUSED';

      END IF;

      v_payment := v_existing_payment;

    ELSE

      INSERT INTO public.payments (

        id, gym_id, membership_id, amount, payment_method, paid_at,

        recorded_by, notes, created_at, updated_at, sync_version

      ) VALUES (

        v_payment_input.id,

        v_payment_input.gym_id,

        v_payment_input.membership_id,

        v_payment_input.amount,

        v_payment_input.payment_method,

        v_payment_input.paid_at,

        v_payment_input.recorded_by,

        v_payment_input.notes,

        COALESCE(v_payment_input.created_at, now()),

        COALESCE(v_payment_input.updated_at, now()),

        COALESCE(v_payment_input.sync_version, 1)

      )

      RETURNING * INTO v_payment;

    END IF;

  END IF;

  RETURN jsonb_build_object(

    'member', (SELECT to_jsonb(m) FROM public.members m WHERE m.id = v_membership.member_id AND m.gym_id = v_membership.gym_id),
    'membership', to_jsonb(v_membership),

    'payment', CASE WHEN p_payment IS NULL THEN NULL ELSE to_jsonb(v_payment) END

  );

END;

$function$
;

-- The scheduler runs as its job owner (postgres). No SECURITY DEFINER endpoint
-- or client-callable cross-gym processor is exposed.
CREATE TABLE gym_private.membership_lifecycle_runs (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  last_cairo_date date,
  last_completed_at timestamptz
);
ALTER TABLE gym_private.membership_lifecycle_runs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON gym_private.membership_lifecycle_runs FROM PUBLIC, anon, authenticated;
INSERT INTO gym_private.membership_lifecycle_runs(singleton) VALUES (true);

CREATE FUNCTION gym_private.reconcile_membership_lifecycle()
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_expired integer;
  v_members integer;
BEGIN
  UPDATE public.memberships SET status = 'expired'
  WHERE deleted_at IS NULL AND status = 'active'
    AND end_date < gym_private.cairo_today();
  GET DIAGNOSTICS v_expired = ROW_COUNT;

  UPDATE public.members m SET is_active = (
    m.deleted_at IS NULL AND NOT m.manually_deactivated
    AND gym_private.member_has_valid_membership(m.id, m.gym_id))
  WHERE m.is_active IS DISTINCT FROM (
    m.deleted_at IS NULL AND NOT m.manually_deactivated
    AND gym_private.member_has_valid_membership(m.id, m.gym_id));
  GET DIAGNOSTICS v_members = ROW_COUNT;

  RETURN jsonb_build_object('expired_memberships', v_expired, 'reconciled_members', v_members);
END
$$;

CREATE FUNCTION gym_private.run_membership_lifecycle()
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_day date := gym_private.cairo_today();
  v_last_day date;
  v_result jsonb;
BEGIN
  SELECT last_cairo_date INTO v_last_day
  FROM gym_private.membership_lifecycle_runs WHERE singleton FOR UPDATE;
  IF v_last_day >= v_day THEN
    RETURN jsonb_build_object('skipped', true, 'cairo_date', v_day);
  END IF;
  v_result := gym_private.reconcile_membership_lifecycle();
  UPDATE gym_private.membership_lifecycle_runs
  SET last_cairo_date = v_day, last_completed_at = statement_timestamp()
  WHERE singleton;
  RETURN v_result || jsonb_build_object('skipped', false, 'cairo_date', v_day);
END
$$;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA gym_private FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION gym_private.cairo_today() TO authenticated;
GRANT EXECUTE ON FUNCTION gym_private.member_has_valid_membership(uuid, uuid) TO authenticated;

-- Initial correction is transactional with the migration, preserving payments.
SELECT gym_private.run_membership_lifecycle();

-- CRON INSTALLATION BEGIN (tested separately on hosted Postgres)
CREATE EXTENSION IF NOT EXISTS pg_cron;
DO $schedule$
BEGIN
  -- Equivalent existing jobs must be reviewed instead of duplicated.
  IF EXISTS (SELECT 1 FROM cron.job
      WHERE command ILIKE '%membership%lifecycle%'
        AND jobname IS DISTINCT FROM 'gym-membership-lifecycle-cairo') THEN
    RAISE EXCEPTION 'Existing membership lifecycle job requires review';
  END IF;
  PERFORM cron.schedule(
    'gym-membership-lifecycle-cairo',
    '0 * * * *',
    'SELECT gym_private.run_membership_lifecycle();'
  );
END
$schedule$;
-- CRON INSTALLATION END

NOTIFY pgrst, 'reload schema';


