-- =========================================================================================
-- Ngam App — Supabase Database Schema
-- Run this in the Supabase SQL Editor (SQL Editor -> New Query)
-- =========================================================================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. USERS TABLE
DROP TABLE IF EXISTS public.users CASCADE;
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role VARCHAR(50) NOT NULL,
  
  -- User attributes
  user_name VARCHAR(255),
  user_email VARCHAR(255),
  user_phone VARCHAR(50),
  user_bio TEXT,
  user_gender VARCHAR(20),
  user_birth_date DATE,
  user_address TEXT,
  user_address_lat DOUBLE PRECISION,
  user_address_lng DOUBLE PRECISION,
  user_qr_code_url VARCHAR,
  user_avatar_url VARCHAR,
  user_fcm_token TEXT,
  user_balance DECIMAL(10, 2) DEFAULT 0.00,
  user_is_verified_runner BOOLEAN DEFAULT FALSE,

  -- Business attributes
  business_name VARCHAR(255),
  business_email VARCHAR(255),
  business_phone VARCHAR(50),
  business_address TEXT,
  business_registration_number VARCHAR(100),
  business_logo_url VARCHAR,
  business_balance DECIMAL(10, 2) DEFAULT 0.00,

  -- Console attributes
  console_name VARCHAR(255),
  console_email VARCHAR(255),
  console_role VARCHAR(50),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);


-- 6. CONVERSATIONS TABLE
DROP TABLE IF EXISTS public.conversations CASCADE;
CREATE TABLE IF NOT EXISTS public.conversations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user1_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  user2_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  last_message TEXT,
  last_message_sender_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  last_message_is_read BOOLEAN DEFAULT FALSE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. MESSAGES TABLE
DROP TABLE IF EXISTS public.messages CASCADE;
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 8. PAYMENT METHODS TABLE
DROP TABLE IF EXISTS public.payment_methods CASCADE;
CREATE TABLE IF NOT EXISTS public.payment_methods (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type VARCHAR(50) NOT NULL, -- 'card', 'bank', 'duitnow_qr'
  is_primary BOOLEAN DEFAULT FALSE,
  color_index INTEGER DEFAULT 0,
  holder_name VARCHAR(255),
  name VARCHAR(255),
  details VARCHAR(255),
  expiry VARCHAR(10),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);


-- =========================================================================================
-- Set up Row Level Security (RLS) & Policies
-- =========================================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;

-- Safe Policy Deletion (Remove old dangerous policies)
DO $$
BEGIN
    DROP POLICY IF EXISTS "Allow public select on users" ON public.users;
    DROP POLICY IF EXISTS "Allow public insert on users" ON public.users;
    DROP POLICY IF EXISTS "Allow public update on users" ON public.users;
    DROP POLICY IF EXISTS "Allow public all on conversations" ON public.conversations;
    DROP POLICY IF EXISTS "Allow public all on messages" ON public.messages;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- ==========================================
-- 1. USERS
-- ==========================================
-- Anyone can view user profiles
CREATE POLICY "Users can be viewed by anyone" 
ON public.users FOR SELECT USING (true);

-- Users can only insert their own profile
CREATE POLICY "Users can insert their own profile" 
ON public.users FOR INSERT WITH CHECK (auth.uid() = id);

-- Users can only update their own profile
CREATE POLICY "Users can update their own profile" 
ON public.users FOR UPDATE USING (auth.uid() = id);

-- Users can only delete their own profile
CREATE POLICY "Users can delete their own profile" 
ON public.users FOR DELETE USING (auth.uid() = id);

-- ==========================================
-- 6. CONVERSATIONS
-- ==========================================
-- Users can only see conversations they are part of
CREATE POLICY "Users can view their conversations" 
ON public.conversations FOR SELECT 
USING (auth.uid() = user1_id OR auth.uid() = user2_id);

-- Users can only create conversations involving themselves
CREATE POLICY "Users can insert their conversations" 
ON public.conversations FOR INSERT 
WITH CHECK (auth.uid() = user1_id OR auth.uid() = user2_id);

-- Users can only update their conversations
CREATE POLICY "Users can update their conversations" 
ON public.conversations FOR UPDATE 
USING (auth.uid() = user1_id OR auth.uid() = user2_id);

-- ==========================================
-- 7. MESSAGES
-- ==========================================
-- Users can view messages in their conversations
CREATE POLICY "Users can view messages in their conversations" 
ON public.messages FOR SELECT 
USING (
    EXISTS (
        SELECT 1 FROM public.conversations c 
        WHERE c.id = messages.conversation_id 
        AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
    )
);

