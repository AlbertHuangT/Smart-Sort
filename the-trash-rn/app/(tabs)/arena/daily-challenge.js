import { useEffect } from 'react';
import { Text, View } from 'react-native';

import ScreenShell from 'src/components/layout/ScreenShell';
import { TrashButton } from 'src/components/themed';
import { useArenaStore } from 'src/stores/arenaStore';
import { useTheme } from 'src/theme/ThemeProvider';

export default function DailyChallengeScreen() {
  const theme = useTheme();
  const spacing = theme.spacing ?? {};
  const radii = theme.radii ?? {};
  const bodyType = theme.typography?.body ?? {
    size: 15,
    lineHeight: 22,
    letterSpacing: 0.12
  };
  const labelType = theme.typography?.label ?? {
    size: 14,
    lineHeight: 19,
    letterSpacing: 0.18
  };
  const captionType = theme.typography?.caption ?? {
    size: 12,
    lineHeight: 17,
    letterSpacing: 0.14
  };

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
    <ScreenShell title="Daily Challenge">
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
            fontSize: captionType.size,
            lineHeight: captionType.lineHeight,
            letterSpacing: captionType.letterSpacing,
            marginBottom: spacing.xs ?? 6
          }}
        >
          Today's task
        </Text>
        <Text
          style={{
            color: theme.palette.textPrimary,
            fontSize: bodyType.size + 9,
            lineHeight: bodyType.lineHeight + 9,
            fontWeight: '700',
            letterSpacing: bodyType.letterSpacing,
            marginBottom: 2
          }}
        >
          {dailyChallenge.prompt}
        </Text>
        <Text
          style={{
            color: theme.palette.textSecondary,
            fontSize: labelType.size,
            lineHeight: labelType.lineHeight,
            letterSpacing: labelType.letterSpacing,
            marginBottom: spacing.sm ?? 10
          }}
        >
          Progress {dailyChallenge.progress}/{dailyChallenge.total} ·{' '}
          {progressPercent}%
        </Text>
        <Text
          style={{
            color: theme.accents.blue,
            fontSize: captionType.size,
            lineHeight: captionType.lineHeight,
            letterSpacing: captionType.letterSpacing,
            fontWeight: '600'
          }}
        >
          Rewards {dailyChallenge.reward ?? 'TBD'}
        </Text>
      </View>
      <TrashButton
        title={
          dailyChallenge.state === 'completed' ? 'Completed' : 'Mark completed'
        }
        onPress={incrementDailyChallenge}
        disabled={dailyChallenge.state === 'completed'}
      />
    </ScreenShell>
  );
}
