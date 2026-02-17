-- ============================================================
-- Migration: 20260212023000_friends_phone_normalization.sql
-- Purpose:
--   1. Normalize phone numbers (default +1 for 10 digits) so that
--      contacts saved without +1 can still match Supabase Auth phones.
--   2. Update find_friends_leaderboard to use the normalization helper.
-- ============================================================

CREATE OR REPLACE FUNCTION public.normalize_phone_number(p_input TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    digits TEXT;
BEGIN
    IF p_input IS NULL THEN
        RETURN NULL;
    END IF;

    digits := regexp_replace(p_input, '[^0-9]', '', 'g');

    IF digits IS NULL OR digits = '' THEN
        RETURN NULL;
    END IF;

    IF length(digits) = 10 THEN
        RETURN '+1' || digits;
    ELSIF length(digits) = 11 AND left(digits, 1) = '1' THEN
        RETURN '+' || digits;
    ELSE
        RETURN '+' || digits;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.find_friends_leaderboard(
    p_emails TEXT[] DEFAULT ARRAY[]::TEXT[],
    p_phones TEXT[] DEFAULT ARRAY[]::TEXT[]
)
RETURNS TABLE (
    id UUID,
    username TEXT,
    credits INT,
    email TEXT,
    phone TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH normalized_emails AS (
        SELECT DISTINCT LOWER(TRIM(e)) AS email
        FROM unnest(COALESCE(p_emails, ARRAY[]::TEXT[])) AS e
        WHERE TRIM(e) <> ''
    ),
    normalized_phones AS (
        SELECT DISTINCT public.normalize_phone_number(raw_phone) AS phone
        FROM unnest(COALESCE(p_phones, ARRAY[]::TEXT[])) AS raw_phone
        CROSS JOIN LATERAL public.normalize_phone_number(raw_phone)
        WHERE public.normalize_phone_number(raw_phone) IS NOT NULL
    ),
    profiles_with_auth AS (
        SELECT
            p.id,
            COALESCE(p.username, 'Anonymous')::TEXT AS username,
            COALESCE(p.credits, 0) AS credits,
            u.email,
            u.phone,
            public.normalize_phone_number(u.phone) AS normalized_phone
        FROM public.profiles p
        JOIN auth.users u ON u.id = p.id
    )
    SELECT
        pa.id,
        pa.username,
        pa.credits,
        pa.email::TEXT,
        pa.phone::TEXT
    FROM profiles_with_auth pa
    WHERE (
        EXISTS (
            SELECT 1
            FROM normalized_emails ne
            WHERE ne.email = LOWER(pa.email)
        )
        OR (
            pa.normalized_phone IS NOT NULL
            AND EXISTS (
                SELECT 1
                FROM normalized_phones np
                WHERE np.phone = pa.normalized_phone
            )
        )
    );
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth;
