import { router } from 'expo-router';
import { useEffect } from 'react';
import { FlatList, Pressable, Text, View } from 'react-native';

import ScreenShell from 'src/components/layout/ScreenShell';
import { TrashButton } from 'src/components/themed';
import { useArenaStore } from 'src/stores/arenaStore';

export default function DuelLobbyScreen() {
  const pendingChallenges = useArenaStore((state) => state.pendingChallenges);
  const refreshChallenges = useArenaStore((state) => state.refreshChallenges);
  const challenges = Object.values(pendingChallenges);

  useEffect(() => {
    refreshChallenges();
  }, [refreshChallenges]);

  return (
    <ScreenShell title="实时对战大厅" useScroll={false}>
      <View className="flex-row gap-3 mb-4">
        <TrashButton
          title="邀请好友"
          onPress={() => router.push('/(modals)/challenge-invite')}
          style={{ flex: 1 }}
        />
        <TrashButton
          title="刷新"
          variant="outline"
          onPress={refreshChallenges}
          style={{ flex: 1 }}
        />
      </View>

      <FlatList
        data={challenges}
        keyExtractor={(item) => item.id}
        ListEmptyComponent={() => (
          <View className="rounded-3xl border border-white/10 bg-white/5 p-5 items-center">
            <Text className="text-white/60">暂时没有待处理挑战</Text>
          </View>
        )}
        renderItem={({ item }) => (
          <Pressable
            className="rounded-3xl border border-white/10 bg-white/5 p-4 mb-3"
            onPress={() => router.push(`/(modals)/challenge-accept/${item.id}`)}
          >
            <Text className="text-white font-semibold">
              {item.opponentName ?? item.opponent ?? '未知对手'}
            </Text>
            <Text className="text-white/60 text-xs mt-1">
              状态 {item.status ?? 'pending'}
            </Text>
          </Pressable>
        )}
      />
    </ScreenShell>
  );
}
