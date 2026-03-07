-- ============================================================
-- Migration 009: Server-verified Arena solo sessions
-- Date: 2026-03-07
--
-- Fixes:
-- 1. Correct answers leaking to clients
-- 2. Client-authoritative solo-mode scoring and credit grants
-- 3. Challenger self-accepting duel invites
-- ============================================================

-- ============================================================
-- 1. Tables
-- ============================================================

CREATE TABLE IF NOT EXISTS public.arena_solo_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    mode TEXT NOT NULL CHECK (mode IN ('classic', 'speed_sort', 'streak', 'daily')),
    question_ids UUID[] NOT NULL,
    challenge_date DATE,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'abandoned')),
    points_awarded INTEGER NOT NULL DEFAULT 0,
    result_payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    completed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.arena_solo_session_answers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.arena_solo_sessions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    question_index INT NOT NULL,
    selected_category TEXT NOT NULL,
    is_correct BOOLEAN NOT NULL,
    answer_time_ms INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    UNIQUE (session_id, question_index)
);

ALTER TABLE public.arena_solo_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.arena_solo_session_answers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Solo sessions readable (own)" ON public.arena_solo_sessions;
DROP POLICY IF EXISTS "Solo answers readable (own)" ON public.arena_solo_session_answers;

CREATE POLICY "Solo sessions readable (own)"
    ON public.arena_solo_sessions FOR SELECT TO authenticated
    USING (user_id = public.current_user_id());

CREATE POLICY "Solo answers readable (own)"
    ON public.arena_solo_session_answers FOR SELECT TO authenticated
    USING (user_id = public.current_user_id());

CREATE INDEX IF NOT EXISTS idx_arena_solo_sessions_user_mode
    ON public.arena_solo_sessions(user_id, mode, status);

-- ============================================================
-- 2. Helpers
-- ============================================================

CREATE OR REPLACE FUNCTION public.build_public_quiz_questions(p_question_ids UUID[])
RETURNS JSON
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE(
        json_agg(
            json_build_object(
                'id', q.id,
                'image_url', q.image_url,
                'item_name', q.item_name
            )
            ORDER BY ord.ordinality
        ),
        '[]'::json
    )
    FROM unnest(p_question_ids) WITH ORDINALITY AS ord(qid, ordinality)
    JOIN public.quiz_questions q ON q.id = ord.qid;
$$;

