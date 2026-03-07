-- ============================================================
-- Migration 005: Arena quiz image bucket bootstrap
-- Date: 2026-03-07
--
-- Creates a public bucket for Arena quiz images.
-- A temporary anon/authenticated upload policy is added for the
-- `seed/` prefix so seed assets can be migrated into Storage.
-- Follow up with migration 006 to update quiz_questions.image_url
-- and remove the temporary upload policy.
-- ============================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'quiz-images',
    'quiz-images',
    true,
    5242880,
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Quiz images seed upload (temporary)"
    ON storage.objects FOR INSERT TO anon, authenticated
    WITH CHECK (
        bucket_id = 'quiz-images'
        AND name LIKE 'seed/%'
    );
