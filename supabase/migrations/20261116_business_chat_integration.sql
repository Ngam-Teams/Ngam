-- =============================================================================
-- Business <-> Customer Two-Way Chat Integration (Ngam & Ngam Business)
-- Idempotent migration: safe to run multiple times in Supabase SQL Editor.
-- =============================================================================

-- 1. Extend public.conversations with business chat columns
ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS business_id UUID NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS context_type TEXT NULL,
  ADD COLUMN IF NOT EXISTS context_id UUID NULL,
  ADD COLUMN IF NOT EXISTS customer_unread_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS business_unread_count INT NOT NULL DEFAULT 0;

-- Partial unique index: one conversation thread per (customer, business)
CREATE UNIQUE INDEX IF NOT EXISTS idx_conversations_customer_business
  ON public.conversations (user1_id, business_id)
  WHERE business_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_conversations_business_id
  ON public.conversations (business_id, updated_at DESC)
  WHERE business_id IS NOT NULL;

-- 2. Additional RLS Policies for Business Owners & Active Staff (Ngam Teams)
DO $$ BEGIN
  DROP POLICY IF EXISTS "Business staff can view business conversations" ON public.conversations;
  DROP POLICY IF EXISTS "Business staff can insert business conversations" ON public.conversations;
  DROP POLICY IF EXISTS "Business staff can update business conversations" ON public.conversations;
  DROP POLICY IF EXISTS "Business staff can view business messages" ON public.messages;
  DROP POLICY IF EXISTS "Business staff can insert business messages" ON public.messages;
  DROP POLICY IF EXISTS "Participants and business staff can update messages read state" ON public.messages;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

CREATE POLICY "Business staff can view business conversations"
  ON public.conversations FOR SELECT TO authenticated
  USING (
    business_id IS NOT NULL
    AND public.is_active_staff_of(business_id)
  );

CREATE POLICY "Business staff can insert business conversations"
  ON public.conversations FOR INSERT TO authenticated
  WITH CHECK (
    business_id IS NOT NULL
    AND public.is_active_staff_of(business_id)
  );

CREATE POLICY "Business staff can update business conversations"
  ON public.conversations FOR UPDATE TO authenticated
  USING (
    business_id IS NOT NULL
    AND public.is_active_staff_of(business_id)
  )
  WITH CHECK (
    business_id IS NOT NULL
    AND public.is_active_staff_of(business_id)
  );

CREATE POLICY "Business staff can view business messages"
  ON public.messages FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = conversation_id
        AND c.business_id IS NOT NULL
        AND public.is_active_staff_of(c.business_id)
    )
  );

CREATE POLICY "Business staff can insert business messages"
  ON public.messages FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = conversation_id
        AND c.business_id IS NOT NULL
        AND public.is_active_staff_of(c.business_id)
    )
  );

CREATE POLICY "Participants and business staff can update messages read state"
  ON public.messages FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = conversation_id
        AND (
          c.user1_id = auth.uid()
          OR c.user2_id = auth.uid()
          OR (c.business_id IS NOT NULL AND public.is_active_staff_of(c.business_id))
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = conversation_id
        AND (
          c.user1_id = auth.uid()
          OR c.user2_id = auth.uid()
          OR (c.business_id IS NOT NULL AND public.is_active_staff_of(c.business_id))
        )
    )
  );

-- 3. RPC: Customer opens or creates a chat with a business
CREATE OR REPLACE FUNCTION public.get_or_create_business_conversation(
  p_business_id UUID,
  p_context_type TEXT DEFAULT NULL,
  p_context_id UUID DEFAULT NULL
)
RETURNS public.conversations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_customer_id UUID := auth.uid();
  v_owner_id UUID;
  v_conv public.conversations;
