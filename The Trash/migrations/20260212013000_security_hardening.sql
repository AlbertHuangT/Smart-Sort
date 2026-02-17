-- ============================================================
-- Migration: 20260212013000_security_hardening.sql
-- Goal:
--   * Eliminate Supabase advisor warnings around mutable search_path
--   * Centralize auth.uid() access through a stable helper for RLS policies
--   * Tighten row-level security on high-traffic tables so only authenticated
--     users (or community admins) can read/write sensitive rows
--   * Replace permissive feedback_logs policy with owner-scoped access
-- ============================================================

-- 1) Force every public function to run with a deterministic search_path.
DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT p.oid::regprocedure AS func_name
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prokind = 'f'
    LOOP
        EXECUTE format('ALTER FUNCTION %s SET search_path = public, pg_temp;', rec.func_name);
    END LOOP;
END $$;

-- 2) Provide a stable helper so RLS policies do not call auth.uid() repeatedly.
CREATE OR REPLACE FUNCTION public.current_user_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT auth.uid();
$$;

ALTER FUNCTION public.current_user_id() OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.current_user_id() TO authenticated;

-- ============================================================
-- Feedback logs: restrict inserts/reads to the owning user.
-- ============================================================

ALTER TABLE public.feedback_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable insert for everyone" ON public.feedback_logs;
DROP POLICY IF EXISTS "Feedback readable" ON public.feedback_logs;
DROP POLICY IF EXISTS "Feedback self-manage" ON public.feedback_logs;

CREATE POLICY "Feedback readable"
    ON public.feedback_logs
    FOR SELECT
    TO authenticated
    USING (user_id = public.current_user_id());

CREATE POLICY "Feedback self-manage"
    ON public.feedback_logs
    FOR ALL
    TO authenticated
    USING (user_id = public.current_user_id())
    WITH CHECK (user_id = public.current_user_id());

-- ============================================================
-- Communities & memberships
-- ============================================================

ALTER TABLE public.communities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_community_memberships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Communities are viewable by everyone" ON public.communities;
DROP POLICY IF EXISTS "Users can view their created communities" ON public.communities;
DROP POLICY IF EXISTS "Users can update their own communities" ON public.communities;
DROP POLICY IF EXISTS "Authenticated users can create communities" ON public.communities;

CREATE POLICY "Communities readable (authenticated)"
    ON public.communities
    FOR SELECT
    TO authenticated
    USING (
        public.current_user_id() IS NOT NULL
        AND (
            COALESCE(is_private, false) = false
            OR created_by = public.current_user_id()
            OR EXISTS (
                SELECT 1
                FROM public.user_community_memberships m
                WHERE m.community_id = public.communities.id
                  AND m.user_id = public.current_user_id()
                  AND m.status IN ('member', 'admin')
            )
        )
    );

CREATE POLICY "Communities insert (authenticated)"
    ON public.communities
    FOR INSERT
    TO authenticated
    WITH CHECK (
        created_by = public.current_user_id()
        AND public.current_user_id() IS NOT NULL
    );

CREATE POLICY "Communities update own"
    ON public.communities
    FOR UPDATE
    TO authenticated
    USING (
        created_by = public.current_user_id()
        OR EXISTS (
            SELECT 1
            FROM public.user_community_memberships m
            WHERE m.community_id = public.communities.id
              AND m.user_id = public.current_user_id()
              AND m.status = 'admin'
        )
    )
    WITH CHECK (
        created_by = public.current_user_id()
        OR EXISTS (
            SELECT 1
            FROM public.user_community_memberships m
            WHERE m.community_id = public.communities.id
              AND m.user_id = public.current_user_id()
              AND m.status = 'admin'
        )
    );

CREATE POLICY "Communities delete own"
    ON public.communities
    FOR DELETE
    TO authenticated
    USING (
        created_by = public.current_user_id()
        OR EXISTS (
            SELECT 1
            FROM public.user_community_memberships m
            WHERE m.community_id = public.communities.id
              AND m.user_id = public.current_user_id()
              AND m.status = 'admin'
        )
    );

DROP POLICY IF EXISTS "Users can view all memberships" ON public.user_community_memberships;
DROP POLICY IF EXISTS "Users can manage own memberships" ON public.user_community_memberships;

