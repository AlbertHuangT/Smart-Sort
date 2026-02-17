import { useRouter } from 'expo-router';
import { Pressable, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

export default function ModalSheet({ title, children }) {
  const router = useRouter();
  const { bottom } = useSafeAreaInsets();

  return (
    <View className="flex-1 justify-end">
      <Pressable className="flex-1" onPress={() => router.back()} />
      <View
        style={{ paddingBottom: bottom + 12 }}
        className="bg-[#050a15] rounded-t-[40px] p-6 border border-white/10"
      >
        <View className="flex-row items-center justify-between mb-4">
          <Text className="text-white font-semibold text-xl">{title}</Text>
          <Pressable onPress={() => router.back()}>
            <Text className="text-white/60 text-sm">关闭</Text>
          </Pressable>
        </View>
        {children}
      </View>
    </View>
  );
}
