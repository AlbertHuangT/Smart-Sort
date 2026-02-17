import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import * as Localization from 'expo-localization';
import en from './en.json';
import zh from './zh.json';

const resources = { en: { translation: en }, zh: { translation: zh } };

if (!i18n.isInitialized) {
  i18n.use(initReactI18next).init({
    compatibilityJSON: 'v3',
    resources,
    lng: (Localization.locale ?? '').startsWith('zh') ? 'zh' : 'en',
    fallbackLng: 'en',
    interpolation: { escapeValue: false }
  });
}

export default i18n;
