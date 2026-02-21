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
      setStatus('The two passwords do not match');
      return;
    }
    setSaving(true);
    setStatus('');
    try {
      await accountService.changePassword(password);
      setStatus('Password updated');
      setPassword('');
      setConfirm('');
    } catch (error) {
      setStatus(error.message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <ModalSheet title="Change Password">
      <TrashInput
        label="New password"
        value={password}
        onChangeText={setPassword}
        placeholder="At least 8 characters"
        secureTextEntry
      />
      <TrashInput
        label="Confirm password"
        value={confirm}
        onChangeText={setConfirm}
        placeholder="Enter again"
        secureTextEntry
      />
      {status ? (
        <Text className="text-white/70 text-xs mb-3">{status}</Text>
      ) : null}
      <TrashButton
        title={saving ? 'Saving...' : 'Save'}
        onPress={handleSave}
        disabled={saving}
      />
    </ModalSheet>
  );
}
