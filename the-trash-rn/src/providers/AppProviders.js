import { useEffect } from 'react';
import { I18nextProvider } from 'react-i18next';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import AchievementToast from 'src/components/shared/AchievementToast';
import i18n from 'src/i18n';
import { useAchievementStore } from 'src/stores/achievementStore';
import { useTrashStore } from 'src/stores/trashStore';
import ThemeProvider from 'src/theme/ThemeProvider';

function AchievementBootstrapper() {
  const load = useAchievementStore((state) => state.load);
  useEffect(() => {
    load();
  }, [load]);
  return null;
}

function ClassifierBootstrapper() {
  const ensureClassifierReady = useTrashStore(
    (state) => state.ensureClassifierReady
  );
  useEffect(() => {
    ensureClassifierReady({ warmup: true }).catch((error) => {
      console.warn('[providers] classifier bootstrap failed', error);
    });
  }, [ensureClassifierReady]);
  return null;
}

export default function AppProviders({ children }) {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <I18nextProvider i18n={i18n}>
          <ThemeProvider>
            {children}
            <AchievementToast />
            <AchievementBootstrapper />
            <ClassifierBootstrapper />
          </ThemeProvider>
        </I18nextProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
