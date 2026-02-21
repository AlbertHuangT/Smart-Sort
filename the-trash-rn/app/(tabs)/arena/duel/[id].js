import { useLocalSearchParams } from 'expo-router';
import { useEffect, useMemo } from 'react';
import { ActivityIndicator, Text, View } from 'react-native';

import ArenaHeader from 'src/components/arena/ArenaHeader';
import QuizCard from 'src/components/arena/QuizCard';
import ScreenShell from 'src/components/layout/ScreenShell';
import { TrashButton } from 'src/components/themed';
import { useArenaStore } from 'src/stores/arenaStore';
import { useTheme } from 'src/theme/ThemeProvider';

const WAITING_STATES = new Set(['loading', 'lobby', 'countdown']);

const buildStatusMessage = (duel) => {
  if (!duel) return 'Creating duel room...';
  if (duel.error) return duel.error;
  if (duel.status === 'countdown') {
    return `Both players ready. Starts in ${duel.countdown ?? 0}s.`;
  }
  if (duel.status === 'waiting-result') {
    return 'You have finished answering. Waiting for your opponent to submit for settlement.';
  }
  if (duel.status === 'lobby' && duel.myReady && duel.opponentReady) {
    return 'Both players are ready. Syncing a shared start time.';
  }
  if (duel.status === 'finalizing') {
    return 'Syncing both scores and settling this duel...';
  }
  if (duel.status === 'completed') {
    return 'This duel has finished.';
  }
  if (duel.myReady && !duel.opponentReady) {
    return 'You are ready. Waiting for your opponent to get ready.';
  }
  return 'Tap ready to sync with your opponent. Countdown starts automatically once both are ready.';
};

export default function DuelScreen() {
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

  const { id } = useLocalSearchParams();
  const duelId = Array.isArray(id) ? id[0] : id;

  const duel = useArenaStore((state) => state.duels[duelId]);
  const ensureDuel = useArenaStore((state) => state.ensureDuel);
  const startDuel = useArenaStore((state) => state.startDuel);
  const disposeDuel = useArenaStore((state) => state.disposeDuel);

  useEffect(() => {
    if (!duelId) return;
    ensureDuel(duelId);
    return () => {
      disposeDuel(duelId);
    };
  }, [duelId, disposeDuel, ensureDuel]);

  const message = useMemo(() => buildStatusMessage(duel), [duel]);
  const isWaiting = WAITING_STATES.has(duel?.status);
  const isPlaying = duel?.status === 'playing';
  const isFinalizing = duel?.status === 'finalizing';
  const isCompleted = duel?.status === 'completed';

  const actionLabel = useMemo(() => {
    if (!duel) return 'Loading...';
    if (duel.myReady && duel.opponentReady) {
      return duel.status === 'countdown'
        ? `Countdown ${duel.countdown ?? 0}s`
        : 'Starting soon';
    }
    if (duel.myReady) return 'Waiting for opponent to ready';
    return 'I am ready';
  }, [duel]);

  const myProgress = useMemo(() => {
    if (!duel) return 0;
    if (duel.hasFinished)
      return duel.totalQuestions ?? duel.questions?.length ?? 0;
    if (duel.status !== 'playing') return duel.currentIndex ?? 0;
    return Math.min(
      (duel.currentIndex ?? 0) + 1,
      duel.totalQuestions ?? duel.questions?.length ?? 0
    );
  }, [duel]);

  return (
    <ScreenShell title="Live Duel" useScroll={false}>
      <ArenaHeader
        status={duel?.status}
        opponent={duel?.opponent}
        countdown={duel?.countdown}
        myReady={duel?.myReady}
        opponentReady={duel?.opponentReady}
        opponentOnline={duel?.opponentOnline}
        myScore={duel?.score ?? 0}
        opponentScore={duel?.opponentScore ?? 0}
        myProgress={myProgress}
        opponentProgress={duel?.opponentProgress ?? 0}
        totalQuestions={duel?.totalQuestions ?? duel?.questions?.length ?? 0}
      />

      {isPlaying && duel?.currentQuestion ? (
        <QuizCard
          mode="duel"
          question={duel.currentQuestion}
          onAnswer={(option) => duel.submit(option)}
        />
      ) : (
        <View
          style={{
            borderRadius: radii.card ?? 20,
            borderWidth: 1,
            borderColor: theme.tabBar.border,
            backgroundColor: theme.palette.card,
            padding: spacing.md ?? 14,
            gap: spacing.sm ?? 10
          }}
        >
          <Text
            style={{
              color: theme.palette.textSecondary,
              fontSize: labelType.size,
              lineHeight: labelType.lineHeight,
              letterSpacing: labelType.letterSpacing
            }}
          >
            {message}
          </Text>

          {isFinalizing ? (
            <View
              style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}
            >
              <ActivityIndicator size="small" color={theme.accents.blue} />
              <Text
                style={{
                  color: theme.palette.textSecondary,
                  fontSize: captionType.size,
                  lineHeight: captionType.lineHeight,
                  letterSpacing: captionType.letterSpacing
                }}
              >
                Requesting final settlement result
              </Text>
            </View>
          ) : null}

          {isCompleted ? (
            <View
              style={{
                borderRadius: radii.input ?? 14,
                borderWidth: 1,
                borderColor: theme.tabBar.border,
                backgroundColor: theme.palette.background,
                padding: spacing.sm ?? 10,
                gap: 4
              }}
            >
              <Text
                style={{
                  color: theme.palette.textPrimary,
                  fontWeight: '700',
                  fontSize: bodyType.size,
                  lineHeight: bodyType.lineHeight,
                  letterSpacing: bodyType.letterSpacing
                }}
              >
                Your score: {duel?.score ?? 0}
              </Text>
              <Text
                style={{
                  color: theme.palette.textSecondary,
                  fontSize: captionType.size,
                  lineHeight: captionType.lineHeight,
                  letterSpacing: captionType.letterSpacing
                }}
              >
                Opponent score: {duel?.opponentScore ?? 0}
              </Text>
            </View>
          ) : null}

          {isWaiting ? (
            <TrashButton
              title={actionLabel}
              onPress={() => startDuel(duelId)}
              disabled={Boolean(
                !duel ||
                duel.status === 'loading' ||
                duel.status === 'countdown' ||
                isFinalizing ||
                isCompleted
              )}
            />
          ) : null}
        </View>
      )}

      <Text
        style={{
          color: theme.palette.textSecondary,
          fontSize: captionType.size,
          lineHeight: captionType.lineHeight,
          letterSpacing: captionType.letterSpacing,
          marginTop: spacing.sm ?? 10
        }}
      >
        Realtime events: player_ready / answer_submitted / player_finished /
        presence.
      </Text>
    </ScreenShell>
  );
}
