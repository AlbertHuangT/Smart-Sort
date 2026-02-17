import * as Location from 'expo-location';
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

import { communityService } from 'src/services/community';
import { createPersistStorage } from 'src/utils/storage';

const DEFAULT_CITIES = [
  {
    id: 'san-francisco-ca',
    name: 'San Francisco',
    city: 'San Francisco',
    state: 'CA',
    latitude: 37.7749,
    longitude: -122.4194
  },
  {
    id: 'los-angeles-ca',
    name: 'Los Angeles',
    city: 'Los Angeles',
    state: 'CA',
    latitude: 34.0522,
    longitude: -118.2437
  },
  {
    id: 'new-york-ny',
    name: 'New York',
    city: 'New York',
    state: 'NY',
    latitude: 40.7128,
    longitude: -74.006
  },
  {
    id: 'seattle-wa',
    name: 'Seattle',
    city: 'Seattle',
    state: 'WA',
    latitude: 47.6062,
    longitude: -122.3321
  },
  {
    id: 'shanghai-cn',
    name: 'Shanghai',
    city: 'Shanghai',
    state: null,
    latitude: 31.2304,
    longitude: 121.4737
  }
];

const toNumber = (value) => {
  const num = Number(value);
  return Number.isFinite(num) ? num : null;
};

const toRadians = (value) => (value * Math.PI) / 180;

const haversineKm = (a, b) => {
  if (!a || !b) return null;
  const lat1 = toNumber(a.latitude);
  const lon1 = toNumber(a.longitude);
  const lat2 = toNumber(b.latitude);
  const lon2 = toNumber(b.longitude);
  if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) return null;

  const earthRadiusKm = 6371;
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const rLat1 = toRadians(lat1);
  const rLat2 = toRadians(lat2);

  const value =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rLat1) * Math.cos(rLat2) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(value), Math.sqrt(1 - value));
  return earthRadiusKm * c;
};

const withCityInList = (cities, city) => {
  if (!city) return cities;
  const exists = cities.some(
    (item) => item.id === city.id || (item.name && item.name === city.name)
  );
  if (exists) return cities;
  return [city, ...cities];
};

const buildFallbackCity = (coords, geocode) => {
  const name =
    geocode?.city ?? geocode?.subregion ?? geocode?.district ?? '当前位置';
  const state = geocode?.region ?? null;
  const id = [name, state]
    .filter(Boolean)
    .join('-')
    .toLowerCase()
    .replace(/\s+/g, '-');
  return {
    id: id || `device-${Date.now()}`,
    name,
    city: name,
    state,
    latitude: toNumber(coords.latitude),
    longitude: toNumber(coords.longitude),
    fromDevice: true
  };
};

const pickNearestCity = (cities, coords) => {
  if (!Array.isArray(cities) || cities.length === 0) return null;
  let nearest = null;
  let nearestDistance = Infinity;

  cities.forEach((city) => {
    const distance = haversineKm(city, coords);
    if (distance == null) return;
    if (distance < nearestDistance) {
      nearest = city;
      nearestDistance = distance;
    }
  });

  if (!nearest) return null;
  if (nearestDistance <= 80) return nearest;
  return null;
};

export const useLocationStore = create(
  persist(
    (set, get) => ({
      cities: [],
      currentCity: null,
      loading: false,
      locating: false,
      permissionStatus: 'undetermined',
      error: null,
      loadCities: async () => {
        if (get().loading) return;
        set({ loading: true, error: null });
        try {
          const fetchedCities = await communityService.fetchCities();
          const cities =
            Array.isArray(fetchedCities) && fetchedCities.length > 0
              ? fetchedCities
              : DEFAULT_CITIES;
          const currentCity = get().currentCity ?? cities[0] ?? null;
          set({ cities, currentCity, loading: false });
        } catch (error) {
          const currentCity = get().currentCity ?? DEFAULT_CITIES[0];
          set({
            cities: DEFAULT_CITIES,
            currentCity,
            loading: false,
            error: error.message
          });
        }
      },
      checkPermission: async () => {
        try {
          const permission = await Location.getForegroundPermissionsAsync();
          set({ permissionStatus: permission.status ?? 'undetermined' });
          return permission.status ?? 'undetermined';
        } catch {
          return 'undetermined';
        }
      },
      requestCurrentLocation: async () => {
        if (get().locating) return get().currentCity;
        set({ locating: true, error: null });
        try {
          const permission = await Location.requestForegroundPermissionsAsync();
          const status = permission.status ?? 'undetermined';
          set({ permissionStatus: status });
          if (!permission.granted) {
            throw new Error('未开启定位权限，请在系统设置中允许定位后重试。');
          }

          const position = await Location.getCurrentPositionAsync({
            accuracy: Location.Accuracy.Balanced
          });
          const coords = {
            latitude: position.coords.latitude,
            longitude: position.coords.longitude
          };
          const currentCities = get().cities;
          let nextCity = pickNearestCity(currentCities, coords);

          if (!nextCity) {
            let geocode = null;
            try {
              const geocodeRows = await Location.reverseGeocodeAsync(coords);
              geocode = geocodeRows?.[0] ?? null;
            } catch {
              geocode = null;
            }
            nextCity = buildFallbackCity(coords, geocode);
          }

          set((state) => ({
            currentCity: nextCity,
            cities: withCityInList(state.cities, nextCity),
            locating: false
          }));
          return nextCity;
        } catch (error) {
          const message = error instanceof Error ? error.message : '定位失败';
          set({ locating: false, error: message });
          throw new Error(message);
        }
      },
      setCity: (city) =>
        set((state) => ({
          currentCity: city,
          cities: withCityInList(state.cities, city)
        }))
    }),
    {
      name: 'the-trash-location',
      storage: createPersistStorage(),
      partialize: (state) => ({ currentCity: state.currentCity })
    }
  )
);
