export const ERROR_CODES = {
  UNKNOWN: 'UNKNOWN',
  VALIDATION: 'VALIDATION',
  AUTH: 'AUTH',
  CONTACTS_PERMISSION_REQUIRED: 'CONTACTS_PERMISSION_REQUIRED',
  CONTACTS_EMPTY: 'CONTACTS_EMPTY',
  BACKEND: 'BACKEND'
};

export class AppError extends Error {
  constructor(message, options = {}) {
    super(message);
    this.name = 'AppError';
    this.code = options.code ?? ERROR_CODES.UNKNOWN;
    this.cause = options.cause ?? null;
    this.meta = options.meta ?? null;
  }
}

const isAppError = (value) => value instanceof AppError;

const normalizeMessage = (error, fallbackMessage) => {
  if (typeof error === 'string' && error.trim()) return error.trim();
  if (error instanceof Error && error.message?.trim())
    return error.message.trim();
  if (
    error &&
    typeof error === 'object' &&
    typeof error.message === 'string' &&
    error.message.trim()
  ) {
    return error.message.trim();
  }
  return fallbackMessage;
};

export const toAppError = (error, fallback = {}) => {
  if (isAppError(error)) return error;

  const message = normalizeMessage(
    error,
    fallback.message ?? '请求失败，请稍后再试'
  );
  return new AppError(message, {
    code: fallback.code ?? ERROR_CODES.UNKNOWN,
    cause: error ?? null,
    meta: fallback.meta ?? null
  });
};

export const fromSupabaseError = (error, fallback = {}) =>
  toAppError(error, {
    message: fallback.message ?? '服务暂时不可用，请稍后重试',
    code: fallback.code ?? ERROR_CODES.BACKEND,
    meta: {
      ...(fallback.meta ?? {}),
      status: error?.status ?? null,
      hint: error?.hint ?? null,
      details: error?.details ?? null
    }
  });

export const messageFromError = (
  error,
  fallbackMessage = '操作失败，请稍后再试'
) => toAppError(error, { message: fallbackMessage }).message;
