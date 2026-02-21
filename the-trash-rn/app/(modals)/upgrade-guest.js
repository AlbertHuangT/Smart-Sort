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
        session
          ? 'Upgrade successful. Signed in'
          : 'Account created successfully. Please verify via email'
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
    <ModalSheet title="Upgrade Account">
      <Text className="text-white/70 text-sm mb-4">
        Guest progress is stored locally only. After upgrade, it can sync to
        Supabase and unlock duels, leaderboards, and more.
      </Text>
      <TrashInput
        label="Email"
        value={email}
        onChangeText={setEmail}
        placeholder="you@example.com"
      />
      <TrashInput
        label="Password"
        value={password}
        onChangeText={setPassword}
        placeholder="At least 8 characters"
        secureTextEntry
      />
      {status ? (
        <Text className="text-white/70 text-xs mb-3">{status}</Text>
      ) : null}
      <TrashButton
        title={loading ? 'Submitting...' : 'Sign up with Email'}
        onPress={handleUpgrade}
        disabled={loading}
      />
    </ModalSheet>
  );
}
