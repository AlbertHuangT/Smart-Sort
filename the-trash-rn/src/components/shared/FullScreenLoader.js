import { ActivityIndicator, Text, View } from 'react-native';

export default function FullScreenLoader({ message }) {
  return (
    <View className="flex-1 items-center justify-center bg-[#040d13]">
      <ActivityIndicator size="large" color="#32f5ff" />
      {message ? <Text className="text-white/70 mt-4">{message}</Text> : null}
    </View>
  );
}
