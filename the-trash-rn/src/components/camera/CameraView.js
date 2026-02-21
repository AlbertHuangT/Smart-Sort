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
  const device = useCameraDevice('back');
  const theme = useTheme();
  const status = permissionStatus ?? 'unknown';
  const needsPermission = status !== 'authorized';

  const permissionCopy = useMemo(() => {
    if (status === 'denied' || status === 'restricted') {
      return '相机权限已被拒绝，请在设置中开启。';
    }
    return '需要相机权限才能开始扫描。';
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
          <Text style={{ color: '#05101f', fontWeight: '700' }}>授予权限</Text>
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
          加载相机…
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
