import { View } from 'react-native';

export default function PaperTexture({ children, style }) {
  return (
    <View style={style} className="bg-[#f1e4cf]">
      {children}
    </View>
  );
}
