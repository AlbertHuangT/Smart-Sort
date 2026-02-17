import { Camera } from 'react-native-vision-camera';
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

import { classifierService } from 'src/services/classifier';
import { feedbackService } from 'src/services/feedback';
import { createPersistStorage } from 'src/utils/storage';

import { useAchievementStore } from './achievementStore';

const LIMIT = 50;

export const useTrashStore = create(
  persist(
    (set, get) => ({
      permission: 'unknown',
      scanningState: 'idle',
      classifierStatus: 'idle',
      classifierMeta: null,
      lastResult: null,
      history: [],
      error: null,
      classifierError: null,
      requestPermission: async () => {
        const status = await Camera.getCameraPermissionStatus();
        if (status === 'authorized') {
          set({ permission: status });
          return status;
        }
        const next = await Camera.requestCameraPermission();
        set({ permission: next });
        return next;
      },
      ensureClassifierReady: async ({ warmup = true } = {}) => {
        const status = get().classifierStatus;
        if (status === 'ready') return get().classifierMeta;
        if (status === 'loading') return null;
        set({ classifierStatus: 'loading', classifierError: null });
        try {
          const meta = await classifierService.ensureReady();
          if (warmup) {
            await classifierService.warmup();
          }
          set({
            classifierStatus: 'ready',
            classifierMeta: {
              ...classifierService.getStatus(),
              source: 'local-knowledge-base'
            },
            classifierError: null
          });
          return meta;
        } catch (error) {
          set({
            classifierStatus: 'error',
            classifierMeta: classifierService.getStatus(),
            classifierError: error?.message ?? 'AI 初始化失败'
          });
          throw error;
        }
      },
      analyzePhoto: async (photo) => {
        set({ scanningState: 'analyzing', error: null });
        try {
          await get().ensureClassifierReady();
          const result = await classifierService.classify(photo);
          set((state) => ({
            lastResult: { ...result, photo },
            history: [{ ...result, photo }, ...state.history].slice(0, LIMIT),
            scanningState: 'result',
            classifierMeta: {
              ...classifierService.getStatus(),
              source: result.source ?? 'unknown'
            }
          }));
        } catch (error) {
          set({ error: error.message, scanningState: 'idle' });
          throw error;
        }
      },
      confirmResult: () => {
        const result = get().lastResult;
        if (!result) return;
        set({
          lastResult: { ...result, confirmed: true },
          scanningState: 'idle'
        });
        useAchievementStore
          .getState()
          .checkAndGrant({ type: 'scan', item: result.item });
      },
      submitCorrection: async ({ category, note }) => {
        const result = get().lastResult;
        if (!result) return;
        set({ scanningState: 'feedback', error: null });
        try {
          await feedbackService.submitFeedback({
            resultId: result.id,
            correction: category,
            note,
            photo: result.photo
          });
          set({
            scanningState: 'idle',
            lastResult: { ...result, correctedCategory: category }
          });
        } catch (error) {
          set({ error: error.message, scanningState: 'result' });
          throw error;
        }
      },
      clearError: () => set({ error: null })
    }),
    {
      name: 'the-trash-history',
      storage: createPersistStorage(),
      partialize: (state) => ({ history: state.history })
    }
  )
);
