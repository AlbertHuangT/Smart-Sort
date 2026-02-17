import Contacts from 'react-native-contacts';

import { normalizePhoneNumber } from 'src/utils/phone';

import { supabase } from './supabase';

const hasSupabaseConfig = Boolean(
  process.env.EXPO_PUBLIC_SUPABASE_URL &&
  process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY
);

const getErrorMessage = (error) => {
  if (error instanceof Error) return error.message;
  if (typeof error === 'string') return error;
  return 'Unknown error';
};

const mapCommunityEntry = (item, currentUserId) => {
  const entryId = item.id ?? item.user_id ?? null;
  return {
    id: entryId ? String(entryId) : String(item.username ?? Math.random()),
    name: item.username ?? item.display_name ?? 'Anonymous',
    community: item.community_name ?? '社区',
    score: Number(item.credits ?? item.score ?? 0),
    badgeIcon: item.achievement_icon ?? null,
    isMe: currentUserId ? String(entryId) === String(currentUserId) : false
  };
};

const mapFriendEntry = (item, currentUserId) => ({
  id: String(item.id),
  name: item.username ?? 'Anonymous',
  community: item.phone ?? item.email ?? '通讯录好友',
  score: Number(item.credits ?? 0),
  isMe: currentUserId ? String(item.id) === String(currentUserId) : false
});

const mapMyCommunity = (item) => ({
  id: item.id,
  name: item.name,
  city: item.city ?? null,
  state: item.state ?? null,
  status: item.status ?? 'member'
});

const getCurrentUserId = async () => {
  const { data, error } = await supabase.auth.getUser();
  if (error) {
    throw new Error(error.message);
  }
  return data.user?.id ?? null;
};

const requestContactsPermission = async () => {
  const status = await Contacts.checkPermission();
  if (status === 'authorized') return true;
  const nextStatus = await Contacts.requestPermission();
  return nextStatus === 'authorized';
};

const readContactsPayload = async () => {
  const granted = await requestContactsPermission();
  if (!granted) {
    throw new Error('通讯录权限被拒绝');
  }
  const contacts = await Contacts.getAll();
  const emails = new Set();
  const phones = new Set();

  contacts.forEach((contact) => {
    (contact.emailAddresses ?? []).forEach((entry) => {
      const email = String(entry.email ?? '')
        .trim()
        .toLowerCase();
      if (email) emails.add(email);
    });
    (contact.phoneNumbers ?? []).forEach((entry) => {
      const normalized = normalizePhoneNumber(entry.number);
      if (normalized) phones.add(normalized);
    });
  });

  return {
    emails: Array.from(emails),
    phones: Array.from(phones)
  };
};

const fetchFriendsLeaderboard = async () => {
  const payload = await readContactsPayload();
  if (!payload.emails.length && !payload.phones.length) {
    return [];
  }
  const { data, error } = await supabase.rpc('find_friends_leaderboard', {
    p_emails: payload.emails,
    p_phones: payload.phones
  });
  if (error) {
    throw new Error(error.message);
  }
  const currentUserId = await getCurrentUserId();
  return (data ?? []).map((item) => mapFriendEntry(item, currentUserId));
};

const fetchCommunityLeaderboard = async (communityId) => {
  const { data, error } = await supabase.rpc('get_community_leaderboard', {
    p_community_id: communityId,
    p_limit: 100
  });
  if (error) {
    throw new Error(error.message);
  }
  const currentUserId = await getCurrentUserId();
  return (data ?? []).map((item) => mapCommunityEntry(item, currentUserId));
};

export const leaderboardService = {
  async fetchMyCommunities() {
    if (!hasSupabaseConfig) {
      return [];
    }
    const { data, error } = await supabase.rpc('get_my_communities');
    if (error) {
      throw new Error(error.message);
    }
    return (data ?? []).map(mapMyCommunity);
  },

  async fetch(filter = 'community', options = {}) {
    if (!hasSupabaseConfig) {
      return [];
    }

    if (filter === 'friends') {
      try {
        return await fetchFriendsLeaderboard();
      } catch (error) {
        console.warn(
          '[leaderboardService] fetch friends failed',
          getErrorMessage(error)
        );
        return [];
      }
    }

    const communityId = options.communityId;
    if (!communityId) {
      return [];
    }

    try {
      return await fetchCommunityLeaderboard(communityId);
    } catch (error) {
      console.warn(
        '[leaderboardService] fetch community failed',
        getErrorMessage(error)
      );
      return [];
    }
  },

  async syncContacts() {
    if (!hasSupabaseConfig) {
      return [];
    }
    return fetchFriendsLeaderboard();
  }
};
