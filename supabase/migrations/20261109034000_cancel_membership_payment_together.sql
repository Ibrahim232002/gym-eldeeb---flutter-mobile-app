-- Cancel a mistakenly-created membership and its linked payment atomically.
-- Both rows remain available for audit; cancelled payments are excluded from revenue.
ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS is_cancelled boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS cancelled_at timestamptz,
  ADD COLUMN IF NOT EXISTS cancelled_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS cancellation_reason text;

CREATE INDEX IF NOT EXISTS payments_active_gym_paid_at_idx
  ON public.payments (gym_id, paid_at DESC)
  WHERE is_cancelled = false;

CREATE OR REPLACE FUNCTION public.cancel_membership_with_payment(p_membership_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_gym_id uuid := public.current_user_gym_id();
  v_membership public.memberships;
  v_cancelled_payments integer := 0;
BEGIN
  IF auth.uid() IS NULL OR v_gym_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'NOT_AUTHENTICATED';
  END IF;

  SELECT * INTO v_membership
  FROM public.memberships
  WHERE id = p_membership_id AND gym_id = v_gym_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'MEMBERSHIP_NOT_FOUND';
  END IF;

  IF v_membership.status = 'cancelled' THEN
    RETURN jsonb_build_object('membership_id', p_membership_id,
      'cancelled_payments', 0, 'already_cancelled', true);
  END IF;

  UPDATE public.memberships
  SET status = 'cancelled', updated_at = now()
  WHERE id = p_membership_id AND gym_id = v_gym_id;

  UPDATE public.payments
  SET is_cancelled = true,
      cancelled_at = COALESCE(cancelled_at, now()),
      cancelled_by = COALESCE(cancelled_by, auth.uid()),
      cancellation_reason = COALESCE(cancellation_reason, 'membership_cancelled'),
      updated_at = now()
  WHERE membership_id = p_membership_id
    AND gym_id = v_gym_id
    AND is_cancelled = false;

  GET DIAGNOSTICS v_cancelled_payments = ROW_COUNT;
  RETURN jsonb_build_object('membership_id', p_membership_id,
    'cancelled_payments', v_cancelled_payments, 'already_cancelled', false);
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_membership_with_payment(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_membership_with_payment(uuid) TO authenticated;
