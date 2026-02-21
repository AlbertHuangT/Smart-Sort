import { Text, View } from 'react-native';

import QuizCard from 'src/components/arena/QuizCard';
import TimerBar from 'src/components/arena/TimerBar';
import ScreenShell from 'src/components/layout/ScreenShell';
import { TrashButton } from 'src/components/themed';
import { useArenaStore } from 'src/stores/arenaStore';
import { useTheme } from 'src/theme/ThemeProvider';

export default function SpeedSortScreen() {
  const theme = useTheme();
  const spacing = theme.spacing ?? {};
  const bodyType = theme.typography?.body ?? {
    size: 15,
    lineHeight: 22,
    letterSpacing: 0.12
  };
  const captionType = theme.typography?.caption ?? {
    size: 12,
    lineHeight: 17,
    letterSpacing: 0.14
  };

  const speed = useArenaStore((state) => state.speed);
  const startSpeedSort = useArenaStore((state) => state.startSpeedSort);
  const answerSpeedSort = useArenaStore((state) => state.answerSpeedSort);
  const stopSpeedSort = useArenaStore((state) => state.stopSpeedSort);

  const progress = speed.total ? speed.remaining / speed.total : 0;

  return (
    <ScreenShell title="Speed Sort" useScroll={false}>
      <View
        style={{
          flexDirection: 'row',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: spacing.md ?? 14
        }}
      >
        <View>
          <Text
            style={{
              color: theme.palette.textPrimary,
              fontSize: bodyType.size + 14,
              lineHeight: bodyType.lineHeight + 14,
              fontWeight: '700',
              letterSpacing: bodyType.letterSpacing
            }}
          >
            {speed.score}
          </Text>
          <Text
            style={{
              color: theme.palette.textSecondary,
              fontSize: captionType.size,
              lineHeight: captionType.lineHeight,
              letterSpacing: captionType.letterSpacing
            }}
          >
            Score
          </Text>
        </View>
        <View style={{ alignItems: 'flex-end' }}>
          <Text
            style={{
              color: theme.palette.textPrimary,
              fontSize: bodyType.size + 4,
              lineHeight: bodyType.lineHeight + 4,
              fontWeight: '600',
              letterSpacing: bodyType.letterSpacing
            }}
          >
            {speed.remaining}s
          </Text>
          <Text
            style={{
              color: theme.palette.textSecondary,
              fontSize: captionType.size,
              lineHeight: captionType.lineHeight,
              letterSpacing: captionType.letterSpacing
            }}
          >
            Time left
          </Text>
        </View>
      </View>
      <TimerBar
        progress={progress}
        variant={speed.remaining < 15 ? 'warning' : 'info'}
      />
      {speed.state === 'idle' ? (
        <TrashButton title="Start 60s Sprint" onPress={startSpeedSort} />
      ) : speed.state === 'finished' ? (
        <View>
          <Text
            style={{
              color: theme.palette.textSecondary,
              fontSize: bodyType.size,
              lineHeight: bodyType.lineHeight,
              letterSpacing: bodyType.letterSpacing,
              marginBottom: spacing.md ?? 14
            }}
          >
            Time is up! Score this round: {speed.score}
          </Text>
          <TrashButton title="Play Again" onPress={startSpeedSort} />
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
          title="End Early"
          variant="outline"
          onPress={stopSpeedSort}
          style={{ marginTop: spacing.lg ?? 20 }}
        />
      ) : null}
    </ScreenShell>
  );
}
