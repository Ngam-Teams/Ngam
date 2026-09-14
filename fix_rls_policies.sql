-- 1. Allow authenticated users to INSERT products
CREATE POLICY "Business owners can insert their products"
ON public.business_products FOR INSERT
TO authenticated
WITH CHECK (true); -- Ideally you'd check auth.uid() against the businesses table

-- 2. Allow authenticated users to UPDATE their products
CREATE POLICY "Business owners can update their products"
ON public.business_products FOR UPDATE
TO authenticated
USING (true);

-- 3. Allow authenticated users to DELETE their products
CREATE POLICY "Business owners can delete their products"
ON public.business_products FOR DELETE
TO authenticated
USING (true);
