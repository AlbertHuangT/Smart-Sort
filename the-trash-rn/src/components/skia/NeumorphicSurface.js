import { View } from 'react-native';

// TODO: Replace with Skia implementation per Phase 8
export default function NeumorphicSurface({ children, style }) {
  return (
    <View
      style={style}
      className="rounded-3xl bg-white/10 border border-white/10"
    >
      {children}
    </View>
  );
}
