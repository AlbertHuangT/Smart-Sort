import { useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { Pressable, ScrollView, Text } from 'react-native';
import ModalSheet from 'src/components/layout/ModalSheet';
import { useCommunityStore } from 'src/stores/communityStore';

const formatTime = (isoString) => {
  if (!isoString) return '待定时间';
  try {
    return new Date(isoString).toLocaleString('zh-CN', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false
    });
  } catch (error) {
    return isoString;
  }
};

export default function EventDetailModal() {
  const { id } = useLocalSearchParams();
  const event = useCommunityStore((state) => state.eventById(id));
  const refreshEvent = useCommunityStore((state) => state.refreshEvent);
  const rsvpEvent = useCommunityStore((state) => state.rsvpEvent);
  const [rsvping, setRsvping] = useState(false);

  useEffect(() => {
    if (id) {
      refreshEvent(id);
    }
  }, [id, refreshEvent]);

  const handleRsvp = async () => {
    if (!id) return;
    try {
      setRsvping(true);
      await rsvpEvent(id);
    } catch (error) {
      console.warn('[event] rsvp failed', error);
    } finally {
      setRsvping(false);
    }
  };

  return (
    <ModalSheet title={event?.title ?? '活动'}>
      <ScrollView contentContainerStyle={{ paddingBottom: 48 }}>
        <Text className="text-white/60 text-xs mb-2">
          {formatTime(event?.startTime)} · {event?.venue ?? '待定地点'}
        </Text>
        <Text className="text-white/70 text-sm mb-6">{event?.description}</Text>
        <Text className="text-white/60 text-xs mb-2">
          已报名 {event?.attendees ?? 0}/{event?.quota ?? 0}
        </Text>
        <Pressable
          onPress={handleRsvp}
          disabled={rsvping}
          className="bg-brand-neon rounded-3xl py-3 items-center"
        >
          <Text className="text-black font-semibold">{rsvping ? '报名中…' : '我要参加'}</Text>
        </Pressable>
      </ScrollView>
    </ModalSheet>
  );
}
