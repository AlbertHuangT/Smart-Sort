-- ============================================================
-- Migration 012: Challenge expiry 1 min + unique pending constraint
-- Date: 2026-02-09
-- Description:
--   - Change challenge expiry from 10 minutes to 1 minute
--   - Only allow one pending challenge per challenger→opponent pair
-- ============================================================

-- 1. Change default expiry to 1 minute for new rows
ALTER TABLE public.arena_challenges
ALTER COLUMN expires_at SET DEFAULT timezone('utc', now()) + INTERVAL '1 minute';

-- 2. Expire all stale pending challenges first
UPDATE public.arena_challenges
SET status = 'expired'
WHERE status = 'pending'
AND expires_at < timezone('utc', now());

-- 3. Deduplicate remaining pending challenges (keep the newest, expire the rest)
UPDATE public.arena_challenges
SET status = 'expired'
WHERE id IN (
    SELECT id FROM (
        SELECT id,
            ROW_NUMBER() OVER (
                PARTITION BY challenger_id, opponent_id
                ORDER BY created_at DESC
            ) AS rn
        FROM public.arena_challenges
        WHERE status = 'pending'
    ) sub
    WHERE rn > 1
);

-- 4. Now safe to create the partial unique index
CREATE UNIQUE INDEX IF NOT EXISTS idx_challenges_unique_pending
ON public.arena_challenges(challenger_id, opponent_id)
WHERE status = 'pending';

-- 5. Update create_arena_challenge: 1 min expiry + duplicate check
CREATE OR REPLACE FUNCTION public.create_arena_challenge(p_opponent_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_challenge_id UUID;
    v_question_ids UUID[];
    v_channel_name TEXT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF v_user_id = p_opponent_id THEN
        RAISE EXCEPTION 'Cannot challenge yourself';
    END IF;

    -- Expire stale pending challenges first
    UPDATE public.arena_challenges
    SET status = 'expired'
    WHERE status = 'pending'
    AND expires_at < timezone('utc', now());

    -- Check for existing pending challenge to this opponent
    IF EXISTS (
        SELECT 1 FROM public.arena_challenges
        WHERE challenger_id = v_user_id
        AND opponent_id = p_opponent_id
        AND status = 'pending'
    ) THEN
        RAISE EXCEPTION 'You already have a pending challenge to this player';
    END IF;

    -- Select 10 random questions
    SELECT ARRAY(
        SELECT q.id
        FROM public.quiz_questions q
        WHERE q.is_active = true
        ORDER BY random()
        LIMIT 10
    ) INTO v_question_ids;

    IF array_length(v_question_ids, 1) < 10 THEN
        RAISE EXCEPTION 'Not enough questions available';
    END IF;

    v_challenge_id := gen_random_uuid();
    v_channel_name := 'duel:' || v_challenge_id::text;

    INSERT INTO public.arena_challenges (
        id, challenger_id, opponent_id, status, question_ids, channel_name,
        expires_at
    ) VALUES (
        v_challenge_id, v_user_id, p_opponent_id, 'pending', v_question_ids, v_channel_name,
        timezone('utc', now()) + INTERVAL '1 minute'
    );

    RETURN json_build_object(
        'challenge_id', v_challenge_id,
        'channel_name', v_channel_name,
        'status', 'pending'
    );
END;
$$;
