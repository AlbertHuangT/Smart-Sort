import { Text, View } from 'react-native';

import QuizCard from 'src/components/arena/QuizCard';
import ScreenShell from 'src/components/layout/ScreenShell';
import { TrashButton } from 'src/components/themed';
import { useArenaStore } from 'src/stores/arenaStore';
import { useTheme } from 'src/theme/ThemeProvider';

export default function StreakModeScreen() {
  const theme = useTheme();
  const spacing = theme.spacing ?? {};
  const radii = theme.radii ?? {};
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

  const streak = useArenaStore((state) => state.streak);
  const startStreakSession = useArenaStore((state) => state.startStreakSession);
  const answerStreak = useArenaStore((state) => state.answerStreak);

  return (
    <ScreenShell title="Streak Mode">
      <View
        style={{
          borderRadius: radii.card ?? 20,
          borderWidth: 1,
          borderColor: theme.tabBar.border,
          backgroundColor: theme.palette.card,
          padding: theme.components?.card?.padding ?? spacing.lg ?? 20,
          marginBottom: spacing.md ?? 14
        }}
      >
        <Text
          style={{
            color: theme.palette.textSecondary,
            fontSize: bodyType.size,
            lineHeight: bodyType.lineHeight,
            letterSpacing: bodyType.letterSpacing,
            marginBottom: spacing.xs ?? 6
          }}
        >
          Current streak
        </Text>
        <Text
          style={{
            color: theme.palette.textPrimary,
            fontSize: bodyType.size + 16,
            lineHeight: bodyType.lineHeight + 16,
            fontWeight: '700',
            letterSpacing: bodyType.letterSpacing
          }}
        >
          {streak.current}
        </Text>
        <Text
          style={{
            color: theme.palette.textSecondary,
            fontSize: captionType.size,
            lineHeight: captionType.lineHeight,
            letterSpacing: captionType.letterSpacing,
            marginTop: spacing.xs ?? 6
          }}
        >
          Best record {streak.best}
        </Text>
      </View>
      {streak.state === 'playing' && streak.question ? (
        <QuizCard
          question={streak.question}
          onAnswer={(option) => answerStreak(option)}
          mode="streak"
        />
      ) : (
        <TrashButton
          title="Start Streak Challenge"
          onPress={startStreakSession}
        />
      )}
      {streak.state === 'cooldown' ? (
        <Text
          style={{
            color: theme.palette.danger ?? '#fca5a5',
            fontSize: captionType.size,
            lineHeight: captionType.lineHeight,
            letterSpacing: captionType.letterSpacing,
            marginTop: spacing.sm ?? 10
          }}
        >
          Wrong answer. Start again.
        </Text>
      ) : null}
    </ScreenShell>
  );
}
