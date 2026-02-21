import { useMemo } from 'react';
import { ActivityIndicator, Pressable, Text, View } from 'react-native';
import { Camera, useCameraDevice } from 'react-native-vision-camera';

import { useTheme } from 'src/theme/ThemeProvider';

export default function CameraView({
  cameraRef,
  permissionStatus,
  onRequestPermission,
  isActive = true
}) {
  const backDevice = useCameraDevice('back');
  const frontDevice = useCameraDevice('front');
  const device = backDevice ?? frontDevice;
  const theme = useTheme();
  const status = permissionStatus ?? 'unknown';
  const needsPermission = !['granted', 'authorized'].includes(status);

  const permissionCopy = useMemo(() => {
    if (status === 'denied' || status === 'restricted') {
      return 'Camera permission was denied. Enable it in system settings.';
    }
    return 'Camera permission is required to start scanning.';
  }, [status]);

  if (needsPermission) {
    return (
      <View
        style={{
          flex: 1,
          borderRadius: 32,
          borderWidth: 1,
          borderColor: 'rgba(255,255,255,0.1)',
          backgroundColor: 'rgba(255,255,255,0.05)',
          alignItems: 'center',
          justifyContent: 'center',
          padding: 24
        }}
      >
        <Text
          style={{
            color: theme.palette.textPrimary,
            fontSize: 16,
            textAlign: 'center',
            marginBottom: 16
          }}
        >
          {permissionCopy}
        </Text>
        <Pressable
          onPress={onRequestPermission}
          style={{
            paddingHorizontal: 24,
            paddingVertical: 12,
            backgroundColor: theme.accents.blue,
            borderRadius: 16
          }}
        >
          <Text style={{ color: '#05101f', fontWeight: '700' }}>
            Grant permission
          </Text>
        </Pressable>
      </View>
    );
  }

  if (!device) {
    return (
      <View
        style={{
          flex: 1,
          borderRadius: 32,
          borderWidth: 1,
          borderColor: 'rgba(255,255,255,0.1)',
          backgroundColor: 'rgba(255,255,255,0.05)',
          alignItems: 'center',
          justifyContent: 'center'
        }}
      >
        <ActivityIndicator color={theme.accents.blue} />
        <Text
          style={{
            color: theme.palette.textSecondary,
            fontSize: 13,
            marginTop: 8
          }}
        >
          No camera device found. Use a physical device or enable a simulator
          camera.
        </Text>
      </View>
    );
  }

  return (
    <Camera
      ref={cameraRef}
      style={{ flex: 1, borderRadius: 32, overflow: 'hidden' }}
      device={device}
      isActive={isActive}
      photo
      enableZoomGesture
    />
  );
}
