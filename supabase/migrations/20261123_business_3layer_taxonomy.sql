-- ==============================================================================
-- BUSINESS: 3-LAYER TAXONOMY CATEGORY GROUP & BOOKING MODE
-- Tarikh : 2026-11-23
-- Fail   : 20261123_business_3layer_taxonomy.sql
-- Description: Implements the clean 3-Layer Business Taxonomy on public.businesses:
--   1. category_group : Top-level discovery pillar (fnb, retail, beauty, stay,
--                       automotive, home_services, health, sports, pets,
--                       education, professional)
--   2. business_type  : Specific sub-type (restaurant, cafe_bakery, food_stall,
--                       kedai_makan, hotel, homestay, chalet, roomstay, resort,
--                       glamping, pet_hotel, barbershop, etc.)
--   3. booking_mode   : Operational booking engine ('none' | 'time_slot' | 'overnight')
-- Also backfills existing rows safely and relaxes business_industry check.
-- ==============================================================================

-- 1. Add the 3 structured columns (idempotent)
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS category_group TEXT,
  ADD COLUMN IF NOT EXISTS business_type  TEXT,
  ADD COLUMN IF NOT EXISTS booking_mode   TEXT DEFAULT 'none';

-- 2. Add CHECK constraint for booking_mode
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'businesses_booking_mode_check'
  ) THEN
    ALTER TABLE public.businesses DROP CONSTRAINT businesses_booking_mode_check;
  END IF;

  ALTER TABLE public.businesses
    ADD CONSTRAINT businesses_booking_mode_check
    CHECK (booking_mode IS NULL OR booking_mode IN ('none', 'time_slot', 'overnight'));
END $$;

-- 3. Relax business_industry CHECK constraint to support all top-level groups + legacy values
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'businesses_business_industry_check'
  ) THEN
    ALTER TABLE public.businesses DROP CONSTRAINT businesses_business_industry_check;
  END IF;

  ALTER TABLE public.businesses
    ADD CONSTRAINT businesses_business_industry_check
    CHECK (
      business_industry IS NULL OR business_industry IN (
        -- Legacy core 4 pillars
        'fnb', 'barber', 'retail', 'services',
        -- Extended category groups
        'stay', 'hospitality', 'beauty', 'pets', 'automotive',
        'home_services', 'sports', 'health', 'education', 'professional',
        -- Legacy granular values
        'restaurant', 'cafe', 'barbershop', 'salon', 'minimarket', 'hotel', 'homestay'
      )
    );
END $$;

-- 4. Backfill business_type from business_settings.operating_hours->>'business_type' if present
UPDATE public.businesses b
SET business_type = LOWER(TRIM(bs.operating_hours->>'business_type'))
FROM public.business_settings bs
WHERE bs.business_id = b.id
  AND (b.business_type IS NULL OR TRIM(b.business_type) = '')
  AND bs.operating_hours ? 'business_type'
  AND NULLIF(TRIM(bs.operating_hours->>'business_type'), '') IS NOT NULL;

-- 5. Fallback backfill business_type from business_industry / business_name
UPDATE public.businesses
SET business_type = CASE
  WHEN LOWER(COALESCE(business_name, '')) ~ '(hotel kucing|cat hotel|pet hotel|asrama kucing|cattery)' THEN 'pet_hotel'
  WHEN LOWER(COALESCE(business_name, '')) ~ '(grooming|dandanan haiwan|spa kucing)' THEN 'pet_grooming'
  WHEN LOWER(COALESCE(business_name, '')) ~ '(homestay)' THEN 'homestay'
  WHEN LOWER(COALESCE(business_name, '')) ~ '(chalet)' THEN 'chalet'
  WHEN LOWER(COALESCE(business_name, '')) ~ '(roomstay)' THEN 'roomstay'
  WHEN LOWER(COALESCE(business_name, '')) ~ '(resort)' THEN 'resort'
  WHEN LOWER(COALESCE(business_name, '')) ~ '(glamping)' THEN 'glamping'
  WHEN LOWER(COALESCE(business_name, '')) ~ '(hotel|motel|lodge|villa)' THEN 'hotel'
  WHEN LOWER(COALESCE(business_industry, '')) IN ('fnb', 'restaurant') THEN 'restaurant'
  WHEN LOWER(COALESCE(business_industry, '')) IN ('cafe', 'bakery') THEN 'cafe_bakery'
  WHEN LOWER(COALESCE(business_industry, '')) IN ('barber', 'barbershop') THEN 'barbershop'
  WHEN LOWER(COALESCE(business_industry, '')) IN ('salon', 'beauty') THEN 'muslimah_salon'
  WHEN LOWER(COALESCE(business_industry, '')) IN ('retail', 'minimarket') THEN 'minimarket'
  WHEN LOWER(COALESCE(business_industry, '')) = 'pets' THEN 'pet_hotel'
  WHEN LOWER(COALESCE(business_industry, '')) IN ('stay', 'hospitality') THEN 'hotel'
  ELSE 'home_cleaning'
