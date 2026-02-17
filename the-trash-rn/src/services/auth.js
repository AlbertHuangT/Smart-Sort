import { supabase } from './supabase';
import { normalizePhoneNumber } from 'src/utils/phone';

const hasSupabaseConfig = Boolean(
  process.env.EXPO_PUBLIC_SUPABASE_URL && process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY
);

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
      console.warn('[auth] restoreSession failed', error.message);
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
      throw new Error('请输入邮箱和密码');
    }
    if (hasSupabaseConfig) {
      const { data, error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) {
        throw new Error(error.message);
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
      throw new Error('请输入邮箱和密码');
    }
    if (password.length < 8) {
      throw new Error('密码至少 8 位');
    }
    if (hasSupabaseConfig) {
      const { data, error } = await supabase.auth.signUp({ email, password });
      if (error) {
        throw new Error(error.message);
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
      throw new Error('请输入手机号');
    }
    if (!code) {
      throw new Error('请输入验证码');
    }
    const normalizedPhone = normalizePhoneNumber(phone);
    if (!normalizedPhone) {
      throw new Error('手机号格式不正确');
    }
    if (hasSupabaseConfig) {
      const { data, error } = await supabase.auth.verifyOtp({
        phone: normalizedPhone,
        token: code,
        type: 'sms'
      });
      if (error) {
        throw new Error(error.message);
      }
      return {
        session: data.session,
        profile: buildProfile(data.user ?? data.session?.user, { phone: normalizedPhone })
      };
    }
    return fakeAuthResult({ phone: normalizedPhone, displayName: `${normalizedPhone} 用户` });
  },
  async requestPhoneCode(phone) {
    if (!phone) {
      throw new Error('请输入手机号');
    }
    const normalizedPhone = normalizePhoneNumber(phone);
    if (!normalizedPhone) {
      throw new Error('手机号格式不正确');
    }
    if (hasSupabaseConfig) {
      const { error } = await supabase.auth.signInWithOtp({ phone: normalizedPhone });
      if (error) {
        throw new Error(error.message);
      }
    }
    return true;
  },
  async signOut() {
    const { error } = await supabase.auth.signOut();
    if (error) {
      console.warn('[auth] signOut failed', error.message);
    }
  }
};
