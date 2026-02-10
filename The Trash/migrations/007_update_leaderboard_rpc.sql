-- 007_update_leaderboard_rpc.sql
-- Update get_community_leaderboard to include achievement icon
-- Fixed: correct table names (profiles, user_community_memberships) and types (p_community_id TEXT)

CREATE OR REPLACE FUNCTION public.get_community_leaderboard(
    p_community_id TEXT,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    id UUID,
    username TEXT,
    credits INT,
    community_name TEXT,
    achievement_icon TEXT
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        COALESCE(p.username, 'Anonymous'),
        COALESCE(p.credits, 0),
        c.name,
        a.icon_name
    FROM public.user_community_memberships cm
    JOIN public.profiles p ON cm.user_id = p.id
    JOIN public.communities c ON cm.community_id = c.id
    LEFT JOIN public.achievements a ON p.selected_achievement_id = a.id
    WHERE cm.community_id = p_community_id
    AND cm.status IN ('member', 'admin')
    ORDER BY p.credits DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
