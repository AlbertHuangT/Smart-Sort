-- =====================================================
-- Migration: 002_community_feature.sql
-- Description: Add community & events support with location-based filtering
-- Author: Albert Huang
-- Date: 2026-02-06
-- Version: 2.0 (支持多社区加入、位置筛选、距离排序)
-- =====================================================

-- =====================================================
-- 1. COMMUNITIES TABLE (社区/组织表)
-- =====================================================

CREATE TABLE IF NOT EXISTS public.communities (
    id TEXT PRIMARY KEY,                          -- 社区唯一标识 (如 'san-diego-green')
    name TEXT NOT NULL,                           -- 社区名称
    city TEXT NOT NULL,                           -- 城市
    state TEXT,                                   -- 州/省
    country TEXT DEFAULT 'US',                    -- 国家
    description TEXT,                             -- 社区描述
    logo_url TEXT,                                -- Logo URL
    latitude DECIMAL(10, 8),                      -- 纬度
    longitude DECIMAL(11, 8),                     -- 经度
    member_count INTEGER DEFAULT 0,               -- 成员数量 (缓存值)
    is_active BOOLEAN DEFAULT true,               -- 是否激活
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_communities_city ON public.communities(city);
CREATE INDEX IF NOT EXISTS idx_communities_state ON public.communities(state);
CREATE INDEX IF NOT EXISTS idx_communities_location ON public.communities(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_communities_is_active ON public.communities(is_active);

-- =====================================================
-- 2. USER COMMUNITY MEMBERSHIPS (用户社区关联表 - 多对多)
-- =====================================================

CREATE TABLE IF NOT EXISTS public.user_community_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    community_id TEXT NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'member' CHECK (status IN ('pending', 'member', 'admin', 'banned')),
    joined_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
    UNIQUE(user_id, community_id)                 -- 每个用户每个社区只能有一条记录
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_memberships_user ON public.user_community_memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_memberships_community ON public.user_community_memberships(community_id);
CREATE INDEX IF NOT EXISTS idx_memberships_status ON public.user_community_memberships(status);

-- =====================================================
-- 3. USER LOCATIONS TABLE (用户位置表)
-- =====================================================

-- 修改 profiles 表，添加位置字段
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS location_city TEXT,
ADD COLUMN IF NOT EXISTS location_state TEXT,
ADD COLUMN IF NOT EXISTS location_latitude DECIMAL(10, 8),
ADD COLUMN IF NOT EXISTS location_longitude DECIMAL(11, 8);

-- 创建位置索引
CREATE INDEX IF NOT EXISTS idx_profiles_location ON public.profiles(location_city, location_state);
CREATE INDEX IF NOT EXISTS idx_profiles_coordinates ON public.profiles(location_latitude, location_longitude);

-- =====================================================
-- 4. COMMUNITY EVENTS TABLE (社区活动表)
-- =====================================================

CREATE TABLE IF NOT EXISTS public.community_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id TEXT NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
    title TEXT NOT NULL,                          -- 活动标题
    description TEXT,                             -- 活动描述
    organizer TEXT NOT NULL,                      -- 组织者名称
    category TEXT NOT NULL CHECK (category IN ('cleanup', 'workshop', 'competition', 'education', 'other')),
    event_date TIMESTAMPTZ NOT NULL,              -- 活动时间
    location TEXT NOT NULL,                       -- 活动地点文字描述
    latitude DECIMAL(10, 8) NOT NULL,             -- 纬度
    longitude DECIMAL(11, 8) NOT NULL,            -- 经度
    image_url TEXT,                               -- 活动封面图
    icon_name TEXT DEFAULT 'calendar',            -- SF Symbol 图标名
    max_participants INTEGER DEFAULT 100,         -- 最大参与人数
    participant_count INTEGER DEFAULT 0,          -- 当前参与人数 (缓存值)
    credits_reward INTEGER DEFAULT 10,            -- 参与可获得积分
    status TEXT DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'ongoing', 'completed', 'cancelled')),
    created_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ DEFAULT timezone('utc', now())
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_events_community ON public.community_events(community_id);
CREATE INDEX IF NOT EXISTS idx_events_date ON public.community_events(event_date);
CREATE INDEX IF NOT EXISTS idx_events_category ON public.community_events(category);
CREATE INDEX IF NOT EXISTS idx_events_status ON public.community_events(status);
CREATE INDEX IF NOT EXISTS idx_events_location ON public.community_events(latitude, longitude);

