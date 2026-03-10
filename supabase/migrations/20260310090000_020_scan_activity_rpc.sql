-- 按日期返回当前用户的扫描活动数据
CREATE OR REPLACE FUNCTION public.get_user_scan_activity(
    p_days INTEGER DEFAULT 90
)
RETURNS TABLE (
    scan_date DATE,
    scan_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := public.current_user_id();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    SELECT
        (vre.created_at AT TIME ZONE 'UTC')::DATE AS scan_date,
        COUNT(*)::BIGINT AS scan_count
    FROM public.verify_reward_events vre
    WHERE vre.user_id = v_user_id
      AND vre.created_at >= NOW() - (p_days || ' days')::INTERVAL
    GROUP BY (vre.created_at AT TIME ZONE 'UTC')::DATE
    ORDER BY scan_date DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_scan_activity(INTEGER) TO authenticated;
