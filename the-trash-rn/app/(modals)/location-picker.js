import { Feather } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  Pressable,
  RefreshControl,
  Text,
  View
} from 'react-native';

import ModalSheet from 'src/components/layout/ModalSheet';
import { useLocationStore } from 'src/stores/locationStore';
import { useTheme } from 'src/theme/ThemeProvider';

export default function LocationPickerModal() {
  const router = useRouter();
  const theme = useTheme();
  const cities = useLocationStore((state) => state.cities);
  const currentCity = useLocationStore((state) => state.currentCity);
  const setCity = useLocationStore((state) => state.setCity);
  const loadCities = useLocationStore((state) => state.loadCities);
  const checkPermission = useLocationStore((state) => state.checkPermission);
  const requestCurrentLocation = useLocationStore(
    (state) => state.requestCurrentLocation
  );
  const loading = useLocationStore((state) => state.loading);
  const locating = useLocationStore((state) => state.locating);
  const permissionStatus = useLocationStore((state) => state.permissionStatus);
  const error = useLocationStore((state) => state.error);
  const [autoRequested, setAutoRequested] = useState(false);

  useEffect(() => {
    loadCities();
    checkPermission();
  }, [checkPermission, loadCities]);

  useEffect(() => {
    if (autoRequested || currentCity) return;
    if (permissionStatus === 'undetermined') {
      setAutoRequested(true);
      requestCurrentLocation().catch(() => {
        // keep silent, user can still manually select a city.
      });
    }
  }, [autoRequested, currentCity, permissionStatus, requestCurrentLocation]);

  const handleSelect = (city) => {
    setCity(city);
    router.back();
  };

  const permissionLabel = useMemo(() => {
    if (permissionStatus === 'granted') return 'Location permission enabled';
    if (permissionStatus === 'denied') return 'Location permission disabled';
    return 'Grant permission to auto-locate the nearest city';
  }, [permissionStatus]);

  const handleLocate = async () => {
    try {
      await requestCurrentLocation();
    } catch {
      // Error message is already stored in locationStore.
    }
  };

  const showLoadingState = loading && cities.length === 0 && !locating;

  return (
    <ModalSheet title="Select City">
      <View
        style={{
          borderRadius: 20,
          borderWidth: 1,
          borderColor: theme.tabBar.border,
          backgroundColor: theme.palette.card,
          padding: 14,
          marginBottom: 12
        }}
      >
        <Text
          style={{
            color: theme.palette.textPrimary,
            fontWeight: '700',
            fontSize: 15
          }}
        >
          Current city: {currentCity?.name ?? 'Not selected'}
        </Text>
        <Text
          style={{
            color: theme.palette.textSecondary,
            fontSize: 12,
            marginTop: 4
          }}
        >
          {permissionLabel}
        </Text>
        {error ? (
          <Text style={{ color: '#ffb4b4', fontSize: 12, marginTop: 6 }}>
            {error}
          </Text>
        ) : null}
        <Pressable
          onPress={handleLocate}
          disabled={locating}
          style={{
            marginTop: 10,
            borderRadius: 14,
            borderWidth: 1,
            borderColor: theme.accents.green,
            backgroundColor: `${theme.accents.green}24`,
            paddingVertical: 10,
            paddingHorizontal: 12,
            flexDirection: 'row',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 8,
            opacity: locating ? 0.7 : 1
          }}
        >
          {locating ? (
            <ActivityIndicator size="small" color={theme.accents.green} />
          ) : (
            <Feather name="navigation" size={14} color={theme.accents.green} />
          )}
          <Text
            style={{
              color: theme.accents.green,
              fontWeight: '700',
              fontSize: 13
            }}
          >
            {locating ? 'Locating...' : 'Use Current Location'}
          </Text>
        </Pressable>
      </View>

      <Text
        style={{
          color: theme.palette.textSecondary,
          fontSize: 12,
          marginBottom: 8
        }}
      >
        Choose City Manually
      </Text>

      {showLoadingState ? (
        <View className="flex-1 items-center justify-center py-12">
          <ActivityIndicator color={theme.accents.blue} />
          <Text style={{ color: theme.palette.textSecondary, marginTop: 12 }}>
            Loading city list...
          </Text>
        </View>
      ) : (
        <FlatList
          data={cities}
          keyExtractor={(item) => item.id}
          refreshControl={
            <RefreshControl
              refreshing={loading || locating}
              onRefresh={loadCities}
            />
          }
          ListEmptyComponent={() => (
            <View className="items-center py-8">
              <Text style={{ color: theme.palette.textSecondary }}>
                No city data yet. Try "Use Current Location" first.
              </Text>
            </View>
          )}
          renderItem={({ item }) => (
            <Pressable
              style={{
                borderRadius: 18,
                borderWidth: 1,
                paddingVertical: 12,
                paddingHorizontal: 14,
                marginBottom: 8,
                borderColor:
                  currentCity?.id === item.id
                    ? theme.accents.blue
                    : theme.tabBar.border,
                backgroundColor:
                  currentCity?.id === item.id
                    ? `${theme.accents.blue}1c`
                    : theme.palette.card,
                flexDirection: 'row',
                alignItems: 'center',
                justifyContent: 'space-between'
              }}
              onPress={() => handleSelect(item)}
            >
              <View
                style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}
              >
                <Feather
                  name="map-pin"
                  size={16}
                  color={theme.palette.textSecondary}
                />
                <View>
                  <Text
                    style={{
                      color: theme.palette.textPrimary,
                      fontWeight: '700'
                    }}
                  >
                    {item.name}
                  </Text>
                  <Text
                    style={{ color: theme.palette.textSecondary, fontSize: 11 }}
                  >
                    Tap to switch to this city
                  </Text>
                </View>
              </View>
              {currentCity?.id === item.id ? (
                <Text
                  style={{
                    color: theme.accents.blue,
                    fontSize: 12,
                    fontWeight: '700'
                  }}
                >
                  Current
                </Text>
              ) : (
                <Feather
                  name="chevron-right"
                  size={16}
                  color={theme.palette.textSecondary}
                />
              )}
            </Pressable>
          )}
        />
      )}
    </ModalSheet>
  );
}
