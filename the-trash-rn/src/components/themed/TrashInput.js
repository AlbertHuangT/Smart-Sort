import { Platform, Text, TextInput, View } from 'react-native';
import Animated, {
  Easing,
  interpolateColor,
  useAnimatedStyle,
  useSharedValue,
  withTiming
} from 'react-native-reanimated';

import { useTheme } from 'src/theme/ThemeProvider';

export default function TrashInput({
  label,
  placeholder,
  value,
  onChangeText,
  secureTextEntry = false,
  keyboardType = 'default',
  autoCapitalize = 'none',
  containerStyle,
  onFocus,
  onBlur,
  ...rest
}) {
  const theme = useTheme();
  const focusProgress = useSharedValue(0);
  const placeholderColor =
    theme.palette.textTertiary ?? theme.palette.textSecondary ?? '#7f889a';
  const inputPadding = theme.components?.input ?? {};
  const baseVerticalPadding =
    inputPadding.verticalPadding ?? theme.spacing?.sm ?? 12;
  const labelType = theme.typography?.label ?? {
    size: 14,
    lineHeight: 20,
    letterSpacing: 0.22
  };
  const bodyType = theme.typography?.body ?? {
    size: 16,
    lineHeight: 25,
    letterSpacing: 0.14
  };
  const baseMinHeight = theme.sizes?.inputMinHeight ?? 52;
  const borderCurveStyle =
    Platform.OS === 'ios' && theme.shape?.borderCurve === 'continuous'
      ? { borderCurve: 'continuous' }
      : null;

  const focusDuration = theme.motion?.durations?.focus ?? 200;
  const curve = theme.motion?.curves?.standard ?? [0.3, 0, 0.2, 1];

  const wrapperStyle = useAnimatedStyle(() => ({
    backgroundColor: interpolateColor(
      focusProgress.value,
      [0, 1],
      [
        theme.palette.elevated ?? theme.palette.card,
        theme.palette.overlay ?? theme.palette.elevated ?? theme.palette.card
      ]
    ),
    shadowColor: theme.accents.blue,
    shadowOpacity: 0.03 + 0.13 * focusProgress.value,
    shadowRadius: 6 + 9 * focusProgress.value,
    transform: [{ scale: 1 + 0.01 * focusProgress.value }]
  }));

  const handleFocus = (event) => {
    focusProgress.value = withTiming(1, {
      duration: focusDuration,
      easing: Easing.bezier(...curve)
    });
    onFocus?.(event);
  };

  const handleBlur = (event) => {
    focusProgress.value = withTiming(0, {
      duration: focusDuration,
      easing: Easing.bezier(...curve)
    });
    onBlur?.(event);
  };

  return (
    <View
      style={[{ marginBottom: theme.spacing?.fieldGap ?? 24 }, containerStyle]}
    >
      <Animated.View
        style={[
          wrapperStyle,
          {
            borderRadius: theme.radii?.input ?? 18,
            ...borderCurveStyle,
            paddingHorizontal:
              inputPadding.horizontalPadding ?? theme.spacing?.md ?? 16,
            paddingTop: label ? Math.max(6, baseVerticalPadding - 4) : 0,
            paddingBottom: label ? Math.max(6, baseVerticalPadding - 2) : 0
          }
        ]}
      >
        {label ? (
          <Text
            style={{
              color: theme.palette.textTertiary ?? theme.palette.textSecondary,
              fontSize: labelType.size ?? 13,
              lineHeight: labelType.lineHeight ?? 18,
              letterSpacing: labelType.letterSpacing ?? 0.26,
              fontWeight: '600',
              marginBottom: 2
            }}
          >
            {label}
          </Text>
        ) : null}
        <TextInput
          value={value}
          onChangeText={onChangeText}
          placeholder={placeholder}
          placeholderTextColor={placeholderColor}
          secureTextEntry={secureTextEntry}
          keyboardType={keyboardType}
          autoCapitalize={autoCapitalize}
          onFocus={handleFocus}
          onBlur={handleBlur}
          style={{
            color: theme.palette.textPrimary,
            paddingVertical: label ? 8 : baseVerticalPadding,
            fontSize: bodyType.size ?? 15,
            lineHeight: bodyType.lineHeight ?? 23,
            letterSpacing: bodyType.letterSpacing ?? 0.12,
            textAlignVertical: rest.multiline ? 'top' : 'center',
            minHeight: rest.multiline
              ? 104
              : label
                ? Math.max(40, baseMinHeight - 10)
                : baseMinHeight
          }}
          {...rest}
        />
      </Animated.View>
    </View>
  );
}