CREATE POLICY "Membership roster visibility"
    ON public.user_community_memberships
    FOR SELECT
    TO authenticated
    USING (
        user_id = public.current_user_id()
        OR EXISTS (
            SELECT 1
            FROM public.user_community_memberships my_membership
            WHERE my_membership.user_id = public.current_user_id()
              AND my_membership.community_id = public.user_community_memberships.community_id
              AND my_membership.status IN ('member', 'admin')
        )
    );

CREATE POLICY "Membership self-management"
    ON public.user_community_memberships
    FOR ALL
    TO authenticated
    USING (user_id = public.current_user_id())
    WITH CHECK (user_id = public.current_user_id());

-- ============================================================
-- Community events & registrations
-- ============================================================

ALTER TABLE public.community_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_registrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view all events" ON public.community_events;
DROP POLICY IF EXISTS "Users can update their own events" ON public.community_events;
DROP POLICY IF EXISTS "Authenticated users can create events" ON public.community_events;

CREATE POLICY "Events readable (members)"
    ON public.community_events
    FOR SELECT
    TO authenticated
    USING (
        public.current_user_id() IS NOT NULL
        AND (
            (is_personal IS TRUE AND created_by = public.current_user_id())
            OR (is_personal IS NOT TRUE AND (
                community_id IS NULL
                OR EXISTS (
                    SELECT 1
                    FROM public.communities c
                    LEFT JOIN public.user_community_memberships m
                        ON m.community_id = c.id
                       AND m.user_id = public.current_user_id()
                    WHERE c.id = public.community_events.community_id
                      AND (
                          COALESCE(c.is_private, false) = false
                          OR m.status IN ('member','admin')
                          OR c.created_by = public.current_user_id()
                      )
                )
            ))
        )
    );

CREATE POLICY "Events insert (authenticated)"
    ON public.community_events
    FOR INSERT
    TO authenticated
    WITH CHECK (
        created_by = public.current_user_id()
        AND (
            is_personal IS TRUE
            OR community_id IS NULL
            OR EXISTS (
                SELECT 1
                FROM public.user_community_memberships m
                WHERE m.community_id = community_id
                  AND m.user_id = public.current_user_id()
                  AND m.status IN ('member','admin')
            )
        )
    );

CREATE POLICY "Events update (owner-or-admin)"
    ON public.community_events
    FOR UPDATE
    TO authenticated
    USING (
        created_by = public.current_user_id()
        OR (
            community_id IS NOT NULL
            AND EXISTS (
                SELECT 1
                FROM public.user_community_memberships m
                WHERE m.community_id = community_id
                  AND m.user_id = public.current_user_id()
                  AND m.status = 'admin'
            )
        )
    )
    WITH CHECK (
        created_by = public.current_user_id()
        OR (
            community_id IS NOT NULL
            AND EXISTS (
                SELECT 1
                FROM public.user_community_memberships m
                WHERE m.community_id = community_id
                  AND m.user_id = public.current_user_id()
                  AND m.status = 'admin'
            )
        )
    );

CREATE POLICY "Events delete (owner-or-admin)"
    ON public.community_events
    FOR DELETE
    TO authenticated
    USING (
        created_by = public.current_user_id()
        OR (
            community_id IS NOT NULL
            AND EXISTS (
                SELECT 1
                FROM public.user_community_memberships m
                WHERE m.community_id = community_id
                  AND m.user_id = public.current_user_id()
                  AND m.status = 'admin'
            )
        )
    );

DROP POLICY IF EXISTS "Users can view own registrations" ON public.event_registrations;
DROP POLICY IF EXISTS "Users can manage own registrations" ON public.event_registrations;

CREATE POLICY "Registrations readable (owner)"
    ON public.event_registrations
    FOR SELECT
    TO authenticated
    USING (user_id = public.current_user_id());

CREATE POLICY "Registrations self-management"
    ON public.event_registrations
    FOR ALL
    TO authenticated
    USING (user_id = public.current_user_id())
    WITH CHECK (user_id = public.current_user_id());

-- ============================================================
-- Community admin workflows (applications, logs, credits)
-- ============================================================

ALTER TABLE public.community_join_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_action_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_grants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own applications" ON public.community_join_applications;
CREATE POLICY "Users can view own applications"
    ON public.community_join_applications
    FOR SELECT
    TO authenticated
    USING (
        public.current_user_id() = user_id
        OR public.is_community_admin(community_id, public.current_user_id())
    );

