import { useState } from 'react';
import { Text } from 'react-native';

import ModalSheet from 'src/components/layout/ModalSheet';
import { TrashButton, TrashInput } from 'src/components/themed';
import { accountService } from 'src/services/account';
import { useAuthStore } from 'src/stores/authStore';

export default function BindEmailModal() {
  const refreshSession = useAuthStore((state) => state.refreshSession);
  const [email, setEmail] = useState('');
  const [code, setCode] = useState('');
  const [sending, setSending] = useState(false);
  const [binding, setBinding] = useState(false);
  const [status, setStatus] = useState('');

  const sendCode = async () => {
    if (!email) {
      setStatus('Please enter email');
      return;
    }
    setStatus('');
    setSending(true);
    try {
      await accountService.requestEmailOtp(email);
      setStatus('Verification code sent. Please check your email');
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
      await accountService.bindEmail({ email, code });
      await refreshSession();
      setStatus('Linked successfully');
    } catch (error) {
      setStatus(error.message);
    } finally {
      setBinding(false);
    }
  };

  return (
    <ModalSheet title="Link Email">
      <TrashInput
        label="Email"
        value={email}
        onChangeText={setEmail}
        placeholder="you@example.com"
        keyboardType="email-address"
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
        title={binding ? 'Binding...' : 'Link Email'}
        onPress={handleBind}
        disabled={binding}
        style={{ marginTop: 12 }}
      />
    </ModalSheet>
  );
}
