-- ============================================================
-- Migration 011: App admin review flow for quiz candidates
-- Date: 2026-03-07
--
-- Fixes:
-- 1. No app-wide admin role for reviewing quiz candidates
-- 2. No authenticated review/publish path for quiz_question_candidates
-- 3. No app-admin storage access for private candidate images
-- ============================================================

CREATE TABLE IF NOT EXISTS public.app_admins (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    added_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.app_admins OWNER TO postgres;
ALTER TABLE public.app_admins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "App admins readable (self)" ON public.app_admins;

CREATE POLICY "App admins readable (self)"
    ON public.app_admins FOR SELECT TO authenticated
    USING (user_id = public.current_user_id());

CREATE OR REPLACE FUNCTION public.is_app_admin(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.app_admins aa
        WHERE aa.user_id = p_user_id
    );
$$;

CREATE OR REPLACE FUNCTION public.get_app_admin_status()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
    SELECT public.is_app_admin(public.current_user_id());
$$;

ALTER FUNCTION public.is_app_admin(UUID) OWNER TO postgres;
ALTER FUNCTION public.get_app_admin_status() OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.is_app_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_app_admin_status() TO authenticated;

ALTER TABLE public.quiz_question_candidates
    ADD COLUMN IF NOT EXISTS published_question_id UUID REFERENCES public.quiz_questions(id);

CREATE INDEX IF NOT EXISTS idx_quiz_question_candidates_published_question
    ON public.quiz_question_candidates(published_question_id);

DROP POLICY IF EXISTS "Quiz candidates readable (app admins)" ON public.quiz_question_candidates;
DROP POLICY IF EXISTS "Quiz candidates update (app admins)" ON public.quiz_question_candidates;

CREATE POLICY "Quiz candidates readable (app admins)"
    ON public.quiz_question_candidates FOR SELECT TO authenticated
    USING (public.is_app_admin(auth.uid()));

CREATE POLICY "Quiz candidates update (app admins)"
    ON public.quiz_question_candidates FOR UPDATE TO authenticated
    USING (public.is_app_admin(auth.uid()))
    WITH CHECK (public.is_app_admin(auth.uid()));

DROP POLICY IF EXISTS "Quiz candidate images read (app admins)" ON storage.objects;
DROP POLICY IF EXISTS "Quiz images approved upload (app admins)" ON storage.objects;
DROP POLICY IF EXISTS "Quiz images approved delete (app admins)" ON storage.objects;

CREATE POLICY "Quiz candidate images read (app admins)"
    ON storage.objects FOR SELECT TO authenticated
    USING (
        bucket_id = 'quiz-candidate-images'
        AND public.is_app_admin(auth.uid())
    );

CREATE POLICY "Quiz images approved upload (app admins)"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'quiz-images'
        AND name LIKE 'approved/%'
        AND public.is_app_admin(auth.uid())
    );

CREATE POLICY "Quiz images approved delete (app admins)"
    ON storage.objects FOR DELETE TO authenticated
    USING (
        bucket_id = 'quiz-images'
        AND name LIKE 'approved/%'
        AND public.is_app_admin(auth.uid())
    );

CREATE OR REPLACE FUNCTION public.get_quiz_question_candidates(
    p_status TEXT DEFAULT 'pending',
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    username TEXT,
    image_path TEXT,
    predicted_label TEXT,
    predicted_category TEXT,
    status TEXT,
    review_notes TEXT,
    created_at TIMESTAMPTZ,
    reviewed_at TIMESTAMPTZ,
    published_question_id UUID
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin_id UUID := public.current_user_id();
BEGIN
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF NOT public.is_app_admin(v_admin_id) THEN
        RAISE EXCEPTION 'Permission denied';
    END IF;

    RETURN QUERY
    SELECT c.id,
           c.user_id,
           COALESCE(p.username, 'Anonymous')::TEXT,
           c.image_path,
           c.predicted_label,
           c.predicted_category,
           c.status,
           c.review_notes,
           c.created_at,
           c.reviewed_at,
           c.published_question_id
    FROM public.quiz_question_candidates c
    LEFT JOIN public.profiles p ON p.id = c.user_id
    WHERE (
        p_status IS NULL
        OR p_status = 'all'
        OR c.status = p_status
    )
    ORDER BY
        CASE WHEN c.status = 'pending' THEN 0 ELSE 1 END,
        c.created_at DESC
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);
END;
$$;

CREATE OR REPLACE FUNCTION public.review_quiz_question_candidate(
    p_candidate_id UUID,
    p_decision TEXT,
    p_review_notes TEXT DEFAULT NULL,
    p_item_name TEXT DEFAULT NULL,
    p_category TEXT DEFAULT NULL,
    p_public_image_url TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin_id UUID := public.current_user_id();
    v_candidate RECORD;
    v_item_name TEXT;
    v_category TEXT;
    v_review_notes TEXT := NULLIF(BTRIM(p_review_notes), '');
    v_public_image_url TEXT := NULLIF(BTRIM(p_public_image_url), '');
    v_published_question_id UUID;
BEGIN
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF NOT public.is_app_admin(v_admin_id) THEN
        RAISE EXCEPTION 'Permission denied';
    END IF;
    IF p_decision NOT IN ('approved', 'rejected') THEN
        RAISE EXCEPTION 'Invalid decision';
    END IF;

    SELECT *
    INTO v_candidate
    FROM public.quiz_question_candidates
    WHERE id = p_candidate_id
    FOR UPDATE;

    IF v_candidate IS NULL THEN
        RAISE EXCEPTION 'Candidate not found';
    END IF;
    IF v_candidate.status <> 'pending' THEN
        RAISE EXCEPTION 'Candidate has already been reviewed';
    END IF;

    IF p_decision = 'approved' THEN
        v_item_name := COALESCE(NULLIF(BTRIM(p_item_name), ''), v_candidate.predicted_label);
        v_category := COALESCE(NULLIF(BTRIM(p_category), ''), v_candidate.predicted_category);

        IF v_public_image_url IS NULL THEN
            RAISE EXCEPTION 'Published image URL is required for approval';
        END IF;
        IF v_category NOT IN ('Recyclable', 'Compostable', 'Landfill', 'Hazardous') THEN
            RAISE EXCEPTION 'Invalid quiz category';
        END IF;

        INSERT INTO public.quiz_questions (image_url, correct_category, item_name, is_active)
        VALUES (v_public_image_url, v_category, v_item_name, true)
        RETURNING id INTO v_published_question_id;

        UPDATE public.quiz_question_candidates
        SET status = 'approved',
            review_notes = v_review_notes,
            reviewer_id = v_admin_id,
            reviewed_at = timezone('utc', now()),
            published_question_id = v_published_question_id
        WHERE id = p_candidate_id;

        RETURN json_build_object(
            'success', true,
            'decision', 'approved',
            'published_question_id', v_published_question_id
        );
    END IF;

    UPDATE public.quiz_question_candidates
    SET status = 'rejected',
        review_notes = v_review_notes,
        reviewer_id = v_admin_id,
        reviewed_at = timezone('utc', now())
    WHERE id = p_candidate_id;

    RETURN json_build_object(
        'success', true,
        'decision', 'rejected'
    );
END;
$$;

ALTER FUNCTION public.get_quiz_question_candidates(TEXT, INTEGER) OWNER TO postgres;
ALTER FUNCTION public.review_quiz_question_candidate(UUID, TEXT, TEXT, TEXT, TEXT, TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.get_quiz_question_candidates(TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_quiz_question_candidate(UUID, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
