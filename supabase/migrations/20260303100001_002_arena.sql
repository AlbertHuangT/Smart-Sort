-- ============================================================
-- Baseline Migration 002: Arena
-- Squashed from 20260209–20260213 incremental migrations.
-- Date: 2026-03-03
--
-- Tables: streak_records, daily_challenges, daily_challenge_results,
--         arena_challenges, arena_challenge_answers
--
-- RPCs: Solo modes (streak, speed-sort, daily challenge),
--       Duel lifecycle (create/accept/decline/answer/complete/list)
--
-- All display_name references unified to username.
-- Challenge expiry: 1 minute. Unique pending constraint.
-- Completion: atomic with FOR UPDATE row lock.
-- ============================================================

-- ============================================================
-- 1. TABLES
-- ============================================================

-- 1.1 streak_records
CREATE TABLE IF NOT EXISTS public.streak_records (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    streak_count INT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);
ALTER TABLE public.streak_records OWNER TO postgres;
CREATE INDEX IF NOT EXISTS idx_streak_records_user_id ON public.streak_records(user_id);
CREATE INDEX IF NOT EXISTS idx_streak_records_streak_count ON public.streak_records(streak_count DESC);
ALTER TABLE public.streak_records ENABLE ROW LEVEL SECURITY;

-- 1.2 daily_challenges
CREATE TABLE IF NOT EXISTS public.daily_challenges (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    challenge_date DATE NOT NULL UNIQUE,
    question_ids UUID[] NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);
ALTER TABLE public.daily_challenges OWNER TO postgres;
CREATE INDEX IF NOT EXISTS idx_daily_challenges_date ON public.daily_challenges(challenge_date DESC);
ALTER TABLE public.daily_challenges ENABLE ROW LEVEL SECURITY;

-- 1.3 daily_challenge_results
CREATE TABLE IF NOT EXISTS public.daily_challenge_results (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    challenge_date DATE NOT NULL,
    score INT NOT NULL DEFAULT 0,
    correct_count INT NOT NULL DEFAULT 0,
    time_seconds DECIMAL NOT NULL DEFAULT 0,
    max_combo INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
    UNIQUE (user_id, challenge_date)
);
ALTER TABLE public.daily_challenge_results OWNER TO postgres;
CREATE INDEX IF NOT EXISTS idx_daily_results_date ON public.daily_challenge_results(challenge_date, score DESC);
CREATE INDEX IF NOT EXISTS idx_daily_results_user ON public.daily_challenge_results(user_id);
ALTER TABLE public.daily_challenge_results ENABLE ROW LEVEL SECURITY;

-- 1.4 arena_challenges
CREATE TABLE IF NOT EXISTS public.arena_challenges (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    challenger_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    opponent_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending','accepted','in_progress','completed','expired','declined','cancelled')),
    question_ids UUID[] NOT NULL,
    channel_name TEXT UNIQUE,
    challenger_score INT DEFAULT 0,
    opponent_score INT DEFAULT 0,
    winner_id UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
    expires_at TIMESTAMPTZ DEFAULT timezone('utc', now()) + INTERVAL '1 minute',
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);
ALTER TABLE public.arena_challenges OWNER TO postgres;
CREATE INDEX IF NOT EXISTS idx_challenges_challenger ON public.arena_challenges(challenger_id, status);
CREATE INDEX IF NOT EXISTS idx_challenges_opponent ON public.arena_challenges(opponent_id, status);
CREATE INDEX IF NOT EXISTS idx_challenges_status ON public.arena_challenges(status);
CREATE INDEX IF NOT EXISTS idx_challenges_channel ON public.arena_challenges(channel_name);
ALTER TABLE public.arena_challenges ENABLE ROW LEVEL SECURITY;

-- Only one pending challenge per challenger→opponent pair.
CREATE UNIQUE INDEX IF NOT EXISTS idx_challenges_unique_pending
ON public.arena_challenges(challenger_id, opponent_id)
WHERE status = 'pending';

-- 1.5 arena_challenge_answers
CREATE TABLE IF NOT EXISTS public.arena_challenge_answers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    challenge_id UUID NOT NULL REFERENCES public.arena_challenges(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    question_index INT NOT NULL,
    selected_category TEXT NOT NULL,
    is_correct BOOLEAN NOT NULL,
    answer_time_ms INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
    UNIQUE (challenge_id, user_id, question_index)
);
ALTER TABLE public.arena_challenge_answers OWNER TO postgres;
CREATE INDEX IF NOT EXISTS idx_challenge_answers_challenge ON public.arena_challenge_answers(challenge_id, user_id);
ALTER TABLE public.arena_challenge_answers ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 2. RPC — Solo modes
-- ============================================================

