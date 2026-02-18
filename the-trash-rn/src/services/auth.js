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
      throw new AppError('请输入邮箱和密码', { code: ERROR_CODES.VALIDATION });
    }
    if (hasSupabaseConfig()) {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password
      });
      if (error) {
        throw fromSupabaseError(error, {
          code: ERROR_CODES.AUTH,
          message: '邮箱或密码错误'
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
      throw new AppError('请输入邮箱和密码', { code: ERROR_CODES.VALIDATION });
    }
    if (password.length < 8) {
      throw new AppError('密码至少 8 位', { code: ERROR_CODES.VALIDATION });
    }
    if (hasSupabaseConfig()) {
      const { data, error } = await supabase.auth.signUp({ email, password });
      if (error) {
        throw fromSupabaseError(error, {
          code: ERROR_CODES.AUTH,
          message: '注册失败，请稍后再试'
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
      throw new AppError('请输入手机号', { code: ERROR_CODES.VALIDATION });
    }
    if (!code) {
      throw new AppError('请输入验证码', { code: ERROR_CODES.VALIDATION });
    }
    const normalizedPhone = normalizePhoneNumber(phone);
    if (!normalizedPhone) {
      throw new AppError('手机号格式不正确', {
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
          message: '验证码无效或已过期'
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
      displayName: `${normalizedPhone} 用户`
    });
  },
  async requestPhoneCode(phone) {
    if (!phone) {
      throw new AppError('请输入手机号', { code: ERROR_CODES.VALIDATION });
    }
    const normalizedPhone = normalizePhoneNumber(phone);
    if (!normalizedPhone) {
      throw new AppError('手机号格式不正确', {
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
          message: '验证码发送失败'
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
