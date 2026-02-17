import { useEffect } from 'react';
import { FlatList, Pressable, Text, View } from 'react-native';
import ModalSheet from 'src/components/layout/ModalSheet';
import { useAchievementStore } from 'src/stores/achievementStore';

export default function BadgesModal() {
  const badges = useAchievementStore((state) => state.badges);
  const load = useAchievementStore((state) => state.load);
  const equipBadge = useAchievementStore((state) => state.equipBadge);
  const equippedBadgeId = useAchievementStore((state) => state.equippedBadgeId);

  useEffect(() => {
    load();
  }, [load]);

  const unlockedCount = badges.filter((badge) => badge.unlocked).length;

  return (
    <ModalSheet title="成就">
      <Text className="text-white/60 text-xs mb-3">
        已解锁 {unlockedCount}/{badges.length}
      </Text>
      <FlatList
        data={badges}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <Pressable
            className="flex-row items-center gap-4 py-3"
            onPress={() => equipBadge(item.id)}
            disabled={!item.unlocked}
            style={{ opacity: item.unlocked ? 1 : 0.4 }}
          >
            <View className="w-12 h-12 rounded-full bg-white/10 items-center justify-center">
              <Text className="text-brand-neon font-display text-lg">{item.icon ?? '✨'}</Text>
            </View>
            <View className="flex-1">
              <Text className="text-white font-semibold">{item.title}</Text>
              <Text className="text-white/60 text-xs">{item.description}</Text>
            </View>
            {item.unlocked ? (
              <Text className="text-brand-neon text-xs">
                {equippedBadgeId === item.id ? '佩戴中' : '点击佩戴'}
              </Text>
            ) : (
              <Text className="text-white/40 text-xs">待解锁</Text>
            )}
          </Pressable>
        )}
      />
    </ModalSheet>
  );
}
