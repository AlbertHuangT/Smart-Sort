-- ============================================================
-- Migration: Restore legacy RPC compatibility for iOS client
-- Date: 2026-02-16
-- Goal:
--   - Re-introduce RPCs still used by Swift client.
--   - Keep function execution deterministic via explicit search_path.
--   - Preserve compatibility while the app migrates to newer RPC names.
-- ============================================================

-- Ensure profile fields required by legacy RPCs exist.
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS total_scans INTEGER DEFAULT 0;

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS selected_achievement_id UUID;

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS location_city TEXT,
    ADD COLUMN IF NOT EXISTS location_state TEXT,
    ADD COLUMN IF NOT EXISTS location_latitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS location_longitude DOUBLE PRECISION;

-- Backward-compatible wrapper used by ArenaViewModel.
DROP FUNCTION IF EXISTS public.get_quiz_questions();

CREATE OR REPLACE FUNCTION public.get_quiz_questions()
RETURNS SETOF public.quiz_questions
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT * FROM public.get_quiz_questions_batch(10);
$$;

ALTER FUNCTION public.get_quiz_questions() OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.get_quiz_questions() TO authenticated;

-- Increment user credits after local gameplay or scan confirmation.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname = 'increment_credits'
          AND pg_get_function_identity_arguments(p.oid) = 'amount integer'
    ) THEN
        EXECUTE $create$
            CREATE FUNCTION public.increment_credits(amount INTEGER)
            RETURNS INTEGER
            LANGUAGE plpgsql
            SECURITY DEFINER
            SET search_path = public, pg_temp
            AS $fn$
            DECLARE
                v_user_id UUID;
                v_new_credits INTEGER;
            BEGIN
                v_user_id := public.current_user_id();
                IF v_user_id IS NULL THEN
                    RAISE EXCEPTION 'Not authenticated';
                END IF;

                IF amount IS NULL OR amount <= 0 THEN
                    RAISE EXCEPTION 'amount must be a positive integer';
                END IF;

                UPDATE public.profiles
                SET credits = COALESCE(credits, 0) + amount
                WHERE id = v_user_id
                RETURNING credits INTO v_new_credits;

                IF v_new_credits IS NULL THEN
                    RAISE EXCEPTION 'Profile not found for current user';
                END IF;

                RETURN v_new_credits;
            END;
            $fn$;
        $create$;
    END IF;
END $$;

GRANT EXECUTE ON FUNCTION public.increment_credits(INTEGER) TO authenticated;

-- Increment total scan counter for achievement triggers.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname = 'increment_total_scans'
          AND pg_get_function_identity_arguments(p.oid) = ''
    ) THEN
        EXECUTE $create$
            CREATE FUNCTION public.increment_total_scans()
            RETURNS INTEGER
            LANGUAGE plpgsql
            SECURITY DEFINER
            SET search_path = public, pg_temp
            AS $fn$
            DECLARE
                v_user_id UUID;
                v_new_total INTEGER;
            BEGIN
                v_user_id := public.current_user_id();
                IF v_user_id IS NULL THEN
                    RAISE EXCEPTION 'Not authenticated';
                END IF;

                UPDATE public.profiles
                SET total_scans = COALESCE(total_scans, 0) + 1
                WHERE id = v_user_id
                RETURNING total_scans INTO v_new_total;

                IF v_new_total IS NULL THEN
                    RAISE EXCEPTION 'Profile not found for current user';
                END IF;

                RETURN v_new_total;
            END;
            $fn$;
        $create$;
    END IF;
END $$;

GRANT EXECUTE ON FUNCTION public.increment_total_scans() TO authenticated;

-- City-based community discovery used by UserSettings.
DROP FUNCTION IF EXISTS public.get_communities_by_city(TEXT);

