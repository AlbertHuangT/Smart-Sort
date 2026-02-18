import { useEffect } from 'react';
import { FlatList, Text, View } from 'react-native';

import ModalSheet from 'src/components/layout/ModalSheet';
import { useArenaStore } from 'src/stores/arenaStore';

export default function ChallengeListModal() {
  const pendingChallenges = useArenaStore((state) => state.pendingChallenges);
  const refreshChallenges = useArenaStore((state) => state.refreshChallenges);
  const items = Object.values(pendingChallenges);

  useEffect(() => {
    refreshChallenges();
  }, [refreshChallenges]);

  return (
    <ModalSheet title="挑战列表">
      <FlatList
        data={items}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <View className="py-3 border-b border-white/10">
            <Text className="text-white font-semibold">
              {item.opponentName ?? item.opponent ?? '未知对手'} · {item.mode}
            </Text>
            <Text className="text-white/50 text-xs">{item.status}</Text>
          </View>
        )}
      />
    </ModalSheet>
  );
}
