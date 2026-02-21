import { Feather } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useEffect } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import ScreenShell from 'src/components/layout/ScreenShell';
import { TrashButton } from 'src/components/themed';
import { useAchievementStore } from 'src/stores/achievementStore';
import { useAuthStore } from 'src/stores/authStore';
import { useProfileStore } from 'src/stores/profileStore';
import { useThemeStore } from 'src/stores/themeStore';
import { useTheme } from 'src/theme/ThemeProvider';
import { THEMES } from 'src/theme/themes';

const quickLinks = [
  {
    title: 'Account Settings',
    subtitle: 'Phone, email, and password',
    href: '/(modals)/account-settings',
    icon: 'settings'
  },
  {
    title: 'Badges',
    subtitle: 'View earned badges',
    href: '/(modals)/badges',
    icon: 'award'
  },
  {
    title: 'Rewards',
    subtitle: 'Redeem available rewards',
    href: '/(modals)/rewards',
    icon: 'gift'
  }
];

export default function ProfileScreen() {
  const theme = useTheme();
  const profile = useAuthStore((state) => state.profile);
  const status = useAuthStore((state) => state.status);
  const signOut = useAuthStore((state) => state.signOut);
  const stats = useProfileStore((state) => state.stats);
  const hydrate = useProfileStore((state) => state.hydrate);
  const { themeName, cycleTheme } = useThemeStore();
  const points = useAchievementStore((state) => state.points);
  const badges = useAchievementStore((state) => state.badges);
  const unlockedBadges = badges.filter((badge) => badge.unlocked).length;
  const activeTheme = THEMES[themeName] ?? THEMES.neon;
  const metrics = [
    { label: 'Total scans', value: stats?.scans ?? 0 },
    { label: 'Arena wins', value: stats?.arenaWins ?? 0 },
    { label: 'Badges unlocked', value: unlockedBadges }
  ];

  useEffect(() => {
    hydrate();
  }, [hydrate]);

  return (
    <ScreenShell title="Profile" useScroll={false}>
      <ScrollView
        decelerationRate={theme.scroll?.decelerationRate ?? 'normal'}
        contentContainerStyle={{ paddingBottom: 48 }}
        showsVerticalScrollIndicator={false}
      >
        <View
          style={[
            styles.card,
            {
              backgroundColor: theme.palette.card,
              borderColor: theme.tabBar.border
            }
          ]}
        >
          <View style={styles.rowBetween}>
            <View style={{ flex: 1 }}>
              <Text style={[styles.name, { color: theme.palette.textPrimary }]}>
                {profile?.displayName ?? 'Guest'}
              </Text>
              <Text
                style={[styles.contact, { color: theme.palette.textSecondary }]}
              >
                {profile?.email ?? profile?.phone ?? 'No contact linked'}
              </Text>
            </View>
            <Pressable
              onPress={() => router.push('/(modals)/account-settings')}
              style={[styles.editPill, { borderColor: theme.tabBar.border }]}
            >
              <Text
                style={{
                  color: theme.palette.textSecondary,
                  fontSize: 12,
                  fontWeight: '600'
                }}
              >
                Edit
              </Text>
            </Pressable>
          </View>
          <View style={styles.badgeRow}>
            <View
              style={[
                styles.badge,
                { backgroundColor: `${theme.accents.blue}26` }
              ]}
            >
              <Text style={{ color: theme.palette.textPrimary, fontSize: 12 }}>
                Level {profile?.level ?? 1}
              </Text>
            </View>
            <View
              style={[
                styles.badge,
                { backgroundColor: `${theme.accents.green}26` }
              ]}
            >
              <Text style={{ color: theme.palette.textPrimary, fontSize: 12 }}>
                Points {points}
              </Text>
            </View>
          </View>
        </View>

        <View
          style={[
            styles.card,
            {
              backgroundColor: theme.palette.card,
              borderColor: theme.tabBar.border
            }
          ]}
        >
          <Text
            style={[styles.sectionTitle, { color: theme.palette.textPrimary }]}
          >
            My stats
          </Text>
          <View style={styles.metricsRow}>
            {metrics.map((item) => (
              <View
                key={item.label}
                style={[
                  styles.metricItem,
                  {
                    backgroundColor: theme.palette.background,
                    borderColor: theme.tabBar.border
                  }
                ]}
              >
                <Text
                  style={{
                    color: theme.palette.textPrimary,
                    fontSize: 18,
                    fontWeight: '700'
                  }}
                >
                  {item.value}
                </Text>
                <Text
                  style={{ color: theme.palette.textSecondary, fontSize: 12 }}
                >
                  {item.label}
                </Text>
              </View>
            ))}
          </View>
        </View>

        {quickLinks.map((item) => (
          <Pressable
            key={item.title}
            style={[
              styles.linkCard,
              {
                borderColor: theme.tabBar.border,
                backgroundColor: theme.palette.card
              }
            ]}
            onPress={() => router.push(item.href)}
          >
            <View style={styles.linkLeft}>
              <View
                style={[
                  styles.linkIconWrap,
                  { backgroundColor: `${theme.accents.blue}1f` }
                ]}
              >
                <Feather
                  name={item.icon}
                  size={16}
                  color={theme.accents.blue}
                />
              </View>
              <View>
                <Text
                  style={{
                    color: theme.palette.textPrimary,
                    fontWeight: '600'
                  }}
                >
                  {item.title}
                </Text>
                <Text
                  style={{ color: theme.palette.textSecondary, fontSize: 12 }}
                >
                  {item.subtitle}
                </Text>
              </View>
            </View>
            <Feather
              name="chevron-right"
              size={18}
              color={theme.palette.textSecondary}
            />
          </Pressable>
        ))}

        <Pressable
          key="theme-entry"
          style={[
            styles.linkCard,
            {
              borderColor: theme.tabBar.border,
              backgroundColor: theme.palette.card
            }
          ]}
          onPress={() => router.push('/(modals)/theme-picker')}
          onLongPress={cycleTheme}
        >
          <View style={styles.linkLeft}>
            <View
              style={[
                styles.linkIconWrap,
                { backgroundColor: `${theme.accents.green}1f` }
              ]}
            >
              <Feather name="aperture" size={16} color={theme.accents.green} />
            </View>
            <View style={{ flex: 1 }}>
              <Text
                style={{
                  color: theme.palette.textPrimary,
                  fontWeight: '600'
                }}
              >
                Theme · {activeTheme.label}
              </Text>
              <Text
                numberOfLines={1}
                style={{ color: theme.palette.textSecondary, fontSize: 12 }}
              >
                {activeTheme.description}
              </Text>
            </View>
          </View>
          <Feather
            name="chevron-right"
            size={18}
            color={theme.palette.textSecondary}
          />
        </Pressable>
        {status === 'authenticated' ? (
          <TrashButton
            title="Sign Out"
            variant="outline"
            onPress={signOut}
            style={{ marginTop: 8 }}
          />
        ) : (
          <TrashButton
            title="Go to Sign In / Sign Up"
            onPress={() => router.replace('/')}
            style={{ marginTop: 8 }}
          />
        )}
      </ScrollView>
    </ScreenShell>
  );
}

