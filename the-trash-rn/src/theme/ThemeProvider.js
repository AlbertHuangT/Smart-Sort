import { createContext, useContext } from 'react';

import { useThemeStore } from 'src/stores/themeStore';

import { THEMES } from './themes';

const ThemeContext = createContext(THEMES.neon);

export default function ThemeProvider({ children }) {
  const theme = useThemeStore((state) => state.theme);
  return (
    <ThemeContext.Provider value={theme}>{children}</ThemeContext.Provider>
  );
}

export const useTheme = () => useContext(ThemeContext);
