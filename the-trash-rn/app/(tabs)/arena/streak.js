import { Text, View } from 'react-native';

import QuizCard from 'src/components/arena/QuizCard';
import ScreenShell from 'src/components/layout/ScreenShell';
import { TrashButton } from 'src/components/themed';
import { useArenaStore } from 'src/stores/arenaStore';

export default function StreakModeScreen() {
  const streak = useArenaStore((state) => state.streak);
  const startStreakSession = useArenaStore((state) => state.startStreakSession);
  const answerStreak = useArenaStore((state) => state.answerStreak);

  return (
    <ScreenShell title="连胜模式">
      <View className="rounded-3xl border border-white/10 bg-white/5 p-6 mb-4">
        <Text className="text-white/70 text-sm mb-2">当前连胜</Text>
        <Text className="text-white text-4xl font-bold">{streak.current}</Text>
        <Text className="text-white/50 text-xs mt-2">
          最佳纪录 {streak.best}
        </Text>
      </View>
      {streak.state === 'playing' && streak.question ? (
        <QuizCard
          question={streak.question}
          onAnswer={(option) => answerStreak(option)}
          mode="streak"
        />
      ) : (
        <TrashButton title="开始连胜挑战" onPress={startStreakSession} />
      )}
      {streak.state === 'cooldown' ? (
        <Text className="text-red-300 text-xs mt-3">答错了！请重新开始。</Text>
      ) : null}
    </ScreenShell>
  );
}
