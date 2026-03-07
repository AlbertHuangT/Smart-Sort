-- ============================================================
-- Baseline Migration 001: Core Schema
-- Squashed from 20260206–20260303 incremental migrations.
-- Date: 2026-03-03
--
-- Tables: communities (extended), community_events (extended),
--         community_join_applications, admin_action_logs,
--         credit_grants, profiles (extended columns)
--
-- Triggers: auto-maintain member_count & participant_count
--
-- RPCs: Community, Admin, Profile, Achievement, Leaderboard, Friends
--
-- IMPORTANT: RPC functions must NOT manually update member_count
-- or participant_count — triggers handle these exclusively.
-- ============================================================

-- ============================================================
-- 0. HELPERS
-- ============================================================

-- Stable wrapper to avoid repeated auth.uid() calls in RLS policies.
CREATE OR REPLACE FUNCTION public.current_user_id()
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$ SELECT auth.uid(); $$;

ALTER FUNCTION public.current_user_id() OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.current_user_id() TO authenticated;

-- Phone number normalizer (default +1 for US 10-digit numbers).
CREATE OR REPLACE FUNCTION public.normalize_phone_number(p_input TEXT)
RETURNS TEXT
LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE digits TEXT;
BEGIN
    IF p_input IS NULL THEN RETURN NULL; END IF;
    digits := regexp_replace(p_input, '[^0-9]', '', 'g');
    IF digits IS NULL OR digits = '' THEN RETURN NULL; END IF;
    IF length(digits) = 10 THEN RETURN '+1' || digits;
    ELSIF length(digits) = 11 AND left(digits, 1) = '1' THEN RETURN '+' || digits;
    ELSE RETURN '+' || digits;
    END IF;
END;
$$;

-- ============================================================
-- 1. SCHEMA EXTENSIONS
--    (assumes profiles, communities, community_events,
--     event_registrations, achievements, user_achievements,
--     quiz_questions, feedback_logs already exist)
-- ============================================================

-- Profile fields for location, achievements, scan tracking.
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS total_scans INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS selected_achievement_id UUID,
    ADD COLUMN IF NOT EXISTS location_city TEXT,
    ADD COLUMN IF NOT EXISTS location_state TEXT,
    ADD COLUMN IF NOT EXISTS location_latitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS location_longitude DOUBLE PRECISION;

-- Community creator + settings columns.
ALTER TABLE public.communities
    ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS requires_approval BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS welcome_message TEXT,
    ADD COLUMN IF NOT EXISTS rules TEXT,
    ADD COLUMN IF NOT EXISTS tags TEXT[],
    ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_communities_created_by ON public.communities(created_by);

-- Event creator + personal-event flag.
ALTER TABLE public.community_events
    ALTER COLUMN community_id DROP NOT NULL;

ALTER TABLE public.community_events
    ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS is_personal BOOLEAN DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_events_created_by ON public.community_events(created_by);
CREATE INDEX IF NOT EXISTS idx_events_is_personal ON public.community_events(is_personal);

-- ============================================================
-- 2. NEW TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.community_join_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id TEXT NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    message TEXT,
    rejection_reason TEXT,
    reviewed_by UUID REFERENCES auth.users(id),
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
    UNIQUE(community_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_applications_community ON public.community_join_applications(community_id, status);
CREATE INDEX IF NOT EXISTS idx_applications_user ON public.community_join_applications(user_id);
CREATE INDEX IF NOT EXISTS idx_applications_status ON public.community_join_applications(status);

CREATE TABLE IF NOT EXISTS public.admin_action_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id TEXT NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
    admin_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL CHECK (action_type IN (
        'approve_member', 'reject_member', 'remove_member', 'grant_credits',
        'edit_community', 'edit_event', 'delete_event', 'pin_post', 'delete_post'
    )),
    target_user_id UUID REFERENCES auth.users(id),
    target_event_id UUID,
    details JSONB,
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);
CREATE INDEX IF NOT EXISTS idx_admin_logs_community ON public.admin_action_logs(community_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_logs_admin ON public.admin_action_logs(admin_id);

CREATE TABLE IF NOT EXISTS public.credit_grants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    granted_by UUID NOT NULL REFERENCES auth.users(id),
    community_id TEXT REFERENCES public.communities(id) ON DELETE SET NULL,
    event_id UUID,
    amount INTEGER NOT NULL CHECK (amount > 0),
    reason TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);
CREATE INDEX IF NOT EXISTS idx_credit_grants_user ON public.credit_grants(user_id);
CREATE INDEX IF NOT EXISTS idx_credit_grants_community ON public.credit_grants(community_id);
CREATE INDEX IF NOT EXISTS idx_credit_grants_event ON public.credit_grants(event_id);

