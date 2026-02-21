import { useRouter, useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { Pressable, Text, View } from 'react-native';

import ModalSheet from 'src/components/layout/ModalSheet';
import { useArenaStore } from 'src/stores/arenaStore';

export default function ChallengeAcceptModal() {
  const router = useRouter();
  const { id } = useLocalSearchParams();
  const challengeId = Array.isArray(id) ? id[0] : id;
  const challenge = useArenaStore(
    (state) => state.pendingChallenges[challengeId]
  );
  const refreshChallenges = useArenaStore((state) => state.refreshChallenges);
  const acceptChallenge = useArenaStore((state) => state.acceptChallenge);
  const [accepting, setAccepting] = useState(false);

  useEffect(() => {
    refreshChallenges();
  }, [refreshChallenges]);

  const handleAccept = async () => {
    if (!challengeId) return;
    try {
      setAccepting(true);
      const payload = await acceptChallenge(challengeId);
      router.replace(`/(tabs)/arena/duel/${payload?.duelId ?? challengeId}`);
    } catch (error) {
      console.warn('[arena] accept failed', error);
    } finally {
      setAccepting(false);
    }
  };

  return (
    <ModalSheet title="Accept Challenge">
      <View className="gap-4">
        <Text className="text-white/70">
          {challenge?.opponentName ?? challenge?.opponent ?? 'A friend'} has
          challenged you to a {challenge?.mode ?? 'duel'} duel.
        </Text>
        <Pressable
          className="bg-brand-neon rounded-3xl py-3 items-center"
          onPress={handleAccept}
          disabled={accepting}
        >
          <Text className="text-black font-semibold">
            {accepting ? 'Joining...' : 'Join Room'}
          </Text>
        </Pressable>
      </View>
    </ModalSheet>
  );
}
