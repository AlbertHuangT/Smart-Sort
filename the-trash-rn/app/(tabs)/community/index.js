import { Feather } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  Pressable,
  RefreshControl,
  Text,
  View
} from 'react-native';
import MapView, { Marker } from 'react-native-maps';

import ScreenShell from 'src/components/layout/ScreenShell';
import { TrashButton, TrashSegmentedControl } from 'src/components/themed';
import { useCommunityStore } from 'src/stores/communityStore';
import { useLocationStore } from 'src/stores/locationStore';
import { useTheme } from 'src/theme/ThemeProvider';

const VIEW_OPTIONS = [
  { value: 'list', label: '列表' },
  { value: 'map', label: '地图' }
];

const SECTION_OPTIONS = [
  { value: 'events', label: '活动' },
  { value: 'groups', label: '社群' }
];

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
  } catch {
    return isoString;
  }
};

export default function CommunityScreen() {
  const theme = useTheme();
  const [section, setSection] = useState('events');
  const [viewMode, setViewMode] = useState('list');
  const [autoLocateRequested, setAutoLocateRequested] = useState(false);

  const spacing = theme.spacing ?? {};
  const radii = theme.radii ?? {};
  const bodyType = theme.typography?.body ?? {
    size: 16,
    lineHeight: 25,
    letterSpacing: 0.14
  };
  const labelType = theme.typography?.label ?? {
    size: 14,
    lineHeight: 20,
    letterSpacing: 0.22
  };
  const captionType = theme.typography?.caption ?? {
    size: 13,
    lineHeight: 19,
    letterSpacing: 0.2
  };

  const events = useCommunityStore((state) => state.events);
  const eventsLoading = useCommunityStore((state) => state.eventsLoading);
  const loadEvents = useCommunityStore((state) => state.loadEvents);
  const groups = useCommunityStore((state) => state.groups);
  const groupsLoading = useCommunityStore((state) => state.groupsLoading);
  const loadGroups = useCommunityStore((state) => state.loadGroups);

  const cities = useLocationStore((state) => state.cities);
  const currentCity = useLocationStore((state) => state.currentCity);
  const loadCities = useLocationStore((state) => state.loadCities);
  const checkPermission = useLocationStore((state) => state.checkPermission);
  const permissionStatus = useLocationStore((state) => state.permissionStatus);
  const locationError = useLocationStore((state) => state.error);
  const requestCurrentLocation = useLocationStore(
    (state) => state.requestCurrentLocation
  );
  const locating = useLocationStore((state) => state.locating);

  useEffect(() => {
    loadCities();
    checkPermission();
  }, [checkPermission, loadCities]);

  useEffect(() => {
    if (!currentCity) return;
    loadEvents(currentCity);
    loadGroups(currentCity);
  }, [currentCity, loadEvents, loadGroups]);

  useEffect(() => {
    if (autoLocateRequested || currentCity) return;
    if (permissionStatus === 'undetermined') {
      setAutoLocateRequested(true);
      requestCurrentLocation().catch(() => {
        // User can still use manual city selection.
      });
    }
  }, [
    autoLocateRequested,
    currentCity,
    permissionStatus,
    requestCurrentLocation
  ]);

  const region = useMemo(() => {
    if (events.length > 0) {
      return {
        latitude: events[0].latitude ?? currentCity?.latitude ?? 31.23,
        longitude: events[0].longitude ?? currentCity?.longitude ?? 121.47,
        latitudeDelta: 0.05,
        longitudeDelta: 0.05
      };
    }
    if (currentCity?.latitude && currentCity?.longitude) {
      return {
        latitude: currentCity.latitude,
        longitude: currentCity.longitude,
        latitudeDelta: 0.1,
        longitudeDelta: 0.1
      };
    }
    return null;
  }, [events, currentCity]);

  const handleRefresh = () => {
    if (!currentCity) return;
    if (section === 'events') {
      loadEvents(currentCity);
      return;
    }
    loadGroups(currentCity);
  };

  const renderEmptyState = (loading, message) => (
    <View
      style={{
        paddingVertical: spacing.xxxl ?? 48,
        alignItems: 'center',
        justifyContent: 'center'
      }}
    >
      {loading ? (
        <ActivityIndicator color={theme.accents.blue} />
      ) : (
        <Text
          style={{
            color: theme.palette.textSecondary,
            fontSize: bodyType.size,
            lineHeight: bodyType.lineHeight,
            letterSpacing: bodyType.letterSpacing
          }}
        >
          {message}
        </Text>
      )}
    </View>
  );

  return (
    <ScreenShell title="社区" useScroll={false}>
      <View style={{ marginBottom: spacing.sectionGap ?? 48 }}>
        <View
          style={{
            borderRadius: radii.card ?? 24,
            backgroundColor: theme.palette.elevated,
            paddingHorizontal: spacing.lg ?? 24,
            paddingVertical: spacing.lg ?? 24
          }}
        >
          <View style={{ flexDirection: 'row', alignItems: 'center' }}>
            <View
              style={{
                width: 36,
                height: 36,
                borderRadius: 12,
                alignItems: 'center',
                justifyContent: 'center',
                backgroundColor: `${theme.accents.blue}1f`,
                marginRight: spacing.md ?? 16
              }}
            >
              <Feather name="map-pin" size={16} color={theme.accents.blue} />
            </View>
            <View style={{ flex: 1 }}>
              <Text
                style={{
                  color:
                    theme.palette.textTertiary ?? theme.palette.textSecondary,
                  fontSize: captionType.size,
                  lineHeight: captionType.lineHeight,
                  letterSpacing: captionType.letterSpacing,
                  marginBottom: 2
                }}
              >
                当前定位
              </Text>
              <Text
                style={{
                  color: theme.palette.textPrimary,
                  fontWeight: '700',
                  fontSize: bodyType.size + 2,
                  lineHeight: bodyType.lineHeight + 2,
                  letterSpacing: bodyType.letterSpacing
                }}
              >
                {currentCity?.name ?? '尚未选择城市'}
              </Text>
            </View>
          </View>

          <Text
            style={{
              marginTop: spacing.sm ?? 12,
              color: theme.palette.textSecondary,
              fontSize: captionType.size,
              lineHeight: captionType.lineHeight,
              letterSpacing: captionType.letterSpacing
            }}
          >
            {currentCity
              ? '活动与社群内容已按当前城市筛选。'
              : '点击“使用当前位置”并授权定位，或手动选择城市。'}
          </Text>

          <View
            style={{
              marginTop: spacing.fieldGap ?? 24,
              flexDirection: 'row',
              alignItems: 'center'
            }}
          >
            <TrashButton
              title={locating ? '定位中…' : '使用当前位置'}
              variant="secondary"
              disabled={locating}
              onPress={() => {
                requestCurrentLocation().catch(() => {
                  // Error is surfaced by locationStore.
                });
              }}
              style={{ flex: 1 }}
            />
            <View style={{ width: spacing.sm ?? 12 }} />
            <TrashButton
              title="手动选择城市"
              variant="outline"
              onPress={() => router.push('/(modals)/location-picker')}
              style={{ flex: 1 }}
            />
          </View>

          {permissionStatus === 'denied' ? (
            <Text
              style={{
                color: theme.palette.danger ?? '#ff8a8a',
                fontSize: captionType.size,
                lineHeight: captionType.lineHeight,
                letterSpacing: captionType.letterSpacing,
                marginTop: spacing.sm ?? 12
              }}
            >
              定位权限已关闭，可在系统设置中开启后继续使用当前位置。
            </Text>
          ) : null}

          {locationError ? (
            <Text
              style={{
                color: theme.palette.danger ?? '#ff8a8a',
                fontSize: captionType.size,
                lineHeight: captionType.lineHeight,
                letterSpacing: captionType.letterSpacing,
                marginTop: spacing.xs ?? 8
              }}
            >
              {locationError}
            </Text>
          ) : null}
        </View>
      </View>

      <View style={{ marginBottom: spacing.fieldGap ?? 24 }}>
        <TrashSegmentedControl
          options={SECTION_OPTIONS}
          value={section}
          onChange={setSection}
        />
      </View>

      {section === 'events' ? (
        <>
          <View style={{ marginBottom: spacing.fieldGap ?? 24 }}>
            <TrashSegmentedControl
              options={VIEW_OPTIONS}
              value={viewMode}
              onChange={setViewMode}
            />
          </View>

          <TrashButton
            title="创建活动"
            variant="outline"
            onPress={() => router.push('/(modals)/create-event')}
            style={{ marginBottom: spacing.fieldGap ?? 24 }}
          />

          {viewMode === 'map' ? (
            <View
              style={{
                flex: 1,
                borderRadius: radii.card ?? 24,
                overflow: 'hidden',
                backgroundColor: theme.palette.elevated
              }}
            >
              {region ? (
                <MapView style={{ flex: 1 }} initialRegion={region}>
                  {events
                    .filter(
                      (event) =>
                        Number.isFinite(event.latitude) &&
                        Number.isFinite(event.longitude)
                    )
                    .map((event) => (
                      <Marker
                        key={event.id}
                        coordinate={{
                          latitude: event.latitude,
                          longitude: event.longitude
                        }}
                        title={event.title}
                        description={event.venue}
                        onCalloutPress={() =>
                          router.push(`/(modals)/event/${event.id}`)
                        }
                      />
                    ))}
                </MapView>
              ) : (
                <View
                  style={{
                    flex: 1,
                    alignItems: 'center',
                    justifyContent: 'center',
                    paddingHorizontal: spacing.lg ?? 24
                  }}
                >
                  <Text
                    style={{
                      color: theme.palette.textSecondary,
                      fontSize: bodyType.size,
                      lineHeight: bodyType.lineHeight,
                      letterSpacing: bodyType.letterSpacing
                    }}
                  >
                    选择城市后即可查看地图上的活动标记。
                  </Text>
                </View>
              )}
            </View>
          ) : (
            <FlatList
              data={events}
              keyExtractor={(item) => item.id}
              style={{ flex: 1 }}
              contentContainerStyle={{ paddingBottom: spacing.xxxl ?? 48 }}
              refreshControl={
                <RefreshControl
                  refreshing={eventsLoading}
                  onRefresh={handleRefresh}
                  tintColor={theme.accents.blue}
                />
              }
              ListEmptyComponent={() =>
                renderEmptyState(
                  eventsLoading,
                  '当前城市暂无活动，点击上方创建一个吧。'
                )
              }
              renderItem={({ item }) => (
                <Pressable
                  style={{
                    borderRadius: radii.card ?? 24,
                    backgroundColor: theme.palette.elevated,
                    paddingHorizontal: spacing.lg ?? 24,
                    paddingVertical: spacing.md ?? 16,
                    marginBottom: spacing.md ?? 16
                  }}
                  onPress={() => router.push(`/(modals)/event/${item.id}`)}
                >
                  <Text
                    style={{
                      color: theme.palette.textPrimary,
                      fontWeight: '700',
                      fontSize: bodyType.size + 2,
                      lineHeight: bodyType.lineHeight + 2,
                      letterSpacing: bodyType.letterSpacing
                    }}
                  >
                    {item.title}
                  </Text>
                  <Text
                    style={{
                      color: theme.palette.textSecondary,
                      marginTop: spacing.xs ?? 8,
                      fontSize: labelType.size,
                      lineHeight: labelType.lineHeight,
                      letterSpacing: labelType.letterSpacing
                    }}
                  >
                    {formatTime(item.startTime)} · {item.venue}
                  </Text>
                  <Text
                    style={{
                      color:
                        theme.palette.textTertiary ??
                        theme.palette.textSecondary,
                      marginTop: 4,
                      fontSize: captionType.size,
                      lineHeight: captionType.lineHeight,
                      letterSpacing: captionType.letterSpacing
                    }}
                  >
                    {item.distance ?? ''} · 已报名 {item.attendees ?? 0}/
                    {item.quota ?? 0}
                  </Text>
                </Pressable>
              )}
            />
          )}
        </>
      ) : (
        <>
          <TrashButton
            title="创建社群"
            variant="outline"
            onPress={() => router.push('/(modals)/create-community')}
            style={{ marginBottom: spacing.fieldGap ?? 24 }}
          />

          <FlatList
            data={groups}
            keyExtractor={(item) => item.id}
            style={{ flex: 1 }}
            contentContainerStyle={{ paddingBottom: spacing.xxxl ?? 48 }}
            refreshControl={
              <RefreshControl
                refreshing={groupsLoading}
                onRefresh={handleRefresh}
                tintColor={theme.accents.blue}
              />
            }
            renderItem={({ item }) => {
              const city = cities.find(
                (cityItem) => cityItem.id === item.cityId
              );
              return (
                <Pressable
                  style={{
                    borderRadius: radii.card ?? 24,
                    backgroundColor: theme.palette.elevated,
                    paddingHorizontal: spacing.lg ?? 24,
                    paddingVertical: spacing.md ?? 16,
                    marginBottom: spacing.md ?? 16
                  }}
                  onPress={() => router.push(`/(modals)/community/${item.id}`)}
                >
                  <Text
                    style={{
                      color: theme.palette.textPrimary,
                      fontWeight: '700',
                      fontSize: bodyType.size + 1,
                      lineHeight: bodyType.lineHeight,
                      letterSpacing: bodyType.letterSpacing
                    }}
                  >
                    {item.name}
                  </Text>
                  <Text
                    style={{
                      color: theme.palette.textSecondary,
                      fontSize: labelType.size,
                      lineHeight: labelType.lineHeight,
                      letterSpacing: labelType.letterSpacing,
                      marginTop: 4
                    }}
                  >
                    {item.memberCount} 人 ·{' '}
                    {city?.name ?? currentCity?.name ?? '未知城市'}
                  </Text>
                </Pressable>
              );
            }}
            ListEmptyComponent={() =>
              renderEmptyState(
                groupsLoading,
                '该城市暂时没有社群，试着创建一个吧。'
              )
            }
          />
        </>
      )}
    </ScreenShell>
  );
}
