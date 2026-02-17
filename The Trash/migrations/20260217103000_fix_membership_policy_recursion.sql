-- ============================================================
-- Migration: 20260217103000_fix_membership_policy_recursion.sql
-- Goal:
--   * Fix "infinite recursion detected in policy" on membership tables.
--   * Avoid self-referencing RLS subqueries on the same table.
--   * Keep compatibility with both historical table names:
--       public.user_community_memberships
--       public.user_community_membership
-- ============================================================

CREATE OR REPLACE FUNCTION public.can_view_community_roster(
    p_community_id TEXT,
    p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_result BOOLEAN := FALSE;
BEGIN
    IF p_community_id IS NULL OR p_user_id IS NULL THEN
        RETURN FALSE;
    END IF;

    IF to_regclass('public.user_community_memberships') IS NOT NULL THEN
        EXECUTE $sql$
            SELECT EXISTS (
                SELECT 1
                FROM public.user_community_memberships m
                WHERE m.community_id = $1
                  AND m.user_id = $2
                  AND m.status IN ('member', 'admin')
            )
        $sql$
        INTO v_result
        USING p_community_id, p_user_id;

        RETURN v_result;
    END IF;

    IF to_regclass('public.user_community_membership') IS NOT NULL THEN
        EXECUTE $sql$
            SELECT EXISTS (
                SELECT 1
                FROM public.user_community_membership m
                WHERE m.community_id = $1
                  AND m.user_id = $2
                  AND m.status IN ('member', 'admin')
            )
        $sql$
        INTO v_result
        USING p_community_id, p_user_id;

        RETURN v_result;
    END IF;

    RETURN FALSE;
END;
$$;

ALTER FUNCTION public.can_view_community_roster(TEXT, UUID) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.can_view_community_roster(TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_view_community_roster(TEXT, UUID) TO authenticated;

DO $$
BEGIN
    IF to_regclass('public.user_community_memberships') IS NOT NULL THEN
        EXECUTE 'DROP POLICY IF EXISTS "Membership roster visibility" ON public.user_community_memberships';
        EXECUTE 'DROP POLICY IF EXISTS "Membership roster visibility (safe)" ON public.user_community_memberships';

        EXECUTE $policy$
            CREATE POLICY "Membership roster visibility"
            ON public.user_community_memberships
            FOR SELECT
            TO authenticated
            USING (
                user_id = auth.uid()
                OR public.can_view_community_roster(community_id, auth.uid())
            )
        $policy$;
    END IF;

    IF to_regclass('public.user_community_membership') IS NOT NULL THEN
        EXECUTE 'DROP POLICY IF EXISTS "Membership roster visibility" ON public.user_community_membership';
        EXECUTE 'DROP POLICY IF EXISTS "Membership roster visibility (safe)" ON public.user_community_membership';

        EXECUTE $policy$
            CREATE POLICY "Membership roster visibility"
            ON public.user_community_membership
            FOR SELECT
            TO authenticated
            USING (
                user_id = auth.uid()
                OR public.can_view_community_roster(community_id, auth.uid())
            )
        $policy$;
    END IF;
END
$$;
