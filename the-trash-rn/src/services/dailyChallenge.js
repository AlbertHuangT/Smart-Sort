import { arenaService } from './arena';

export const dailyChallengeService = {
  fetch: () => arenaService.fetchDailyChallenge(),
  submit: (payload) => arenaService.submitDailyChallenge(payload)
};
