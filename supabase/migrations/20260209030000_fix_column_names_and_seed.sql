-- ============================================================
-- Migration 011: Fix display_name → username + Seed quiz data
-- Date: 2026-02-09
-- Description:
--   - Fix all RPC functions that reference display_name to use username
--   - Seed quiz_questions with real trash sorting questions
-- ============================================================

-- ============================================================
-- PART 1: Fix RPC functions (display_name → username)
-- ============================================================

-- Fix get_streak_leaderboard
CREATE OR REPLACE FUNCTION public.get_streak_leaderboard(p_limit INT DEFAULT 20)
RETURNS TABLE (
    user_id UUID,
    display_name TEXT,
    best_streak INT,
    total_games BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        sr.user_id,
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

-- Fix get_daily_leaderboard
CREATE OR REPLACE FUNCTION public.get_daily_leaderboard(
    p_date DATE DEFAULT NULL,
    p_limit INT DEFAULT 50
)
RETURNS TABLE (
    rank BIGINT,
    user_id UUID,
    display_name TEXT,
    score INT,
    correct_count INT,
    time_seconds DECIMAL,
    max_combo INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_date DATE;
BEGIN
    v_date := COALESCE(p_date, (timezone('utc', now()))::date);

    RETURN QUERY
    SELECT
        ROW_NUMBER() OVER (ORDER BY dr.score DESC, dr.time_seconds ASC) AS rank,
        dr.user_id,
        COALESCE(p.username, 'Anonymous') AS display_name,
        dr.score,
        dr.correct_count,
        dr.time_seconds,
        dr.max_combo
    FROM public.daily_challenge_results dr
    JOIN public.profiles p ON p.id = dr.user_id
    WHERE dr.challenge_date = v_date
    ORDER BY dr.score DESC, dr.time_seconds ASC
    LIMIT p_limit;
END;
$$;

-- Fix get_my_challenges
CREATE OR REPLACE FUNCTION public.get_my_challenges(p_status TEXT DEFAULT NULL)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_result JSON;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Expire old pending challenges
    UPDATE public.arena_challenges
    SET status = 'expired'
    WHERE status = 'pending'
    AND expires_at < timezone('utc', now());

    SELECT json_agg(row_to_json(t))
    INTO v_result
    FROM (
        SELECT
            ac.id,
            ac.challenger_id,
            ac.opponent_id,
            ac.status,
            ac.challenger_score,
            ac.opponent_score,
            ac.winner_id,
            ac.channel_name,
            ac.created_at,
            ac.expires_at,
            ac.started_at,
            ac.completed_at,
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

-- ============================================================
-- PART 2: Seed quiz_questions with real trash sorting questions
-- Using public domain / free stock image URLs from Supabase Storage
-- or placeholder URLs that the app can display
-- ============================================================

INSERT INTO public.quiz_questions (image_url, correct_category, item_name, is_active) VALUES
-- Recyclable items
('https://images.unsplash.com/photo-1572949645841-094ead53d9a7?w=400', 'Recyclable', 'Plastic Bottle', true),
('https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=400', 'Recyclable', 'Aluminum Can', true),
('https://images.unsplash.com/photo-1589927986089-35812388d1f4?w=400', 'Recyclable', 'Cardboard Box', true),
('https://images.unsplash.com/photo-1585386959984-a4155224a1ad?w=400', 'Recyclable', 'Glass Jar', true),
('https://images.unsplash.com/photo-1600298882525-5107bb87cf64?w=400', 'Recyclable', 'Newspaper', true),
('https://images.unsplash.com/photo-1523293836414-f04e712e1f3b?w=400', 'Recyclable', 'Plastic Container', true),
('https://images.unsplash.com/photo-1619642751034-765dfdf7c58e?w=400', 'Recyclable', 'Tin Can', true),
('https://images.unsplash.com/photo-1530587191325-3db32d826c18?w=400', 'Recyclable', 'Paper Bag', true),

-- Compostable items
('https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=400', 'Compostable', 'Banana Peel', true),
('https://images.unsplash.com/photo-1582515073490-39981397c445?w=400', 'Compostable', 'Apple Core', true),
('https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400', 'Compostable', 'Salad Leaves', true),
('https://images.unsplash.com/photo-1516594798947-e65505dbb29d?w=400', 'Compostable', 'Egg Shells', true),
('https://images.unsplash.com/photo-1601004890684-d8573e12a8da?w=400', 'Compostable', 'Coffee Grounds', true),
('https://images.unsplash.com/photo-1587049352846-4a222e784d38?w=400', 'Compostable', 'Orange Peel', true),
('https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=400', 'Compostable', 'Tea Bag', true),
('https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=400', 'Compostable', 'Bread Slice', true),

-- Hazardous items
('https://images.unsplash.com/photo-1619641805634-8d29b4024a95?w=400', 'Hazardous', 'Battery', true),
('https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=400&q=80', 'Hazardous', 'Paint Can', true),
('https://images.unsplash.com/photo-1583947215259-38e31be8751f?w=400', 'Hazardous', 'Light Bulb', true),
('https://images.unsplash.com/photo-1612538498456-e861df91d4d0?w=400', 'Hazardous', 'Motor Oil', true),
('https://images.unsplash.com/photo-1585435557343-3b092031a831?w=400', 'Hazardous', 'Cleaning Chemicals', true),
('https://images.unsplash.com/photo-1587854692152-cbe660dbde88?w=400', 'Hazardous', 'Medicine Bottle', true),
('https://images.unsplash.com/photo-1609592424614-0ac4c5db0f5e?w=400', 'Hazardous', 'Aerosol Can', true),
('https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=400&q=60', 'Hazardous', 'Pesticide', true),

-- Landfill items
('https://images.unsplash.com/photo-1558171013-2846a3057b6b?w=400', 'Landfill', 'Chip Bag', true),
('https://images.unsplash.com/photo-1605001011156-cbf0b0f67a51?w=400', 'Landfill', 'Styrofoam Cup', true),
('https://images.unsplash.com/photo-1581783898377-1c85bf937427?w=400', 'Landfill', 'Diaper', true),
('https://images.unsplash.com/photo-1558171013-2846a3057b6b?w=400&q=80', 'Landfill', 'Plastic Wrap', true),
('https://images.unsplash.com/photo-1600585152220-90363fe7e115?w=400', 'Landfill', 'Broken Ceramic', true),
('https://images.unsplash.com/photo-1622226119165-68fad54b2b77?w=400', 'Landfill', 'Used Tissue', true),
('https://images.unsplash.com/photo-1571210862729-78a52d3779a2?w=400', 'Landfill', 'Rubber Gloves', true),
('https://images.unsplash.com/photo-1567538096630-e0c55bd6374c?w=400', 'Landfill', 'Candy Wrapper', true);
