-- =============================================================================
-- Ngam — Customer booking hardening (soft launch)           2026-10-30
-- Run in: Supabase Dashboard → SQL Editor.
--
-- ORDER OF OPERATIONS
--   STEP 1  (safe — run NOW, before/with the new app release)
--   STEP 2  (run AFTER the new customer app/PWA is live — it removes the public
--            read access to the bookings table, so old app versions would stop
--            seeing booked slots)
--   STEP 3  (optional — hard guarantee against double-booking at DB level)
-- =============================================================================


-- ───────────────────────── STEP 1 ─────────────────────────

-- 1a. A customer must be able to promote their own slot hold → 'pending'.
--     (The old WITH CHECK allowed ONLY status='cancelled', so confirming a
--      booking was silently rejected and rows stayed in 'holding'.)
DROP POLICY IF EXISTS "Users can update own booking" ON public.bookings;
CREATE POLICY "Users can update own booking"
  ON public.bookings FOR UPDATE TO authenticated
  USING (
    (customer_id = auth.uid() OR (booking_metadata->>'customer_auth_id') = auth.uid()::text)
    AND status IN ('holding', 'pending')
  )
  WITH CHECK (
    (customer_id = auth.uid() OR (booking_metadata->>'customer_auth_id') = auth.uid()::text)
    AND status IN ('holding', 'pending', 'cancelled')
  );

-- 1b. A customer may delete their own *unconfirmed hold* (releases the slot).
DROP POLICY IF EXISTS "Users can delete own holds" ON public.bookings;
CREATE POLICY "Users can delete own holds"
  ON public.bookings FOR DELETE TO authenticated
  USING (
    status = 'holding'
    AND (customer_id = auth.uid() OR (booking_metadata->>'customer_auth_id') = auth.uid()::text)
  );

-- 1c. Privacy-safe slot availability (NO names / phones / notes are exposed).
CREATE OR REPLACE FUNCTION public.get_booked_slots(p_business_id uuid)
RETURNS TABLE (
  id               uuid,
  booking_date     date,
  booking_time     varchar,
  staff_id         uuid,
  status           varchar,
  created_at       timestamptz,
  booking_metadata jsonb
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    b.id,
    b.booking_date,
    b.booking_time::varchar,
    b.staff_id,
    b.status::varchar,
    b.created_at,
    jsonb_build_object(
      'provider_name', b.booking_metadata->>'provider_name',
      'staff_id',      b.booking_metadata->>'staff_id'
    )
  FROM public.bookings b
  WHERE b.business_id = p_business_id
    AND b.booking_date >= CURRENT_DATE
    AND b.status NOT IN ('cancelled', 'rejected', 'declined', 'no_show')
    AND NOT (b.status = 'holding' AND b.created_at < now() - interval '10 minutes');
$$;

REVOKE ALL ON FUNCTION public.get_booked_slots(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.get_booked_slots(uuid) TO anon, authenticated;

-- 1d. Housekeeping: abandoned holds older than 1 day (run occasionally / via cron).
-- DELETE FROM public.bookings WHERE status = 'holding' AND created_at < now() - interval '1 day';


-- ───────────────────────── STEP 2 ─────────────────────────
-- Run only after the new customer app is deployed.
-- Today ANY visitor (even logged-out) can read EVERY booking incl. customer
-- names + phone numbers (booking_metadata). This closes that PDPA exposure.
--
-- (Merchant app is unaffected: it uses the "Business manage bookings" policy.)
-- If you have a separate admin app that reads bookings with a normal login
-- (not service-role), add a super-admin SELECT policy for it before running.

-- DROP POLICY IF EXISTS "Public can view bookings for slot check" ON public.bookings;
-- DROP POLICY IF EXISTS "Customers read own bookings" ON public.bookings;
-- CREATE POLICY "Customers read own bookings"
--   ON public.bookings FOR SELECT TO authenticated
--   USING (
--     customer_id = auth.uid()
--     OR (booking_metadata->>'customer_auth_id') = auth.uid()::text
--   );


-- ───────────────────────── STEP 3 (optional) ─────────────────────────
-- Hard double-booking guard: one active booking per business + date + time +
-- staff (NULL staff = "any staff"). First check for existing duplicates:
--
--   SELECT business_id, booking_date, booking_time, staff_id, count(*)
--   FROM public.bookings
--   WHERE status NOT IN ('cancelled','rejected','declined','no_show','completed')
--   GROUP BY 1,2,3,4 HAVING count(*) > 1;
--
-- If that returns no rows:
--
-- CREATE UNIQUE INDEX IF NOT EXISTS uq_bookings_active_slot
--   ON public.bookings (
--     business_id, booking_date, booking_time,
--     COALESCE(staff_id, '00000000-0000-0000-0000-000000000000'::uuid)
--   )
--   WHERE status IN ('holding', 'pending', 'confirmed', 'in_progress', 'preparing', 'ready');
--
-- NOTE: this also blocks a merchant from manually adding two walk-ins in the same
-- slot for the same staff. Skip this step if your businesses allow parallel
-- bookings (e.g. restaurants with many tables).
