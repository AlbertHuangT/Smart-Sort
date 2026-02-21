import { hasSupabaseConfig } from 'src/services/config';
import { AppError, ERROR_CODES, fromSupabaseError } from 'src/utils/errors';
import { normalizePhoneNumber } from 'src/utils/phone';

import { supabase } from './supabase';

const resolveEmail = (email) =>
  String(email ?? '')
    .trim()
    .toLowerCase();

const getCurrentSession = async () => {
  const { data, error } = await supabase.auth.getSession();
  if (error) {
    throw fromSupabaseError(error, {
      code: ERROR_CODES.AUTH,
      message: '读取登录状态失败'
    });
  }
  return data.session ?? null;
};

export const accountService = {
  async requestPhoneOtp(phone) {
    if (!phone)
      throw new AppError('请输入手机号', { code: ERROR_CODES.VALIDATION });
    const normalizedPhone = normalizePhoneNumber(phone);
    if (!normalizedPhone) {
      throw new AppError('手机号格式不正确', { code: ERROR_CODES.VALIDATION });
    }
    if (hasSupabaseConfig()) {
      const session = await getCurrentSession();
      const { error } = session?.user
        ? await supabase.auth.updateUser({ phone: normalizedPhone })
        : await supabase.auth.signInWithOtp({ phone: normalizedPhone });
      if (error)
        throw fromSupabaseError(error, {
          code: ERROR_CODES.AUTH,
          message: '发送手机验证码失败'
        });
    }
    return true;
  },
  async bindPhone({ phone, code }) {
    if (!phone || !code) {
      throw new AppError('请输入手机号和验证码', {
        code: ERROR_CODES.VALIDATION
      });
    }
    const normalizedPhone = normalizePhoneNumber(phone);
    if (!normalizedPhone) {
      throw new AppError('手机号格式不正确', { code: ERROR_CODES.VALIDATION });
    }
    if (hasSupabaseConfig()) {
      const session = await getCurrentSession();
      const { error } = await supabase.auth.verifyOtp({
        phone: normalizedPhone,
        token: code,
        type: session?.user ? 'phone_change' : 'sms'
      });
      if (error)
        throw fromSupabaseError(error, {
          code: ERROR_CODES.AUTH,
          message: '手机验证码校验失败'
        });
    }
    return true;
  },
  async requestEmailOtp(email) {
    const normalizedEmail = resolveEmail(email);
    if (!normalizedEmail) {
      throw new AppError('请输入邮箱', { code: ERROR_CODES.VALIDATION });
    }
    if (hasSupabaseConfig()) {
      const session = await getCurrentSession();
      const { error } = session?.user
        ? await supabase.auth.updateUser({ email: normalizedEmail })
        : await supabase.auth.signInWithOtp({ email: normalizedEmail });
      if (error)
        throw fromSupabaseError(error, {
          code: ERROR_CODES.AUTH,
          message: '发送邮箱验证码失败'
        });
    }
    return true;
  },
  async bindEmail({ email, code }) {
    const normalizedEmail = resolveEmail(email);
    if (!normalizedEmail || !code) {
      throw new AppError('请输入邮箱和验证码', {
        code: ERROR_CODES.VALIDATION
      });
    }
    if (hasSupabaseConfig()) {
      const session = await getCurrentSession();
      const { error } = await supabase.auth.verifyOtp({
        email: normalizedEmail,
        token: code,
        type: session?.user ? 'email_change' : 'email'
      });
      if (error)
        throw fromSupabaseError(error, {
          code: ERROR_CODES.AUTH,
          message: '邮箱验证码校验失败'
        });
    }
    return true;
  },
  async changePassword(password) {
    if (!password || password.length < 8) {
      throw new AppError('密码至少 8 位', { code: ERROR_CODES.VALIDATION });
    }
    if (hasSupabaseConfig()) {
      const { error } = await supabase.auth.updateUser({ password });
      if (error)
        throw fromSupabaseError(error, {
          code: ERROR_CODES.AUTH,
          message: '修改密码失败'
        });
    }
    return true;
  },
  async upgradeGuest({ email, password }) {
    const normalizedEmail = resolveEmail(email);
    if (!normalizedEmail || !password) {
      throw new AppError('请输入邮箱和密码', { code: ERROR_CODES.VALIDATION });
    }
    if (password.length < 8) {
      throw new AppError('密码至少 8 位', { code: ERROR_CODES.VALIDATION });
    }
    if (hasSupabaseConfig()) {
      const session = await getCurrentSession();
      const { error } = session?.user
        ? await supabase.auth.updateUser({ email: normalizedEmail, password })
        : await supabase.auth.signUp({ email: normalizedEmail, password });
      if (error)
        throw fromSupabaseError(error, {
          code: ERROR_CODES.AUTH,
          message: '升级账号失败'
        });
    }
    return true;
  }
};
