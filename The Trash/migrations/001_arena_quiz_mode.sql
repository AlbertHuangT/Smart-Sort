-- ============================================================
-- Migration: Arena Quiz Mode
-- Date: 2026-02-06
-- Description: 
--   - Remove crowdsource voting system (correction_tasks, correction_votes)
--   - Remove settlement/punishment triggers
--   - Create new quiz_questions table with correct answers
--   - Create get_quiz_questions RPC function
-- ============================================================

-- ============================================================
-- PART 1: CLEANUP - Drop old tables and triggers
-- ============================================================

-- Drop triggers first (they depend on functions)
DROP TRIGGER IF EXISTS on_vote_added_settlement ON public.correction_votes;
DROP TRIGGER IF EXISTS on_feedback_submitted ON public.feedback_logs;

-- Drop functions
DROP FUNCTION IF EXISTS public.process_arena_settlement();
DROP FUNCTION IF EXISTS public.convert_feedback_to_arena_task();
DROP FUNCTION IF EXISTS public.get_arena_tasks();

-- Drop old tables (correction_votes first due to foreign key)
DROP TABLE IF EXISTS public.correction_votes;
DROP TABLE IF EXISTS public.correction_tasks;

-- ============================================================
-- PART 2: CREATE NEW QUIZ SYSTEM
-- ============================================================

-- Create quiz_questions table
CREATE TABLE IF NOT EXISTS public.quiz_questions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    image_url TEXT NOT NULL,
    correct_category TEXT NOT NULL,
    item_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now()),
    is_active BOOLEAN DEFAULT true
);

-- Set ownership
ALTER TABLE public.quiz_questions OWNER TO postgres;

-- Enable RLS
ALTER TABLE public.quiz_questions ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read quiz questions
CREATE POLICY "Quiz questions are readable by authenticated users"
    ON public.quiz_questions
    FOR SELECT
    TO authenticated
    USING (is_active = true);

-- ============================================================
-- PART 3: CREATE RPC FUNCTION
-- ============================================================

-- Function to get random quiz questions (10 per session)
CREATE OR REPLACE FUNCTION public.get_quiz_questions()
RETURNS SETOF public.quiz_questions
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM public.quiz_questions
    WHERE is_active = true
    ORDER BY random()
    LIMIT 10;
END;
$$;

ALTER FUNCTION public.get_quiz_questions() OWNER TO postgres;

-- ============================================================
-- PART 4: OPTIONAL - Remove punishment columns from profiles
-- Uncomment if you want to clean up the profiles table
-- ============================================================

-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS status;
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS banned_until;

-- Drop the protection trigger if removing status fields
-- DROP TRIGGER IF EXISTS ensure_profile_security ON public.profiles;
-- DROP FUNCTION IF EXISTS public.protect_sensitive_profile_fields();

-- ============================================================
-- PART 5: SEED DATA (Example quiz questions)
-- Replace with your actual quiz data
-- ============================================================

-- INSERT INTO public.quiz_questions (image_url, correct_category, item_name) VALUES
-- ('https://example.com/images/plastic_bottle.jpg', 'Recyclable', 'Plastic Bottle'),
-- ('https://example.com/images/banana_peel.jpg', 'Compostable', 'Banana Peel'),
-- ('https://example.com/images/battery.jpg', 'Hazardous', 'Battery'),
-- ('https://example.com/images/chip_bag.jpg', 'Landfill', 'Chip Bag');

-- ============================================================
-- VERIFICATION QUERIES (Run after migration to verify)
-- ============================================================

-- Check new table exists:
-- SELECT * FROM public.quiz_questions LIMIT 5;

-- Test RPC function:
-- SELECT * FROM public.get_quiz_questions();

-- Verify old tables are gone:
-- SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'correction_tasks');
-- SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'correction_votes');