DROP POLICY IF EXISTS "Admins can view action logs" ON public.admin_action_logs;
CREATE POLICY "Admins can view action logs"
    ON public.admin_action_logs
    FOR SELECT
    TO authenticated
    USING (public.is_community_admin(community_id, public.current_user_id()));

DROP POLICY IF EXISTS "Users can view own credit grants" ON public.credit_grants;
CREATE POLICY "Users can view own credit grants"
    ON public.credit_grants
    FOR SELECT
    TO authenticated
    USING (
        public.current_user_id() = user_id
        OR (
            community_id IS NOT NULL
            AND public.is_community_admin(community_id, public.current_user_id())
        )
    );

-- ============================================================
-- Achievements
-- ============================================================

ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read on achievements" ON public.achievements;
DROP POLICY IF EXISTS "Allow admins to create community achievements" ON public.achievements;
DROP POLICY IF EXISTS "Allow admins to update community achievements" ON public.achievements;

CREATE POLICY "Achievements readable (auth)"
    ON public.achievements
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Achievements insert (admins)"
    ON public.achievements
    FOR INSERT
    TO authenticated
    WITH CHECK (
        community_id IS NOT NULL
        AND EXISTS (
            SELECT 1
            FROM public.user_community_memberships m
            WHERE m.community_id = public.achievements.community_id
              AND m.user_id = public.current_user_id()
              AND m.status = 'admin'
        )
    );

CREATE POLICY "Achievements update (admins)"
    ON public.achievements
    FOR UPDATE
    TO authenticated
    USING (
        community_id IS NOT NULL
        AND EXISTS (
            SELECT 1
            FROM public.user_community_memberships m
            WHERE m.community_id = public.achievements.community_id
              AND m.user_id = public.current_user_id()
              AND m.status = 'admin'
        )
    )
    WITH CHECK (
        community_id IS NOT NULL
        AND EXISTS (
            SELECT 1
            FROM public.user_community_memberships m
            WHERE m.community_id = public.achievements.community_id
              AND m.user_id = public.current_user_id()
              AND m.status = 'admin'
        )
    );

DROP POLICY IF EXISTS "Allow users to read achievements" ON public.user_achievements;
DROP POLICY IF EXISTS "Allow admins to grant achievements" ON public.user_achievements;

CREATE POLICY "User achievements readable"
    ON public.user_achievements
    FOR SELECT
    TO authenticated
    USING (
        user_id = public.current_user_id()
        OR (
            community_id IS NOT NULL
            AND EXISTS (
                SELECT 1
                FROM public.user_community_memberships m
                WHERE m.community_id = public.user_achievements.community_id
                  AND m.user_id = public.current_user_id()
                  AND m.status = 'admin'
            )
        )
    );

CREATE POLICY "User achievements grant"
    ON public.user_achievements
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.achievements a
            LEFT JOIN public.user_community_memberships m
                ON m.community_id = a.community_id
               AND m.user_id = public.current_user_id()
            WHERE a.id = achievement_id
              AND (
                  a.community_id IS NULL
                  OR m.status = 'admin'
              )
        )
    );

-- ============================================================
-- Daily & streak challenges
-- ============================================================

ALTER TABLE public.daily_challenge_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.streak_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert their own daily results" ON public.daily_challenge_results;
CREATE POLICY "Users can insert their own daily results"
    ON public.daily_challenge_results
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = public.current_user_id());

DROP POLICY IF EXISTS "Users can insert their own streak records" ON public.streak_records;
CREATE POLICY "Users can insert their own streak records"
    ON public.streak_records
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = public.current_user_id());

-- ============================================================
-- Arena duel visibility
-- ============================================================

ALTER TABLE public.arena_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.arena_challenge_answers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own challenges" ON public.arena_challenges;
CREATE POLICY "Users can view their own challenges"
    ON public.arena_challenges
    FOR SELECT
    TO authenticated
    USING (
        public.current_user_id() = challenger_id
        OR public.current_user_id() = opponent_id
    );

DROP POLICY IF EXISTS "Users can view answers for their challenges" ON public.arena_challenge_answers;
CREATE POLICY "Users can view answers for their challenges"
    ON public.arena_challenge_answers
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.arena_challenges ac
            WHERE ac.id = challenge_id
              AND (
                  ac.challenger_id = public.current_user_id()
                  OR ac.opponent_id = public.current_user_id()
              )
        )
    );
