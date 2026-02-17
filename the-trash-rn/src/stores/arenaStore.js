import { create } from 'zustand';

import { arenaService } from 'src/services/arena';
import { dailyChallengeService } from 'src/services/dailyChallenge';
import { realtimeService } from 'src/services/realtime';
import { streakModeService } from 'src/services/streakMode';

import { useAchievementStore } from './achievementStore';

const SPEED_DURATION = 60;
const DUEL_COUNTDOWN_SECONDS = 3;
const DUEL_COMPLETE_RETRY_MS = 1200;
const DUEL_COMPLETE_MAX_ATTEMPTS = 20;
const DUEL_CLOCK_OFFSET_CACHE_MS = 1000 * 60 * 5;
const DUEL_GC_INTERVAL_MS = 1000 * 30;
const DUEL_STALE_SESSION_MS = 1000 * 60 * 10;

let speedTimerRef = null;
const duelCountdownTimers = new Map();
const duelEventQueues = new Map();
let duelGcInterval = null;

const initialClassic = {
  sessionId: null,
  question: null,
  questionIndex: 0,
  score: 0,
  state: 'idle',
  lastAnswerCorrect: null
};

const initialSpeed = {
  sessionId: null,
  question: null,
  score: 0,
  remaining: SPEED_DURATION,
  total: SPEED_DURATION,
  state: 'idle'
};

const initialStreak = {
  question: null,
  current: 0,
  best: 0,
  state: 'idle'
};

const initialDailyChallenge = {
  id: null,
  prompt: '加载中…',
  progress: 0,
  total: 0,
  reward: null,
  state: 'idle'
};

const normalizeAnswer = (value) =>
  String(value ?? '')
    .trim()
    .toLowerCase();

const notifyAchievement = (payload) => {
  useAchievementStore.getState().checkAndGrant(payload);
};

const sleep = (ms) =>
  new Promise((resolve) => {
    setTimeout(resolve, ms);
  });

const toId = (value) => {
  if (value == null) return null;
  return String(value);
};

const isSameId = (a, b) => {
  const left = toId(a);
  const right = toId(b);
  return Boolean(left && right && left === right);
};

const resolveOpponentId = ({ myUserId, challengerId, opponentId }) => {
  if (!myUserId) return null;
  if (isSameId(myUserId, challengerId)) return toId(opponentId);
  if (isSameId(myUserId, opponentId)) return toId(challengerId);
  return toId(opponentId ?? challengerId);
};

const clearDuelCountdown = (duelId) => {
  const timer = duelCountdownTimers.get(duelId);
  if (timer) {
    clearInterval(timer);
    duelCountdownTimers.delete(duelId);
  }
};

const queueDuelEvent = (duelId, task) => {
  const previous = duelEventQueues.get(duelId) ?? Promise.resolve();
  const next = previous
    .catch(() => {})
    .then(task)
    .catch((error) => {
      console.warn('[arenaStore] duel event queue error', duelId, error);
    });

  duelEventQueues.set(
    duelId,
    next.finally(() => {
      if (duelEventQueues.get(duelId) === next) {
        duelEventQueues.delete(duelId);
      }
    })
  );

  return next;
};

const clearQueuedDuelEvents = (duelId) => {
  duelEventQueues.delete(duelId);
};

const toNumber = (value) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

const getEstimatedServerNow = (offsetMs = 0) =>
  Date.now() + Number(offsetMs ?? 0);

const computeCountdownSeconds = (startAtServerMs, offsetMs = 0) => {
  const startAt = toNumber(startAtServerMs);
  if (startAt == null) return 0;
  const remainingMs = startAt - getEstimatedServerNow(offsetMs);
  return Math.max(0, Math.ceil(remainingMs / 1000));
};

