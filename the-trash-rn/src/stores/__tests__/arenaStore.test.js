const setupArenaStore = () => {
  jest.resetModules();

  const arenaService = {
    startClassic: jest.fn().mockResolvedValue({
      sessionId: 'classic-1',
      question: { id: 'q-1', prompt: 'Q1' }
    }),
    fetchServerTimeOffset: jest.fn().mockResolvedValue(0),
    acceptChallenge: jest.fn().mockResolvedValue({
      duelId: 'duel-1',
      challenge_id: 'duel-1',
      channelName: 'duel:duel-1',
      questions: [{ id: 'dq-1', prompt: 'DQ1' }],
      challengerId: 'me',
      opponentId: 'u-2'
    }),
    getChallengeQuestions: jest.fn(),
    getCurrentUserId: jest.fn().mockResolvedValue('me'),
    fetchPendingChallenges: jest.fn().mockResolvedValue({}),
    fetchLeaderboards: jest.fn().mockResolvedValue({ daily: [], streak: [] }),
    fetchFriends: jest.fn().mockResolvedValue([]),
    sendInvite: jest.fn().mockResolvedValue({
      id: 'challenge-1',
      opponentId: 'u-2'
    }),
    submitDuelAnswer: jest.fn(),
    completeDuel: jest.fn().mockResolvedValue(null),
    fetchQuestion: jest.fn().mockResolvedValue(null),
    submitClassic: jest.fn(),
    startSpeedSort: jest.fn(),
    submitSpeedAnswer: jest.fn()
  };

  const realtimeService = {
    joinDuel: jest.fn().mockReturnValue({
      send: jest.fn(),
      sendReady: jest.fn(),
      sendAnswerSubmitted: jest.fn(),
      sendFinished: jest.fn(),
      unsubscribe: jest.fn()
    })
  };

  jest.doMock('src/services/arena', () => ({ arenaService }));
  jest.doMock('src/services/realtime', () => ({ realtimeService }));
  jest.doMock('src/services/dailyChallenge', () => ({
    dailyChallengeService: {
      fetch: jest.fn().mockResolvedValue({
        id: 'daily-1',
        alreadyPlayed: false,
        total: 3,
        progress: 0
      }),
      submit: jest.fn().mockResolvedValue(true)
    }
  }));
  jest.doMock('src/services/streakMode', () => ({
    streakModeService: {
      fetchStats: jest.fn().mockResolvedValue({ best: 0, current: 0 }),
      submitAnswer: jest.fn().mockResolvedValue(true)
    }
  }));
  jest.doMock('src/stores/achievementStore', () => ({
    useAchievementStore: {
      getState: () => ({
        checkAndGrant: jest.fn()
      })
    }
  }));

  const { useArenaStore } = require('src/stores/arenaStore');
  return { useArenaStore, arenaService, realtimeService };
};

describe('arenaStore slices', () => {
  test('solo slice methods update classic mode state', async () => {
    const { useArenaStore, arenaService } = setupArenaStore();

    await useArenaStore.getState().startClassic();

    const state = useArenaStore.getState();
    expect(state.classic.state).toBe('playing');
    expect(state.classic.sessionId).toBe('classic-1');
    expect(arenaService.startClassic).toHaveBeenCalledTimes(1);
  });

  test('duel slice methods initialize duel session from acceptChallenge', async () => {
    const { useArenaStore, realtimeService } = setupArenaStore();

    await useArenaStore.getState().acceptChallenge('duel-1');

    const duel = useArenaStore.getState().duels['duel-1'];
    expect(duel).toBeTruthy();
    expect(duel.channelName).toBe('duel:duel-1');
    expect(duel.totalQuestions).toBe(1);
    expect(typeof duel.sendReady).toBe('function');
    expect(realtimeService.joinDuel).toHaveBeenCalledTimes(1);
  });
});
