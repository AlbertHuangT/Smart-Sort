import { useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { Pressable, ScrollView, Text } from 'react-native';

import ModalSheet from 'src/components/layout/ModalSheet';
import { useCommunityStore } from 'src/stores/communityStore';
import { useLocationStore } from 'src/stores/locationStore';

export default function CommunityDetailModal() {
  const { id } = useLocalSearchParams();
  const community = useCommunityStore((state) => state.communityById(id));
  const refreshCommunity = useCommunityStore((state) => state.refreshCommunity);
  const joinCommunity = useCommunityStore((state) => state.joinCommunity);
  const cities = useLocationStore((state) => state.cities);
  const [joining, setJoining] = useState(false);

  useEffect(() => {
    if (id) {
      refreshCommunity(id);
    }
  }, [id, refreshCommunity]);

  const cityName = cities.find((city) => city.id === community?.cityId)?.name;

  const handleJoin = async () => {
    if (!id) return;
    try {
      setJoining(true);
      await joinCommunity(id);
    } catch (error) {
      console.warn('[community] join failed', error);
    } finally {
      setJoining(false);
    }
  };

  return (
    <ModalSheet title={community?.name ?? '社群详情'}>
      <ScrollView contentContainerStyle={{ paddingBottom: 48 }}>
        <Text className="text-white/60 text-xs mb-2">
          {cityName ?? '未知城市'}
        </Text>
        <Text className="text-white/70 text-sm mb-6">
          {community?.description}
        </Text>
        <Text className="text-white/60 text-xs mb-2">
          成员 {community?.memberCount ?? '--'} 人
        </Text>
        <Pressable
          onPress={handleJoin}
          disabled={joining}
          className="bg-brand-neon rounded-3xl py-3 items-center"
        >
          <Text className="text-black font-semibold">
            {joining ? '加入中…' : '加入社群'}
          </Text>
        </Pressable>
      </ScrollView>
    </ModalSheet>
  );
}
