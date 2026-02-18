import '../global.css';
import { Stack } from 'expo-router';

import AppProviders from 'src/providers/AppProviders';

export const unstable_settings = {
  initialRouteName: 'index'
};

export default function RootLayout() {
  return (
    <AppProviders>
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="index" />
        <Stack.Screen name="(tabs)" />
        <Stack.Screen
          name="(modals)"
          options={{ presentation: 'modal', animation: 'fade' }}
        />
        <Stack.Screen name="challenge/[id]" options={{ headerShown: false }} />
      </Stack>
    </AppProviders>
  );
}
