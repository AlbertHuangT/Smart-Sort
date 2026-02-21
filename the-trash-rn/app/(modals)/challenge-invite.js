import { useEffect } from 'react';
import { FlatList, Pressable, Text, View } from 'react-native';

import ModalSheet from 'src/components/layout/ModalSheet';
import { useArenaStore } from 'src/stores/arenaStore';

export default function ChallengeInviteModal() {
  const friends = useArenaStore((state) => state.friends);
  const loadFriends = useArenaStore((state) => state.loadFriends);
  const sendInvite = useArenaStore((state) => state.sendInvite);

  useEffect(() => {
    loadFriends();
  }, [loadFriends]);

  return (
    <ModalSheet title="Invite Challenge">
      <FlatList
        data={friends}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <View className="flex-row items-center justify-between py-3">
            <View>
              <Text className="text-white font-semibold">{item.name}</Text>
              <Text className="text-white/60 text-xs">
                Recent score {item.score ?? 0}
              </Text>
            </View>
            <Pressable
              onPress={() => sendInvite(item.id)}
              className="px-4 py-2 rounded-2xl bg-brand-neon"
            >
              <Text className="text-black font-semibold">Invite</Text>
            </Pressable>
          </View>
        )}
      />
    </ModalSheet>
  );
}