CREATE OR REPLACE FUNCTION public.get_communities_by_city(p_city TEXT)
RETURNS TABLE (
    id TEXT,
    name TEXT,
    city TEXT,
    state TEXT,
    description TEXT,
    member_count INTEGER,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    is_member BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := public.current_user_id();

    RETURN QUERY
    SELECT
        c.id,
        c.name,
        c.city,
        c.state,
        c.description,
        COALESCE(c.member_count, 0),
        c.latitude::DOUBLE PRECISION,
        c.longitude::DOUBLE PRECISION,
        EXISTS (
            SELECT 1
            FROM public.user_community_memberships m
            WHERE m.community_id = c.id
              AND m.user_id = v_user_id
              AND m.status IN ('member', 'admin')
        )
    FROM public.communities c
    WHERE c.city = p_city
      AND c.is_active = true
    ORDER BY c.member_count DESC, c.name ASC;
END;
$$;

ALTER FUNCTION public.get_communities_by_city(TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.get_communities_by_city(TEXT) TO authenticated;

-- Leave community and keep member_count in sync.
DROP FUNCTION IF EXISTS public.leave_community(TEXT);

CREATE OR REPLACE FUNCTION public.leave_community(p_community_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_deleted_count INTEGER;
BEGIN
    v_user_id := public.current_user_id();
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    DELETE FROM public.user_community_memberships
    WHERE user_id = v_user_id
      AND community_id = p_community_id
      AND status IN ('member', 'admin');

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

    IF COALESCE(v_deleted_count, 0) = 0 THEN
        RETURN json_build_object('success', false, 'message', 'Not a member of this community');
    END IF;

    UPDATE public.communities
    SET member_count = GREATEST(0, COALESCE(member_count, 0) - v_deleted_count),
        updated_at = NOW()
    WHERE id = p_community_id;

    RETURN json_build_object('success', true, 'message', 'Left community successfully');
END;
$$;

ALTER FUNCTION public.leave_community(TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.leave_community(TEXT) TO authenticated;

-- Register event participation.
DROP FUNCTION IF EXISTS public.register_for_event(UUID);

CREATE OR REPLACE FUNCTION public.register_for_event(p_event_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_event RECORD;
    v_existing RECORD;
BEGIN
    v_user_id := public.current_user_id();
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    SELECT * INTO v_event
    FROM public.community_events
    WHERE id = p_event_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Event not found');
    END IF;

    IF v_event.status NOT IN ('upcoming', 'ongoing') THEN
        RETURN json_build_object('success', false, 'message', 'Event is not open for registration');
    END IF;

    IF v_event.max_participants IS NOT NULL
       AND COALESCE(v_event.participant_count, 0) >= v_event.max_participants THEN
        RETURN json_build_object('success', false, 'message', 'Event is full');
    END IF;

    SELECT * INTO v_existing
    FROM public.event_registrations
    WHERE event_id = p_event_id
      AND user_id = v_user_id;

    IF FOUND THEN
        IF v_existing.status = 'registered' THEN
            RETURN json_build_object('success', false, 'message', 'Already registered');
        ELSIF v_existing.status = 'cancelled' THEN
            UPDATE public.event_registrations
            SET status = 'registered',
                registered_at = NOW()
            WHERE id = v_existing.id;
        ELSE
            RETURN json_build_object('success', false, 'message', 'Cannot register for this event');
        END IF;
    ELSE
        INSERT INTO public.event_registrations (event_id, user_id, status, registered_at)
        VALUES (p_event_id, v_user_id, 'registered', NOW());
    END IF;

    UPDATE public.community_events
    SET participant_count = COALESCE(participant_count, 0) + 1,
        updated_at = NOW()
    WHERE id = p_event_id;

    RETURN json_build_object('success', true, 'message', 'Registration successful');
END;
$$;

ALTER FUNCTION public.register_for_event(UUID) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.register_for_event(UUID) TO authenticated;

-- Cancel existing registration.
DROP FUNCTION IF EXISTS public.cancel_event_registration(UUID);

CREATE OR REPLACE FUNCTION public.cancel_event_registration(p_event_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := public.current_user_id();
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    UPDATE public.event_registrations
    SET status = 'cancelled'
    WHERE event_id = p_event_id
      AND user_id = v_user_id
      AND status = 'registered';

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Registration not found');
    END IF;

    UPDATE public.community_events
    SET participant_count = GREATEST(0, COALESCE(participant_count, 0) - 1),
        updated_at = NOW()
    WHERE id = p_event_id;

    RETURN json_build_object('success', true, 'message', 'Registration cancelled');
END;
$$;

ALTER FUNCTION public.cancel_event_registration(UUID) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.cancel_event_registration(UUID) TO authenticated;

-- List my registrations for account screens.
DROP FUNCTION IF EXISTS public.get_my_registrations();

CREATE OR REPLACE FUNCTION public.get_my_registrations()
RETURNS TABLE (
    registration_id UUID,
    event_id UUID,
    event_title TEXT,
    event_date TIMESTAMPTZ,
    event_location TEXT,
    event_category TEXT,
    community_name TEXT,
    registration_status TEXT,
    registered_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := public.current_user_id();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    SELECT
        r.id AS registration_id,
        e.id AS event_id,
        e.title AS event_title,
        e.event_date,
        e.location AS event_location,
        e.category AS event_category,
        COALESCE(c.name, 'Personal') AS community_name,
        r.status AS registration_status,
        r.registered_at
    FROM public.event_registrations r
    JOIN public.community_events e ON e.id = r.event_id
    LEFT JOIN public.communities c ON c.id = e.community_id
    WHERE r.user_id = v_user_id
    ORDER BY e.event_date DESC;
END;
$$;

ALTER FUNCTION public.get_my_registrations() OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.get_my_registrations() TO authenticated;

-- Persist current user location preference.
DROP FUNCTION IF EXISTS public.update_user_location(TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION);

CREATE OR REPLACE FUNCTION public.update_user_location(
    p_city TEXT,
    p_state TEXT,
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := public.current_user_id();
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    UPDATE public.profiles
    SET location_city = p_city,
        location_state = p_state,
        location_latitude = p_latitude,
        location_longitude = p_longitude
    WHERE id = v_user_id;

    RETURN json_build_object('success', true, 'message', 'Location updated');
END;
$$;

ALTER FUNCTION public.update_user_location(TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.update_user_location(TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;

-- Community leaderboard endpoint consumed by LeaderboardView.
DROP FUNCTION IF EXISTS public.get_community_leaderboard(TEXT, INTEGER);

CREATE OR REPLACE FUNCTION public.get_community_leaderboard(
    p_community_id TEXT,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    id UUID,
    username TEXT,
    credits INTEGER,
    community_name TEXT,
    achievement_icon TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        COALESCE(p.username, 'Anonymous')::TEXT AS username,
        COALESCE(p.credits, 0) AS credits,
        c.name AS community_name,
        a.icon_name AS achievement_icon
    FROM public.user_community_memberships cm
    JOIN public.profiles p ON p.id = cm.user_id
    JOIN public.communities c ON c.id = cm.community_id
    LEFT JOIN public.achievements a ON a.id = p.selected_achievement_id
    WHERE cm.community_id = p_community_id
      AND cm.status IN ('member', 'admin')
    ORDER BY COALESCE(p.credits, 0) DESC, p.username ASC
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);
END;
$$;

ALTER FUNCTION public.get_community_leaderboard(TEXT, INTEGER) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.get_community_leaderboard(TEXT, INTEGER) TO authenticated;

-- Equip or clear selected achievement.
DROP FUNCTION IF EXISTS public.set_primary_achievement(UUID);

CREATE OR REPLACE FUNCTION public.set_primary_achievement(achievement_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := public.current_user_id();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF achievement_id IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM public.user_achievements ua
        WHERE ua.user_id = v_user_id
          AND ua.achievement_id = set_primary_achievement.achievement_id
    ) THEN
        RAISE EXCEPTION 'User does not own this achievement';
    END IF;

    UPDATE public.profiles
    SET selected_achievement_id = set_primary_achievement.achievement_id
    WHERE id = v_user_id;
END;
$$;

ALTER FUNCTION public.set_primary_achievement(UUID) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.set_primary_achievement(UUID) TO authenticated;

-- Fetch earned achievements with display metadata.
DROP FUNCTION IF EXISTS public.get_my_achievements();

CREATE OR REPLACE FUNCTION public.get_my_achievements()
RETURNS TABLE (
    user_achievement_id UUID,
    achievement_id UUID,
    name TEXT,
    description TEXT,
    icon_name TEXT,
    community_id TEXT,
    community_name TEXT,
    granted_at TIMESTAMPTZ,
    is_equipped BOOLEAN,
    rarity TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := public.current_user_id();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    SELECT
        ua.id AS user_achievement_id,
        a.id AS achievement_id,
        a.name,
        a.description,
        a.icon_name,
        a.community_id,
        c.name AS community_name,
        ua.granted_at,
        (p.selected_achievement_id = a.id) AS is_equipped,
        COALESCE(a.rarity, 'common') AS rarity
    FROM public.user_achievements ua
    JOIN public.achievements a ON a.id = ua.achievement_id
    LEFT JOIN public.communities c ON c.id = a.community_id
    LEFT JOIN public.profiles p ON p.id = ua.user_id
    WHERE ua.user_id = v_user_id
    ORDER BY ua.granted_at DESC;
END;
$$;

ALTER FUNCTION public.get_my_achievements() OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.get_my_achievements() TO authenticated;

-- Admin helper for grant-achievement picker UI.
DROP FUNCTION IF EXISTS public.get_community_members_for_grant(TEXT, UUID);

CREATE OR REPLACE FUNCTION public.get_community_members_for_grant(
    p_community_id TEXT,
    p_achievement_id UUID
)
RETURNS TABLE (
    user_id UUID,
    username TEXT,
    already_has BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin_id UUID;
BEGIN
    v_admin_id := public.current_user_id();
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF NOT public.is_community_admin(p_community_id, v_admin_id) THEN
        RAISE EXCEPTION 'Only community admins can view this list';
    END IF;

    RETURN QUERY
    SELECT
        m.user_id,
        COALESCE(p.username, 'Anonymous')::TEXT AS username,
        EXISTS (
            SELECT 1
            FROM public.user_achievements ua
            WHERE ua.user_id = m.user_id
              AND ua.achievement_id = p_achievement_id
        ) AS already_has
    FROM public.user_community_memberships m
    JOIN public.profiles p ON p.id = m.user_id
    WHERE m.community_id = p_community_id
      AND m.status IN ('member', 'admin')
    ORDER BY p.username ASC;
END;
$$;

ALTER FUNCTION public.get_community_members_for_grant(TEXT, UUID) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.get_community_members_for_grant(TEXT, UUID) TO authenticated;
