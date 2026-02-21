import { router } from 'expo-router';
import { useEffect } from 'react';
import { FlatList, Pressable, Text, View } from 'react-native';

import ScreenShell from 'src/components/layout/ScreenShell';
import { TrashButton } from 'src/components/themed';
import { useArenaStore } from 'src/stores/arenaStore';
import { useTheme } from 'src/theme/ThemeProvider';

export default function DuelLobbyScreen() {
  const theme = useTheme();
  const spacing = theme.spacing ?? {};
  const radii = theme.radii ?? {};
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

  const pendingChallenges = useArenaStore((state) => state.pendingChallenges);
  const refreshChallenges = useArenaStore((state) => state.refreshChallenges);
  const challenges = Object.values(pendingChallenges);

  useEffect(() => {
    refreshChallenges();
  }, [refreshChallenges]);

  return (
    <ScreenShell title="Live Duel Lobby" useScroll={false}>
      <View
        style={{
          flexDirection: 'row',
          gap: spacing.sm ?? 10,
          marginBottom: spacing.md ?? 14
        }}
      >
        <TrashButton
          title="Invite Friends"
          onPress={() => router.push('/(modals)/challenge-invite')}
          style={{ flex: 1 }}
        />
        <TrashButton
          title="Refresh"
          variant="outline"
          onPress={refreshChallenges}
          style={{ flex: 1 }}
        />
      </View>

      <FlatList
        data={challenges}
        keyExtractor={(item) => item.id}
        contentContainerStyle={{ paddingBottom: spacing.xxl ?? 36 }}
        ListEmptyComponent={() => (
          <View
            style={{
              borderRadius: radii.card ?? 20,
              borderWidth: 1,
              borderColor: theme.tabBar.border,
              backgroundColor: theme.palette.card,
              paddingHorizontal: spacing.lg ?? 20,
              paddingVertical: spacing.lg ?? 20,
              alignItems: 'center'
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
              No pending challenges right now
            </Text>
          </View>
        )}
        renderItem={({ item }) => (
          <Pressable
            style={{
              borderRadius: radii.card ?? 20,
              borderWidth: 1,
              borderColor: theme.tabBar.border,
              backgroundColor: theme.palette.card,
              paddingHorizontal: spacing.md ?? 14,
              paddingVertical: spacing.md ?? 14,
              marginBottom: spacing.sm ?? 10
            }}
            onPress={() => router.push(`/(modals)/challenge-accept/${item.id}`)}
          >
            <Text
              style={{
                color: theme.palette.textPrimary,
                fontWeight: '700',
                fontSize: labelType.size,
                lineHeight: labelType.lineHeight,
                letterSpacing: labelType.letterSpacing
              }}
            >
              {item.opponentName ?? item.opponent ?? 'Unknown opponent'}
            </Text>
            <Text
              style={{
                color: theme.palette.textSecondary,
                fontSize: captionType.size,
                lineHeight: captionType.lineHeight,
                letterSpacing: captionType.letterSpacing,
                marginTop: 2
              }}
            >
              Status {item.status ?? 'pending'}
            </Text>
          </Pressable>
        )}
      />
    </ScreenShell>
  );
}
