import { Pressable, Text, View } from 'react-native';

import { useTheme } from 'src/theme/ThemeProvider';

export default function QuizCard({ question, onAnswer, mode }) {
  const theme = useTheme();
  const spacing = theme.spacing ?? {};
  const radii = theme.radii ?? {};
  const bodyType = theme.typography?.body ?? {
    size: 15,
    lineHeight: 22,
    letterSpacing: 0.12
  };
  const labelType = theme.typography?.label ?? {
    size: 14,
    lineHeight: 19,
    letterSpacing: 0.18
  };
  const captionType = theme.typography?.caption ?? {
    size: 12,
    lineHeight: 17,
    letterSpacing: 0.14
  };

  const wrapperStyle = {
    borderRadius: radii.card ?? 20,
    borderWidth: 1,
    borderColor: theme.tabBar.border,
    backgroundColor: theme.palette.card,
    padding: theme.components?.card?.padding ?? spacing.lg ?? 20
  };

  if (!question) {
    return (
      <View style={wrapperStyle}>
        <Text
          style={{
            color: theme.palette.textSecondary,
            fontSize: labelType.size,
            lineHeight: labelType.lineHeight,
            letterSpacing: labelType.letterSpacing
          }}
        >
          Loading questions...
        </Text>
      </View>
    );
  }

  return (
    <View style={wrapperStyle}>
      <Text
        style={{
          color: theme.accents.blue,
          fontSize: captionType.size,
          lineHeight: captionType.lineHeight,
          letterSpacing: 1.6,
          textTransform: 'uppercase',
          marginBottom: spacing.xs ?? 6,
          fontWeight: '700'
        }}
      >
        {mode}
      </Text>
      <Text
        style={{
          color: theme.palette.textPrimary,
          fontWeight: '700',
          fontSize: bodyType.size + 4,
          lineHeight: bodyType.lineHeight + 4,
          letterSpacing: bodyType.letterSpacing,
          marginBottom: spacing.md ?? 14
        }}
      >
        {question.prompt}
      </Text>
      {question.options?.map((option) => (
        <Pressable
          key={option}
          onPress={() => onAnswer?.(option)}
          style={{
            borderRadius: radii.input ?? 14,
            borderWidth: 1,
            borderColor: theme.tabBar.border,
            backgroundColor: theme.palette.background,
            paddingHorizontal: spacing.md ?? 14,
            paddingVertical: spacing.md ?? 14,
            marginBottom: spacing.sm ?? 10
          }}
        >
          <Text
            style={{
              color: theme.palette.textPrimary,
              fontSize: bodyType.size,
              lineHeight: bodyType.lineHeight,
              letterSpacing: bodyType.letterSpacing
            }}
          >
            {option}
          </Text>
        </Pressable>
      ))}
    </View>
  );
}
