import { useLocalSearchParams, useRouter } from 'expo-router';
import { useEffect } from 'react';

import FullScreenLoader from 'src/components/shared/FullScreenLoader';
import { useArenaStore } from 'src/stores/arenaStore';

export default function ChallengeDeepLinkScreen() {
  const { id } = useLocalSearchParams();
  const challengeId = Array.isArray(id) ? id[0] : id;
  const router = useRouter();
  const acceptDeepLink = useArenaStore((state) => state.acceptDeepLink);

  useEffect(() => {
    if (challengeId) {
      acceptDeepLink(challengeId).then((target) => {
        router.replace(target ?? '/(tabs)/arena/index');
      });
    }
  }, [challengeId, router, acceptDeepLink]);

  return <FullScreenLoader message="Loading challenge" />;
}