-- =====================================================
-- 5. EVENT REGISTRATIONS TABLE (活动报名表)
-- =====================================================

CREATE TABLE IF NOT EXISTS public.event_registrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES public.community_events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'registered' CHECK (status IN ('registered', 'attended', 'cancelled', 'no_show')),
    registered_at TIMESTAMPTZ DEFAULT timezone('utc', now()),
    attended_at TIMESTAMPTZ,                      -- 签到时间
    credits_earned INTEGER DEFAULT 0,             -- 获得的积分
    UNIQUE(event_id, user_id)                     -- 每个用户每个活动只能报名一次
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_registrations_event ON public.event_registrations(event_id);
CREATE INDEX IF NOT EXISTS idx_registrations_user ON public.event_registrations(user_id);
CREATE INDEX IF NOT EXISTS idx_registrations_status ON public.event_registrations(status);

-- =====================================================
-- 6. HELPER FUNCTIONS (辅助函数)
-- =====================================================

-- 6.1 计算两点之间的距离（公里）- Haversine 公式
CREATE OR REPLACE FUNCTION public.calculate_distance_km(
    lat1 DECIMAL, lon1 DECIMAL,
    lat2 DECIMAL, lon2 DECIMAL
) RETURNS DECIMAL
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
    R CONSTANT DECIMAL := 6371; -- 地球半径（公里）
    dlat DECIMAL;
    dlon DECIMAL;
    a DECIMAL;
    c DECIMAL;
BEGIN
    dlat := radians(lat2 - lat1);
    dlon := radians(lon2 - lon1);
    a := sin(dlat/2) * sin(dlat/2) + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon/2) * sin(dlon/2);
    c := 2 * atan2(sqrt(a), sqrt(1-a));
    RETURN R * c;
END;
$$;

-- =====================================================
-- 7. COMMUNITY FUNCTIONS (社区函数)
-- =====================================================

