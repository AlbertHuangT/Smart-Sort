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
      message: 'Failed to read auth state'
    });
  }
  return data.session ?? null;
};

export const accountService = {
  async requestPhoneOtp(phone) {
    if (!phone)
      throw new AppError('Please enter phone number', {
        code: ERROR_CODES.VALIDATION
      });
    const normalizedPhone = normalizePhoneNumber(phone);
    if (!normalizedPhone) {
      throw new AppError('Invalid phone number format', {
        code: ERROR_CODES.VALIDATION
      });
    }
    if (hasSupabaseConfig()) {
      const session = await getCurrentSession();
      const { error } = session?.user
        ? await supabase.auth.updateUser({ phone: normalizedPhone })
        : await supabase.auth.signInWithOtp({ phone: normalizedPhone });
      if (error)
        throw fromSupabaseError(error, {
          code: ERROR_CODES.AUTH,
          message: 'Failed to send phone verification code'
        });
    }
    return true;
  },
  async bindPhone({ phone, code }) {
    if (!phone || !code) {
      throw new AppError('Please enter phone number and verification code', {
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
      const session = await getCurrentSession();
      const { error } = await supabase.auth.verifyOtp({
        phone: normalizedPhone,
        token: code,
        type: session?.user ? 'phone_change' : 'sms'
      });
      if (error)
        throw fromSupabaseError(error, {
          code: ERROR_CODES.AUTH,
          message: 'Phone verification failed'
        });
    }
    return true;
  },
  async requestEmailOtp(email) {
    const normalizedEmail = resolveEmail(email);
    if (!normalizedEmail) {
      throw new AppError('Please enter email', {
        code: ERROR_CODES.VALIDATION
      });
    }
    if (hasSupabaseConfig()) {
      const session = await getCurrentSession();
      const { error } = session?.user
        ? await supabase.auth.updateUser({ email: normalizedEmail })
        : await supabase.auth.signInWithOtp({ email: normalizedEmail });
      if (error)
        throw fromSupabaseError(error, {
          code: ERROR_CODES.AUTH,
          message: 'Failed to send email verification code'
        });
    }
    return true;
  },
  async bindEmail({ email, code }) {
    const normalizedEmail = resolveEmail(email);
    if (!normalizedEmail || !code) {
      throw new AppError('Please enter email and verification code', {
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
          message: 'Email verification failed'
        });
    }
    return true;
  },
  async changePassword(password) {
    if (!password || password.length < 8) {
      throw new AppError('Password must be at least 8 characters', {
        code: ERROR_CODES.VALIDATION
      });
    }
    if (hasSupabaseConfig()) {
      const { error } = await supabase.auth.updateUser({ password });
      if (error)
        throw fromSupabaseError(error, {
          code: ERROR_CODES.AUTH,
          message: 'Failed to change password'
        });
    }
    return true;
  },
  async upgradeGuest({ email, password }) {
    const normalizedEmail = resolveEmail(email);
    if (!normalizedEmail || !password) {
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
      const session = await getCurrentSession();
      const { error } = session?.user
        ? await supabase.auth.updateUser({ email: normalizedEmail, password })
        : await supabase.auth.signUp({ email: normalizedEmail, password });
      if (error)
        throw fromSupabaseError(error, {
          code: ERROR_CODES.AUTH,
          message: 'Failed to upgrade account'
        });
    }
    return true;
  }
};
