import { useEffect } from 'react';
import { FlatList, Text, View } from 'react-native';

import ModalSheet from 'src/components/layout/ModalSheet';
import { useArenaStore } from 'src/stores/arenaStore';

export default function StreakLeaderboardModal() {
  const streakLeaderboard = useArenaStore((state) => state.streakLeaderboard);
  const loadLeaderboards = useArenaStore((state) => state.loadLeaderboards);

  useEffect(() => {
    loadLeaderboards();
  }, [loadLeaderboards]);

  return (
    <ModalSheet title="Streak Leaderboard">
      <FlatList
        data={streakLeaderboard}
        keyExtractor={(item) => item.id}
        renderItem={({ item, index }) => (
          <View className="flex-row items-center justify-between py-3">
            <Text className="text-white/70 w-6">#{index + 1}</Text>
            <View className="flex-1">
              <Text className="text-white font-semibold">{item.name}</Text>
              <Text className="text-white/60 text-xs">{item.community}</Text>
            </View>
            <Text className="text-brand-amber font-semibold">
              {item.streak}
            </Text>
          </View>
        )}
      />
    </ModalSheet>
  );
}
