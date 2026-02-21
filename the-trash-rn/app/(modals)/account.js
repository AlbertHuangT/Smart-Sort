import { router } from 'expo-router';
import { Pressable, ScrollView, Text, View } from 'react-native';

import ModalSheet from 'src/components/layout/ModalSheet';
import { useAchievementStore } from 'src/stores/achievementStore';
import { useAuthStore } from 'src/stores/authStore';
import { useThemeStore } from 'src/stores/themeStore';
import { THEMES } from 'src/theme/themes';

export default function AccountModal() {
  const profile = useAuthStore((state) => state.profile);
  const { themeName, cycleTheme } = useThemeStore();
  const themeLabels = Object.values(THEMES)
    .map((item) => item.label)
    .join(' / ');
  const badges = useAchievementStore((state) => state.badges);
  const equippedBadgeId = useAchievementStore((state) => state.equippedBadgeId);
  const points = useAchievementStore((state) => state.points);
  const equippedBadge = badges.find((badge) => badge.id === equippedBadgeId);

  return (
    <ModalSheet title="Account">
      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingBottom: 80 }}
      >
        <View className="bg-white/5 rounded-3xl border border-white/10 p-4 mb-4">
          <Text className="text-white text-xl font-semibold">
            {profile?.displayName ?? 'Guest'}
          </Text>
          <Text className="text-white/70 text-sm">
            Level {profile?.level ?? 1}
          </Text>
          <Text className="text-white/70 text-xs mt-1">
            Badge: {equippedBadge?.title ?? 'None'} · Points {points}
          </Text>
        </View>
        <Pressable
          onPress={() => router.push('/(modals)/account-settings')}
          className="rounded-3xl border border-white/10 p-4 mb-3"
        >
          <Text className="text-white font-semibold">Account Settings</Text>
          <Text className="text-white/60 text-xs">
            Sign-in, privacy, security
          </Text>
        </Pressable>
        <Pressable
          onPress={() => router.push('/(modals)/theme-picker')}
          className="rounded-3xl border border-white/10 p-4 mb-3"
        >
          <Text className="text-white font-semibold">Theme · {themeName}</Text>
          <Text className="text-white/60 text-xs">{themeLabels}</Text>
        </Pressable>
        <Pressable
          onPress={() => router.push('/(modals)/badges')}
          className="rounded-3xl border border-white/10 p-4 mb-3"
        >
          <Text className="text-white font-semibold">
            Achievements & Badges
          </Text>
          <Text className="text-white/60 text-xs">
            View and equip unlocked badges
          </Text>
        </Pressable>
        <Pressable
          onPress={() => router.push('/(modals)/rewards')}
          className="rounded-3xl border border-white/10 p-4 mb-3"
        >
          <Text className="text-white font-semibold">Rewards</Text>
          <Text className="text-white/60 text-xs">
            Redeem gifts with points
          </Text>
        </Pressable>
        <Pressable
          onPress={cycleTheme}
          className="rounded-3xl bg-white/5 p-4 mb-6"
        >
          <Text className="text-brand-neon font-semibold">
            Randomly switch theme
          </Text>
        </Pressable>
      </ScrollView>
    </ModalSheet>
  );
}
