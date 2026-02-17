import { View, Text } from 'react-native';

export default function StampedIcon({ label }) {
  return (
    <View className="w-12 h-12 rounded-full border border-white/40 items-center justify-center">
      <Text className="text-white/70 text-xs">{label}</Text>
    </View>
  );
}
