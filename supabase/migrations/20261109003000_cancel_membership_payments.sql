-- Preserve financial audit history while voiding payments linked to cancelled records.
-- Deleting a membership is treated as a correction of an accidental subscription entry.
-- No payment, membership, or member rows are physically deleted.

ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS is_cancelled boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS cancelled_at timestamptz,
  ADD COLUMN IF NOT EXISTS cancelled_by uuid,
  ADD COLUMN IF NOT EXISTS cancellation_reason text;

CREATE INDEX IF NOT EXISTS payments_gym_membership_idx
  ON public.payments (gym_id, membership_id);

-- A soft-deleted membership voids every linked payment in the same transaction.
-- The payment row and its original amount/date/recorder remain available for audit.
CREATE OR REPLACE FUNCTION gym_private.cancel_payments_after_membership_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
    UPDATE public.payments AS p
    SET is_cancelled = true,
        cancelled_at = COALESCE(p.cancelled_at, NEW.deleted_at, statement_timestamp()),
        cancelled_by = COALESCE(p.cancelled_by, auth.uid()),
        cancellation_reason = COALESCE(p.cancellation_reason, 'membership_cancelled'),
        updated_at = statement_timestamp(),
        sync_version = p.sync_version + 1
    WHERE p.gym_id = NEW.gym_id
      AND p.membership_id = NEW.id
      AND p.is_cancelled = false;
  END IF;

  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION gym_private.cancel_payments_after_membership_delete()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS memberships_cancel_linked_payments
  ON public.memberships;

CREATE TRIGGER memberships_cancel_linked_payments
AFTER UPDATE OF deleted_at ON public.memberships
FOR EACH ROW
EXECUTE FUNCTION gym_private.cancel_payments_after_membership_delete();

-- If a member is soft-deleted after an accidental registration, cancel only
-- current/future memberships and their payments. Expired historical records
-- and legitimate historical revenue remain untouched.
CREATE OR REPLACE FUNCTION gym_private.cancel_current_memberships_after_member_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
    UPDATE public.memberships AS s
    SET status = 'cancelled',
        deleted_at = COALESCE(s.deleted_at, NEW.deleted_at, statement_timestamp()),
        updated_at = statement_timestamp(),
        sync_version = s.sync_version + 1
    WHERE s.gym_id = NEW.gym_id
      AND s.member_id = NEW.id
      AND s.deleted_at IS NULL
      AND s.status = 'active'
      AND s.end_date >= gym_private.cairo_today();
  END IF;

  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION gym_private.cancel_current_memberships_after_member_delete()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS members_cancel_current_memberships
  ON public.members;

CREATE TRIGGER members_cancel_current_memberships
AFTER UPDATE OF deleted_at ON public.members
FOR EACH ROW
EXECUTE FUNCTION gym_private.cancel_current_memberships_after_member_delete();

NOTIFY pgrst, 'reload schema';
