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
      setStatus('请输入手机号');
      return;
    }
    setStatus('');
    setSending(true);
    try {
      await accountService.requestPhoneOtp(phone);
      setStatus('验证码已发送，请查收短信');
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
      setStatus('绑定成功');
    } catch (error) {
      setStatus(error.message);
    } finally {
      setBinding(false);
    }
  };

  return (
    <ModalSheet title="绑定手机">
      <TrashInput
        label="手机号"
        value={phone}
        onChangeText={setPhone}
        placeholder="6505551234（无需 +1）"
        keyboardType="phone-pad"
      />
      <TrashInput
        label="验证码"
        value={code}
        onChangeText={setCode}
        placeholder="123456"
        keyboardType="number-pad"
      />
      {status ? (
        <Text className="text-white/70 text-xs mb-3">{status}</Text>
      ) : null}
      <TrashButton
        title={sending ? '发送中…' : '发送验证码'}
        onPress={sendCode}
        disabled={sending}
      />
      <TrashButton
        title={binding ? '绑定中…' : '绑定手机'}
        onPress={handleBind}
        disabled={binding}
        style={{ marginTop: 12 }}
      />
    </ModalSheet>
  );
}
