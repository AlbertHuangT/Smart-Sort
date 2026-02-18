import { View } from 'react-native';

export default function TimerBar({ progress = 1, variant = 'info' }) {
  const color = variant === 'warning' ? '#ffae35' : '#32f5ff';
  return (
    <View className="h-3 bg-white/10 rounded-full overflow-hidden mb-4">
      <View
        style={{
          width: `${Math.max(0, Math.min(1, progress)) * 100}%`,
          backgroundColor: color
        }}
        className="h-full"
      />
    </View>
  );
}
