import { View } from 'react-native';

import { useTheme } from 'src/theme/ThemeProvider';

export default function TimerBar({ progress = 1, variant = 'info' }) {
  const theme = useTheme();
  const spacing = theme.spacing ?? {};
  const radii = theme.radii ?? {};
  const color =
    variant === 'warning' ? theme.accents.orange : theme.accents.blue;
  return (
    <View
      style={{
        height: 8,
        backgroundColor: theme.palette.overlay ?? theme.palette.elevated,
        borderRadius: radii.pill ?? 999,
        overflow: 'hidden',
        marginBottom: spacing.md ?? 14
      }}
    >
      <View
        style={{
          width: `${Math.max(0, Math.min(1, progress)) * 100}%`,
          backgroundColor: color,
          height: '100%'
        }}
      />
    </View>
  );
}
