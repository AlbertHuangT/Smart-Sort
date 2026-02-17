import { Stack } from 'expo-router';

export default function ArenaLayout() {
  return (
    <Stack screenOptions={{ headerShown: false }}>
      <Stack.Screen name="index" />
      <Stack.Screen name="classic" />
      <Stack.Screen name="speed-sort" />
      <Stack.Screen name="streak" />
      <Stack.Screen name="daily-challenge" />
      <Stack.Screen name="duel/[id]" />
      <Stack.Screen name="duel/lobby" />
    </Stack>
  );
}
