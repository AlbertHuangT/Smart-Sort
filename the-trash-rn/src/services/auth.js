import { hasSupabaseConfig } from 'src/services/config';
import {
  AppError,
  ERROR_CODES,
  fromSupabaseError,
  messageFromError
} from 'src/utils/errors';
import { normalizePhoneNumber } from 'src/utils/phone';

import { supabase } from './supabase';

const buildProfile = (user, fallback = {}) => ({
  id: user?.id ?? fallback.id ?? `demo-${Date.now()}`,
  displayName:
    user?.user_metadata?.full_name ??
    user?.email ??
    user?.phone ??
    fallback.displayName ??
    'Trash Ranger',
  email: user?.email ?? fallback.email ?? null,
  phone: user?.phone ?? fallback.phone ?? null,
  level: fallback.level ?? 1
});

const fakeAuthResult = (payload) => {
  const user = {
    id: payload?.id ?? `demo-${Date.now()}`,
    email: payload?.email ?? null,
    phone: payload?.phone ?? null
  };
  return {
    session: { user },
    profile: buildProfile(user, payload)
  };
};

export const authService = {
  async restoreSession() {
    const { data, error } = await supabase.auth.getSession();
    if (error) {
      console.warn('[auth] restoreSession failed', messageFromError(error));
      return { session: null, profile: null };
    }
    if (!data.session) {
      return { session: null, profile: null };
    }
    return {
      session: data.session,
      profile: buildProfile(data.session.user)
    };
  },
  async signInWithEmail({ email, password }) {
    if (!email || !password) {
      throw new AppError('Please enter email and password', {
        code: ERROR_CODES.VALIDATION
      });
    }
    if (hasSupabaseConfig()) {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password
      });
      if (error) {
        throw fromSupabaseError(error, {
          code: ERROR_CODES.AUTH,
          message: 'Incorrect email or password'
        });
      }
      return {
        session: data.session,
        profile: buildProfile(data.user ?? data.session?.user, { email })
      };
    }
    return fakeAuthResult({ email, displayName: email });
  },
  async signUpWithEmail({ email, password }) {
    if (!email || !password) {
      throw new AppError('Please enter email and password', {
        code: ERROR_CODES.VALIDATION
      });
    }
    if (password.length < 8) {
      throw new AppError('Password must be at least 8 characters', {
        code: ERROR_CODES.VALIDATION
      });
    }
    if (hasSupabaseConfig()) {
      const { data, error } = await supabase.auth.signUp({ email, password });
      if (error) {
        throw fromSupabaseError(error, {
          code: ERROR_CODES.AUTH,
          message: 'Sign-up failed. Please try again later.'
        });
      }
      return {
        session: data.session ?? null,
        profile: data.user ? buildProfile(data.user, { email }) : null,
        requiresEmailConfirmation: !data.session
      };
    }
    return {
      ...fakeAuthResult({ email, displayName: email }),
      requiresEmailConfirmation: false
    };
  },
  async signInWithPhone({ phone, code }) {
    if (!phone) {
      throw new AppError('Please enter phone number', {
        code: ERROR_CODES.VALIDATION
      });
    }
    if (!code) {
      throw new AppError('Please enter verification code', {
        code: ERROR_CODES.VALIDATION
      });
    }
    const normalizedPhone = normalizePhoneNumber(phone);
    if (!normalizedPhone) {
      throw new AppError('Invalid phone number format', {
        code: ERROR_CODES.VALIDATION
      });
    }
    if (hasSupabaseConfig()) {
      const { data, error } = await supabase.auth.verifyOtp({
        phone: normalizedPhone,
        token: code,
        type: 'sms'
      });
      if (error) {
        throw fromSupabaseError(error, {
          code: ERROR_CODES.AUTH,
          message: 'Verification code is invalid or expired'
        });
      }
      return {
        session: data.session,
        profile: buildProfile(data.user ?? data.session?.user, {
          phone: normalizedPhone
        })
      };
    }
    return fakeAuthResult({
      phone: normalizedPhone,
      displayName: `${normalizedPhone} User`
    });
  },
  async requestPhoneCode(phone) {
    if (!phone) {
      throw new AppError('Please enter phone number', {
        code: ERROR_CODES.VALIDATION
      });
    }
    const normalizedPhone = normalizePhoneNumber(phone);
    if (!normalizedPhone) {
      throw new AppError('Invalid phone number format', {
        code: ERROR_CODES.VALIDATION
      });
    }
    if (hasSupabaseConfig()) {
      const { error } = await supabase.auth.signInWithOtp({
        phone: normalizedPhone
      });
      if (error) {
        throw fromSupabaseError(error, {
          code: ERROR_CODES.AUTH,
          message: 'Failed to send verification code'
        });
      }
    }
    return true;
  },
  async signOut() {
    const { error } = await supabase.auth.signOut();
    if (error) {
      console.warn('[auth] signOut failed', messageFromError(error));
    }
  }
};
