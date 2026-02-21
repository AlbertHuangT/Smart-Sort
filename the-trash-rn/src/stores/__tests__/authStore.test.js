const { AppError, ERROR_CODES } = require('src/utils/errors');

const setupStore = ({
  restoreSessionResult = { session: null, profile: null },
  signInError = null
} = {}) => {
  jest.resetModules();

  const authServiceMock = {
    restoreSession: jest.fn().mockResolvedValue(restoreSessionResult),
    signInWithEmail: signInError
      ? jest.fn().mockRejectedValue(signInError)
      : jest.fn().mockResolvedValue({
          session: { user: { id: 'u-1' } },
          profile: { id: 'u-1', displayName: 'Tester', level: 1 }
        }),
    signUpWithEmail: jest.fn(),
    signInWithPhone: jest.fn(),
    requestPhoneCode: jest.fn(),
    signOut: jest.fn().mockResolvedValue(undefined)
  };

  const onAuthStateChangeMock = jest.fn(() => ({
    data: {
      subscription: {
        unsubscribe: jest.fn()
      }
    }
  }));

  jest.doMock('src/services/auth', () => ({
    authService: authServiceMock
  }));
  jest.doMock('src/services/supabase', () => ({
    supabase: {
      auth: {
        onAuthStateChange: onAuthStateChangeMock
      }
    }
  }));

  const { useAuthStore } = require('src/stores/authStore');
  return { useAuthStore, authServiceMock, onAuthStateChangeMock };
};

describe('authStore', () => {
  test('bootstrap uses supabase session as single source of truth', async () => {
    const { useAuthStore, authServiceMock, onAuthStateChangeMock } = setupStore(
      {
        restoreSessionResult: {
          session: { user: { id: 'u-1', email: 'user@example.com' } },
          profile: { id: 'u-1', displayName: 'User', level: 3 }
        }
      }
    );

    await useAuthStore.getState().bootstrap();

    const state = useAuthStore.getState();
    expect(state.status).toBe('authenticated');
    expect(state.session.user.id).toBe('u-1');
    expect(authServiceMock.restoreSession).toHaveBeenCalledTimes(1);
    expect(onAuthStateChangeMock).toHaveBeenCalledTimes(1);
  });

  test('signInWithEmail failure stores normalized error', async () => {
    const { useAuthStore } = setupStore({
      signInError: new AppError('邮箱或密码错误', { code: ERROR_CODES.AUTH })
    });

    await expect(
      useAuthStore.getState().signInWithEmail({
        email: 'bad@example.com',
        password: 'wrong'
      })
    ).rejects.toBeTruthy();

    expect(useAuthStore.getState().error).toBe('邮箱或密码错误');
    expect(useAuthStore.getState().authenticating).toBe(false);
  });

  test('refreshSession keeps guest profile when configured', async () => {
    const { useAuthStore } = setupStore({
      restoreSessionResult: { session: null, profile: null }
    });

    useAuthStore.getState().signInAsGuest();
    await useAuthStore.getState().refreshSession({
      keepGuestOnMissingSession: true
    });

    expect(useAuthStore.getState().status).toBe('guest');
    expect(useAuthStore.getState().profile.id).toBe('guest');
  });
});