-- 7.1 获取指定城市的社区列表
CREATE OR REPLACE FUNCTION public.get_communities_by_city(p_city TEXT)
RETURNS TABLE (
    id TEXT,
    name TEXT,
    city TEXT,
    state TEXT,
    description TEXT,
    member_count INTEGER,
    latitude DECIMAL,
    longitude DECIMAL,
    is_member BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.name,
        c.city,
        c.state,
        c.description,
        c.member_count,
        c.latitude,
        c.longitude,
        EXISTS (
            SELECT 1 FROM public.user_community_memberships m
            WHERE m.community_id = c.id
            AND m.user_id = auth.uid()
            AND m.status = 'member'
        ) as is_member
    FROM public.communities c
    WHERE c.city = p_city AND c.is_active = true
    ORDER BY c.member_count DESC;
END;
$$;

-- 7.2 获取用户已加入的社区列表
CREATE OR REPLACE FUNCTION public.get_my_communities()
RETURNS TABLE (
    id TEXT,
    name TEXT,
    city TEXT,
    state TEXT,
    description TEXT,
    member_count INTEGER,
    joined_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.name,
        c.city,
        c.state,
        c.description,
        c.member_count,
        m.joined_at
    FROM public.user_community_memberships m
    JOIN public.communities c ON m.community_id = c.id
    WHERE m.user_id = auth.uid() AND m.status = 'member'
    ORDER BY m.joined_at DESC;
END;
$$;

-- 7.3 加入社区
CREATE OR REPLACE FUNCTION public.join_community(p_community_id TEXT)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_existing RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;
    
    -- 检查社区是否存在
    IF NOT EXISTS (SELECT 1 FROM public.communities WHERE id = p_community_id AND is_active = true) THEN
        RETURN json_build_object('success', false, 'message', 'Community not found');
    END IF;
    
    -- 检查是否已加入
    SELECT * INTO v_existing FROM public.user_community_memberships
    WHERE user_id = v_user_id AND community_id = p_community_id;
    
    IF FOUND THEN
        IF v_existing.status = 'member' THEN
            RETURN json_build_object('success', false, 'message', 'Already a member');
        ELSIF v_existing.status = 'banned' THEN
            RETURN json_build_object('success', false, 'message', 'You are banned from this community');
        ELSE
            -- 重新激活
            UPDATE public.user_community_memberships
            SET status = 'member', joined_at = NOW()
            WHERE id = v_existing.id;
        END IF;
    ELSE
        -- 新加入
        INSERT INTO public.user_community_memberships (user_id, community_id, status)
        VALUES (v_user_id, p_community_id, 'member');
    END IF;
    
    -- 更新社区成员数
    UPDATE public.communities
    SET member_count = member_count + 1, updated_at = NOW()
    WHERE id = p_community_id;
    
    RETURN json_build_object('success', true, 'message', 'Joined community successfully');
END;
$$;

-- 7.4 离开社区
CREATE OR REPLACE FUNCTION public.leave_community(p_community_id TEXT)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;
    
    -- 检查是否是成员
    IF NOT EXISTS (
        SELECT 1 FROM public.user_community_memberships
        WHERE user_id = v_user_id AND community_id = p_community_id AND status = 'member'
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Not a member of this community');
    END IF;
    
    -- 删除成员记录
    DELETE FROM public.user_community_memberships
    WHERE user_id = v_user_id AND community_id = p_community_id;
    
    -- 更新社区成员数
    UPDATE public.communities
    SET member_count = GREATEST(0, member_count - 1), updated_at = NOW()
    WHERE id = p_community_id;
    
    RETURN json_build_object('success', true, 'message', 'Left community successfully');
END;
$$;

-- =====================================================
-- 8. EVENT FUNCTIONS (活动函数)
-- =====================================================

-- 8.1 获取附近活动（基于位置和距离）
CREATE OR REPLACE FUNCTION public.get_nearby_events(
    p_latitude DECIMAL,
    p_longitude DECIMAL,
    p_max_distance_km DECIMAL DEFAULT 50,
    p_category TEXT DEFAULT NULL,
    p_only_joined_communities BOOLEAN DEFAULT false,
    p_sort_by TEXT DEFAULT 'date' -- 'date', 'distance', 'popularity'
)
RETURNS TABLE (
    id UUID,
    title TEXT,
    description TEXT,
    organizer TEXT,
    category TEXT,
    event_date TIMESTAMPTZ,
    location TEXT,
    latitude DECIMAL,
    longitude DECIMAL,
    icon_name TEXT,
    max_participants INTEGER,
    participant_count INTEGER,
    community_id TEXT,
    community_name TEXT,
    distance_km DECIMAL,
    is_registered BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        e.id,
        e.title,
        e.description,
        e.organizer,
        e.category,
        e.event_date,
        e.location,
        e.latitude,
        e.longitude,
        e.icon_name,
        e.max_participants,
        e.participant_count,
        e.community_id,
        c.name as community_name,
        public.calculate_distance_km(p_latitude, p_longitude, e.latitude, e.longitude) as distance_km,
        EXISTS (
            SELECT 1 FROM public.event_registrations r
            WHERE r.event_id = e.id AND r.user_id = auth.uid() AND r.status = 'registered'
        ) as is_registered
    FROM public.community_events e
    JOIN public.communities c ON e.community_id = c.id
    WHERE
        e.status IN ('upcoming', 'ongoing')
        AND e.event_date > NOW()
        AND public.calculate_distance_km(p_latitude, p_longitude, e.latitude, e.longitude) <= p_max_distance_km
        AND (p_category IS NULL OR e.category = p_category)
        AND (
            NOT p_only_joined_communities
            OR EXISTS (
                SELECT 1 FROM public.user_community_memberships m
                WHERE m.community_id = e.community_id
                AND m.user_id = auth.uid()
                AND m.status = 'member'
            )
        )
    ORDER BY
        CASE WHEN p_sort_by = 'date' THEN e.event_date END ASC,
        CASE WHEN p_sort_by = 'distance' THEN public.calculate_distance_km(p_latitude, p_longitude, e.latitude, e.longitude) END ASC,
        CASE WHEN p_sort_by = 'popularity' THEN e.participant_count END DESC,
        e.event_date ASC;
END;
$$;

-- 8.2 报名活动
CREATE OR REPLACE FUNCTION public.register_for_event(p_event_id UUID)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_event RECORD;
    v_existing RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;
    
    -- 获取活动信息
    SELECT * INTO v_event FROM public.community_events WHERE id = p_event_id;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Event not found');
    END IF;
    
    -- 检查活动状态
    IF v_event.status NOT IN ('upcoming', 'ongoing') THEN
        RETURN json_build_object('success', false, 'message', 'Event is not open for registration');
    END IF;
    
    -- 检查名额
    IF v_event.participant_count >= v_event.max_participants THEN
        RETURN json_build_object('success', false, 'message', 'Event is full');
    END IF;
    
    -- 检查是否已报名
    SELECT * INTO v_existing FROM public.event_registrations
    WHERE event_id = p_event_id AND user_id = v_user_id;
    
    IF FOUND THEN
        IF v_existing.status = 'registered' THEN
            RETURN json_build_object('success', false, 'message', 'Already registered');
        ELSIF v_existing.status = 'cancelled' THEN
            -- 重新报名
            UPDATE public.event_registrations
            SET status = 'registered', registered_at = NOW()
            WHERE id = v_existing.id;
        ELSE
            RETURN json_build_object('success', false, 'message', 'Cannot register for this event');
        END IF;
    ELSE
        -- 新报名
        INSERT INTO public.event_registrations (event_id, user_id)
        VALUES (p_event_id, v_user_id);
    END IF;
    
    -- 更新参与人数
    UPDATE public.community_events
    SET participant_count = participant_count + 1, updated_at = NOW()
    WHERE id = p_event_id;
    
    RETURN json_build_object('success', true, 'message', 'Registration successful');
END;
$$;

-- 8.3 取消报名
CREATE OR REPLACE FUNCTION public.cancel_event_registration(p_event_id UUID)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_registration RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;
    
    SELECT * INTO v_registration
    FROM public.event_registrations
    WHERE event_id = p_event_id AND user_id = v_user_id AND status = 'registered';
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Registration not found');
    END IF;
    
    -- 取消报名
    UPDATE public.event_registrations
    SET status = 'cancelled'
    WHERE id = v_registration.id;
    
    -- 更新参与人数
    UPDATE public.community_events
    SET participant_count = GREATEST(0, participant_count - 1), updated_at = NOW()
    WHERE id = p_event_id;
    
    RETURN json_build_object('success', true, 'message', 'Registration cancelled');
END;
$$;

-- 8.4 获取用户已报名的活动
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
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.id as registration_id,
        e.id as event_id,
        e.title as event_title,
        e.event_date,
        e.location as event_location,
        e.category as event_category,
        c.name as community_name,
        r.status as registration_status,
        r.registered_at
    FROM public.event_registrations r
    JOIN public.community_events e ON r.event_id = e.id
    JOIN public.communities c ON e.community_id = c.id
    WHERE r.user_id = auth.uid()
    ORDER BY e.event_date DESC;
END;
$$;

-- =====================================================
-- 9. USER LOCATION FUNCTIONS (用户位置函数)
-- =====================================================

-- 9.1 更新用户位置
CREATE OR REPLACE FUNCTION public.update_user_location(
    p_city TEXT,
    p_state TEXT,
    p_latitude DECIMAL,
    p_longitude DECIMAL
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;
    
    UPDATE public.profiles
    SET
        location_city = p_city,
        location_state = p_state,
        location_latitude = p_latitude,
        location_longitude = p_longitude
    WHERE id = v_user_id;
    
    RETURN json_build_object('success', true, 'message', 'Location updated');
END;
$$;

-- =====================================================
-- 10. ROW LEVEL SECURITY (RLS)
-- =====================================================

ALTER TABLE public.communities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_community_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_registrations ENABLE ROW LEVEL SECURITY;

-- Communities: 所有人可读
DROP POLICY IF EXISTS "Communities are viewable by everyone" ON public.communities;
CREATE POLICY "Communities are viewable by everyone"
ON public.communities FOR SELECT USING (true);

-- Memberships: 用户可以看所有成员关系，但只能管理自己的
DROP POLICY IF EXISTS "Users can view all memberships" ON public.user_community_memberships;
CREATE POLICY "Users can view all memberships"
ON public.user_community_memberships FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can manage own memberships" ON public.user_community_memberships;
CREATE POLICY "Users can manage own memberships"
ON public.user_community_memberships FOR ALL USING (auth.uid() = user_id);

-- Events: 所有人可读
DROP POLICY IF EXISTS "Events are viewable by everyone" ON public.community_events;
CREATE POLICY "Events are viewable by everyone"
ON public.community_events FOR SELECT USING (true);

-- Registrations: 用户只能看/改自己的报名
DROP POLICY IF EXISTS "Users can view own registrations" ON public.event_registrations;
CREATE POLICY "Users can view own registrations"
ON public.event_registrations FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can manage own registrations" ON public.event_registrations;
CREATE POLICY "Users can manage own registrations"
ON public.event_registrations FOR ALL USING (auth.uid() = user_id);

-- =====================================================
-- 11. SEED DATA (初始数据)
-- =====================================================

-- 插入社区数据
INSERT INTO public.communities (id, name, city, state, description, member_count, latitude, longitude) VALUES
-- San Diego
('san-diego-green', 'San Diego Green Initiative', 'San Diego', 'CA', 'Leading environmental community in San Diego', 1250, 32.7157, -117.1611),
('san-diego-beach', 'SD Beach Cleanup Crew', 'San Diego', 'CA', 'Weekly beach cleanup events', 890, 32.7502, -117.2542),
-- Los Angeles
('la-eco', 'LA Eco Warriors', 'Los Angeles', 'CA', 'Los Angeles eco-conscious community', 3420, 34.0522, -118.2437),
('la-recycle', 'LA Recycling Network', 'Los Angeles', 'CA', 'Promoting recycling across LA', 2100, 34.0195, -118.4912),
-- San Francisco
('sf-green', 'SF Bay Recyclers', 'San Francisco', 'CA', 'Bay Area sustainability hub', 2180, 37.7749, -122.4194),
('sf-zero-waste', 'SF Zero Waste Coalition', 'San Francisco', 'CA', 'Working towards zero waste SF', 1560, 37.7849, -122.4094),
-- Seattle
('seattle-sustain', 'Seattle Sustainability', 'Seattle', 'WA', 'Seattle environmental advocacy', 1890, 47.6062, -122.3321),
-- Portland
('portland-eco', 'Portland Eco Community', 'Portland', 'OR', 'Portland green living community', 1560, 45.5152, -122.6784),
-- Denver
('denver-green', 'Denver Green Team', 'Denver', 'CO', 'Colorado environmental initiative', 980, 39.7392, -104.9903),
-- Austin
('austin-recycle', 'Austin Recyclers', 'Austin', 'TX', 'Austin waste reduction community', 1340, 30.2672, -97.7431),
-- New York
('nyc-sustain', 'NYC Sustainability Hub', 'New York', 'NY', 'New York City environmental community', 5200, 40.7128, -74.0060),
('nyc-green', 'NYC Green Initiative', 'New York', 'NY', 'Making NYC greener one block at a time', 3800, 40.7580, -73.9855),
-- Boston
('boston-eco', 'Boston Eco Alliance', 'Boston', 'MA', 'Boston area green initiative', 1780, 42.3601, -71.0589),
-- Chicago
('chicago-green', 'Chicago Green Initiative', 'Chicago', 'IL', 'Chicago sustainability community', 2340, 41.8781, -87.6298)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude;

-- 插入示例活动
INSERT INTO public.community_events (community_id, title, organizer, description, category, event_date, location, latitude, longitude, icon_name, max_participants, participant_count) VALUES
-- San Diego
('san-diego-green', 'Mission Beach Cleanup', 'San Diego Green Initiative', 'Join us for a community beach cleanup at Mission Beach! Help protect marine life.', 'cleanup', NOW() + INTERVAL '3 days', 'Mission Beach, San Diego', 32.7702, -117.2528, 'water.waves', 100, 45),
('san-diego-green', 'SD Recycling Workshop', 'San Diego Green Initiative', 'Learn how to recycle properly and reduce waste.', 'workshop', NOW() + INTERVAL '5 days', 'Balboa Park Community Center', 32.7341, -117.1446, 'scissors', 30, 18),
('san-diego-beach', 'La Jolla Cove Cleanup', 'SD Beach Cleanup Crew', 'Weekly cleanup at beautiful La Jolla Cove!', 'cleanup', NOW() + INTERVAL '2 days', 'La Jolla Cove', 32.8502, -117.2711, 'water.waves', 50, 32),
('san-diego-green', 'UCSD Sorting Challenge', 'UCSD Green Team', 'Compete with teams to sort waste correctly!', 'competition', NOW() + INTERVAL '7 days', 'UCSD Campus', 32.8801, -117.2340, 'flag.checkered', 80, 64),
-- Los Angeles
('la-eco', 'Santa Monica Beach Day', 'LA Eco Warriors', 'Help keep Santa Monica Beach clean and beautiful!', 'cleanup', NOW() + INTERVAL '4 days', 'Santa Monica Beach', 34.0195, -118.4912, 'water.waves', 150, 85),
('la-eco', 'Hollywood Zero Waste Talk', 'LA Eco Warriors', 'Learn practical tips for zero waste living.', 'education', NOW() + INTERVAL '10 days', 'LA Public Library', 34.0522, -118.2437, 'person.wave.2.fill', 60, 42),
('la-recycle', 'Venice Beach Recycling Drive', 'LA Recycling Network', 'Collect recyclables along Venice Beach!', 'cleanup', NOW() + INTERVAL '6 days', 'Venice Beach', 33.9850, -118.4695, 'arrow.3.trianglepath', 80, 55),
-- San Francisco
('sf-green', 'Golden Gate Park Cleanup', 'SF Bay Recyclers', 'Restore native plants and clean up Golden Gate Park.', 'cleanup', NOW() + INTERVAL '6 days', 'Golden Gate Park', 37.7694, -122.4862, 'tree.fill', 70, 38),
('sf-green', 'Bay Area Eco Competition', 'SF Bay Recyclers', 'Annual eco competition with teams from Bay Area!', 'competition', NOW() + INTERVAL '14 days', 'SF Civic Center', 37.7793, -122.4193, 'trophy.fill', 200, 120),
-- Seattle
('seattle-sustain', 'Puget Sound Beach Cleanup', 'Seattle Sustainability', 'Protect Puget Sound marine life with cleanup!', 'cleanup', NOW() + INTERVAL '8 days', 'Alki Beach, Seattle', 47.5763, -122.4095, 'water.waves', 100, 55),
-- Portland
('portland-eco', 'Portland Composting Workshop', 'Portland Eco Community', 'Learn the art of composting for your garden!', 'workshop', NOW() + INTERVAL '9 days', 'Portland Community Garden', 45.5231, -122.6765, 'leaf.fill', 40, 22)
ON CONFLICT DO NOTHING;

-- =====================================================
-- 12. GRANTS (权限)
-- =====================================================

GRANT SELECT ON public.communities TO anon, authenticated;
GRANT SELECT ON public.user_community_memberships TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_community_memberships TO authenticated;
GRANT SELECT ON public.community_events TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.event_registrations TO authenticated;

GRANT EXECUTE ON FUNCTION public.calculate_distance_km TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_communities_by_city TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_communities TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_community TO authenticated;
GRANT EXECUTE ON FUNCTION public.leave_community TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_nearby_events TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.register_for_event TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_event_registration TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_registrations TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_user_location TO authenticated;
