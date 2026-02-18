import { hasSupabaseConfig } from 'src/services/config';

import { supabase } from './supabase';

const mapBadge = (achievement, ownedMap) => {
  const owned = ownedMap.get(achievement.id);
  return {
    id: achievement.id,
    title: achievement.name ?? 'Achievement',
    description: achievement.description ?? '',
    icon: achievement.icon_name ?? 'award',
    rarity: achievement.rarity ?? 'common',
    unlocked: Boolean(owned),
    equipped: Boolean(owned?.is_equipped)
  };
};

const rpc = async (fn, args = {}) => {
  const { data, error } = await supabase.rpc(fn, args);
  if (error) throw new Error(error.message);
  return data;
};

const triggerKeysFromPayload = ({ trigger, stats }) => {
  const keys = [];
  if (trigger?.type === 'scan') {
    if ((stats?.scans ?? 0) >= 1) keys.push('first_scan');
    if ((stats?.scans ?? 0) >= 10) keys.push('scans_10');
    if ((stats?.scans ?? 0) >= 50) keys.push('scans_50');
  }
  if (trigger?.type === 'arena' && trigger?.mode === 'duel' && trigger?.won) {
    keys.push('arena_win');
  }
  return keys;
};

export const achievementService = {
  async fetchBadges() {
    if (!hasSupabaseConfig()) {
      return [];
    }
    const [allAchievementsResult, myAchievementsResult] = await Promise.all([
      supabase
        .from('achievements')
        .select('id,name,description,icon_name,rarity')
        .order('created_at', { ascending: true }),
      supabase.rpc('get_my_achievements')
    ]);

    if (allAchievementsResult.error) {
      throw new Error(allAchievementsResult.error.message);
    }
    if (myAchievementsResult.error) {
      throw new Error(myAchievementsResult.error.message);
    }

    const ownedMap = new Map(
      (myAchievementsResult.data ?? []).map((item) => [
        item.achievement_id,
        { is_equipped: Boolean(item.is_equipped) }
      ])
    );

    return (allAchievementsResult.data ?? []).map((item) =>
      mapBadge(item, ownedMap)
    );
  },

  async fetchRewards() {
    return [];
  },

  async redeemReward() {
    throw new Error('积分兑换功能暂未开放');
  },

  async checkAndGrant(payload) {
    if (!hasSupabaseConfig()) {
      return { unlocked: [], points: 0 };
    }

    const triggerKeys = triggerKeysFromPayload(payload);
    if (!triggerKeys.length) {
      return { unlocked: [], points: 0 };
    }

    const unlocked = [];
    for (const key of triggerKeys) {
      const result = await rpc('check_and_grant_achievement', {
        p_trigger_key: key
      });
      if (result?.granted && result?.achievement_id) {
        unlocked.push({
          id: result.achievement_id,
          title: result.name ?? '新成就',
          description: result.description ?? '',
          icon: result.icon_name ?? 'award'
        });
      }
    }

    return { unlocked, points: 0 };
  }
};
