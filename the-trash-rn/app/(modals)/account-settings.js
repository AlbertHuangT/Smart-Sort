import { router } from 'expo-router';
import { Pressable, ScrollView, Text } from 'react-native';

import ModalSheet from 'src/components/layout/ModalSheet';
import { useAuthStore } from 'src/stores/authStore';

const items = [
  { title: '绑定手机', href: '/(modals)/bind-phone' },
  { title: '绑定邮箱', href: '/(modals)/bind-email' },
  { title: '修改密码', href: '/(modals)/change-password' },
  { title: '升级账号', href: '/(modals)/upgrade-guest' }
];

export default function AccountSettingsModal() {
  const signOut = useAuthStore((state) => state.signOut);

  return (
    <ModalSheet title="账户设置">
      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingBottom: 48 }}
      >
        {items.map((item) => (
          <Pressable
            key={item.title}
            className="rounded-3xl border border-white/10 p-4 mb-3"
            onPress={() => router.push(item.href)}
          >
            <Text className="text-white font-semibold">{item.title}</Text>
          </Pressable>
        ))}
        <Pressable
          onPress={signOut}
          className="rounded-3xl bg-red-500/20 border border-red-500/40 p-4"
        >
          <Text className="text-red-200 font-semibold text-center">
            退出登录
          </Text>
        </Pressable>
      </ScrollView>
    </ModalSheet>
  );
}
