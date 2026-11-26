-- ==============================================================================
-- INVENTORY: ADD PRODUCT WEIGHT_KG FOR SHIPPING & EASYPARCEL
-- Tarikh : 2026-11-26
-- Fail   : 20261126_product_weight_for_shipping.sql
-- ==============================================================================

-- Tambah lajur berat penghantaran (kg) pada jadual produk supaya kadar pos EasyParcel
-- dikira secara tepat mengikut berat sebenar item dalam troli pelanggan & pesanan peniaga.
ALTER TABLE public.business_products
  ADD COLUMN IF NOT EXISTS weight_kg NUMERIC(8, 2) NOT NULL DEFAULT 0.50 CHECK (weight_kg >= 0);
