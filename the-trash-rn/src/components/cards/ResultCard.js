import { memo } from 'react';
import { Text, View } from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Animated, {
  runOnJS,
  useAnimatedStyle,
  useSharedValue,
  withSpring
} from 'react-native-reanimated';

import { useTheme } from 'src/theme/ThemeProvider';

function ResultCard({ result, onConfirm, onCorrect }) {
  const theme = useTheme();
  const translateX = useSharedValue(0);
  const swipeThreshold = theme.components?.resultCard?.swipeThreshold ?? 110;
  const spring = theme.animationConfig?.resultCardSpring ??
    theme.motion?.springs?.snappy ?? {
      damping: 18,
      stiffness: 280,
      mass: 0.34
    };
  const cardRadius = theme.radii?.card ?? 24;
  const cardPadding =
    theme.components?.card?.padding ?? theme.spacing?.lg ?? 24;
  const bodyType = theme.typography?.body ?? {
    size: 15,
    lineHeight: 23,
    letterSpacing: 0.12
  };
  const labelType = theme.typography?.label ?? {
    size: 13,
    lineHeight: 18,
    letterSpacing: 0.26
  };
  const titleType = theme.typography?.title ?? {
    size: 28,
    lineHeight: 34,
    letterSpacing: -0.55
  };

  const gesture = Gesture.Pan()
    .onUpdate((event) => {
      translateX.value = event.translationX;
    })
    .onEnd(() => {
      if (translateX.value > swipeThreshold) {
        runOnJS(onConfirm)?.();
      } else if (translateX.value < -swipeThreshold) {
        runOnJS(onCorrect)?.();
      }
      translateX.value = withSpring(0, {
        damping: spring.damping ?? 18,
        stiffness: spring.stiffness ?? 280,
        mass: spring.mass ?? 0.34
      });
    });

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: translateX.value }]
  }));

  if (!result) {
    return (
      <View
        style={{
          borderRadius: cardRadius,
          borderWidth: 1,
          borderColor: theme.palette.divider ?? 'rgba(255,255,255,0.12)',
          backgroundColor: theme.palette.card,
          padding: cardPadding
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
          拍照后会显示 AI 识别结果。
        </Text>
      </View>
    );
  }

  return (
    <GestureDetector gesture={gesture}>
      <Animated.View
        style={[
          {
            borderRadius: cardRadius,
            padding: cardPadding,
            backgroundColor: theme.palette.card,
            borderWidth: 1,
            borderColor: theme.palette.divider ?? 'rgba(255,255,255,0.1)'
          },
          animatedStyle
        ]}
      >
        <Text
          style={{
            color: theme.accents.blue,
            fontSize: labelType.size,
            lineHeight: labelType.lineHeight,
            fontWeight: '600',
            letterSpacing: Math.max(labelType.letterSpacing ?? 0.26, 1.6),
            marginBottom: theme.spacing?.sm ?? 12
          }}
        >
          AI RESULT
        </Text>
        <Text
          style={{
            color: theme.palette.textPrimary,
            fontSize: titleType.size,
            lineHeight: titleType.lineHeight,
            letterSpacing: titleType.letterSpacing,
            fontWeight: '700',
            marginBottom: theme.spacing?.xs ?? 8
          }}
        >
          {result.item}
        </Text>
        <Text
          style={{
            color: theme.palette.textSecondary,
            fontSize: bodyType.size,
            lineHeight: bodyType.lineHeight,
            letterSpacing: bodyType.letterSpacing,
            marginBottom: theme.spacing?.md ?? 16
          }}
        >
          推荐投放：{result.category}
        </Text>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
          <Text
            style={{
              color: theme.palette.textSecondary,
              fontSize: theme.typography?.caption?.size ?? 12
            }}
          >
            可信度 {Math.round((result.confidence ?? 0) * 100)}%
          </Text>
          <Text
            style={{
              color: theme.palette.textSecondary,
              fontSize: theme.typography?.caption?.size ?? 12
            }}
          >
            向右确认 · 向左纠正
          </Text>
        </View>
      </Animated.View>
    </GestureDetector>
  );
}

export default memo(ResultCard);