BEGIN
  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT owner_user_id INTO v_owner_id
  FROM public.businesses
  WHERE id = p_business_id;

  IF v_owner_id IS NULL THEN
    RAISE EXCEPTION 'Business not found';
  END IF;

  SELECT * INTO v_conv
  FROM public.conversations
  WHERE user1_id = v_customer_id
    AND business_id = p_business_id
  LIMIT 1;

  IF v_conv.id IS NULL THEN
    INSERT INTO public.conversations (
      user1_id,
      user2_id,
      business_id,
      context_type,
      context_id,
      updated_at
    )
    VALUES (
      v_customer_id,
      v_owner_id,
      p_business_id,
      COALESCE(p_context_type, 'general'),
      p_context_id,
      now()
    )
    ON CONFLICT (user1_id, business_id) WHERE business_id IS NOT NULL
    DO UPDATE SET
      context_type = COALESCE(EXCLUDED.context_type, public.conversations.context_type),
      context_id   = COALESCE(EXCLUDED.context_id, public.conversations.context_id)
    RETURNING * INTO v_conv;
  ELSIF p_context_type IS NOT NULL OR p_context_id IS NOT NULL THEN
    UPDATE public.conversations
    SET context_type = COALESCE(p_context_type, context_type),
        context_id   = COALESCE(p_context_id, context_id)
    WHERE id = v_conv.id
    RETURNING * INTO v_conv;
  END IF;

  RETURN v_conv;
END;
$$;

-- 4. RPC: Merchant or active staff opens or creates a chat with a customer
CREATE OR REPLACE FUNCTION public.merchant_open_conversation(
  p_business_id UUID,
  p_customer_id UUID,
  p_context_type TEXT DEFAULT NULL,
  p_context_id UUID DEFAULT NULL
)
RETURNS public.conversations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_owner_id UUID;
  v_conv public.conversations;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT owner_user_id INTO v_owner_id
  FROM public.businesses
  WHERE id = p_business_id;

  IF v_owner_id IS NULL THEN
    RAISE EXCEPTION 'Business not found';
  END IF;

  IF v_caller <> v_owner_id AND NOT public.is_active_staff_of(p_business_id) THEN
    RAISE EXCEPTION 'Not authorized for this business';
  END IF;

  SELECT * INTO v_conv
  FROM public.conversations
  WHERE user1_id = p_customer_id
    AND business_id = p_business_id
  LIMIT 1;

  IF v_conv.id IS NULL THEN
    INSERT INTO public.conversations (
      user1_id,
      user2_id,
      business_id,
      context_type,
      context_id,
      updated_at
    )
    VALUES (
      p_customer_id,
      v_owner_id,
      p_business_id,
      COALESCE(p_context_type, 'general'),
      p_context_id,
      now()
    )
    ON CONFLICT (user1_id, business_id) WHERE business_id IS NOT NULL
    DO UPDATE SET
      context_type = COALESCE(EXCLUDED.context_type, public.conversations.context_type),
      context_id   = COALESCE(EXCLUDED.context_id, public.conversations.context_id)
    RETURNING * INTO v_conv;
  ELSIF p_context_type IS NOT NULL OR p_context_id IS NOT NULL THEN
    UPDATE public.conversations
    SET context_type = COALESCE(p_context_type, context_type),
        context_id   = COALESCE(p_context_id, context_id)
    WHERE id = v_conv.id
    RETURNING * INTO v_conv;
  END IF;

  RETURN v_conv;
END;
$$;

