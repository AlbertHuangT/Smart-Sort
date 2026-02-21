import { Feather } from '@expo/vector-icons';
import { ActivityIndicator, Pressable, View } from 'react-native';

import { useTheme } from 'src/theme/ThemeProvider';

export default function CameraControls({
  onCapture,
  onHistory,
  disabled = false,
  analyzing = false
}) {
  const theme = useTheme();

  return (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        marginTop: 16
      }}
    >
      <Pressable
        onPress={onHistory}
        style={{
          width: 48,
          height: 48,
          borderRadius: 24,
          borderWidth: 1,
          borderColor: 'rgba(255,255,255,0.2)',
          alignItems: 'center',
          justifyContent: 'center'
        }}
      >
        <Feather name="clock" color={theme.palette.textPrimary} size={20} />
      </Pressable>
      <Pressable
        onPress={onCapture}
        disabled={disabled}
        style={{
          width: 80,
          height: 80,
          borderRadius: 40,
          backgroundColor: 'rgba(255,255,255,0.9)',
          alignItems: 'center',
          justifyContent: 'center'
        }}
      >
        {analyzing ? (
          <ActivityIndicator color={theme.palette.textPrimary} />
        ) : (
          <View
            style={{
              width: 64,
              height: 64,
              borderRadius: 32,
              backgroundColor: theme.accents.blue
            }}
          />
        )}
      </Pressable>
      <View style={{ width: 48, height: 48 }} />
    </View>
  );
}
