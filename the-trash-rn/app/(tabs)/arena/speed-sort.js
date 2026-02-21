import { Text, View } from 'react-native';

import QuizCard from 'src/components/arena/QuizCard';
import TimerBar from 'src/components/arena/TimerBar';
import ScreenShell from 'src/components/layout/ScreenShell';
import { TrashButton } from 'src/components/themed';
import { useArenaStore } from 'src/stores/arenaStore';

export default function SpeedSortScreen() {
  const speed = useArenaStore((state) => state.speed);
  const startSpeedSort = useArenaStore((state) => state.startSpeedSort);
  const answerSpeedSort = useArenaStore((state) => state.answerSpeedSort);
  const stopSpeedSort = useArenaStore((state) => state.stopSpeedSort);

  const progress = speed.total ? speed.remaining / speed.total : 0;

  return (
    <ScreenShell title="极速分类" useScroll={false}>
      <View className="flex-row justify-between items-center mb-4">
        <View>
          <Text className="text-white text-3xl font-bold">{speed.score}</Text>
          <Text className="text-white/60 text-xs">得分</Text>
        </View>
        <View className="items-end">
          <Text className="text-white text-xl font-semibold">
            {speed.remaining}s
          </Text>
          <Text className="text-white/60 text-xs">剩余时间</Text>
        </View>
      </View>
      <TimerBar
        progress={progress}
        variant={speed.remaining < 15 ? 'warning' : 'info'}
      />
      {speed.state === 'idle' ? (
        <TrashButton title="开始 60 秒冲刺" onPress={startSpeedSort} />
      ) : speed.state === 'finished' ? (
        <View>
          <Text className="text-white/80 text-sm mb-4">
            时间到！本轮得分 {speed.score}
          </Text>
          <TrashButton title="再玩一次" onPress={startSpeedSort} />
        </View>
      ) : (
        <QuizCard
          question={speed.question}
          onAnswer={(option) => answerSpeedSort(option)}
          mode="speed"
        />
      )}
      {speed.state === 'playing' ? (
        <TrashButton
          title="提前结束"
          variant="outline"
          onPress={stopSpeedSort}
          style={{ marginTop: 20 }}
        />
      ) : null}
    </ScreenShell>
  );
}
