-- ==============================================================================
-- Migration: 20261109_relax_business_industry_check.sql
-- Description: Updates the CHECK constraint on businesses.business_industry to allow
--              extended industry categories if granular codes are submitted directly,
--              while maintaining backwards compatibility with core categories
--              ('fnb', 'barber', 'retail', 'services').
-- ==============================================================================

DO $$
BEGIN
  -- Drop existing strict check constraint if present
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'businesses_business_industry_check'
  ) THEN
    ALTER TABLE public.businesses DROP CONSTRAINT businesses_business_industry_check;
  END IF;

  -- Add relaxed check constraint allowing core 4 categories plus granular category group identifiers
  ALTER TABLE public.businesses
    ADD CONSTRAINT businesses_business_industry_check
    CHECK (
      business_industry IN (
        -- Core 4 pillars
        'fnb', 'barber', 'retail', 'services',
        -- Extended catalog categories
        'beauty', 'pets', 'automotive', 'home_services',
        'sports', 'health', 'education', 'professional',
        'restaurant', 'cafe', 'barbershop', 'salon', 'minimarket'
      )
    );
END $$;
