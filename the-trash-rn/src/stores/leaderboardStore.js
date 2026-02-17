import { create } from 'zustand';

import { leaderboardService } from 'src/services/leaderboard';

const withRank = (entries) =>
  entries.map((entry, index) => ({
    ...entry,
    rank: index + 1
  }));

const pickMyRanking = (entries) => entries.find((entry) => entry.isMe) ?? null;

export const useLeaderboardStore = create((set, get) => ({
  entries: [],
  myRanking: null,
  myCommunities: [],
  selectedCommunityId: null,
  loading: false,
  loadingCommunities: false,
  syncingContacts: false,

  setCommunity(communityId) {
    set({ selectedCommunityId: communityId });
  },

  async loadMyCommunities() {
    set({ loadingCommunities: true });
    try {
      const myCommunities = await leaderboardService.fetchMyCommunities();
      const currentId = get().selectedCommunityId;
      const nextId = myCommunities.some((item) => item.id === currentId)
        ? currentId
        : (myCommunities[0]?.id ?? null);
      set({
        myCommunities,
        selectedCommunityId: nextId,
        loadingCommunities: false
      });
      return nextId;
    } catch (error) {
      console.warn('[leaderboard] load communities failed', error);
      set({
        myCommunities: [],
        selectedCommunityId: null,
        loadingCommunities: false
      });
      return null;
    }
  },

  async load(filter = 'community') {
    set({ loading: true });
    try {
      let communityId = get().selectedCommunityId;
      if (filter === 'community' && !communityId) {
        communityId = await get().loadMyCommunities();
      }
      const rawEntries = await leaderboardService.fetch(filter, {
        communityId
      });
      const entries = withRank(rawEntries);
      const myRanking = pickMyRanking(entries);
      set({ entries, myRanking, loading: false });
    } catch (error) {
      console.warn('[leaderboard] load failed', error);
      set({ entries: [], myRanking: null, loading: false });
    }
  },

  async syncContacts() {
    set({ syncingContacts: true });
    try {
      const entries = withRank(await leaderboardService.syncContacts());
      const myRanking = pickMyRanking(entries);
      set({ entries, myRanking, syncingContacts: false });
    } catch (error) {
      console.warn('[leaderboard] sync contacts failed', error);
      set({ syncingContacts: false });
    }
  }
}));
