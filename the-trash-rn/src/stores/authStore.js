import { create } from 'zustand';

import { authService } from 'src/services/auth';
import { supabase } from 'src/services/supabase';
import { messageFromError } from 'src/utils/errors';

let authSubscription = null;

const toGuestState = (currentProfile = null) => ({
  status: 'guest',
  session: null,
  profile: currentProfile,
  error: null
});

export const useAuthStore = create((set, get) => ({
  status: 'checking',
  session: null,
  profile: null,
  authenticating: false,
  error: null,

  bootstrap: async () => {
    if (!authSubscription) {
      const { data } = supabase.auth.onAuthStateChange((_event, session) => {
        const current = get();
        if (session?.user) {
          set({
            status: 'authenticated',
            session,
            profile: {
              id: session.user.id,
              displayName:
                session.user.user_metadata?.full_name ??
                session.user.email ??
                session.user.phone ??
                'Trash Ranger',
              email: session.user.email ?? null,
              phone: session.user.phone ?? null,
              level: current.profile?.level ?? 1
            },
            error: null
          });
          return;
        }

        const keepGuestProfile =
          current.status === 'guest' && current.profile?.id === 'guest'
            ? current.profile
            : null;
        set(toGuestState(keepGuestProfile));
      });
      authSubscription = data.subscription;
    }

    try {
      const { session, profile } = await authService.restoreSession();
      if (session) {
        set({ status: 'authenticated', session, profile, error: null });
      } else {
        const current = get();
        const keepGuestProfile =
          current.status === 'guest' && current.profile?.id === 'guest'
            ? current.profile
            : null;
        set(toGuestState(keepGuestProfile));
      }
    } catch (error) {
      console.warn('[authStore] bootstrap failed', error);
      set({
        status: 'guest',
        session: null,
        profile: null,
        error: messageFromError(error, 'Failed to initialize auth state')
      });
    }
  },

  signInWithEmail: async ({ email, password }) => {
    set({ authenticating: true, error: null });
    try {
      const { session, profile } = await authService.signInWithEmail({
        email,
        password
      });
      set({
        status: 'authenticated',
        session,
        profile,
        authenticating: false,
        error: null
      });
    } catch (error) {
      set({
        authenticating: false,
        error: messageFromError(error, 'Sign-in failed')
      });
      throw error;
    }
  },

  signUpWithEmail: async ({ email, password }) => {
    set({ authenticating: true, error: null });
    try {
      const { session, profile, requiresEmailConfirmation } =
        await authService.signUpWithEmail({
          email,
          password
        });
      if (session) {
        set({
          status: 'authenticated',
          session,
          profile,
          authenticating: false,
          error: null
        });
      } else {
        set({
          status: 'guest',
          session: null,
          profile: null,
          authenticating: false,
          error: null
        });
      }
      return { requiresEmailConfirmation };
    } catch (error) {
      set({
        authenticating: false,
        error: messageFromError(error, 'Sign-up failed')
      });
      throw error;
    }
  },

  signInWithPhone: async ({ phone, code }) => {
    set({ authenticating: true, error: null });
    try {
      const { session, profile } = await authService.signInWithPhone({
        phone,
        code
      });
      set({
        status: 'authenticated',
        session,
        profile,
        authenticating: false,
        error: null
      });
    } catch (error) {
      set({
        authenticating: false,
        error: messageFromError(error, 'Phone sign-in failed')
      });
      throw error;
    }
  },

  requestPhoneCode: async (phone) => {
    try {
      await authService.requestPhoneCode(phone);
      set({ error: null });
      return true;
    } catch (error) {
      set({
        error: messageFromError(error, 'Failed to send verification code')
      });
      throw error;
    }
  },

  refreshSession: async ({ keepGuestOnMissingSession = true } = {}) => {
    try {
      const { session, profile } = await authService.restoreSession();
      if (session) {
        set({ status: 'authenticated', session, profile, error: null });
        return session;
      }

      const current = get();
      const shouldKeepGuest =
        keepGuestOnMissingSession &&
        current.status === 'guest' &&
        current.profile?.id === 'guest';
      set(toGuestState(shouldKeepGuest ? current.profile : null));
      return null;
    } catch (error) {
      const message = messageFromError(error, 'Failed to refresh auth state');
      set({ error: message });
      throw error;
    }
  },

  signInAsGuest: () =>
    set({
      status: 'guest',
      profile: { id: 'guest', displayName: 'Guest', level: 1 },
      session: null,
      error: null
    }),

  signOut: async () => {
    await authService.signOut();
    set(toGuestState(null));
  }
}));
