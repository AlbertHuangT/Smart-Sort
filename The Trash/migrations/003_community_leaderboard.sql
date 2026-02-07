-- =====================================================
-- 003_community_leaderboard.sql
-- 社区排行榜功能迁移
-- Created: 2026-02-06
-- =====================================================

-- =====================================================
-- 1. GET COMMUNITY LEADERBOARD RPC
-- 获取指定社区的成员排行榜 (按 credits 排序)
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_community_leaderboard(
    p_community_id TEXT,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    id UUID,
    username TEXT,
    credits INTEGER,
    community_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_community_name TEXT;
BEGIN
    -- 获取社区名称
    SELECT c.name INTO v_community_name
    FROM public.communities c
    WHERE c.id = p_community_id;
    
    -- 返回该社区成员的排行榜
    RETURN QUERY
    SELECT 
        p.id,
        COALESCE(p.username, 'Anonymous')::TEXT AS username,
        COALESCE(p.credits, 0) AS credits,
        v_community_name AS community_name
    FROM public.profiles p
    INNER JOIN public.user_community_memberships m 
        ON p.id = m.user_id
    WHERE m.community_id = p_community_id
      AND m.status IN ('member', 'admin')  -- 只包含正式成员和管理员
    ORDER BY p.credits DESC NULLS LAST
    LIMIT p_limit;
END;
$$;

-- 添加函数注释
COMMENT ON FUNCTION public.get_community_leaderboard(TEXT, INTEGER) IS 
'获取指定社区的成员排行榜，按积分降序排列';

-- =====================================================
-- 2. GRANT PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION public.get_community_leaderboard(TEXT, INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION public.get_community_leaderboard(TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_community_leaderboard(TEXT, INTEGER) TO service_role;
