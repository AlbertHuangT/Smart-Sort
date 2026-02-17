import { Tabs } from 'expo-router';
import { useMemo } from 'react';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import TabBarIcon from 'src/components/navigation/TabBarIcon';
import { useThemeStore } from 'src/stores/themeStore';

export default function TabsLayout() {
  const tint = useThemeStore((state) => state.theme.tabBar);
  const insets = useSafeAreaInsets();
  const tabBarStyle = useMemo(
    () => ({
      backgroundColor: tint.background,
      borderTopColor: tint.border,
      borderTopWidth: 1,
      height: Math.max(68, 54 + insets.bottom),
      paddingBottom: Math.max(10, insets.bottom + 4),
      paddingTop: 8
    }),
    [insets.bottom, tint.background, tint.border]
  );

  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarStyle,
        tabBarLabelStyle: {
          fontSize: 11,
          fontWeight: '600'
        },
        tabBarHideOnKeyboard: true,
        tabBarActiveTintColor: tint.active,
        tabBarInactiveTintColor: tint.inactive
      }}
    >
      <Tabs.Screen
        name="verify"
        options={{
          title: 'Verify',
          tabBarIcon: (props) => <TabBarIcon {...props} name="camera" />
        }}
      />
      <Tabs.Screen
        name="arena"
        options={{
          title: 'Arena',
          tabBarIcon: (props) => <TabBarIcon {...props} name="zap" />
        }}
      />
      <Tabs.Screen
        name="leaderboard"
        options={{
          title: 'Leaders',
          tabBarIcon: (props) => <TabBarIcon {...props} name="award" />
        }}
      />
      <Tabs.Screen
        name="community"
        options={{
          title: 'Community',
          tabBarIcon: (props) => <TabBarIcon {...props} name="users" />
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: 'Profile',
          tabBarIcon: (props) => <TabBarIcon {...props} name="user" />
        }}
      />
    </Tabs>
  );
}