-- ============================================================
-- 3. TRIGGERS — auto-maintain counters
--    All RPC functions rely on these; they must NOT do manual
--    UPDATE ... member_count or participant_count.
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_community_member_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        IF NEW.status IN ('member', 'admin') THEN
            UPDATE public.communities SET member_count = member_count + 1, updated_at = NOW() WHERE id = NEW.community_id;
        END IF;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        IF OLD.status IN ('member', 'admin') THEN
            UPDATE public.communities SET member_count = GREATEST(0, member_count - 1), updated_at = NOW() WHERE id = OLD.community_id;
        END IF;
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        IF OLD.status NOT IN ('member', 'admin') AND NEW.status IN ('member', 'admin') THEN
            UPDATE public.communities SET member_count = member_count + 1, updated_at = NOW() WHERE id = NEW.community_id;
        ELSIF OLD.status IN ('member', 'admin') AND NEW.status NOT IN ('member', 'admin') THEN
            UPDATE public.communities SET member_count = GREATEST(0, member_count - 1), updated_at = NOW() WHERE id = NEW.community_id;
        END IF;
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS on_community_member_change ON public.user_community_memberships;
CREATE TRIGGER on_community_member_change
AFTER INSERT OR UPDATE OR DELETE ON public.user_community_memberships
FOR EACH ROW EXECUTE FUNCTION public.handle_community_member_count();

CREATE OR REPLACE FUNCTION public.handle_event_participant_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        IF NEW.status = 'registered' THEN
            UPDATE public.community_events SET participant_count = participant_count + 1 WHERE id = NEW.event_id;
        END IF;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        IF OLD.status = 'registered' THEN
            UPDATE public.community_events SET participant_count = GREATEST(0, participant_count - 1) WHERE id = OLD.event_id;
        END IF;
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        IF OLD.status != 'registered' AND NEW.status = 'registered' THEN
            UPDATE public.community_events SET participant_count = participant_count + 1 WHERE id = NEW.event_id;
        ELSIF OLD.status = 'registered' AND NEW.status != 'registered' THEN
            UPDATE public.community_events SET participant_count = GREATEST(0, participant_count - 1) WHERE id = NEW.event_id;
        END IF;
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS on_event_registration_change ON public.event_registrations;
CREATE TRIGGER on_event_registration_change
AFTER INSERT OR UPDATE OR DELETE ON public.event_registrations
FOR EACH ROW EXECUTE FUNCTION public.handle_event_participant_count();

-- ============================================================
-- 4. RPC — Community domain
-- ============================================================

-- 4.1 is_community_admin
CREATE OR REPLACE FUNCTION public.is_community_admin(
    p_community_id TEXT,
    p_user_id UUID DEFAULT auth.uid()
)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.user_community_memberships
        WHERE community_id = p_community_id AND user_id = p_user_id AND status = 'admin'
    );
END;
$$;

-- 4.2 can_user_create_community (max 3)
CREATE OR REPLACE FUNCTION public.can_user_create_community()
RETURNS json LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_count   INTEGER;
    v_max     INTEGER := 3;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('allowed', false, 'reason', 'Not authenticated',
                                 'current_count', 0, 'max_allowed', v_max);
    END IF;
    SELECT COUNT(*) INTO v_count FROM public.communities WHERE created_by = v_user_id;
    IF v_count >= v_max THEN
        RETURN json_build_object('allowed', false, 'reason', 'Maximum community limit reached',
                                 'current_count', v_count, 'max_allowed', v_max);
    END IF;
    RETURN json_build_object('allowed', true, 'reason', NULL,
                             'current_count', v_count, 'max_allowed', v_max);
END;
$$;

-- 4.3 can_user_create_event (max 7/week)
CREATE OR REPLACE FUNCTION public.can_user_create_event()
RETURNS json LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_count   INTEGER;
    v_max     INTEGER := 7;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('allowed', false, 'reason', 'Not authenticated',
                                 'current_count', 0, 'max_allowed', v_max);
    END IF;
    SELECT COUNT(*) INTO v_count
    FROM public.community_events
    WHERE created_by = v_user_id AND created_at >= date_trunc('week', NOW());
    IF v_count >= v_max THEN
        RETURN json_build_object('allowed', false, 'reason', 'Weekly event limit reached',
                                 'current_count', v_count, 'max_allowed', v_max);
    END IF;
    RETURN json_build_object('allowed', true, 'reason', NULL,
                             'current_count', v_count, 'max_allowed', v_max);
END;
$$;

-- 4.4 create_community
CREATE OR REPLACE FUNCTION public.create_community(
    p_id TEXT, p_name TEXT, p_city TEXT, p_state TEXT,
    p_description TEXT DEFAULT NULL, p_latitude DECIMAL DEFAULT NULL,
    p_longitude DECIMAL DEFAULT NULL
)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id    UUID := auth.uid();
    v_can_create json;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;
    v_can_create := public.can_user_create_community();
    IF NOT (v_can_create->>'allowed')::boolean THEN
        RETURN json_build_object('success', false, 'message', v_can_create->>'reason');
    END IF;
    IF EXISTS (SELECT 1 FROM public.communities WHERE id = p_id) THEN
        RETURN json_build_object('success', false, 'message', 'Community ID already exists');
    END IF;
    -- member_count starts at 0; trigger will +1 when admin membership is inserted.
    INSERT INTO public.communities (id, name, city, state, description, latitude, longitude, created_by, member_count)
    VALUES (p_id, p_name, p_city, p_state, p_description, p_latitude, p_longitude, v_user_id, 0);
    INSERT INTO public.user_community_memberships (user_id, community_id, status)
    VALUES (v_user_id, p_id, 'admin');
    RETURN json_build_object('success', true, 'message', 'Community created', 'community_id', p_id);
END;
$$;

