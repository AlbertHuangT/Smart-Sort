import { useEffect } from 'react';
import { Platform } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withSpring,
  withTiming
} from 'react-native-reanimated';

import { useTheme } from 'src/theme/ThemeProvider';

const resolveCornerStyle = (radius, offsets) => {
  if (!offsets) return { borderRadius: radius };
  return {
    borderTopLeftRadius: Math.max(8, radius + (offsets.topLeft ?? 0)),
    borderTopRightRadius: Math.max(8, radius + (offsets.topRight ?? 0)),
    borderBottomRightRadius: Math.max(8, radius + (offsets.bottomRight ?? 0)),
    borderBottomLeftRadius: Math.max(8, radius + (offsets.bottomLeft ?? 0))
  };
};

export default function TrashCard({ children, style }) {
  const theme = useTheme();
  const radius = theme.radii?.card ?? 24;
  const cardPadding =
    theme.components?.card?.padding ?? theme.spacing?.lg ?? 24;

  const cornerStyle = resolveCornerStyle(
    radius,
    theme.shape?.cardCornerOffsets ?? null
  );
  const borderCurveStyle =
    Platform.OS === 'ios' && theme.shape?.borderCurve === 'continuous'
      ? { borderCurve: 'continuous' }
      : null;

  const enterType = theme.animationConfig?.type ?? 'tactile';
  const enterSpring = theme.animationConfig?.cardEnterSpring ?? {
    damping: 18,
    stiffness: 220,
    mass: 0.45
  };
  const enterDuration = theme.motion?.durations?.normal ?? 240;
  const enterCurve = theme.motion?.curves?.decelerate ?? [0, 0, 0.2, 1];

  const reveal = useSharedValue(0);

  useEffect(() => {
    if (enterType === 'organic-grow') {
      reveal.value = withSpring(1, {
        damping: enterSpring.damping ?? 22,
        stiffness: enterSpring.stiffness ?? 120,
        mass: enterSpring.mass ?? 0.8
      });
      return;
    }

    reveal.value = withTiming(1, {
      duration: enterDuration,
      easing: Easing.bezier(...enterCurve)
    });
  }, [
    enterCurve,
    enterDuration,
    enterSpring.damping,
    enterSpring.mass,
    enterSpring.stiffness,
    enterType,
    reveal
  ]);

  const revealStyle = useAnimatedStyle(() => {
    const initialScale = enterType === 'pulse' ? 0.988 : 0.98;
    const initialTranslate = enterType === 'organic-grow' ? 8 : 4;
    return {
      opacity: 0.9 + reveal.value * 0.1,
      transform: [
        { translateY: (1 - reveal.value) * initialTranslate },
        { scale: initialScale + (1 - initialScale) * reveal.value }
      ]
    };
  });

  return (
    <Animated.View
      style={[
        revealStyle,
        {
          overflow: 'hidden',
          backgroundColor: theme.palette.card,
          padding: cardPadding,
          shadowColor: theme.shadows?.dark ?? '#000',
          shadowOffset: { width: 0, height: 6 },
          shadowOpacity: Platform.OS === 'ios' ? 0.08 : 0.1,
          shadowRadius: 14,
          elevation: 2
        },
        cornerStyle,
        borderCurveStyle,
        style
      ]}
    >
      {children}
    </Animated.View>
  );
}
