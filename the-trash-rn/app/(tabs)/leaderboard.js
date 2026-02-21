import { useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  FlatList,
  Pressable,
  Text,
  View
} from 'react-native';

import ScreenShell from 'src/components/layout/ScreenShell';
import { TrashButton, TrashSegmentedControl } from 'src/components/themed';
import { leaderboardPrivacy } from 'src/services/leaderboard';
import { useLeaderboardStore } from 'src/stores/leaderboardStore';
import { useTheme } from 'src/theme/ThemeProvider';

const FILTERS = [
  { value: 'community', label: 'Community' },
  { value: 'friends', label: 'Friends' }
];

export default function LeaderboardScreen() {
  const [filter, setFilter] = useState('community');
  const theme = useTheme();
  const spacing = theme.spacing ?? {};
  const radii = theme.radii ?? {};
  const bodyType = theme.typography?.body ?? {
    size: 15,
    lineHeight: 22,
    letterSpacing: 0.12
  };
  const labelType = theme.typography?.label ?? {
    size: 14,
    lineHeight: 19,
    letterSpacing: 0.18
  };
  const captionType = theme.typography?.caption ?? {
    size: 12,
    lineHeight: 17,
    letterSpacing: 0.14
  };

  const entries = useLeaderboardStore((state) => state.entries);
  const load = useLeaderboardStore((state) => state.load);
  const loading = useLeaderboardStore((state) => state.loading);
  const error = useLeaderboardStore((state) => state.error);
  const syncingContacts = useLeaderboardStore((state) => state.syncingContacts);
  const syncContacts = useLeaderboardStore((state) => state.syncContacts);
  const contactsSyncOptIn = useLeaderboardStore(
    (state) => state.contactsSyncOptIn
  );
  const setContactsSyncOptIn = useLeaderboardStore(
    (state) => state.setContactsSyncOptIn
  );
  const contactsLastSyncedAt = useLeaderboardStore(
    (state) => state.contactsLastSyncedAt
  );
  const contactsLastSyncStats = useLeaderboardStore(
    (state) => state.contactsLastSyncStats
  );
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

  const handleContactsSync = () => {
    if (contactsSyncOptIn) {
      syncContacts();
      return;
    }

    Alert.alert(
      '启用好友榜同步',
      `将读取通讯录中的邮箱和手机号做匹配，不上传姓名。每次最多上传 ${leaderboardPrivacy.maxEmailsPerSync} 个邮箱和 ${leaderboardPrivacy.maxPhonesPerSync} 个手机号。`,
      [
        { text: '取消', style: 'cancel' },
        {
          text: '同意并同步',
          onPress: async () => {
            setContactsSyncOptIn(true);
            await syncContacts({ allowPermissionPrompt: true });
          }
        }
      ]
    );
  };

  const sectionCardStyle = {
    borderRadius: radii.card ?? 20,
    borderWidth: 1,
    borderColor: theme.tabBar.border,
    backgroundColor: theme.palette.card,
    paddingHorizontal: spacing.md ?? 14,
    paddingVertical: spacing.sm ?? 10,
    marginBottom: spacing.sm ?? 10
  };

  return (
    <ScreenShell title="排行榜" useScroll={false}>
      <TrashSegmentedControl
        options={FILTERS}
        value={filter}
        onChange={setFilter}
        style={{
          width: '100%',
          marginBottom: filter === 'friends' ? (spacing.xs ?? 6) : 0
        }}
        optionStyle={{ minHeight: 48 }}
      />
      {filter === 'friends' ? (
        <View
          style={{
            alignItems: 'flex-end',
            marginBottom: spacing.md ?? 14
          }}
        >
          <Pressable onPress={handleContactsSync} disabled={syncingContacts}>
            <Text
              style={{
                color: theme.accents.blue,
                fontSize: labelType.size,
                lineHeight: labelType.lineHeight,
                letterSpacing: labelType.letterSpacing,
                fontWeight: '600'
              }}
            >
              {syncingContacts
                ? '同步中…'
                : contactsSyncOptIn
                  ? '重新同步'
                  : '启用通讯录好友榜'}
            </Text>
          </Pressable>
        </View>
      ) : null}

      {filter === 'friends' && !contactsSyncOptIn ? (
        <View style={sectionCardStyle}>
          <Text
            style={{
              color: theme.palette.textPrimary,
              fontWeight: '700',
              fontSize: labelType.size,
              lineHeight: labelType.lineHeight,
              letterSpacing: labelType.letterSpacing
            }}
          >
            好友榜需要通讯录授权
          </Text>
          <Text
            style={{
              color: theme.palette.textSecondary,
              fontSize: captionType.size,
              lineHeight: captionType.lineHeight,
              letterSpacing: captionType.letterSpacing,
              marginTop: spacing.xs ?? 6
            }}
          >
            仅上传去重后的邮箱和手机号，不上传联系人姓名。你可随时关闭授权。
          </Text>
          <TrashButton
            title="同意并同步"
            variant="outline"
            onPress={handleContactsSync}
            style={{ marginTop: spacing.sm ?? 10 }}
          />
        </View>
      ) : null}

      {filter === 'friends' && contactsSyncOptIn && contactsLastSyncedAt ? (
        <View style={sectionCardStyle}>
          <Text
            style={{
              color: theme.palette.textSecondary,
              fontSize: captionType.size,
              lineHeight: captionType.lineHeight,
              letterSpacing: captionType.letterSpacing
            }}
          >
            上次同步：{new Date(contactsLastSyncedAt).toLocaleString()}
          </Text>
          {contactsLastSyncStats ? (
            <Text
              style={{
                color: theme.palette.textSecondary,
                fontSize: captionType.size,
                lineHeight: captionType.lineHeight,
                letterSpacing: captionType.letterSpacing,
                marginTop: 2
              }}
            >
              上传标识：邮箱 {contactsLastSyncStats.emailCount} / 手机号{' '}
              {contactsLastSyncStats.phoneCount}
            </Text>
          ) : null}
        </View>
      ) : null}

      {filter === 'community' ? (
        <View style={sectionCardStyle}>
          <Text
            style={{
              color: theme.palette.textSecondary,
              fontSize: captionType.size,
              lineHeight: captionType.lineHeight,
              letterSpacing: captionType.letterSpacing
            }}
          >
            当前社群
          </Text>
          <Text
            style={{
              color: theme.palette.textPrimary,
              fontWeight: '700',
              marginTop: 2,
              marginBottom: spacing.xs ?? 6,
              fontSize: bodyType.size,
              lineHeight: bodyType.lineHeight,
              letterSpacing: bodyType.letterSpacing
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
              contentContainerStyle={{ gap: spacing.xs ?? 6 }}
              renderItem={({ item }) => {
                const active = item.id === selectedCommunityId;
                return (
                  <Pressable
                    onPress={() => setCommunity(item.id)}
                    style={{
                      borderRadius: radii.pill ?? 999,
                      borderWidth: 1,
                      borderColor: active
                        ? theme.accents.green
                        : theme.tabBar.border,
                      backgroundColor: active
                        ? `${theme.accents.green}1f`
                        : theme.palette.background,
                      paddingVertical: spacing.xs ?? 6,
                      paddingHorizontal: spacing.sm ?? 10
                    }}
                  >
                    <Text
                      style={{
                        color: active
                          ? theme.accents.green
                          : theme.palette.textPrimary,
                        fontSize: captionType.size,
                        lineHeight: captionType.lineHeight,
                        letterSpacing: captionType.letterSpacing,
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
            <Text
              style={{
                color: theme.palette.textSecondary,
                fontSize: captionType.size,
                lineHeight: captionType.lineHeight,
                letterSpacing: captionType.letterSpacing
              }}
            >
              你还没有加入任何社群，请先到社区页加入社群。
            </Text>
          )}
        </View>
      ) : null}

      {error ? (
        <View
          style={{
            borderRadius: radii.input ?? 14,
            borderWidth: 1,
            borderColor: theme.palette.danger ?? '#f87171',
            backgroundColor: 'rgba(248,113,113,0.12)',
            paddingHorizontal: spacing.md ?? 14,
            paddingVertical: spacing.sm ?? 10,
            marginBottom: spacing.sm ?? 10
          }}
        >
          <Text
            style={{
              color: theme.palette.danger ?? '#fca5a5',
              fontSize: captionType.size,
              lineHeight: captionType.lineHeight,
              letterSpacing: captionType.letterSpacing
            }}
          >
            {error}
          </Text>
        </View>
      ) : null}

      <FlatList
        data={entries}
        keyExtractor={(item) => item.id}
        style={{ flex: 1 }}
        contentContainerStyle={{ paddingBottom: spacing.xxl ?? 36 }}
        ListEmptyComponent={() => (
          <View
            style={{
              alignItems: 'center',
              justifyContent: 'center',
              paddingVertical: spacing.xxxl ?? 44
            }}
          >
            {loading ? (
              <ActivityIndicator color={theme.accents.blue} />
            ) : (
              <Text
                style={{
                  color: theme.palette.textSecondary,
                  fontSize: labelType.size,
                  lineHeight: labelType.lineHeight,
                  letterSpacing: labelType.letterSpacing,
                  textAlign: 'center'
                }}
              >
                {filter === 'community'
                  ? '该社群暂无可显示的排名数据。'
                  : contactsSyncOptIn
                    ? '暂无好友排名，试试重新同步通讯录。'
                    : '请先开启通讯录好友榜。'}
              </Text>
            )}
          </View>
        )}
        ItemSeparatorComponent={() => (
          <View
            style={{
              height: 1,
              backgroundColor: theme.tabBar.border
            }}
          />
        )}
        renderItem={({ item }) => (
          <View
            style={{
              paddingVertical: spacing.md ?? 14,
              flexDirection: 'row',
              alignItems: 'center'
            }}
          >
            <Text
              style={{
                color: theme.palette.textSecondary,
                width: 36,
                textAlign: 'right',
                fontSize: labelType.size,
                lineHeight: labelType.lineHeight,
                letterSpacing: labelType.letterSpacing
              }}
            >
              #{item.rank}
            </Text>
            <View style={{ flex: 1, marginLeft: spacing.sm ?? 10 }}>
              <Text
                style={{
                  color: theme.palette.textPrimary,
                  fontWeight: '600',
                  fontSize: bodyType.size,
                  lineHeight: bodyType.lineHeight,
                  letterSpacing: bodyType.letterSpacing
                }}
              >
                {item.name}
              </Text>
              <Text
                style={{
                  color: theme.palette.textSecondary,
                  fontSize: captionType.size,
                  lineHeight: captionType.lineHeight,
                  letterSpacing: captionType.letterSpacing
                }}
              >
                {item.community}
              </Text>
            </View>
            <Text
              style={{
                color: theme.accents.orange,
                fontWeight: '700',
                fontSize: bodyType.size,
                lineHeight: bodyType.lineHeight,
                letterSpacing: bodyType.letterSpacing
              }}
            >
              {item.score}
            </Text>
          </View>
        )}
      />

      <View
        style={[
          sectionCardStyle,
          {
            marginTop: spacing.sm ?? 10
          }
        ]}
      >
        <Text
          style={{
            color: theme.palette.textSecondary,
            fontSize: captionType.size,
            lineHeight: captionType.lineHeight,
            letterSpacing: captionType.letterSpacing,
            marginBottom: 2
          }}
        >
          我的排名
        </Text>
        {myRanking?.rank ? (
          <View
            style={{
              flexDirection: 'row',
              alignItems: 'center',
              justifyContent: 'space-between'
            }}
          >
            <Text
              style={{
                color: theme.palette.textPrimary,
                fontWeight: '600',
                fontSize: labelType.size,
                lineHeight: labelType.lineHeight,
                letterSpacing: labelType.letterSpacing
              }}
            >
              #{myRanking.rank} · {myRanking.name}
            </Text>
            <Text
              style={{
                color: theme.accents.blue,
                fontWeight: '700',
                fontSize: bodyType.size,
                lineHeight: bodyType.lineHeight,
                letterSpacing: bodyType.letterSpacing
              }}
            >
              {myRanking.score}
            </Text>
          </View>
        ) : (
          <Text
            style={{
              color: theme.palette.textSecondary,
              fontSize: labelType.size,
              lineHeight: labelType.lineHeight,
              letterSpacing: labelType.letterSpacing
            }}
          >
            当前榜单未上榜
          </Text>
        )}
      </View>

      <TrashButton
        title="刷新榜单"
        variant="ghost"
        onPress={() => load(filter)}
        style={{ marginTop: spacing.sm ?? 10 }}
      />
    </ScreenShell>
  );
}