-- 5. RPC: Mark a business conversation as read for either customer or business side
CREATE OR REPLACE FUNCTION public.mark_business_conversation_read(
  p_conversation_id UUID,
  p_viewer_role TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_conv public.conversations;
  v_is_business_viewer BOOLEAN := FALSE;
BEGIN
  IF v_uid IS NULL THEN
    RETURN;
  END IF;

  SELECT * INTO v_conv
  FROM public.conversations
  WHERE id = p_conversation_id;

  IF v_conv.id IS NULL OR v_conv.business_id IS NULL THEN
    RETURN;
  END IF;

  IF p_viewer_role = 'business' THEN
    IF v_uid = v_conv.user2_id OR public.is_active_staff_of(v_conv.business_id) THEN
      v_is_business_viewer := TRUE;
    END IF;
  ELSIF p_viewer_role = 'customer' THEN
    v_is_business_viewer := FALSE;
  ELSE
    IF v_uid <> v_conv.user1_id AND (v_uid = v_conv.user2_id OR public.is_active_staff_of(v_conv.business_id)) THEN
      v_is_business_viewer := TRUE;
    END IF;
  END IF;

  IF v_is_business_viewer THEN
    UPDATE public.messages
    SET is_read = true
    WHERE conversation_id = p_conversation_id
      AND sender_id = v_conv.user1_id
      AND is_read = false;

    UPDATE public.conversations
    SET business_unread_count = 0,
        last_message_is_read = CASE
          WHEN last_message_sender_id = v_conv.user1_id THEN true
          ELSE last_message_is_read
        END
    WHERE id = p_conversation_id;
  ELSE
    IF v_uid = v_conv.user1_id THEN
      UPDATE public.messages
      SET is_read = true
      WHERE conversation_id = p_conversation_id
        AND sender_id <> v_conv.user1_id
        AND is_read = false;

      UPDATE public.conversations
      SET customer_unread_count = 0,
          last_message_is_read = CASE
            WHEN last_message_sender_id <> v_conv.user1_id THEN true
            ELSE last_message_is_read
          END
      WHERE id = p_conversation_id;
    END IF;
  END IF;
END;
$$;

-- 6. Trigger: Auto-update business conversation metadata, unread counters & customer notifications on new message
CREATE OR REPLACE FUNCTION public.handle_business_chat_message_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conv public.conversations;
  v_biz_name TEXT;
  v_preview TEXT;
  v_is_customer_sender BOOLEAN;
BEGIN
  IF NEW.content LIKE '__SYSTEM__%' THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_conv
  FROM public.conversations
  WHERE id = NEW.conversation_id;

  IF v_conv.id IS NULL OR v_conv.business_id IS NULL THEN
    RETURN NEW;
  END IF;

  v_is_customer_sender := (NEW.sender_id = v_conv.user1_id);
  v_preview := CASE
    WHEN NEW.image_url IS NOT NULL AND (NEW.content = 'Photo' OR NEW.content = 'Image' OR NEW.content = '') THEN '📷 Photo'
    ELSE left(NEW.content, 200)
  END;

  UPDATE public.conversations
  SET last_message = v_preview,
      last_message_sender_id = NEW.sender_id,
      last_message_is_read = false,
      updated_at = COALESCE(NEW.created_at, now()),
      business_unread_count = CASE
        WHEN v_is_customer_sender THEN COALESCE(business_unread_count, 0) + 1
        ELSE business_unread_count
      END,
      customer_unread_count = CASE
        WHEN NOT v_is_customer_sender THEN COALESCE(customer_unread_count, 0) + 1
        ELSE customer_unread_count
      END
  WHERE id = v_conv.id;

  -- Notify customer when business replies
  IF NOT v_is_customer_sender THEN
    BEGIN
      SELECT business_name INTO v_biz_name
      FROM public.businesses
      WHERE id = v_conv.business_id;

      INSERT INTO public.notifications (
        user_id,
        business_id,
        title,
        message,
        type,
        reference_id,
        is_read
      ) VALUES (
        v_conv.user1_id,
        v_conv.business_id,
        COALESCE(v_biz_name, 'Ngam Business'),
        left(v_preview, 160),
        CASE
          WHEN v_conv.context_type = 'order' THEN 'pesanan'
          WHEN v_conv.context_type = 'booking' THEN 'tempahan'
          ELSE 'sistem'
        END,
        v_conv.id::text,
        false
      );
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_on_business_chat_message_insert ON public.messages;
CREATE TRIGGER trg_on_business_chat_message_insert
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_business_chat_message_insert();

GRANT EXECUTE ON FUNCTION public.get_or_create_business_conversation(UUID, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.merchant_open_conversation(UUID, UUID, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_business_conversation_read(UUID, TEXT) TO authenticated;
