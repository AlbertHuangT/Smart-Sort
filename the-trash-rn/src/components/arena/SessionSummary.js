import { Text, View } from 'react-native';

export default function SessionSummary({ title, value, subtitle }) {
  return (
    <View className="rounded-3xl border border-white/10 bg-white/5 p-6">
      <Text className="text-white/70 text-sm mb-1">{title}</Text>
      <Text className="text-white text-4xl font-bold">{value}</Text>
      {subtitle ? <Text className="text-white/60 text-xs mt-2">{subtitle}</Text> : null}
    </View>
  );
}
