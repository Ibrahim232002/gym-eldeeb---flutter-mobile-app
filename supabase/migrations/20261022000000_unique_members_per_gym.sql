-- Enforce normalized member-name and phone uniqueness per gym.
-- Preflight aborts with duplicate member IDs; existing rows are never changed.

DO $schema_check$
DECLARE
  required_column text;
BEGIN
  IF to_regclass('public.members') IS NULL THEN
    RAISE EXCEPTION 'Expected public.members table before adding member uniqueness';
  END IF;

  FOREACH required_column IN ARRAY ARRAY[
    'id', 'gym_id', 'full_name', 'phone', 'deleted_at'
  ] LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'members'
        AND column_name = required_column
    ) THEN
      RAISE EXCEPTION 'Missing public.members column required for uniqueness: %',
        required_column;
    END IF;
  END LOOP;
END
$schema_check$;

CREATE OR REPLACE FUNCTION public.normalize_member_name_for_uniqueness(value text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $function$
  SELECT lower(regexp_replace(btrim(coalesce(value, '')), '[[:space:]]+', ' ', 'g'));
$function$;

CREATE OR REPLACE FUNCTION public.normalize_member_phone_for_uniqueness(value text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
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
$function$;

DO $duplicate_check$
DECLARE
  duplicate_groups text;
BEGIN
  SELECT string_agg(
    format('gym=%s member_ids=[%s]', gym_id, member_ids),
    '; '
  )
  INTO duplicate_groups
  FROM (
    SELECT
      gym_id,
      string_agg(id::text, ',' ORDER BY id) AS member_ids
    FROM public.members
    WHERE deleted_at IS NULL
      AND public.normalize_member_name_for_uniqueness(full_name) <> ''
    GROUP BY
      gym_id,
      public.normalize_member_name_for_uniqueness(full_name)
    HAVING count(*) > 1
  ) duplicate_names;

  IF duplicate_groups IS NOT NULL THEN
    RAISE EXCEPTION
      'Duplicate normalized member names already exist; resolve them manually without deleting linked data. %',
      duplicate_groups;
  END IF;

  SELECT string_agg(
    format('gym=%s member_ids=[%s]', gym_id, member_ids),
    '; '
  )
  INTO duplicate_groups
  FROM (
    SELECT
      gym_id,
      string_agg(id::text, ',' ORDER BY id) AS member_ids
    FROM public.members
    WHERE deleted_at IS NULL
      AND public.normalize_member_phone_for_uniqueness(phone) <> ''
    GROUP BY
      gym_id,
      public.normalize_member_phone_for_uniqueness(phone)
    HAVING count(*) > 1
  ) duplicate_phones;

  IF duplicate_groups IS NOT NULL THEN
    RAISE EXCEPTION
      'Duplicate normalized member phones already exist; resolve them manually without deleting linked data. %',
      duplicate_groups;
  END IF;
END
$duplicate_check$;

CREATE UNIQUE INDEX members_unique_name_per_gym
  ON public.members (
    gym_id,
    public.normalize_member_name_for_uniqueness(full_name)
  )
  WHERE deleted_at IS NULL
    AND public.normalize_member_name_for_uniqueness(full_name) <> '';

CREATE UNIQUE INDEX members_unique_phone_per_gym
  ON public.members (
    gym_id,
    public.normalize_member_phone_for_uniqueness(phone)
  )
  WHERE deleted_at IS NULL
    AND public.normalize_member_phone_for_uniqueness(phone) <> '';
