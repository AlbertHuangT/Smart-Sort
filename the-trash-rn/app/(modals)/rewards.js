import { useEffect } from 'react';
import { FlatList, Pressable, Text, View } from 'react-native';

import ModalSheet from 'src/components/layout/ModalSheet';
import { useAchievementStore } from 'src/stores/achievementStore';

export default function RewardsModal() {
  const rewards = useAchievementStore((state) => state.rewards);
  const redeem = useAchievementStore((state) => state.redeem);
  const load = useAchievementStore((state) => state.load);
  const points = useAchievementStore((state) => state.points);

  useEffect(() => {
    load();
  }, [load]);

  return (
    <ModalSheet title="Rewards">
      <Text className="text-white/60 text-xs mb-3">
        Current points: {points}
      </Text>
      <FlatList
        data={rewards}
        keyExtractor={(item) => item.id}
        ListEmptyComponent={() => (
          <Text className="text-white/60 text-xs">
            Point redemption is not available in this version yet.
          </Text>
        )}
        renderItem={({ item }) => {
          const disabled = item.redeemed || item.points > points;
          return (
            <View className="rounded-3xl border border-white/10 p-4 mb-3">
              <Text className="text-white font-semibold">{item.title}</Text>
              <Text className="text-white/60 text-xs mb-2">
                {item.points} pts
              </Text>
              <Pressable
                onPress={() => redeem(item.id)}
                disabled={disabled}
                className="rounded-2xl py-2 items-center"
                style={{
                  backgroundColor: disabled
                    ? 'rgba(255,255,255,0.1)'
                    : '#32f5ff'
                }}
              >
                <Text className="text-black font-semibold">
                  {item.redeemed
                    ? 'Redeemed'
                    : disabled
                      ? 'Insufficient points'
                      : 'Redeem'}
                </Text>
              </Pressable>
            </View>
          );
        }}
      />
    </ModalSheet>
  );
}
