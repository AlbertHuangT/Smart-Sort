import { View } from 'react-native';

export default function TornEdges({ children }) {
  return <View className="border-dashed border border-white/20 rounded-3xl">{children}</View>;
}
