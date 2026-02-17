import { router } from 'expo-router';
import { useEffect, useMemo } from 'react';
import { FlatList, Pressable, Text, View } from 'react-native';

import ScreenShell from 'src/components/layout/ScreenShell';
import { ARENA_MODES } from 'src/constants/arena';
import { useArenaStore } from 'src/stores/arenaStore';
import { useTheme } from 'src/theme/ThemeProvider';

export default function ArenaHubScreen() {
  const theme = useTheme();
  const spacing = theme.spacing ?? {};
  const radii = theme.radii ?? {};
  const bodyType = theme.typography?.body ?? {
    size: 16,
    lineHeight: 25,
    letterSpacing: 0.14
  };
  const labelType = theme.typography?.label ?? {
    size: 14,
    lineHeight: 20,
    letterSpacing: 0.22
  };
  const captionType = theme.typography?.caption ?? {
    size: 13,
    lineHeight: 19,
    letterSpacing: 0.2
  };

  const refreshChallenges = useArenaStore((state) => state.refreshChallenges);
  const loadDailyChallenge = useArenaStore((state) => state.loadDailyChallenge);
  const dailyChallenge = useArenaStore((state) => state.dailyChallenge);
  const pendingChallenges = useArenaStore((state) => state.pendingChallenges);
  const streak = useArenaStore((state) => state.streak);

  useEffect(() => {
    refreshChallenges();
    loadDailyChallenge();
  }, [refreshChallenges, loadDailyChallenge]);

  const badges = useMemo(
    () => ({
      daily: `${dailyChallenge.progress}/${dailyChallenge.total}`,
      duel: `${Object.keys(pendingChallenges).length} 待处理`,
      streak: `最佳 ${streak.best}`
    }),
    [dailyChallenge, pendingChallenges, streak]
  );

  return (
    <ScreenShell title="竞技场" useScroll={false}>
      <View
        style={{
          borderRadius: radii.card ?? 24,
          backgroundColor: theme.palette.elevated,
          paddingHorizontal: spacing.lg ?? 24,
          paddingVertical: spacing.md ?? 16,
          marginBottom: spacing.sectionGap ?? 48
        }}
      >
        <Text
          style={{
            color: theme.palette.textTertiary ?? theme.palette.textSecondary,
            fontSize: captionType.size,
            lineHeight: captionType.lineHeight,
            letterSpacing: captionType.letterSpacing
          }}
        >
          当前进度
        </Text>

        <View
          style={{
            marginTop: spacing.sm ?? 12,
            flexDirection: 'row',
            justifyContent: 'space-between',
            alignItems: 'center'
          }}
        >
          <View>
            <Text
              style={{
                color: theme.palette.textPrimary,
                fontSize: bodyType.size + 2,
                lineHeight: bodyType.lineHeight + 2,
                letterSpacing: bodyType.letterSpacing,
                fontWeight: '700'
              }}
            >
              每日挑战 {badges.daily}
            </Text>
            <Text
              style={{
                color: theme.palette.textSecondary,
                fontSize: labelType.size,
                lineHeight: labelType.lineHeight,
                letterSpacing: labelType.letterSpacing,
                marginTop: 2
              }}
            >
              实时对战 {badges.duel} · 连胜 {badges.streak}
            </Text>
          </View>
        </View>
      </View>

      <FlatList
        data={ARENA_MODES}
        keyExtractor={(item) => item.key}
        style={{ flex: 1 }}
        numColumns={2}
        contentContainerStyle={{
          paddingBottom: spacing.xxxl ?? 48
        }}
        columnWrapperStyle={{ marginBottom: spacing.md ?? 16 }}
        renderItem={({ item, index }) => {
          const isRightColumn = index % 2 === 1;
          return (
            <Pressable
              style={{
                flex: 1,
                borderRadius: radii.card ?? 24,
                backgroundColor: theme.palette.elevated,
                paddingHorizontal: spacing.md ?? 16,
                paddingVertical: spacing.md ?? 16,
                marginLeft: isRightColumn ? (spacing.sm ?? 12) : 0,
                minHeight: 132
              }}
              onPress={() => router.push(item.href)}
            >
              <View
                style={{
                  flexDirection: 'row',
                  justifyContent: 'space-between',
                  alignItems: 'flex-start',
                  marginBottom: spacing.xs ?? 8
                }}
              >
                <Text
                  style={{
                    color: theme.palette.textPrimary,
                    fontWeight: '700',
                    fontSize: bodyType.size + 1,
                    lineHeight: bodyType.lineHeight,
                    letterSpacing: bodyType.letterSpacing,
                    flex: 1,
                    marginRight: spacing.xs ?? 8
                  }}
                >
                  {item.title}
                </Text>
                {badges[item.key] ? (
                  <Text
                    style={{
                      color: theme.accents.blue,
                      fontSize: captionType.size,
                      lineHeight: captionType.lineHeight,
                      letterSpacing: captionType.letterSpacing,
                      fontWeight: '600'
                    }}
                  >
                    {badges[item.key]}
                  </Text>
                ) : null}
              </View>

              <Text
                style={{
                  color: theme.palette.textSecondary,
                  fontSize: labelType.size,
                  lineHeight: labelType.lineHeight,
                  letterSpacing: labelType.letterSpacing
                }}
              >
                {item.description}
              </Text>
            </Pressable>
          );
        }}
      />
    </ScreenShell>
  );
}
