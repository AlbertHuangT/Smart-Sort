import { Redirect } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';
import { ScrollView, Text, View, useWindowDimensions } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import FullScreenLoader from 'src/components/shared/FullScreenLoader';
import {
  ThemeBackdrop,
  TrashButton,
  TrashInput,
  TrashPageHeader,
  TrashSegmentedControl
} from 'src/components/themed';
import { useAuthStore } from 'src/stores/authStore';
import { useTheme } from 'src/theme/ThemeProvider';

const LOGIN_OPTIONS = [
  { value: 'email-login', label: '欢迎回来' },
  { value: 'email-signup', label: '创建账号' },
  { value: 'phone', label: '手机验证码' }
];

export default function Index() {
  const [mode, setMode] = useState('email-login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [formError, setFormError] = useState('');
  const [otpMessage, setOtpMessage] = useState('');
  const [statusMessage, setStatusMessage] = useState('');

  const insets = useSafeAreaInsets();
  const { height } = useWindowDimensions();
  const theme = useTheme();
  const spacing = theme.spacing ?? {};
  const bodyType = theme.typography?.body ?? {
    size: 16,
    lineHeight: 25,
    letterSpacing: 0.14
  };
  const captionType = theme.typography?.caption ?? {
    size: 13,
    lineHeight: 19,
    letterSpacing: 0.2
  };
  const inlineActionWidth = theme.sizes?.inlineActionWidth ?? 136;
  const headerSinkOffset = Math.max(0, Math.min(64, (height - 780) * 0.24));

  const status = useAuthStore((state) => state.status);
  const profile = useAuthStore((state) => state.profile);
  const bootstrap = useAuthStore((state) => state.bootstrap);
  const authenticating = useAuthStore((state) => state.authenticating);
  const globalError = useAuthStore((state) => state.error);
  const signInWithEmail = useAuthStore((state) => state.signInWithEmail);
  const signUpWithEmail = useAuthStore((state) => state.signUpWithEmail);
  const signInWithPhone = useAuthStore((state) => state.signInWithPhone);
  const requestPhoneCode = useAuthStore((state) => state.requestPhoneCode);
  const signInAsGuest = useAuthStore((state) => state.signInAsGuest);

  useEffect(() => {
    bootstrap();
  }, [bootstrap]);

  useEffect(() => {
    setFormError('');
    setOtpMessage('');
    setStatusMessage('');
  }, [mode]);

  const canSubmit = useMemo(() => {
    if (mode === 'email-login' || mode === 'email-signup') {
      return email.trim().length > 0 && password.length > 0;
    }
    return phone.trim().length > 0 && code.trim().length > 0;
  }, [mode, email, password, phone, code]);

  const handleSubmit = async () => {
    setFormError('');
    setStatusMessage('');
    try {
      if (mode === 'email-login') {
        if (!email.trim() || !password) {
          setFormError('请输入邮箱和密码');
          return;
        }
        await signInWithEmail({ email: email.trim(), password });
      } else if (mode === 'email-signup') {
        if (!email.trim() || !password) {
          setFormError('请输入邮箱和密码');
          return;
        }
        const result = await signUpWithEmail({ email: email.trim(), password });
        setStatusMessage(
          result?.requiresEmailConfirmation
            ? '注册成功，请先到邮箱确认后再登录。'
            : '注册成功，已自动登录。'
        );
      } else {
        if (!phone.trim() || !code.trim()) {
          setFormError('请输入手机号和验证码');
          return;
        }
        await signInWithPhone({ phone: phone.trim(), code: code.trim() });
      }
    } catch (_error) {
      // 错误已在 store 中记录，无需重复处理
    }
  };

  const handleSendCode = async () => {
    setFormError('');
    setOtpMessage('');
    if (!phone.trim()) {
      setFormError('请输入手机号');
      return;
    }
    try {
      await requestPhoneCode(phone.trim());
      setOtpMessage('验证码已发送（开发环境可直接输入 000000）');
    } catch (_error) {
      // store 会显示错误
    }
  };

  if (status === 'checking') {
    return <FullScreenLoader message="Restoring your session" />;
  }

  if (
    status === 'authenticated' ||
    (status === 'guest' && profile?.id === 'guest')
  ) {
    return <Redirect href="/(tabs)/verify" />;
  }

  return (
    <View style={{ flex: 1, backgroundColor: theme.palette.background }}>
      <ThemeBackdrop />
      <ScrollView
        style={{
          flex: 1
        }}
        decelerationRate={theme.scroll?.decelerationRate ?? 'normal'}
        contentContainerStyle={{
          paddingHorizontal: spacing.screenHorizontal ?? 24,
          paddingTop: insets.top + (spacing.screenTop ?? 56) + headerSinkOffset,
          paddingBottom: insets.bottom + (spacing.screenBottom ?? 44)
        }}
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
      >
        <View style={{ width: '100%' }}>
          <TrashPageHeader
            title="The Trash"
            subtitle="欢迎回来，继续你的环保挑战。登录后即可使用 AI 识别、竞技场和社群。"
          />

          <View style={{ marginBottom: spacing.sectionGap ?? 48 }}>
            <TrashSegmentedControl
              options={LOGIN_OPTIONS}
              value={mode}
              onChange={setMode}
              style={{ marginBottom: spacing.fieldGap ?? 24 }}
            />

            {mode === 'email-login' || mode === 'email-signup' ? (
              <>
                <TrashInput
                  label="邮箱"
                  placeholder="you@example.com"
                  value={email}
                  onChangeText={setEmail}
                  keyboardType="email-address"
                />
                <TrashInput
                  label="密码"
                  placeholder="不少于 8 位"
                  value={password}
                  onChangeText={setPassword}
                  secureTextEntry
                />
              </>
            ) : (
              <>
                <TrashInput
                  label="手机号"
                  placeholder="6505551234（无需手动输入 +1）"
                  value={phone}
                  onChangeText={setPhone}
                  keyboardType="phone-pad"
                />
                <View style={{ flexDirection: 'row', alignItems: 'flex-end' }}>
                  <View style={{ flex: 1, marginRight: spacing.md ?? 16 }}>
                    <TrashInput
                      label="验证码"
                      placeholder="6 位数字"
                      value={code}
                      onChangeText={setCode}
                      keyboardType="number-pad"
                      containerStyle={{ marginBottom: 0 }}
                    />
                  </View>
                  <TrashButton
                    title="获取验证码"
                    variant="outline"
                    onPress={handleSendCode}
                    disabled={authenticating}
                    style={{
                      width: inlineActionWidth
                    }}
                  />
                </View>
              </>
            )}

            {formError ? (
              <Text
                style={{
                  color: theme.palette.danger ?? '#ff6b6b',
                  marginBottom: spacing.xs ?? 8,
                  fontSize: bodyType.size,
                  lineHeight: bodyType.lineHeight,
                  letterSpacing: bodyType.letterSpacing
                }}
              >
                {formError}
              </Text>
            ) : null}

            {!formError && globalError ? (
              <Text
                style={{
                  color: theme.palette.danger ?? '#ff6b6b',
                  marginBottom: spacing.xs ?? 8,
                  fontSize: bodyType.size,
                  lineHeight: bodyType.lineHeight,
                  letterSpacing: bodyType.letterSpacing
                }}
              >
                {globalError}
              </Text>
            ) : null}

            {otpMessage ? (
              <Text
                style={{
                  color: theme.accents.green,
                  marginBottom: spacing.xs ?? 8,
                  fontSize: bodyType.size,
                  lineHeight: bodyType.lineHeight,
                  letterSpacing: bodyType.letterSpacing
                }}
              >
                {otpMessage}
              </Text>
            ) : null}

            {statusMessage ? (
              <Text
                style={{
                  color: theme.accents.green,
                  marginBottom: spacing.xs ?? 8,
                  fontSize: bodyType.size,
                  lineHeight: bodyType.lineHeight,
                  letterSpacing: bodyType.letterSpacing
                }}
              >
                {statusMessage}
              </Text>
            ) : null}

            <TrashButton
              title={
                mode === 'email-login'
                  ? '继续登录'
                  : mode === 'email-signup'
                    ? '创建并继续'
                    : '验证并继续'
              }
              onPress={handleSubmit}
              loading={authenticating}
              disabled={!canSubmit}
            />
          </View>

          <View>
            <TrashButton
              title="游客体验"
              variant="ghost"
              onPress={signInAsGuest}
            />
            <Text
              style={{
                color: theme.palette.textSecondary,
                marginTop: spacing.sm ?? 12,
                fontSize: captionType.size,
                lineHeight: captionType.lineHeight,
                letterSpacing: captionType.letterSpacing
              }}
            >
              Alpha 版本 · 将按 clever-meandering-volcano 计划逐步开放全部功能。
            </Text>
          </View>
        </View>
      </ScrollView>
    </View>
  );
}