-- 2.1 get_quiz_questions (wrapper, 10 questions)
CREATE OR REPLACE FUNCTION public.get_quiz_questions()
RETURNS SETOF public.quiz_questions
LANGUAGE sql SECURITY DEFINER
SET search_path = public
AS $$
    SELECT * FROM public.get_quiz_questions_batch(10);
$$;
ALTER FUNCTION public.get_quiz_questions() OWNER TO postgres;

-- 2.2 get_quiz_questions_batch
CREATE OR REPLACE FUNCTION public.get_quiz_questions_batch(p_limit INT DEFAULT 10)
RETURNS SETOF public.quiz_questions
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM public.quiz_questions
    WHERE is_active = true
    ORDER BY random()
    LIMIT p_limit;
END;
$$;
ALTER FUNCTION public.get_quiz_questions_batch(INT) OWNER TO postgres;

-- 2.3 submit_streak_record (5 pts per correct answer)
CREATE OR REPLACE FUNCTION public.submit_streak_record(p_streak_count INT)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id   UUID;
    v_record_id UUID;
    v_points    INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    INSERT INTO public.streak_records (user_id, streak_count)
    VALUES (v_user_id, p_streak_count)
    RETURNING id INTO v_record_id;
    v_points := p_streak_count * 5;
    IF v_points > 0 THEN
        UPDATE public.profiles SET credits = credits + v_points WHERE id = v_user_id;
    END IF;
    RETURN v_record_id;
END;
$$;
ALTER FUNCTION public.submit_streak_record(INT) OWNER TO postgres;

