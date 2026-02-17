import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { THEMES, DEFAULT_THEME } from 'src/theme/themes';
import { createPersistStorage } from 'src/utils/storage';

const themeKeys = Object.keys(THEMES);

export const useThemeStore = create(
  persist(
    (set, get) => ({
      themeName: DEFAULT_THEME,
      theme: THEMES[DEFAULT_THEME],
      setTheme: (name) => {
        const themeKey = THEMES[name] ? name : DEFAULT_THEME;
        set({ themeName: themeKey, theme: THEMES[themeKey] });
      },
      cycleTheme: () => {
        const idx = themeKeys.indexOf(get().themeName);
        const next = themeKeys[(idx + 1) % themeKeys.length];
        get().setTheme(next);
      }
    }),
    {
      name: 'the-trash-theme',
      storage: createPersistStorage(),
      partialize: (state) => ({ themeName: state.themeName }),
      merge: (persistedState, currentState) => {
        const themeName = persistedState?.themeName ?? DEFAULT_THEME;
        return {
          ...currentState,
          ...persistedState,
          theme: THEMES[themeName] ?? THEMES[DEFAULT_THEME]
        };
      }
    }
  )
);
