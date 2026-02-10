-- 008_achievement_system_enhance.sql
-- Enhance achievement system: rarity, trigger keys, auto-grant, member picker

-- 1. Add rarity and trigger_key to achievements
ALTER TABLE public.achievements
ADD COLUMN IF NOT EXISTS rarity TEXT DEFAULT 'common' CHECK (rarity IN ('common', 'rare', 'epic', 'legendary'));

ALTER TABLE public.achievements
ADD COLUMN IF NOT EXISTS trigger_key TEXT UNIQUE;

-- 2. Add total_scans to profiles for scan-count triggers
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS total_scans INT DEFAULT 0;

-- 3. Seed official system achievements (community_id = NULL means official)
INSERT INTO public.achievements (id, name, description, icon_name, community_id, rarity, trigger_key, is_hidden)
VALUES
    ('a0000001-0000-0000-0000-000000000001', 'First Steps', 'Complete your first trash scan', 'leaf.arrow.circlepath', NULL, 'common', 'first_scan', false),
    ('a0000001-0000-0000-0000-000000000002', 'Green Guardian', 'Earn 100 credits', 'shield.lefthalf.filled', NULL, 'common', 'credits_100', false),
    ('a0000001-0000-0000-0000-000000000003', 'Eco Warrior', 'Earn 500 credits', 'bolt.shield.fill', NULL, 'rare', 'credits_500', false),
    ('a0000001-0000-0000-0000-000000000004', 'Planet Savior', 'Earn 2000 credits', 'globe.americas.fill', NULL, 'epic', 'credits_2000', false),
    ('a0000001-0000-0000-0000-000000000005', 'Trash Detective', 'Scan 10 items', 'magnifyingglass', NULL, 'common', 'scans_10', false),
    ('a0000001-0000-0000-0000-000000000006', 'Sorting Master', 'Scan 50 items', 'archivebox.fill', NULL, 'rare', 'scans_50', false),
    ('a0000001-0000-0000-0000-000000000007', 'Community Member', 'Join your first community', 'person.3.fill', NULL, 'common', 'join_community', false),
    ('a0000001-0000-0000-0000-000000000008', 'Arena Champion', 'Win a 1v1 duel', 'trophy.fill', NULL, 'rare', 'arena_win', false)
ON CONFLICT (id) DO NOTHING;

-- 4. RPC: Check and auto-grant achievement by trigger key
CREATE OR REPLACE FUNCTION public.check_and_grant_achievement(p_trigger_key TEXT)
RETURNS JSON AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_achievement RECORD;
    v_profile RECORD;
    v_already_has BOOLEAN;
    v_qualifies BOOLEAN := false;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('granted', false, 'reason', 'Not authenticated');
    END IF;

    -- Find the achievement by trigger key
    SELECT * INTO v_achievement FROM public.achievements
    WHERE trigger_key = p_trigger_key AND community_id IS NULL;

    IF NOT FOUND THEN
        RETURN json_build_object('granted', false, 'reason', 'Achievement not found');
    END IF;

    -- Check if already earned
    SELECT EXISTS (
        SELECT 1 FROM public.user_achievements
        WHERE user_id = v_user_id AND achievement_id = v_achievement.id
    ) INTO v_already_has;

    IF v_already_has THEN
        RETURN json_build_object('granted', false, 'reason', 'Already earned');
    END IF;

    -- Get user profile
    SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id;

    -- Check qualification based on trigger key
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
            -- Arena win is granted directly from the duel completion flow
            v_qualifies := true;
        ELSE
            v_qualifies := false;
    END CASE;

    IF NOT v_qualifies THEN
        RETURN json_build_object('granted', false, 'reason', 'Not qualified');
    END IF;

    -- Grant the achievement
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

-- 5. RPC: Get community members with achievement ownership status (for admin grant UI)
CREATE OR REPLACE FUNCTION public.get_community_members_for_grant(
    p_community_id TEXT,
    p_achievement_id UUID
)
RETURNS TABLE (
    user_id UUID,
    username TEXT,
    already_has BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.user_id,
        COALESCE(p.username, 'Anonymous')::TEXT,
        EXISTS (
            SELECT 1 FROM public.user_achievements ua
            WHERE ua.user_id = m.user_id AND ua.achievement_id = p_achievement_id
        )
    FROM public.user_community_memberships m
    JOIN public.profiles p ON m.user_id = p.id
    WHERE m.community_id = p_community_id
    AND m.status IN ('member', 'admin')
    ORDER BY p.username ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. RPC: Increment total_scans (called after each successful scan)
CREATE OR REPLACE FUNCTION public.increment_total_scans()
RETURNS VOID AS $$
BEGIN
    UPDATE public.profiles
    SET total_scans = COALESCE(total_scans, 0) + 1
    WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
