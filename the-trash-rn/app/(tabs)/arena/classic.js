import { useEffect } from 'react';
import { Text, View } from 'react-native';

import QuizCard from 'src/components/arena/QuizCard';
import ScreenShell from 'src/components/layout/ScreenShell';
import { TrashButton } from 'src/components/themed';
import { useArenaStore } from 'src/stores/arenaStore';

export default function ClassicArenaScreen() {
  const classic = useArenaStore((state) => state.classic);
  const startClassic = useArenaStore((state) => state.startClassic);
  const answerClassic = useArenaStore((state) => state.answerClassic);

  useEffect(() => {
    if (classic.state === 'idle') {
      startClassic().catch(() => {});
    }
  }, [classic.state, startClassic]);

  return (
    <ScreenShell title="经典模式" useScroll={false}>
      <View className="flex-row justify-between items-center mb-4">
        <View>
          <Text className="text-white text-3xl font-bold">{classic.score}</Text>
          <Text className="text-white/60 text-xs">分数</Text>
        </View>
        <View className="items-end">
          <Text className="text-white text-xl font-semibold">
            第 {classic.questionIndex ?? 0} 题
          </Text>
          {classic.lastAnswerCorrect != null ? (
            <Text
              className={`text-xs ${classic.lastAnswerCorrect ? 'text-green-300' : 'text-red-300'}`}
            >
              {classic.lastAnswerCorrect ? '答对 +10' : '答错 0 分'}
            </Text>
          ) : null}
        </View>
      </View>
      {classic.state === 'finished' ? (
        <View className="rounded-3xl border border-white/10 bg-white/5 p-6">
          <Text className="text-white font-semibold text-lg mb-1">
            本轮已结束
          </Text>
          <Text className="text-white/70 text-sm">
            最终得分 {classic.score}
          </Text>
        </View>
      ) : (
        <QuizCard
          question={classic.question}
          onAnswer={(option) => answerClassic(option)}
          mode="classic"
        />
      )}
      <TrashButton
        title="换一批题目"
        onPress={startClassic}
        variant="outline"
        style={{ marginTop: 24 }}
      />
    </ScreenShell>
  );
}
