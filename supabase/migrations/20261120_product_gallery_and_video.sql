-- =========================================================================================
-- NGAM ECOSYSTEM: MULTI-IMAGE GALLERY & PRODUCT VIDEO SUPPORT (SHOPEE-STYLE)
-- Date: 2026-11-20
-- Systems: Ngam Business (Merchant Upload) | Ngam (Customer Product Detail Carousel & Video)
-- Idempotent migration: safe to run multiple times in Supabase SQL Editor.
-- =========================================================================================

BEGIN;

ALTER TABLE public.business_products
  ADD COLUMN IF NOT EXISTS image_urls JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS video_url TEXT;

-- Backfill existing products that only have single `image_url`
UPDATE public.business_products
SET image_urls = jsonb_build_array(image_url)
WHERE image_url IS NOT NULL
  AND TRIM(image_url) <> ''
  AND (
    image_urls IS NULL
    OR jsonb_typeof(image_urls) <> 'array'
    OR jsonb_array_length(image_urls) = 0
  );

COMMIT;