-- 2.4 get_streak_leaderboard
CREATE OR REPLACE FUNCTION public.get_streak_leaderboard(p_limit INT DEFAULT 20)
RETURNS TABLE (user_id UUID, display_name TEXT, best_streak INT, total_games BIGINT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT sr.user_id,
           COALESCE(p.username, 'Anonymous') AS display_name,
           MAX(sr.streak_count) AS best_streak,
           COUNT(sr.id) AS total_games
    FROM public.streak_records sr
    JOIN public.profiles p ON p.id = sr.user_id
    GROUP BY sr.user_id, p.username
    ORDER BY best_streak DESC, total_games DESC
    LIMIT p_limit;
END;
$$;
ALTER FUNCTION public.get_streak_leaderboard(INT) OWNER TO postgres;

-- 2.5 get_daily_challenge (get or create today's challenge)
CREATE OR REPLACE FUNCTION public.get_daily_challenge()
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id        UUID;
    v_today          DATE;
    v_challenge_id   UUID;
    v_question_ids   UUID[];
    v_already_played BOOLEAN;
    v_questions      JSON;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    v_today := (timezone('utc', now()))::date;

    SELECT id, question_ids INTO v_challenge_id, v_question_ids
    FROM public.daily_challenges WHERE challenge_date = v_today;

    IF v_challenge_id IS NULL THEN
        SELECT ARRAY(
            SELECT q.id FROM public.quiz_questions q
            WHERE q.is_active = true ORDER BY random() LIMIT 10
        ) INTO v_question_ids;
        INSERT INTO public.daily_challenges (challenge_date, question_ids)
        VALUES (v_today, v_question_ids)
        ON CONFLICT (challenge_date) DO UPDATE SET challenge_date = EXCLUDED.challenge_date
        RETURNING id INTO v_challenge_id;
        SELECT question_ids INTO v_question_ids
        FROM public.daily_challenges WHERE id = v_challenge_id;
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM public.daily_challenge_results
        WHERE user_id = v_user_id AND challenge_date = v_today
    ) INTO v_already_played;

    SELECT json_agg(q ORDER BY ord.ordinality) INTO v_questions
    FROM unnest(v_question_ids) WITH ORDINALITY AS ord(qid, ordinality)
    JOIN public.quiz_questions q ON q.id = ord.qid;

    RETURN json_build_object(
        'challenge_id', v_challenge_id,
        'challenge_date', v_today,
        'already_played', v_already_played,
        'questions', COALESCE(v_questions, '[]'::json)
    );
END;
$$;
ALTER FUNCTION public.get_daily_challenge() OWNER TO postgres;

-- 2.6 submit_daily_challenge (once per day)
CREATE OR REPLACE FUNCTION public.submit_daily_challenge(
    p_score INT, p_correct_count INT,
    p_time_seconds DECIMAL, p_max_combo INT
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id   UUID;
    v_today     DATE;
    v_result_id UUID;
    v_points    INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    v_today := (timezone('utc', now()))::date;

    IF NOT EXISTS (SELECT 1 FROM public.daily_challenges WHERE challenge_date = v_today) THEN
        RAISE EXCEPTION 'No daily challenge for today';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.daily_challenge_results
        WHERE user_id = v_user_id AND challenge_date = v_today
    ) THEN
        RAISE EXCEPTION 'Already completed today''s challenge';
    END IF;

    INSERT INTO public.daily_challenge_results
        (user_id, challenge_date, score, correct_count, time_seconds, max_combo)
    VALUES (v_user_id, v_today, p_score, p_correct_count, p_time_seconds, p_max_combo)
    RETURNING id INTO v_result_id;

    v_points := p_score;
    IF v_points > 0 THEN
        UPDATE public.profiles SET credits = credits + v_points WHERE id = v_user_id;
    END IF;

    RETURN json_build_object('result_id', v_result_id, 'points_awarded', v_points);
END;
$$;
ALTER FUNCTION public.submit_daily_challenge(INT, INT, DECIMAL, INT) OWNER TO postgres;

-- 2.7 get_daily_leaderboard
CREATE OR REPLACE FUNCTION public.get_daily_leaderboard(
    p_date DATE DEFAULT NULL, p_limit INT DEFAULT 50
)
RETURNS TABLE (
    rank BIGINT, user_id UUID, display_name TEXT,
    score INT, correct_count INT, time_seconds DECIMAL, max_combo INT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_date DATE;
BEGIN
    v_date := COALESCE(p_date, (timezone('utc', now()))::date);
    RETURN QUERY
    SELECT ROW_NUMBER() OVER (ORDER BY dr.score DESC, dr.time_seconds ASC),
           dr.user_id,
           COALESCE(p.username, 'Anonymous') AS display_name,
           dr.score, dr.correct_count, dr.time_seconds, dr.max_combo
    FROM public.daily_challenge_results dr
    JOIN public.profiles p ON p.id = dr.user_id
    WHERE dr.challenge_date = v_date
    ORDER BY dr.score DESC, dr.time_seconds ASC
    LIMIT p_limit;
END;
$$;
ALTER FUNCTION public.get_daily_leaderboard(DATE, INT) OWNER TO postgres;

-- ============================================================
-- 3. RPC — Duel lifecycle
-- ============================================================

-- 3.1 create_arena_challenge (1-min expiry, duplicate check)
CREATE OR REPLACE FUNCTION public.create_arena_challenge(p_opponent_id UUID)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id      UUID;
    v_challenge_id UUID;
    v_question_ids UUID[];
    v_channel_name TEXT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    IF v_user_id = p_opponent_id THEN RAISE EXCEPTION 'Cannot challenge yourself'; END IF;

    -- Expire stale pending challenges.
    UPDATE public.arena_challenges SET status = 'expired'
    WHERE status = 'pending' AND expires_at < timezone('utc', now());

    IF EXISTS (
        SELECT 1 FROM public.arena_challenges
        WHERE challenger_id = v_user_id AND opponent_id = p_opponent_id AND status = 'pending'
    ) THEN
        RAISE EXCEPTION 'You already have a pending challenge to this player';
    END IF;

    SELECT ARRAY(
        SELECT q.id FROM public.quiz_questions q
        WHERE q.is_active = true ORDER BY random() LIMIT 10
    ) INTO v_question_ids;

    IF array_length(v_question_ids, 1) < 10 THEN
        RAISE EXCEPTION 'Not enough questions available';
    END IF;

    v_challenge_id := gen_random_uuid();
    v_channel_name := 'duel:' || v_challenge_id::text;

    INSERT INTO public.arena_challenges (
        id, challenger_id, opponent_id, status, question_ids, channel_name, expires_at
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
ALTER FUNCTION public.create_arena_challenge(UUID) OWNER TO postgres;

-- 3.2 accept_arena_challenge
CREATE OR REPLACE FUNCTION public.accept_arena_challenge(p_challenge_id UUID)
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

    SELECT * INTO v_challenge FROM public.arena_challenges WHERE id = p_challenge_id;
    IF v_challenge IS NULL THEN RAISE EXCEPTION 'Challenge not found'; END IF;
    IF v_challenge.opponent_id != v_user_id AND v_challenge.challenger_id != v_user_id THEN
        RAISE EXCEPTION 'Not your challenge';
    END IF;
    IF v_challenge.status != 'pending' THEN
        RAISE EXCEPTION 'Challenge is no longer pending (status: %)', v_challenge.status;
    END IF;
    IF v_challenge.expires_at < timezone('utc', now()) THEN
        UPDATE public.arena_challenges SET status = 'expired' WHERE id = p_challenge_id;
        RAISE EXCEPTION 'Challenge has expired';
    END IF;

    UPDATE public.arena_challenges SET status = 'accepted' WHERE id = p_challenge_id;

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
ALTER FUNCTION public.accept_arena_challenge(UUID) OWNER TO postgres;

-- 3.3 decline_arena_challenge
CREATE OR REPLACE FUNCTION public.decline_arena_challenge(p_challenge_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id   UUID;
    v_challenge RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

    SELECT * INTO v_challenge FROM public.arena_challenges WHERE id = p_challenge_id;
    IF v_challenge IS NULL THEN RAISE EXCEPTION 'Challenge not found'; END IF;
    IF v_challenge.challenger_id != v_user_id AND v_challenge.opponent_id != v_user_id THEN
        RAISE EXCEPTION 'Not your challenge';
    END IF;
    IF v_challenge.status NOT IN ('pending','accepted') THEN
        RAISE EXCEPTION 'Cannot decline challenge in status: %', v_challenge.status;
    END IF;

    IF v_challenge.challenger_id = v_user_id THEN
        UPDATE public.arena_challenges SET status = 'cancelled' WHERE id = p_challenge_id;
    ELSE
        UPDATE public.arena_challenges SET status = 'declined' WHERE id = p_challenge_id;
    END IF;
END;
$$;
ALTER FUNCTION public.decline_arena_challenge(UUID) OWNER TO postgres;

-- 3.4 submit_duel_answer (server-side verification)
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

    SELECT * INTO v_challenge FROM public.arena_challenges WHERE id = p_challenge_id;
    IF v_challenge IS NULL THEN RAISE EXCEPTION 'Challenge not found'; END IF;
    IF v_challenge.challenger_id != v_user_id AND v_challenge.opponent_id != v_user_id THEN
        RAISE EXCEPTION 'Not your challenge';
    END IF;
    IF v_challenge.status NOT IN ('accepted','in_progress') THEN
        RAISE EXCEPTION 'Challenge is not active (status: %)', v_challenge.status;
    END IF;

    IF v_challenge.status = 'accepted' THEN
        UPDATE public.arena_challenges
        SET status = 'in_progress', started_at = timezone('utc', now())
        WHERE id = p_challenge_id AND status = 'accepted';
    END IF;

    v_question_id := v_challenge.question_ids[p_question_index + 1]; -- 1-indexed array
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

-- 3.5 complete_arena_challenge (atomic, FOR UPDATE lock)
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

    -- Lock row to prevent concurrent double-award.
    SELECT * INTO v_challenge
    FROM public.arena_challenges WHERE id = p_challenge_id FOR UPDATE;

    IF v_challenge IS NULL THEN RAISE EXCEPTION 'Challenge not found'; END IF;
    IF v_challenge.challenger_id != v_user_id AND v_challenge.opponent_id != v_user_id THEN
        RAISE EXCEPTION 'Not your challenge';
    END IF;

    -- Idempotent: return existing result if already completed.
    IF v_challenge.status = 'completed' THEN
        RETURN json_build_object(
            'challenge_id', p_challenge_id,
            'challenger_score', v_challenge.challenger_score,
            'opponent_score', v_challenge.opponent_score,
            'winner_id', v_challenge.winner_id,
            'already_completed', true
        );
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

-- 3.6 get_my_challenges
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
    UPDATE public.arena_challenges SET status = 'expired'
    WHERE status = 'pending' AND expires_at < timezone('utc', now());

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

-- 3.7 get_challenge_questions
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

    SELECT * INTO v_challenge FROM public.arena_challenges WHERE id = p_challenge_id;
    IF v_challenge IS NULL THEN RAISE EXCEPTION 'Challenge not found'; END IF;
    IF v_challenge.challenger_id != v_user_id AND v_challenge.opponent_id != v_user_id THEN
        RAISE EXCEPTION 'Not your challenge';
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

-- ============================================================
-- 4. QUIZ SEED DATA
-- ============================================================

INSERT INTO public.quiz_questions (image_url, correct_category, item_name, is_active) VALUES
-- Recyclable
('https://images.unsplash.com/photo-1572949645841-094ead53d9a7?w=400', 'Recyclable', 'Plastic Bottle', true),
('https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=400', 'Recyclable', 'Aluminum Can', true),
('https://images.unsplash.com/photo-1589927986089-35812388d1f4?w=400', 'Recyclable', 'Cardboard Box', true),
('https://images.unsplash.com/photo-1585386959984-a4155224a1ad?w=400', 'Recyclable', 'Glass Jar', true),
('https://images.unsplash.com/photo-1600298882525-5107bb87cf64?w=400', 'Recyclable', 'Newspaper', true),
('https://images.unsplash.com/photo-1523293836414-f04e712e1f3b?w=400', 'Recyclable', 'Plastic Container', true),
('https://images.unsplash.com/photo-1619642751034-765dfdf7c58e?w=400', 'Recyclable', 'Tin Can', true),
('https://images.unsplash.com/photo-1530587191325-3db32d826c18?w=400', 'Recyclable', 'Paper Bag', true),
-- Compostable
('https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=400', 'Compostable', 'Banana Peel', true),
('https://images.unsplash.com/photo-1582515073490-39981397c445?w=400', 'Compostable', 'Apple Core', true),
('https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400', 'Compostable', 'Salad Leaves', true),
('https://images.unsplash.com/photo-1516594798947-e65505dbb29d?w=400', 'Compostable', 'Egg Shells', true),
('https://images.unsplash.com/photo-1601004890684-d8573e12a8da?w=400', 'Compostable', 'Coffee Grounds', true),
('https://images.unsplash.com/photo-1587049352846-4a222e784d38?w=400', 'Compostable', 'Orange Peel', true),
('https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=400', 'Compostable', 'Tea Bag', true),
('https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=400', 'Compostable', 'Bread Slice', true),
-- Hazardous
('https://images.unsplash.com/photo-1619641805634-8d29b4024a95?w=400', 'Hazardous', 'Battery', true),
('https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=400&q=80', 'Hazardous', 'Paint Can', true),
('https://images.unsplash.com/photo-1583947215259-38e31be8751f?w=400', 'Hazardous', 'Light Bulb', true),
('https://images.unsplash.com/photo-1612538498456-e861df91d4d0?w=400', 'Hazardous', 'Motor Oil', true),
('https://images.unsplash.com/photo-1585435557343-3b092031a831?w=400', 'Hazardous', 'Cleaning Chemicals', true),
('https://images.unsplash.com/photo-1587854692152-cbe660dbde88?w=400', 'Hazardous', 'Medicine Bottle', true),
('https://images.unsplash.com/photo-1609592424614-0ac4c5db0f5e?w=400', 'Hazardous', 'Aerosol Can', true),
('https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=400&q=60', 'Hazardous', 'Pesticide', true),
-- Landfill
('https://images.unsplash.com/photo-1558171013-2846a3057b6b?w=400', 'Landfill', 'Chip Bag', true),
('https://images.unsplash.com/photo-1605001011156-cbf0b0f67a51?w=400', 'Landfill', 'Styrofoam Cup', true),
('https://images.unsplash.com/photo-1581783898377-1c85bf937427?w=400', 'Landfill', 'Diaper', true),
('https://images.unsplash.com/photo-1558171013-2846a3057b6b?w=400&q=80', 'Landfill', 'Plastic Wrap', true),
('https://images.unsplash.com/photo-1600585152220-90363fe7e115?w=400', 'Landfill', 'Broken Ceramic', true),
('https://images.unsplash.com/photo-1622226119165-68fad54b2b77?w=400', 'Landfill', 'Used Tissue', true),
('https://images.unsplash.com/photo-1571210862729-78a52d3779a2?w=400', 'Landfill', 'Rubber Gloves', true),
('https://images.unsplash.com/photo-1567538096630-e0c55bd6374c?w=400', 'Landfill', 'Candy Wrapper', true)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 5. GRANT PERMISSIONS
-- ============================================================

GRANT EXECUTE ON FUNCTION public.get_quiz_questions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_quiz_questions_batch(INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_streak_record(INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_streak_leaderboard(INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_daily_challenge() TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_daily_challenge(INT, INT, DECIMAL, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_daily_leaderboard(DATE, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_arena_challenge(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_arena_challenge(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decline_arena_challenge(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_duel_answer(UUID, INT, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_arena_challenge(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_challenges(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_challenge_questions(UUID) TO authenticated;