-- 4.5 create_event (only admins for community events)
CREATE OR REPLACE FUNCTION public.create_event(
    p_title TEXT, p_description TEXT, p_category TEXT,
    p_event_date TIMESTAMPTZ, p_location TEXT,
    p_latitude DECIMAL, p_longitude DECIMAL,
    p_max_participants INTEGER DEFAULT 50,
    p_community_id TEXT DEFAULT NULL,
    p_icon_name TEXT DEFAULT 'calendar'
)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id     UUID := auth.uid();
    v_can_create  json;
    v_event_id    UUID;
    v_organizer   TEXT;
    v_is_personal BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;
    v_can_create := public.can_user_create_event();
    IF NOT (v_can_create->>'allowed')::boolean THEN
        RETURN json_build_object('success', false, 'message', v_can_create->>'reason');
    END IF;
    v_is_personal := (p_community_id IS NULL);
    IF v_is_personal THEN
        SELECT COALESCE(username, email, 'Anonymous') INTO v_organizer
        FROM public.profiles WHERE id = v_user_id;
    ELSE
        IF NOT EXISTS (
            SELECT 1 FROM public.user_community_memberships
            WHERE user_id = v_user_id AND community_id = p_community_id AND status = 'admin'
        ) THEN
            RETURN json_build_object('success', false, 'message', 'Only community admins can create community events');
        END IF;
        SELECT name INTO v_organizer FROM public.communities WHERE id = p_community_id;
    END IF;
    INSERT INTO public.community_events (
        community_id, title, description, organizer, category, event_date,
        location, latitude, longitude, max_participants, icon_name,
        created_by, is_personal
    ) VALUES (
        p_community_id, p_title, p_description, v_organizer, p_category, p_event_date,
        p_location, p_latitude, p_longitude, p_max_participants, p_icon_name,
        v_user_id, v_is_personal
    ) RETURNING id INTO v_event_id;
    RETURN json_build_object('success', true, 'message', 'Event created', 'event_id', v_event_id);
END;
$$;

