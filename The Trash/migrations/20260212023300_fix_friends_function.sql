-- Fix find_friends_leaderboard casting issues (ensure email/phone returned as text)

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
            u.email::TEXT AS email,
            u.phone::TEXT AS phone,
            public.normalize_phone_number(u.phone) AS normalized_phone
        FROM public.profiles p
        JOIN auth.users u ON u.id = p.id
    )
    SELECT
        pa.id,
        pa.username,
        pa.credits,
        pa.email,
        pa.phone
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
