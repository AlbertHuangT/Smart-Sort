import { useEffect } from 'react';
import { Text, View } from 'react-native';

import ScreenShell from 'src/components/layout/ScreenShell';
import { TrashButton } from 'src/components/themed';
import { useArenaStore } from 'src/stores/arenaStore';

export default function DailyChallengeScreen() {
  const dailyChallenge = useArenaStore((state) => state.dailyChallenge);
  const loadDailyChallenge = useArenaStore((state) => state.loadDailyChallenge);
  const incrementDailyChallenge = useArenaStore(
    (state) => state.incrementDailyChallenge
  );

  useEffect(() => {
    loadDailyChallenge();
  }, [loadDailyChallenge]);

  const progressPercent = dailyChallenge.total
    ? Math.round((dailyChallenge.progress / dailyChallenge.total) * 100)
    : 0;

  return (
    <ScreenShell title="每日挑战">
      <View className="rounded-3xl border border-white/10 bg-white/5 p-6 mb-4">
        <Text className="text-white/60 text-xs mb-2">今日任务</Text>
        <Text className="text-white text-2xl font-semibold mb-1">
          {dailyChallenge.prompt}
        </Text>
        <Text className="text-white/60 text-sm mb-3">
          进度 {dailyChallenge.progress}/{dailyChallenge.total} ·{' '}
          {progressPercent}%
        </Text>
        <Text className="text-brand-neon text-xs">
          奖励 {dailyChallenge.reward ?? '待公布'}
        </Text>
      </View>
      <TrashButton
        title={dailyChallenge.state === 'completed' ? '已完成' : '标记完成'}
        onPress={incrementDailyChallenge}
        disabled={dailyChallenge.state === 'completed'}
      />
    </ScreenShell>
  );
}
