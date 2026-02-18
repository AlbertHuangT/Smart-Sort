const {
  AppError,
  ERROR_CODES,
  fromSupabaseError,
  messageFromError,
  toAppError
} = require('src/utils/errors');

describe('errors utils', () => {
  test('toAppError wraps unknown values with fallback message', () => {
    const error = toAppError({ not: 'an-error' }, { message: 'fallback' });
    expect(error).toBeInstanceOf(AppError);
    expect(error.message).toBe('fallback');
    expect(error.code).toBe(ERROR_CODES.UNKNOWN);
  });

  test('toAppError keeps existing AppError', () => {
    const original = new AppError('already wrapped', {
      code: ERROR_CODES.AUTH
    });
    const error = toAppError(original, { message: 'fallback' });
    expect(error).toBe(original);
    expect(error.code).toBe(ERROR_CODES.AUTH);
  });

  test('fromSupabaseError preserves status and uses backend code by default', () => {
    const error = fromSupabaseError(
      { message: 'db down', status: 500 },
      { message: '服务失败' }
    );
    expect(error).toBeInstanceOf(AppError);
    expect(error.message).toBe('db down');
    expect(error.code).toBe(ERROR_CODES.BACKEND);
    expect(error.meta.status).toBe(500);
  });

  test('messageFromError extracts message from native errors', () => {
    const message = messageFromError(new Error('boom'), 'fallback');
    expect(message).toBe('boom');
  });
});
