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
  if (!duel) return '正在创建对战房间…';
  if (duel.error) return duel.error;
  if (duel.status === 'countdown') {
    return `双方已准备，${duel.countdown ?? 0}s 后开始`;
  }
  if (duel.status === 'waiting-result') {
    return '你已完成作答，等待对手提交并结算结果。';
  }
  if (duel.status === 'lobby' && duel.myReady && duel.opponentReady) {
    return '双方已准备，正在同步统一开局时间。';
  }
  if (duel.status === 'finalizing') {
    return '正在同步双方成绩并结算本场对战…';
  }
  if (duel.status === 'completed') {
    return '本场对战已结束。';
  }
  if (duel.myReady && !duel.opponentReady) {
    return '你已准备，等待对手准备。';
  }
  return '点击准备后会同步给对手，并在双方准备后自动倒计时。';
};

export default function DuelScreen() {
  const theme = useTheme();
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
    if (!duel) return '加载中…';
    if (duel.myReady && duel.opponentReady) {
      return duel.status === 'countdown'
        ? `倒计时 ${duel.countdown ?? 0}s`
        : '即将开始';
    }
    if (duel.myReady) return '等待对手准备';
    return '我已准备';
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
    <ScreenShell title="实时对战" useScroll={false}>
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
            borderRadius: 24,
            borderWidth: 1,
            borderColor: theme.tabBar.border,
            backgroundColor: theme.palette.card,
            padding: 16,
            gap: 10
          }}
        >
          <Text style={{ color: theme.palette.textSecondary, fontSize: 13 }}>
            {message}
          </Text>

          {isFinalizing ? (
            <View
              style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}
            >
              <ActivityIndicator size="small" color={theme.accents.blue} />
              <Text
                style={{ color: theme.palette.textSecondary, fontSize: 12 }}
              >
                正在请求最终结算结果
              </Text>
            </View>
          ) : null}

          {isCompleted ? (
            <View
              style={{
                borderRadius: 16,
                borderWidth: 1,
                borderColor: theme.tabBar.border,
                backgroundColor: theme.palette.background,
                padding: 12,
                gap: 4
              }}
            >
              <Text
                style={{ color: theme.palette.textPrimary, fontWeight: '700' }}
              >
                你的得分：{duel?.score ?? 0}
              </Text>
              <Text
                style={{ color: theme.palette.textSecondary, fontSize: 12 }}
              >
                对手得分：{duel?.opponentScore ?? 0}
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
          fontSize: 11,
          marginTop: 12
        }}
      >
        实时事件：player_ready / answer_submitted / player_finished / presence。
      </Text>
    </ScreenShell>
  );
}
