-- ============================================================
-- Migration 004: Bug Reports & Log Upload
-- Date: 2026-03-05
--
-- 1. bug_reports table for user-submitted bug feedback
-- 2. bug-report-logs Storage bucket (private)
-- 3. RLS policies for table and storage
-- ============================================================

-- ============================================================
-- 1. BUG REPORTS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.bug_reports (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    description TEXT,
    log_path    TEXT,                        -- Storage path, nullable
    device_info JSONB,                       -- {model, os_version, ...}
    app_version TEXT,
    status      TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'reviewed', 'closed')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bug_reports_user_id ON public.bug_reports(user_id);
CREATE INDEX IF NOT EXISTS idx_bug_reports_status  ON public.bug_reports(status);

-- ============================================================
-- 2. STORAGE BUCKET (private)
-- ============================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'bug-report-logs',
    'bug-report-logs',
    false,
    5242880,                                 -- 5 MB limit per file
    ARRAY['text/plain']
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 3. RLS — bug_reports table
-- ============================================================

ALTER TABLE public.bug_reports ENABLE ROW LEVEL SECURITY;

-- Users (including anonymous/guest) can read their own reports
CREATE POLICY "Bug reports readable (own)"
    ON public.bug_reports FOR SELECT TO authenticated
    USING (user_id = auth.uid());

-- Users can insert their own reports
CREATE POLICY "Bug reports insert (own)"
    ON public.bug_reports FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

-- ============================================================
-- 4. RLS — Storage: bug-report-logs bucket
-- ============================================================

-- Allow authenticated users to upload logs under their own uid folder
CREATE POLICY "Bug logs upload (own folder)"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'bug-report-logs'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- Allow users to read their own uploaded logs
CREATE POLICY "Bug logs read (own folder)"
    ON storage.objects FOR SELECT TO authenticated
    USING (
        bucket_id = 'bug-report-logs'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- ============================================================
-- 5. Force search_path on any new functions (none in this file,
--    but keeping pattern consistent with 003)
-- ============================================================
