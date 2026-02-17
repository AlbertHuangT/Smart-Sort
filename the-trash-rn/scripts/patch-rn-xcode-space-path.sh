#!/bin/sh
set -eu

SCRIPT_PATH="node_modules/react-native/scripts/xcode/with-environment.sh"

if [ -f "$SCRIPT_PATH" ] && grep -q '  $1' "$SCRIPT_PATH"; then
  perl -0pi -e 's/\n  \$1\n/\n  "\$1"\n/' "$SCRIPT_PATH"
  echo "[patch-rn-xcode] patched $SCRIPT_PATH for paths with spaces."
fi

LOCALIZATION_MODULE="$(find node_modules -path '*expo-localization*/ios/LocalizationModule.swift' -print -quit 2>/dev/null || true)"

if [ -n "$LOCALIZATION_MODULE" ] && ! grep -q '@unknown default' "$LOCALIZATION_MODULE"; then
  perl -0pi -e 's/\n    case \.iso8601:\n      return "iso8601"\n/\n    case \.iso8601:\n      return "iso8601"\n    @unknown default:\n      return "gregory"\n/' "$LOCALIZATION_MODULE"
  echo "[patch-rn-xcode] patched ExpoLocalization switch exhaustiveness for Xcode 26."
fi

DEVICE_MODULE="$(find node_modules -path '*expo-device*/ios/UIDevice.swift' -print -quit 2>/dev/null || true)"

if [ -n "$DEVICE_MODULE" ] && grep -q 'TARGET_OS_SIMULATOR != 0' "$DEVICE_MODULE"; then
  perl -0pi -e 's/\n  var isSimulator: Bool \{\n    return TARGET_OS_SIMULATOR != 0\n  \}\n/\n  var isSimulator: Bool {\n    #if targetEnvironment(simulator)\n    return true\n    #else\n    return false\n    #endif\n  }\n/' "$DEVICE_MODULE"
  echo "[patch-rn-xcode] patched ExpoDevice simulator detection for Xcode 26."
fi

DEV_MENU_VIEW_CONTROLLER="$(find node_modules -path '*expo-dev-menu*/ios/DevMenuViewController.swift' -print -quit 2>/dev/null || true)"

if [ -n "$DEV_MENU_VIEW_CONTROLLER" ] && grep -q 'TARGET_IPHONE_SIMULATOR > 0' "$DEV_MENU_VIEW_CONTROLLER"; then
  perl -0pi -e 's/\n    let isSimulator = TARGET_IPHONE_SIMULATOR > 0\n/\n    let isSimulator: Bool = {\n      #if targetEnvironment(simulator)\n      return true\n      #else\n      return false\n      #endif\n    }()\n/' "$DEV_MENU_VIEW_CONTROLLER"
  echo "[patch-rn-xcode] patched ExpoDevMenu simulator detection for Xcode 26."
fi