const styles = StyleSheet.create({
  card: {
    borderRadius: 26,
    borderWidth: 1,
    padding: 16,
    marginBottom: 12
  },
  rowBetween: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: 12
  },
  name: {
    fontSize: 23,
    fontWeight: '700'
  },
  contact: {
    fontSize: 12,
    marginTop: 4
  },
  editPill: {
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 8
  },
  badgeRow: {
    marginTop: 12,
    flexDirection: 'row',
    gap: 8
  },
  badge: {
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 6
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '700'
  },
  sectionHint: {
    marginTop: 4,
    fontSize: 12
  },
  themeTag: {
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 6
  },
  paletteRow: {
    marginTop: 12,
    flexDirection: 'row',
    gap: 8
  },
  colorDot: {
    width: 18,
    height: 18,
    borderRadius: 999,
    borderWidth: 1
  },
  themeActions: {
    marginTop: 14,
    flexDirection: 'row',
    gap: 8
  },
  metricsRow: {
    marginTop: 12,
    flexDirection: 'row',
    gap: 8
  },
  metricItem: {
    flex: 1,
    borderWidth: 1,
    borderRadius: 16,
    paddingVertical: 12,
    paddingHorizontal: 10
  },
  linkCard: {
    borderRadius: 20,
    borderWidth: 1,
    paddingHorizontal: 14,
    paddingVertical: 12,
    marginBottom: 10,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center'
  },
  linkLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10
  },
  linkIconWrap: {
    width: 32,
    height: 32,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center'
  }
});