const createDuelState = (duelId, submit) => ({
  id: duelId,
  status: 'loading',
  opponent: '等待对手',
  countdown: 0,
  countdownStartAtServerMs: null,
  questions: [],
  totalQuestions: 0,
  currentIndex: 0,
  currentQuestion: null,
  score: 0,
  correctCount: 0,
  myReady: false,
  opponentReady: false,
  bothReady: false,
  opponentProgress: 0,
  opponentCorrect: 0,
  opponentScore: 0,
  opponentFinished: false,
  opponentOnline: false,
  hasFinished: false,
  awaitingResult: false,
  finalizing: false,
  submitting: false,
  realtimeStatus: 'idle',
  channelName: null,
  challengerId: null,
  opponentId: null,
  myUserId: null,
  result: null,
  error: null,
  send: null,
  sendReady: null,
  sendAnswerSubmitted: null,
  sendFinished: null,
  unsubscribe: null,
  submit,
  createdAt: Date.now(),
  updatedAt: Date.now()
});

const patchDuel = (state, duelId, patch) => {
  const duel = state.duels[duelId];
  if (!duel) return null;
  return {
    ...state.duels,
    [duelId]: {
      ...duel,
      ...patch,
      updatedAt: Date.now()
    }
  };
};

const ACTIVE_DUEL_STATUSES = new Set(['playing', 'countdown', 'finalizing']);

const ensureDuelWatchdog = (get, set) => {
  if (duelGcInterval) return;

  duelGcInterval = setInterval(() => {
    const now = Date.now();
    const state = get();
    const staleIds = Object.entries(state.duels)
      .filter(([, duel]) => {
        if (!duel) return false;
        if (ACTIVE_DUEL_STATUSES.has(duel.status)) return false;
        const updatedAt = Number(duel.updatedAt ?? duel.createdAt ?? now);
        return now - updatedAt > DUEL_STALE_SESSION_MS;
      })
      .map(([id]) => id);

    if (!staleIds.length) return;

    staleIds.forEach((duelId) => {
      clearDuelCountdown(duelId);
      const duel = get().duels[duelId];
      duel?.unsubscribe?.();
      clearQueuedDuelEvents(duelId);
    });

    set((current) => {
      const duels = { ...current.duels };
      staleIds.forEach((duelId) => {
        delete duels[duelId];
      });
      return { duels };
    });
  }, DUEL_GC_INTERVAL_MS);
};

