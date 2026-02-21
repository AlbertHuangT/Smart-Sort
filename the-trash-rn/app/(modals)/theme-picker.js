import { Pressable, Text, View } from 'react-native';

import ModalSheet from 'src/components/layout/ModalSheet';
import { useThemeStore } from 'src/stores/themeStore';
import { useTheme } from 'src/theme/ThemeProvider';
import { THEMES } from 'src/theme/themes';

export default function ThemePickerModal() {
  const theme = useTheme();
  const { themeName, setTheme } = useThemeStore();

  return (
    <ModalSheet title="Choose Theme">
      <View className="gap-3">
        {Object.entries(THEMES).map(([key, config]) => (
          <Pressable
            key={key}
            onPress={() => setTheme(key)}
            style={{
              borderRadius: 24,
              borderWidth: 1,
              padding: 16,
              borderColor:
                key === themeName ? theme.accents.green : theme.tabBar.border,
              backgroundColor:
                key === themeName
                  ? `${theme.accents.green}20`
                  : theme.palette.card
            }}
          >
            <View
              style={{
                flexDirection: 'row',
                justifyContent: 'space-between',
                alignItems: 'center'
              }}
            >
              <Text
                style={{ color: theme.palette.textPrimary, fontWeight: '700' }}
              >
                {config.label}
              </Text>
              {key === themeName ? (
                <Text
                  style={{
                    color: theme.accents.green,
                    fontSize: 12,
                    fontWeight: '700'
                  }}
                >
                  Current
                </Text>
              ) : null}
            </View>
            <Text
              style={{
                color: theme.palette.textSecondary,
                fontSize: 12,
                marginTop: 4
              }}
            >
              {config.description}
            </Text>
            <View style={{ flexDirection: 'row', gap: 8, marginTop: 10 }}>
              {[
                { slot: 'blue', color: config.accents.blue },
                { slot: 'green', color: config.accents.green },
                { slot: 'orange', color: config.accents.orange }
              ].map(({ slot, color }) => (
                <View
                  key={slot}
                  style={{
                    width: 16,
                    height: 16,
                    borderRadius: 999,
                    backgroundColor: color,
                    borderWidth: 1,
                    borderColor: theme.tabBar.border
                  }}
                />
              ))}
            </View>
          </Pressable>
        ))}
      </View>
    </ModalSheet>
  );
}
