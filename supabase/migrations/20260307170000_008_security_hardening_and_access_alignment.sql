-- ============================================================
-- Migration 008: Security hardening and access alignment
-- Date: 2026-03-07
--
-- Fixes:
-- 1. Overly broad membership / registration RLS
-- 2. Community update/delete permissions
-- 3. Private-community visibility leaks in SECURITY DEFINER RPCs
-- 4. Direct admin achievement grant path
-- 5. Profile access alignment with explicit RPCs
-- 6. Event credit idempotency and participant-status validation
-- ============================================================

-- ============================================================
-- 1. Helpers
-- ============================================================

CREATE OR REPLACE FUNCTION public.can_view_community(
    p_community_id TEXT,
    p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_result BOOLEAN := FALSE;
BEGIN
    IF p_community_id IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM public.communities c
        WHERE c.id = p_community_id
          AND (
              COALESCE(c.is_private, false) = false
              OR c.created_by = p_user_id
              OR (
                  p_user_id IS NOT NULL
                  AND public.can_view_community_roster(p_community_id, p_user_id)
              )
          )
    ) INTO v_result;

    RETURN COALESCE(v_result, FALSE);
END;
$$;

ALTER FUNCTION public.can_view_community(TEXT, UUID) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.can_view_community(TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_view_community(TEXT, UUID) TO authenticated;

-- ============================================================
-- 2. Profiles RLS + explicit profile RPCs
-- ============================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Profiles readable (self)" ON public.profiles;
DROP POLICY IF EXISTS "Profiles update (self)" ON public.profiles;

CREATE POLICY "Profiles readable (self)"
    ON public.profiles FOR SELECT TO authenticated
    USING (id = public.current_user_id());

CREATE POLICY "Profiles update (self)"
    ON public.profiles FOR UPDATE TO authenticated
    USING (id = public.current_user_id())
    WITH CHECK (id = public.current_user_id());

CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS TABLE (
    id UUID,
    username TEXT,
    credits INTEGER,
    selected_achievement_id UUID
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    SELECT p.id, p.username, COALESCE(p.credits, 0), p.selected_achievement_id
    FROM public.profiles p
    WHERE p.id = v_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_my_username(p_username TEXT)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
    v_trimmed TEXT := NULLIF(BTRIM(p_username), '');
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF v_trimmed IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Username cannot be empty');
    END IF;

    UPDATE public.profiles
    SET username = v_trimmed
    WHERE id = v_user_id;

    RETURN json_build_object('success', true, 'message', 'Username updated');
END;
$$;

ALTER FUNCTION public.get_my_profile() OWNER TO postgres;
ALTER FUNCTION public.update_my_username(TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_my_username(TEXT) TO authenticated;

-- ============================================================
-- 3. Community / membership / event RLS alignment
-- ============================================================

DROP POLICY IF EXISTS "Communities update own" ON public.communities;
DROP POLICY IF EXISTS "Communities delete own" ON public.communities;

CREATE POLICY "Communities update own"
    ON public.communities FOR UPDATE TO authenticated
    USING (
        created_by = public.current_user_id()
        OR public.is_community_admin(id, public.current_user_id())
    )
    WITH CHECK (
        created_by = public.current_user_id()
        OR public.is_community_admin(id, public.current_user_id())
    );

CREATE POLICY "Communities delete own"
    ON public.communities FOR DELETE TO authenticated
    USING (
        created_by = public.current_user_id()
        OR public.is_community_admin(id, public.current_user_id())
    );

DROP POLICY IF EXISTS "Membership self-management" ON public.user_community_memberships;
DROP POLICY IF EXISTS "Membership readable (safe)" ON public.user_community_memberships;

CREATE POLICY "Membership readable (safe)"
    ON public.user_community_memberships FOR SELECT TO authenticated
    USING (
        user_id = public.current_user_id()
        OR public.can_view_community_roster(community_id, public.current_user_id())
    );

DROP POLICY IF EXISTS "Events insert (authenticated)" ON public.community_events;
CREATE POLICY "Events insert (authenticated)"
    ON public.community_events FOR INSERT TO authenticated
    WITH CHECK (
        created_by = public.current_user_id()
        AND (
            is_personal IS TRUE
            OR community_id IS NULL
            OR EXISTS (
                SELECT 1
                FROM public.user_community_memberships m
                WHERE m.community_id = public.community_events.community_id
                  AND m.user_id = public.current_user_id()
                  AND m.status = 'admin'
            )
        )
    );

DROP POLICY IF EXISTS "Registrations self-management" ON public.event_registrations;
DROP POLICY IF EXISTS "Registrations readable (owner)" ON public.event_registrations;

CREATE POLICY "Registrations readable (owner)"
    ON public.event_registrations FOR SELECT TO authenticated
    USING (user_id = public.current_user_id());

-- Direct client writes are no longer allowed. Registration must flow
-- through RPCs that enforce event state and capacity.

-- ============================================================
-- 4. Achievements via explicit RPCs
-- ============================================================

DROP POLICY IF EXISTS "Achievements insert (admins)" ON public.achievements;
DROP POLICY IF EXISTS "Achievements update (admins)" ON public.achievements;
DROP POLICY IF EXISTS "User achievements grant" ON public.user_achievements;

CREATE OR REPLACE FUNCTION public.create_community_achievement(
    p_community_id TEXT,
    p_name TEXT,
    p_description TEXT,
    p_icon_name TEXT,
    p_rarity TEXT DEFAULT 'common'
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin_id UUID := public.current_user_id();
    v_achievement_id UUID;
BEGIN
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF NOT public.is_community_admin(p_community_id, v_admin_id) THEN
        RAISE EXCEPTION 'Permission denied';
    END IF;

    INSERT INTO public.achievements (
        id, name, description, icon_name, community_id, rarity, is_hidden
    )
    VALUES (
        gen_random_uuid(),
        NULLIF(BTRIM(p_name), ''),
        NULLIF(BTRIM(p_description), ''),
        NULLIF(BTRIM(p_icon_name), ''),
        p_community_id,
        COALESCE(NULLIF(BTRIM(p_rarity), ''), 'common'),
        false
    )
    RETURNING id INTO v_achievement_id;

    RETURN v_achievement_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.grant_community_achievement(
    p_user_id UUID,
    p_achievement_id UUID,
    p_community_id TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF public.current_user_id() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF NOT public.is_community_admin(p_community_id, public.current_user_id()) THEN
        RAISE EXCEPTION 'Permission denied';
    END IF;
    IF NOT EXISTS (
        SELECT 1
        FROM public.achievements a
        WHERE a.id = p_achievement_id
          AND a.community_id = p_community_id
    ) THEN
        RAISE EXCEPTION 'Achievement does not belong to this community';
    END IF;
    IF NOT EXISTS (
        SELECT 1
        FROM public.user_community_memberships m
        WHERE m.community_id = p_community_id
          AND m.user_id = p_user_id
          AND m.status IN ('member', 'admin')
    ) THEN
        RAISE EXCEPTION 'User is not a member of this community';
    END IF;

    INSERT INTO public.user_achievements (user_id, achievement_id, community_id)
    VALUES (p_user_id, p_achievement_id, p_community_id)
    ON CONFLICT DO NOTHING;

    RETURN TRUE;
END;
$$;

ALTER FUNCTION public.create_community_achievement(TEXT, TEXT, TEXT, TEXT, TEXT) OWNER TO postgres;
ALTER FUNCTION public.grant_community_achievement(UUID, UUID, TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.create_community_achievement(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.grant_community_achievement(UUID, UUID, TEXT) TO authenticated;

-- ============================================================
-- 5. Community / event / leaderboard visibility fixes
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_communities_by_city(p_city TEXT)
RETURNS TABLE (
    id TEXT, name TEXT, city TEXT, state TEXT, description TEXT,
    member_count INTEGER, latitude DOUBLE PRECISION, longitude DOUBLE PRECISION,
    is_member BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := public.current_user_id();
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    SELECT c.id, c.name, c.city, c.state, c.description,
           COALESCE(c.member_count, 0),
           c.latitude::DOUBLE PRECISION, c.longitude::DOUBLE PRECISION,
           EXISTS (
               SELECT 1
               FROM public.user_community_memberships m
               WHERE m.community_id = c.id
                 AND m.user_id = v_uid
                 AND m.status IN ('member','admin')
           )
    FROM public.communities c
    WHERE c.city = p_city
      AND c.is_active = true
      AND public.can_view_community(c.id, v_uid)
    ORDER BY c.member_count DESC, c.name ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_nearby_events(
    p_latitude DECIMAL, p_longitude DECIMAL,
    p_max_distance_km DECIMAL DEFAULT 50,
    p_category TEXT DEFAULT NULL,
    p_only_joined_communities BOOLEAN DEFAULT false,
    p_sort_by TEXT DEFAULT 'date'
)
RETURNS TABLE (
    id UUID, title TEXT, description TEXT, organizer TEXT, category TEXT,
    event_date TIMESTAMPTZ, location TEXT, latitude DECIMAL, longitude DECIMAL,
    icon_name TEXT, max_participants INTEGER, participant_count INTEGER,
    community_id TEXT, community_name TEXT, distance_km DECIMAL,
    is_registered BOOLEAN, is_personal BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
    v_lat_range DECIMAL;
    v_lon_range DECIMAL;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_lat_range := (p_max_distance_km / 111.0) * 1.1;
    v_lon_range := (p_max_distance_km / 50.0) * 1.1;

    RETURN QUERY
    SELECT e.id, e.title, e.description, e.organizer, e.category,
           e.event_date, e.location, e.latitude, e.longitude, e.icon_name,
           e.max_participants, e.participant_count, e.community_id,
           c.name AS community_name,
           public.calculate_distance_km(p_latitude, p_longitude, e.latitude, e.longitude) AS distance_km,
           EXISTS (
               SELECT 1 FROM public.event_registrations r
               WHERE r.event_id = e.id AND r.user_id = v_user_id AND r.status = 'registered'
           ) AS is_registered,
           COALESCE(e.is_personal, false) AS is_personal
    FROM public.community_events e
    LEFT JOIN public.communities c ON e.community_id = c.id
    WHERE e.status = 'upcoming'
      AND e.event_date >= NOW()
      AND e.latitude  BETWEEN (p_latitude  - v_lat_range) AND (p_latitude  + v_lat_range)
      AND e.longitude BETWEEN (p_longitude - v_lon_range) AND (p_longitude + v_lon_range)
      AND public.calculate_distance_km(p_latitude, p_longitude, e.latitude, e.longitude) <= p_max_distance_km
      AND (p_category IS NULL OR e.category = p_category)
      AND (
          e.is_personal = true
          OR e.community_id IS NULL
          OR public.can_view_community(e.community_id, v_user_id)
      )
      AND (
          NOT p_only_joined_communities
          OR e.is_personal = true
          OR EXISTS (
              SELECT 1
              FROM public.user_community_memberships m
              WHERE m.community_id = e.community_id
                AND m.user_id = v_user_id
                AND m.status IN ('member','admin')
          )
      )
    ORDER BY
        CASE WHEN p_sort_by = 'date' THEN e.event_date END ASC,
        CASE WHEN p_sort_by = 'distance' THEN public.calculate_distance_km(p_latitude, p_longitude, e.latitude, e.longitude) END ASC,
        CASE WHEN p_sort_by = 'popularity' THEN e.participant_count END DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_community_events(p_community_id TEXT)
RETURNS TABLE (
    id UUID, title TEXT, description TEXT, organizer TEXT, category TEXT,
    event_date TIMESTAMPTZ, location TEXT, latitude DECIMAL, longitude DECIMAL,
    icon_name TEXT, max_participants INTEGER, participant_count INTEGER,
    community_id TEXT, community_name TEXT, distance_km DECIMAL,
    is_registered BOOLEAN, is_personal BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF NOT public.can_view_community(p_community_id, v_user_id) THEN
        RAISE EXCEPTION 'Permission denied';
    END IF;

    RETURN QUERY
    SELECT e.id, e.title, e.description, e.organizer, e.category,
           e.event_date, e.location, e.latitude, e.longitude, e.icon_name,
           e.max_participants, e.participant_count, e.community_id,
           c.name AS community_name,
           0::DECIMAL AS distance_km,
           EXISTS (
               SELECT 1 FROM public.event_registrations r
               WHERE r.event_id = e.id AND r.user_id = v_user_id AND r.status = 'registered'
           ) AS is_registered,
           COALESCE(e.is_personal, false) AS is_personal
    FROM public.community_events e
    LEFT JOIN public.communities c ON e.community_id = c.id
    WHERE e.community_id = p_community_id
    ORDER BY e.event_date DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_community_leaderboard(
    p_community_id TEXT, p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    id UUID, username TEXT, credits INTEGER,
    community_name TEXT, achievement_icon TEXT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF NOT public.can_view_community(p_community_id, v_user_id) THEN
        RAISE EXCEPTION 'Permission denied';
    END IF;

    RETURN QUERY
    SELECT p.id, COALESCE(p.username, 'Anonymous')::TEXT,
           COALESCE(p.credits, 0), c.name, a.icon_name
    FROM public.user_community_memberships cm
    JOIN public.profiles p ON p.id = cm.user_id
    JOIN public.communities c ON c.id = cm.community_id
    LEFT JOIN public.achievements a ON a.id = p.selected_achievement_id
    WHERE cm.community_id = p_community_id
      AND cm.status IN ('member','admin')
    ORDER BY COALESCE(p.credits, 0) DESC, p.username ASC
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_community_settings(p_community_id TEXT)
RETURNS TABLE (
    id TEXT,
    description TEXT,
    welcome_message TEXT,
    rules TEXT,
    requires_approval BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF public.current_user_id() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF NOT public.is_community_admin(p_community_id, public.current_user_id()) THEN
        RAISE EXCEPTION 'Permission denied';
    END IF;

    RETURN QUERY
    SELECT c.id, c.description, c.welcome_message, c.rules, c.requires_approval
    FROM public.communities c
    WHERE c.id = p_community_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_invitable_members(p_limit INTEGER DEFAULT 50)
RETURNS TABLE (id UUID, display_name TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    SELECT DISTINCT p.id, COALESCE(p.username, 'Anonymous')::TEXT
    FROM public.user_community_memberships mine
    JOIN public.user_community_memberships peers
      ON peers.community_id = mine.community_id
     AND peers.status IN ('member', 'admin')
    JOIN public.profiles p ON p.id = peers.user_id
    WHERE mine.user_id = v_user_id
      AND mine.status IN ('member', 'admin')
      AND peers.user_id != v_user_id
      AND COALESCE(p.username, '') <> ''
    ORDER BY display_name ASC
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
END;
$$;

ALTER FUNCTION public.get_community_settings(TEXT) OWNER TO postgres;
ALTER FUNCTION public.get_invitable_members(INTEGER) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.get_community_settings(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_invitable_members(INTEGER) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_community_events(TEXT) FROM anon;

-- ============================================================
-- 6. Friend leaderboard privacy hardening
-- ============================================================

DROP FUNCTION IF EXISTS public.find_friends_leaderboard(TEXT[], TEXT[]);

CREATE OR REPLACE FUNCTION public.find_friends_leaderboard(
    p_emails TEXT[] DEFAULT ARRAY[]::TEXT[],
    p_phones TEXT[] DEFAULT ARRAY[]::TEXT[]
)
RETURNS TABLE (id UUID, username TEXT, credits INT, email TEXT, phone TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    IF public.current_user_id() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

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
        SELECT p.id,
               COALESCE(p.username, 'Anonymous')::TEXT AS username,
               COALESCE(p.credits, 0) AS credits,
               u.email::TEXT AS email,
               public.normalize_phone_number(u.phone) AS normalized_phone
        FROM public.profiles p
        JOIN auth.users u ON u.id = p.id
    )
    SELECT pa.id, pa.username, pa.credits, NULL::TEXT AS email, NULL::TEXT AS phone
    FROM profiles_with_auth pa
    WHERE EXISTS (SELECT 1 FROM normalized_emails ne WHERE ne.email = LOWER(pa.email))
       OR (pa.normalized_phone IS NOT NULL
           AND EXISTS (SELECT 1 FROM normalized_phones np WHERE np.phone = pa.normalized_phone))
    ORDER BY pa.credits DESC NULLS LAST, pa.username ASC;
END;
$$;

ALTER FUNCTION public.find_friends_leaderboard(TEXT[], TEXT[]) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.find_friends_leaderboard(TEXT[], TEXT[]) TO authenticated;

-- ============================================================
-- 7. Event credit hardening
-- ============================================================

CREATE UNIQUE INDEX IF NOT EXISTS uq_credit_grants_event_user_reason
    ON public.credit_grants (event_id, user_id, reason)
    WHERE event_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.grant_event_credits(
    p_event_id UUID, p_user_ids UUID[],
    p_credits_per_user INTEGER, p_reason TEXT
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin_id UUID := public.current_user_id();
    v_community_id TEXT;
    v_user_id UUID;
    v_granted_count INTEGER := 0;
    v_inserted_id UUID;
BEGIN
    SELECT community_id INTO v_community_id
    FROM public.community_events
    WHERE id = p_event_id;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Event not found', 'granted_count', 0);
    END IF;
    IF NOT (
        public.is_community_admin(v_community_id, v_admin_id)
        OR EXISTS (
            SELECT 1
            FROM public.community_events
            WHERE id = p_event_id AND created_by = v_admin_id
        )
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Permission denied', 'granted_count', 0);
    END IF;
    IF p_credits_per_user <= 0 OR p_credits_per_user > 1000 THEN
        RETURN json_build_object('success', false, 'message', 'Invalid credit amount (must be 1-1000)', 'granted_count', 0);
    END IF;

    FOREACH v_user_id IN ARRAY p_user_ids LOOP
        IF EXISTS (
            SELECT 1
            FROM public.event_registrations
            WHERE event_id = p_event_id
              AND user_id = v_user_id
              AND status = 'registered'
        ) THEN
            INSERT INTO public.credit_grants (
                user_id, granted_by, community_id, event_id, amount, reason
            )
            VALUES (
                v_user_id, v_admin_id, v_community_id, p_event_id, p_credits_per_user, p_reason
            )
            ON CONFLICT (event_id, user_id, reason) WHERE event_id IS NOT NULL DO NOTHING
            RETURNING id INTO v_inserted_id;

            IF v_inserted_id IS NOT NULL THEN
                UPDATE public.profiles
                SET credits = credits + p_credits_per_user
                WHERE id = v_user_id;
                v_granted_count := v_granted_count + 1;
            END IF;

            v_inserted_id := NULL;
        END IF;
    END LOOP;

    INSERT INTO public.admin_action_logs (
        community_id, admin_id, action_type, target_event_id, details
    )
    VALUES (
        v_community_id,
        v_admin_id,
        'grant_credits',
        p_event_id,
        json_build_object(
            'user_count', v_granted_count,
            'credits_per_user', p_credits_per_user,
            'reason', p_reason
        )
    );

    RETURN json_build_object(
        'success', true,
        'message', 'Credits granted',
        'granted_count', v_granted_count
    );
END;
$$;

ALTER FUNCTION public.grant_event_credits(UUID, UUID[], INTEGER, TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.grant_event_credits(UUID, UUID[], INTEGER, TEXT) TO authenticated;
