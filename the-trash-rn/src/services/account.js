import { supabase } from './supabase';
import { normalizePhoneNumber } from 'src/utils/phone';

const hasSupabaseConfig = Boolean(
  process.env.EXPO_PUBLIC_SUPABASE_URL && process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY
);

export const accountService = {
  async requestPhoneOtp(phone) {
    if (!phone) throw new Error('请输入手机号');
    const normalizedPhone = normalizePhoneNumber(phone);
    if (!normalizedPhone) {
      throw new Error('手机号格式不正确');
    }
    if (hasSupabaseConfig) {
      const { error } = await supabase.auth.signInWithOtp({ phone: normalizedPhone });
      if (error) throw new Error(error.message);
    }
    return true;
  },
  async bindPhone({ phone, code }) {
    if (!phone || !code) throw new Error('请输入手机号和验证码');
    const normalizedPhone = normalizePhoneNumber(phone);
    if (!normalizedPhone) {
      throw new Error('手机号格式不正确');
    }
    if (hasSupabaseConfig) {
      const { error } = await supabase.auth.verifyOtp({
        phone: normalizedPhone,
        token: code,
        type: 'sms'
      });
      if (error) throw new Error(error.message);
    }
    return true;
  },
  async requestEmailOtp(email) {
    if (!email) throw new Error('请输入邮箱');
    if (hasSupabaseConfig) {
      const { error } = await supabase.auth.signInWithOtp({ email });
      if (error) throw new Error(error.message);
    }
    return true;
  },
  async bindEmail({ email, code }) {
    if (!email || !code) throw new Error('请输入邮箱和验证码');
    if (hasSupabaseConfig) {
      const { error } = await supabase.auth.verifyOtp({ email, token: code, type: 'email' });
      if (error) throw new Error(error.message);
    }
    return true;
  },
  async changePassword(password) {
    if (!password || password.length < 8) throw new Error('密码至少 8 位');
    if (hasSupabaseConfig) {
      const { error } = await supabase.auth.updateUser({ password });
      if (error) throw new Error(error.message);
    }
    return true;
  },
  async upgradeGuest({ email, password }) {
    if (!email || !password) throw new Error('请输入邮箱和密码');
    if (password.length < 8) throw new Error('密码至少 8 位');
    if (hasSupabaseConfig) {
      const { error } = await supabase.auth.signUp({ email, password });
      if (error) throw new Error(error.message);
    }
    return true;
  }
};
