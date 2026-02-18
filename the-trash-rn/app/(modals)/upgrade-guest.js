import { useState } from 'react';
import { Text } from 'react-native';

import ModalSheet from 'src/components/layout/ModalSheet';
import { TrashButton, TrashInput } from 'src/components/themed';
import { accountService } from 'src/services/account';
import { useAuthStore } from 'src/stores/authStore';

export default function UpgradeGuestModal() {
  const refreshSession = useAuthStore((state) => state.refreshSession);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [status, setStatus] = useState('');
  const [loading, setLoading] = useState(false);

  const handleUpgrade = async () => {
    setStatus('');
    setLoading(true);
    try {
      await accountService.upgradeGuest({ email, password });
      const session = await refreshSession();
      setStatus(
        session ? '升级成功，已完成登录' : '账号创建成功，请查收验证邮件'
      );
      setEmail('');
      setPassword('');
    } catch (error) {
      setStatus(error.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <ModalSheet title="升级账号">
      <Text className="text-white/70 text-sm mb-4">
        游客进度只保存在本地。升级后可同步到
        Supabase，并开启对战、排行榜等功能。
      </Text>
      <TrashInput
        label="邮箱"
        value={email}
        onChangeText={setEmail}
        placeholder="you@example.com"
      />
      <TrashInput
        label="密码"
        value={password}
        onChangeText={setPassword}
        placeholder="不少于 8 位"
        secureTextEntry
      />
      {status ? (
        <Text className="text-white/70 text-xs mb-3">{status}</Text>
      ) : null}
      <TrashButton
        title={loading ? '提交中…' : '使用邮箱注册'}
        onPress={handleUpgrade}
        disabled={loading}
      />
    </ModalSheet>
  );
}
