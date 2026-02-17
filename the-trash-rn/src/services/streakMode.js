import { arenaService } from './arena';

export const streakModeService = {
  fetchStats: () => arenaService.fetchStreakStats(),
  submitAnswer: (payload) => arenaService.submitStreakAnswer(payload)
};
