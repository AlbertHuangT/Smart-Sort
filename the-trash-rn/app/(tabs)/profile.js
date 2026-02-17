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
    title: '账户设置',
    subtitle: '手机号、邮箱、密码',
    href: '/(modals)/account-settings',
    icon: 'settings'
  },
  {
    title: '成就徽章',
    subtitle: '查看已获得的徽章',
    href: '/(modals)/badges',
    icon: 'award'
  },
  {
    title: '积分奖励',
    subtitle: '兑换可用奖励',
    href: '/(modals)/rewards',
    icon: 'gift'
  },
  {
    title: '历史记录',
    subtitle: '识别与挑战记录',
    href: '/(modals)/history',
    icon: 'clock'
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
    { label: '累计识别', value: stats?.scans ?? 0 },
    { label: '竞技场胜场', value: stats?.arenaWins ?? 0 },
    { label: '已解锁徽章', value: unlockedBadges }
  ];

  useEffect(() => {
    hydrate();
  }, [hydrate]);

  return (
    <ScreenShell title="个人主页" useScroll={false}>
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
                {profile?.displayName ?? '游客'}
              </Text>
              <Text
                style={[styles.contact, { color: theme.palette.textSecondary }]}
              >
                {profile?.email ?? profile?.phone ?? '未绑定联系方式'}
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
                编辑
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
                等级 {profile?.level ?? 1}
              </Text>
            </View>
            <View
              style={[
                styles.badge,
                { backgroundColor: `${theme.accents.green}26` }
              ]}
            >
              <Text style={{ color: theme.palette.textPrimary, fontSize: 12 }}>
                积分 {points}
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
          <View style={styles.rowBetween}>
            <View style={{ flex: 1 }}>
              <Text
                style={[
                  styles.sectionTitle,
                  { color: theme.palette.textPrimary }
                ]}
              >
                主题外观
              </Text>
              <Text
                style={[
                  styles.sectionHint,
                  { color: theme.palette.textSecondary }
                ]}
              >
                {activeTheme.description}
              </Text>
            </View>
            <View
              style={[styles.themeTag, { borderColor: theme.accents.green }]}
            >
              <Text
                style={{
                  color: theme.accents.green,
                  fontSize: 12,
                  fontWeight: '700'
                }}
              >
                {activeTheme.label}
              </Text>
            </View>
          </View>
          <View style={styles.paletteRow}>
            {[
              activeTheme.accents.blue,
              activeTheme.accents.green,
              activeTheme.accents.orange
            ].map((color) => (
              <View
                key={color}
                style={[
                  styles.colorDot,
                  { backgroundColor: color, borderColor: theme.tabBar.border }
                ]}
              />
            ))}
          </View>
          <View style={styles.themeActions}>
            <TrashButton
              title="切换下一个"
              variant="secondary"
              onPress={cycleTheme}
              style={{ flex: 1 }}
            />
            <TrashButton
              title="更多主题"
              variant="outline"
              onPress={() => router.push('/(modals)/theme-picker')}
              style={{ flex: 1 }}
            />
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
            我的数据
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
        {status === 'authenticated' ? (
          <TrashButton
            title="退出登录"
            variant="outline"
            onPress={signOut}
            style={{ marginTop: 8 }}
          />
        ) : (
          <TrashButton
            title="去登录/注册"
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