-- 4.6 get_communities_by_city
CREATE OR REPLACE FUNCTION public.get_communities_by_city(p_city TEXT)
RETURNS TABLE (
    id TEXT, name TEXT, city TEXT, state TEXT, description TEXT,
    member_count INTEGER, latitude DOUBLE PRECISION, longitude DOUBLE PRECISION,
    is_member BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_uid UUID;
BEGIN
    v_uid := public.current_user_id();
    RETURN QUERY
    SELECT c.id, c.name, c.city, c.state, c.description,
           COALESCE(c.member_count, 0),
           c.latitude::DOUBLE PRECISION, c.longitude::DOUBLE PRECISION,
           EXISTS (
               SELECT 1 FROM public.user_community_memberships m
               WHERE m.community_id = c.id AND m.user_id = v_uid AND m.status IN ('member','admin')
           )
    FROM public.communities c
    WHERE c.city = p_city AND c.is_active = true
    ORDER BY c.member_count DESC, c.name ASC;
END;
$$;

-- 4.7 get_my_communities
CREATE OR REPLACE FUNCTION public.get_my_communities()
RETURNS TABLE (
    id TEXT, name TEXT, city TEXT, state TEXT, description TEXT,
    member_count INTEGER, joined_at TIMESTAMPTZ, status TEXT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT c.id, c.name, c.city, c.state, c.description, c.member_count,
           m.joined_at, m.status
    FROM public.user_community_memberships m
    JOIN public.communities c ON m.community_id = c.id
    WHERE m.user_id = auth.uid() AND m.status IN ('member','admin')
    ORDER BY m.joined_at DESC;
END;
$$;

-- 4.8 apply_to_join_community
-- NOTE: NO manual member_count update — trigger handles INSERT into memberships.
CREATE OR REPLACE FUNCTION public.apply_to_join_community(
    p_community_id TEXT, p_message TEXT DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_requires_approval BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated', 'requires_approval', false);
    END IF;
    SELECT requires_approval INTO v_requires_approval
    FROM public.communities WHERE id = p_community_id AND is_active = true;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Community not found', 'requires_approval', false);
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.user_community_memberships
        WHERE user_id = v_user_id AND community_id = p_community_id
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Already a member', 'requires_approval', false);
    END IF;
    IF NOT COALESCE(v_requires_approval, false) THEN
        -- Direct join — trigger increments member_count.
        INSERT INTO public.user_community_memberships (user_id, community_id, status)
        VALUES (v_user_id, p_community_id, 'member');
        RETURN json_build_object('success', true, 'message', 'Joined successfully', 'requires_approval', false);
    END IF;
    -- Approval required.
    INSERT INTO public.community_join_applications (community_id, user_id, message)
    VALUES (p_community_id, v_user_id, p_message)
    ON CONFLICT (community_id, user_id)
    DO UPDATE SET status = 'pending', message = EXCLUDED.message, updated_at = NOW();
    RETURN json_build_object('success', true, 'message', 'Application submitted', 'requires_approval', true);
END;
$$;

-- 4.9 leave_community
-- NOTE: NO manual member_count update — trigger handles DELETE.
CREATE OR REPLACE FUNCTION public.leave_community(p_community_id TEXT)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id       UUID;
    v_deleted_count INTEGER;
BEGIN
    v_user_id := public.current_user_id();
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;
    DELETE FROM public.user_community_memberships
    WHERE user_id = v_user_id AND community_id = p_community_id AND status IN ('member','admin');
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    IF COALESCE(v_deleted_count, 0) = 0 THEN
        RETURN json_build_object('success', false, 'message', 'Not a member of this community');
    END IF;
    RETURN json_build_object('success', true, 'message', 'Left community successfully');
END;
$$;

-- 4.10 get_nearby_events (bounding-box pre-filter)
-- NOTE: requires pre-existing calculate_distance_km(DECIMAL,DECIMAL,DECIMAL,DECIMAL).
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
    v_user_id   UUID := auth.uid();
    v_lat_range DECIMAL;
    v_lon_range DECIMAL;
BEGIN
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
    WHERE e.status = 'upcoming' AND e.event_date >= NOW()
      AND e.latitude  BETWEEN (p_latitude  - v_lat_range) AND (p_latitude  + v_lat_range)
      AND e.longitude BETWEEN (p_longitude - v_lon_range) AND (p_longitude + v_lon_range)
      AND public.calculate_distance_km(p_latitude, p_longitude, e.latitude, e.longitude) <= p_max_distance_km
      AND (p_category IS NULL OR e.category = p_category)
      AND (
          NOT p_only_joined_communities
          OR e.is_personal = true
          OR EXISTS (
              SELECT 1 FROM public.user_community_memberships m
              WHERE m.community_id = e.community_id AND m.user_id = v_user_id
                AND m.status IN ('member','admin')
          )
      )
    ORDER BY
        CASE WHEN p_sort_by = 'date'       THEN e.event_date END ASC,
        CASE WHEN p_sort_by = 'distance'   THEN public.calculate_distance_km(p_latitude, p_longitude, e.latitude, e.longitude) END ASC,
        CASE WHEN p_sort_by = 'popularity' THEN e.participant_count END DESC;
END;
$$;

-- 4.11 get_community_events
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
BEGIN
    RETURN QUERY
    SELECT e.id, e.title, e.description, e.organizer, e.category,
           e.event_date, e.location, e.latitude, e.longitude, e.icon_name,
           e.max_participants, e.participant_count, e.community_id,
           c.name AS community_name,
           0::DECIMAL AS distance_km,
           EXISTS (
               SELECT 1 FROM public.event_registrations r
               WHERE r.event_id = e.id AND r.user_id = auth.uid() AND r.status = 'registered'
           ) AS is_registered,
           COALESCE(e.is_personal, false) AS is_personal
    FROM public.community_events e
    LEFT JOIN public.communities c ON e.community_id = c.id
    WHERE e.community_id = p_community_id
    ORDER BY e.event_date DESC;
END;
$$;

-- 4.12 register_for_event
-- NOTE: NO manual participant_count — trigger handles it.
CREATE OR REPLACE FUNCTION public.register_for_event(p_event_id UUID)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id  UUID;
    v_event    RECORD;
    v_existing RECORD;
BEGIN
    v_user_id := public.current_user_id();
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;
    SELECT * INTO v_event FROM public.community_events WHERE id = p_event_id FOR UPDATE;
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
    SELECT * INTO v_existing FROM public.event_registrations
    WHERE event_id = p_event_id AND user_id = v_user_id;
    IF FOUND THEN
        IF v_existing.status = 'registered' THEN
            RETURN json_build_object('success', false, 'message', 'Already registered');
        ELSIF v_existing.status = 'cancelled' THEN
            UPDATE public.event_registrations
            SET status = 'registered', registered_at = NOW()
            WHERE id = v_existing.id;
        ELSE
            RETURN json_build_object('success', false, 'message', 'Cannot register for this event');
        END IF;
    ELSE
        INSERT INTO public.event_registrations (event_id, user_id, status, registered_at)
        VALUES (p_event_id, v_user_id, 'registered', NOW());
    END IF;
    RETURN json_build_object('success', true, 'message', 'Registration successful');
END;
$$;

-- 4.13 cancel_event_registration
-- NOTE: NO manual participant_count — trigger handles it.
CREATE OR REPLACE FUNCTION public.cancel_event_registration(p_event_id UUID)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_user_id UUID;
BEGIN
    v_user_id := public.current_user_id();
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;
    UPDATE public.event_registrations
    SET status = 'cancelled'
    WHERE event_id = p_event_id AND user_id = v_user_id AND status = 'registered';
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Registration not found');
    END IF;
    RETURN json_build_object('success', true, 'message', 'Registration cancelled');
END;
$$;

-- 4.14 get_my_registrations
CREATE OR REPLACE FUNCTION public.get_my_registrations()
RETURNS TABLE (
    registration_id UUID, event_id UUID, event_title TEXT,
    event_date TIMESTAMPTZ, event_location TEXT, event_category TEXT,
    community_name TEXT, registration_status TEXT, registered_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_user_id UUID;
BEGIN
    v_user_id := public.current_user_id();
    IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    RETURN QUERY
    SELECT r.id, e.id, e.title, e.event_date, e.location, e.category,
           COALESCE(c.name, 'Personal'), r.status, r.registered_at
    FROM public.event_registrations r
    JOIN public.community_events e ON e.id = r.event_id
    LEFT JOIN public.communities c ON c.id = e.community_id
    WHERE r.user_id = v_user_id
    ORDER BY e.event_date DESC;
END;
$$;

-- 4.15 update_user_location
CREATE OR REPLACE FUNCTION public.update_user_location(
    p_city TEXT, p_state TEXT,
    p_latitude DOUBLE PRECISION, p_longitude DOUBLE PRECISION
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_user_id UUID;
BEGIN
    v_user_id := public.current_user_id();
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;
    UPDATE public.profiles
    SET location_city = p_city, location_state = p_state,
        location_latitude = p_latitude, location_longitude = p_longitude
    WHERE id = v_user_id;
    RETURN json_build_object('success', true, 'message', 'Location updated');
END;
$$;

-- ============================================================
-- 5. RPC — Admin domain
-- ============================================================

-- 5.1 get_pending_applications
CREATE OR REPLACE FUNCTION public.get_pending_applications(p_community_id TEXT)
RETURNS TABLE (
    id UUID, user_id UUID, username TEXT, user_credits INTEGER,
    message TEXT, created_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_community_admin(p_community_id, auth.uid()) THEN
        RAISE EXCEPTION 'Permission denied';
    END IF;
    RETURN QUERY
    SELECT a.id, a.user_id, COALESCE(p.username, 'Anonymous')::TEXT,
           COALESCE(p.credits, 0), a.message, a.created_at
    FROM public.community_join_applications a
    LEFT JOIN public.profiles p ON a.user_id = p.id
    WHERE a.community_id = p_community_id AND a.status = 'pending'
    ORDER BY a.created_at;
END;
$$;

-- 5.2 review_join_application
-- NOTE: NO manual member_count — trigger handles INSERT into memberships.
CREATE OR REPLACE FUNCTION public.review_join_application(
    p_application_id UUID, p_approve BOOLEAN,
    p_rejection_reason TEXT DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin_id     UUID := auth.uid();
    v_community_id TEXT;
    v_user_id      UUID;
    v_username     TEXT;
BEGIN
    SELECT community_id, user_id INTO v_community_id, v_user_id
    FROM public.community_join_applications
    WHERE id = p_application_id AND status = 'pending';
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Application not found');
    END IF;
    IF NOT public.is_community_admin(v_community_id, v_admin_id) THEN
        RETURN json_build_object('success', false, 'message', 'Permission denied');
    END IF;
    SELECT username INTO v_username FROM public.profiles WHERE id = v_user_id;
    IF p_approve THEN
        UPDATE public.community_join_applications
        SET status = 'approved', reviewed_by = v_admin_id,
            reviewed_at = NOW(), updated_at = NOW()
        WHERE id = p_application_id;
        INSERT INTO public.user_community_memberships (user_id, community_id, status)
        VALUES (v_user_id, v_community_id, 'member')
        ON CONFLICT (user_id, community_id) DO NOTHING;
        INSERT INTO public.admin_action_logs (community_id, admin_id, action_type, target_user_id, details)
        VALUES (v_community_id, v_admin_id, 'approve_member', v_user_id,
                json_build_object('username', v_username));
        RETURN json_build_object('success', true, 'message', 'Application approved');
    ELSE
        UPDATE public.community_join_applications
        SET status = 'rejected', reviewed_by = v_admin_id, reviewed_at = NOW(),
            rejection_reason = p_rejection_reason, updated_at = NOW()
        WHERE id = p_application_id;
        INSERT INTO public.admin_action_logs (community_id, admin_id, action_type, target_user_id, details)
        VALUES (v_community_id, v_admin_id, 'reject_member', v_user_id,
                json_build_object('username', v_username, 'reason', p_rejection_reason));
        RETURN json_build_object('success', true, 'message', 'Application rejected');
    END IF;
END;
$$;

-- 5.3 update_community_info
CREATE OR REPLACE FUNCTION public.update_community_info(
    p_community_id TEXT, p_description TEXT DEFAULT NULL,
    p_welcome_message TEXT DEFAULT NULL, p_rules TEXT DEFAULT NULL,
    p_requires_approval BOOLEAN DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_admin_id UUID := auth.uid();
BEGIN
    IF NOT public.is_community_admin(p_community_id, v_admin_id) THEN
        RETURN json_build_object('success', false, 'message', 'Permission denied');
    END IF;
    UPDATE public.communities
    SET description      = COALESCE(p_description, description),
        welcome_message  = COALESCE(p_welcome_message, welcome_message),
        rules            = COALESCE(p_rules, rules),
        requires_approval = COALESCE(p_requires_approval, requires_approval),
        updated_at = NOW()
    WHERE id = p_community_id;
    INSERT INTO public.admin_action_logs (community_id, admin_id, action_type, details)
    VALUES (p_community_id, v_admin_id, 'edit_community',
            json_build_object('description', p_description,
                              'welcome_message', p_welcome_message,
                              'requires_approval', p_requires_approval));
    RETURN json_build_object('success', true, 'message', 'Community updated');
END;
$$;

-- 5.4 remove_community_member
-- NOTE: NO manual member_count — trigger handles DELETE.
CREATE OR REPLACE FUNCTION public.remove_community_member(
    p_community_id TEXT, p_user_id UUID, p_reason TEXT DEFAULT NULL
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_username TEXT;
BEGIN
    IF NOT public.is_community_admin(p_community_id, v_admin_id) THEN
        RETURN json_build_object('success', false, 'message', 'Permission denied');
    END IF;
    IF public.is_community_admin(p_community_id, p_user_id) THEN
        RETURN json_build_object('success', false, 'message', 'Cannot remove admin');
    END IF;
    SELECT username INTO v_username FROM public.profiles WHERE id = p_user_id;
    DELETE FROM public.user_community_memberships
    WHERE community_id = p_community_id AND user_id = p_user_id;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'User is not a member');
    END IF;
    INSERT INTO public.admin_action_logs (community_id, admin_id, action_type, target_user_id, details)
    VALUES (p_community_id, v_admin_id, 'remove_member', p_user_id,
            json_build_object('username', v_username, 'reason', p_reason));
    RETURN json_build_object('success', true, 'message', 'Member removed');
END;
$$;

-- 5.5 grant_event_credits
CREATE OR REPLACE FUNCTION public.grant_event_credits(
    p_event_id UUID, p_user_ids UUID[],
    p_credits_per_user INTEGER, p_reason TEXT
)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin_id      UUID := auth.uid();
    v_community_id  TEXT;
    v_user_id       UUID;
    v_granted_count INTEGER := 0;
BEGIN
    SELECT community_id INTO v_community_id
    FROM public.community_events WHERE id = p_event_id;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Event not found', 'granted_count', 0);
    END IF;
    IF NOT (
        public.is_community_admin(v_community_id, v_admin_id) OR
        EXISTS (SELECT 1 FROM public.community_events WHERE id = p_event_id AND created_by = v_admin_id)
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Permission denied', 'granted_count', 0);
    END IF;
    IF p_credits_per_user <= 0 OR p_credits_per_user > 1000 THEN
        RETURN json_build_object('success', false, 'message', 'Invalid credit amount (must be 1-1000)', 'granted_count', 0);
    END IF;
    FOREACH v_user_id IN ARRAY p_user_ids LOOP
        IF EXISTS (
            SELECT 1 FROM public.event_registrations
            WHERE event_id = p_event_id AND user_id = v_user_id
        ) THEN
            UPDATE public.profiles SET credits = credits + p_credits_per_user WHERE id = v_user_id;
            INSERT INTO public.credit_grants (user_id, granted_by, community_id, event_id, amount, reason)
            VALUES (v_user_id, v_admin_id, v_community_id, p_event_id, p_credits_per_user, p_reason);
            v_granted_count := v_granted_count + 1;
        END IF;
    END LOOP;
    INSERT INTO public.admin_action_logs (community_id, admin_id, action_type, target_event_id, details)
    VALUES (v_community_id, v_admin_id, 'grant_credits', p_event_id,
            json_build_object('user_count', v_granted_count, 'credits_per_user', p_credits_per_user,
                              'total_credits', v_granted_count * p_credits_per_user, 'reason', p_reason));
    RETURN json_build_object('success', true,
                             'message', format('Credits granted to %s users', v_granted_count),
                             'granted_count', v_granted_count);
END;
$$;

-- 5.6 get_community_members_admin
CREATE OR REPLACE FUNCTION public.get_community_members_admin(p_community_id TEXT)
RETURNS TABLE (
    user_id UUID, username TEXT, credits INTEGER,
    status TEXT, joined_at TIMESTAMPTZ, is_admin BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_community_admin(p_community_id, auth.uid()) THEN
        RAISE EXCEPTION 'Permission denied';
    END IF;
    RETURN QUERY
    SELECT m.user_id, COALESCE(p.username, 'Anonymous')::TEXT,
           COALESCE(p.credits, 0), m.status, m.joined_at,
           (m.status = 'admin')
    FROM public.user_community_memberships m
    LEFT JOIN public.profiles p ON m.user_id = p.id
    WHERE m.community_id = p_community_id AND m.status IN ('member','admin')
    ORDER BY CASE WHEN m.status = 'admin' THEN 0 ELSE 1 END, m.joined_at;
END;
$$;

-- 5.7 get_admin_action_logs
CREATE OR REPLACE FUNCTION public.get_admin_action_logs(
    p_community_id TEXT, p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    id UUID, admin_username TEXT, action_type TEXT,
    target_username TEXT, details JSONB, created_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_community_admin(p_community_id, auth.uid()) THEN
        RAISE EXCEPTION 'Permission denied';
    END IF;
    RETURN QUERY
    SELECT l.id, COALESCE(admin_p.username, 'Unknown')::TEXT,
           l.action_type, COALESCE(target_p.username, NULL)::TEXT,
           l.details, l.created_at
    FROM public.admin_action_logs l
    LEFT JOIN public.profiles admin_p ON l.admin_id = admin_p.id
    LEFT JOIN public.profiles target_p ON l.target_user_id = target_p.id
    WHERE l.community_id = p_community_id
    ORDER BY l.created_at DESC LIMIT p_limit;
END;
$$;

-- 5.8 get_event_participants (restricted: admin or event creator only)
CREATE OR REPLACE FUNCTION public.get_event_participants(p_event_id UUID)
RETURNS TABLE (
    user_id UUID, username TEXT, credits INTEGER, registered_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id      UUID := auth.uid();
    v_community_id TEXT;
    v_created_by   UUID;
BEGIN
    SELECT community_id, created_by INTO v_community_id, v_created_by
    FROM public.community_events WHERE id = p_event_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Event not found'; END IF;
    -- Permission: must be event creator or community admin.
    IF v_user_id != v_created_by
       AND (v_community_id IS NULL OR NOT public.is_community_admin(v_community_id, v_user_id))
    THEN
        RAISE EXCEPTION 'Permission denied';
    END IF;
    RETURN QUERY
    SELECT r.user_id, COALESCE(p.username, 'Anonymous')::TEXT,
           COALESCE(p.credits, 0), r.registered_at
    FROM public.event_registrations r
    LEFT JOIN public.profiles p ON r.user_id = p.id
    WHERE r.event_id = p_event_id
    ORDER BY r.registered_at;
END;
$$;

-- ============================================================
-- 6. RPC — Profile / Credits / Scans
-- ============================================================

-- 6.1 increment_credits
CREATE OR REPLACE FUNCTION public.increment_credits(amount INTEGER)
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_uid UUID; v_new INTEGER;
BEGIN
    v_uid := public.current_user_id();
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    IF amount IS NULL OR amount <= 0 THEN RAISE EXCEPTION 'amount must be a positive integer'; END IF;
    UPDATE public.profiles SET credits = COALESCE(credits, 0) + amount
    WHERE id = v_uid RETURNING credits INTO v_new;
    IF v_new IS NULL THEN RAISE EXCEPTION 'Profile not found for current user'; END IF;
    RETURN v_new;
END;
$$;

-- 6.2 increment_total_scans
CREATE OR REPLACE FUNCTION public.increment_total_scans()
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_uid UUID; v_new INTEGER;
BEGIN
    v_uid := public.current_user_id();
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    UPDATE public.profiles SET total_scans = COALESCE(total_scans, 0) + 1
    WHERE id = v_uid RETURNING total_scans INTO v_new;
    IF v_new IS NULL THEN RAISE EXCEPTION 'Profile not found for current user'; END IF;
    RETURN v_new;
END;
$$;

-- ============================================================
-- 7. RPC — Achievements
-- ============================================================

-- 7.1 get_my_achievements
CREATE OR REPLACE FUNCTION public.get_my_achievements()
RETURNS TABLE (
    user_achievement_id UUID, achievement_id UUID, name TEXT,
    description TEXT, icon_name TEXT, community_id TEXT,
    community_name TEXT, granted_at TIMESTAMPTZ,
    is_equipped BOOLEAN, rarity TEXT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_uid UUID;
BEGIN
    v_uid := public.current_user_id();
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    RETURN QUERY
    SELECT ua.id, a.id, a.name, a.description, a.icon_name, a.community_id,
           c.name, ua.granted_at,
           (p.selected_achievement_id = a.id),
           COALESCE(a.rarity, 'common')
    FROM public.user_achievements ua
    JOIN public.achievements a ON a.id = ua.achievement_id
    LEFT JOIN public.communities c ON c.id = a.community_id
    LEFT JOIN public.profiles p ON p.id = ua.user_id
    WHERE ua.user_id = v_uid
    ORDER BY ua.granted_at DESC;
END;
$$;

-- 7.2 set_primary_achievement
CREATE OR REPLACE FUNCTION public.set_primary_achievement(achievement_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_uid UUID;
BEGIN
    v_uid := public.current_user_id();
    IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    IF achievement_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.user_achievements ua
        WHERE ua.user_id = v_uid AND ua.achievement_id = set_primary_achievement.achievement_id
    ) THEN
        RAISE EXCEPTION 'User does not own this achievement';
    END IF;
    UPDATE public.profiles
    SET selected_achievement_id = set_primary_achievement.achievement_id
    WHERE id = v_uid;
END;
$$;

-- 7.3 check_and_grant_achievement
CREATE OR REPLACE FUNCTION public.check_and_grant_achievement(p_trigger_key TEXT)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id            UUID := auth.uid();
    v_achievement        RECORD;
    v_profile            RECORD;
    v_already_has        BOOLEAN;
    v_qualifies          BOOLEAN := false;
    v_auth_email         TEXT;
    v_email_confirmed_at TIMESTAMPTZ;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('granted', false, 'reason', 'Not authenticated');
    END IF;
    SELECT * INTO v_achievement FROM public.achievements
    WHERE trigger_key = p_trigger_key AND community_id IS NULL;
    IF NOT FOUND THEN
        RETURN json_build_object('granted', false, 'reason', 'Achievement not found');
    END IF;
    SELECT EXISTS (
        SELECT 1 FROM public.user_achievements
        WHERE user_id = v_user_id AND achievement_id = v_achievement.id
    ) INTO v_already_has;
    IF v_already_has THEN
        RETURN json_build_object('granted', false, 'reason', 'Already earned');
    END IF;
    SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id;
    CASE p_trigger_key
        WHEN 'first_scan'    THEN v_qualifies := COALESCE(v_profile.total_scans, 0) >= 1;
        WHEN 'scans_10'      THEN v_qualifies := COALESCE(v_profile.total_scans, 0) >= 10;
        WHEN 'scans_50'      THEN v_qualifies := COALESCE(v_profile.total_scans, 0) >= 50;
        WHEN 'credits_100'   THEN v_qualifies := COALESCE(v_profile.credits, 0) >= 100;
        WHEN 'credits_500'   THEN v_qualifies := COALESCE(v_profile.credits, 0) >= 500;
        WHEN 'credits_2000'  THEN v_qualifies := COALESCE(v_profile.credits, 0) >= 2000;
        WHEN 'join_community' THEN
            v_qualifies := EXISTS (
                SELECT 1 FROM public.user_community_memberships
                WHERE user_id = v_user_id AND status IN ('member','admin')
            );
        WHEN 'arena_win' THEN v_qualifies := true;
        WHEN 'ucsd_email' THEN
            SELECT email, email_confirmed_at INTO v_auth_email, v_email_confirmed_at
            FROM auth.users WHERE id = v_user_id;
            v_qualifies := v_email_confirmed_at IS NOT NULL AND v_auth_email ILIKE '%@ucsd.edu';
        ELSE v_qualifies := false;
    END CASE;
    IF NOT v_qualifies THEN
        RETURN json_build_object('granted', false, 'reason', 'Not qualified');
    END IF;
    INSERT INTO public.user_achievements (user_id, achievement_id)
    VALUES (v_user_id, v_achievement.id);
    RETURN json_build_object(
        'granted', true, 'achievement_id', v_achievement.id,
        'name', v_achievement.name, 'description', v_achievement.description,
        'icon_name', v_achievement.icon_name, 'rarity', v_achievement.rarity
    );
END;
$$;

-- 7.4 get_community_members_for_grant
CREATE OR REPLACE FUNCTION public.get_community_members_for_grant(
    p_community_id TEXT, p_achievement_id UUID
)
RETURNS TABLE (user_id UUID, username TEXT, already_has BOOLEAN)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_admin UUID;
BEGIN
    v_admin := public.current_user_id();
    IF v_admin IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
    IF NOT public.is_community_admin(p_community_id, v_admin) THEN
        RAISE EXCEPTION 'Only community admins can view this list';
    END IF;
    RETURN QUERY
    SELECT m.user_id, COALESCE(p.username, 'Anonymous')::TEXT,
           EXISTS (
               SELECT 1 FROM public.user_achievements ua
               WHERE ua.user_id = m.user_id AND ua.achievement_id = p_achievement_id
           )
    FROM public.user_community_memberships m
    JOIN public.profiles p ON p.id = m.user_id
    WHERE m.community_id = p_community_id AND m.status IN ('member','admin')
    ORDER BY p.username ASC;
END;
$$;

-- ============================================================
-- 8. RPC — Leaderboard / Friends
-- ============================================================

-- 8.1 get_community_leaderboard
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
BEGIN
    RETURN QUERY
    SELECT p.id, COALESCE(p.username, 'Anonymous')::TEXT,
           COALESCE(p.credits, 0), c.name, a.icon_name
    FROM public.user_community_memberships cm
    JOIN public.profiles p ON p.id = cm.user_id
    JOIN public.communities c ON c.id = cm.community_id
    LEFT JOIN public.achievements a ON a.id = p.selected_achievement_id
    WHERE cm.community_id = p_community_id AND cm.status IN ('member','admin')
    ORDER BY COALESCE(p.credits, 0) DESC, p.username ASC
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);
END;
$$;

-- 8.2 find_friends_leaderboard (final version with ordering)
CREATE OR REPLACE FUNCTION public.find_friends_leaderboard(
    p_emails TEXT[] DEFAULT ARRAY[]::TEXT[],
    p_phones TEXT[] DEFAULT ARRAY[]::TEXT[]
)
RETURNS TABLE (id UUID, username TEXT, credits INT, email TEXT, phone TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth
AS $$
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
        SELECT p.id, COALESCE(p.username, 'Anonymous')::TEXT AS username,
               COALESCE(p.credits, 0) AS credits,
               u.email::TEXT AS email, u.phone::TEXT AS phone,
               public.normalize_phone_number(u.phone) AS normalized_phone
        FROM public.profiles p
        JOIN auth.users u ON u.id = p.id
    )
    SELECT pa.id, pa.username, pa.credits, pa.email, pa.phone
    FROM profiles_with_auth pa
    WHERE EXISTS (SELECT 1 FROM normalized_emails ne WHERE ne.email = LOWER(pa.email))
       OR (pa.normalized_phone IS NOT NULL
           AND EXISTS (SELECT 1 FROM normalized_phones np WHERE np.phone = pa.normalized_phone))
    ORDER BY pa.credits DESC NULLS LAST;
END;
$$;

-- ============================================================
-- 9. SEED DATA
-- ============================================================

INSERT INTO public.achievements (id, name, description, icon_name, community_id, rarity, trigger_key, is_hidden)
VALUES (
    'a0000001-0000-0000-0000-000000000009',
    'UCSD Recycler',
    'Verify your UCSD email to represent Triton pride.',
    'graduationcap.fill', NULL, 'rare', 'ucsd_email', false
) ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 10. GRANT PERMISSIONS
-- ============================================================

GRANT EXECUTE ON FUNCTION public.current_user_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_community_admin(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_user_create_community() TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_user_create_event() TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_community(TEXT, TEXT, TEXT, TEXT, TEXT, DECIMAL, DECIMAL) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_event(TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, DECIMAL, DECIMAL, INTEGER, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_communities_by_city(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_communities() TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_to_join_community(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.leave_community(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_nearby_events(DECIMAL, DECIMAL, DECIMAL, TEXT, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_community_events(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_community_events(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.register_for_event(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_event_registration(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_registrations() TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_user_location(TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pending_applications(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_join_application(UUID, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_community_info(TEXT, TEXT, TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_community_member(TEXT, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.grant_event_credits(UUID, UUID[], INTEGER, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_community_members_admin(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_action_logs(TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_event_participants(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_credits(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_total_scans() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_achievements() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_primary_achievement(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_and_grant_achievement(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_community_members_for_grant(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_community_leaderboard(TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.find_friends_leaderboard(TEXT[], TEXT[]) TO authenticated;
