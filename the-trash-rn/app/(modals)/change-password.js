import { useState } from 'react';
import { Text } from 'react-native';
import ModalSheet from 'src/components/layout/ModalSheet';
import { TrashButton, TrashInput } from 'src/components/themed';
import { accountService } from 'src/services/account';

export default function ChangePasswordModal() {
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [status, setStatus] = useState('');
  const [saving, setSaving] = useState(false);

  const handleSave = async () => {
    if (password !== confirm) {
      setStatus('两次输入不一致');
      return;
    }
    setSaving(true);
    setStatus('');
    try {
      await accountService.changePassword(password);
      setStatus('密码已更新');
      setPassword('');
      setConfirm('');
    } catch (error) {
      setStatus(error.message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <ModalSheet title="修改密码">
      <TrashInput
        label="新密码"
        value={password}
        onChangeText={setPassword}
        placeholder="不少于 8 位"
        secureTextEntry
      />
      <TrashInput
        label="确认密码"
        value={confirm}
        onChangeText={setConfirm}
        placeholder="再次输入"
        secureTextEntry
      />
      {status ? <Text className="text-white/70 text-xs mb-3">{status}</Text> : null}
      <TrashButton title={saving ? '保存中…' : '保存'} onPress={handleSave} disabled={saving} />
    </ModalSheet>
  );
}