END
WHERE business_type IS NULL OR TRIM(business_type) = '';

-- 6. Backfill category_group from business_type
UPDATE public.businesses
SET category_group = CASE
  WHEN business_type IN ('restaurant', 'cafe_bakery', 'food_stall', 'kedai_makan', 'food_truck', 'catering', 'dessert_drinks') THEN 'fnb'
  WHEN business_type IN ('hotel', 'homestay', 'chalet', 'roomstay', 'resort', 'glamping') THEN 'stay'
  WHEN business_type IN ('minimarket', 'fresh_market', 'florist', 'boutique_fashion', 'jewelry_gold') THEN 'retail'
  WHEN business_type IN ('barbershop', 'muslimah_salon', 'spa_massage', 'nail_lash', 'aesthetic_clinic') THEN 'beauty'
  WHEN business_type IN ('carwash', 'detailing', 'workshop', 'tyre_battery', 'tint_accessories', 'motorcycle_shop') THEN 'automotive'
  WHEN business_type IN ('aircond_service', 'home_cleaning', 'plumbing_electric', 'laundry_dobi', 'renovation_contractor', 'pest_control') THEN 'home_services'
  WHEN business_type IN ('medical_clinic', 'dental_clinic', 'physiotherapy', 'optical_shop', 'pharmacy', 'acupuncture_hijama') THEN 'health'
  WHEN business_type IN ('badminton_court', 'pickleball_court', 'fitness_gym', 'yoga_pilates', 'swimming_academy') THEN 'sports'
  WHEN business_type IN ('pet_hotel', 'pet_grooming', 'pet_clinic', 'pet_shop', 'pet_cafe') THEN 'pets'
  WHEN business_type IN ('tuition_center', 'quran_class', 'kindergarten_daycare', 'music_art', 'driving_school') THEN 'education'
  WHEN business_type IN ('photography_studio', 'printing_banner', 'gadget_repair', 'coworking_space', 'event_hall') THEN 'professional'
  WHEN LOWER(COALESCE(business_industry, '')) = 'fnb' THEN 'fnb'
  WHEN LOWER(COALESCE(business_industry, '')) = 'barber' THEN 'beauty'
  WHEN LOWER(COALESCE(business_industry, '')) = 'retail' THEN 'retail'
  ELSE 'home_services'
END
WHERE category_group IS NULL OR TRIM(category_group) = '';

-- 7. Backfill booking_mode ('none' | 'time_slot' | 'overnight') from business_type
UPDATE public.businesses
SET booking_mode = CASE
  WHEN business_type IN ('hotel', 'homestay', 'chalet', 'roomstay', 'resort', 'glamping', 'pet_hotel') THEN 'overnight'
  WHEN business_type IN (
    'barbershop', 'muslimah_salon', 'spa_massage', 'nail_lash', 'aesthetic_clinic',
    'carwash', 'detailing', 'workshop', 'tyre_battery', 'tint_accessories', 'motorcycle_shop',
    'aircond_service', 'home_cleaning', 'plumbing_electric', 'renovation_contractor', 'pest_control',
    'medical_clinic', 'dental_clinic', 'physiotherapy', 'acupuncture_hijama',
    'badminton_court', 'pickleball_court', 'fitness_gym', 'yoga_pilates', 'swimming_academy',
    'pet_grooming', 'pet_clinic',
    'tuition_center', 'quran_class', 'kindergarten_daycare', 'music_art', 'driving_school',
    'photography_studio', 'gadget_repair', 'coworking_space', 'event_hall',
    'restaurant', 'catering', 'pet_cafe'
  ) THEN 'time_slot'
  ELSE 'none'
END
WHERE booking_mode IS NULL OR TRIM(booking_mode) = '' OR booking_mode = 'none';

-- 8. Performance indexes for customer discovery & filtering
CREATE INDEX IF NOT EXISTS idx_businesses_category_group ON public.businesses (category_group);
CREATE INDEX IF NOT EXISTS idx_businesses_business_type  ON public.businesses (business_type);
CREATE INDEX IF NOT EXISTS idx_businesses_booking_mode   ON public.businesses (booking_mode);