-- Users can insert messages if they are the sender
CREATE POLICY "Users can insert their own messages" 
ON public.messages FOR INSERT 
WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (
        SELECT 1 FROM public.conversations c 
        WHERE c.id = messages.conversation_id 
        AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
    )
);

-- ==========================================
-- 8. PAYMENT METHODS
-- Users can view their own payment methods
CREATE POLICY "Users can view their own payment methods" 
ON public.payment_methods FOR SELECT USING (auth.uid() = payment_methods.user_id);

-- Users can insert their own payment methods
CREATE POLICY "Users can insert their own payment methods" 
ON public.payment_methods FOR INSERT WITH CHECK (auth.uid() = payment_methods.user_id);

-- Users can update their own payment methods
CREATE POLICY "Users can update their own payment methods" 
ON public.payment_methods FOR UPDATE USING (auth.uid() = payment_methods.user_id);

-- Users can delete their own payment methods
CREATE POLICY "Users can delete their own payment methods" 
ON public.payment_methods FOR DELETE USING (auth.uid() = payment_methods.user_id);


-- Enable Realtime for conversations, messages, and gigs safely
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'conversations') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'messages') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename = 'users') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
  END IF;
END
$$;

-- =========================================================================================
-- Avatar Storage Setup
-- =========================================================================================

-- Create the Storage Bucket for Avatars
INSERT INTO storage.buckets (id, name, public) 
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Set up Storage Policies (RLS) for the 'avatars' bucket

-- Allow public read access to all avatars
DO $$
BEGIN
    DROP POLICY IF EXISTS "Avatar Public View" ON storage.objects;
    CREATE POLICY "Avatar Public View" ON storage.objects FOR SELECT USING ( bucket_id = 'avatars' );
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Allow authenticated users to upload an avatar
DO $$
BEGIN
    DROP POLICY IF EXISTS "Avatar User Upload" ON storage.objects;
    CREATE POLICY "Avatar User Upload" ON storage.objects FOR INSERT TO authenticated WITH CHECK (
        bucket_id = 'avatars' AND 
        (storage.foldername(name))[1] = auth.uid()::text
    );
EXCEPTION WHEN OTHERS THEN NULL;
END $$;






-- 1. Update the RPC function to reset task_unread_counts when the sender changes
CREATE OR REPLACE FUNCTION update_conversation_task_message(
  p_conversation_id UUID,
  p_sender_id UUID,
  p_message_content TEXT,
  p_gig_id UUID
) RETURNS void AS $$
DECLARE
  current_counts JSONB;
  current_count INT;
  prev_sender_id UUID;
BEGIN
  -- Fetch the current task_unread_counts and last_message_sender_id
  SELECT 
    COALESCE(task_unread_counts, '{}'::jsonb),
    last_message_sender_id
  INTO 
    current_counts,
    prev_sender_id
  FROM conversations 
  WHERE id = p_conversation_id;
  
  -- If the sender changed, it means the new sender has seen previous messages
  -- or at least, the unread direction has flipped. So we reset the counts.
  IF prev_sender_id IS NOT NULL AND prev_sender_id != p_sender_id THEN
    current_counts := '{}'::jsonb;
    current_count := 0;
  ELSE
    -- Extract the current count for this specific gig_id, defaulting to 0
    current_count := COALESCE((current_counts->>p_gig_id::text)::INT, 0);
  END IF;

  UPDATE conversations
  SET 
    -- Safely merge the new message into the JSON object
    task_last_messages = COALESCE(task_last_messages, '{}'::jsonb) || jsonb_build_object(p_gig_id::text, p_message_content),
    -- Safely increment the unread count for this specific gig_id
    task_unread_counts = current_counts || jsonb_build_object(p_gig_id::text, current_count + 1),
    last_message = p_message_content,
    last_message_sender_id = p_sender_id,
    last_message_is_read = false,
    updated_at = NOW()
  WHERE id = p_conversation_id;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- NGAM APP: ROW LEVEL SECURITY (RLS) MIGRATION
-- ==========================================

-- 1. Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- 2. Drop old dangerous policies
DO $$
BEGIN
    DROP POLICY IF EXISTS "Allow public select on users" ON public.users;
    DROP POLICY IF EXISTS "Allow public insert on users" ON public.users;
    DROP POLICY IF EXISTS "Allow public update on users" ON public.users;
    DROP POLICY IF EXISTS "Allow public all on conversations" ON public.conversations;
    DROP POLICY IF EXISTS "Allow public all on messages" ON public.messages;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- ==========================================
