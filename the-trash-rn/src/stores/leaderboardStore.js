import { create } from 'zustand';
import { persist } from 'zustand/middleware';

import { leaderboardService } from 'src/services/leaderboard';
import { messageFromError, toAppError } from 'src/utils/errors';
import { createPersistStorage } from 'src/utils/storage';

const withRank = (entries) =>
  entries.map((entry, index) => ({
    ...entry,
    rank: index + 1
  }));

const pickMyRanking = (entries) => entries.find((entry) => entry.isMe) ?? null;

export const useLeaderboardStore = create(
  persist(
    (set, get) => ({
      entries: [],
      myRanking: null,
      myCommunities: [],
      selectedCommunityId: null,
      error: null,
      loading: false,
      loadingCommunities: false,
      syncingContacts: false,
      contactsSyncOptIn: false,
      contactsLastSyncedAt: null,
      contactsLastSyncStats: null,

      setCommunity(communityId) {
        set({ selectedCommunityId: communityId });
      },

      setContactsSyncOptIn(enabled) {
        set({ contactsSyncOptIn: Boolean(enabled), error: null });
      },

      async loadMyCommunities() {
        set({ loadingCommunities: true, error: null });
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
            loadingCommunities: false,
            error: messageFromError(error, '加载社群失败')
          });
          return null;
        }
      },

      async load(filter = 'community') {
        set({ loading: true, error: null });
        try {
          if (filter === 'friends' && !get().contactsSyncOptIn) {
            set({ entries: [], myRanking: null, loading: false, error: null });
            return;
          }

          let communityId = get().selectedCommunityId;
          if (filter === 'community' && !communityId) {
            communityId = await get().loadMyCommunities();
          }

          const rawEntries = await leaderboardService.fetch(filter, {
            communityId,
            explicitSync: filter === 'friends',
            allowPermissionPrompt: false
          });
          const entries = withRank(rawEntries);
          const myRanking = pickMyRanking(entries);
          set({ entries, myRanking, loading: false, error: null });
        } catch (error) {
          console.warn('[leaderboard] load failed', error);
          set({
            entries: [],
            myRanking: null,
            loading: false,
            error: messageFromError(error, '加载排行榜失败')
          });
        }
      },

      async syncContacts({ allowPermissionPrompt = true } = {}) {
        set({ syncingContacts: true, error: null });
        try {
          const { entries: rawEntries, syncStats } =
            await leaderboardService.syncContacts({
              allowPermissionPrompt
            });
          const entries = withRank(rawEntries);
          const myRanking = pickMyRanking(entries);
          set({
            entries,
            myRanking,
            contactsSyncOptIn: true,
            contactsLastSyncedAt: Date.now(),
            contactsLastSyncStats: syncStats ?? null,
            syncingContacts: false,
            error: null
          });
        } catch (error) {
          const appError = toAppError(error, {
            message: '同步通讯录失败'
          });
          console.warn('[leaderboard] sync contacts failed', appError);
          set({
            syncingContacts: false,
            error: appError.message
          });
        }
      }
    }),
    {
      name: 'the-trash-leaderboard',
      storage: createPersistStorage(),
      partialize: (state) => ({
        contactsSyncOptIn: state.contactsSyncOptIn
      })
    }
  )
);
