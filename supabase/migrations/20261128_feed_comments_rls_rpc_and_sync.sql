-- ==============================================================================
-- HOTFIX: FEED COMMENTS TABLE SCHEMA, RLS POLICIES, ATOMIC LIKES RPC & COUNT SYNC
-- Tarikh : 2026-11-28
-- Fail   : 20261128_feed_comments_rls_rpc_and_sync.sql
-- ==============================================================================

-- 1. Pastikan jadual feed_comments & semua kolum penting wujud
CREATE TABLE IF NOT EXISTS public.feed_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES public.feed_posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  user_name TEXT NOT NULL DEFAULT 'Pelanggan Ngam',
  user_avatar TEXT DEFAULT '',
  comment_text TEXT NOT NULL DEFAULT '',
  likes_count INTEGER NOT NULL DEFAULT 0,
  liked_by_owner BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.feed_comments
  ADD COLUMN IF NOT EXISTS user_name TEXT NOT NULL DEFAULT 'Pelanggan Ngam',
  ADD COLUMN IF NOT EXISTS user_avatar TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS comment_text TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS likes_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS liked_by_owner BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_feed_comments_post_created
  ON public.feed_comments (post_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_feed_comments_user_id
  ON public.feed_comments (user_id);

-- 2. Aktifkan RLS dan tetapkan polisi bersih (baca awam, komen pengguna log masuk, padam penulis/pemilik kedai)
ALTER TABLE public.feed_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "feed_comments_select_all" ON public.feed_comments;
DROP POLICY IF EXISTS "feed_comments_insert_auth" ON public.feed_comments;
DROP POLICY IF EXISTS "feed_comments_update_author" ON public.feed_comments;
DROP POLICY IF EXISTS "feed_comments_delete_author_or_owner" ON public.feed_comments;
DROP POLICY IF EXISTS "Anyone can read feed comments" ON public.feed_comments;
DROP POLICY IF EXISTS "Authenticated users can insert feed comments" ON public.feed_comments;
DROP POLICY IF EXISTS "Users can delete own comments" ON public.feed_comments;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.feed_comments;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.feed_comments;

CREATE POLICY "feed_comments_select_all"
  ON public.feed_comments
  FOR SELECT
  TO anon, authenticated
  USING (TRUE);

CREATE POLICY "feed_comments_insert_auth"
  ON public.feed_comments
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "feed_comments_update_author"
  ON public.feed_comments
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "feed_comments_delete_author_or_owner"
  ON public.feed_comments
  FOR DELETE
  TO authenticated
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1
      FROM public.feed_posts fp
      JOIN public.businesses b ON b.id = fp.business_id
      WHERE fp.id = feed_comments.post_id
        AND b.owner_user_id = auth.uid()
    )
  );

-- 3. RPC SECURITY DEFINER: Like/Unlike komen secara atomik (selamat RLS untuk semua pengguna)
CREATE OR REPLACE FUNCTION public.toggle_feed_comment_like(
  p_comment_id UUID,
  p_delta INTEGER,
  p_is_owner BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(likes_count INTEGER, liked_by_owner BOOLEAN)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_step INTEGER;
  v_actual_owner BOOLEAN := FALSE;
  v_new_likes INTEGER;
  v_new_owner_like BOOLEAN;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  -- Hadkan delta kepada -1 atau +1 sahaja untuk elak manipulasi
  v_step := CASE WHEN p_delta >= 0 THEN 1 ELSE -1 END;

  IF p_is_owner THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.feed_comments fc
      JOIN public.feed_posts fp ON fp.id = fc.post_id
      JOIN public.businesses b ON b.id = fp.business_id
      WHERE fc.id = p_comment_id
        AND b.owner_user_id = v_uid
    ) INTO v_actual_owner;
  END IF;

  UPDATE public.feed_comments fc
  SET
    likes_count = GREATEST(0, COALESCE(fc.likes_count, 0) + v_step),
    liked_by_owner = CASE
      WHEN v_actual_owner THEN (v_step > 0)
      ELSE COALESCE(fc.liked_by_owner, FALSE)
    END
  WHERE fc.id = p_comment_id
  RETURNING fc.likes_count, fc.liked_by_owner
  INTO v_new_likes, v_new_owner_like;

  RETURN QUERY SELECT COALESCE(v_new_likes, 0), COALESCE(v_new_owner_like, FALSE);
END;
$$;

REVOKE ALL ON FUNCTION public.toggle_feed_comment_like(UUID, INTEGER, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.toggle_feed_comment_like(UUID, INTEGER, BOOLEAN) TO authenticated;

-- 4. RPC SECURITY DEFINER: Padam komen bersama semua balasan (elak komen anak jadi orphan)
CREATE OR REPLACE FUNCTION public.delete_feed_comment_cascade(
  p_comment_id UUID
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_post_id UUID;
  v_author_id UUID;
  v_is_owner BOOLEAN := FALSE;
  v_deleted INTEGER := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT fc.post_id, fc.user_id
  INTO v_post_id, v_author_id
  FROM public.feed_comments fc
  WHERE fc.id = p_comment_id;

  IF v_post_id IS NULL THEN
    RETURN 0;
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.feed_posts fp
    JOIN public.businesses b ON b.id = fp.business_id
    WHERE fp.id = v_post_id
      AND b.owner_user_id = v_uid
  ) INTO v_is_owner;

  IF v_author_id IS DISTINCT FROM v_uid AND NOT v_is_owner THEN
    RAISE EXCEPTION 'Not authorized to delete this comment';
  END IF;

  -- Padam semua balasan (replies) bagi komen induk ini terlebih dahulu
  DELETE FROM public.feed_comments
  WHERE post_id = v_post_id
    AND comment_text LIKE ('[[REPLY:' || p_comment_id::TEXT || '|%');

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  -- Padam komen itu sendiri
  DELETE FROM public.feed_comments
  WHERE id = p_comment_id;

  RETURN v_deleted + 1;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_feed_comment_cascade(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_feed_comment_cascade(UUID) TO authenticated;

-- 5. Trigger automatik untuk pastikan feed_posts.comments_count sentiasa 100% tepat
CREATE OR REPLACE FUNCTION public.sync_feed_post_comments_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_post_id UUID;
BEGIN
  v_post_id := COALESCE(NEW.post_id, OLD.post_id);
  IF v_post_id IS NOT NULL THEN
    UPDATE public.feed_posts
    SET comments_count = (
      SELECT COUNT(*)::INTEGER
      FROM public.feed_comments
      WHERE post_id = v_post_id
    )
    WHERE id = v_post_id;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_feed_post_comments_count ON public.feed_comments;
CREATE TRIGGER trg_sync_feed_post_comments_count
  AFTER INSERT OR DELETE ON public.feed_comments
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_feed_post_comments_count();

-- 6. Selaraskan semula semua comments_count sedia ada pada feed_posts
UPDATE public.feed_posts fp
SET comments_count = COALESCE((
  SELECT COUNT(*)::INTEGER
  FROM public.feed_comments fc
  WHERE fc.post_id = fp.id
), 0);
