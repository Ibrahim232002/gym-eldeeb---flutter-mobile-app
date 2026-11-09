-- ISOLATED TEST FIXTURE ONLY. Schema captured from the live audit, no real rows.
-- Never apply this file to a hosted project.
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE ROLE service_role BYPASSRLS;
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
$$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
GRANT USAGE ON SCHEMA auth TO authenticated, anon;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated, anon;
CREATE EXTENSION btree_gist;
CREATE TABLE public.gyms (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "name" text NOT NULL,
  "phone" text,
  "currency" text NOT NULL DEFAULT 'EGP'::text,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE public.profiles (
  "id" uuid NOT NULL,
  "gym_id" uuid NOT NULL,
  "full_name" text NOT NULL,
  "role" text NOT NULL DEFAULT 'coach'::text,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE public.members (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "gym_id" uuid NOT NULL,
  "full_name" text NOT NULL,
  "phone" text,
  "notes" text,
  "join_date" date NOT NULL DEFAULT CURRENT_DATE,
  "is_active" boolean NOT NULL DEFAULT true,
  "created_by" uuid,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "deleted_at" timestamp with time zone,
  "sync_version" integer NOT NULL DEFAULT 1,
  "legacy_ref" text,
  "photo_path" text
);
CREATE TABLE public.membership_plans (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "gym_id" uuid NOT NULL,
  "name" text NOT NULL,
  "duration_days" integer NOT NULL DEFAULT 30,
  "price" numeric NOT NULL DEFAULT 0,
  "is_active" boolean NOT NULL DEFAULT true,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "deleted_at" timestamp with time zone,
  "sync_version" integer NOT NULL DEFAULT 1
);
CREATE TABLE public.memberships (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "gym_id" uuid NOT NULL,
  "member_id" uuid NOT NULL,
  "plan_id" uuid,
  "start_date" date NOT NULL,
  "end_date" date NOT NULL,
  "price" numeric NOT NULL DEFAULT 0,
  "status" text NOT NULL DEFAULT 'active'::text,
  "created_by" uuid,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "deleted_at" timestamp with time zone,
  "sync_version" integer NOT NULL DEFAULT 1
);
CREATE TABLE public.payments (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "gym_id" uuid NOT NULL,
  "membership_id" uuid NOT NULL,
  "amount" numeric NOT NULL,
  "payment_method" text NOT NULL DEFAULT 'cash'::text,
  "paid_at" timestamp with time zone NOT NULL DEFAULT now(),
  "recorded_by" uuid,
  "notes" text,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  "sync_version" integer NOT NULL DEFAULT 1
);
CREATE TABLE public.sync_metadata (
  "user_id" uuid NOT NULL,
  "gym_id" uuid NOT NULL,
  "last_synced_at" timestamp with time zone,
  "updated_at" timestamp with time zone NOT NULL DEFAULT now()
);
CREATE TABLE public.gym_invites (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "gym_id" uuid NOT NULL,
  "invite_code" text NOT NULL,
  "max_uses" integer NOT NULL DEFAULT 2,
  "used_count" integer NOT NULL DEFAULT 0,
  "is_active" boolean NOT NULL DEFAULT true,
  "expires_at" timestamp with time zone,
  "created_at" timestamp with time zone NOT NULL DEFAULT now()
);
ALTER TABLE public."members" ADD CONSTRAINT "members_pkey" PRIMARY KEY (id);
ALTER TABLE public."gyms" ADD CONSTRAINT "gyms_pkey" PRIMARY KEY (id);
ALTER TABLE public."profiles" ADD CONSTRAINT "profiles_pkey" PRIMARY KEY (id);
ALTER TABLE public."membership_plans" ADD CONSTRAINT "membership_plans_pkey" PRIMARY KEY (id);
ALTER TABLE public."memberships" ADD CONSTRAINT "memberships_pkey" PRIMARY KEY (id);
ALTER TABLE public."payments" ADD CONSTRAINT "payments_pkey" PRIMARY KEY (id);
ALTER TABLE public."sync_metadata" ADD CONSTRAINT "sync_metadata_pkey" PRIMARY KEY (user_id);
ALTER TABLE public."gym_invites" ADD CONSTRAINT "gym_invites_pkey" PRIMARY KEY (id);
ALTER TABLE public."gym_invites" ADD CONSTRAINT "gym_invites_invite_code_key" UNIQUE (invite_code);
ALTER TABLE public."profiles" ADD CONSTRAINT "profiles_gym_id_fkey" FOREIGN KEY (gym_id) REFERENCES gyms(id) ON DELETE RESTRICT;
ALTER TABLE public."members" ADD CONSTRAINT "members_gym_id_fkey" FOREIGN KEY (gym_id) REFERENCES gyms(id) ON DELETE RESTRICT;
ALTER TABLE public."members" ADD CONSTRAINT "members_created_by_fkey" FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public."profiles" ADD CONSTRAINT "profiles_role_check" CHECK ((role = ANY (ARRAY['owner'::text, 'coach'::text])));
ALTER TABLE public."profiles" ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public."membership_plans" ADD CONSTRAINT "membership_plans_duration_days_check" CHECK ((duration_days > 0));
ALTER TABLE public."membership_plans" ADD CONSTRAINT "membership_plans_price_check" CHECK ((price >= (0)::numeric));
ALTER TABLE public."membership_plans" ADD CONSTRAINT "membership_plans_gym_id_fkey" FOREIGN KEY (gym_id) REFERENCES gyms(id) ON DELETE RESTRICT;
ALTER TABLE public."memberships" ADD CONSTRAINT "memberships_price_check" CHECK ((price >= (0)::numeric));
ALTER TABLE public."memberships" ADD CONSTRAINT "memberships_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'expired'::text, 'cancelled'::text])));
ALTER TABLE public."memberships" ADD CONSTRAINT "valid_membership_dates" CHECK ((end_date >= start_date));
ALTER TABLE public."memberships" ADD CONSTRAINT "memberships_gym_id_fkey" FOREIGN KEY (gym_id) REFERENCES gyms(id) ON DELETE RESTRICT;
ALTER TABLE public."memberships" ADD CONSTRAINT "memberships_member_id_fkey" FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE RESTRICT;
ALTER TABLE public."memberships" ADD CONSTRAINT "memberships_plan_id_fkey" FOREIGN KEY (plan_id) REFERENCES membership_plans(id) ON DELETE SET NULL;
ALTER TABLE public."memberships" ADD CONSTRAINT "memberships_created_by_fkey" FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public."payments" ADD CONSTRAINT "payments_amount_check" CHECK ((amount > (0)::numeric));
ALTER TABLE public."payments" ADD CONSTRAINT "payments_gym_id_fkey" FOREIGN KEY (gym_id) REFERENCES gyms(id) ON DELETE RESTRICT;
ALTER TABLE public."payments" ADD CONSTRAINT "payments_membership_id_fkey" FOREIGN KEY (membership_id) REFERENCES memberships(id) ON DELETE RESTRICT;
ALTER TABLE public."payments" ADD CONSTRAINT "payments_recorded_by_fkey" FOREIGN KEY (recorded_by) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE public."sync_metadata" ADD CONSTRAINT "sync_metadata_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public."sync_metadata" ADD CONSTRAINT "sync_metadata_gym_id_fkey" FOREIGN KEY (gym_id) REFERENCES gyms(id) ON DELETE CASCADE;
ALTER TABLE public."gym_invites" ADD CONSTRAINT "gym_invites_max_uses_check" CHECK ((max_uses > 0));
ALTER TABLE public."gym_invites" ADD CONSTRAINT "gym_invites_used_count_check" CHECK ((used_count >= 0));
ALTER TABLE public."gym_invites" ADD CONSTRAINT "gym_invites_gym_id_fkey" FOREIGN KEY (gym_id) REFERENCES gyms(id) ON DELETE CASCADE;
ALTER TABLE public."memberships" ADD CONSTRAINT "memberships_no_overlapping_active_periods" EXCLUDE USING gist (member_id WITH =, daterange(start_date, end_date, '[]'::text) WITH &&) WHERE (((status = 'active'::text) AND (deleted_at IS NULL)));
ALTER TABLE public."payments" ADD CONSTRAINT "payments_payment_method_check" CHECK ((payment_method = ANY (ARRAY['cash'::text, 'vodafone_cash'::text, 'instapay'::text, 'card'::text])));
CREATE OR REPLACE FUNCTION public.claim_gym_invite(p_user_id uuid, p_full_name text, p_invite_code text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
    v_gym_id uuid;
    v_max_uses integer;
    v_used_count integer;
    v_is_active boolean;
    v_expires_at timestamptz;
begin
    if p_user_id is null
       or p_full_name is null
       or length(trim(p_full_name)) = 0
       or length(trim(p_full_name)) > 100 then
        raise exception 'Invalid input';
    end if;

    select gym_id, max_uses, used_count, is_active, expires_at
    into v_gym_id, v_max_uses, v_used_count, v_is_active, v_expires_at
    from public.gym_invites
    where invite_code = trim(p_invite_code)
    for update;

    if not found
       or not v_is_active
       or v_used_count >= v_max_uses
       or (v_expires_at is not null and v_expires_at <= now()) then
        raise exception 'Invalid or expired invite';
    end if;

    if exists (
        select 1 from public.profiles where id = p_user_id
    ) then
        raise exception 'Profile already exists';
    end if;

    insert into public.profiles (id, gym_id, full_name, role)
    values (p_user_id, v_gym_id, trim(p_full_name), 'owner');

    update public.gym_invites
    set used_count = used_count + 1
    where invite_code = trim(p_invite_code);

    return v_gym_id;
end;
$function$
;
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

    'membership', to_jsonb(v_membership),

    'payment', CASE WHEN p_payment IS NULL THEN NULL ELSE to_jsonb(v_payment) END

  );

END;

$function$
;
CREATE OR REPLACE FUNCTION public.current_user_gym_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
    select gym_id
    from public.profiles
    where id = (select auth.uid())
    limit 1;
$function$
;
CREATE OR REPLACE FUNCTION public.normalize_member_name_for_uniqueness(value text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
AS $function$
  SELECT lower(
    regexp_replace(
      btrim(coalesce(value, '')),
      '[[:space:]]+',
      ' ',
      'g'
    )
  );
$function$
;
CREATE OR REPLACE FUNCTION public.normalize_member_phone_for_uniqueness(value text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
AS $function$
  WITH digits AS (
    SELECT regexp_replace(
      translate(
        coalesce(value, ''),
        '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹',
        '01234567890123456789'
      ),
      '[^0-9]',
      '',
      'g'
    ) AS number
  )
  SELECT CASE
    WHEN number LIKE '00%' THEN substr(number, 3)
    WHEN number LIKE '01%' AND length(number) = 11
      THEN '20' || substr(number, 2)
    WHEN number LIKE '1%' AND length(number) = 10
      THEN '20' || number
    ELSE number
  END
  FROM digits;
$function$
;
CREATE OR REPLACE FUNCTION public.prevent_overlapping_active_memberships()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
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

$function$
;
CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
    new.updated_at = now();
    return new;
end;
$function$
;
CREATE TRIGGER gyms_updated_at BEFORE UPDATE ON public.gyms FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER members_updated_at BEFORE UPDATE ON public.members FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER plans_updated_at BEFORE UPDATE ON public.membership_plans FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER memberships_updated_at BEFORE UPDATE ON public.memberships FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER payments_updated_at BEFORE UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER memberships_prevent_overlapping_active BEFORE INSERT OR UPDATE OF member_id, gym_id, start_date, end_date, status, deleted_at ON public.memberships FOR EACH ROW EXECUTE FUNCTION prevent_overlapping_active_memberships();
ALTER TABLE public.gyms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.membership_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gym_invites ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Gym payments access" ON public."payments" AS PERMISSIVE FOR ALL TO "authenticated" USING ((gym_id = ( SELECT current_user_gym_id() AS current_user_gym_id))) WITH CHECK ((gym_id = ( SELECT current_user_gym_id() AS current_user_gym_id)));
CREATE POLICY "Users can update own profile" ON public."profiles" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((id = ( SELECT auth.uid() AS uid))) WITH CHECK (((id = ( SELECT auth.uid() AS uid)) AND (gym_id = ( SELECT current_user_gym_id() AS current_user_gym_id))));
CREATE POLICY "Users can view gym profiles" ON public."profiles" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((gym_id = ( SELECT current_user_gym_id() AS current_user_gym_id)));
CREATE POLICY "Owners can update own gym" ON public."gyms" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (((id = ( SELECT current_user_gym_id() AS current_user_gym_id)) AND (EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = ( SELECT auth.uid() AS uid)) AND (p.role = 'owner'::text)))))) WITH CHECK ((id = ( SELECT current_user_gym_id() AS current_user_gym_id)));
CREATE POLICY "Users can view own gym" ON public."gyms" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((id = ( SELECT current_user_gym_id() AS current_user_gym_id)));
CREATE POLICY "Gym plans access" ON public."membership_plans" AS PERMISSIVE FOR ALL TO "authenticated" USING ((gym_id = ( SELECT current_user_gym_id() AS current_user_gym_id))) WITH CHECK ((gym_id = ( SELECT current_user_gym_id() AS current_user_gym_id)));
CREATE POLICY "Gym memberships access" ON public."memberships" AS PERMISSIVE FOR ALL TO "authenticated" USING ((gym_id = ( SELECT current_user_gym_id() AS current_user_gym_id))) WITH CHECK ((gym_id = ( SELECT current_user_gym_id() AS current_user_gym_id)));
CREATE POLICY "Users manage own sync metadata" ON public."sync_metadata" AS PERMISSIVE FOR ALL TO "authenticated" USING ((user_id = ( SELECT auth.uid() AS uid))) WITH CHECK (((user_id = ( SELECT auth.uid() AS uid)) AND (gym_id = ( SELECT current_user_gym_id() AS current_user_gym_id))));
CREATE POLICY "Gym members access" ON public."members" AS PERMISSIVE FOR ALL TO "authenticated" USING ((gym_id = ( SELECT current_user_gym_id() AS current_user_gym_id))) WITH CHECK ((gym_id = ( SELECT current_user_gym_id() AS current_user_gym_id)));
GRANT ALL ON public.gyms, public.members, public.memberships, public.membership_plans, public.payments, public.sync_metadata TO authenticated, anon, service_role;
GRANT SELECT ON public.profiles TO authenticated;
GRANT UPDATE(full_name,updated_at) ON public.profiles TO authenticated;
REVOKE ALL ON FUNCTION public.create_membership_with_initial_payment(jsonb,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.create_membership_with_initial_payment(jsonb,jsonb) TO authenticated;

