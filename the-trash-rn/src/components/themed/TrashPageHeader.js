import { Text, View, useWindowDimensions } from 'react-native';

import { useTheme } from 'src/theme/ThemeProvider';

export default function TrashPageHeader({ title, subtitle, style }) {
  const { width } = useWindowDimensions();
  const theme = useTheme();
  const display = theme.typography?.display ?? {
    size: 34,
    lineHeight: 40,
    letterSpacing: -0.82
  };
  const body = theme.typography?.body ?? {
    size: 15,
    lineHeight: 22,
    letterSpacing: 0.12
  };
  const displaySize =
    width < 390 ? Math.max(28, display.size - 2) : display.size;
  const displayLineHeight =
    width < 390 ? Math.max(34, display.lineHeight - 2) : display.lineHeight;

  return (
    <View style={[{ marginBottom: theme.spacing?.sectionGap ?? 28 }, style]}>
      <Text
        style={{
          color: theme.palette.textPrimary,
          fontSize: displaySize,
          lineHeight: displayLineHeight,
          fontWeight: '700',
          letterSpacing: display.letterSpacing
        }}
      >
        {title}
      </Text>
      {subtitle ? (
        <Text
          style={{
            color: theme.palette.textTertiary ?? theme.palette.textSecondary,
            marginTop: theme.spacing?.sm ?? 10,
            fontSize: body.size,
            lineHeight: body.lineHeight,
            letterSpacing: body.letterSpacing,
            maxWidth: theme.sizes?.proseMaxWidth ?? 540
          }}
        >
          {subtitle}
        </Text>
      ) : null}
    </View>
  );
}
