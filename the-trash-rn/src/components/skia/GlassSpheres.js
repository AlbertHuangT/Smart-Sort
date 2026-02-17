import { View } from 'react-native';

export default function GlassSpheres({ children, style }) {
  return (
    <View style={style} className="bg-[#050a15]">
      {children}
    </View>
  );
}
