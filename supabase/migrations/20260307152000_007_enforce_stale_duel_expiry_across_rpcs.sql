-- ============================================================
-- Migration 007: Enforce stale active duel expiry across core RPCs
-- Date: 2026-03-07
--
-- get_my_challenges already expires accepted / in-progress duels that
-- have been inactive for 30 minutes. Apply the same rule to gameplay
-- RPCs so stale challenges cannot still be loaded, answered, or
-- completed until the inbox list happens to be fetched.
-- ============================================================

-- 1. submit_duel_answer
CREATE OR REPLACE FUNCTION public.submit_duel_answer(
    p_challenge_id UUID, p_question_index INT,
    p_selected_category TEXT, p_answer_time_ms INT
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id          UUID;
    v_challenge        RECORD;
    v_question_id      UUID;
    v_correct_category TEXT;
    v_is_correct       BOOLEAN;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

    UPDATE public.arena_challenges ac
    SET status = 'expired'
    WHERE ac.id = p_challenge_id
      AND ac.status IN ('accepted', 'in_progress')
      AND COALESCE(
            (
                SELECT MAX(aca.created_at)
                FROM public.arena_challenge_answers aca
                WHERE aca.challenge_id = ac.id
            ),
            ac.started_at,
            ac.created_at
          ) < timezone('utc', now()) - INTERVAL '30 minutes';

    SELECT * INTO v_challenge FROM public.arena_challenges WHERE id = p_challenge_id;
    IF v_challenge IS NULL THEN RAISE EXCEPTION 'Challenge not found'; END IF;
    IF v_challenge.challenger_id != v_user_id AND v_challenge.opponent_id != v_user_id THEN
        RAISE EXCEPTION 'Not your challenge';
    END IF;
    IF v_challenge.status = 'expired' THEN
        RAISE EXCEPTION 'Challenge has expired';
    END IF;
    IF v_challenge.status NOT IN ('accepted','in_progress') THEN
        RAISE EXCEPTION 'Challenge is not active (status: %)', v_challenge.status;
    END IF;

    IF v_challenge.status = 'accepted' THEN
        UPDATE public.arena_challenges
        SET status = 'in_progress', started_at = timezone('utc', now())
        WHERE id = p_challenge_id AND status = 'accepted';
    END IF;

    v_question_id := v_challenge.question_ids[p_question_index + 1];
    IF v_question_id IS NULL THEN
        RAISE EXCEPTION 'Invalid question index: %', p_question_index;
    END IF;

    SELECT correct_category INTO v_correct_category
    FROM public.quiz_questions WHERE id = v_question_id;
    v_is_correct := (p_selected_category = v_correct_category);

    INSERT INTO public.arena_challenge_answers (
        challenge_id, user_id, question_index, selected_category, is_correct, answer_time_ms
    ) VALUES (
        p_challenge_id, v_user_id, p_question_index, p_selected_category, v_is_correct, p_answer_time_ms
    ) ON CONFLICT (challenge_id, user_id, question_index) DO NOTHING;

    RETURN json_build_object(
        'is_correct', v_is_correct,
        'correct_category', v_correct_category,
        'question_index', p_question_index
    );
END;
$$;
ALTER FUNCTION public.submit_duel_answer(UUID, INT, TEXT, INT) OWNER TO postgres;

-- 2. complete_arena_challenge
CREATE OR REPLACE FUNCTION public.complete_arena_challenge(p_challenge_id UUID)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id            UUID;
    v_challenge          RECORD;
    v_challenger_correct INT;
    v_opponent_correct   INT;
    v_challenger_score   INT;
    v_opponent_score     INT;
    v_winner_id          UUID;
    v_challenger_points  INT;
    v_opponent_points    INT;
    v_total_questions    INT;
    v_challenger_answers INT;
    v_opponent_answers   INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

    UPDATE public.arena_challenges ac
    SET status = 'expired'
    WHERE ac.id = p_challenge_id
      AND ac.status IN ('accepted', 'in_progress')
      AND COALESCE(
            (
                SELECT MAX(aca.created_at)
                FROM public.arena_challenge_answers aca
                WHERE aca.challenge_id = ac.id
            ),
            ac.started_at,
            ac.created_at
          ) < timezone('utc', now()) - INTERVAL '30 minutes';

    SELECT * INTO v_challenge
    FROM public.arena_challenges WHERE id = p_challenge_id FOR UPDATE;

    IF v_challenge IS NULL THEN RAISE EXCEPTION 'Challenge not found'; END IF;
    IF v_challenge.challenger_id != v_user_id AND v_challenge.opponent_id != v_user_id THEN
        RAISE EXCEPTION 'Not your challenge';
    END IF;

    IF v_challenge.status = 'completed' THEN
        RETURN json_build_object(
            'challenge_id', p_challenge_id,
            'challenger_score', v_challenge.challenger_score,
            'opponent_score', v_challenge.opponent_score,
            'winner_id', v_challenge.winner_id,
            'already_completed', true
        );
    END IF;

    IF v_challenge.status = 'expired' THEN
        RAISE EXCEPTION 'Challenge has expired';
    END IF;
    IF v_challenge.status NOT IN ('accepted','in_progress') THEN
        RAISE EXCEPTION 'Challenge is not active (status: %)', v_challenge.status;
    END IF;

    v_total_questions := COALESCE(array_length(v_challenge.question_ids, 1), 0);
    IF v_total_questions <= 0 THEN RAISE EXCEPTION 'Challenge has no questions'; END IF;

    SELECT COUNT(*) INTO v_challenger_answers
    FROM public.arena_challenge_answers
    WHERE challenge_id = p_challenge_id AND user_id = v_challenge.challenger_id;

    SELECT COUNT(*) INTO v_opponent_answers
    FROM public.arena_challenge_answers
    WHERE challenge_id = p_challenge_id AND user_id = v_challenge.opponent_id;

    IF v_challenger_answers < v_total_questions OR v_opponent_answers < v_total_questions THEN
        RAISE EXCEPTION 'Challenge not complete yet';
    END IF;

    SELECT COUNT(*) FILTER (WHERE is_correct) INTO v_challenger_correct
    FROM public.arena_challenge_answers
    WHERE challenge_id = p_challenge_id AND user_id = v_challenge.challenger_id;

    SELECT COUNT(*) FILTER (WHERE is_correct) INTO v_opponent_correct
    FROM public.arena_challenge_answers
    WHERE challenge_id = p_challenge_id AND user_id = v_challenge.opponent_id;

    v_challenger_score := v_challenger_correct * 20;
    v_opponent_score   := v_opponent_correct * 20;

    IF v_challenger_score > v_opponent_score THEN v_winner_id := v_challenge.challenger_id;
    ELSIF v_opponent_score > v_challenger_score THEN v_winner_id := v_challenge.opponent_id;
    ELSE v_winner_id := NULL;
    END IF;

    IF v_winner_id IS NULL THEN
        v_challenger_points := 30; v_opponent_points := 30;
    ELSIF v_winner_id = v_challenge.challenger_id THEN
        v_challenger_points := 50; v_opponent_points := 10;
    ELSE
        v_challenger_points := 10; v_opponent_points := 50;
    END IF;

    UPDATE public.arena_challenges
    SET status = 'completed',
        challenger_score = v_challenger_score,
        opponent_score   = v_opponent_score,
        winner_id        = v_winner_id,
        completed_at     = timezone('utc', now())
    WHERE id = p_challenge_id;

    UPDATE public.profiles SET credits = credits + v_challenger_points WHERE id = v_challenge.challenger_id;
    UPDATE public.profiles SET credits = credits + v_opponent_points  WHERE id = v_challenge.opponent_id;

    RETURN json_build_object(
        'challenge_id', p_challenge_id,
        'challenger_score', v_challenger_score,
        'opponent_score', v_opponent_score,
        'winner_id', v_winner_id,
        'challenger_points', v_challenger_points,
        'opponent_points', v_opponent_points,
        'already_completed', false
    );
END;
$$;
ALTER FUNCTION public.complete_arena_challenge(UUID) OWNER TO postgres;

-- 3. get_challenge_questions
CREATE OR REPLACE FUNCTION public.get_challenge_questions(p_challenge_id UUID)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id   UUID;
    v_challenge RECORD;
    v_questions JSON;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

    UPDATE public.arena_challenges ac
    SET status = 'expired'
    WHERE ac.id = p_challenge_id
      AND ac.status IN ('accepted', 'in_progress')
      AND COALESCE(
            (
                SELECT MAX(aca.created_at)
                FROM public.arena_challenge_answers aca
                WHERE aca.challenge_id = ac.id
            ),
            ac.started_at,
            ac.created_at
          ) < timezone('utc', now()) - INTERVAL '30 minutes';

    SELECT * INTO v_challenge FROM public.arena_challenges WHERE id = p_challenge_id;
    IF v_challenge IS NULL THEN RAISE EXCEPTION 'Challenge not found'; END IF;
    IF v_challenge.challenger_id != v_user_id AND v_challenge.opponent_id != v_user_id THEN
        RAISE EXCEPTION 'Not your challenge';
    END IF;
    IF v_challenge.status = 'expired' THEN
        RAISE EXCEPTION 'Challenge has expired';
    END IF;
    IF v_challenge.status NOT IN ('accepted','in_progress') THEN
        RAISE EXCEPTION 'Challenge is not ready for play';
    END IF;

    SELECT json_agg(q ORDER BY ord.ordinality) INTO v_questions
    FROM unnest(v_challenge.question_ids) WITH ORDINALITY AS ord(qid, ordinality)
    JOIN public.quiz_questions q ON q.id = ord.qid;

    RETURN json_build_object(
        'challenge_id', p_challenge_id,
        'channel_name', v_challenge.channel_name,
        'questions', COALESCE(v_questions, '[]'::json),
        'challenger_id', v_challenge.challenger_id,
        'opponent_id', v_challenge.opponent_id
    );
END;
$$;
ALTER FUNCTION public.get_challenge_questions(UUID) OWNER TO postgres;
