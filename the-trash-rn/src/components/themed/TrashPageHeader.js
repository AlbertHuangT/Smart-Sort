import { Text, View } from 'react-native';

import { useTheme } from 'src/theme/ThemeProvider';

export default function TrashPageHeader({ title, subtitle, style }) {
  const theme = useTheme();
  const display = theme.typography?.display ?? {
    size: 42,
    lineHeight: 48,
    letterSpacing: -1
  };
  const body = theme.typography?.body ?? {
    size: 16,
    lineHeight: 25,
    letterSpacing: 0.14
  };

  return (
    <View style={[{ marginBottom: theme.spacing?.sectionGap ?? 48 }, style]}>
      <Text
        style={{
          color: theme.palette.textPrimary,
          fontSize: display.size,
          lineHeight: display.lineHeight,
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
            marginTop: theme.spacing?.md ?? 16,
            fontSize: body.size,
            lineHeight: body.lineHeight,
            letterSpacing: body.letterSpacing
          }}
        >
          {subtitle}
        </Text>
      ) : null}
    </View>
  );
}
