import { FlatList, Text, View } from 'react-native';

import ModalSheet from 'src/components/layout/ModalSheet';
import { useAchievementStore } from 'src/stores/achievementStore';
import { useTrashStore } from 'src/stores/trashStore';

export default function HistoryModal() {
  const history = useTrashStore((state) => state.history);
  const achievementHistory = useAchievementStore((state) => state.history);

  return (
    <ModalSheet title="历史记录">
      <Text className="text-white/60 text-xs mb-2">分类历史</Text>
      <FlatList
        data={history}
        keyExtractor={(item) => item.id}
        style={{ maxHeight: 240 }}
        renderItem={({ item }) => (
          <View className="py-3 border-b border-white/10">
            <Text className="text-white font-semibold">{item.item}</Text>
            <Text className="text-white/50 text-xs">
              {item.category} · {item.timestamp}
            </Text>
          </View>
        )}
        ListEmptyComponent={() => (
          <Text className="text-white/40 text-xs py-6">暂无扫描记录</Text>
        )}
      />
      <View className="mt-6">
        <Text className="text-white/60 text-xs mb-2">成就解锁</Text>
        {achievementHistory.length === 0 ? (
          <Text className="text-white/40 text-xs">暂未解锁成就</Text>
        ) : (
          achievementHistory.slice(0, 5).map((entry) => (
            <View key={entry.id} className="py-2 border-b border-white/10">
              <Text className="text-white font-semibold text-sm">
                {entry.title}
              </Text>
              {entry.description ? (
                <Text className="text-white/50 text-xs mb-1">
                  {entry.description}
                </Text>
              ) : null}
              <Text className="text-white/60 text-xs">{entry.timestamp}</Text>
            </View>
          ))
        )}
      </View>
    </ModalSheet>
  );
}
