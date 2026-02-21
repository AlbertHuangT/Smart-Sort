import { useState } from 'react';
import { Text } from 'react-native';

import ModalSheet from 'src/components/layout/ModalSheet';
import { TrashButton, TrashInput } from 'src/components/themed';
import { accountService } from 'src/services/account';
import { useAuthStore } from 'src/stores/authStore';

export default function BindPhoneModal() {
  const refreshSession = useAuthStore((state) => state.refreshSession);
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [sending, setSending] = useState(false);
  const [binding, setBinding] = useState(false);
  const [status, setStatus] = useState('');

  const sendCode = async () => {
    if (!phone) {
      setStatus('Please enter phone number');
      return;
    }
    setStatus('');
    setSending(true);
    try {
      await accountService.requestPhoneOtp(phone);
      setStatus('Verification code sent. Please check your SMS');
    } catch (error) {
      setStatus(error.message);
    } finally {
      setSending(false);
    }
  };

  const handleBind = async () => {
    setStatus('');
    setBinding(true);
    try {
      await accountService.bindPhone({ phone, code });
      await refreshSession();
      setStatus('Linked successfully');
    } catch (error) {
      setStatus(error.message);
    } finally {
      setBinding(false);
    }
  };

  return (
    <ModalSheet title="Link Phone">
      <TrashInput
        label="Phone"
        value={phone}
        onChangeText={setPhone}
        placeholder="6505551234 (no +1 required)"
        keyboardType="phone-pad"
      />
      <TrashInput
        label="Code"
        value={code}
        onChangeText={setCode}
        placeholder="123456"
        keyboardType="number-pad"
      />
      {status ? (
        <Text className="text-white/70 text-xs mb-3">{status}</Text>
      ) : null}
      <TrashButton
        title={sending ? 'Sending...' : 'Send Code'}
        onPress={sendCode}
        disabled={sending}
      />
      <TrashButton
        title={binding ? 'Binding...' : 'Link Phone'}
        onPress={handleBind}
        disabled={binding}
        style={{ marginTop: 12 }}
      />
    </ModalSheet>
  );
}
