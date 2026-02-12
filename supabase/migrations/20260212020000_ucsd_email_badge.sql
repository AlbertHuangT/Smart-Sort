-- ============================================================
-- Migration: 20260212020000_ucsd_email_badge.sql
-- Description:
--   - Adds UCSD-specific achievement triggered by verified @ucsd.edu email
--   - Updates check_and_grant_achievement to handle the new trigger
-- ============================================================

INSERT INTO public.achievements (id, name, description, icon_name, community_id, rarity, trigger_key, is_hidden)
VALUES (
    'a0000001-0000-0000-0000-000000000009',
    'UCSD Recycler',
    'Verify your UCSD email to represent Triton pride.',
    'graduationcap.fill',
    NULL,
    'rare',
    'ucsd_email',
    false
)
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.check_and_grant_achievement(p_trigger_key TEXT)
RETURNS JSON AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_achievement RECORD;
    v_profile RECORD;
    v_already_has BOOLEAN;
    v_qualifies BOOLEAN := false;
    v_auth_email TEXT;
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
        WHEN 'first_scan' THEN
            v_qualifies := COALESCE(v_profile.total_scans, 0) >= 1;
        WHEN 'scans_10' THEN
            v_qualifies := COALESCE(v_profile.total_scans, 0) >= 10;
        WHEN 'scans_50' THEN
            v_qualifies := COALESCE(v_profile.total_scans, 0) >= 50;
        WHEN 'credits_100' THEN
            v_qualifies := COALESCE(v_profile.credits, 0) >= 100;
        WHEN 'credits_500' THEN
            v_qualifies := COALESCE(v_profile.credits, 0) >= 500;
        WHEN 'credits_2000' THEN
            v_qualifies := COALESCE(v_profile.credits, 0) >= 2000;
        WHEN 'join_community' THEN
            v_qualifies := EXISTS (
                SELECT 1 FROM public.user_community_memberships
                WHERE user_id = v_user_id AND status IN ('member', 'admin')
            );
        WHEN 'arena_win' THEN
            v_qualifies := true;
        WHEN 'ucsd_email' THEN
            SELECT email, email_confirmed_at INTO v_auth_email, v_email_confirmed_at
            FROM auth.users
            WHERE id = v_user_id;
            v_qualifies := v_email_confirmed_at IS NOT NULL
                AND v_auth_email ILIKE '%@ucsd.edu';
        ELSE
            v_qualifies := false;
    END CASE;

    IF NOT v_qualifies THEN
        RETURN json_build_object('granted', false, 'reason', 'Not qualified');
    END IF;

    INSERT INTO public.user_achievements (user_id, achievement_id)
    VALUES (v_user_id, v_achievement.id);

    RETURN json_build_object(
        'granted', true,
        'achievement_id', v_achievement.id,
        'name', v_achievement.name,
        'description', v_achievement.description,
        'icon_name', v_achievement.icon_name,
        'rarity', v_achievement.rarity
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
