import { supabase } from './supabase';

const hasSupabaseConfig = Boolean(
  process.env.EXPO_PUBLIC_SUPABASE_URL && process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY
);

const getErrorMessage = (error) => {
  if (error instanceof Error) return error.message;
  if (typeof error === 'string') return error;
  return 'Unknown error';
};

const toNumber = (value) => {
  const num = Number(value);
  return Number.isFinite(num) ? num : null;
};

const formatDistance = (distanceKm) => {
  const km = Number(distanceKm);
  if (!Number.isFinite(km)) return null;
  return `${km.toFixed(1)} km`;
};

const slugify = (value) =>
  String(value ?? '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');

const rpc = async (fn, args = {}) => {
  const { data, error } = await supabase.rpc(fn, args);
  if (error) {
    throw new Error(error.message);
  }
  return data;
};

const resolveCity = (city) => {
  if (!city) return { cityName: null, latitude: null, longitude: null, state: null };
  if (typeof city === 'string') {
    return { cityName: city, latitude: null, longitude: null, state: null };
  }
  return {
    cityName: city.id ?? city.city ?? city.name ?? null,
    latitude: toNumber(city.latitude),
    longitude: toNumber(city.longitude),
    state: city.state ?? null
  };
};

const formatEvent = (event, fallbackCity = null) => ({
  id: event.id,
  title: event.title,
  cityId: event.city ?? fallbackCity,
  cover: event.image_url ?? event.cover_url ?? null,
  latitude: toNumber(event.latitude),
  longitude: toNumber(event.longitude),
  distance: event.distance ?? formatDistance(event.distance_km),
  description: event.description ?? '',
  venue: event.location ?? event.venue ?? '',
  startTime: event.event_date ?? event.start_time ?? null,
  quota: event.max_participants ?? event.quota ?? 0,
  attendees: event.participant_count ?? event.attendees ?? 0,
  communityId: event.community_id ?? null,
  communityName: event.community_name ?? event.communities?.name ?? null,
  isRegistered: Boolean(event.is_registered),
  isPersonal: Boolean(event.is_personal),
  category: event.category ?? 'other'
});

const formatGroup = (group) => ({
  id: group.id,
  name: group.name,
  cityId: group.city ?? group.city_id ?? null,
  city: group.city ?? null,
  state: group.state ?? null,
  description: group.description ?? '',
  memberCount: group.member_count ?? group.memberCount ?? 0,
  latitude: toNumber(group.latitude),
  longitude: toNumber(group.longitude),
  isMember: Boolean(group.is_member)
});

const getCityCoordinates = async (cityName) => {
  if (!cityName) return { latitude: null, longitude: null };
  const { data, error } = await supabase
    .from('communities')
    .select('latitude,longitude')
    .eq('city', cityName)
    .eq('is_active', true)
    .limit(1)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return {
    latitude: toNumber(data?.latitude),
    longitude: toNumber(data?.longitude)
  };
};

