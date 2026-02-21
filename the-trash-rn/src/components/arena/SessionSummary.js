import { Text, View } from 'react-native';

import { useTheme } from 'src/theme/ThemeProvider';

export default function SessionSummary({ title, value, subtitle }) {
  const theme = useTheme();
  const spacing = theme.spacing ?? {};
  const radii = theme.radii ?? {};
  const bodyType = theme.typography?.body ?? {
    size: 15,
    lineHeight: 22,
    letterSpacing: 0.12
  };
  const captionType = theme.typography?.caption ?? {
    size: 12,
    lineHeight: 17,
    letterSpacing: 0.14
  };

  return (
    <View
      style={{
        borderRadius: radii.card ?? 20,
        borderWidth: 1,
        borderColor: theme.tabBar.border,
        backgroundColor: theme.palette.card,
        padding: theme.components?.card?.padding ?? spacing.lg ?? 20
      }}
    >
      <Text
        style={{
          color: theme.palette.textSecondary,
          fontSize: bodyType.size,
          lineHeight: bodyType.lineHeight,
          letterSpacing: bodyType.letterSpacing,
          marginBottom: 2
        }}
      >
        {title}
      </Text>
      <Text
        style={{
          color: theme.palette.textPrimary,
          fontSize: bodyType.size + 16,
          lineHeight: bodyType.lineHeight + 16,
          fontWeight: '700',
          letterSpacing: bodyType.letterSpacing
        }}
      >
        {value}
      </Text>
      {subtitle ? (
        <Text
          style={{
            color: theme.palette.textSecondary,
            fontSize: captionType.size,
            lineHeight: captionType.lineHeight,
            letterSpacing: captionType.letterSpacing,
            marginTop: spacing.xs ?? 6
          }}
        >
          {subtitle}
        </Text>
      ) : null}
    </View>
  );
}
