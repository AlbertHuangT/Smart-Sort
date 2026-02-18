import Contacts from 'react-native-contacts';

import { hasSupabaseConfig } from 'src/services/config';
import { AppError, ERROR_CODES, fromSupabaseError } from 'src/utils/errors';
import { normalizePhoneNumber } from 'src/utils/phone';

import { supabase } from './supabase';

const isSupabaseEnabled = () =>
  process.env.NODE_ENV === 'test' || hasSupabaseConfig();

const CONTACT_EMAIL_LIMIT = 300;
const CONTACT_PHONE_LIMIT = 300;

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
    throw fromSupabaseError(error, {
      code: ERROR_CODES.AUTH,
      message: '读取用户信息失败'
    });
  }
  return data.user?.id ?? null;
};

const requestContactsPermission = async ({
  allowPermissionPrompt = true
} = {}) => {
  const status = await Contacts.checkPermission();
  if (status === 'authorized') return true;
  if (!allowPermissionPrompt) return false;
  const nextStatus = await Contacts.requestPermission();
  return nextStatus === 'authorized';
};

const readContactsPayload = async ({ allowPermissionPrompt = true } = {}) => {
  const granted = await requestContactsPermission({ allowPermissionPrompt });
  if (!granted) {
    throw new AppError('需要通讯录权限后才能同步好友榜', {
      code: ERROR_CODES.CONTACTS_PERMISSION_REQUIRED
    });
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

  const minimizedEmails = Array.from(emails).slice(0, CONTACT_EMAIL_LIMIT);
  const minimizedPhones = Array.from(phones).slice(0, CONTACT_PHONE_LIMIT);

  if (!minimizedEmails.length && !minimizedPhones.length) {
    throw new AppError('通讯录里没有可匹配的邮箱或手机号', {
      code: ERROR_CODES.CONTACTS_EMPTY
    });
  }

  return {
    emails: minimizedEmails,
    phones: minimizedPhones,
    stats: {
      emailCount: minimizedEmails.length,
      phoneCount: minimizedPhones.length,
      contactCount: contacts.length
    }
  };
};

const fetchFriendsLeaderboard = async ({
  allowPermissionPrompt = true
} = {}) => {
  const payload = await readContactsPayload({ allowPermissionPrompt });
  const { data, error } = await supabase.rpc('find_friends_leaderboard', {
    p_emails: payload.emails,
    p_phones: payload.phones
  });
  if (error) {
    throw fromSupabaseError(error, {
      message: '同步好友榜失败'
    });
  }
  const currentUserId = await getCurrentUserId();
  return {
    entries: (data ?? []).map((item) => mapFriendEntry(item, currentUserId)),
    syncStats: payload.stats
  };
};

const fetchCommunityLeaderboard = async (communityId) => {
  const { data, error } = await supabase.rpc('get_community_leaderboard', {
    p_community_id: communityId,
    p_limit: 100
  });
  if (error) {
    throw fromSupabaseError(error, {
      message: '加载社群排行榜失败'
    });
  }
  const currentUserId = await getCurrentUserId();
  return (data ?? []).map((item) => mapCommunityEntry(item, currentUserId));
};

export const leaderboardService = {
  async fetchMyCommunities() {
    if (!isSupabaseEnabled()) {
      return [];
    }
    const { data, error } = await supabase.rpc('get_my_communities');
    if (error) {
      throw fromSupabaseError(error, {
        message: '加载我的社群失败'
      });
    }
    return (data ?? []).map(mapMyCommunity);
  },

  async fetch(filter = 'community', options = {}) {
    if (!isSupabaseEnabled()) {
      return [];
    }

    if (filter === 'friends') {
      if (!options.explicitSync) {
        return [];
      }
      const result = await fetchFriendsLeaderboard({
        allowPermissionPrompt: options.allowPermissionPrompt !== false
      });
      return result.entries;
    }

    const communityId = options.communityId;
    if (!communityId) {
      return [];
    }

    return fetchCommunityLeaderboard(communityId);
  },

  async syncContacts(options = {}) {
    if (!isSupabaseEnabled()) {
      return { entries: [], syncStats: null };
    }
    return fetchFriendsLeaderboard({
      allowPermissionPrompt: options.allowPermissionPrompt !== false
    });
  }
};

export const leaderboardPrivacy = {
  maxEmailsPerSync: CONTACT_EMAIL_LIMIT,
  maxPhonesPerSync: CONTACT_PHONE_LIMIT
};
