-- Prevent active membership windows from overlapping for the same stable member ID.
-- End dates are inclusive; a renewal may begin the following calendar day.
-- Existing membership and payment rows are intentionally never modified or deleted.

DO $migration$
DECLARE
  required_column text;
BEGIN
  IF to_regclass('public.memberships') IS NULL
     OR to_regclass('public.payments') IS NULL THEN
    RAISE EXCEPTION 'Expected public.memberships and public.payments tables';
  END IF;

  FOREACH required_column IN ARRAY ARRAY[
    'id', 'gym_id', 'member_id', 'plan_id', 'start_date', 'end_date',
    'price', 'status', 'created_by', 'created_at', 'updated_at',
    'deleted_at', 'sync_version'
  ] LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'memberships'
        AND column_name = required_column
    ) THEN
      RAISE EXCEPTION 'Missing public.memberships column: %', required_column;
    END IF;
  END LOOP;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'memberships'
      AND column_name IN ('start_date', 'end_date')
      AND data_type <> 'date'
  ) THEN
    RAISE EXCEPTION
      'public.memberships start_date/end_date must be date columns for inclusive calendar overlap enforcement';
  END IF;

  FOREACH required_column IN ARRAY ARRAY[
    'id', 'gym_id', 'membership_id', 'amount', 'payment_method', 'paid_at',
    'recorded_by', 'notes', 'created_at', 'updated_at', 'sync_version'
  ] LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'payments'
        AND column_name = required_column
    ) THEN
      RAISE EXCEPTION 'Missing public.payments column: %', required_column;
    END IF;
  END LOOP;
END;
$migration$;

CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE public.memberships
  ADD CONSTRAINT memberships_no_overlapping_active_periods
  EXCLUDE USING gist (
    member_id WITH =,
    (daterange(start_date::date, end_date::date, '[]')) WITH &&
  )
  WHERE (status = 'active' AND deleted_at IS NULL);

CREATE OR REPLACE FUNCTION public.prevent_overlapping_active_memberships()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
BEGIN
  IF NEW.status = 'active' AND NEW.deleted_at IS NULL THEN
    IF NEW.member_id IS NULL
       OR NEW.gym_id IS NULL
       OR NEW.start_date IS NULL
       OR NEW.end_date IS NULL THEN
      RAISE EXCEPTION USING
        ERRCODE = '23502',
        MESSAGE = 'ACTIVE_MEMBERSHIP_MEMBER_GYM_AND_DATES_REQUIRED';
    END IF;

    IF NEW.start_date::date > NEW.end_date::date THEN
      RAISE EXCEPTION USING
        ERRCODE = '22007',
        MESSAGE = 'MEMBERSHIP_START_AFTER_END';
    END IF;

    -- Serialize active-window checks per member so concurrent writes cannot race.
    PERFORM pg_advisory_xact_lock(hashtextextended(NEW.member_id::text, 0));

    IF EXISTS (
      SELECT 1
      FROM public.memberships AS existing
      WHERE existing.member_id = NEW.member_id
        AND existing.id IS DISTINCT FROM NEW.id
        AND existing.status = 'active'
        AND existing.deleted_at IS NULL
        AND daterange(
              existing.start_date::date,
              existing.end_date::date,
              '[]'
            ) && daterange(NEW.start_date::date, NEW.end_date::date, '[]')
    ) THEN
      RAISE EXCEPTION USING
        ERRCODE = '23P01',
        MESSAGE = 'ACTIVE_MEMBERSHIP_OVERLAP';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.prevent_overlapping_active_memberships()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS memberships_prevent_overlapping_active
  ON public.memberships;
CREATE TRIGGER memberships_prevent_overlapping_active
  BEFORE INSERT OR UPDATE OF member_id, start_date, end_date, status, deleted_at
  ON public.memberships
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_overlapping_active_memberships();

CREATE OR REPLACE FUNCTION public.create_membership_with_initial_payment(
  p_membership jsonb,
  p_payment jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
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
       OR v_existing_membership.status IS DISTINCT FROM
         v_membership_input.status
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
    'membership', to_jsonb(v_membership),
    'payment', CASE WHEN p_payment IS NULL THEN NULL ELSE to_jsonb(v_payment) END
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.create_membership_with_initial_payment(jsonb, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_membership_with_initial_payment(jsonb, jsonb)
  TO authenticated;
