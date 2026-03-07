-- ============================================================
-- Migration 010: Feedback storage hardening and quiz candidates
-- Date: 2026-03-07
--
-- Fixes:
-- 1. Missing explicit feedback_images storage bootstrap
-- 2. Correct-recognition candidate pipeline for Arena quiz growth
-- ============================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'feedback_images',
    'feedback_images',
    true,
    5242880,
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'quiz-candidate-images',
    'quiz-candidate-images',
    false,
    5242880,
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Feedback images upload (own folder)" ON storage.objects;
DROP POLICY IF EXISTS "Feedback images read (public bucket)" ON storage.objects;
DROP POLICY IF EXISTS "Feedback images delete (own folder)" ON storage.objects;
DROP POLICY IF EXISTS "Quiz candidate images upload (own folder)" ON storage.objects;
DROP POLICY IF EXISTS "Quiz candidate images read (own folder)" ON storage.objects;
DROP POLICY IF EXISTS "Quiz candidate images delete (own folder)" ON storage.objects;
DROP POLICY IF EXISTS "Quiz candidate images read (service role)" ON storage.objects;

CREATE POLICY "Feedback images upload (own folder)"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'feedback_images'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "Feedback images read (public bucket)"
    ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'feedback_images');

CREATE POLICY "Feedback images delete (own folder)"
    ON storage.objects FOR DELETE TO authenticated
    USING (
        bucket_id = 'feedback_images'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "Quiz candidate images upload (own folder)"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'quiz-candidate-images'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "Quiz candidate images read (own folder)"
    ON storage.objects FOR SELECT TO authenticated
    USING (
        bucket_id = 'quiz-candidate-images'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "Quiz candidate images delete (own folder)"
    ON storage.objects FOR DELETE TO authenticated
    USING (
        bucket_id = 'quiz-candidate-images'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "Quiz candidate images read (service role)"
    ON storage.objects FOR SELECT TO service_role
    USING (bucket_id = 'quiz-candidate-images');

CREATE TABLE IF NOT EXISTS public.quiz_question_candidates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    image_path TEXT NOT NULL,
    predicted_label TEXT NOT NULL,
    predicted_category TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewer_id UUID REFERENCES auth.users(id),
    review_notes TEXT,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_quiz_question_candidates_user_id
    ON public.quiz_question_candidates(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_quiz_question_candidates_status
    ON public.quiz_question_candidates(status, created_at DESC);

ALTER TABLE public.quiz_question_candidates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Quiz candidates insert own" ON public.quiz_question_candidates;
DROP POLICY IF EXISTS "Quiz candidates readable own" ON public.quiz_question_candidates;
DROP POLICY IF EXISTS "Quiz candidates readable (service role)" ON public.quiz_question_candidates;
DROP POLICY IF EXISTS "Quiz candidates update (service role)" ON public.quiz_question_candidates;

CREATE POLICY "Quiz candidates insert own"
    ON public.quiz_question_candidates FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Quiz candidates readable own"
    ON public.quiz_question_candidates FOR SELECT TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "Quiz candidates readable (service role)"
    ON public.quiz_question_candidates FOR SELECT TO service_role
    USING (true);

CREATE POLICY "Quiz candidates update (service role)"
    ON public.quiz_question_candidates FOR UPDATE TO service_role
    USING (true)
    WITH CHECK (true);