export const communityService = {
  async fetchCities() {
    if (!hasSupabaseConfig) return [];
    const { data, error } = await supabase
      .from('communities')
      .select('city,state,latitude,longitude')
      .eq('is_active', true)
      .not('city', 'is', null)
      .order('city', { ascending: true });
    if (error) {
      throw new Error(error.message);
    }

    const cityMap = new Map();
    (data ?? []).forEach((row) => {
      const city = row.city;
      if (!city) return;
      const existing = cityMap.get(city);
      const latitude = toNumber(row.latitude);
      const longitude = toNumber(row.longitude);
      if (!existing) {
        cityMap.set(city, {
          id: city,
          name: city,
          city,
          state: row.state ?? null,
          latitude,
          longitude
        });
        return;
      }
      if (existing.latitude == null && latitude != null) existing.latitude = latitude;
      if (existing.longitude == null && longitude != null) existing.longitude = longitude;
    });

    return Array.from(cityMap.values()).sort((a, b) => a.name.localeCompare(b.name));
  },

  async fetchEvents(city) {
    if (!hasSupabaseConfig) return [];
    const resolved = resolveCity(city);
    if (!resolved.cityName) return [];

    let latitude = resolved.latitude;
    let longitude = resolved.longitude;
    if (latitude == null || longitude == null) {
      const coords = await getCityCoordinates(resolved.cityName);
      latitude = coords.latitude;
      longitude = coords.longitude;
    }
    if (latitude == null || longitude == null) {
      return [];
    }

    const rows = await rpc('get_nearby_events', {
      p_latitude: latitude,
      p_longitude: longitude,
      p_max_distance_km: 80,
      p_sort_by: 'date'
    });
    return (rows ?? []).map((item) => formatEvent(item, resolved.cityName));
  },

  async fetchGroups(city) {
    if (!hasSupabaseConfig) return [];
    const resolved = resolveCity(city);
    if (resolved.cityName) {
      const rows = await rpc('get_communities_by_city', {
        p_city: resolved.cityName
      });
      return (rows ?? []).map(formatGroup);
    }
    const { data, error } = await supabase
      .from('communities')
      .select('id,name,city,state,description,member_count,latitude,longitude')
      .eq('is_active', true)
      .order('member_count', { ascending: false });
    if (error) throw new Error(error.message);
    return (data ?? []).map(formatGroup);
  },

  async createEvent(payload) {
    if (!hasSupabaseConfig) {
      throw new Error('请先连接 Supabase');
    }
    const eventDate = payload.startTime ? new Date(payload.startTime) : new Date(Date.now() + 86400000);
    const safeDate = Number.isNaN(eventDate.getTime()) ? new Date(Date.now() + 86400000) : eventDate;
    const data = await rpc('create_event', {
      p_title: payload.title,
      p_description: payload.description,
      p_category: payload.category ?? 'other',
      p_event_date: safeDate.toISOString(),
      p_location: payload.venue ?? payload.location ?? 'TBD',
      p_latitude: toNumber(payload.latitude) ?? 0,
      p_longitude: toNumber(payload.longitude) ?? 0,
      p_max_participants: Number(payload.quota ?? 50),
      p_community_id: payload.communityId ?? null,
      p_icon_name: payload.iconName ?? 'calendar'
    });
    if (!data?.success) {
      throw new Error(data?.message ?? '创建活动失败');
    }
    if (!data?.event_id) {
      throw new Error('活动创建成功但未返回活动 ID');
    }
    const event = await this.fetchEvent(data.event_id);
    if (!event) return null;
    return {
      ...event,
      cityId: event.cityId ?? payload.cityId ?? payload.city ?? null
    };
  },

  async createCommunity(payload) {
    if (!hasSupabaseConfig) {
      throw new Error('请先连接 Supabase');
    }
    const cityName = payload.cityId ?? payload.city ?? payload.cityName;
    const baseId = slugify(`${payload.name}-${cityName}`);
    const communityId = `${baseId}-${Date.now().toString().slice(-6)}`;
    const data = await rpc('create_community', {
      p_id: communityId,
      p_name: payload.name,
      p_city: cityName,
      p_state: payload.state ?? null,
      p_description: payload.description ?? null,
      p_latitude: toNumber(payload.latitude),
      p_longitude: toNumber(payload.longitude)
    });
    if (!data?.success) {
      throw new Error(data?.message ?? '创建社群失败');
    }
    return this.fetchCommunity(communityId);
  },

  async fetchCommunity(id) {
    if (!id || !hasSupabaseConfig) return null;
    const { data, error } = await supabase
      .from('communities')
      .select('id,name,city,state,description,member_count,latitude,longitude')
      .eq('id', id)
      .maybeSingle();
    if (error) throw new Error(error.message);
    return data ? formatGroup(data) : null;
  },

  async fetchEvent(id) {
    if (!id || !hasSupabaseConfig) return null;
    const { data, error } = await supabase
      .from('community_events')
      .select('id,title,description,category,event_date,location,latitude,longitude,icon_name,max_participants,participant_count,community_id')
      .eq('id', id)
      .maybeSingle();
    if (error) throw new Error(error.message);
    return data ? formatEvent(data) : null;
  },

  async joinCommunity(id) {
    if (!id || !hasSupabaseConfig) return null;
    const result = await rpc('apply_to_join_community', {
      p_community_id: id,
      p_message: null
    });
    if (!result?.success) {
      throw new Error(result?.message ?? '加入社群失败');
    }
    return true;
  },

  async rsvpEvent(id) {
    if (!id || !hasSupabaseConfig) return null;
    const result = await rpc('register_for_event', {
      p_event_id: id
    });
    if (!result?.success) {
      throw new Error(result?.message ?? '报名失败');
    }
    return this.fetchEvent(id);
  },

  async adminDashboard(communityId) {
    if (!communityId || !hasSupabaseConfig) {
      return { requests: [], members: [], logs: [] };
    }
    try {
      const [requests, members, logs] = await Promise.all([
        rpc('get_pending_applications', { p_community_id: communityId }),
        rpc('get_community_members_admin', { p_community_id: communityId }),
        rpc('get_admin_action_logs', { p_community_id: communityId, p_limit: 50 })
      ]);
      return {
        requests: requests ?? [],
        members: members ?? [],
        logs: logs ?? []
      };
    } catch (error) {
      console.warn('[communityService] adminDashboard failed', getErrorMessage(error));
      return { requests: [], members: [], logs: [] };
    }
  }
};
