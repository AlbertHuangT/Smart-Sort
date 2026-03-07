-- ============================================================
-- Migration 004: Expire stale accepted / in-progress arena challenges
-- Date: 2026-03-07
--
-- Inbox cleanup previously only expired pending challenges.
-- Accepted or partially played duels could remain "In Progress" forever.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_my_challenges(p_status TEXT DEFAULT NULL)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_result  JSON;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

    -- Expire stale pending challenges.
    UPDATE public.arena_challenges
    SET status = 'expired'
    WHERE status = 'pending'
      AND expires_at < timezone('utc', now());

    -- Real-time duels should not stay active indefinitely if nobody comes back.
    UPDATE public.arena_challenges ac
    SET status = 'expired'
    WHERE ac.status IN ('accepted', 'in_progress')
      AND COALESCE(
            (
                SELECT MAX(aca.created_at)
                FROM public.arena_challenge_answers aca
                WHERE aca.challenge_id = ac.id
            ),
            ac.started_at,
            ac.created_at
          ) < timezone('utc', now()) - INTERVAL '30 minutes';

    SELECT json_agg(row_to_json(t)) INTO v_result
    FROM (
        SELECT ac.id, ac.challenger_id, ac.opponent_id, ac.status,
               ac.challenger_score, ac.opponent_score, ac.winner_id,
               ac.channel_name, ac.created_at, ac.expires_at,
               ac.started_at, ac.completed_at,
               cp.username AS challenger_name,
               op.username AS opponent_name
        FROM public.arena_challenges ac
        JOIN public.profiles cp ON cp.id = ac.challenger_id
        JOIN public.profiles op ON op.id = ac.opponent_id
        WHERE (ac.challenger_id = v_user_id OR ac.opponent_id = v_user_id)
          AND (p_status IS NULL OR ac.status = p_status)
        ORDER BY ac.created_at DESC
        LIMIT 50
    ) t;

    RETURN COALESCE(v_result, '[]'::json);
END;
$$;
ALTER FUNCTION public.get_my_challenges(TEXT) OWNER TO postgres;
