


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."calculate_distance_km"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) RETURNS numeric
    LANGUAGE "plpgsql" IMMUTABLE
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


ALTER FUNCTION "public"."calculate_distance_km"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_event_registration"("p_event_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
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


ALTER FUNCTION "public"."cancel_event_registration"("p_event_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_friends_leaderboard"("p_emails" "text"[], "p_phones" "text"[]) RETURNS TABLE("id" "uuid", "username" "text", "credits" integer, "email" "text", "phone" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    COALESCE(p.username, 'Unknown Friend') as username, -- 如果没有用户名，显示默认
    p.credits,
    p.email,
    p.phone
  FROM profiles p
  WHERE 
    -- 匹配邮箱 (忽略大小写)
    (p.email IS NOT NULL AND lower(p.email) = ANY(select lower(unnest(p_emails))))
    OR 
    -- 匹配手机号 (移除所有非数字字符后比较，增加容错率)
    (p.phone IS NOT NULL AND regexp_replace(p.phone, '\D', '', 'g') = ANY(select regexp_replace(unnest(p_phones), '\D', '', 'g')))
  ORDER BY p.credits DESC; -- 按积分从高到低排序
END;
$$;


ALTER FUNCTION "public"."find_friends_leaderboard"("p_emails" "text"[], "p_phones" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_communities_by_city"("p_city" "text") RETURNS TABLE("id" "text", "name" "text", "city" "text", "state" "text", "description" "text", "member_count" integer, "latitude" numeric, "longitude" numeric, "is_member" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
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


ALTER FUNCTION "public"."get_communities_by_city"("p_city" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_community_leaderboard"("p_community_id" "text", "p_limit" integer DEFAULT 100) RETURNS TABLE("id" "uuid", "username" "text", "credits" integer, "community_name" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."get_community_leaderboard"("p_community_id" "text", "p_limit" integer) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_community_leaderboard"("p_community_id" "text", "p_limit" integer) IS '获取指定社区的成员排行榜，按积分降序排列';



CREATE OR REPLACE FUNCTION "public"."get_my_communities"() RETURNS TABLE("id" "text", "name" "text", "city" "text", "state" "text", "description" "text", "member_count" integer, "joined_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
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


ALTER FUNCTION "public"."get_my_communities"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_registrations"() RETURNS TABLE("registration_id" "uuid", "event_id" "uuid", "event_title" "text", "event_date" timestamp with time zone, "event_location" "text", "event_category" "text", "community_name" "text", "registration_status" "text", "registered_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
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


ALTER FUNCTION "public"."get_my_registrations"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_nearby_events"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric DEFAULT 50, "p_category" "text" DEFAULT NULL::"text", "p_only_joined_communities" boolean DEFAULT false, "p_sort_by" "text" DEFAULT 'date'::"text") RETURNS TABLE("id" "uuid", "title" "text", "description" "text", "organizer" "text", "category" "text", "event_date" timestamp with time zone, "location" "text", "latitude" numeric, "longitude" numeric, "icon_name" "text", "max_participants" integer, "participant_count" integer, "community_id" "text", "community_name" "text", "distance_km" numeric, "is_registered" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
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


ALTER FUNCTION "public"."get_nearby_events"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_category" "text", "p_only_joined_communities" boolean, "p_sort_by" "text") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."quiz_questions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "image_url" "text" NOT NULL,
    "correct_category" "text" NOT NULL,
    "item_name" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "is_active" boolean DEFAULT true
);


ALTER TABLE "public"."quiz_questions" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_quiz_questions"() RETURNS SETOF "public"."quiz_questions"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM public.quiz_questions
    WHERE is_active = true
    ORDER BY random()
    LIMIT 10;
END;
$$;


ALTER FUNCTION "public"."get_quiz_questions"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  insert into public.profiles (id, email, phone, credits)
  values (new.id, new.email, new.phone, 0);
  return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_user_update"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE public.profiles
  SET 
    email = NEW.email,
    phone = NEW.phone
    -- 如果你有 updated_at 字段，可以加上: , updated_at = NOW()
  WHERE id = NEW.id;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_user_update"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_credits"("amount" integer) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  UPDATE public.profiles
  SET credits = credits + amount
  where id = auth.uid();
END;
$$;


ALTER FUNCTION "public"."increment_credits"("amount" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."join_community"("p_community_id" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
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


ALTER FUNCTION "public"."join_community"("p_community_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."leave_community"("p_community_id" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
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


ALTER FUNCTION "public"."leave_community"("p_community_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."protect_sensitive_profile_fields"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- 仅限制普通通过 API 访问的用户，不限制 Service Role 或 Postgres Admin
    IF auth.role() = 'authenticated' THEN
        IF NEW.credits IS DISTINCT FROM OLD.credits OR 
           NEW.status IS DISTINCT FROM OLD.status OR 
           NEW.banned_until IS DISTINCT FROM OLD.banned_until THEN
            RAISE EXCEPTION 'Permission denied: Cannot modify sensitive fields (credits/status/ban).';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."protect_sensitive_profile_fields"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."register_for_event"("p_event_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
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


ALTER FUNCTION "public"."register_for_event"("p_event_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_user_location"("p_city" "text", "p_state" "text", "p_latitude" numeric, "p_longitude" numeric) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
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


ALTER FUNCTION "public"."update_user_location"("p_city" "text", "p_state" "text", "p_latitude" numeric, "p_longitude" numeric) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."communities" (
    "id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "city" "text" NOT NULL,
    "state" "text",
    "country" "text" DEFAULT 'US'::"text",
    "description" "text",
    "logo_url" "text",
    "latitude" numeric(10,8),
    "longitude" numeric(11,8),
    "member_count" integer DEFAULT 0,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"())
);


ALTER TABLE "public"."communities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."community_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "community_id" "text" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "organizer" "text" NOT NULL,
    "category" "text" NOT NULL,
    "event_date" timestamp with time zone NOT NULL,
    "location" "text" NOT NULL,
    "latitude" numeric(10,8) NOT NULL,
    "longitude" numeric(11,8) NOT NULL,
    "image_url" "text",
    "icon_name" "text" DEFAULT 'calendar'::"text",
    "max_participants" integer DEFAULT 100,
    "participant_count" integer DEFAULT 0,
    "credits_reward" integer DEFAULT 10,
    "status" "text" DEFAULT 'upcoming'::"text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    CONSTRAINT "community_events_category_check" CHECK (("category" = ANY (ARRAY['cleanup'::"text", 'workshop'::"text", 'competition'::"text", 'education'::"text", 'other'::"text"]))),
    CONSTRAINT "community_events_status_check" CHECK (("status" = ANY (ARRAY['upcoming'::"text", 'ongoing'::"text", 'completed'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."community_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."event_registrations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'registered'::"text",
    "registered_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "attended_at" timestamp with time zone,
    "credits_earned" integer DEFAULT 0,
    CONSTRAINT "event_registrations_status_check" CHECK (("status" = ANY (ARRAY['registered'::"text", 'attended'::"text", 'cancelled'::"text", 'no_show'::"text"])))
);


ALTER TABLE "public"."event_registrations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."feedback_logs" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "user_id" "uuid",
    "predicted_label" "text",
    "predicted_category" "text",
    "user_correction" "text",
    "user_comment" "text",
    "image_path" "text"
);


ALTER TABLE "public"."feedback_logs" OWNER TO "postgres";


ALTER TABLE "public"."feedback_logs" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."feedback_logs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "phone" "text",
    "email" "text",
    "credits" integer DEFAULT 0,
    "username" "text",
    "status" "text" DEFAULT 'active'::"text",
    "banned_until" timestamp with time zone,
    "location_city" "text",
    "location_state" "text",
    "location_latitude" numeric(10,8),
    "location_longitude" numeric(11,8)
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_community_memberships" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "community_id" "text" NOT NULL,
    "status" "text" DEFAULT 'member'::"text",
    "joined_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    CONSTRAINT "user_community_memberships_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'member'::"text", 'admin'::"text", 'banned'::"text"])))
);


ALTER TABLE "public"."user_community_memberships" OWNER TO "postgres";


ALTER TABLE ONLY "public"."communities"
    ADD CONSTRAINT "communities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."community_events"
    ADD CONSTRAINT "community_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."event_registrations"
    ADD CONSTRAINT "event_registrations_event_id_user_id_key" UNIQUE ("event_id", "user_id");



ALTER TABLE ONLY "public"."event_registrations"
    ADD CONSTRAINT "event_registrations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."feedback_logs"
    ADD CONSTRAINT "feedback_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."quiz_questions"
    ADD CONSTRAINT "quiz_questions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_community_memberships"
    ADD CONSTRAINT "user_community_memberships_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_community_memberships"
    ADD CONSTRAINT "user_community_memberships_user_id_community_id_key" UNIQUE ("user_id", "community_id");



CREATE INDEX "idx_communities_city" ON "public"."communities" USING "btree" ("city");



CREATE INDEX "idx_communities_is_active" ON "public"."communities" USING "btree" ("is_active");



CREATE INDEX "idx_communities_location" ON "public"."communities" USING "btree" ("latitude", "longitude");



CREATE INDEX "idx_communities_state" ON "public"."communities" USING "btree" ("state");



CREATE INDEX "idx_events_category" ON "public"."community_events" USING "btree" ("category");



CREATE INDEX "idx_events_community" ON "public"."community_events" USING "btree" ("community_id");



CREATE INDEX "idx_events_date" ON "public"."community_events" USING "btree" ("event_date");



CREATE INDEX "idx_events_location" ON "public"."community_events" USING "btree" ("latitude", "longitude");



CREATE INDEX "idx_events_status" ON "public"."community_events" USING "btree" ("status");



CREATE INDEX "idx_memberships_community" ON "public"."user_community_memberships" USING "btree" ("community_id");



CREATE INDEX "idx_memberships_status" ON "public"."user_community_memberships" USING "btree" ("status");



CREATE INDEX "idx_memberships_user" ON "public"."user_community_memberships" USING "btree" ("user_id");



CREATE INDEX "idx_profiles_coordinates" ON "public"."profiles" USING "btree" ("location_latitude", "location_longitude");



CREATE INDEX "idx_profiles_location" ON "public"."profiles" USING "btree" ("location_city", "location_state");



CREATE INDEX "idx_registrations_event" ON "public"."event_registrations" USING "btree" ("event_id");



CREATE INDEX "idx_registrations_status" ON "public"."event_registrations" USING "btree" ("status");



CREATE INDEX "idx_registrations_user" ON "public"."event_registrations" USING "btree" ("user_id");



CREATE OR REPLACE TRIGGER "ensure_profile_security" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."protect_sensitive_profile_fields"();



ALTER TABLE ONLY "public"."community_events"
    ADD CONSTRAINT "community_events_community_id_fkey" FOREIGN KEY ("community_id") REFERENCES "public"."communities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."event_registrations"
    ADD CONSTRAINT "event_registrations_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."community_events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."event_registrations"
    ADD CONSTRAINT "event_registrations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."feedback_logs"
    ADD CONSTRAINT "feedback_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_community_memberships"
    ADD CONSTRAINT "user_community_memberships_community_id_fkey" FOREIGN KEY ("community_id") REFERENCES "public"."communities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_community_memberships"
    ADD CONSTRAINT "user_community_memberships_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Communities are viewable by everyone" ON "public"."communities" FOR SELECT USING (true);



CREATE POLICY "Enable insert for everyone" ON "public"."feedback_logs" FOR INSERT WITH CHECK (true);



CREATE POLICY "Enable read access for all users" ON "public"."feedback_logs" FOR SELECT USING (true);



CREATE POLICY "Events are viewable by everyone" ON "public"."community_events" FOR SELECT USING (true);



CREATE POLICY "Public profiles are viewable by everyone." ON "public"."profiles" FOR SELECT USING (true);



CREATE POLICY "Quiz questions are readable by authenticated users" ON "public"."quiz_questions" FOR SELECT TO "authenticated" USING (("is_active" = true));



CREATE POLICY "Users can insert their own profile." ON "public"."profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Users can manage own memberships" ON "public"."user_community_memberships" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can manage own registrations" ON "public"."event_registrations" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own profile." ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "id"));



CREATE POLICY "Users can view all memberships" ON "public"."user_community_memberships" FOR SELECT USING (true);



CREATE POLICY "Users can view own registrations" ON "public"."event_registrations" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."communities" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."community_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."event_registrations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."feedback_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."quiz_questions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_community_memberships" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."calculate_distance_km"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_distance_km"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_distance_km"("lat1" numeric, "lon1" numeric, "lat2" numeric, "lon2" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."cancel_event_registration"("p_event_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."cancel_event_registration"("p_event_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_event_registration"("p_event_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."find_friends_leaderboard"("p_emails" "text"[], "p_phones" "text"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."find_friends_leaderboard"("p_emails" "text"[], "p_phones" "text"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_friends_leaderboard"("p_emails" "text"[], "p_phones" "text"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_communities_by_city"("p_city" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_communities_by_city"("p_city" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_communities_by_city"("p_city" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_community_leaderboard"("p_community_id" "text", "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_community_leaderboard"("p_community_id" "text", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_community_leaderboard"("p_community_id" "text", "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_communities"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_communities"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_communities"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_registrations"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_registrations"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_registrations"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_nearby_events"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_category" "text", "p_only_joined_communities" boolean, "p_sort_by" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_nearby_events"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_category" "text", "p_only_joined_communities" boolean, "p_sort_by" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_nearby_events"("p_latitude" numeric, "p_longitude" numeric, "p_max_distance_km" numeric, "p_category" "text", "p_only_joined_communities" boolean, "p_sort_by" "text") TO "service_role";



GRANT ALL ON TABLE "public"."quiz_questions" TO "anon";
GRANT ALL ON TABLE "public"."quiz_questions" TO "authenticated";
GRANT ALL ON TABLE "public"."quiz_questions" TO "service_role";



GRANT ALL ON FUNCTION "public"."get_quiz_questions"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_quiz_questions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_quiz_questions"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_user_update"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_user_update"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_user_update"() TO "service_role";



GRANT ALL ON FUNCTION "public"."increment_credits"("amount" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."increment_credits"("amount" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_credits"("amount" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."join_community"("p_community_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."join_community"("p_community_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."join_community"("p_community_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."leave_community"("p_community_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."leave_community"("p_community_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."leave_community"("p_community_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."protect_sensitive_profile_fields"() TO "anon";
GRANT ALL ON FUNCTION "public"."protect_sensitive_profile_fields"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."protect_sensitive_profile_fields"() TO "service_role";



GRANT ALL ON FUNCTION "public"."register_for_event"("p_event_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."register_for_event"("p_event_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."register_for_event"("p_event_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_user_location"("p_city" "text", "p_state" "text", "p_latitude" numeric, "p_longitude" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."update_user_location"("p_city" "text", "p_state" "text", "p_latitude" numeric, "p_longitude" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_user_location"("p_city" "text", "p_state" "text", "p_latitude" numeric, "p_longitude" numeric) TO "service_role";


















GRANT ALL ON TABLE "public"."communities" TO "anon";
GRANT ALL ON TABLE "public"."communities" TO "authenticated";
GRANT ALL ON TABLE "public"."communities" TO "service_role";



GRANT ALL ON TABLE "public"."community_events" TO "anon";
GRANT ALL ON TABLE "public"."community_events" TO "authenticated";
GRANT ALL ON TABLE "public"."community_events" TO "service_role";



GRANT ALL ON TABLE "public"."event_registrations" TO "anon";
GRANT ALL ON TABLE "public"."event_registrations" TO "authenticated";
GRANT ALL ON TABLE "public"."event_registrations" TO "service_role";



GRANT ALL ON TABLE "public"."feedback_logs" TO "anon";
GRANT ALL ON TABLE "public"."feedback_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."feedback_logs" TO "service_role";



GRANT ALL ON SEQUENCE "public"."feedback_logs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."feedback_logs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."feedback_logs_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."user_community_memberships" TO "anon";
GRANT ALL ON TABLE "public"."user_community_memberships" TO "authenticated";
GRANT ALL ON TABLE "public"."user_community_memberships" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































