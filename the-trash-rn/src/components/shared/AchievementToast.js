import { useEffect, useRef } from 'react';
import { Animated, Text, View } from 'react-native';

import { useAchievementStore } from 'src/stores/achievementStore';
import { useTheme } from 'src/theme/ThemeProvider';

export default function AchievementToast() {
  const toast = useAchievementStore((state) => state.toastQueue[0]);
  const consumeToast = useAchievementStore((state) => state.consumeToast);
  const theme = useTheme();
  const opacity = useRef(new Animated.Value(0)).current;
  const translateY = useRef(new Animated.Value(-20)).current;

  useEffect(() => {
    if (!toast) {
      return;
    }
    Animated.parallel([
      Animated.timing(opacity, {
        toValue: 1,
        duration: 250,
        useNativeDriver: true
      }),
      Animated.timing(translateY, {
        toValue: 0,
        duration: 250,
        useNativeDriver: true
      })
    ]).start();
    const timer = setTimeout(() => {
      Animated.parallel([
        Animated.timing(opacity, {
          toValue: 0,
          duration: 200,
          useNativeDriver: true
        }),
        Animated.timing(translateY, {
          toValue: -20,
          duration: 200,
          useNativeDriver: true
        })
      ]).start(() => consumeToast());
    }, 2800);
    return () => clearTimeout(timer);
  }, [toast, consumeToast, opacity, translateY]);

  if (!toast) {
    return null;
  }

  return (
    <View
      pointerEvents="none"
      style={{
        position: 'absolute',
        top: 24,
        left: 0,
        right: 0,
        alignItems: 'center'
      }}
    >
      <Animated.View
        style={{
          opacity,
          transform: [{ translateY }],
          backgroundColor: theme.palette.card,
          borderRadius: 28,
          paddingHorizontal: 20,
          paddingVertical: 12,
          borderWidth: 1,
          borderColor: 'rgba(255,255,255,0.2)',
          shadowColor: '#000',
          shadowOpacity: 0.2,
          shadowOffset: { width: 0, height: 6 },
          shadowRadius: 12
        }}
      >
        <Text
          style={{
            fontSize: 16,
            color: theme.palette.textPrimary,
            fontWeight: '700'
          }}
        >
          {toast.icon ?? '✨'} {toast.title}
        </Text>
        <Text
          style={{
            fontSize: 13,
            color: theme.palette.textSecondary,
            marginTop: 4
          }}
        >
          {toast.description}
        </Text>
      </Animated.View>
    </View>
  );
}
