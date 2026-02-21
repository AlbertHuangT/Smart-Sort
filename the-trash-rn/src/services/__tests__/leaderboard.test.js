jest.mock('react-native-contacts', () => ({
  checkPermission: jest.fn(),
  requestPermission: jest.fn(),
  getAll: jest.fn()
}));

jest.mock('src/services/supabase', () => ({
  supabase: {
    auth: {
      getUser: jest.fn()
    },
    rpc: jest.fn()
  }
}));

process.env.EXPO_PUBLIC_SUPABASE_URL =
  process.env.EXPO_PUBLIC_SUPABASE_URL ?? 'https://example.supabase.co';
process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY =
  process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY ?? 'anon-key';

const Contacts = require('react-native-contacts');

const { leaderboardService } = require('src/services/leaderboard');
const { supabase } = require('src/services/supabase');
const { ERROR_CODES } = require('src/utils/errors');

describe('leaderboardService contacts privacy', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    supabase.auth.getUser.mockResolvedValue({
      data: { user: { id: 'me' } },
      error: null
    });
  });

  test('friends fetch does not auto-read contacts without explicit sync', async () => {
    const result = await leaderboardService.fetch('friends');
    expect(result).toEqual([]);
    expect(Contacts.getAll).not.toHaveBeenCalled();
    expect(supabase.rpc).not.toHaveBeenCalled();
  });

  test('syncContacts requires contacts permission when prompting is disabled', async () => {
    Contacts.checkPermission.mockResolvedValue('denied');
    await expect(
      leaderboardService.syncContacts({ allowPermissionPrompt: false })
    ).rejects.toMatchObject({
      code: ERROR_CODES.CONTACTS_PERMISSION_REQUIRED
    });
  });

  test('syncContacts uploads deduped identifiers and caps payload size', async () => {
    Contacts.checkPermission.mockResolvedValue('authorized');
    Contacts.getAll.mockResolvedValue(
      Array.from({ length: 350 }).map((_, idx) => ({
        emailAddresses: [
          {
            email: `User${idx % 320}@Example.com`
          }
        ],
        phoneNumbers: [
          {
            number: `650555${String(idx % 320).padStart(4, '0')}`
          }
        ]
      }))
    );

    supabase.rpc.mockImplementation(async (fn) => {
      if (fn === 'find_friends_leaderboard') {
        return {
          data: [
            {
              id: 'u-1',
              username: 'Alice',
              credits: 42,
              phone: '+***1234'
            }
          ],
          error: null
        };
      }
      return { data: [], error: null };
    });

    const result = await leaderboardService.syncContacts();
    expect(result.entries).toHaveLength(1);

    const call = supabase.rpc.mock.calls.find(
      ([fn]) => fn === 'find_friends_leaderboard'
    );
    expect(call).toBeTruthy();
    const payload = call[1];
    expect(payload.p_emails.length).toBeLessThanOrEqual(300);
    expect(payload.p_phones.length).toBeLessThanOrEqual(300);
    expect(result.syncStats.emailCount).toBe(payload.p_emails.length);
    expect(result.syncStats.phoneCount).toBe(payload.p_phones.length);
  });
});
