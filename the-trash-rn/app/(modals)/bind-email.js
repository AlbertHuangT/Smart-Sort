import { useState } from 'react';
import { Text } from 'react-native';
import ModalSheet from 'src/components/layout/ModalSheet';
import { TrashButton, TrashInput } from 'src/components/themed';
import { accountService } from 'src/services/account';

export default function BindEmailModal() {
  const [email, setEmail] = useState('');
  const [code, setCode] = useState('');
  const [sending, setSending] = useState(false);
  const [binding, setBinding] = useState(false);
  const [status, setStatus] = useState('');

  const sendCode = async () => {
    if (!email) {
      setStatus('请输入邮箱');
      return;
    }
    setStatus('');
    setSending(true);
    try {
      await accountService.requestEmailOtp(email);
      setStatus('验证码已发送，请查收邮件');
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
      setStatus('绑定成功');
    } catch (error) {
      setStatus(error.message);
    } finally {
      setBinding(false);
    }
  };

  return (
    <ModalSheet title="绑定邮箱">
      <TrashInput
        label="邮箱"
        value={email}
        onChangeText={setEmail}
        placeholder="you@example.com"
        keyboardType="email-address"
      />
      <TrashInput
        label="验证码"
        value={code}
        onChangeText={setCode}
        placeholder="123456"
        keyboardType="number-pad"
      />
      {status ? <Text className="text-white/70 text-xs mb-3">{status}</Text> : null}
      <TrashButton title={sending ? '发送中…' : '发送验证码'} onPress={sendCode} disabled={sending} />
      <TrashButton
        title={binding ? '绑定中…' : '绑定邮箱'}
        onPress={handleBind}
        disabled={binding}
        style={{ marginTop: 12 }}
      />
    </ModalSheet>
  );
}
