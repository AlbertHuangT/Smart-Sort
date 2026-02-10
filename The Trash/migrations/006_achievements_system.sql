-- 006_achievements_system.sql
-- New tables for Achievement System
-- Fixed: correct table names (profiles, user_community_memberships) and types (community_id TEXT)

-- 1. Create achievements table
CREATE TABLE IF NOT EXISTS public.achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id TEXT REFERENCES public.communities(id) ON DELETE CASCADE, -- NULL means official achievement
    name TEXT NOT NULL,
    description TEXT,
    icon_name TEXT NOT NULL, -- SF Symbol name
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    points INT DEFAULT 0, -- Achievement point value (optional)
    is_hidden BOOLEAN DEFAULT FALSE,
    rarity TEXT DEFAULT 'common' CHECK (rarity IN ('common', 'rare', 'epic', 'legendary')),
    trigger_key TEXT UNIQUE
);

-- 2. Create user_achievements table (Many-to-Many)
CREATE TABLE IF NOT EXISTS public.user_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    achievement_id UUID REFERENCES public.achievements(id) ON DELETE CASCADE,
    community_id TEXT REFERENCES public.communities(id) ON DELETE SET NULL,
    granted_at TIMESTAMPTZ DEFAULT NOW(),
    granted_by UUID REFERENCES auth.users(id),
    UNIQUE(user_id, achievement_id)
);

-- 3. Add selected_achievement_id and total_scans to profiles
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS selected_achievement_id UUID REFERENCES public.achievements(id) ON DELETE SET NULL;

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS total_scans INT DEFAULT 0;

-- 4. Enable RLS
ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies

CREATE POLICY "Allow public read on achievements" ON public.achievements
    FOR SELECT USING (true);

CREATE POLICY "Allow admins to create community achievements" ON public.achievements
    FOR INSERT WITH CHECK (
        community_id IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM public.user_community_memberships
            WHERE community_id = public.achievements.community_id
            AND user_id = auth.uid()
            AND status = 'admin'
        )
    );

CREATE POLICY "Allow admins to update community achievements" ON public.achievements
    FOR UPDATE USING (
        community_id IS NOT NULL AND
        EXISTS (
            SELECT 1 FROM public.user_community_memberships
            WHERE community_id = public.achievements.community_id
            AND user_id = auth.uid()
            AND status = 'admin'
        )
    );

CREATE POLICY "Allow users to read achievements" ON public.user_achievements
    FOR SELECT USING (true);

CREATE POLICY "Allow admins to grant achievements" ON public.user_achievements
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.achievements a
            JOIN public.user_community_memberships cm ON a.community_id = cm.community_id
            WHERE a.id = achievement_id
            AND cm.user_id = auth.uid()
            AND cm.status = 'admin'
        ) OR
        (SELECT community_id FROM public.achievements WHERE id = achievement_id) IS NULL
    );

-- 6. Functions

-- Function to equip an achievement
CREATE OR REPLACE FUNCTION set_primary_achievement(achievement_id UUID)
RETURNS VOID AS $$
BEGIN
    IF achievement_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.user_achievements ua
        WHERE ua.user_id = auth.uid() AND ua.achievement_id = set_primary_achievement.achievement_id
    ) THEN
        RAISE EXCEPTION 'User does not own this achievement';
    END IF;

    UPDATE public.profiles
    SET selected_achievement_id = set_primary_achievement.achievement_id
    WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to fetch my achievements with details
CREATE OR REPLACE FUNCTION get_my_achievements()
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
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ua.id,
        a.id,
        a.name,
        a.description,
        a.icon_name,
        a.community_id,
        c.name,
        ua.granted_at,
        (p.selected_achievement_id = a.id),
        a.rarity
    FROM public.user_achievements ua
    JOIN public.achievements a ON ua.achievement_id = a.id
    LEFT JOIN public.communities c ON a.community_id = c.id
    LEFT JOIN public.profiles p ON ua.user_id = p.id
    WHERE ua.user_id = auth.uid()
    ORDER BY ua.granted_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