-- 3. USERS
-- ==========================================
DROP POLICY IF EXISTS "Users can be viewed by anyone" ON public.users;
CREATE POLICY "Users can be viewed by anyone" 
ON public.users FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.users;
CREATE POLICY "Users can insert their own profile" 
ON public.users FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;
CREATE POLICY "Users can update their own profile" 
ON public.users FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can delete their own profile" ON public.users;
CREATE POLICY "Users can delete their own profile" 
ON public.users FOR DELETE USING (auth.uid() = id);

-- ==========================================
-- 5. CONVERSATIONS & MESSAGES
-- ==========================================
DROP POLICY IF EXISTS "Users can view their conversations" ON public.conversations;
CREATE POLICY "Users can view their conversations" 
ON public.conversations FOR SELECT 
USING (auth.uid() = user1_id OR auth.uid() = user2_id);

DROP POLICY IF EXISTS "Users can insert their conversations" ON public.conversations;
CREATE POLICY "Users can insert their conversations" 
ON public.conversations FOR INSERT 
WITH CHECK (auth.uid() = user1_id OR auth.uid() = user2_id);

DROP POLICY IF EXISTS "Users can update their conversations" ON public.conversations;
CREATE POLICY "Users can update their conversations" 
ON public.conversations FOR UPDATE 
USING (auth.uid() = user1_id OR auth.uid() = user2_id);

DROP POLICY IF EXISTS "Users can view messages in their conversations" ON public.messages;
CREATE POLICY "Users can view messages in their conversations" 
ON public.messages FOR SELECT 
USING (
    EXISTS (
        SELECT 1 FROM public.conversations c 
        WHERE c.id = messages.conversation_id 
        AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
    )
);

DROP POLICY IF EXISTS "Users can insert their own messages" ON public.messages;
CREATE POLICY "Users can insert their own messages" 
ON public.messages FOR INSERT 
WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (
        SELECT 1 FROM public.conversations c 
        WHERE c.id = messages.conversation_id 
        AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
    )
);

-- 1. Add user_balance to users table
-- ADD COLUMN IF NOT EXISTS user_balance DECIMAL(10, 2) DEFAULT 0.00; (Handled in table creation)

-- 2. Create transactions table
DROP TABLE IF EXISTS public.transactions CASCADE;
CREATE TABLE IF NOT EXISTS public.transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type VARCHAR(50) NOT NULL, -- 'topup', 'payment', 'refund', 'earning'
  amount DECIMAL(10, 2) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- Users can view their own transactions
CREATE POLICY "Users can view their own transactions" 
ON public.transactions FOR SELECT 
USING (auth.uid() = transactions.user_id);



-- 4. RPC for Top Up
CREATE OR REPLACE FUNCTION public.top_up_wallet(
  p_user_id UUID,
  p_amount DECIMAL
) RETURNS json AS $$
DECLARE
  new_balance DECIMAL;
BEGIN
  -- 1. Add user_balance
  UPDATE public.users SET user_balance = user_balance + p_amount WHERE id = p_user_id RETURNING user_balance INTO new_balance;

  -- 2. Record transaction
  INSERT INTO public.transactions (user_id, type, amount)
  VALUES (p_user_id, 'topup', p_amount);

  RETURN json_build_object('success', true, 'new_balance', new_balance);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;





-- 1. RPC for Withdrawal
CREATE OR REPLACE FUNCTION public.withdraw_wallet(
  p_user_id UUID,
  p_amount DECIMAL
) RETURNS json AS $$
DECLARE
  current_balance DECIMAL;
  new_balance DECIMAL;
BEGIN
  -- 1. Check user user_balance (Row-level lock for safety)
  SELECT user_balance INTO current_balance FROM public.users WHERE id = p_user_id FOR UPDATE;
  
  IF current_balance < p_amount THEN
    RAISE EXCEPTION 'Insufficient user_balance. You have RM%, but RM% is required.', current_balance, p_amount;
  END IF;

  -- 2. Deduct user_balance
  UPDATE public.users SET user_balance = user_balance - p_amount WHERE id = p_user_id RETURNING user_balance INTO new_balance;

  -- 3. Record transaction
  INSERT INTO public.transactions (user_id, type, amount)
  VALUES (p_user_id, 'withdrawal', -p_amount);

  RETURN json_build_object('success', true, 'new_balance', new_balance);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;






