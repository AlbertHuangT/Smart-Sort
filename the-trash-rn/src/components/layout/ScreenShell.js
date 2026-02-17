import { ScrollView, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import ThemeBackdrop from 'src/components/themed/ThemeBackdrop';
import { useTheme } from 'src/theme/ThemeProvider';

export default function ScreenShell({ title, children, useScroll = true }) {
  const { top, bottom } = useSafeAreaInsets();
  const theme = useTheme();
  const spacing = theme.spacing ?? {};
  const titleType = theme.typography?.title ?? {
    size: 28,
    lineHeight: 34,
    letterSpacing: -0.55
  };

  const baseStyle = {
    flex: 1,
    paddingTop: top + (spacing.screenTop ?? 48),
    paddingBottom: bottom + (spacing.lg ?? 24),
    paddingHorizontal: spacing.screenHorizontal ?? 24
  };

  const content = (
    <>
      {title ? (
        <Text
          style={{
            color: theme.palette.textPrimary,
            fontSize: titleType.size,
            lineHeight: titleType.lineHeight,
            letterSpacing: titleType.letterSpacing,
            fontWeight: '700',
            marginBottom: spacing.sectionGap ?? 24
          }}
        >
          {title}
        </Text>
      ) : null}
      {children}
    </>
  );

  if (!useScroll) {
    return (
      <View style={{ flex: 1, backgroundColor: theme.palette.background }}>
        <ThemeBackdrop />
        <View style={baseStyle}>{content}</View>
      </View>
    );
  }

  return (
    <View style={{ flex: 1, backgroundColor: theme.palette.background }}>
      <ThemeBackdrop />
      <ScrollView
        style={baseStyle}
        decelerationRate={theme.scroll?.decelerationRate ?? 'normal'}
        contentContainerStyle={{ paddingBottom: spacing.xxl ?? 40 }}
        showsVerticalScrollIndicator={false}
      >
        {content}
      </ScrollView>
    </View>
  );
}
