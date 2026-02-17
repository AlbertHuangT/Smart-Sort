import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { authService } from 'src/services/auth';
import { createPersistStorage } from 'src/utils/storage';

export const useAuthStore = create(
  persist(
    (set, get) => ({
      status: 'checking',
      session: null,
      profile: null,
      authenticating: false,
      error: null,
      bootstrap: async () => {
        try {
          const { session, profile } = await authService.restoreSession();
          if (session) {
            set({ status: 'authenticated', session, profile, error: null });
          } else {
            set({ status: 'guest', session: null, profile: null, error: null });
          }
        } catch (error) {
          console.warn('[authStore] bootstrap failed', error);
          set({ status: 'guest', session: null, profile: null, error: error.message });
        }
      },
      signInWithEmail: async ({ email, password }) => {
        set({ authenticating: true, error: null });
        try {
          const { session, profile } = await authService.signInWithEmail({ email, password });
          set({ status: 'authenticated', session, profile, authenticating: false, error: null });
        } catch (error) {
          set({ authenticating: false, error: error.message });
          throw error;
        }
      },
      signUpWithEmail: async ({ email, password }) => {
        set({ authenticating: true, error: null });
        try {
          const { session, profile, requiresEmailConfirmation } = await authService.signUpWithEmail({
            email,
            password
          });
          if (session) {
            set({ status: 'authenticated', session, profile, authenticating: false, error: null });
          } else {
            set({ status: 'guest', session: null, profile: null, authenticating: false, error: null });
          }
          return { requiresEmailConfirmation };
        } catch (error) {
          set({ authenticating: false, error: error.message });
          throw error;
        }
      },
      signInWithPhone: async ({ phone, code }) => {
        set({ authenticating: true, error: null });
        try {
          const { session, profile } = await authService.signInWithPhone({ phone, code });
          set({ status: 'authenticated', session, profile, authenticating: false, error: null });
        } catch (error) {
          set({ authenticating: false, error: error.message });
          throw error;
        }
      },
      requestPhoneCode: async (phone) => {
        try {
          await authService.requestPhoneCode(phone);
          set({ error: null });
          return true;
        } catch (error) {
          set({ error: error.message });
          throw error;
        }
      },
      signInAsGuest: () =>
        set({
          status: 'guest',
          profile: { id: 'guest', displayName: '游客', level: 1 },
          session: null,
          error: null
        }),
      setSession: (session, profile) =>
        set({
          status: 'authenticated',
          session,
          profile,
          error: null
        }),
      signOut: async () => {
        await authService.signOut();
        set({ status: 'guest', session: null, profile: null, error: null });
      }
    }),
    {
      name: 'the-trash-auth',
      storage: createPersistStorage(),
      partialize: (state) => ({ profile: state.profile, status: state.status, session: state.session })
    }
  )
);
