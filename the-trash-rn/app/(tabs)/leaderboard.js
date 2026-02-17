import { useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  Pressable,
  Text,
  View
} from 'react-native';

import ScreenShell from 'src/components/layout/ScreenShell';
import { TrashButton, TrashSegmentedControl } from 'src/components/themed';
import { useLeaderboardStore } from 'src/stores/leaderboardStore';
import { useTheme } from 'src/theme/ThemeProvider';

const FILTERS = [
  { value: 'community', label: '社群' },
  { value: 'friends', label: '好友' }
];

export default function LeaderboardScreen() {
  const [filter, setFilter] = useState('community');
  const theme = useTheme();

  const entries = useLeaderboardStore((state) => state.entries);
  const load = useLeaderboardStore((state) => state.load);
  const loading = useLeaderboardStore((state) => state.loading);
  const syncingContacts = useLeaderboardStore((state) => state.syncingContacts);
  const syncContacts = useLeaderboardStore((state) => state.syncContacts);
  const myRanking = useLeaderboardStore((state) => state.myRanking);
  const myCommunities = useLeaderboardStore((state) => state.myCommunities);
  const selectedCommunityId = useLeaderboardStore(
    (state) => state.selectedCommunityId
  );
  const setCommunity = useLeaderboardStore((state) => state.setCommunity);
  const loadMyCommunities = useLeaderboardStore(
    (state) => state.loadMyCommunities
  );
  const loadingCommunities = useLeaderboardStore(
    (state) => state.loadingCommunities
  );

  useEffect(() => {
    loadMyCommunities();
  }, [loadMyCommunities]);

  useEffect(() => {
    load(filter);
  }, [filter, load, selectedCommunityId]);

  const selectedCommunityName = useMemo(
    () =>
      myCommunities.find((item) => item.id === selectedCommunityId)?.name ??
      '未选择社群',
    [myCommunities, selectedCommunityId]
  );

  return (
    <ScreenShell title="排行榜" useScroll={false}>
      <View className="flex-row justify-between items-center mb-4">
        <TrashSegmentedControl
          options={FILTERS}
          value={filter}
          onChange={setFilter}
          style={{ marginBottom: 0, marginRight: 12, flex: 1 }}
        />
        {filter === 'friends' ? (
          <Pressable onPress={syncContacts} disabled={syncingContacts}>
            <Text style={{ color: theme.accents.blue, fontSize: 13 }}>
              {syncingContacts ? '同步中…' : '同步通讯录'}
            </Text>
          </Pressable>
        ) : null}
      </View>

      {filter === 'community' ? (
        <View
          style={{
            borderRadius: 18,
            borderWidth: 1,
            borderColor: theme.tabBar.border,
            backgroundColor: theme.palette.card,
            padding: 12,
            marginBottom: 10
          }}
        >
          <Text style={{ color: theme.palette.textSecondary, fontSize: 12 }}>
            当前社群
          </Text>
          <Text
            style={{
              color: theme.palette.textPrimary,
              fontWeight: '700',
              marginTop: 2,
              marginBottom: 8
            }}
          >
            {selectedCommunityName}
          </Text>
          {loadingCommunities ? (
            <ActivityIndicator size="small" color={theme.accents.blue} />
          ) : myCommunities.length > 0 ? (
            <FlatList
              data={myCommunities}
              horizontal
              keyExtractor={(item) => item.id}
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={{ gap: 8 }}
              renderItem={({ item }) => {
                const active = item.id === selectedCommunityId;
                return (
                  <Pressable
                    onPress={() => setCommunity(item.id)}
                    style={{
                      borderRadius: 999,
                      borderWidth: 1,
                      borderColor: active
                        ? theme.accents.green
                        : theme.tabBar.border,
                      backgroundColor: active
                        ? `${theme.accents.green}1f`
                        : theme.palette.background,
                      paddingVertical: 8,
                      paddingHorizontal: 12
                    }}
                  >
                    <Text
                      style={{
                        color: active
                          ? theme.accents.green
                          : theme.palette.textPrimary,
                        fontSize: 12,
                        fontWeight: '600'
                      }}
                    >
                      {item.name}
                    </Text>
                  </Pressable>
                );
              }}
            />
          ) : (
            <Text style={{ color: theme.palette.textSecondary, fontSize: 12 }}>
              你还没有加入任何社群，请先到社区页加入社群。
            </Text>
          )}
        </View>
      ) : null}

      <FlatList
        data={entries}
        keyExtractor={(item) => item.id}
        style={{ flex: 1 }}
        ListEmptyComponent={() => (
          <View className="items-center justify-center py-12">
            {loading ? (
              <ActivityIndicator color={theme.accents.blue} />
            ) : (
              <Text className="text-white/60">
                {filter === 'community'
                  ? '该社群暂无可显示的排名数据。'
                  : '暂无好友排名，请先同步通讯录。'}
              </Text>
            )}
          </View>
        )}
        ItemSeparatorComponent={() => <View className="h-px bg-white/10" />}
        renderItem={({ item }) => (
          <View className="py-4 flex-row items-center gap-3">
            <Text className="text-white/60 w-10 text-right">#{item.rank}</Text>
            <View className="flex-1">
              <Text className="text-white font-semibold">{item.name}</Text>
              <Text className="text-white/60 text-xs">{item.community}</Text>
            </View>
            <Text className="text-brand-amber font-semibold">{item.score}</Text>
          </View>
        )}
      />

      <View className="mt-4 rounded-3xl border border-white/20 bg-white/5 p-4">
        <Text className="text-white/60 text-xs mb-1">我的排名</Text>
        {myRanking?.rank ? (
          <View className="flex-row items-center justify-between">
            <Text className="text-white font-semibold">
              #{myRanking.rank} · {myRanking.name}
            </Text>
            <Text className="text-brand-neon font-semibold">
              {myRanking.score}
            </Text>
          </View>
        ) : (
          <Text className="text-white/70">当前榜单未上榜</Text>
        )}
      </View>

      <TrashButton
        title="刷新榜单"
        variant="ghost"
        onPress={() => load(filter)}
        style={{ marginTop: 12 }}
      />
    </ScreenShell>
  );
}