export const useArenaStore = create((set, get) => {
  ensureDuelWatchdog(get, set);
  return {
    classic: { ...initialClassic },
    speed: { ...initialSpeed },
    streak: { ...initialStreak },
    dailyChallenge: { ...initialDailyChallenge },
    duels: {},
    pendingChallenges: {},
    friends: [],
    dailyLeaderboard: [],
    streakLeaderboard: [],
    serverTimeOffsetMs: 0,
    serverTimeOffsetFetchedAt: 0,

    async syncServerTimeOffset({ force = false } = {}) {
      const cachedAt = Number(get().serverTimeOffsetFetchedAt ?? 0);
      const now = Date.now();
      if (
        !force &&
        cachedAt > 0 &&
        now - cachedAt < DUEL_CLOCK_OFFSET_CACHE_MS
      ) {
        return Number(get().serverTimeOffsetMs ?? 0);
      }

      const offsetMs = await arenaService.fetchServerTimeOffset();
      set({
        serverTimeOffsetMs: Number(offsetMs ?? 0),
        serverTimeOffsetFetchedAt: Date.now()
      });
      return Number(offsetMs ?? 0);
    },

    async startClassic() {
      set({ classic: { ...initialClassic, state: 'loading' } });
      const session = await arenaService.startClassic();
      set({
        classic: {
          sessionId: session.sessionId,
          question: session.question,
          questionIndex: 1,
          score: 0,
          state: 'playing',
          lastAnswerCorrect: null
        }
      });
    },

    async answerClassic(option) {
      const { classic } = get();
      if (!classic.question) return;
      const result = await arenaService.submitClassic({
        sessionId: classic.sessionId,
        questionId: classic.question.id,
        answer: option
      });
      const newScore = result.correct ? classic.score + 10 : classic.score;
      set({
        classic: {
          ...classic,
          score: newScore,
          question: result.nextQuestion,
          questionIndex: result.nextQuestion
            ? classic.questionIndex + 1
            : classic.questionIndex,
          lastAnswerCorrect: result.correct,
          state: result.nextQuestion ? 'playing' : 'finished'
        }
      });
      notifyAchievement({
        type: 'arena',
        mode: 'classic',
        correct: result.correct,
        score: newScore
      });
    },

    async startSpeedSort() {
      clearInterval(speedTimerRef);
      set({ speed: { ...initialSpeed, state: 'loading' } });
      const session = await arenaService.startSpeedSort();
      set({
        speed: {
          sessionId: session.sessionId,
          question: session.question,
          score: 0,
          remaining: session.duration,
          total: session.duration,
          state: 'playing'
        }
      });
      speedTimerRef = setInterval(() => {
        set((state) => {
          if (state.speed.remaining <= 1) {
            clearInterval(speedTimerRef);
            return {
              speed: {
                ...state.speed,
                state: 'finished',
                remaining: 0
              }
            };
          }
          return {
            speed: {
              ...state.speed,
              remaining: state.speed.remaining - 1
            }
          };
        });
      }, 1000);
    },

    async answerSpeedSort(option) {
      const { speed } = get();
      if (!speed.question || speed.state !== 'playing') return;
      const result = await arenaService.submitSpeedAnswer({
        sessionId: speed.sessionId,
        questionId: speed.question.id,
        answer: option
      });
      const newScore = speed.score + (result.scoreDelta ?? 0);
      set({
        speed: {
          ...speed,
          score: newScore,
          question: result.question
        }
      });
      if (result.correct) {
        notifyAchievement({
          type: 'arena',
          mode: 'speed',
          score: newScore,
          correct: true
        });
      }
    },

    stopSpeedSort() {
      clearInterval(speedTimerRef);
      set({ speed: { ...initialSpeed } });
    },

    async loadStreakStats() {
      const stats = await streakModeService.fetchStats();
      set({
        streak: {
          ...initialStreak,
          best: stats.best ?? 0,
          current: stats.current ?? 0
        }
      });
    },

    async startStreakSession() {
      await get().loadStreakStats();
      const question = await arenaService.fetchQuestion('streak');
      set((state) => ({
        streak: {
          ...state.streak,
          question,
          current: 0,
          state: question ? 'playing' : 'idle'
        }
      }));
    },

    async answerStreak(option) {
      const { streak } = get();
      if (!streak.question || streak.state !== 'playing') return;
      const correct =
        normalizeAnswer(streak.question.answer) === normalizeAnswer(option);
      const finished = !correct;
      const achievedStreak = correct ? streak.current + 1 : streak.current;
      await streakModeService.submitAnswer({
        finished,
        streakCount: achievedStreak
      });
      const nextQuestion = await arenaService.fetchQuestion('streak');
      const nextCurrent = correct ? streak.current + 1 : 0;
      const nextBest = correct
        ? Math.max(streak.best, nextCurrent)
        : streak.best;
      set({
        streak: {
          question: nextQuestion,
          current: nextCurrent,
          best: nextBest,
          state: correct ? 'playing' : 'cooldown'
        }
      });
      if (correct) {
        notifyAchievement({
          type: 'arena',
          mode: 'streak',
          streak: nextCurrent
        });
      }
    },

    async loadDailyChallenge() {
      const challenge = await dailyChallengeService.fetch();
      set({
        dailyChallenge: {
          ...challenge,
          state: challenge?.alreadyPlayed ? 'completed' : 'ready'
        }
      });
    },

    async incrementDailyChallenge() {
      const { dailyChallenge } = get();
      if (!dailyChallenge.id || dailyChallenge.state === 'completed') return;
      await dailyChallengeService.submit({
        score: dailyChallenge.total * 10,
        correctCount: dailyChallenge.total,
        timeSeconds: 60,
        maxCombo: dailyChallenge.total
      });
      const nextProgress = dailyChallenge.total;
      set({
        dailyChallenge: {
          ...dailyChallenge,
          progress: nextProgress,
          state: 'completed'
        }
      });
      notifyAchievement({ type: 'arena', mode: 'daily', completed: true });
    },

    async loadLeaderboards() {
      const data = await arenaService.fetchLeaderboards();
      set({
        dailyLeaderboard: data.daily ?? [],
        streakLeaderboard: data.streak ?? []
      });
    },

    async refreshChallenges() {
      const pending = await arenaService.fetchPendingChallenges();
      set({ pendingChallenges: pending ?? {} });
    },

    async loadFriends() {
      const friends = await arenaService.fetchFriends();
      set({ friends });
    },

    async sendInvite(friendId, mode = 'duel') {
      const challenge = await arenaService.sendInvite(friendId, mode);
      set((state) => ({
        pendingChallenges: {
          ...state.pendingChallenges,
          [challenge.id]: challenge
        }
      }));
    },

    async acceptChallenge(challengeId) {
      const payload = await arenaService.acceptChallenge(challengeId);
      const duelId = payload?.duelId ?? challengeId;

      set((state) => {
        const duel =
          state.duels[duelId] ??
          createDuelState(duelId, (option) =>
            get().submitDuelAnswer(duelId, option)
          );
        return {
          duels: {
            ...state.duels,
            [duelId]: {
              ...duel,
              status: 'lobby',
              channelName: payload?.channelName ?? duel.channelName,
              challengerId: payload?.challengerId ?? duel.challengerId,
              opponentId: payload?.opponentId ?? duel.opponentId,
              questions: payload?.questions ?? duel.questions,
              totalQuestions: (payload?.questions ?? duel.questions ?? [])
                .length,
              currentQuestion:
                (payload?.questions ?? duel.questions)?.[0] ?? null,
              currentIndex: 0,
              hasFinished: false,
              awaitingResult: false,
              finalizing: false,
              error: null
            }
          }
        };
      });

      await get().ensureDuel(duelId, { preloadedPayload: payload });
      await get().refreshChallenges();
      return {
        ...payload,
        duelId
      };
    },

    async ensureDuel(duelId, options = {}) {
      if (!duelId) return null;

      const existing = get().duels[duelId];
      if (!existing) {
        set((state) => ({
          duels: {
            ...state.duels,
            [duelId]: createDuelState(duelId, (option) =>
              get().submitDuelAnswer(duelId, option)
            )
          }
        }));
      }

      let payload = options.preloadedPayload ?? null;
      try {
        if (!payload) {
          payload = await arenaService.getChallengeQuestions(duelId);
        }
      } catch (error) {
        console.warn('[arenaStore] getChallengeQuestions failed', error);
        set((state) => {
          const duels = patchDuel(state, duelId, {
            status: 'lobby',
            error: '无法加载对战题目'
          });
          return duels ? { duels } : {};
        });
        return get().duels[duelId] ?? null;
      }

      const myUserId =
        payload?.myUserId ?? (await arenaService.getCurrentUserId());
      const challengerId = payload?.challengerId ?? null;
      const opponentId = payload?.opponentId ?? null;
      const remoteOpponentId = resolveOpponentId({
        myUserId,
        challengerId,
        opponentId
      });
      const channelName = payload?.channelName ?? `duel:${duelId}`;
      const pending = get().pendingChallenges[duelId];

      const onPlayerReady = ({ userId, isOpponent }) => {
        queueDuelEvent(duelId, async () => {
          if (!userId) return;
          const latest = get().duels[duelId];
          if (!latest) return;
          if (isSameId(userId, latest.myUserId ?? myUserId)) return;

          const opponentReady = Boolean(
            isOpponent ||
            !remoteOpponentId ||
            latest.opponentReady ||
            isSameId(userId, latest.opponentId) ||
            isSameId(userId, latest.challengerId)
          );
          const bothReady = Boolean(latest.myReady && opponentReady);

          set((state) => {
            const duel = state.duels[duelId];
            if (!duel) return {};
            return {
              duels: {
                ...state.duels,
                [duelId]: {
                  ...duel,
                  opponentReady,
                  bothReady
                }
              }
            };
          });

          if (bothReady) {
            await get().beginSynchronizedCountdown(duelId);
          }
        });
      };

      const onAnswerSubmitted = ({ userId, questionIndex, isCorrect }) => {
        queueDuelEvent(duelId, async () => {
          const latest = get().duels[duelId];
          if (!latest) return;
          if (!userId || isSameId(userId, latest.myUserId ?? myUserId)) return;

          set((state) => {
            const duel = state.duels[duelId];
            if (!duel) return {};
            const safeIndex = Number.isFinite(questionIndex)
              ? questionIndex
              : 0;
            return {
              duels: {
                ...state.duels,
                [duelId]: {
                  ...duel,
                  opponentProgress: Math.max(
                    duel.opponentProgress,
                    safeIndex + 1
                  ),
                  opponentCorrect: isCorrect
                    ? duel.opponentCorrect + 1
                    : duel.opponentCorrect,
                  opponentScore: isCorrect
                    ? duel.opponentScore + 20
                    : duel.opponentScore
                }
              }
            };
          });
        });
      };

      const onPlayerFinished = ({ userId, totalCorrect, totalScore }) => {
        queueDuelEvent(duelId, async () => {
          const latest = get().duels[duelId];
          if (!latest) return;
          if (!userId || isSameId(userId, latest.myUserId ?? myUserId)) return;

          set((state) => {
            const duel = state.duels[duelId];
            if (!duel) return {};
            const nextStatus = duel.hasFinished
              ? 'finalizing'
              : 'waiting-result';
            return {
              duels: {
                ...state.duels,
                [duelId]: {
                  ...duel,
                  opponentFinished: true,
                  opponentProgress:
                    duel.totalQuestions > 0
                      ? Math.max(duel.opponentProgress, duel.totalQuestions)
                      : duel.opponentProgress,
                  opponentCorrect: Number.isFinite(totalCorrect)
                    ? totalCorrect
                    : duel.opponentCorrect,
                  opponentScore: Number.isFinite(totalScore)
                    ? totalScore
                    : duel.opponentScore,
                  status: nextStatus,
                  awaitingResult: duel.hasFinished
                }
              }
            };
          });

          await get().maybeFinalizeDuel(duelId);
        });
      };

      const onPresence = ({ opponentOnline }) => {
        queueDuelEvent(duelId, async () => {
          set((state) => {
            const duels = patchDuel(state, duelId, { opponentOnline });
            return duels ? { duels } : {};
          });
        });
      };

      const onStatusChange = (status) => {
        queueDuelEvent(duelId, async () => {
          set((state) => {
            const duels = patchDuel(state, duelId, {
              realtimeStatus: String(status ?? 'unknown')
            });
            return duels ? { duels } : {};
          });
        });
      };

      const onState = (payloadState) => {
        queueDuelEvent(duelId, async () => {
          if (!payloadState || typeof payloadState !== 'object') return;
          const nextPatch = {};

          if (typeof payloadState.status === 'string') {
            nextPatch.status = payloadState.status;
          }
          if (Number.isFinite(payloadState.countdown)) {
            nextPatch.countdown = payloadState.countdown;
          }
          if (Number.isFinite(payloadState.currentIndex)) {
            nextPatch.opponentProgress = Math.max(
              0,
              Number(payloadState.currentIndex) + 1
            );
          }
          if (Number.isFinite(payloadState.score)) {
            nextPatch.opponentScore = Number(payloadState.score);
          }

          const startAtServerMs = toNumber(payloadState.startAtServerMs);
          if (startAtServerMs != null) {
            nextPatch.countdownStartAtServerMs = startAtServerMs;
            nextPatch.status = 'countdown';
          }

          if (!Object.keys(nextPatch).length) return;

          set((state) => {
            const duels = patchDuel(state, duelId, nextPatch);
            return duels ? { duels } : {};
          });

          if (startAtServerMs != null) {
            await get().beginSynchronizedCountdown(duelId, startAtServerMs);
          }
        });
      };

      clearQueuedDuelEvents(duelId);
      const existingDuel = get().duels[duelId];
      existingDuel?.unsubscribe?.();

      const realtime = realtimeService.joinDuel(
        duelId,
        {
          onState,
          onPlayerReady,
          onAnswerSubmitted,
          onPlayerFinished,
          onPresence,
          onStatusChange
        },
        {
          channelName,
          myUserId,
          opponentUserId: remoteOpponentId
        }
      );

      const questions = payload?.questions ?? existingDuel?.questions ?? [];
      const hasQuestions = questions.length > 0;

      set((state) => {
        const duel = state.duels[duelId];
        if (!duel) return {};
        return {
          duels: {
            ...state.duels,
            [duelId]: {
              ...duel,
              status:
                duel.status === 'playing' || duel.status === 'countdown'
                  ? duel.status
                  : 'lobby',
              opponent: pending?.opponentName ?? duel.opponent ?? '等待对手',
              channelName,
              challengerId,
              opponentId,
              myUserId,
              questions,
              totalQuestions: questions.length,
              currentIndex: duel.currentIndex ?? 0,
              currentQuestion:
                duel.currentQuestion ?? (hasQuestions ? questions[0] : null),
              error: hasQuestions ? null : '题目尚未准备完成',
              send: realtime.send,
              sendReady: realtime.sendReady,
              sendAnswerSubmitted: realtime.sendAnswerSubmitted,
              sendFinished: realtime.sendFinished,
              unsubscribe: realtime.unsubscribe,
              submit: (option) => get().submitDuelAnswer(duelId, option)
            }
          }
        };
      });

      return get().duels[duelId] ?? null;
    },

    async beginSynchronizedCountdown(duelId, explicitStartAtServerMs = null) {
      if (!duelId) return null;

      const duel = get().duels[duelId];
      if (!duel) return null;
      if (duel.status === 'playing' || duel.status === 'completed') {
        return duel.countdownStartAtServerMs ?? null;
      }
      if (!duel.questions?.length) return null;

      let startAtServerMs = toNumber(explicitStartAtServerMs);
      if (startAtServerMs == null) {
        startAtServerMs = toNumber(duel.countdownStartAtServerMs);
      }

      if (startAtServerMs == null) {
        const iAmCountdownHost = isSameId(duel.myUserId, duel.challengerId);
        if (!iAmCountdownHost) {
          return null;
        }
        const offsetMs = await get().syncServerTimeOffset();
        startAtServerMs =
          getEstimatedServerNow(offsetMs) + DUEL_COUNTDOWN_SECONDS * 1000 + 450;
        duel.send?.({
          status: 'countdown',
          startAtServerMs
        });
      }

      get().startDuelCountdown(duelId, startAtServerMs);
      return startAtServerMs;
    },

    startDuelCountdown(duelId, startAtServerMs = null) {
      if (!duelId) return;
      const duel = get().duels[duelId];
      if (!duel) return;
      if (!duel.questions?.length) return;
      if (duel.status === 'playing' || duel.status === 'completed') return;

      const countdownStartAt =
        toNumber(startAtServerMs) ?? toNumber(duel.countdownStartAtServerMs);
      if (countdownStartAt == null) return;
      const offsetMs = Number(get().serverTimeOffsetMs ?? 0);

      clearDuelCountdown(duelId);
      set((state) => {
        const duels = patchDuel(state, duelId, {
          status: 'countdown',
          countdownStartAtServerMs: countdownStartAt,
          countdown: computeCountdownSeconds(countdownStartAt, offsetMs),
          error: null
        });
        return duels ? { duels } : {};
      });

      const initialState = get().duels[duelId];
      if (!initialState || (initialState.countdown ?? 0) <= 0) {
        set((state) => {
          const duelState = state.duels[duelId];
          if (!duelState) return {};
          return {
            duels: {
              ...state.duels,
              [duelId]: {
                ...duelState,
                status: 'playing',
                countdown: 0,
                currentQuestion:
                  duelState.currentQuestion ?? duelState.questions?.[0] ?? null
              }
            }
          };
        });
        return;
      }

      const timer = setInterval(() => {
        const latest = get().duels[duelId];
        if (!latest) {
          clearDuelCountdown(duelId);
          return;
        }

        const startAt = toNumber(
          latest.countdownStartAtServerMs ?? countdownStartAt
        );
        if (startAt == null) {
          clearDuelCountdown(duelId);
          return;
        }

        const latestOffset = Number(get().serverTimeOffsetMs ?? 0);
        const remainingSeconds = computeCountdownSeconds(startAt, latestOffset);

        if (remainingSeconds <= 0) {
          clearDuelCountdown(duelId);
          set((state) => {
            const duelState = state.duels[duelId];
            if (!duelState) return {};
            return {
              duels: {
                ...state.duels,
                [duelId]: {
                  ...duelState,
                  status: 'playing',
                  countdown: 0,
                  currentQuestion:
                    duelState.currentQuestion ??
                    duelState.questions?.[0] ??
                    null
                }
              }
            };
          });
          return;
        }

        if (remainingSeconds !== latest.countdown) {
          set((state) => {
            const duelState = state.duels[duelId];
            if (!duelState) return {};
            return {
              duels: {
                ...state.duels,
                [duelId]: {
                  ...duelState,
                  countdown: remainingSeconds
                }
              }
            };
          });
        }
      }, 250);

      duelCountdownTimers.set(duelId, timer);
    },

    async startDuel(duelId) {
      if (!duelId) return;
      let duel = get().duels[duelId];

      if (!duel) {
        duel = await get().ensureDuel(duelId);
      }
      if (!duel) return;

      if (!duel.questions?.length) {
        await get().ensureDuel(duelId);
        duel = get().duels[duelId];
      }

      if (!duel) return;
      if (duel.status === 'playing' || duel.status === 'completed') return;
      if (!duel.myReady) {
        duel.sendReady?.();
        set((state) => {
          const current = state.duels[duelId];
          if (!current) return {};
          const bothReady = current.opponentReady;
          return {
            duels: {
              ...state.duels,
              [duelId]: {
                ...current,
                myReady: true,
                bothReady,
                status:
                  current.status === 'countdown' || current.status === 'playing'
                    ? current.status
                    : 'lobby',
                error: null
              }
            }
          };
        });
        const latest = get().duels[duelId];
        if (latest?.bothReady) {
          await get().beginSynchronizedCountdown(duelId);
        }
        return;
      }

      if (duel.myReady && duel.opponentReady) {
        await get().beginSynchronizedCountdown(duelId);
      }
    },

    async submitDuelAnswer(duelId, option) {
      const duel = get().duels[duelId];
      if (!duel?.currentQuestion) return;
      if (duel.status !== 'playing' || duel.submitting) return;

      set((state) => {
        const duels = patchDuel(state, duelId, {
          submitting: true,
          error: null
        });
        return duels ? { duels } : {};
      });

      try {
        const result = await arenaService.submitDuelAnswer({
          challengeId: duelId,
          questionIndex: duel.currentIndex ?? 0,
          selectedCategory: option,
          answerTimeMs: 0
        });

        const correct = Boolean(result?.is_correct);
        const nextIndex = (duel.currentIndex ?? 0) + 1;
        const nextQuestion = duel.questions?.[nextIndex] ?? null;
        const nextScore = correct ? duel.score + 20 : duel.score;
        const nextCorrectCount = correct
          ? duel.correctCount + 1
          : duel.correctCount;
        const finished = !nextQuestion;

        set((state) => {
          const current = state.duels[duelId];
          if (!current) return {};
          return {
            duels: {
              ...state.duels,
              [duelId]: {
                ...current,
                submitting: false,
                currentQuestion: nextQuestion,
                currentIndex: nextIndex,
                score: nextScore,
                correctCount: nextCorrectCount,
                hasFinished: finished,
                status: finished
                  ? current.opponentFinished
                    ? 'finalizing'
                    : 'waiting-result'
                  : 'playing',
                awaitingResult: finished,
                opponentProgress: current.opponentProgress,
                error: null
              }
            }
          };
        });

        const latest = get().duels[duelId];
        latest?.sendAnswerSubmitted?.({
          questionIndex: duel.currentIndex ?? 0,
          isCorrect: correct
        });
        latest?.send?.({
          currentIndex: nextIndex,
          score: nextScore,
          status: finished ? 'waiting-result' : 'playing'
        });

        if (finished) {
          latest?.sendFinished?.({
            totalCorrect: nextCorrectCount,
            totalScore: nextScore
          });
          get().maybeFinalizeDuel(duelId);
        }

        if (correct) {
          notifyAchievement({ type: 'arena', mode: 'duel', correct: true });
        }
      } catch (error) {
        console.warn('[arenaStore] submit duel answer failed', error);
        set((state) => {
          const duels = patchDuel(state, duelId, {
            submitting: false,
            error: error?.message ?? '提交答案失败'
          });
          return duels ? { duels } : {};
        });
      }
    },

    async maybeFinalizeDuel(duelId) {
      const duel = get().duels[duelId];
      if (!duel) return;
      if (!duel.hasFinished || !duel.opponentFinished) return;
      if (duel.finalizing || duel.status === 'completed') return;

      set((state) => {
        const duels = patchDuel(state, duelId, {
          finalizing: true,
          awaitingResult: false,
          status: 'finalizing',
          error: null
        });
        return duels ? { duels } : {};
      });

      for (
        let attempt = 0;
        attempt < DUEL_COMPLETE_MAX_ATTEMPTS;
        attempt += 1
      ) {
        try {
          const result = await arenaService.completeDuel(duelId);
          if (result) {
            set((state) => {
              const duels = patchDuel(state, duelId, {
                finalizing: false,
                awaitingResult: false,
                status: 'completed',
                result,
                error: null
              });
              return duels ? { duels } : {};
            });
            return;
          }
        } catch (error) {
          console.warn('[arenaStore] finalize duel failed', error);
        }
        await sleep(DUEL_COMPLETE_RETRY_MS);
      }

      set((state) => {
        const duels = patchDuel(state, duelId, {
          finalizing: false,
          awaitingResult: true,
          status: 'waiting-result',
          error: '等待对手完成结算，稍后会自动同步结果。'
        });
        return duels ? { duels } : {};
      });
    },

    disposeDuel(duelId) {
      if (!duelId) return;
      clearDuelCountdown(duelId);
      clearQueuedDuelEvents(duelId);
      const duel = get().duels[duelId];
      duel?.unsubscribe?.();
      set((state) => {
        const duels = { ...state.duels };
        delete duels[duelId];
        return { duels };
      });
    },

    async acceptDeepLink(id) {
      await get().refreshChallenges();
      return `/(tabs)/arena/duel/${id}`;
    }
  };
});