ALTER FUNCTION public.build_public_quiz_questions(UUID[]) OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.create_solo_session(
    p_mode TEXT,
    p_limit INT DEFAULT 10
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
    v_session_id UUID;
    v_limit INT := LEAST(GREATEST(COALESCE(p_limit, 10), 1), 50);
    v_question_ids UUID[];
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF p_mode NOT IN ('classic', 'speed_sort', 'streak') THEN
        RAISE EXCEPTION 'Unsupported solo mode';
    END IF;

    SELECT ARRAY(
        SELECT q.id
        FROM public.quiz_questions q
        WHERE q.is_active = true
        ORDER BY random()
        LIMIT v_limit
    ) INTO v_question_ids;

    IF COALESCE(array_length(v_question_ids, 1), 0) < v_limit THEN
        RAISE EXCEPTION 'Not enough questions available';
    END IF;

    INSERT INTO public.arena_solo_sessions (user_id, mode, question_ids)
    VALUES (v_user_id, p_mode, v_question_ids)
    RETURNING id INTO v_session_id;

    RETURN json_build_object(
        'session_id', v_session_id,
        'questions', public.build_public_quiz_questions(v_question_ids)
    );
END;
$$;

ALTER FUNCTION public.create_solo_session(TEXT, INT) OWNER TO postgres;

-- ============================================================
-- 3. Question fetch RPCs
-- ============================================================

DROP FUNCTION IF EXISTS public.get_quiz_questions();
CREATE OR REPLACE FUNCTION public.get_quiz_questions()
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN public.create_solo_session('classic', 10);
END;
$$;
ALTER FUNCTION public.get_quiz_questions() OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.get_quiz_questions_for_mode(
    p_mode TEXT,
    p_limit INT DEFAULT 10
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN public.create_solo_session(p_mode, p_limit);
END;
$$;
ALTER FUNCTION public.get_quiz_questions_for_mode(TEXT, INT) OWNER TO postgres;

DROP FUNCTION IF EXISTS public.get_quiz_questions_batch(INT);
CREATE OR REPLACE FUNCTION public.get_quiz_questions_batch(
    p_limit INT DEFAULT 10,
    p_session_id UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
    v_session_id UUID := p_session_id;
    v_existing_question_ids UUID[] := ARRAY[]::UUID[];
    v_new_question_ids UUID[] := ARRAY[]::UUID[];
    v_fill_question_ids UUID[] := ARRAY[]::UUID[];
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF v_session_id IS NULL THEN
        RETURN public.create_solo_session('streak', p_limit);
    END IF;

    SELECT question_ids INTO v_existing_question_ids
    FROM public.arena_solo_sessions
    WHERE id = v_session_id
      AND user_id = v_user_id
      AND mode = 'streak'
      AND status = 'active';

    IF v_existing_question_ids IS NULL THEN
        RAISE EXCEPTION 'Streak session not found';
    END IF;

    SELECT ARRAY(
        SELECT q.id
        FROM public.quiz_questions q
        WHERE q.is_active = true
          AND NOT (q.id = ANY(v_existing_question_ids))
        ORDER BY random()
        LIMIT p_limit
    ) INTO v_new_question_ids;

    IF COALESCE(array_length(v_new_question_ids, 1), 0) < p_limit THEN
        SELECT ARRAY(
            SELECT q.id
            FROM public.quiz_questions q
            WHERE q.is_active = true
            ORDER BY random()
            LIMIT p_limit - COALESCE(array_length(v_new_question_ids, 1), 0)
        ) INTO v_fill_question_ids;

        v_new_question_ids := COALESCE(v_new_question_ids, ARRAY[]::UUID[]) || COALESCE(v_fill_question_ids, ARRAY[]::UUID[]);
    END IF;

    UPDATE public.arena_solo_sessions
    SET question_ids = question_ids || v_new_question_ids
    WHERE id = v_session_id;

    RETURN json_build_object(
        'session_id', v_session_id,
        'questions', public.build_public_quiz_questions(v_new_question_ids)
    );
END;
$$;
ALTER FUNCTION public.get_quiz_questions_batch(INT, UUID) OWNER TO postgres;

-- ============================================================
-- 4. Solo answer verification
-- ============================================================

CREATE OR REPLACE FUNCTION public.submit_solo_answer(
    p_session_id UUID,
    p_question_index INT,
    p_selected_category TEXT,
    p_answer_time_ms INT DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
    v_session RECORD;
    v_question_id UUID;
    v_correct_category TEXT;
    v_is_correct BOOLEAN;
    v_existing RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_session
    FROM public.arena_solo_sessions
    WHERE id = p_session_id
      AND user_id = v_user_id
      AND status = 'active';

    IF v_session IS NULL THEN
        RAISE EXCEPTION 'Solo session not found';
    END IF;

    v_question_id := v_session.question_ids[p_question_index + 1];
    IF v_question_id IS NULL THEN
        RAISE EXCEPTION 'Invalid question index: %', p_question_index;
    END IF;

    SELECT * INTO v_existing
    FROM public.arena_solo_session_answers
    WHERE session_id = p_session_id
      AND question_index = p_question_index;

    IF v_existing IS NOT NULL THEN
        RETURN json_build_object(
            'is_correct', v_existing.is_correct,
            'correct_category', (
                SELECT q.correct_category
                FROM public.quiz_questions q
                WHERE q.id = v_question_id
            ),
            'question_index', p_question_index
        );
    END IF;

    SELECT correct_category INTO v_correct_category
    FROM public.quiz_questions
    WHERE id = v_question_id;

    v_is_correct := (p_selected_category = v_correct_category);

    INSERT INTO public.arena_solo_session_answers (
        session_id, user_id, question_index, selected_category, is_correct, answer_time_ms
    )
    VALUES (
        p_session_id, v_user_id, p_question_index, p_selected_category, v_is_correct,
        GREATEST(COALESCE(p_answer_time_ms, 0), 0)
    );

    RETURN json_build_object(
        'is_correct', v_is_correct,
        'correct_category', v_correct_category,
        'question_index', p_question_index
    );
END;
$$;
ALTER FUNCTION public.submit_solo_answer(UUID, INT, TEXT, INT) OWNER TO postgres;

-- ============================================================
-- 5. Solo completion RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.complete_classic_session(p_session_id UUID)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
    v_session RECORD;
    v_total_questions INT;
    v_correct_count INT := 0;
    v_combo_count INT := 0;
    v_max_combo INT := 0;
    v_score INT := 0;
    v_answer RECORD;
    v_result JSONB;
    v_idx INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_session
    FROM public.arena_solo_sessions
    WHERE id = p_session_id
      AND user_id = v_user_id
      AND mode = 'classic';

    IF v_session IS NULL THEN
        RAISE EXCEPTION 'Classic session not found';
    END IF;

    IF v_session.status = 'completed' THEN
        RETURN COALESCE(v_session.result_payload, '{}'::jsonb);
    END IF;

    v_total_questions := COALESCE(array_length(v_session.question_ids, 1), 0);

    FOR v_idx IN 0..(v_total_questions - 1) LOOP
        SELECT * INTO v_answer
        FROM public.arena_solo_session_answers
        WHERE session_id = p_session_id
          AND question_index = v_idx;

        IF v_answer IS NULL THEN
            RAISE EXCEPTION 'Session is not complete yet';
        END IF;

        IF v_answer.is_correct THEN
            v_correct_count := v_correct_count + 1;
            v_combo_count := v_combo_count + 1;
            v_max_combo := GREATEST(v_max_combo, v_combo_count);
            v_score := v_score + 20;
            IF v_combo_count >= 3 THEN
                v_score := v_score + ((v_combo_count - 2) * 5);
            END IF;
        ELSE
            v_combo_count := 0;
        END IF;
    END LOOP;

    UPDATE public.profiles
    SET credits = credits + v_score
    WHERE id = v_user_id;

    v_result := json_build_object(
        'session_id', p_session_id,
        'score', v_score,
        'correct_count', v_correct_count,
        'max_combo', v_max_combo,
        'points_awarded', v_score
    );

    UPDATE public.arena_solo_sessions
    SET status = 'completed',
        completed_at = timezone('utc', now()),
        points_awarded = v_score,
        result_payload = v_result
    WHERE id = p_session_id;

    RETURN v_result;
END;
$$;
ALTER FUNCTION public.complete_classic_session(UUID) OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.complete_speed_sort_session(p_session_id UUID)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
    v_session RECORD;
    v_total_questions INT;
    v_correct_count INT := 0;
    v_combo_count INT := 0;
    v_max_combo INT := 0;
    v_score INT := 0;
    v_answer RECORD;
    v_time_bonus INT;
    v_result JSONB;
    v_idx INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_session
    FROM public.arena_solo_sessions
    WHERE id = p_session_id
      AND user_id = v_user_id
      AND mode = 'speed_sort';

    IF v_session IS NULL THEN
        RAISE EXCEPTION 'Speed Sort session not found';
    END IF;

    IF v_session.status = 'completed' THEN
        RETURN COALESCE(v_session.result_payload, '{}'::jsonb);
    END IF;

    v_total_questions := COALESCE(array_length(v_session.question_ids, 1), 0);

    FOR v_idx IN 0..(v_total_questions - 1) LOOP
        SELECT * INTO v_answer
        FROM public.arena_solo_session_answers
        WHERE session_id = p_session_id
          AND question_index = v_idx;

        IF v_answer IS NULL THEN
            RAISE EXCEPTION 'Session is not complete yet';
        END IF;

        IF v_answer.is_correct THEN
            v_correct_count := v_correct_count + 1;
            v_combo_count := v_combo_count + 1;
            v_max_combo := GREATEST(v_max_combo, v_combo_count);
            v_score := v_score + 20;
            IF v_combo_count >= 3 THEN
                v_score := v_score + ((v_combo_count - 2) * 5);
            END IF;

            v_time_bonus := FLOOR((GREATEST(0, 5000 - COALESCE(v_answer.answer_time_ms, 0))::NUMERIC / 1000.0) * 4);
            v_score := v_score + GREATEST(v_time_bonus, 0);
        ELSE
            v_combo_count := 0;
        END IF;
    END LOOP;

    UPDATE public.profiles
    SET credits = credits + v_score
    WHERE id = v_user_id;

    v_result := json_build_object(
        'session_id', p_session_id,
        'score', v_score,
        'correct_count', v_correct_count,
        'max_combo', v_max_combo,
        'points_awarded', v_score
    );

    UPDATE public.arena_solo_sessions
    SET status = 'completed',
        completed_at = timezone('utc', now()),
        points_awarded = v_score,
        result_payload = v_result
    WHERE id = p_session_id;

    RETURN v_result;
END;
$$;
ALTER FUNCTION public.complete_speed_sort_session(UUID) OWNER TO postgres;

DROP FUNCTION IF EXISTS public.submit_streak_record(INT);
CREATE OR REPLACE FUNCTION public.submit_streak_record(p_session_id UUID)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
    v_session RECORD;
    v_total_answers INT;
    v_streak_count INT := 0;
    v_points INT := 0;
    v_answer RECORD;
    v_result JSONB;
    v_idx INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_session
    FROM public.arena_solo_sessions
    WHERE id = p_session_id
      AND user_id = v_user_id
      AND mode = 'streak';

    IF v_session IS NULL THEN
        RAISE EXCEPTION 'Streak session not found';
    END IF;

    IF v_session.status = 'completed' THEN
        RETURN COALESCE(v_session.result_payload, '{}'::jsonb);
    END IF;

    SELECT COALESCE(MAX(question_index), -1) + 1
    INTO v_total_answers
    FROM public.arena_solo_session_answers
    WHERE session_id = p_session_id;

    IF v_total_answers <= 0 THEN
        RAISE EXCEPTION 'No streak answers submitted';
    END IF;

    FOR v_idx IN 0..(v_total_answers - 1) LOOP
        SELECT * INTO v_answer
        FROM public.arena_solo_session_answers
        WHERE session_id = p_session_id
          AND question_index = v_idx;

        EXIT WHEN v_answer IS NULL OR NOT v_answer.is_correct;
        v_streak_count := v_streak_count + 1;
    END LOOP;

    INSERT INTO public.streak_records (user_id, streak_count)
    VALUES (v_user_id, v_streak_count);

    v_points := v_streak_count * 5;
    IF v_points > 0 THEN
        UPDATE public.profiles
        SET credits = credits + v_points
        WHERE id = v_user_id;
    END IF;

    v_result := json_build_object(
        'session_id', p_session_id,
        'streak_count', v_streak_count,
        'points_awarded', v_points
    );

    UPDATE public.arena_solo_sessions
    SET status = 'completed',
        completed_at = timezone('utc', now()),
        points_awarded = v_points,
        result_payload = v_result
    WHERE id = p_session_id;

    RETURN v_result;
END;
$$;
ALTER FUNCTION public.submit_streak_record(UUID) OWNER TO postgres;

-- ============================================================
-- 6. Daily challenge verification
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_daily_challenge()
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
    v_today DATE := (timezone('utc', now()))::date;
    v_challenge_id UUID;
    v_question_ids UUID[];
    v_already_played BOOLEAN;
    v_session_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT id, question_ids
    INTO v_challenge_id, v_question_ids
    FROM public.daily_challenges
    WHERE challenge_date = v_today;

    IF v_challenge_id IS NULL THEN
        SELECT ARRAY(
            SELECT q.id
            FROM public.quiz_questions q
            WHERE q.is_active = true
            ORDER BY random()
            LIMIT 10
        ) INTO v_question_ids;

        IF COALESCE(array_length(v_question_ids, 1), 0) < 10 THEN
            RAISE EXCEPTION 'Not enough questions available for today''s challenge';
        END IF;

        INSERT INTO public.daily_challenges (challenge_date, question_ids)
        VALUES (v_today, v_question_ids)
        ON CONFLICT (challenge_date) DO UPDATE
            SET challenge_date = EXCLUDED.challenge_date
        RETURNING id INTO v_challenge_id;

        SELECT question_ids INTO v_question_ids
        FROM public.daily_challenges
        WHERE id = v_challenge_id;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM public.daily_challenge_results
        WHERE user_id = v_user_id
          AND challenge_date = v_today
    ) INTO v_already_played;

    IF NOT v_already_played THEN
        SELECT id INTO v_session_id
        FROM public.arena_solo_sessions
        WHERE user_id = v_user_id
          AND mode = 'daily'
          AND challenge_date = v_today
          AND status = 'active'
        ORDER BY created_at DESC
        LIMIT 1;

        IF v_session_id IS NULL THEN
            INSERT INTO public.arena_solo_sessions (
                user_id, mode, question_ids, challenge_date
            )
            VALUES (
                v_user_id, 'daily', v_question_ids, v_today
            )
            RETURNING id INTO v_session_id;
        END IF;
    END IF;

    RETURN json_build_object(
        'challenge_id', v_challenge_id,
        'challenge_date', v_today,
        'already_played', v_already_played,
        'session_id', v_session_id,
        'questions', public.build_public_quiz_questions(v_question_ids)
    );
END;
$$;
ALTER FUNCTION public.get_daily_challenge() OWNER TO postgres;

DROP FUNCTION IF EXISTS public.submit_daily_challenge(INT, INT, DECIMAL, INT);
CREATE OR REPLACE FUNCTION public.submit_daily_challenge(
    p_session_id UUID,
    p_time_seconds DECIMAL
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
    v_session RECORD;
    v_today DATE := (timezone('utc', now()))::date;
    v_total_questions INT;
    v_correct_count INT := 0;
    v_combo_count INT := 0;
    v_max_combo INT := 0;
    v_score INT := 0;
    v_answer RECORD;
    v_result_id UUID;
    v_result JSONB;
    v_idx INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_session
    FROM public.arena_solo_sessions
    WHERE id = p_session_id
      AND user_id = v_user_id
      AND mode = 'daily'
      AND challenge_date = v_today;

    IF v_session IS NULL THEN
        RAISE EXCEPTION 'Daily session not found';
    END IF;

    IF v_session.status = 'completed' THEN
        RETURN COALESCE(v_session.result_payload, '{}'::jsonb);
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.daily_challenge_results
        WHERE user_id = v_user_id
          AND challenge_date = v_today
    ) THEN
        RAISE EXCEPTION 'Already completed today''s challenge';
    END IF;

    v_total_questions := COALESCE(array_length(v_session.question_ids, 1), 0);

    FOR v_idx IN 0..(v_total_questions - 1) LOOP
        SELECT * INTO v_answer
        FROM public.arena_solo_session_answers
        WHERE session_id = p_session_id
          AND question_index = v_idx;

        IF v_answer IS NULL THEN
            RAISE EXCEPTION 'Daily challenge is not complete yet';
        END IF;

        IF v_answer.is_correct THEN
            v_correct_count := v_correct_count + 1;
            v_combo_count := v_combo_count + 1;
            v_max_combo := GREATEST(v_max_combo, v_combo_count);
            v_score := v_score + 20;
            IF v_combo_count >= 3 THEN
                v_score := v_score + ((v_combo_count - 2) * 5);
            END IF;
        ELSE
            v_combo_count := 0;
        END IF;
    END LOOP;

    INSERT INTO public.daily_challenge_results (
        user_id, challenge_date, score, correct_count, time_seconds, max_combo
    )
    VALUES (
        v_user_id, v_today, v_score, v_correct_count, p_time_seconds, v_max_combo
    )
    RETURNING id INTO v_result_id;

    IF v_score > 0 THEN
        UPDATE public.profiles
        SET credits = credits + v_score
        WHERE id = v_user_id;
    END IF;

    v_result := json_build_object(
        'result_id', v_result_id,
        'points_awarded', v_score,
        'score', v_score,
        'correct_count', v_correct_count,
        'max_combo', v_max_combo
    );

    UPDATE public.arena_solo_sessions
    SET status = 'completed',
        completed_at = timezone('utc', now()),
        points_awarded = v_score,
        result_payload = v_result
    WHERE id = p_session_id;

    RETURN v_result;
END;
$$;
ALTER FUNCTION public.submit_daily_challenge(UUID, DECIMAL) OWNER TO postgres;

-- ============================================================
-- 7. Duel payload hardening
-- ============================================================

CREATE OR REPLACE FUNCTION public.accept_arena_challenge(p_challenge_id UUID)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
    v_challenge RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_challenge
    FROM public.arena_challenges
    WHERE id = p_challenge_id;

    IF v_challenge IS NULL THEN
        RAISE EXCEPTION 'Challenge not found';
    END IF;
    IF v_challenge.opponent_id != v_user_id THEN
        RAISE EXCEPTION 'Only the invited opponent can accept this challenge';
    END IF;
    IF v_challenge.status != 'pending' THEN
        RAISE EXCEPTION 'Challenge is no longer pending (status: %)', v_challenge.status;
    END IF;
    IF v_challenge.expires_at < timezone('utc', now()) THEN
        UPDATE public.arena_challenges
        SET status = 'expired'
        WHERE id = p_challenge_id;
        RAISE EXCEPTION 'Challenge has expired';
    END IF;

    UPDATE public.arena_challenges
    SET status = 'accepted'
    WHERE id = p_challenge_id;

    RETURN json_build_object(
        'challenge_id', p_challenge_id,
        'channel_name', v_challenge.channel_name,
        'questions', public.build_public_quiz_questions(v_challenge.question_ids),
        'challenger_id', v_challenge.challenger_id,
        'opponent_id', v_challenge.opponent_id
    );
END;
$$;
ALTER FUNCTION public.accept_arena_challenge(UUID) OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.get_challenge_questions(p_challenge_id UUID)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
    v_challenge RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

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
    FROM public.arena_challenges
    WHERE id = p_challenge_id;

    IF v_challenge IS NULL THEN
        RAISE EXCEPTION 'Challenge not found';
    END IF;
    IF v_challenge.challenger_id != v_user_id AND v_challenge.opponent_id != v_user_id THEN
        RAISE EXCEPTION 'Not your challenge';
    END IF;
    IF v_challenge.status = 'expired' THEN
        RAISE EXCEPTION 'Challenge has expired';
    END IF;
    IF v_challenge.status NOT IN ('accepted', 'in_progress') THEN
        RAISE EXCEPTION 'Challenge is not ready for play';
    END IF;

    RETURN json_build_object(
        'challenge_id', p_challenge_id,
        'channel_name', v_challenge.channel_name,
        'questions', public.build_public_quiz_questions(v_challenge.question_ids),
        'challenger_id', v_challenge.challenger_id,
        'opponent_id', v_challenge.opponent_id
    );
END;
$$;
ALTER FUNCTION public.get_challenge_questions(UUID) OWNER TO postgres;

-- ============================================================
-- 8. Grants
-- ============================================================

GRANT EXECUTE ON FUNCTION public.create_solo_session(TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_quiz_questions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_quiz_questions_for_mode(TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_quiz_questions_batch(INT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_solo_answer(UUID, INT, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_classic_session(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_speed_sort_session(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_streak_record(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_daily_challenge() TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_daily_challenge(UUID, DECIMAL) TO authenticated;
