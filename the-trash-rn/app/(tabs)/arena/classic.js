import { useEffect } from 'react';
import { Text, View } from 'react-native';

import QuizCard from 'src/components/arena/QuizCard';
import ScreenShell from 'src/components/layout/ScreenShell';
import { TrashButton } from 'src/components/themed';
import { useArenaStore } from 'src/stores/arenaStore';
import { useTheme } from 'src/theme/ThemeProvider';

export default function ClassicArenaScreen() {
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

  const classic = useArenaStore((state) => state.classic);
  const startClassic = useArenaStore((state) => state.startClassic);
  const answerClassic = useArenaStore((state) => state.answerClassic);

  useEffect(() => {
    if (classic.state === 'idle') {
      startClassic().catch(() => {});
    }
  }, [classic.state, startClassic]);

  return (
    <ScreenShell title="Classic Mode" useScroll={false}>
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
            {classic.score}
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
            Question {classic.questionIndex ?? 0}
          </Text>
          {classic.lastAnswerCorrect != null ? (
            <Text
              style={{
                color: classic.lastAnswerCorrect
                  ? theme.accents.green
                  : (theme.palette.danger ?? '#fca5a5'),
                fontSize: captionType.size,
                lineHeight: captionType.lineHeight,
                letterSpacing: captionType.letterSpacing
              }}
            >
              {classic.lastAnswerCorrect ? 'Correct +10' : 'Wrong 0 pts'}
            </Text>
          ) : null}
        </View>
      </View>
      {classic.state === 'finished' ? (
        <View
          style={{
            borderRadius: radii.card ?? 20,
            borderWidth: 1,
            borderColor: theme.tabBar.border,
            backgroundColor: theme.palette.card,
            padding: theme.components?.card?.padding ?? spacing.lg ?? 20
          }}
        >
          <Text
            style={{
              color: theme.palette.textPrimary,
              fontWeight: '700',
              fontSize: bodyType.size + 2,
              lineHeight: bodyType.lineHeight + 2,
              letterSpacing: bodyType.letterSpacing,
              marginBottom: 2
            }}
          >
            Round completed
          </Text>
          <Text
            style={{
              color: theme.palette.textSecondary,
              fontSize: labelType.size,
              lineHeight: labelType.lineHeight,
              letterSpacing: labelType.letterSpacing
            }}
          >
            Final score {classic.score}
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
        title="Load New Questions"
        onPress={startClassic}
        variant="outline"
        style={{ marginTop: spacing.lg ?? 20 }}
      />
    </ScreenShell>
  );
}
